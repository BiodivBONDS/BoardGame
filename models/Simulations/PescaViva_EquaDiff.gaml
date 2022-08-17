/**
* Name: EquaDiff
* Based on the internal empty template. 
* Author: kevinchapuis
* Tags: 
*/


model EquaDiff

import "../Game.gaml"
import "../Jogo.gaml"

global {
	
	// ==================
	// Choose game
	
	bool twofish;
	float lisoprop;
	float lisoescamareprodiff;
	bool twolocation;
	float rioprop;
	float rioeffort;
	
	bool pvsed;
	// ==========
	string pe <- "escama";
	string pl <- "liso";
	string pb <- "brilhante";
	eqf get_peixe(string nomo, bool brilhante) { return eqf first_with (each.modelo = nomo+(brilhante?" "+pb:"")); }
	// ==========
	// Pop initial
	int init_pop parameter:true init:100 min:50 max:500;
	// Reproduction rate
	float r parameter:true init:0.1 min:0.01 max:0.4;
	float o parameter:true init:0.05 min:0.01 max:0.4;
	// Carrying capacity
	int K parameter:true init:200 min:100 max:1000;
	// Net immigration
	int i parameter:true init:5 min:0 max:50;
	// Fishing effort
	int e parameter:true init:10 min:1 max:50;
	// ==========
	
	fishingSED mod;
	list<fishingSED> pvmod;
	init {
		if pvsed {
			
			write "Create pv";
			create edmanager; 
			PescaViva game <- leer_o_jogo(first(edmanager));
			write "Create differential equations";
			loop lug over:eql { loop pex over:eqf {create lugarsed with:[l::lug,f::pex];}}
			write "Setup model";
			pvmod <- list(lugarsed); 
			
		} else {
		
			if twofish and twolocation {
				create pvleq with:[x::init_pop,
					x1r::init_pop*lisoprop*rioprop, x2r::init_pop*(1-lisoprop)*rioprop,
					x1l::init_pop*lisoprop*(1-rioprop), x2l::init_pop*(1-lisoprop)*(1-rioprop),
					Kr::K*rioprop,Kl::K*(1-rioprop)
				];
			} else if twofish {
				create pveq with:[x1::init_pop*lisoprop,x2::init_pop*(1-lisoprop)];
			} else if twolocation {
				create leq with:[x::init_pop,
					xr::init_pop*rioprop,xl::init_pop*(1-rioprop),
					Kr::K*rioprop,Kl::K*(1-rioprop)
				];
			} else {
				create eq with:[x::init_pop];	
			}
			mod <- fishingSED(first(fishingSED.subspecies accumulate each.population));
			
		}
	}
	
	int trials(int trials, float proba) { return binomial(trials,proba); }
	
	list<int> n_trial_without_replacement(list<int> success_ranks, int trials) {
		int rank <- 0;
		list<int> bin <- [];
		loop sr over:success_ranks { bin <<+ list_with(success_ranks[rank],rank); rank <- rank+1; }
		map<int,list<int>> draws <- bin sample (trials-1,false) group_by (each);
		return draws.keys sort (each) collect (length(draws[each]));
	}
}

species fishingSED virtual:true {
	float t; //time
	float x; //fish population
	
	equation pop;
	reflex solving { solve pop method: #rk4;}
}


species eq parent:fishingSED {
	equation pop {diff(x,t) = (r * x + i) * (1 - x / K) - binomial(e,x/K);}
}

species pveq parent:fishingSED {
	
	float x -> x1+x2; 
	float x1; // Liso
	float x2; // Escama
	
	equation pop { 
		diff(x1,t) = (r * x1 + i) * (1 - x / K) - binomial(e,x1/K);
		diff(x2,t) = (r * lisoescamareprodiff * x2 + i) * (1 - x / K) - binomial(e,x2/K);
	}
	
}

species leq parent:fishingSED {
	float x -> xr+xl;
	float xr; float Kr;
	float xl; float Kl;
	equation pop {
		diff(xr,t) = (r*xr+i)*(1-xr/Kr) - binomial(e*rioeffort,xr/Kr);
		diff(xl,t) = r*xl*(1-xl/Kl) - binomial(e*(1-rioeffort),xl/Kl);
	}
	
}

species pvleq parent:fishingSED {
	
	float x -> xr+xl; 
	float xr -> x1r+x2r; // Liso
	float xl -> x1l+x2l; // Escama
	
	float Kr; float Kl;
	float x1r; float x1l;
	float x2r; float x2l;
	
	equation pop {
		diff(x1r,t) = (r*x1r+i-o*x1r)*(1-xr/Kr)-binomial(e*rioeffort,x1r/Kr);
		diff(x1l,t) = (r*x1l+o*x1r)*(1-xl/Kl)-binomial(e*(1-rioeffort),x1l/Kl);
		diff(x2r,t) = (r*lisoescamareprodiff*x2r+i-o*x2r)*(1-xr/Kr)-binomial(e*rioeffort,x2r/Kr);
		diff(x2l,t) = (r*lisoescamareprodiff*x2l+o*x2r)*(1-xl/Kl)-binomial(e*(1-rioeffort),x2l/Kl);
	}
	
}

//==================//
// PescaViva in SDE //
//==================//

species lugarsed parent:fishingSED {
	eql l;
	eqf f;
	equation pop {
		diff(x,t) = 
			(f.r * x // normal reproduction 
				+ l.imigracao) // imigration of fish
				* (1 - sum(l._estoque.values)/l._branco) // carrying capacity limit 
				- binomial((eqp first_with (l=each.lug)).effort,sum(l._estoque.values)/l._branco); // fishing effort
	}
	reflex uptd { l._estoque[f] <- x; }
}

species edmanager parent:game_manager {
	
	container<pescador> create_pescadores(list args) {
		int nbp <- length(args);
		list peff <- list_with(nbp,1);
		int remaining_effort <- e - sum(peff);
		loop while:remaining_effort>0 {
			loop idx from:0 to:nbp-1 { 
				int ip <- int(min(remaining_effort,rnd(0,e*1.0/nbp))); 
				peff[idx] <- peff[idx]+ip; remaining_effort <- remaining_effort-ip;
			}
		}
		create eqp number:length(args) returns:eqps { effort <- peff[int(self)]; } 
		return eqp;
	}
	
	container<lugar> create_lugares(list args) {
		loop lug over:args {
			map l <- map(lug);
			create eql with:[
				name::l[LUNOM],
				imigracao::int(l[LUIMI]),
				_ambiante_peixe::float(l[LUMIG]),
				_branco::100
			];
		}
		return eql;
	}
	
	container<peixe> create_peixe(list args) { loop pei over:args { map p <- map(pei); create eqf with:[name::p[PESP],estoque::int(p[PEST])]; } return eqf; }
	
	action prepare_round {} action close_round {}
}

species eqp parent:pescador { int effort; lugar lug; action pescar {} action custo_fixo {}}
species eql parent:lugar { action reproducao {} action renovacao {} }
species eqf parent:peixe { float r; }

//================

experiment xp type:gui {
	
	float minimum_cycle_duration <- 0.1#s;
	
	parameter "pesca viva ODE" var:pvsed init:false disables:[twofish,lisoprop,lisoescamareprodiff,twolocation,rioprop,rioeffort];
	
	parameter "2 fish species" var:twofish init:false enables:[lisoprop];
	parameter "Proportion of liso" var:lisoprop init:0.5 min:0.05 max:0.95;
	parameter "Escama/liso reproduction ratio" var:lisoescamareprodiff init:1.0 min:0.5 max:2.0;
	parameter "2 fishing spot" var:twolocation init:true enables:[rioprop,rioeffort];
	parameter "Rio weight" var:rioprop init:0.5 min:0.2 max:0.8;
	parameter "Rio effort" var:rioeffort init:0.5 min:0.1 max:0.9;
	
	output {
		display display_charts toolbar: false {
			chart "fish population" type: series background: rgb(47,47,47) color: #white {
				if mod!=nil {
					data "fish" value:mod.x color:#darkgrey;
					if mod is leq {
						data "rio" value:leq(mod).xr color:#brown;
						data "lago" value:leq(mod).xl color:#blue;
					}
					if mod is pveq {
						data "liso" value:pveq(mod).x1 color:#orange;
						data "escama" value:pveq(mod).x2 color:#green;
					}
					if mod is pvleq {
						data "liso no rio" value:pvleq(mod).x1r color:#darkorange;
						data "liso no lago" value:pvleq(mod).x1l color:#indigo;
						data "escama no rio" value:pvleq(mod).x2r color:#olive;
						data "escama no lago" value:pvleq(mod).x2l color:#turquoise;
					}
				} else if not(empty(pvmod)) {
					loop l over:lugarsed { data l.name value:sum(l.l._estoque.values); }
				}
			}
		}
	}
}
