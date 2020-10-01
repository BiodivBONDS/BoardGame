/**
* Name: Bonds
* Based on the internal empty template. 
* Author: etsop
* Tags: 
*/


model Bonds

global {

	int nb_comunidades <- 3;
	int nb_pescadores <- 12;
	int nb_lagos <- 4;
	
	init {
		
		create comunidade number:nb_comunidades;
		create pescador number:nb_pescadores with:[comu::any(comunidade)];
		create lago number:nb_lagos;
		create rio;
	
		do tabuleiro;
		
	}
	
	action tabuleiro {
		ask lago(0) { 
			extencao <- 20;
			estoque <- 100;
			create parana { 
				origin <- first(rio);
				destination <- myself;
				create lugar_de_pesca { 
					lugares <<+ [myself,lago(0)];
					estoque <- 40;
				}
				lugares <+ last(lugar_de_pesca);
			}
			paranas <+ last(parana);
			create parana {
				origin <- myself;
				destination <- lago(1);
				create lugar_de_pesca { 
					lugares <<+ [myself,lago(0)];
					estoque <- 10;
				}
				lugares <+ last(lugar_de_pesca);
				create lugar_de_pesca { 
					lugares <<+ [myself,lago(1)];
					estoque <- 10;
				}
				lugares <+ last(lugar_de_pesca);
			}	
			paranas <+ last(parana);
			lago(1).paranas <+ last(parana);
		}
		ask lago(1) {
			extencao <- 10;
			estoque <- 40;
			create parana {
				origin <- myself;
				destination <- lago(2);
				create lugar_de_pesca { 
					lugares <<+ [myself,lago(1)];
					estoque <- 10;
				}
				lugares <+ last(lugar_de_pesca);
				create lugar_de_pesca { 
					lugares <<+ [myself,lago(2)];
					estoque <- 10;
				}
				lugares <+ last(lugar_de_pesca);
			}
			paranas <+ last(parana);
			lago(2).paranas <+ last(parana);
		}
		ask lago(2) {
			extencao <- 20;
			estoque <- 100;
			create parana {
				origin <- first(rio);
				destination <- myself;
				create lugar_de_pesca { 
					lugares <<+ [myself,lago(2)];
					estoque <- 20;
				}
				lugares <+ last(lugar_de_pesca);
			}
			paranas <+ last(parana);
			create parana number:2 returns:prns {
				origin <- myself;
				destination <- lago(3);
				create lugar_de_pesca { 
					lugares <<+ [myself,lago(2)];
					estoque <- 10;
				}
				lugares <+ last(lugar_de_pesca);
				create lugar_de_pesca { 
					lugares <<+ [myself,lago(3)];
					estoque <- 15;
				}
				lugares <+ last(lugar_de_pesca);
			}	
			paranas <<+ prns;
			lago(3).paranas <<+ prns;
		}
		ask lago(3) {
			extencao <- 15;
			estoque <- 60;
		}
		ask lago {
			int nb_lugares <- int(extencao/5);
			create lugar_de_pesca number:nb_lugares returns: ldp
				with:[estoque::self.estoque/2/nb_lugares, lugares::[self]];
			lugares <<+ ldp;
		}
	}
	
}

//////////
// AQUA //
//////////

species water_body virtual:true {
	bool dry <- false;
	int extencao;
	int estoque;
	
	float densidade {
		return estoque/float(extencao);
	}
}

species rio parent:water_body {}

species lago parent:water_body {
		
	list<lugar_de_pesca> lugares;
	list<parana> paranas;
	
}

species parana parent:water_body {
	bool open <- true;
	water_body origin;
	water_body destination;
	
	list<lugar_de_pesca> lugares;
	
	action reverse {
		water_body temp <- origin;
		origin <- destination;
		destination <- temp;
	}
	
}

species lugar_de_pesca {
	list<lugar_de_pesca> conectidade;
	list<water_body> lugares;
	int estoque;	
}

///////////////
// SOCIEDADE //
///////////////

species pescador {
	
	comunidade comu;
	lugar_de_pesca lp;
	
} 

species comunidade {
	list<pescador> pescadores;
	list<lugar_de_pesca> accesibilidade;	
}

///////////////
// SIMULACAO //
///////////////

experiment xp {}