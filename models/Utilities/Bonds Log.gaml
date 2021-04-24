/**
* Name: BondsLog
* Based on the internal empty template. 
* Author: kevinchapuis
* Tags: 
*/


model BondsLog

global {
	
	// Themed log
	string SCH <- "scheduling";
	list<string> theme_list <- [SCH];
	
	// Level log 
	string LEVEL <- "verbose" among:["trace","debug","verbose","warning","error"];
	list<string> level_list <- ["trace","debug","verbose","warning","error"];
	
	string DEFAULT_LEVEL <- "DEFAULT";
	
	// action to log
	action print_as(string msg, agent caller <- nil, string level <- "debug", string theme <- nil) {
		if authorise_msg(level, theme) {
			string head <- get_header(caller,theme);
			string level <- level = DEFAULT_LEVEL ? LEVEL : level;
			switch level {
				match "error" {error head+" "+msg;}
				match "warning" {warn head+" "+msg;}
				default {write head+" "+msg;}
			}	
		}
	}
	
	// action to format the header of the message with caller and theme
	string get_header(agent caller, string theme) {
		string c <- caller = nil ? "BONDS" : caller.name;
		string t;
		switch theme {
			match SCH {t <- "|"+theme+"-"+sample(cycle);}
			default {t <- "";}
		}
		return "["+c+t+"]";
	}
	
	// action to authorize or not the message based on requested level of log and theme
	bool authorise_msg(string level, string theme) {
		return (upper_case(level) = DEFAULT_LEVEL or 
			level_list index_of LEVEL <= level_list index_of level) 
				and (theme=nil or theme_list contains theme) ;
	}
	
}

