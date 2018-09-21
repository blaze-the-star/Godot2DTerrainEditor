tool
extends EditorPlugin

const terr_gen_path = "res://addons/terrain_editor/nodes/terrain_generator/terrain_generator.gd"
const terr_gen_icon_path = "res://addons/terrain_editor/nodes/terrain_generator/icon.png"
const terr_gen_gd_load = preload( terr_gen_path )
const terr_gen_icon_img = preload( terr_gen_icon_path )
const hyper_poly_obj_path = "res://addons/terrain_editor/nodes/hyper_polygon_obj/hyper_polygon.gd"
const hyper_poly_obj_icon_path = "res://addons/terrain_editor/nodes/hyper_polygon_obj/icon.png"
const hyper_poly_obj_gd = preload( hyper_poly_obj_path )
const hyper_poly_obj_icon = preload( hyper_poly_obj_icon_path )

const button_add_point_pck = preload( "ui/button_add_polygon_point/button_add_polygon_point.tscn" )
var button_add_point_inst
const button_tweak_poly_pck = preload( "ui/button_tweak_polygon/button_tweak_polygon.tscn" )
var button_tweak_poly_inst
const button_remove_poly_pck = preload( "ui/button_remove_polygon_point/button_remove_polygon_point.tscn" )
var button_remove_poly_inst
const button_bake_poly_pck = preload( "ui/button_bake_polygon/button_bake_polygon.tscn" )
var button_bake_poly_inst

const menu_line_tweaker_pck = preload( "ui/line_tweaker_menu/line_tweaker_menu.tscn" )
var menu_line_tweaker_inst = menu_line_tweaker_pck.instance()

# ===== Polygon editing =====
const this = {"type":"point", "index":0}
var poly_edit_mode = "add_point"
var select_terr_genr_node = null
var select_points_arr = []
var init_mouse_click_pos = null
var reset_select_upon_mouse_release = false
var point_dragged = false
var line_split = false
# ----- Polygon editing -----

var undo_redo = get_undo_redo()

func _enter_tree():
	undo_redo = get_undo_redo()
	### UI ###
	create_buttons_instances()
	#Menu
	menu_line_tweaker_inst = menu_line_tweaker_pck.instance()
	### Nodes ###
	add_custom_type( "TerrainGenerator2D", "Node2D", terr_gen_gd_load, terr_gen_icon_img )
	add_custom_type( "HyperPolygon", "Object", hyper_poly_obj_gd, hyper_poly_obj_icon )
	### Signals ###
	get_editor_interface().get_selection().connect( "selection_changed", self, "_on_editor_selection_changed" )
	
func _exit_tree():
	### Controls ###
	remove_control_from_container( CONTAINER_CANVAS_EDITOR_MENU, button_add_point_inst )
	remove_control_from_container( CONTAINER_CANVAS_EDITOR_MENU, button_tweak_poly_inst )
	remove_control_from_container( CONTAINER_CANVAS_EDITOR_MENU, button_remove_poly_inst )
	remove_control_from_container( CONTAINER_CANVAS_EDITOR_MENU, button_bake_poly_inst )
	#Menu
	remove_control_from_docks(menu_line_tweaker_inst)
	### Nodes ###
	remove_custom_type( "TerrainGenerator2D" )

func create_buttons_instances():
	#Create instances
	if button_add_point_inst == null:
		button_add_point_inst = button_add_point_pck.instance()
		add_control_to_container( CONTAINER_CANVAS_EDITOR_MENU, button_add_point_inst )
		button_add_point_inst.hide()
		button_add_point_inst.connect( "pressed", self, "_change_mode_add_point" )
	if button_tweak_poly_inst == null:
		button_tweak_poly_inst = button_tweak_poly_pck.instance()
		add_control_to_container( CONTAINER_CANVAS_EDITOR_MENU, button_tweak_poly_inst )
		button_tweak_poly_inst.hide()
		button_tweak_poly_inst.connect( "pressed", self, "_change_mode_tweak_poly" )
	if button_remove_poly_inst == null:
		button_remove_poly_inst = button_remove_poly_pck.instance()
		add_control_to_container( CONTAINER_CANVAS_EDITOR_MENU, button_remove_poly_inst )
		button_remove_poly_inst.hide()
		button_remove_poly_inst.connect( "pressed", self, "_change_mode_remove_point" )
	if button_bake_poly_inst == null:
		button_bake_poly_inst = button_bake_poly_pck.instance()
		add_control_to_container( CONTAINER_CANVAS_EDITOR_MENU, button_bake_poly_inst )
		button_bake_poly_inst.hide()
		button_bake_poly_inst.connect( "pressed", self, "_bake_polygon" )
	
func create_menu_instances():
	if menu_line_tweaker_inst == null:
		menu_line_tweaker_inst = menu_line_tweaker_pck.instance()
	
func forward_canvas_gui_input(input):
	#print( get_editor_interface().get_editor_viewport().get_children() )
	if "button_index" in input and select_terr_genr_node != null: 
		#Mouse button pressed
		var mouse_pos = select_terr_genr_node.get_local_mouse_position()
		if (input.button_index == 1 or input.button_index == 2) and input.is_pressed() and init_mouse_click_pos == null:
			#Add points to polygon
			if poly_edit_mode == "add_point":
				select_points_arr = []
				var point_selected = select_hyper_point("mid_point")
				if point_selected:
					#Add point to middle of line
					terrain_split_line(mouse_pos)
				else:
					#Add point to end of line
					undo_redo.create_action( "AddPoint" )
					undo_redo.add_do_method(select_terr_genr_node, "add_point", mouse_pos)
					undo_redo.add_undo_method(select_terr_genr_node, "remove_point", select_terr_genr_node.hyper_point_arr.size(), "point")
					undo_redo.commit_action()
			#Tweak poly mode
			if poly_edit_mode == "tweak_poly":
				point_dragged = false
				reset_select_upon_mouse_release = true
				init_mouse_click_pos = mouse_pos
				#Check for points that have been clicked on
				var point_selected = false
				if input.button_index == 1: #Clicked on point
					point_selected = select_hyper_point("point")
				if not point_selected: #Clicked on control_ppast
					point_selected = select_hyper_point("control_post")
				if not point_selected: #Clicked on control_past
					point_selected = select_hyper_point("control_past")
				if not point_selected: #Clicked on mid_point
					point_selected = select_hyper_point("mid_point")
					if point_selected:
						#Split line
						terrain_split_line(mouse_pos)
				#Update point's relative to mouse location
				for point_info in select_points_arr:
					var point_pos = select_terr_genr_node.hyper_point_arr[point_info.index][point_info.point_type]
					point_info.rel_to_mouse = Vector2(point_pos.x-mouse_pos.x, point_pos.y-mouse_pos.y)
			#Remove points from polygon mode
			if poly_edit_mode == "remove_point":
				var point_selected = select_hyper_point("point")
				if not point_selected:
					point_selected = select_hyper_point("control_post")
				if not point_selected:
					point_selected = select_hyper_point("control_past")
				#Remove selected points
				for point_info in select_points_arr:
					var hyper_point = select_terr_genr_node.hyper_point_arr[point_info.index]
					undo_redo.create_action( "RemovePoint" )
					undo_redo.add_do_method(select_terr_genr_node, "remove_point", point_info.index, point_info.point_type)
					if point_info.point_type == "point":
						undo_redo.add_undo_method(select_terr_genr_node, "add_point", hyper_point.point, point_info.index)
					else:
						print(hyper_point[point_info.point_type])
						undo_redo.add_undo_method(select_terr_genr_node, "move_point", hyper_point[point_info.point_type], point_info.index, point_info.point_type)
					undo_redo.commit_action()
				select_points_arr = []
				select_terr_genr_node.deselect_points() #Tell polygon deselect all points
		#Mouse released
		if (input.button_index == 1 or input.button_index == 2) and not input.is_pressed():
			if poly_edit_mode == "add_point":
				init_mouse_click_pos = null
				line_split = false
				#Reset selection
				if reset_select_upon_mouse_release:
					select_points_arr = []
					select_terr_genr_node.deselect_points() #Tell polygon deselect all points
			#Tweak poly mode
			if poly_edit_mode == "tweak_poly":
				#Add undo_redo action for moving point
				undo_redo.create_action( "MovePoint" )
				for point_info in select_points_arr:
					var new_point = Vector2(mouse_pos.x+point_info.rel_to_mouse.x, mouse_pos.y+point_info.rel_to_mouse.y)
					var old_point = Vector2(init_mouse_click_pos.x+point_info.rel_to_mouse.x, init_mouse_click_pos.y+point_info.rel_to_mouse.y)
					undo_redo.add_do_method(select_terr_genr_node, "move_point", new_point, point_info.index, point_info.point_type)
					undo_redo.add_undo_method(select_terr_genr_node, "move_point", old_point, point_info.index, point_info.point_type)
				undo_redo.commit_action()
				#Reset selection
				if reset_select_upon_mouse_release:
					select_points_arr = []
					select_terr_genr_node.deselect_points() #Tell polygon deselect all points
				init_mouse_click_pos = null
				
	elif select_terr_genr_node != null: #Mouse motion
		#Line split drag
		if (poly_edit_mode == "add_point" or poly_edit_mode == "tweak_poly") and line_split:
			var mouse_pos = select_terr_genr_node.get_local_mouse_position()
			reset_select_upon_mouse_release = true
			#Drag selected points
			if init_mouse_click_pos != null:
				for point_info in select_points_arr:
					var new_point = Vector2(mouse_pos.x+point_info.rel_to_mouse.x, mouse_pos.y+point_info.rel_to_mouse.y)
					select_terr_genr_node.move_point(new_point, point_info.index, point_info.point_type)
		#Tweak poly mode drag
		if poly_edit_mode == "tweak_poly":
			var mouse_pos = select_terr_genr_node.get_local_mouse_position()
			if select_points_arr.size() == 1:
				reset_select_upon_mouse_release = true
			else:
				reset_select_upon_mouse_release = false
			#Drag selected points
			if init_mouse_click_pos != null:
				for point_info in select_points_arr:
					var new_point = Vector2(mouse_pos.x+point_info.rel_to_mouse.x, mouse_pos.y+point_info.rel_to_mouse.y)
					select_terr_genr_node.move_point(new_point, point_info.index, point_info.point_type)
					#select_terr_genr_node.hyper_point_arr[point_info.index][point_info.point_type] = new_poin

func terrain_split_line(mouse_pos):
	"""
	Break a line into two lines
	"""
	line_split = true
	init_mouse_click_pos = mouse_pos
	#Add point to middle of line
	undo_redo.create_action( "AddPoint" )
	undo_redo.add_do_method(select_terr_genr_node, "add_point", mouse_pos, select_points_arr[0].index+1)
	undo_redo.add_undo_method(select_terr_genr_node, "remove_point", select_points_arr[0].index+1, "point")
	undo_redo.commit_action()
	
	select_points_arr = [ {"point_type":"point", "index":select_points_arr[0].index+1, "rel_to_mouse":Vector2(0,0)} ]

func mouse_hovers_over_points():
	var mouse_pos = select_terr_genr_node.get_local_mouse_position()
	var index_array = []
	var counter = 0
	for hyper_point in select_terr_genr_node.hyper_point_arr:
		if mouse_pos.distance_to(hyper_point["point"]) < select_terr_genr_node.POINT_SIZE:
			return {"index":counter, "node_type":"point"}
		if mouse_pos.distance_to(hyper_point["control_post"]) < select_terr_genr_node.POINT_SIZE:
			return {"index":counter, "node_type":"control_post"}
		if mouse_pos.distance_to(hyper_point["control_post"]) < select_terr_genr_node.POINT_SIZE:
			return {"index":counter, "node_type":"control_past"}
		if mouse_pos.distance_to(hyper_point["mid_point"]) < select_terr_genr_node.POINT_SIZE:
			return {"index":counter, "node_type":"mid_point"}
		counter += 1

func select_hyper_point(point_type):
	"""
	Runs a check for if a point is selected. Returns if a point is selected
	"""
	var mouse_pos = select_terr_genr_node.get_local_mouse_position()
	var point_selected = false
	var counter = 0
	for hyper_point in select_terr_genr_node.hyper_point_arr:
		#If point is in range
		if mouse_pos.distance_to(hyper_point[point_type]) < select_terr_genr_node.POINT_SIZE:
			#Tell polygon point is selected
			select_terr_genr_node.point_selected(true, counter, point_type)
			#Set variables
			reset_select_upon_mouse_release = false
			var new_point_info = {
				"index":counter, 
				"point_type":point_type, 
				"rel_to_mouse":Vector2(hyper_point[point_type].x-mouse_pos.x, hyper_point[point_type].y-mouse_pos.y)
			}
			#Add point to selected points list if point is not in selected point list
			if not select_points_arr.has(new_point_info):
				select_points_arr.append(new_point_info)
				point_selected = true
				#Update tweak menu's point position
				menu_line_tweaker_inst.set_selected_hype_points(select_points_arr)
				menu_line_tweaker_inst.set_hype_index(counter)
				break
		counter += 1
	return point_selected
		
func make_visible(visible):
	if visible:
		if button_add_point_inst != null:
			button_add_point_inst.show()
		if button_tweak_poly_inst != null:
			button_tweak_poly_inst.show()
		if button_remove_poly_inst != null:
			button_remove_poly_inst.show()
		if button_bake_poly_inst != null:
			button_bake_poly_inst.show()
	else:
		if button_add_point_inst != null:
			button_add_point_inst.hide()
		if button_tweak_poly_inst != null:
			button_tweak_poly_inst.hide()
		if button_remove_poly_inst != null:
			button_remove_poly_inst.hide()
		if button_bake_poly_inst != null:
			button_bake_poly_inst.hide()
			
func handles(object):
	return object is terr_gen_gd_load
	
func _change_mode_add_point():
	poly_edit_mode = "add_point"
func _change_mode_tweak_poly():
	poly_edit_mode = "tweak_poly"
func _change_mode_remove_point():
	select_points_arr = []
	poly_edit_mode = "remove_point"
func _bake_polygon():
	if select_terr_genr_node is terr_gen_gd_load:
		select_terr_genr_node.bake_polygon()
	
func _on_editor_selection_changed():
	var select_nodes_arr = get_editor_interface().get_selection().get_selected_nodes()
	#Get selected node
	if select_nodes_arr.size() != 1: 
		make_visible( false );
		select_terr_genr_node = null
		if menu_line_tweaker_inst.get_parent() != null:
			remove_control_from_docks(menu_line_tweaker_inst)
		return
	var selected_node = select_nodes_arr[0];
	
	if selected_node.get_parent() != null:
		#Terrain generator selected
		if selected_node is terr_gen_gd_load:
			make_visible( true );
			select_terr_genr_node = selected_node
			#Add line tweaker menu
			if menu_line_tweaker_inst.get_parent() == null:
				add_control_to_dock(DOCK_SLOT_LEFT_BR, menu_line_tweaker_inst)
		#Terrain generator de-selected
		else:
			make_visible( false );
			select_terr_genr_node = null
			#Remove line tweaker menu
			if menu_line_tweaker_inst.get_parent() != null:
				remove_control_from_docks(menu_line_tweaker_inst)
			
	menu_line_tweaker_inst.set_selected_generator(select_terr_genr_node)
	
	
	
	
	
	