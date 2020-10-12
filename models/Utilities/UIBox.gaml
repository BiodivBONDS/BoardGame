/**
* Name: UIBox
* Based on the internal empty template. 
* Author: etsop
* Tags: 
*/


model UIBox

global {
	
	
}

species VirtualBox virtual:true {
	
	// up rigth
	point _anchor -> first(shape.points);
	
	// look and feel
	rgb color <- #grey;
	string _atomic_aspect <- "slot" among:["none","slot"];
	
	map<agent,VirtualBox> grid;
	map<VirtualBox,list<agent>> occupancy;
	
	list<list<VirtualBox>> boxes;
	
	// CREATE INSIDE BOXES
	action __build_boxes virtual:true;
	init { do __build_boxes; }
	
	// Generic methods
	
	pair<int,int> get_grid(VirtualBox loc) {
		list<VirtualBox> line <- boxes first_with (each contains loc);
		return pair<int, int>(line = nil ? pair(-1,-1) : pair(boxes index_of line, line index_of loc));
	}
	
	VirtualBox get_location(int x, int y) {return boxes[x][y];}
		
	point _outside {return any_location_in(world.shape-shape);}
	action _insert(agent a, VirtualBox vb) {
		grid[a] <- vb;
		occupancy[vb] <+ a;
		a.location <- vb.location;
	}
	
	action insert(agent a, int x, int y) { do _insert(a, get_location(x,y)); }
	action insert_empty(agent a) { do _insert(a, occupancy.keys first_with (empty(occupancy[each]))); }
	
	VirtualBox move(agent a, int x, int y) {
		VirtualBox vb <- grid[a];
		if vb = nil {do insert(a,x,y);} 
		else { do insert(a, get_grid(vb).key+x, get_grid(vb).value+y); }
		return grid[a];
	} 
	
	action remove(agent a) {
		occupancy[grid[a]] >- a;
		grid[] >- a; 
		a.location <- any_location_in(world.shape-shape);
	}
	
	// Visualization
	
	geometry slot_display virtual:true;
	
	aspect default {
		draw shape color:rgb(color,0.1);
		draw shape.contour color:color;
		switch _atomic_aspect { 
			ask occupancy.keys {draw slot_display() color:rgb(color,0.5);}
		}
		draw name at:_anchor+point(1,1) font:font(10) color:#black border:#black;
	}
	
}

species GridBox parent:VirtualBox {
	
	// number of cells horizontal and vertical
	int _x;
	int _y;

	action __build_boxes {
		if (_x=0 or _y=0) {error "Cannot build a GridBox without x ("+_x+") or y ("+_y+") dimensions";}
		list<AtomicBox> atomicBoxes;
		loop ab over:shape to_rectangles (_y,_x,false) {
			create AtomicBox with:[shape::ab,b_host::self] returns:atoms;
			atomicBoxes <<+ atoms;
		}
		occupancy <- atomicBoxes as_map (each::[]);
		loop boxidx over: remove_duplicates(atomicBoxes collect (each.location.x)) {
			boxes <+ atomicBoxes where (each.location.x=boxidx);
		}
	}
	
	geometry slot_display {return shape;}
	
}

species RegularBox parent:VirtualBox {
	
	float _size;
	
	action __build_boxes {
		if (_size<=0) {error "Cannot build a RegularBox with 0 or less atomic box size ("+_size+")";}
		list<AtomicBox> atomicBoxes;
		loop ab over:shape to_squares (_size,false) {
			create AtomicBox with:[shape::ab,b_host::self] returns:atoms;
			atomicBoxes <<+ atoms;
		}
		occupancy <- atomicBoxes as_map (each::[]);
		loop boxidx over: remove_duplicates(atomicBoxes collect (each.location.x)) {
			boxes <+ atomicBoxes where (each.location.x=boxidx);
		}
	}
	
	geometry slot_display {return shape;}
	
}

/*
 * Boxes that cannot have boxes insides
 */
species AtomicBox parent:VirtualBox {
	
	VirtualBox b_host;
	geometry slot_display;	
	
	init {
		slot_display <- geometry(shape.contour.geometries 
			collect (each + (each.location buffer each.perimeter*0.35))
		);
		//slot_display <- shape.contour;
	}
	
	action __build_boxes {}
	pair<int,int> get_grid(VirtualBox loc) {return 0::0;}
	VirtualBox get_location(int x, int y) {return self;}
	action insert(agent a, int x, int y) {/* do nothing */}
	VirtualBox move(agent a, int x, int y) {return self;}
	action remove(agent a) {ask b_host {do remove(a);}}
	
	geometry slot_display {return slot_display;}
	
}

