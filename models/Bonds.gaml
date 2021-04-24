/**
 * Name: Bonds
 * Based on the internal empty template. 
 * Author: etsop
 * Tags: 
 */


model Bonds

import "Utilities/Bonds Log.gaml"

import "Entities/Pescador.gaml"
import "Hydro/Varzea.gaml"

import "Parameters.gaml"

global {

		
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
	string feature_char_attribute <- "att";
	
	string rio_type <- "RIO";
	string forest_type <- "FOREST";
	string lago_type <- "WATER";
	string parana_type <- "CHANNEL";
	string comunidade_type <- "COMMUNITY";
	string default_type <- "LAND";
	map<string,rgb> landuse_types <- [
		rio_type::#midnightblue,
		forest_type::#forestgreen,
		lago_type::#dodgerblue,
		parana_type::#deepskyblue,
		comunidade_type::#slategrey,
		default_type::#sandybrown
	];
	
	shape_file board_map <- shape_file("../includes/drawn_environment.shp");
	geometry shape <- envelope(board_map);
	
	// GAME RULES
	string CHOOSE_FISHING_SPOT <- "fishing spot";
	string GO_BACK_TO_COMU <- "return from fishing";
	
	// RASTER BASED LANDUSE
	int w_size <- 150; 
	int h_size <- 100;

	init {
		
		do read_parameter;
		
		do print_as("Param "+sample(starting_nb_boats),self,DEFAULT_LEVEL);
		
		if board_map != nil {
			
			list<string> coms <- [];
			loop geom over:board_map.contents {
				string t <- geom.attributes[feature_type_attribute];
				string id <- geom.attributes[feature_id_attribute];
				switch t {
					match rio_type {create rio with:[shape::geom,id::"R"];}
					match lago_type {
						string short_id <- copy_between(id,0,2);
						string season_id <- copy_between(id,2,3);
						if lago none_matches (each.id = short_id) { create lago with:[id::short_id]; }
						lago cl <- lago first_with (each.id = short_id);
						switch season_id { 
							match "H" {cl.season_shapes[HIGH_WATER_SEASON] <+ geom;} 
							match_one ["M","L"] {cl.season_shapes[LOW_WATER_SEASON] <+ geom;}
						}
					}
					match parana_type {create parana with:[shape::geom,id::id];}
					match forest_type {create forest with:[shape::geom];}
					match comunidade_type {
						string num <- copy_between(id,0,2);
						if not (coms contains num) { coms <+ num; create comunidade with:[id::num];}
						comunidade my_com <- comunidade first_with (each.id = num);
						create pescador with:[comu::my_com,homeplace::geom,location::any_location_in(geom)];
						my_com.pescadores <+ last(pescador);
					}	
				}
			}
			
			ask lago { shape <- union(season_shapes[LOW_WATER_SEASON] collect (each+0.1));}
			
		} else {
			do create_comunidades;
			create lago number:length(init_lagos) {id <- "L"+int(self);}
			create parana number:length(init_paranas);
			create rio with:[id::"R"];
		}
		
		do init_landuse;
		do tabuleiro;
		
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
			estoque <- float(init_lagos[int(last(id))-1].value);
			fish_stock_cache[cycle] <- fish_stock_cache[cycle]+estoque; 
			int nb_lugares <- int(extencao/5);
			
			// Area for baixao
			list<geometry> baixao_de_pesca <- [];
			loop baixao_parana over:paranas collect (each.shape + 2) {
				geometry g <- shape inter baixao_parana;
				baixao_de_pesca <+ last(g.geometries sort (each.area));
			} 
			
			// Area of regular lugares de pesca
			list<geometry> lugares_de_pesca <- (shape - baixao_de_pesca) to_sub_geometries list_with(nb_lugares,round(shape.area)/extencao*5);
			lugares_de_pesca <- lugares_de_pesca collect union(each.geometries where (each.area > 0));
			
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
			if length(baixaos)=1 {
				point rio_link <- ((shape + 1) inter first(rio).shape).centroid;
				hydro_graph <- hydro_graph add_node (rio_link);
				hydro_graph <- hydro_graph add_edge (rio_link::first(baixaos));
			}
			else if length(baixaos)=2 {hydro_graph <- hydro_graph add_edge (first(baixaos)::last(baixaos));}
			else {error "There should be no more than 2 extremity to a parana ("+self+" connected to "+length(baixaos)+" lugares)";}
		}
		
		// BUILDING COMUNITY SHAPE AND ACCESSIBILITY
		ask comunidade {
			shape <- envelope(pescadores collect (each.homeplace));
			lugar_de_pesca zero_cost_lugar <- lugar_de_pesca closest_to shape;
			loop l over:lugar_de_pesca { graph_accesibilidade[l] <- length(path(hydro_graph path_between (zero_cost_lugar,l)).edges); }
		}

	}
	
	action init_landuse {
		ask landuse { 
			list<agent> ovlps <- agents_overlapping(self.location) where (each.shape.attributes contains_key feature_type_attribute);
			if empty(ovlps) {type <- default_type;}
			else {
				agent a <- ovlps first_with (landuse_types contains_key each.shape.attributes[feature_type_attribute]);
				if a != nil { 
					type <- a.shape.attributes[feature_type_attribute];
					the_host <- a;
					if a is land_use_based { land_use_based(a).cover <+ self; }
				} else { 
					type <- default_type;
					the_host <- world;
				}
			}
			color <- landuse_types[type];
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
	
	// HYDRO
	graph hydro_graph <- graph([]);
	string hydro_regime -> cycle=0? LOW_WATER_SEASON : (cycle mod 2 = 0 ? LOW_WATER_SEASON : HIGH_WATER_SEASON);
	
	/*
	 * MASTER GAME CYCLE
	 * -----------------
	 * No pescador reflexes
	 */
	reflex game_schedule when:general_dyn {
		do print_as("global schedule",self,theme::SCH);
		ask pescador { do allocate_boats; }
		if cycle=0 {fish_stock_cache[0] <- 0.0;}
		ask lugar_de_pesca where not(empty(each.fishing_boats)) { do fishing_output; }
		ask pescador { do sell_fish; }
	}
	
	/*
	 * The action to sell the fish and get back money 
	 * TODO : is there any rate for fish ? might be interesting considering fish species ?
	 * TODO : is there any agent (e.g. attraversador) that might do the process ? PNG ? Game master ? Players ?
	 */ 
	float sold_fish(float fish_quantity) { return fish_quantity * fish_selling_price; }
	
}

/////////
// ENV //
/////////

species land_use_based virtual:true { list<landuse> cover; }

species forest parent:land_use_based { aspect default { draw shape color:landuse_types[forest_type];} }

species pasto parent:land_use_based { bool natural; }

grid landuse width: w_size height: h_size {
	agent the_host;
	string type;
	aspect default { draw shape color:color; }
}

///////////////
// SIMULACAO //
///////////////

experiment xp_board {
	output {
		
		 layout horizontal([0::6141,vertical([vertical([1::5000,2::5000])::6921,3::3079])::3859]) consoles:false tabs:true editors: false;
		
		
		monitor season value:hydro_regime refresh:true;
		monitor fishes value:round(fish_stock_cache[cycle]) refresh:true color:(cycle<2?#black:(fsc.key>fsc.value?#red:(fsc.key<fsc.value?#green:#black)));
		monitor reproduction value:round(fish_reproduction[cycle]) refresh:true;
		monitor fished value:round(fish_fished_cache[cycle]) refresh:true color:#grey;
		
		display game_board {

			species landuse;
			species rio;
			species lago aspect: hydro;
			species parana;
			species lugar_de_pesca;
			species forest;
			species comunidade transparency:0.8;
			species boat;
			species pescador;
			graphics "hydro graph" {
				loop v over:hydro_graph.vertices { draw circle(0.5) at:point(v) color:#white; }
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