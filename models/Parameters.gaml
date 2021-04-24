/**
* Name: Parameters
* Based on the internal empty template. 
* Author: kevinchapuis
* Tags: 
*/

model Parameters

import "Utilities/Bonds Log.gaml"

global {
	
	// UTILITIES
	bool IMG_SHAPE <- true;
	
	// PESCADOR
	int init_money_bank <- 5;
	int starting_nb_boats <- 1;
	
	image_file house_imf <- image_file("../includes/img/house.png");

	// BOATS & MOBILITY
	int init_boat_capacity <- 10 parameter:true min:2 max:20 step:1 category:eco;
	float move_cost_ratio <- 0.2 parameter:true min:0.1 max:1.0 step:0.1 category:eco;
	float move_cost_low_water_factor <- 2.0 parameter:true min:1.0 max:5.0 step:0.5 category:eco;
	bool move_cost_limitation <- false parameter:true category:eco;
	
	image_file boat_img <- image_file("../includes/img/canos.png");
	
	// FISHING
	string rnd_spot <- "rnd_spot";
	string dst_spot <- "dst_spot";
	string eff_spot <- "eff_spot";
	string global_spot_strategy <- rnd_spot parameter:true among:["rnd_spot","dst_spot","eff_spot"] category:decision;
	
	float fish_selling_price <- 1.0 parameter:true min:0.1 max:5.0 category:eco;
	
	// FISH
	int max_fish_stock_per_unit <- 50;
	float normal_recovery <- 0.1 parameter:true min:0.1 max:1.0 step:0.1 category:fish;
	float degradeted_recovery <- 0.05 parameter:true min:0.05 max:0.5 step:0.05 category:fish; 
	float high_threshold_recovery <- 4/5;
	float low_threshold_recovery <- 1/5;
	
	float low_season_fish_recovery <- 1.0 parameter:true min:0.0 max:1.0 step:0.1 category:fish;
	float high_season_fish_recovery <- 0.0 parameter:true min:0.0 max:1.0 step:0.1 category:fish;
		
	// HYDRO
	string HIGH_WATER_SEASON <- "High water season";
	string LOW_WATER_SEASON <- "Low water season";
	map<string, float> hydro_regime_fish_growth <- [HIGH_WATER_SEASON::high_season_fish_recovery,LOW_WATER_SEASON::low_season_fish_recovery];
	
	// --------------------------------------------------------------------------------------------------
	// PARAMETER FILE
	// --------------------------------------------------------------------------------------------------
	
	csv_file params <- csv_file("../includes/parameters.csv");
	bool PARAMETER_FILE_ACTIVE <- true;
	
	string pname <- "name";
	string ptype <- "type";
	string pvalues <- "values";
	string pinit <- "init";
	string pmin <- "min";
	string pmax <- "max";
	string pcategory <- "category";
	list<string> param_headers <- [pname,ptype,pvalues,pinit,pmin,pmax,pcategory];
	
	/*
	 * TODO description
	 */
	action read_parameter {
		matrix p <- matrix(params);
		loop i from:1 to:p.rows-1 {
			string pn <- format_parameter_name(p[param_headers index_of pname,i]);
			if pn != nil {
				string pv <- p[param_headers index_of pinit,i];
				switch p[param_headers index_of ptype,i] {
					match 'int' {world.shape.attributes[pn] <- int(pv);}
					match_one ['float','double'] {world.shape.attributes[pn] <- float(pv);}
					default {world.shape.attributes[pn] <- pv;}
				}
			 } else {
			 	do print_as("No parameter "+p[param_headers index_of pname,i]+" as been found in the model",world,last(level_list));
			 }
		}
	}
	
	list<string> param_regex_pattern <- [" the "," of "," in "];
	map<string,string> param_translat_pattern <- ["number"::"nb","numbers"::"nb","maximum"::"max","minimum"::"min"];
	
	/*
	 * 
	 */
	string format_parameter_name(string param_name) {
		if world.shape.attributes.keys contains param_name {return param_name;}
		string formated_name <- param_name;
		loop r over:param_translat_pattern.keys {if formated_name contains r {formated_name <- formated_name replace_regex(r,param_translat_pattern[r]);}}
		loop r over:param_regex_pattern {if formated_name contains r {formated_name <- formated_name replace_regex(r," ");}}
		formated_name <- formated_name replace_regex(" ","_");
		
		do print_as(sample(formated_name),world,DEFAULT_LEVEL);
		
		if world.shape.attributes.keys contains formated_name {return formated_name;}
		return nil;
	}
	
}

