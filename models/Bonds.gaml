/**
* Name: Bonds
* Based on the internal empty template. 
* Author: etsop
* Tags: 
*/


model Bonds

import "Utilities/UIActions.gaml"

global {

	// PESCADORES
	int nb_comunidades <- 3;
	int nb_pescadores <- 12;
	int init_money_bank <- 5;
	float fish_selling_price <- 1.0 parameter:true min:0.1 max:5.0 category:eco;

	// BOATS
	int starting_nb_boats <- 1;
	int init_boat_capacity <- 5 parameter:true min:2 max:20 step:1 category:eco;
	float move_cost_ratio <- 0.2 parameter:true min:0.1 max:1.0 step:0.1 category:eco;
	
	// FISHING
	string rnd_spot <- "rnd_spot";
	string dst_spot <- "dst_spot";
	string eff_spot <- "eff_spot";
	string global_spot_strategy <- rnd_spot parameter:true among:["rnd_spot","dst_spot","eff_spot"] category:decision;
	
	// FISH
	int max_fish_stock_per_unit <- 50;
	float normal_recovery <- 0.1 parameter:true min:0.1 max:1.0 step:0.1 category:fish;
	float degradeted_recovery <- 0.05 parameter:true min:0.05 max:0.5 step:0.05 category:fish; 
	float high_threshold_recovery <- 4/5;
	float low_threshold_recovery <- 1/5;
	
	// LAGOS
	list<pair<int,int>> init_lagos <- [(20::100),(10::40),(20::100),(15::60)];
	list<pair<string,string>> init_paranas <- [
		(string(rio)::"L1"),("L1"::"L2"),("L2"::"L3"),(string(rio)::"L3"),("L3"::"L4")
	];
	
	// BAIXAO MANAGEMENT
	string regular <- "Regular";
	string regular_baixao <- "Regular baixao";
	string rio_baixao <- "Rio baixao";
	map<string,float> lugar_weights <- [regular::0.5,regular_baixao::1.0,rio_baixao::2.0];
	
	// GIS-like GAME BOARD
	string feature_type_attribute <- "type";
	string feature_id_attribute <- "id";
	string rio_type <- "RIO";
	string lago_type <- "WATER";
	string parana_type <- "CHANNEL";
	string comunidade_type <- "COMMUNITY";
	shape_file board_map <- shape_file("../includes/drawn_environment.shp");
	geometry shape <- envelope(board_map);
	
	// GAME RULES
	string CHOOSE_FISHING_SPOT <- "fishing spot";
	string GO_BACK_TO_COMU <- "return from fishing";

	init {
		
		if board_map != nil {
			
			list<string> coms <- [];
			loop geom over:board_map.contents {
				string t <- geom.attributes[feature_type_attribute];
				string id <- geom.attributes[feature_id_attribute];
				switch t {
					match rio_type {create rio with:[shape::geom,id::"R"];}
					match lago_type {create lago with:[shape::geom,id::id];}
					match parana_type {create parana with:[shape::geom,id::id];}
					match comunidade_type {
						string num <- copy_between(id,0,2);
						if not (coms contains num) { coms <+ num; create comunidade with:[id::num];}
						comunidade my_com <- comunidade first_with (each.id = num);
						create pescador with:[comu::my_com,homeplace::geom,location::any_location_in(geom)];
						my_com.pescadores <+ last(pescador);
					}	
				}
			}
			
		} else {
			do create_comunidades;
			create lago number:length(init_lagos) {id <- "L"+int(self);}
			create parana number:length(init_paranas);
			create rio with:[id::"R"];
		}
	
		do tabuleiro;
		if board_map = nil {do block_setup;}
		
	}
	
	/*
	 * Create comunidades from scratch
	 */
	action create_comunidades {
		create comunidade number:nb_comunidades;
		ask comunidade {
			create pescador number:rnd(1,nb_pescadores-length(pescador)) 
				with:[comu::self] returns:pescs;
			pescadores <- pescs;
		}
	}
	
	/*
	 * Create environment from the originaly drawn object :
	 * - link lake with proper channels
	 * - build fishing spot with corresponding fish stocks
	 */
	action tabuleiro {
		
		ask parana {
			string ori;
			string dest;
			if id = nil or id = "" {
				ori <- init_paranas[int(self)].key;
				dest <-  init_paranas[int(self)].value;
			} else {
				ori <- first(id) = "R" ? string(rio) : copy_between(id,0,2);
				dest <- last(id) = "R" ? string(rio) : copy_between(id,length(id)-2,length(id));
			}
			
			// Set channel's origin
			if ori=string(rio) { origin <- first(rio); }
			else { origin <- lago first_with (each.id = ori); lago(origin).paranas <+ self; }
			
			// Set channel's destination
			if dest=string(rio) { destination <- first(rio); }
			else { destination <- lago first_with (each.id = dest); lago(destination).paranas <+ self; }
		}
		
		ask lago {
			
			// Compute lac size and fish stock
			extencao <- init_lagos[int(last(id))-1].key;
			estoque <- float(init_lagos[int(self)].value);
			int nb_lugares <- int(extencao/5);
			
			// Area for baixao
			list<geometry> baixao_de_pesca;
			loop baixao_parana over:paranas collect (each.shape + 2) {
				baixao_de_pesca <+ shape inter baixao_parana;
			} 
			
			// Area of regular lugares de pesca
			list<geometry> lugares_de_pesca <- (shape - baixao_de_pesca) to_sub_geometries (list_with(nb_lugares,shape.area/extencao*5));
			
			// Regular fishing spot
			int lid <- 1;
			create lugar_de_pesca number:nb_lugares with:[localisacao::self] {
				extencao <- int((myself.extencao - length(baixao_de_pesca)) / nb_lugares);
				name <- myself.id+lid;
				lid <- lid+1;
				shape <- any(lugares_de_pesca);
				lugares_de_pesca >- shape;
				myself.lugares <+ self::lugar_weights[regular];
			}
			
			map<parana,float> parana_weights <- paranas as_map (each::([each.origin,each.destination] contains first(rio)) ? 
				lugar_weights[rio_baixao] : lugar_weights[regular_baixao]
			);
			
			// Create baixoa
			ask paranas {
				geometry the_area <- baixao_de_pesca closest_to self;
				create lugar_de_pesca with:[shape::the_area,localisacao::myself] returns:lps;
				first(lps).name <- myself.id+(self.origin=myself?self.destination.id:self.origin.id);
				myself.lugares <+ first(lps)::nb_lugares * parana_weights[self] / sum(parana_weights.values);
			}
			
			ask lugares.keys { estoque <- myself.estoque_de_lugar(self); extencao <- 1; }
		}

		// BUILDING HYDRO NETWORK
		ask lugar_de_pesca { hydro_graph <- hydro_graph add_node self; }
		ask lugar_de_pesca { 
			loop c over:lugar_de_pesca where (each.shape overlaps self.shape) { hydro_graph <- hydro_graph add_edge (self::c);}
		}
		ask parana { 
			list<lugar_de_pesca> baixaos <- lugar_de_pesca where (each.shape overlaps self.shape);
			if length(baixaos)=1 {hydro_graph <- hydro_graph add_edge (first(rio)::first(baixaos));}
			else if length(baixaos)=2 {hydro_graph <- hydro_graph add_edge (first(baixaos)::last(baixaos));}
			else {error "There should be no more than 2 extremity to a parana ("+self+" connected to "+length(baixaos)+" lugares)";}
		}
		
		// BUILDING COMUNITY SHAPE AND ACCESSIBILITY
		ask comunidade {
			shape <- envelope(pescadores collect (each.homeplace));
			accesibilidade <- lugar_de_pesca as_map (each::10 / each distance_to self);
			lugar_de_pesca zero_cost_lugar <- lugar_de_pesca closest_to shape;
			loop l over:lugar_de_pesca { graph_accesibilidade[l] <- length(path(hydro_graph path_between (zero_cost_lugar,l)).edges); }
		}

	}

	action block_setup {
		list<geometry> splited_env <- shape to_rectangles (2,1);
		
		list<geometry> com_env <- first(splited_env) to_squares (length(comunidade),false);
		ask comunidade {
			create RegularBox with:[name::self.name,shape::com_env[int(self)],_size::5#m];
			RegularBox com_box <- last(RegularBox);
			ask pescadores { ask com_box {do insert_empty(myself); } }
		}
		list<geometry> lagos_env <- last(splited_env) to_squares (length(lago)+1,false);
		create GridBox with:[name::first(rio).name,shape::first(lagos_env),_x::1,_y::1,color::#darkblue];
		ask lago {
			create GridBox with:[name::self.name,shape::lagos_env[int(self)+1],_x::length(lugares),_y::1,color::#blue];
			GridBox lago_box <- last(GridBox);
			ask lugares.keys { ask lago_box {do insert_empty(myself); } }
		}
	}

	//------//
	// GAME //
	//------//

	bool general_dyn <- true;
	// ----------------------
	string SPOT <- "Choose fishing spot";
	string COMU <- "Return to community"; 
	list<string> game_turns <- [SPOT,COMU];
	string game_turn -> general_dyn ? game_turns[cycle mod length(game_turns)] : nil;
	// ----------------------
	
	graph hydro_graph <- graph([]) add_node first(rio);
	
	/*
	 * MASTER GAME CYCLE
	 * -----------------
	 * No pescador reflexes
	 */
	reflex game_schedule when:general_dyn {
		ask pescador { do allocate_boats; }
		ask lugar_de_pesca where not(empty(each.fishing_boats)) {
			float fish_catch <- estoque / 2 / length(fishing_boats); 
			ask fishing_boats {
				load <- min(fish_catch, capacity);
				myself.estoque <- myself.estoque - load;
			}
		}
		ask pescador { do sell_fish; }
	}
	
	/*
	 * The action to sell the fish and get back money 
	 * TODO : is there any rate for fish ? might be interesting considering fish species ?
	 * TODO : is there any agent (e.g. attraversador) that might do the process ? PNG ? Game master ? Players ?
	 */ 
	float sold_fish(float fish_quantity) { return fish_quantity * fish_selling_price; }
	
}

//////////
// AQUA //
//////////

species water_body virtual:true parent:selectable {
	string id;
	
	bool dry <- false;
	int extencao;
	float estoque;
	
	float densidade {
		return estoque/float(extencao);
	}
}

species rio parent:water_body {
	aspect default {
		draw "RIO" at:centroid(shape) font:font(20,#bold) color:#white;
		draw shape color:#midnightblue;
	}
}

species lugar_de_pesca parent:water_body {
	
	water_body localisacao;
	
	list<boat> fishing_boats;
	
	reflex update_fish_stock {
		if estoque > extencao * max_fish_stock_per_unit {estoque <- float(extencao * max_fish_stock_per_unit);}
		else if estoque > extencao * max_fish_stock_per_unit * high_threshold_recovery 
			or estoque < extencao * max_fish_stock_per_unit * low_threshold_recovery { estoque <- estoque + estoque * degradeted_recovery; }
		else {estoque <- estoque + estoque * normal_recovery;}
		fishing_boats <- [];  
	}
	
	aspect default { 
		draw name at:shape.centroid color:#white; draw shape.contour color:#white;
		if selected { draw (shape + 0.25).contour color:contour_color;}
	}
}

species lago parent:water_body {
	
	map<lugar_de_pesca,float> lugares;
	list<parana> paranas;
	
	float estoque_de_lugar(lugar_de_pesca lugar) {
		if not (lugares contains_key lugar) {return 0.0;}
		return lugares[lugar] / sum(lugares.values) * estoque;
	}  
	
	reflex fish_distribution {
		estoque <- sum(lugares.keys collect each.estoque);
		ask lugares.keys {estoque <- myself.estoque_de_lugar(self);}
	}
	
	aspect default { draw shape color:#dodgerblue;}
}

species parana parent:water_body {
	bool open <- true;
	water_body origin;
	water_body destination;
	
	bool chanel -> origin != rio(0) or destination != rio(0);
	
	action reverse {
		water_body temp <- origin;
		origin <- destination;
		destination <- temp;
	}
	
	aspect default { draw shape color:#deepskyblue;}
	
}

///////////////
// SOCIEDADE //
///////////////

species boat { 
	int capacity;
	float load;
	rgb color;
	init {capacity <- init_boat_capacity;}
	aspect default {draw rectangle(2,0.5)+triangle(1) color:color;}
}

species pescador parent:selectable {
	
	geometry homeplace;
	comunidade comu;
	
	// Fishing attributes
	list<boat> my_boats;
	float fish_catch;

	float money_bank;
	// TODO : movement constraints (e.g. gazoline, accessibility)
	
	init {
		create boat number:starting_nb_boats with:[location::any_location_in(homeplace+2),color::comu.color] returns:bs;
		my_boats <- bs;
	}
	
	action allocate_boats {
		map<lugar_de_pesca,float> distribution;
		list<lugar_de_pesca> accessible_lugares <- comu.graph_accesibilidade.keys where (comu.graph_accesibilidade[each] * move_cost_ratio <= money_bank);
		switch global_spot_strategy {
			match rnd_spot {distribution <- accessible_lugares as_map (each::1.0);}
			match dst_spot {distribution <- accessible_lugares as_map (each::comu.accesibilidade[each]);}
			match eff_spot {distribution <- accessible_lugares as_map (each::each.estoque);}
		}
		loop b over:my_boats {
			lugar_de_pesca ldp <- rnd_choice(distribution);
			ldp.fishing_boats <+ b;
			b.location <- any_location_in(ldp);
			money_bank <- money_bank - comu.graph_accesibilidade[ldp] * move_cost_ratio;
		}	
	}
	
	action sell_fish {
		money_bank <- money_bank + world.sold_fish(fish_catch);
		ask my_boats {
			myself.fish_catch <- load; 
			load <- 0.0;
		}
	}
	
	aspect default {
		draw homeplace.contour color:comu.color;
		draw circle(0.4).contour color:#darkgreen;
		draw circle(0.4) color:comu.color;
		if selected { draw contour_shape ? circle(1).contour : circle(1) at:location color:contour_color; }
	}
	
} 

species comunidade {
	
	string id;
	rgb color;
	
	list<pescador> pescadores;
	map<lugar_de_pesca,float> accesibilidade;
	map<lugar_de_pesca,int> graph_accesibilidade;
	
	init {
		if color=nil { color <- rnd_color(255); }
	}
	
	aspect default { 
		draw shape color:color border:#black;
	}	
}

///////////////
// SIMULACAO //
///////////////

experiment xp_board {
	output {
		
		layout horizontal([0::6141,vertical([vertical([1::5000,2::5000])::6921,3::3079])::3859]) consoles:false tabs:true editors: false;
		
		display game_board {
			event mouse_down action: select_agent;
			event mouse_menu action: inspect_agent;
			event mouse_move action: move_select;
			
			species rio;
			species lago;
			species parana;
			species lugar_de_pesca;
			species comunidade transparency:0.8;
			species boat;
			species pescador;
			graphics "hydro graph" {
				loop v over:hydro_graph.vertices { draw circle(0.5) at:agent(v).location color:#white; }
				loop e over:hydro_graph.edges {draw geometry(e) color:#black;}
				loop c over: comunidade {
					draw line([
						c.graph_accesibilidade.keys first_with (c.graph_accesibilidade[each]=0),
						first(c closest_points_with (c.graph_accesibilidade.keys first_with (c.graph_accesibilidade[each]=0)))
					])+0.25 color:c.color;
				}
			}	
		}
		display env {
			chart "fish stocks" type:series {
				loop l over:lago {
					data "fs:"+l.id value: l.estoque style: spline;
				}
			}
		}
		display pesca {
			chart "fish catch" type:series {
				loop p over:pescador {
					data "p"+int(p) value: p.fish_catch style: spline;
				}
			}
		}
		display bank {
			chart "money bank" type:series {
				loop p over:pescador {
					data "p"+int(p) value: p.money_bank style: spline;
				}
			}
		}
	}
}

experiment xp_test {}

experiment xp_ui {
	output {
		layout vertical([0::7285,1::2715]) tabs:true consoles:false navigator:false ;
		display boxes {
			species GridBox;
			species RegularBox;
			species pescador;
			
			event mouse_down action: select_agent;
			event mouse_menu action: inspect_agent;
			event mouse_move action: move_select;
			graphics "selection zone" transparency:0.4 {
				draw circle(select_threshold) at: select_loc empty: true border: true color: #black;
			}
		}
		monitor selected_agent value:sample(selected_agent) refresh:true;
		display actions type: opengl draw_env:false {
			species button;
			event mouse_down action:activate_act; 
		}
	}
}