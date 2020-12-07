/**
* Name: Bonds
* Based on the internal empty template. 
* Author: etsop
* Tags: 
*/


model Bonds

import "Utilities/UIBox.gaml"
import "Utilities/UIActions.gaml"

global {

	int nb_comunidades <- 3;
	int nb_pescadores <- 12;
	
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

	init {
		
		if board_map != nil {
			
			loop geom over:board_map.contents {
				list<string> coms <- [];
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
			create lugar_de_pesca number:nb_lugares with:[localisacao::[self]] {
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
				create lugar_de_pesca with:[shape::the_area,localisacao::[origin,destination]] returns:lps;
				first(lps).name <- myself.id+(self.origin=myself?self.destination.id:self.origin.id);
				myself.lugares <+ first(lps)::nb_lugares * parana_weights[self] / sum(parana_weights.values);
			}
			
			ask lugares.keys { estoque <- myself.estoque_de_lugar(self); write sample(self)+" fish stock is :"+with_precision(estoque,2);}
		}
		
		ask comunidade {
			accesibilidade <+ lago accumulate (each.lugares.keys) closest_to self;
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
	
}

//////////
// AQUA //
//////////

species water_body virtual:true {
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

species lago parent:water_body {
	
	map<lugar_de_pesca,float> lugares;
	list<parana> paranas;
	
	float estoque_de_lugar(lugar_de_pesca lugar) {
		if not (lugares contains_key lugar) {return 0.0;}
		return lugares[lugar] / sum(lugares.values) * estoque;
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

species lugar_de_pesca parent:selectable {
	list<lugar_de_pesca> conectidade;
	list<water_body> localisacao;
	float estoque;	
	
	aspect default { draw name at:shape.centroid color:#white; draw shape.contour color:#white; }
}

///////////////
// SOCIEDADE //
///////////////

species pescador parent:selectable {
	
	geometry homeplace;
	
	comunidade comu;
	lugar_de_pesca lp;
	
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
	list<lugar_de_pesca> accesibilidade;
	
	init {
		if color=nil { color <- rnd_color(255); }
	}
	
	aspect default {
		draw envelope(pescadores collect (each.homeplace)) color:color border:#black; 
	}	
}

///////////////
// SIMULACAO //
///////////////

experiment xp_board {
	output {
		display game_board {
			species rio;
			species lago;
			species parana;
			species lugar_de_pesca;
			species comunidade transparency:0.8;
			species pescador;	
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