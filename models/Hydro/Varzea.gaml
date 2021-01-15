/**
* Name: Varzea
* Based on the internal empty template. 
* Author: kevinchapuis
* Tags: 
*/


model Varzea

import "../Bonds.gaml"

/*
 * Generic expression of a water body
 */
species water_body virtual:true parent:selectable {
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
		if estoque > extencao * max_fish_stock_per_unit {estoque <- float(extencao * max_fish_stock_per_unit);}
		else if estoque > extencao * max_fish_stock_per_unit * high_threshold_recovery 
			or estoque < extencao * max_fish_stock_per_unit * low_threshold_recovery { 
				estoque <- estoque + estoque * degradeted_recovery * hydro_regime_fish_growth[hydro_regime];
			}
		else {
			estoque <- estoque + estoque * normal_recovery * hydro_regime_fish_growth[hydro_regime];
		}
		fishing_boats <- [];  
	}
	
	aspect default { 
		draw name + "("+int(estoque / (extencao * max_fish_stock_per_unit) * 100)+"%)" at:shape.centroid color:#white; draw shape.contour color:#white;
		draw (envelope(shape) scaled_by (point((estoque / (extencao * max_fish_stock_per_unit)),1,1)) inter shape) color:#grey;
		if selected { draw (shape + 0.25).contour color:contour_color;}
	}
}

/*
 * The Rio river
 */
species rio parent:water_body {
	aspect default {
		draw "RIO" at:centroid(shape) font:font(20,#bold) color:#white;
		draw shape color:#midnightblue;
	}
}

/*
 * The lagos of the varzea
 */
species lago parent:water_body {
	
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
	
	aspect default { draw shape color:#dodgerblue;}
}

/*
 * The channels of the varzea
 */
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

