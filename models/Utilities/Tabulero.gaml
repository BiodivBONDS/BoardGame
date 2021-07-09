/**
* Name: Tabulero
* Based on the internal empty template. 
* Author: kevinchapuis
* Tags: 
*/


model Tabulero

import "../Entities/Pescador.gaml"

global {
	
	// LAGOS
	// TODO : turn this into attibutes of the shapefile features
	// like 'type' and 'id' but with 'size', 'stocks' and 'connections'
	list<pair<int,int>> init_lagos <- [(20::100),(10::40),(20::100),(15::60)];
	list<pair<string,string>> init_paranas <- [
		(string(rio)::"L1"),("L1"::"L2"),("L2"::"L3"),(string(rio)::"L3"),("L3"::"L4")
	];
	
	// BAIXAO MANAGEMENT
	string regular <- "Regular";
	string regular_baixao <- "Regular baixao";
	string rio_baixao <- "Rio baixao";
	map<string,float> lugar_weights <- [regular::0.5,regular_baixao::1.0,rio_baixao::2.0];
	
	// GIS-like GAME BOARD
	string feature_type_attribute <- "type";
	string feature_id_attribute <- "id";
	string feature_char_attribute <- "att";
	
	// ---------------------------------------------------------- //
	// MAIN ACTIONS TO BUILD A TABULERO
	
	/*
	 * Read a shapefile and turn it into a game board considering few rules:
	 * <ul>
	 * <i> Each feature should have a 'type' attribute among [RIO,FOREST,GRASS,WATER,CHANNEL,COMMUNITY,LAND]
	 * <i> Each feature should have an 'id' (used for lakes to have several layer according to dry/wet seasons)
	 * </ul>
	 */
	action build_tabulero_species(shape_file gameboard) {
		list<string> coms <- [];
		loop geom over:gameboard.contents {
			string t <- geom.attributes[feature_type_attribute];
			string id <- geom.attributes[feature_id_attribute];
			switch t {
				match rio_type {create rio with:[shape::geom,id::"R"];}
				match lago_type {
					string short_id <- copy_between(id,0,2);
					string season_id <- copy_between(id,2,3);
					if lago none_matches (each.id = short_id) { create lago with:[id::short_id]; }
					lago cl <- lago first_with (each.id = short_id);
					switch season_id { 
						match "H" {cl.season_shapes[HIGH_WATER_SEASON] <+ geom;} 
						match_one ["M","L"] {cl.season_shapes[LOW_WATER_SEASON] <+ geom;}
					}
				}
				match parana_type {create parana with:[shape::geom,id::id];}
				match forest_type {create forest with:[shape::geom];}
				match pasto_type {create pasto with:[shape::geom];}
				match comunidade_type {
					string num <- copy_between(id,0,2);
					if not (coms contains num) { coms <+ num; create comunidade with:[id::num];}
					comunidade my_com <- comunidade first_with (each.id = num);
					create pescador with:[comu::my_com,homeplace::geom,location::any_location_in(geom)];
					my_com.pescadores <+ last(pescador);
				}	
			}
		}
		
		ask lago { shape <- union(season_shapes[LOW_WATER_SEASON] collect (each+0.1));}
		
		// Connect the lakes
		loop p over:parana { do connect_lakes(p);}
		// Assigne values to lakes
		loop l over:lago {do build_lakes(l);}
	}
	
	/*
	 * Built a simple environment based on parameters values
	 */
	action build_tabulero_from_scratsh(list<pair<int,int>> lagos <-  init_lagos, list<pair<string,string>> paranas <- init_paranas) {
		create rio with:[id::"R"];
		create lago number:length(lagos) {id <- "L"+int(self);}
		loop pp over:init_paranas {
			create parana;
			do connect_lakes(last(parana),[list(lago + rio) first_with (each.id = pp.key),list(lago + rio) first_with (each.id = pp.value)]);
		}
		int lidx <- 0;
		loop lago_shape over:shape to_triangles length(lagos) {
			lago[lidx].shape <- circle(lagos[lidx].key, lago_shape.centroid);
			do build_lakes(lago[lidx],false,lagos[lidx].key,DEFAULT_SIZE_LUGAR_DE_PESCA,float(lagos[lidx].value));
		}
		point com_location;
		float scale <- world.shape.width/10;
		loop times:nb_comunidades {
			lago com_lago <- any(lago);
			com_location <- any_location_in (com_lago.shape buffer (scale) - com_lago.shape);
			do create_comunidade(
				rectangle(point(com_location.x-rnd(scale),com_location.y-rnd(scale)),point(com_location.x+rnd(scale),com_location.y+rnd(scale)))
			);
		}
		
	}
	
	// ----------------------
	// UTIL ACTIONS
	
		
	/*
	 * Create comunidades from scratch
	 */
	action create_comunidade(geometry geom, int pescador_nb <- rnd(1,5)) {
		create comunidade with:[shape::geom]{
			create pescador number:pescador_nb with:[comu::self,homeplace::any_location_in(geom)] returns:pescs;
			pescadores <- pescs;
		}
	}
	
	/*
	 * Connect the para with two water bodies (i.e. first and last of wbodies)
	 */
	parana connect_lakes(parana para, list<water_body> wbodies <- nil) {
		water_body o;
		water_body d;
		
		if wbodies = nil or empty(wbodies) {
			string ori <- first(para.id) = "R" ? string(rio) : copy_between(para.id,0,2);
			string dest <- last(para.id) = "R" ? string(rio) : copy_between(para.id,length(para.id)-2,length(para.id));
			// Set channel's origin
			if ori=string(rio) { o <- first(rio); }
			else { o <- lago first_with (each.id = ori); }
			// Set channel's destination
			if dest=string(rio) { d <- first(rio); }
			else { d <- lago first_with (each.id = dest); }
		} else {
			if length(wbodies) < 1 { error "The should be at least 2 water body to connect";}
			o <- first(wbodies);
			d <- last(wbodies);
		}
		
		para.origin <- o; if o is lago {lago(o).paranas <+ para;}
		para.destination <- d; if d is lago {lago(d).paranas <+ para;}

		return para;
	}
	
	/*
	 * Populate lakes with their attributes
	 */
	lago build_lakes(lago lake, bool baixao <- true, int size <- -1, 
		int fish_spot_size <- DEFAULT_SIZE_LUGAR_DE_PESCA, float stock <- -1
	) {
			
		// Compute lac size and fish stock
		lake.extencao <- size=-1?init_lagos[int(last(lake.id))-1].key:size;
		lake.estoque <- stock=-1?float(init_lagos[int(last(lake.id))-1].value):stock;
		fish_stock_cache[cycle] <- fish_stock_cache[cycle]+lake.estoque; 
		
		int nb_lugares <- int(lake.extencao/fish_spot_size);
		
		// Area for baixao
		list<geometry> baixao_de_pesca <- [];
		if baixao {
			loop baixao_parana over:lake.paranas collect (each.shape + 2) {
				geometry g <- shape inter baixao_parana;
				baixao_de_pesca <+ last(g.geometries sort (each.area));
			}
		}
		
		// Area of regular lugares de pesca
		list<geometry> lugares_de_pesca <- (shape - baixao_de_pesca) 
			to_sub_geometries list_with(nb_lugares,round(lake.shape.area)/lake.extencao*fish_spot_size);
		lugares_de_pesca <- lugares_de_pesca collect union(each.geometries where (each.area > 0));
		
		// Regular fishing spot
		int lid <- 1;
		create lugar_de_pesca number:nb_lugares with:[localisacao::lake] {
			extencao <- int((lake.extencao - length(baixao_de_pesca)) / nb_lugares);
			name <- lake.id+lid;
			lid <- lid+1;
			shape <- any(lugares_de_pesca);
			lugares_de_pesca >- shape;
			lake.lugares <+ self::lugar_weights[regular];
		}
		
		if baixao {
			map<parana,float> parana_weights <- lake.paranas as_map (each::([each.origin,each.destination] contains first(rio)) ? 
				lugar_weights[rio_baixao] : lugar_weights[regular_baixao]
			);
			
			// Create baixoa
			ask lake.paranas {
				geometry the_area <- baixao_de_pesca closest_to self;
				create lugar_de_pesca with:[shape::the_area,localisacao::lake] returns:lps;
				first(lps).name <- lake.id+(self.origin=lake?self.destination.id:self.origin.id);
				lake.lugares <+ first(lps)::nb_lugares * parana_weights[self] / sum(parana_weights.values);
			}
			
		}
		
		ask lake.lugares.keys { estoque <- lake.estoque_de_lugar(self); extencao <- 1; }
		
		return lake;
	}
	
}