/**
* Name: Game
* Based on the internal empty template. 
* Author: kevinchapuis
* Tags: 
*/

model Game

import "Entities.gaml" 

global {
	
	string VERAO <- "Verão";
	string DEFESO <- "Defeso";
	string INVERNO <- "Inverno";
	
	/*
	 * Logistic function of population growth
	 */
	float log_population(int total_population, int carrying_capacity, float reproduction_ratio, 
		float reproductive_population_ratio <- 1.0
	) {
		float N <- float(total_population);
		float K <- float(carrying_capacity); 
		return reproduction_ratio * total_population * reproductive_population_ratio * (1 - N / K); 
	}
	
	float threshold_population { return 0.0; }
	
	/*
	 * Find the proper way to express estacao in the game
	 */
	string get_season(string in, list<string> seasons <- [INVERNO,VERAO,DEFESO]) {
		string pro <- __proper_string_representation(in, seasons);
		if pro=nil {error in+" does not relate with any season in the game: "+seasons;}
		return pro;
	}
	
	/**
	 * MAIN UTILITY TO OUTPUT PROPER STRING REPRESENTATION OF ENTITIES IN THE GAME
	 */
	string __proper_string_representation(string in, list<string> propers, 
		map<string,string> cryp <- map<string,string>([]), int first_n_chars <- 3
	){
		if propers contains in {return in;}
		if not(empty(cryp)) and cryp contains_key in {return cryp[in];}
		string lcin <- lower_case(in); 
		loop p over: propers {
			string lcp <- lower_case(p);
			if lcin = lcp {return p;}
			if lcin copy_between (0,first_n_chars) = lcp copy_between (0,first_n_chars) {return p;}
		}
		return nil;
	}
	
}

species PescaViva {
	
	game_manager gm;
	list<pescador> p;
	list<lugar> l;
	list<peixe> f;
	
	// ----
	// VARS
	
	map<peixe,int> estoque_initial <- [];
	float ratio_valoroso_normal <- 0.2;
	
	map<string,int> arreios_modelo;
	map<string,list<int>> arreios_capacidade;
	
	bool _defesar -> estacao=VERAO and estacao_cycle=2;
	
	int gazolin <- 1;
	
	// -----------
	// SIMULATION
	
	list ESTACAOS;
	map<string,int> estacao_duracao;
	
	// Fish related properties according to seasons
	map<string,float> estacao_densidade;
	map<string,int> estacao_reproducao;
	map<string,int> estacao_migracao;
	
	// Current season
	string estacao;
	
	// The current season cycle (step of the game - season number - within a round - a year)
	int estacao_cycle <- 1;
	int ano <- 1;
	
	bool __rep -> estacao_reproducao contains_key estacao and estacao_reproducao[estacao]=estacao_cycle;
	bool __mig -> estacao_migracao contains_key estacao and estacao_migracao[estacao]=estacao_cycle;
	
	reflex dyn {
		ask gm {do prepare_round;}
		
		ask p { do pescar; }
		if __rep { do reproducao; }
		if __mig { do migracao; }

		ask gm {do close_round;}
	}
	
	action reproducao {
		
		// REPROD
		int K <- sum(f accumulate (each.estoque))*2;
		int N <- sum(l accumulate each._estoque.values);
		float lr <- mean(f collect each.r);
		map<peixe,int> repro <- f as_map (each::0);
		ask f {
			int festoque; 
			ask myself.l { festoque <- festoque + _estoque[myself]; }
			repro[self] <- round(world.log_population(N,K,lr,festoque*1.0/N));
		}
		
		//EXIT
		ask l { loop fi over:myself.f { _estoque[fi] <- max(0, _estoque[fi] - round(imigracao * __imqualidade * (fi.valor=2?0.2:0.8) / 2)); } }
		
		//MIG
		float gambiante <- sum(l collect (each._ambiante_peixe));
		loop pei over:repro.keys {
			ask l { 
				float nes <- repro[pei] * _ambiante_peixe / gambiante;
				_estoque[pei] <- _estoque[pei] + int(nes) + (flip(nes-int(nes))?1:0);
				if _estoque[pei] < 0 {error "Negative stock during migration: "+name+"|"+pei.name+" = "+_estoque[pei];}
			}
		}
	}
	
	action migracao {

		ask l {
			do renovacao; 
			loop fi over:myself.f {_estoque[fi] <- _estoque[fi] + round(imigracao * __imqualidade * (fi.valor=2?0.2:0.8) / 2); }
		}
		/* 
		map<peixe,int> gestoque;
		float gambiante <- sum(l collect (each._ambiante_peixe));
		ask f { gestoque[self] <- sum(myself.l collect (each._estoque[self])); }
		loop fs over:f { 
			ask l {
				float nes <- gestoque[fs] * _ambiante_peixe / gambiante;
				_estoque[fs] <- int(nes) + (flip(nes-int(nes))?1:0);
				if _estoque[fs] < 0 {error "Negative stock during migration: "+name+"|"+fs.name+" = "+_estoque[fs];}
			}
		}
		* 
		*/
	}
	
	action atualizar_estacao {
		if estacao_duracao[estacao]=estacao_cycle {
			if ESTACAOS index_of estacao = length(ESTACAOS)-1 { 
				estacao <- first(ESTACAOS); ano <- ano + 1;
			} else {
				estacao <- ESTACAOS[(ESTACAOS index_of estacao) + 1];
			}
			estacao_cycle <- 1;
		} else {
			estacao_cycle <- estacao_cycle + 1;
		}
	}
	
}

species game_manager virtual:true {
	PescaViva pv;
	container<pescador> create_pescadores(list args) virtual:true;
	container<lugar> create_lugares(list args) virtual:true;
	container<peixe> create_peixe(list args) virtual:true;
	action prepare_round virtual:true;
	action close_round virtual:true;
}
