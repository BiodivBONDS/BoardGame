/**
* Name: Varzea
* Based on the internal empty template. 
* Author: kevinchapuis
* Tags: 
*/


model Varzea

import "../Bonds.gaml"

global {
	
	list<float> fish_stock_cache <- list_with(100,0.0);
	list<float> fish_reproduction <- list_with(100,0.0);
	list<float> fish_fished_cache <- list_with(100,0.0);
	pair<int,int> fsc -> round(fish_stock_cache[cycle=0?0:cycle-1])::round(fish_stock_cache[cycle]);
	
	/*
	 * Create the connectivity graph based on the fishing spots
	 */
	action init_hydro_graph {
		
		// add all fishing spots as nodes of the graph
		ask lugar_de_pesca { hydro_graph <- hydro_graph add_node self; }
		
		// connect them to one another when they are spatially connected (overlaps)
		ask lugar_de_pesca { 
			loop c over:lugar_de_pesca where (each.shape overlaps self.shape) {
				ask world {do print_as("Add an edge between "+sample(self)+" and "+sample(c),myself,first(level_list));} 
				hydro_graph <- hydro_graph add_edge (self::c);
			}
		}
		
		// Build connections based on parana
		ask parana { 
			list<lugar_de_pesca> baixaos <- lugar_de_pesca where (each.shape overlaps self.shape);
			if empty(baixaos) and origin!=nil and destination!=nil { // Means that parana has no shape but connections
				water_body o <- origin;
				water_body d <- destination;
				if o is rio { 
					point rio_link <- first(first(rio).shape closest_points_with d.shape);
					lugar_de_pesca ldp <- lago(d).lugares.keys closest_to o;
					
					ask world {do print_as(sample(rio_link)+" "+sample(lago(d).lugares), myself, first(level_list));}
					
					hydro_graph <- hydro_graph add_node (rio_link);
					hydro_graph <- hydro_graph add_edge (rio_link::ldp);
				}
				else if d is rio { 
					point rio_link <- first(first(rio).shape closest_points_with o.shape);
					hydro_graph <- hydro_graph add_node (rio_link);
					hydro_graph <- hydro_graph add_edge (rio_link::lago(o).lugares.keys closest_to d);
				}
				else { 
					baixaos <+ lago(o).lugares.keys closest_to d;
					baixaos <+ lago(d).lugares.keys closest_to o;
				}
			} 
			else if length(baixaos)=1 {
				point rio_link <- ((shape + 1) inter first(rio).shape).centroid;
				hydro_graph <- hydro_graph add_node (rio_link);
				hydro_graph <- hydro_graph add_edge (rio_link::first(baixaos));
			}
			else if length(baixaos)=2 {hydro_graph <- hydro_graph add_edge (first(baixaos)::last(baixaos));}
			else {
				ask world {do print_as("There should be no more than 2 extremity to a parana ("+self
					+" connected to "+length(baixaos)+" lugares)",myself,last(level_list));}
			}
		}
		
		// associate communities with the network for accessibility
		ask comunidade {
			lugar_de_pesca zero_cost_lugar <- lugar_de_pesca closest_to shape;
			loop l over:lugar_de_pesca {
				path tp <- hydro_graph path_between (zero_cost_lugar,l);
				ask world {do print_as(sample(tp),myself,DEFAULT_LEVEL);}
				graph_accesibilidade[l] <- tp=nil?-1:length(tp.edges);
			}
		}

	}
	
}

/*
 * Generic expression of a water body
 */
species water_body virtual:true parent:land_use_based {
	string id;
	
	string water_level;
	int extencao;
	float estoque;
	
	float densidade {
		return estoque/float(extencao);
	}
}

/*
 * Discret spot to fish in lakes
 */
species lugar_de_pesca parent:water_body {
	
	water_body localisacao;
	
	list<boat> fishing_boats;
	
	reflex update_fish_stock {
		ask world {do print_as("update fish stock", myself, theme::SCH);}
		float reprod; // Fish reproduction amount
		if estoque > extencao * max_fish_stock_per_unit * high_threshold_recovery 
			or estoque < extencao * max_fish_stock_per_unit * low_threshold_recovery { 
				reprod <- estoque * degradeted_recovery * hydro_regime_fish_growth[hydro_regime];
			}
		else {
			reprod <- estoque * normal_recovery * hydro_regime_fish_growth[hydro_regime];
		}
		if estoque + reprod > extencao * max_fish_stock_per_unit {reprod <- extencao * max_fish_stock_per_unit - estoque;}
		
		estoque <- estoque + reprod;
		fish_reproduction[cycle] <- fish_reproduction[cycle] + reprod;
		fish_stock_cache[cycle] <- fish_stock_cache[cycle] + estoque;
		fishing_boats <- [];  
	}
	
	action fishing_output {
		float fish_catch <- estoque / (hydro_regime = LOW_WATER_SEASON ? 3/2 : 3) 
				/ length(fishing_boats); 
		ask fishing_boats {
			load <- min(fish_catch, capacity);
			myself.estoque <- myself.estoque - load;
			fish_fished_cache[cycle] <- fish_fished_cache[cycle] + load;
		}
		ask world{do print_as("Fish fished : "+round(fish_fished_cache[cycle]),myself);}
	}
	
	aspect default { 
		draw name + "("+int(estoque / (extencao * max_fish_stock_per_unit) * 100)+"%)" at:shape.centroid color:#white; draw shape.contour color:#white;
	}
}

/*
 * The Rio river
 */
species rio parent:water_body {
	aspect default {
		draw "RIO" at:centroid(shape) font:font(20,#bold) color:#white;
		draw shape color:landuse_types[rio_type];
	}
}

/*
 * The lagos of the varzea
 */
species lago parent:water_body {
	
	map<string,list<geometry>> season_shapes <- [LOW_WATER_SEASON::[],HIGH_WATER_SEASON::[]];
	
	map<lugar_de_pesca,float> lugares;
	list<parana> paranas;
	
	float estoque_de_lugar(lugar_de_pesca lugar) {
		if not (lugares contains_key lugar) {return 0.0;}
		return lugares[lugar] / sum(lugares.values) * estoque;
	}  
	
	reflex fish_distribution {
		ask world {do print_as("distribute fish stock", myself, theme::SCH);}
		estoque <- sum(lugares.keys collect each.estoque);
		ask lugares.keys {estoque <- myself.estoque_de_lugar(self);}
	}
	
	aspect default { draw shape color:landuse_types[lago_type];}
	aspect hydro { draw hydro_regime=LOW_WATER_SEASON?shape:union(shape+union(season_shapes[HIGH_WATER_SEASON])) color:landuse_types[lago_type];}
}

/*
 * The channels of the varzea
 */
species parana parent:water_body {
	
	water_body origin;
	water_body destination;
	
	bool chanel -> origin != rio(0) or destination != rio(0);
	
	map<string,string> season_water_level;
	
	action reverse {
		water_body temp <- origin;
		origin <- destination;
		destination <- temp;
	}
	
	aspect default { draw shape color:landuse_types[parana_type];}
	
}

