/**
* Name: Comunidade
* Based on the internal empty template. 
* Author: kevinchapuis
* Tags: 
*/

model Pescador

import "../Bonds.gaml"

global {
	
	// Fix number of comunidades and pescadores
	int nb_comunidades <- 3;
	int nb_pescadores <- 12;
	
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
		float move_cost <- move_cost_ratio * (hydro_regime = LOW_WATER_SEASON ? move_cost_low_water_factor : 1);
		list<lugar_de_pesca> accessible_lugares <- comu.graph_accesibilidade.keys;
		if move_cost_limitation {accessible_lugares <- accessible_lugares where (comu.graph_accesibilidade[each] * move_cost <= money_bank);}
		switch global_spot_strategy {
			match rnd_spot {distribution <- accessible_lugares as_map (each::1.0);}
			match dst_spot {distribution <- accessible_lugares as_map (each::comu.accesibilidade[each]);}
			match eff_spot {distribution <- accessible_lugares as_map (each::each.estoque);}
		}
		loop b over:my_boats {
			lugar_de_pesca ldp <- rnd_choice(distribution);
			ldp.fishing_boats <+ b;
			b.location <- any_location_in(ldp);
			money_bank <- money_bank - comu.graph_accesibilidade[ldp] * move_cost;
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
		if IMG_SHAPE { draw house_imf size:{7,4,0}; } 
		else { draw homeplace.contour color:comu.color; }
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

