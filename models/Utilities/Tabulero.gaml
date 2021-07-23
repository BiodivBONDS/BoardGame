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
		("R"::"L1"),("L1"::"L2"),("L2"::"L3"),("R"::"L3"),("L3"::"L4")
	];
	map<string,int> init_comunidades <- ["L1"::2,"L2"::1,"L3"::2,"L4"::1];
	
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
					if lago none_matches (each.id = short_id) { create lago with:[shape::geom,id::short_id]; }
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
		ask comunidade { shape <- envelope(pescadores collect (each.homeplace)); }
		// Connect the lakes
		loop p over:parana { do connect_lakes(p);}
		// Assigne values to lakes
		loop l over:lago {do build_lakes(l);}
	}
	
	/*
	 * Built a simple environment based on parameters values
	 */
	action build_tabulero_from_scratsh(
		list<pair<int,int>> lagos <-  init_lagos, list<pair<string,string>> paranas <- init_paranas
	) {
		create rio with:[id::"R",shape::rectangle({0,0},{shape.width,int(shape.height*0.1)})];

		geometry world_shape <- shape - first(rio).shape;
		loop i from:1 to:length(lagos) { create lago with:[id::"L"+i]; } 
		loop pp over:init_paranas {
			water_body orig <- list(lago + rio) first_with (each.id = pp.key);
			water_body dest <- list(lago + rio) first_with (each.id = pp.value);
			create parana { ask world { do connect_lakes(myself, [orig,dest]); } }
		}
		
		list<lago> lago_rio_connect <- lago where (each.paranas one_matches (each.origin is rio or each.destination is rio));
		list<lago> lago_no_rio <- list(lago) - lago_rio_connect;
		
		do print_as("Init lago and paranas: "+sample(lago_rio_connect));
		
		// Create the shape and position of lakes : delaunay's triangulation (bad idea)
		// Design envelops
		list<geometry> t_lagos;
		if DELAUNAYS_GEN {
			float prop <- 1.0/10;
			float loc_buffer <- 5.0;
			float rate <- 1.1;
			t_lagos <- to_triangles(world_shape - square(world_shape.width*prop) at_location any_location_in(world_shape.centroid buffer loc_buffer));
			loop while:length(t_lagos) < length(lagos) {
				t_lagos <- to_triangles(world_shape - square(world_shape.width*prop) at_location any_location_in(world_shape.centroid buffer loc_buffer));
				loc_buffer <- loc_buffer*rate;
				prop <- prop*rate;
			}
		}
		else {
			if length(lago) mod 2 = 0 { t_lagos <- world_shape to_squares (int(length(lago)),false); }
			else if length(lago) = 1 { t_lagos <- [circle(world_shape.width/2,world_shape.centroid)]; }
			else if length(lago) = 3 { 
				list<geometry> geoms <- world_shape to_rectangles (1,2);
				t_lagos <- first(geoms) to_rectangles (2,1) + [last(geoms)]; 
			} else if length(lago) = 5 {
				list<geometry> geoms <- world_shape to_rectangles (1,2);
				t_lagos <- first(geoms) to_rectangles (3,1) + last(geoms) to_rectangles (2,1);
			} else if length(lago) < 11 {
				list<geometry> geoms <- world_shape to_rectangles (1,3);
				t_lagos <- first(geoms) to_rectangles (3,1) + geoms[1] to_rectangles (3,1) + (length(lago)=7 ? last(geoms) :last(geoms) to_rectangles (3,1));
			} else {
				list<geometry> geoms <- world_shape to_rectangles (1,4);
				t_lagos <- geoms accumulate (each to_rectangles (4,1));
			}
		}
		
		float ext_max <- float(lagos max_of (each.value));
		// Assign an envelop to lakes connected to rio
		t_lagos <- t_lagos sort_by (each.centroid distance_to first(rio));
		loop lago_rio_shape over: t_lagos copy_between (0,length(lago_rio_connect)) {
			lago cl <- any(lago_rio_connect);
			int lidx <- int(cl);
			
			cl.shape <- circle(lago_rio_shape.height/2.2*lagos[lidx].value/ext_max, lago_rio_shape.centroid);
			do build_lakes(cl,false,lagos[lidx].key,DEFAULT_SIZE_LUGAR_DE_PESCA,float(lagos[lidx].value));
			
			t_lagos >- lago_rio_shape;
			lago_rio_connect >- cl;
		}
		
		// Sort from largest to lowest area
		t_lagos <- t_lagos sort_by (-each.area);
		loop lago_shape over: t_lagos copy_between (0,length(lago_no_rio)) {
			
			lago cl <- lago_no_rio with_max_of (lagos[int(each)].value);
			lago_no_rio >- cl;
			int lidx <- int(cl);
			
			cl.shape <- circle(lago_shape.height/2.2*lagos[lidx].value/ext_max, lago_shape.centroid);
			do build_lakes(cl,false,lagos[lidx].key,DEFAULT_SIZE_LUGAR_DE_PESCA,float(lagos[lidx].value));
		}
		
		// Give a shape to paranas
		ask parana { 
			point op <- first(origin closest_points_with destination);
			point dp <- first(destination closest_points_with origin);
			shape <- line(op,dp);
		}
		
		// Create com outside lakes
		point com_location;
		int scale <- int(world.shape.height/20);
		geometry mask <- union(lago collect (each.shape) + rio collect (each.shape));
		loop cc over:init_comunidades.keys {
			lago com_lago <- lago first_with (each.id=cc);
			write sample(com_lago)+" "+sample(cc)+" "+sample(lago collect each.id);
			point com_loc <- any_location_in ((com_lago.shape buffer (scale)) - (com_lago.shape buffer (scale*0.5)) inter world_shape);
			do create_comunidade(circle(scale,com_loc) - union(mask,union(comunidade collect each.shape)),init_comunidades[cc]);
		}
		
	}
	
	// ----------------------
	// UTIL ACTIONS
	
		
	/*
	 * Create comunidades from scratch
	 */
	comunidade create_comunidade(geometry geom, int pescador_nb <- rnd(1,5)) {
		do print_as("Creating comunity within "+geom,world,first(level_list));
		create comunidade with:[shape::geom] returns:coms {
			create pescador number:pescador_nb with:[comu::self,homeplace::any_location_in(geom)] returns:pescs;
			pescadores <- pescs;
		}
		return first(coms);
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
			if length(wbodies) < 1 { do print_as("The should be at least 2 water body to connect",self,last(level_list));}
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
		list<geometry> lugares_de_pesca <- (lake.shape - baixao_de_pesca) 
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