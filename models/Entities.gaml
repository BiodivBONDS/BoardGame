/**
* Name: Entities
* Based on the internal empty template. 
* Author: kevinchapuis
* Tags: 
*/


model Entities

import "Game.gaml"

global {
	
	string RIO <- "Rio";
	string LAGO <- "Lago";
	string POCO <- "Poco";
	string ENSEADA <- "Enseada";
	string IGARAPE <- "Igarapé";
	
	string JAKARE <- "Jakare";
	string PIRANHA <- "Piranha";
	string BOTO <- "Boto";
	
	string MIQUERA <- "Miquera";
	string MALHADERA <- "Malhadera";
	string TARRAFA <- "Tarrafa";
	
	string LISO <- "Liso";
	string ESCAMA <- "Escama";
	string VALOROSO <- "Valoroso";
	
	string GELEROS <- "Geleros";
	
	// ------------------------------------------ //
	// String contract representation of entities //
	// ------------------------------------------ // 
	
	// Return proper string form of any fishing spot
	string get_place(string in, list<string> places <- [RIO,LAGO,POCO,ENSEADA,IGARAPE]) {
		string pro <- __proper_string_representation(in,places);
		if pro=nil {error in+" cannot be link to any known places: "+places;}
		return pro;
	}
	
	// Return proper string form of any fishing gear
	string get_gear(string in, list<string> gears <- [MIQUERA,MALHADERA,TARRAFA]) {
		string pro <- __proper_string_representation(in,gears);
		if pro=nil {error in+" is not one of the recorded gears in "+gears;}
		return pro;
	}
	
	// Return proper string representation of fish species
	string get_fish(string in, list<string> fishes <- [LISO,ESCAMA]) {
		string pro <- "";
		
		list<string> species_valor <- in split_with " ";
		if length(species_valor)=1 { 
			loop f over:fishes { if lower_case(species_valor[0])=lower_case(f) {pro <- f;} }
			if not(empty(pro)) {return pro;}
			else {
				bool m <- false;
				loop f over:fishes { if length(lower_case(in) regex_matches lower_case(f))=1 { species_valor[0] <- f; m <- true;} }
				if m { species_valor[1] <- lower_case(in) replace_regex (lower_case(species_valor[0]),""); } 
				else {error in+" cannot be link to any known fish species "+fishes;} 
			}
		}
		pro <- __proper_string_representation(species_valor[0],fishes);
		
		string valor <- species_valor[1] replace_regex (" ","");
		valor <- __proper_string_representation(valor,[VALOROSO,"Brilhante"]);
		pro <- pro + ([VALOROSO,"Brilhante"] contains valor ? " "+VALOROSO : "");
		
		return pro;
	}
	
}

/*
 * Main agent of the game: fishermen
 */
species pescador virtual:true {
	int comm;
	int tamanho;
	int caixa; 
	
	map<lugar,map<peixe,int>> _pesca;
	list<mater> material_de_pesca;
	
	action pescar virtual:true; // the action to fish - kind of reflex for fishing
	action custo_fixo virtual:true; // the action of pay for fix cost (familly, repair, etc.)
	
}

/*
 * Main entity of the environment: fishing spots
 */
species lugar virtual:true {
	list<int> _communidade_connexao;
	
	map<peixe,int> _estoque;
	int _branco;
	
	float _ambiante_peixe;
	float __rep_ratio <- 0.3;
	
	float __imqualidade;
	int imigracao;
	
	action reproducao virtual:true;
	action renovacao virtual:true;
}

/*
 * Tools used by fisherman to catch fish
 */
species mater virtual:true {
	string modelo;
	
	int reparar;
	int velado;
	
	list<int> capacidade; // gauss= 0:mu ; 1:sigma
	int efforte { return min(capacidade[0]+capacidade[1], max(1, round(gauss(capacidade[0],capacidade[1])))); }
}

/*
 * Fish species - to monitor full stock and attached behavior to stocks 
 */
species peixe virtual:true {
	int estoque;
	string modelo;
	float r;
	float valor <- 1.0;
}

