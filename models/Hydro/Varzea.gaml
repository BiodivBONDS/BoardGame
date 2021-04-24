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
	
}

/*
 * Generic expression of a water body
 */
species water_body virtual:true parent:land_use_based {
	string id;
	
	bool dry <- false;
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
	
	action reverse {
		water_body temp <- origin;
		origin <- destination;
		destination <- temp;
	}
	
	aspect default { draw shape color:landuse_types[parana_type];}
	
}

