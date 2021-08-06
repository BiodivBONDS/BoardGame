/**
* Name: Calibration
* Based on the internal empty template. 
* Author: kevinchapuis
* Tags: 
*/


model Calibration

import "../Parameters.gaml"

global {
	
	// ext * K = capacity
	float K <- 5.0 parameter:true min:2.0 max:20.0;
	bool K_low <- true parameter:true;
	float estoque_start_factor <- 0.5 parameter:true min:0.1 max:2.0;
	float rep_factor <- 0.1 parameter:true min:0.01 max:1.0;
	
	int channel_ext <- 8 parameter:true min:5 max:30;
	
	bool water_body_reproduction <- true parameter:true;
	float channel_regrowing_factor <- 1.0 parameter:true min:0.5 max:5.0;
	
	int l0 <- 100 parameter:true min:10 max:100;
	int l1 <- 80 parameter:true min:10 max:100;
	int l2 <- 30 parameter:true min:10 max:100;
	
	float dec_ext_factor <- 2/3.0 parameter:true min: 0.1 max: 1.0;
	float inc_ext_factor <- 2/3.0 parameter:true min: 0.1 max: 1.0;
	float low_ext_factor <- 1/3.0 parameter:true min: 0.1 max: 1.0;
	
	bool repro_high_season <- false parameter:true;
	bool repro_dec_season <- false parameter:true;
	bool repro_low_season <- false parameter:true;
	bool repro_inc_season <- true parameter:true;
	
	
	list<string> reproduction_season <- [];
	list<list<water_body>> groups;
	
	// Scenario
	map<string,float> hydro_scenario <- ["high"::1.0,"dec"::dec_ext_factor,"low"::low_ext_factor,"inc"::inc_ext_factor];

	list<int> lakes <- [l0,l1,l2];
	map<pair<string,string>,map<string,string>> connections_scenario <- [
		("R"::"0")::CONSTANT_DEEP,("0"::"2")::DEEP_TO_SHALLOW,("1"::"2")::DEEP_TO_SHALLOW,("1"::"R")::DEEP_TO_DRY
	];
	
	// Seasonal dynamic
	graph<water_body,channel> hydro_graph <- graph([]);
	
	string current_season -> [HIGH_WATER_SEASON,DEC_WATER_SEASON,LOW_WATER_SEASON,INC_WATER_SEASON][cycle mod 4];
	
	map<string,string> CONSTANT_DEEP <- [HIGH_WATER_SEASON::DEEP_CHANNEL,DEC_WATER_SEASON::DEEP_CHANNEL,LOW_WATER_SEASON::DEEP_CHANNEL,INC_WATER_SEASON::DEEP_CHANNEL];
	map<string,string> DEEP_TO_SHALLOW <- [HIGH_WATER_SEASON::DEEP_CHANNEL,DEC_WATER_SEASON::SHALLOW_CHANNEL,LOW_WATER_SEASON::SHALLOW_CHANNEL,INC_WATER_SEASON::DEEP_CHANNEL];
	map<string,string> DEEP_TO_DRY <- [HIGH_WATER_SEASON::DEEP_CHANNEL,DEC_WATER_SEASON::SHALLOW_CHANNEL,LOW_WATER_SEASON::DRY_CHANNEL,INC_WATER_SEASON::SHALLOW_CHANNEL];

	init {
		if repro_inc_season {reproduction_season <+ INC_WATER_SEASON;}
		if repro_high_season {reproduction_season <+ HIGH_WATER_SEASON;}
		if repro_low_season {reproduction_season <+ LOW_WATER_SEASON;}
		if repro_dec_season {reproduction_season <+ DEC_WATER_SEASON;}
		create rio;
		loop e over:lakes {create lake with:[name::"L"+lakes index_of e,referent_ext::e,extencao::e] {hydro_graph <- hydro_graph add_node self;}}
		loop pc over:connections_scenario.keys {
			create channel with:[season_water_level::connections_scenario[pc],extencao::channel_ext] { 
				if pc.key = "R" {origin <- first(rio);} else {origin <- lake[int(pc.key)];}
				if pc.value = "R" {destination <- first(rio);} else {destination <- lake[int(pc.value)];}
				hydro_graph <- hydro_graph add_edge (self.origin::self.destination);
				name <- origin.name+destination.name;
			}
		}
		loop wb over:lake+channel { wb.estoque <- float(wb.referent_ext)*hydro_scenario["inc"]*estoque_start_factor*K;}
	}

	reflex repoduction when:reproduction_season contains current_season {
		if water_body_reproduction {
			map<channel,int> reported_fish_stock;
			list<channel> fish_repopulation;
			ask channel {
				if water_level=DRY_CHANNEL { reported_fish_stock[self] <- estoque; estoque <- 0.0;}
				else if water_level!=DRY_CHANNEL and estoque=0 { fish_repopulation <+ self; }
				else { do update_estoque(rep_factor,(K_low?extencao:referent_ext)*K); }
			}
			ask lake {
				list<channel> add_to <- reported_fish_stock.keys where (each.origin=self or each.destination=self);
				
				// Fish from dry channels goes into lakes 
				loop c over:add_to {
					if c.origin=rio[0] or c.destination=rio[0] { estoque <- estoque + reported_fish_stock[c];}
					else { estoque <- estoque + reported_fish_stock[c]/2;}
				}
				
				// Update lake fish stock
				do update_estoque(rep_factor,(K_low?extencao:referent_ext)*K);
			}
			ask fish_repopulation {
				float fish_limit <- extencao * channel_regrowing_factor;
				map<water_body,int> sources;
				if origin=rio[0] { sources[destination] <- fish_limit; } 
				else if destination=rio[0] { sources[origin] <- fish_limit;}
				// Proportionnaly split fish from sources according to source (lake) size
				else {
					int overall <- origin.extencao+destination.extencao; 
					sources[origin] <- fish_limit * origin.extencao / overall; sources[destination] <- fish_limit * destination.extencao / overall;
				}
				
				loop wb over:sources.keys {
					int fish_move <- sources[wb];
					// If there is enough fish then move them
					if wb.estoque > fish_move { 
						estoque <- fish_limit; wb.estoque <- wb.estoque - fish_move;
					// Otherwise equally split fish stock
					} else {
						estoque <- wb.estoque/2; wb.estoque <- wb.estoque/2;
					} 
				}
			}
		} else {
			groups <- [];
			list<channel> connected_channels <- channel where (each.water_level != DRY_CHANNEL);
			ask lake {
				// TODO : avoid being dependant over lake looping order and having 2 dependant groups
				if groups=nil or empty(groups) { groups <+ [self]+connected_channels where (each.origin=self or each.destination=self); }
				else {
					bool match <- false;
					loop g over:groups { 
						if g where (each is channel) one_matches (channel(each).origin=self or channel(each).destination=self) {
							match <- true; 
							g <+ self;
							g <<+ connected_channels where (not(g contains each) and (each.origin=self or each.destination=self));
						} 
					}
					if not(match) {
						groups <+ [self]+connected_channels where (each.origin=self or each.destination=self);
					}
				}
			}
			write "Nb of stocks = "+length(groups)+" | details: "+sample(groups);
			loop g over:groups {
				float total_estoque <- g sum_of (each.estoque);
				int total_extencao <- g sum_of ((K_low?each.extencao:each.referent_ext));
				int te <- total_extencao;
				float new_estoque <- min(total_estoque + total_estoque * rep_factor, total_extencao * K);
				loop wb over:shuffle(g) { 
					wb.estoque <- min(new_estoque*wb.extencao/te, wb.extencao * K);
					new_estoque <- new_estoque - wb.estoque;
					te <- te - wb.extencao;
				}
			}
		}
	}

}

/*
 * Generic expression of a water body
 */
species water_body virtual:true {
	string id;

	int referent_ext;
	int extencao;
	float estoque;
	
	float densidade {
		return estoque/float(extencao);
	}
	
	action update_estoque(float factor, float max) { estoque <- min([estoque + estoque * factor,max]); }
}

species rio parent:water_body { init {name <- "Rio grande";} }

species lake control:fsm parent:water_body {
	
	state low { transition to:inc { extencao <- round(referent_ext * hydro_scenario[state]); } }
	state inc { transition to:high { extencao <- round(referent_ext * hydro_scenario[state]); }}
	state dec { transition to:low { extencao <- round(referent_ext * hydro_scenario[state]); }}
	state high initial:true { transition to:dec { extencao <- round(referent_ext * hydro_scenario[state]); }}
	
}

species channel parent:water_body {
	water_body origin;
	water_body destination;
	
	map<string,string> season_water_level;
	string water_level -> season_water_level[current_season];
}

experiment test {
	output {
		monitor "nb stocks" value:length(groups);
		display "fish population" {
			chart "Fish population" type: series {
				loop wb over: lake+channel { data wb.name value:wb.estoque; }
			}
		}
		display "Water body fish occupation" {
			chart "Fish proportion to K" type: series {
				loop wb over: lake+channel { data wb.name value:wb.estoque / (wb.extencao * K); }
			}
		}
	}
}
