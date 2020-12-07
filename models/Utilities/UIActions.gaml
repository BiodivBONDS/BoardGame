/**
* Name: UIActions
* Based on the internal empty template. 
* Author: etsop
* Tags: 
*/


model UIActions

import "UIBox.gaml"

global {
	
	string FISH <- "Fishing";
	string ECO <- "Selling";
	string AGREEMENT <- "Agreement";
	list<string> actypes <- [FISH,ECO,AGREEMENT];
	list<rgb> actolor <- [#blue,blend(#gold,#brown,0.6),#green];
	
	map<string,list<string>> actions <- [FISH::["Spot","Fish","Gear"],ECO::["Sell","Stock"],AGREEMENT::["Regulation"]];
	string act <- "nothing";
	
	// MOUSE SELECT VARS
	
	list<selectable> selectables -> list<selectable>(selectable.subspecies accumulate (each.population)); // TODO : dynamic ?
	
	// Select color
	rgb selected_color <- #red;
	
	selectable selected_agent;
	
	point select_loc;
	float select_threshold <- 2#m;
	
	action select_agent { 
		selectable selagent <- selectables overlapping (select_loc buffer select_threshold) closest_to select_loc;
		selected_agent.selected <- false;
		if selagent=selected_agent { selected_agent <- nil; }
		else {selected_agent <- selagent; selagent.selected <- true;}
	}
	
	action inspect_agent {
		selectable selagent <- selectables overlapping (select_loc buffer select_threshold) closest_to select_loc;
		inspect(selagent);
	}
	
	action move_select { select_loc <- #user_location; }
	
	// ------------
	// Action type
	action activate_act {
		button selected_but <- first(button overlapping (circle(1) at_location #user_location));
		if(selected_but != nil) {
			ask selected_but {
				ask button { bord_col <- actolor[grid_x];}
				if (act != id) {
					act <- id;
					bord_col <- selected_color;
				} else {
					act <- "nothing";
				}
				
			}
		}
	}
	
}

species selectable virtual:true {
	
	bool selected <- false;
	
	bool contour_shape <- true;
	rgb contour_color <- #red;
	
}

grid button width:length(actypes) height:max(actions.values collect (length(each))) 
{
	
	string id <- actions contains_key actypes[grid_x] 
		and grid_y < length(actions[actypes[grid_x]]) ? 
				actions[actypes[grid_x]][grid_y] : "";
	rgb bord_col <- actolor[grid_x];
	
	aspect default {
		if id!=""{
			draw rectangle(shape.width * 0.8, shape.height * 0.8).contour + (shape.height * 0.01) color: bord_col;
			draw id anchor:#center font:bord_col=selected_color?font(6,#bold):font(10) color:bord_col;
			if grid_y = 0 {
				draw actypes[grid_x] at:first(shape.points)+point(shape.width*0.1,shape.height*0.06) font:font(10,#bold) color: blend(bord_col,#black,0.75);
			}
		}
	}
	
}