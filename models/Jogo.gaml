/**
* Name: jogo
* Based on the internal empty template. 
* Author: kevinchapuis
* Tags: 
*/

model jogo

import "Game.gaml"

global {
	
	// ========================================
	// Configuration of the game
	
	string ojogofile <- "../includes/jogo.json";
	map jogo;
    
    // Dictionnary
    string JOGO <- "jogo";
    string JCAI <- "caixa";
    string JEST <- "estacao";
    
    string AR <- "arreio";
    string ARNUM <- "name";
    string ARCUS <- "custo";
    
    string ES <- "estacaos";
    string ESNUM <- "numo";
    string ESDUR <- "duracao";
    string ESREP <- "reproducao";
    string ESDEN <- "densidade";
    string ESMIG <- "migracao";
    
    string PE <- "peixe";
    string PESP <- "especies";
    string PEST <- "estoque";
    string PVAL <- "valor";
    
    string PL <- "players";
    string PLID <- "id"; 
    string PLCOM <- "communidade"; 
    string PLFAM <- "fam";
    
    string LU <- "lugares";
    string LUNOM <- "name"; 
	string LUMIG <- "migracao";
	string LUCON <- "connexao";
	string LUCOM <- "communidade";
	string LUIMI <- "imigracao";
	
	PescaViva leer_o_jogo(game_manager gmanager, string filepath <- ojogofile) {
		
		create PescaViva returns:pvs { gm <- gmanager; gm.pv <- self; }
		PescaViva pv <- first(pvs);
		
		map<string, unknown> c <- json_file(filepath).contents;
		jogo <- map(c[JOGO]);
		pv.estacao <- get_season(jogo[JEST]);
		
		loop arr over:list(c[AR]) {
			map a <- map(arr);
			pv.arreios_modelo[a[ARNUM]] <- int(a[ARCUS]);
		}
		
		loop esp over:list(c[ES]) {
			map e <- map(esp);
			string es <- e[ESNUM]; 
			pv.ESTACAOS <+ get_season(es);
			pv.estacao_densidade[es] <- float(e[ESDEN]);
			pv.estacao_duracao[es] <- int(e[ESDUR]);
			if e contains_key ESREP { pv.estacao_reproducao[es] <- int(e[ESREP]); }
			if e contains_key ESMIG { pv.estacao_migracao[es] <- int(e[ESMIG]); }  
		}
		
		ask pv.gm {pv.p <- list<pescador>(create_pescadores(list(c[PL])));}
		ask pv.gm {pv.f <- list<peixe>(create_peixe(list(c[PE])));}
		ask pv.gm {pv.l <- list<lugar>(create_lugares(list(c[LU])));}

		

		return pv;
	}
	
}

