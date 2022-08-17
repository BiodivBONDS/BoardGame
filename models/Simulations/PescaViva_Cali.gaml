/**
* Name: Cali
* Based on the internal empty template. 
* Author: kevinchapuis
* Tags: 
*/

model Cali

import "../Game.gaml"
import "../Jogo.gaml"

/**
 * TODO : add predators
 * TODO : add detrimental effect of miquera on reproductions
 * TODO : add detrimental impact of fishing effort on next imigration
 */
global {
	
	PescaViva pv;
	
	bool TEST <- true parameter:true;
	string session_name <- TEST?"SESSION_TEST":"Sessions/"+date(#now).year
		+"-"+(date(#now).month<10?"0"+date(#now).month:date(#now).month)
		+"-"+(date(#now).day<10?"0"+date(#now).day:date(#now).day);
	string fp;
	
	//=============================
	// UI
	
	geometry shape <- rectangle(1394,862);
	image_file inv_img <- image_file("../includes/img/PV_inverno.jpeg");
	image_file ver_img <- image_file("../includes/img/PV_verao.jpeg");
	
	image_file peiL <- image_file("../includes/img/bolaBranca.png"); image_file peiLB <- image_file("../includes/img/bolaAmarela.png");
	image_file peiE <- image_file("../includes/img/bolaVerdeEscura.png"); image_file peiEB <- image_file("../includes/img/bolaVerdeClara.png");
	image_file preP <- image_file("../includes/img/bolaVermelha.png"); image_file preJ <- image_file("../includes/img/bolaPreta.png");
	image_file preB <- image_file("../includes/img/boto.png");
	
	point _loc_enseada <- {180,110}; point _loc_rio <- {730,130}; point _loc_igarape <- {60,480}; point _loc_poco <- {580,570}; point _loc_lago <- {1120,550};
	map loclug <- [_loc_enseada::ENSEADA,_loc_rio::RIO,_loc_igarape::IGARAPE,_loc_poco::POCO,_loc_lago::LAGO];
	
	//=============================
	// PARAM DE MAO - TODO move to a better parameter place
	
	// CODE FOR SESSION RECORD FILE
	string ANO <- "Ano"; string COM <- "C"; string EST <- "Rodada"; 
	string LUG <- "Lugar"; string MAT <- "Arreio";
	
	// List of fish to fish in order of input
	list<peixe> __FISH_CATCH_HEADER;
	
	// Fishing location
	string Rio <- "R"; string Lago <- "L"; string Poco <- "P"; string Enseada <- "E"; string Igarape <- "I";
	map<string,simple_lugar> lugar_reader;
	
	// Gears
	string Miqueira <- "I"; string Malhadeira <- "A"; string Tarrafa <- "T";  
	
	// Predators
	string JAK <- "J"; string PIR <- "P"; string BOT <- "B"; 
	map<string,predador> predator_reader; 
	
	// CATCHABILITY OF GEARS
	int miqmu <- 25; int miqsigma <- 9;
	int maimu <- 20; int maisigma <- 5;
	int tarmu <- 9; int tarsigma <- 2;
	
	// PREDATORS
	map<simple_lugar,map<predador,int>> predalugar;
	
	// ECONOMY
	map<pescador,map<lugar,int>> cost <- [];
	map<string,map<peixe,int>> precos <- [];
	
	// BLANK BALLS MADE "PETIT POIS"
	map<simple_lugar,map<string,int>> ervilha <- []; 
	float ervilhas_para_brancas <- 3.0;
	
	// DEFES : TODO turn it into a season
	int rodade_de_defeso <- 3;
	
	peixe br; // peixe that represents blank balls

	//=============================
	// OUTPUT
	list<map<simple_pescador,map<peixe,int>>> peixe_por_ano <- [];
	list<map<simple_lugar,map<peixe,int>>> peixe_por_lugar <- [];

	//=============================
	
	float peixe_reproducao parameter:true init:0.2 min:0.01 max:0.5;
	
	// ============================
	// Initialization of the game
	//
	init {
		
		lcodes <- [Rio::RIO,Lago::LAGO,Poco::POCO,Enseada::ENSEADA,Igarape::IGARAPE];
		acodes <- [Miqueira::MIQUEIRA,Malhadeira::MALHADEIRA,Tarrafa::TARRAFA];
		
		// Create the game
		create simple_gm returns:ams;
		pv <- leer_o_jogo(first(ams));
		
		// Create TODO use jogo to build this with simple rule (1 for direct access - n for others)
		cost <- [
			simple_pescador[0]::[lugar_reader[Rio]::2,lugar_reader[Enseada]::1,lugar_reader[Lago]::2,lugar_reader[Poco]::2,lugar_reader[Igarape]::2],
			simple_pescador[1]::[lugar_reader[Rio]::2,lugar_reader[Enseada]::2,lugar_reader[Lago]::2,lugar_reader[Poco]::2,lugar_reader[Igarape]::1],
			simple_pescador[2]::[lugar_reader[Rio]::2,lugar_reader[Enseada]::2,lugar_reader[Lago]::1,lugar_reader[Poco]::2,lugar_reader[Igarape]::2],
			simple_pescador[3]::[lugar_reader[Rio]::2,lugar_reader[Enseada]::2,lugar_reader[Lago]::1,lugar_reader[Poco]::2,lugar_reader[Igarape]::2]
		];
		// Create TODO blank balls
		ervilha <- [
			lugar_reader[Rio]::[INVERNO::900,VERAO::600,DEFESO::600], 
			lugar_reader[Enseada]::[INVERNO::750,VERAO::375,DEFESO::375], 
			lugar_reader[Lago]::[INVERNO::900,VERAO::450,DEFESO::450], 
			lugar_reader[Poco]::[INVERNO::450,VERAO::150,DEFESO::150], 
			lugar_reader[Igarape]::[INVERNO::300,VERAO::150,DEFESO::150] 
		];
		
		// Create TODO precos
		precos <- [
			MIQUEIRA::[simple_peixe[0]::2,simple_peixe[1]::4,simple_peixe[2]::1,simple_peixe[3]::2],
			MALHADEIRA::[simple_peixe[0]::4,simple_peixe[1]::8,simple_peixe[2]::2,simple_peixe[3]::4],
			TARRAFA::[simple_peixe[0]::4,simple_peixe[1]::8,simple_peixe[2]::2,simple_peixe[3]::4]
		];
		// Create TODO predadores
		predalugar <- [
			lugar_reader[Rio]::[predator_reader[JAK]::0,predator_reader[PIR]::0,predator_reader[BOT]::1],
			lugar_reader[Enseada]::[predator_reader[JAK]::0,predator_reader[PIR]::1,predator_reader[BOT]::0],
			lugar_reader[Lago]::[predator_reader[JAK]::1,predator_reader[PIR]::1,predator_reader[BOT]::0],
			lugar_reader[Poco]::[predator_reader[JAK]::1,predator_reader[PIR]::1,predator_reader[BOT]::0],
			lugar_reader[Igarape]::[predator_reader[JAK]::0,predator_reader[PIR]::0,predator_reader[BOT]::0]
		];
		
		__FISH_CATCH_HEADER <- [simple_peixe[0],simple_peixe[1],simple_peixe[2],simple_peixe[3]];
		
		// Create fishing files
		fp <- "../../includes/"+session_name+".csv";
		if not(file_exists(fp)) { do create_new_session_file(fp); }
		
		do init_fishing_stock;
	}
	
	// ============================
	// Game dynamic
	
	bool SYSO <- false;
	
	reflex dyn { 
		if SYSO {
			write ANO+pv.ano+" "+pv.estacao;
			loop sl over:simple_lugar { loop sp over:simple_peixe { write sl.name+"|"+sp.name+" = "+sl._estoque[sp]; } }
		}
	}
	
	// ============================
	// FILES OF PLAYERS

	/**
	 * Read a session action by action
	 */
	action read_new_action_sheet(string filepath) {
		matrix m <- matrix(csv_file(filepath));
		loop line from:0 to:m.rows-1 {
			// Validate the line
			bool validated_line <- true;
			string com <- string(m[0,line]) replace (COM,"");
			// ----- Community and year are numbers 
			validated_line <- not(empty(com)) and is_number(com) and is_number(string(m[1,line]));
			// ----- There is a fishing place and a gear
			loop i from:2 to:4 {validated_line <- validated_line and not(empty(m[i,line]) or m[i,line]=nil); write "Entry "+i+" is "+m[i,line];}
			if validated_line {
				// write "Line number "+line+" has been validated with content:";
				int c <- int(com);
				int a <- int(m[1,line]);
				string r <- get_season(m[2,line]); 
				simple_lugar lgr <- simple_lugar first_with (each.name=get_place(m[3,line]));
				string mat <- get_gear(m[4,line]); 
				write "\t"+m[0,line]+" fished in "+lgr.name+" with "+mat;
				
				map<peixe,int> ctch <- []; 
				list<predador> prddr <- [];
				map<peixe,int> prcatch <- []; 
				// Read The catch
				list<string> app <- range(5,4+length(__FISH_CATCH_HEADER)) collect (m[each,line]);
				loop fci from:0 to:length(app)-1 {
					string fc <- app[fci];
					if fc != nil and int(first(fc)) != 0 {
						peixe yp <- __FISH_CATCH_HEADER[fci]; // Read peixe
					
						bool jak <- fc contains JAK;
						bool pir <- fc contains PIR;
						bool bot <- fc contains BOT;
						list<string> cpp <- fc split_with (JAK+PIR+BOT, true); // Read predators if any
						
						ctch[yp] <- int(cpp[0]); // Extract non predator catch
						write "\t--- "+yp.name+" >> "+ctch[yp];
						if length(cpp)=2 {
							prddr <+ jak ? predator_reader[JAK] : (pir ? predator_reader[PIR] : predator_reader[BOT]);
							prcatch[yp] <- int(cpp[1]);
							write "\t--- "+last(prddr).name+" <<- "+prcatch[yp];
						} else if length(cpp)>2 {
							map<int,predador> pidx <- [];
							if jak { pidx[fc index_of JAK] <- predator_reader[JAK]; }
							if pir { pidx[fc index_of PIR] <- predator_reader[PIR]; } 
							if bot { pidx[fc index_of BOT] <- predator_reader[BOT]; }
							int idp <- 1;
							loop pi over:pidx.keys sort each { 
								prddr <+ pidx[pi];
								if not( prcatch contains_key yp) {prcatch[yp] <- 0;} 
								prcatch[yp] <- prcatch[yp] + int(cpp[idp]); 
								idp <- idp+1;
							}
							loop pc over:prcatch.keys { write "\t--- "+pc.name+" <<- "+prcatch[pc]; }
						}
						
					}	
				}
				ask simple_pescador[c-1] { do store_action(a,r,lgr,mat,ctch,prddr,prcatch); } // Store action as potential default 
			}
		}
	}
	
	/**
	 * 
	 * Create a file associated to a session
	 * 
	 */
	action create_new_session_file(string file_path) {
		// HEADER
		save [COM,ANO,EST,LUG,MAT]+list(simple_peixe collect (each.name)) to:file_path type:csv header:false rewrite:true;
		// 3 line per community per season for the First year
		loop e over:pv.ESTACAOS { loop c over:simple_pescador { loop times:3 { save [COM+c.comm,1,e]+list_with(2+length(simple_peixe),"") to:file_path type:csv rewrite:false; } } }
		
	}
	
	// ===================================================
	
	/*
	 * init fish stocks for each species and each location
	 */
	action init_fishing_stock {
		// Fish stock
		loop p over:simple_peixe {
			float total_ambiante <- sum(simple_lugar collect each._ambiante_peixe);
			loop l over:simple_lugar {
				l._estoque[p] <- p.estoque * l._ambiante_peixe / total_ambiante;
			}
		}
		
		// Predator
		loop lug over:simple_lugar {lug._preds <<+ predalugar[lug];}
	}
	
}

/*
 * manage init of the game and start/end of game turn
 */
species simple_gm parent:game_manager {
	
	// Create 1 fisherman per communidade
	container<simple_pescador> create_pescadores(list args) {
		loop plm over:args {
			map p <- map(plm);
			create simple_pescador with:[comm::int(p[PLCOM]),tamanho::int(p[PLFAM]),caixa::int(jogo[JCAI])];
		}
		return simple_pescador;
	}
	
	// Create stock of fish
	container<simple_peixe> create_peixe(list args) {
		
		// Fake species of "water"
		create __branco; br <- last(__branco);
		loop preds over:[JAKARE,PIRANHA,BOTO] {
			create predador with:[name::preds] {if name=JAKARE {attak <- 100;}}
			predator_reader[upper_case(first(preds))] <- last(predador);
		}
		
		// Usual initialization
		loop pmod over:args {
			map v <- map(pmod);
			string n <- world.get_fish(v[PESP]); 
			int e <- int(v[PEST]);
			create simple_peixe with:[name::n,valor::float(v[PVAL]),estoque::e];
		}
		return simple_peixe;
	}
	
	container<simple_lugar> create_lugares(list args) {
		loop lug over:args {
			map l <- map(lug);
			create simple_lugar with:[
				name::world.get_place(l[LUNOM]),
				imigracao::int(l[LUIMI]),
				_ambiante_peixe::float(l[LUMIG]),
				_communidade_connexao::list<int>(l[LUCOM])
			];
			lugar_reader[upper_case(first(last(simple_lugar).name))] <- last(simple_lugar);
		}
		return simple_lugar;
	}
	
	action prepare_round { 
		ask simple_lugar {do nivel_de_agua;}
		ask simple_pescador { // Refresh tmp fishing amount 
			loop lgr over:simple_lugar { _pesca[lgr] <- []; 
				loop px over:simple_peixe { _pesca[lgr][px] <- 0; }
			}
		}
		ask world { do read_new_action_sheet(fp); }
	}
	
	action close_round {
		// Pay for the family, repair gears and store fishing pattern
		ask simple_pescador { do custo_fixo;}
		// Anual report
		do report_do_ano;
		// Next round
		ask pv {do atualizar_estacao;} 
		if pv.estacao = INVERNO {ask world {do pause;}}
	}
	
	// ===============
	// UTILS
	
	action report_do_ano {
		// Update catch for fisherman per year/species
		ask simple_pescador {
			// Compute seasonal catch
			map<simple_peixe,int> tp <- map<simple_peixe,int>([]); 
			loop px over:simple_peixe { 
				loop lg over:_pesca.keys { tp[px] <- tp[px]+_pesca[lg][px]; }
			} 
			// Create year catches
			if length(peixe_por_ano)<pv.ano { peixe_por_ano <+ map<simple_pescador,map<peixe,int>>([]);}
			// Add seasonal catch to year catch 
			if not(peixe_por_ano[pv.ano-1] contains_key self) { peixe_por_ano[pv.ano-1][self] <- tp; }
			else { loop sp over:tp.keys { peixe_por_ano[pv.ano-1][self][sp] <- peixe_por_ano[pv.ano-1][self][sp]+tp[sp]; } }
		}
		
		// Update stock for each location per year/species
		if pv.estacao = VERAO and pv.estacao_cycle = pv.estacao_duracao[pv.estacao] {
			peixe_por_lugar <+ simple_lugar as_map (each::each._estoque);
			
			write ANO+" "+pv.ano+" summary";
			map<simple_pescador,map<peixe,int>> pa <- last(peixe_por_ano);
			loop sp over:pa.keys { 
				write "C"+sp.comm+" => "+ 
					"E = "+pa[sp][simple_peixe[0]]+" | "+
					"Ev = "+pa[sp][simple_peixe[1]]+" | "+
					"L = "+pa[sp][simple_peixe[2]]+" | "+
					"Lv = "+pa[sp][simple_peixe[3]]+" | "+
					"Total = "+sum(pa[sp].values) color:[#darkblue,#crimson,#darkgreen,#saddlebrown][sp.comm-1];
			}
			write "\tNew stocks:";
			map<simple_lugar,map<peixe,int>> la <- last(peixe_por_lugar);
			loop lp over:la.keys { 
				write upper_case(first(lp.name))+" => "+ 
					"E = "+la[lp][simple_peixe[0]]+" | "+
					"Ev = "+la[lp][simple_peixe[1]]+" | "+
					"L = "+la[lp][simple_peixe[2]]+" | "+
					"Lv = "+la[lp][simple_peixe[3]]+" | "+
					"Total = "+sum(la[lp].values);
			}
			write "=================================\n";
		}
	}
} 

// ==============

/**
 * 
 * V0722
 * -----
 * Version of the pescador with both autonomous & human driven
 * 
 * 1. Retain input (latest) from human behavior to reproduce
 * 
 */
species simple_pescador parent:pescador {
	
	list<aPattern> current_actions;
	map<string,list<aPattern>> default_actions; 
	
	int __atual_catch;
		
	action pescar {
		
		list<aPattern> new_actions <- simple_lugar accumulate get_action(pv.ano,pv.estacao,each);
		if not(empty(new_actions)) { 
			current_actions <- new_actions;
			default_actions[pv.estacao] <- get_dAction(current_actions);
		} else { 
			current_actions <- default_actions[pv.estacao];
		} 
		if empty(current_actions) { error "There is no option of fully autonomous players for now"; }
		__atual_catch <- 0;
		
		// COST
		caixa <- caixa - sum(remove_duplicates(current_actions collect each.lug) collect (cost[self][each])) * pv.gazolin; 
		
		list<simple_mater> tmp_mater <- list<simple_mater>(material_de_pesca);
		loop ca over:current_actions {
			
			// Identify gear used
			simple_mater sm <- tmp_mater first_with (each.modelo=ca.mat);
			// If none available buy one
			if sm=nil { sm <- comprar_mater(ca.mat); material_de_pesca <+ sm; } else { tmp_mater >- sm; }
			
			simple_lugar sl <- simple_lugar(ca.lug);
			// If miquera lugar is deprecated
			if sm.modelo=MIQUEIRA {sl.miq_nb <- sl.miq_nb+1;}
			
			// Actual fish fished
			map<peixe,int> actual_fish;
			// Actual fish eaten by predators
			map<peixe,int> actual_Pfish;
			
			// CATCH IS UNKONWN
			if empty(ca.catches) {
				
				// actual fish fished
				actual_fish <- _autonomous_fishing(sl,sm.efforte()); // WARNING : SIDE EFFECT OF ACTUAL STOCK DIMINUTION
				// filter predador
				map<peixe,int> pf <- actual_fish.keys where (each is predador) as_map (each::actual_fish[each]);
				// Remove them from the fishes
				loop pr over:pf.keys { actual_fish[] >- pr; }
				// Make them eat fish and destroy gears
				loop pr over:pf.keys {
					map<peixe,int> predf <- predador(pr).comer_peixe(actual_fish);
					loop px over:predf.keys { 
						actual_Pfish[px] <- actual_Pfish contains_key px ? actual_Pfish[px]+predf[px] : predf[px]; 
						actual_fish[px] <- actual_fish[px] - predf[px];
					}
					sm <- predador(pr).danificar(sm);
				}
				
			// CATCH HAS BEEN MADE BY PLAYER
			} else { 
				
				// Actual fish killed
				actual_fish <- ca.catches;
				loop af over:actual_fish.keys { sl._estoque[af] <- sl._estoque[af] - actual_fish[af]; }
				
				// Predator hit the gears
				loop prddr over:ca.pr { sm <- prddr.danificar(sm); }
				
				// Predators eating fishes of fishermen
				actual_Pfish <- ca.predador;
				loop px over:actual_Pfish.keys { actual_fish[px] <- actual_fish[px] - actual_Pfish[px]; }
				
			}
			
			// sell fish and store information
			loop ff over:actual_fish.keys {
				// Sell the fish
				caixa <- caixa + precos[sm.modelo][ff];
				// Store the result for this rodade
				__atual_catch <- __atual_catch+1;
				// Store the global result
				_pesca[sl][ff] <- _pesca[sl][ff] + actual_fish[ff];
			}
			
		}
		
	}
	
	// ======================
	// Action from players
	
	/*
	 * Fish
	 */
	map<peixe,int> _autonomous_fishing(simple_lugar lug, int effort) {
		map<peixe,int> res <- [];
		map<predador,int> localPreds <- lug._preds; 
		loop times:effort { 
			// actually draw balls one by one WITHOUT replacement || TODO : change to draw one shot
			map<peixe,int> ec <- copy(lug._estoque);
			ec[br] <- lug._branco;
			// introduce predators
			loop pred over:localPreds.keys { if localPreds[pred]>0 {ec[pred] <- localPreds[pred];} }
			// Draw a ball
			peixe d <- rnd_choice(ec);
			if d!=br {
				if d is predador {
					predador pp <- predador(d); 
					// Count the number of predator remaining 
					localPreds[pp] <- localPreds[predador(d)]-1;
					if not(res contains_key pp) { res[pp] <- 0; }
					res[pp] <- res[pp]+1;
				} else {
					// Reduce the stock
					lug._estoque[d] <- lug._estoque[d]-1;
					if lug._estoque[d] < 0 {error "Pescador should not be able to fish negative stock of "+sample(d);}
					if not(res contains_key d) {res[d] <- 0;}
					// Tmp store fish catched
					res[d] <- res[d]+1;
				}
			}
		}
		return res;
	}
	
	// =======================
	// Economic stuff
	
	// Buy fishing gear
	simple_mater comprar_mater(string modelo) { 
		create simple_mater with:[modelo::world.get_gear(modelo)] returns:sms;
		caixa <- caixa - pv.arreios_modelo[modelo];
		material_de_pesca <+ first(sms); 
		return first(sms);
	}
	
	/**
	 * Fix cost of fisherman
	 */
	action custo_fixo { 
		// Family
		caixa <- caixa - tamanho; 

		//if pv._defesar { caixa <- caixa - sum(material_de_pesca collect (flip(0.2)?each.reparar:0));}
		int repair_mater;
		list<mater> mat_broken;
		loop mt over:material_de_pesca {
			simple_mater sm <- simple_mater(mt);
			if sm.danifica > 10 { mat_broken <+ sm; } 
			else { repair_mater <- repair_mater + sm.danifica * sm.reparar; sm.danifica <- 0; }
		}
		loop mt over:mat_broken { material_de_pesca >- mt; ask mt {do die;} }
		caixa <- caixa - repair_mater;
	}
	
	// ===============
	// Fishing patterns
	
	/**
	 * Filter actions per year, season and place
	 */
	list<aPattern> get_action(int year, string season, lugar place) {
		return aPattern where (each.ano=year and each.aestacao=season and each.lug=place);
	}

	/**
	 * Build default action pattern from a list of action made by players
	 */
	list<aPattern> get_dAction(list<aPattern> pActions) {
		list<aPattern> dacts; 
		loop pa over:pActions { create aPattern with:[aestacao::pa.aestacao,lug::pa.lug,mat::pa.mat]; dacts <+ last(aPattern); }
		return dacts;
	}
	
	/**
	 * Store a single action as a pattern
	 */
	action store_action(int a, string e, simple_lugar l, string m, 
		map<peixe,int> c, list<predador> p <- [], map<peixe,int> prey <- []
	) {
		if aPattern none_matches (each.ano=a and each.aestacao=e and each.lug=l and each.mat=m) {
			create aPattern with:[ano::a,aestacao::e,lug::l,mat::m,catches::c,pr::p,predador::prey];
		}
	}
	
	/*
	 * A pattern for a fishing action
	 */
	species aPattern {
		int ano; string aestacao; lugar lug; string mat;
		map<peixe,int> catches;
		list<predador> pr;
		map<peixe,int> predador;
	}
	
}

// Special lugar V0722
species simple_lugar parent:lugar {
	
	map<predador,int> _preds;
	
	init { __rep_ratio <- peixe_reproducao; }
	
	/**
	 * 
	 * << DEPRECATED >>
	 * 
	 * Reproduction of fish in each lugar
	 * 
	 */
	action reproducao { 
		int N <- sum(_estoque.values);
		loop f over:_estoque.keys {
			float ar <- world.log_population(N,_branco,f.r,_estoque[f]*1.0/N);
			if ar < 0 {error f.name + " in "+self.name+"(estoque="+_estoque[f]+") is having a negative reproduction ("+ar+") ";}
			_estoque[f] <- _estoque[f] + int(ar) + (flip(ar-int(ar))?1:0);
		}
	}
	
	/*
	 * Level of water according to season of the year
	 */
	action nivel_de_agua { _branco <- round(ervilha[self][pv.estacao] / (ln(1+ervilha[self][pv.estacao]) / ervilhas_para_brancas)); }
	
	/*
	 * Degradation of the lugar due to the use of miquera
	 */
	int miq_nb;
	float _recov <- 0.2;
	action renovacao { 
		__rep_ratio <- min(peixe_reproducao,__rep_ratio*1.1); 
		__imqualidade <- miq_nb=0?1.0:min(1.0, max(0.0,__imqualidade+__imqualidade*(_recov-0.1*miq_nb))); 
		miq_nb <- 0;
	}
}

/**  
 * == Special species of fish for V0722 ==
 * 
 * 1. simple peixe is simply generic peixe
 * 2. __branco is a fake version of blank balls of V0322 (to simulate binomial fishing)
 * 3. predador are specific fishing entity that eat peixe and cut gears
 * 
 */
species simple_peixe parent:peixe { init {r <- peixe_reproducao;} } 
species __branco parent:peixe {}
species predador parent:peixe { 
	int attak <- 1;
	int eat <- -1;
	
	map<peixe,int> comer_peixe(map<peixe,int> pesc) {
		map<peixe,int> res <- [];
		map<peixe,int> lotery <- copy(pesc);
		loop times: eat<0 ? int(sum(pesc.values)/2.0) : eat {
			peixe pd <- rnd_choice(lotery);
			lotery[pd] <- lotery[pd]-1;
			res[pd] <- res contains_key pd ? res[pd]+1 : 1;
		}
		return res;
	}
	
	simple_mater danificar(simple_mater m) { m.danifica <- m.danifica+attak; return m; }
}

// Special version of fishing gear with mean/std fish
species simple_mater parent:mater {
	int danifica;
	init {
		switch modelo { 
 			match MIQUEIRA {capacidade <- [miqmu,miqsigma];}
 			match MALHADEIRA {capacidade <- [maimu,maisigma];}
 			match TARRAFA {capacidade <- [tarmu,tarsigma];}
 		}
 		reparar <- MIQUEIRA=modelo?2:(MALHADEIRA=modelo?1:0);
 	}
}

// ==============

experiment pvxp type:gui virtual:true {
	list<rgb> commu_colors <- [#darkblue,#crimson,#darkgreen,#saddlebrown];
	list<rgb> peixe_colors <- [#darkgreen,#lightgreen,#white,#gold];
}

experiment session type:gui parent:pvxp {
	
	output {
		display peixe_stocks toolbar: false {
			chart "fish population per species" type: series background: rgb(47,47,47) color: #white 
					x_serie_labels:("A"+pv.ano+(pv.__mig?" mig":(pv.__rep?" rep":""))) {
				loop p over:simple_peixe { data p.name value:sum(simple_lugar collect (each._estoque[p]))/*1.0/p.estoque*/ color:peixe_colors[int(p)]; }
				data "all" value:sum(simple_lugar collect (sum(each._estoque.values)))/*1.0/sum(simple_peixe collect (each.estoque))*/ color:#red;
			}
		}
		display lugar_stocks toolbar: false {
			chart "fish population per fishing spot" type: series background: rgb(47,47,47) color: #white
					x_serie_labels:("A"+pv.ano+(pv.__mig?" mig":(pv.__rep?" rep":""))) {
				if cycle mod 3 = 0 {
					loop l over:simple_lugar { data l.name value:sum(l._estoque.values); }
				}
			}
		}
		
		display pescador toolbar: false {
			chart "peixes" type: series style:line background: rgb(47,47,47) color: #white x_serie_labels:"ano"+(pv.ano) {
				loop p over:simple_pescador { 
					data "C"+p.comm+"p" value:p.__atual_catch marker_shape:marker_diamond color:commu_colors[p.comm-1]; // CATCH
				}
			}
		}
		
		display pescador_caixa toolbar:false {
			chart "caixas" type: series style:line background: rgb(47,47,47) color: #white x_serie_labels:"ano"+(pv.ano) {
				loop p over:simple_pescador {
					data "C"+p.comm+"p" value:p.caixa color:commu_colors[p.comm-1]; // CAIXA
				}
			}
		}
	}
}

experiment PVSim type:gui parent:pvxp {
	output synchronized:true {
		display tabuler toolbar: false {
			image pv.estacao=first(pv.ESTACAOS)?inv_img:ver_img;
			graphics lugpesc {
				loop lg over:[_loc_enseada,_loc_rio,_loc_igarape,_loc_poco,_loc_lago]{
					simple_lugar sl <- simple_lugar first_with (each.name=loclug[lg]);  
					loop sp over:simple_pescador { 
						list<image_file> afish <- [];
						loop pp over:sp._pesca[sl].keys { 
							image_file img <- pp.name contains ESCAMA?(pp.name contains VALIOSO?peiEB:peiE) : (pp.name contains VALIOSO?peiLB:peiL);
							afish <<+ list_with(sp._pesca[sl][pp],img);
						}
						draw "C"+sp.comm at:lg+{0,(int(sp))*50} font:font("Times", 30, #plain) color:blend(commu_colors[int(sp)],#transparent,empty(afish)?0.3:1.0);
						loop imgidx from:0 to:length(afish)-1 { draw afish[imgidx] size:{40,40} at:lg+{20+(1+imgidx)*50,(int(sp))*50-15}; }
					}
				}
			}
		}
	}
}