/**
 * Name: Bonds
 * Based on the internal empty template. 
 * Author: etsop
 * Tags: 
 */


model Bonds

import "Utilities/Bonds Log.gaml"
import "Utilities/Tabulero.gaml"

import "Entities/Pescador.gaml"
import "Hydro/Varzea.gaml"

import "Parameters.gaml"

global {

	// INIT WORLD
	geometry shape <- game_board and board_map!=nil ? envelope(board_map) : rectangle(w_size,h_size);
	
	// RASTER BASED LANDUSE
	int w_size <- 150; 
	int h_size <- 100;
	
	// LAND USE
	string rio_type <- "RIO";
	string forest_type <- "FOREST";
	string pasto_type <- "GRASS";
	string lago_type <- "WATER";
	string parana_type <- "CHANNEL";
	string comunidade_type <- "COMMUNITY";
	string default_type <- "LAND";
	map<string,rgb> landuse_types <- [
		rio_type::#midnightblue,
		forest_type::#forestgreen,
		pasto_type::#mediumaquamarine,
		lago_type::#dodgerblue,
		parana_type::#deepskyblue,
		comunidade_type::#slategrey,
		default_type::#sandybrown
	];

	init {
		
		do read_parameter;
		
		if game_board and board_map != nil {
			do build_tabulero_species(board_map);
		} else {
			do build_tabulero_from_scratsh();
		}
		
		do init_landuse;
		do init_hydro_graph;
		
	}
	
	/*
	 * Draw the environment based on species properties and shapes
	 */
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

species pasto parent:land_use_based { bool natural; aspect default { draw shape color:landuse_types[pasto_type];}  }

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
		
		 layout horizontal([0::6141,vertical([vertical([1::5000,2::5000])::6921,3::3079])::3859]) consoles:true tabs:true editors: false;
		
		
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
			species pasto;
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