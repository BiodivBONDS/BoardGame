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
	
	// action to log
	action print_as(string msg, agent caller, string level <- "debug", string theme <- nil) {
		if level_list index_of LEVEL <= level_list index_of level 
				and (theme=nil or theme_list contains theme) {
			string c <- caller = nil ? "BONDS" : caller.name;
			string head <- "["+c+(theme!=nil?get_theme(theme):"")+"] ";
			switch level {
				match "error" {error head+msg;}
				match "warning" {warn head+msg;}
				default {write head+msg;}
			}	
		}
	}
	
	string get_theme(string theme) {
		switch theme {
			match SCH {return "|"+theme+"-"+sample(cycle);}
			default {return "";}
		}
	}
	
}

