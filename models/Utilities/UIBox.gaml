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

	// number of cells horizontal and vertical
	int _x;
	int _y;
	
	map<agent,VirtualBox> grid;
	map<VirtualBox,list<agent>> occupancy;
	
	list<list<VirtualBox>> boxes;
	
	pair<int,int> get_grid(VirtualBox loc) virtual:true;
	VirtualBox get_location(int x, int y) virtual:true;
	
	action __build_boxes virtual:true;
		
	point _outside {return any_location_in(world.shape-shape);}
	action _insert(agent a, VirtualBox vb) {
		grid[a] <- vb;
		occupancy[vb] <+ a;
		a.location <- vb.location;
	}
	
	action insert(agent a, int x, int y) { do _insert(a, get_location(x,y)); }
	action insert_empty(agent a) { do _insert(a, any(occupancy.keys where (empty(occupancy[each])))); }
	
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
	
}

species RegularBox parent:VirtualBox {
	
	init {
		do __build_boxes;
	}
	
	pair<int,int> get_grid(VirtualBox loc) {
		list<VirtualBox> line <- boxes first_with (each contains loc);
		return pair<int, int>(line = nil ? pair(-1,-1) : pair(boxes index_of line, line index_of loc));
	}
	
	VirtualBox get_location(int x, int y) {return boxes[x][y];}
	
	action __build_boxes {
		if (_x=0 or _y=0) {error "Cannot build a RegularBox without x ("+_x+") or y ("+_y+") dimensions";}
		create atomicBox from:shape to_squares(_x*_y,false) with:[b_host::self] returns:atomicBoxes;
		occupancy <- atomicBoxes as_map (each::[]);
		loop boxidx over: remove_duplicates(atomicBoxes collect (each.location.y)) {
			boxes <+ atomicBoxes where (each.location.y=boxidx);
		}
	}
	
}

/*
 * Boxes that cannot have boxes insides
 */
species atomicBox parent:VirtualBox {
	
	VirtualBox b_host;	
	
	action __build_boxes {}
	pair<int,int> get_grid(VirtualBox loc) {return 0::0;}
	VirtualBox get_location(int x, int y) {return self;}
	action insert(agent a, int x, int y) {/* do nothing */}
	VirtualBox move(agent a, int x, int y) {return self;}
	action remove(agent a) {ask b_host {do remove(a);}}
}

