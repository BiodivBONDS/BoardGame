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
		(string(rio)::"0"),("0"::"1"),("1"::"2"),(string(rio)::"2"),("2"::"3")
	];
	
	string regular <- "Regular";
	string regular_baixao <- "Regular baixao";
	string rio_baixao <- "Rio baixao";
	map<string,float> lugar_weights <- [regular::0.5,regular_baixao::1.0,rio_baixao::2.0];
	
	init {
		
		do create_comunidades;
		
		create lago number:length(init_lagos);
		create parana number:length(init_paranas);
		create rio;
	
		do tabuleiro;
		do block_setup;
		
	}
	
	action create_comunidades {
		create comunidade number:nb_comunidades;
		ask comunidade {
			create pescador number:rnd(1,nb_pescadores-length(pescador)) 
				with:[comu::self] returns:pescs;
			pescadores <- pescs;
		}
	}
	
	action tabuleiro {
		
		ask parana {
			string ori <- init_paranas[int(self)].key;
			string dest <-  init_paranas[int(self)].value;
			
			// Set channel's origin
			if ori=string(rio) { origin <- first(rio); }
			else { origin <- lago(int(ori)); lago(int(ori)).paranas <+ self; }
			
			// Set channel's destination
			if dest=string(rio) { destination <- first(rio); }
			else { destination <- lago(int(dest)); lago(int(dest)).paranas <+ self; }
		}
		
		ask lago {
			
			// Compute lac size and fish stock
			extencao <- init_lagos[int(self)].key;
			estoque <- float(init_lagos[int(self)].value);
			int nb_lugares <- int(extencao/5);
			
			// Regular fishing spot
			create lugar_de_pesca number:nb_lugares with:[localisacao::[self]] { myself.lugares <+ self::lugar_weights[regular]; }
			
			map<parana,float> parana_weights <- paranas as_map (each::([each.origin,each.destination] contains first(rio)) ? lugar_weights[rio_baixao] : lugar_weights[regular_baixao]);
			
			// Create baixoa
			ask paranas {
				create lugar_de_pesca with:[localisacao::[origin,destination]] returns:lps;
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
	bool dry <- false;
	int extencao;
	float estoque;
	
	float densidade {
		return estoque/float(extencao);
	}
}

species rio parent:water_body {}

species lago parent:water_body {
		
	map<lugar_de_pesca,float> lugares;
	list<parana> paranas;
	
	float estoque_de_lugar(lugar_de_pesca lugar) {
		if not (lugares contains_key lugar) {return 0.0;}
		return lugares[lugar] / sum(lugares.values) * estoque;
	}  
	
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
	
}

species lugar_de_pesca parent:selectable {
	list<lugar_de_pesca> conectidade;
	list<water_body> localisacao;
	float estoque;	
}

///////////////
// SOCIEDADE //
///////////////

species pescador parent:selectable {
	
	comunidade comu;
	lugar_de_pesca lp;
	
	aspect default {
		draw circle(1) color:#black;
		if selected { draw contour_shape ? circle(1).contour : circle(1) at:location color:contour_color; }
	}
	
} 

species comunidade {
	list<pescador> pescadores;
	list<lugar_de_pesca> accesibilidade;	
}

///////////////
// SIMULACAO //
///////////////

experiment xp_test {}

experiment xp_ui {
	output {
		layout vertical([0::7285,1::2715]) tabs:true consoles:false navigator:false ;
		display boxes {
			species GridBox;
			species RegularBox;
			species pescador;
			
			event mouse_down action: select_agent;
			event mouse_move action: move_select;
			graphics "selection zone" transparency:0.4 {
				draw circle(select_threshold) at: select_loc empty: true border: true color: #black;
			}
		}
		monitor selected_agent value:sample(selected_agent);
		display actions type: opengl draw_env:false {
			species button;
			event mouse_down action:activate_act; 
		}
	}
}