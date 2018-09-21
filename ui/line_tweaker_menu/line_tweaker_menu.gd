tool
extends VBoxContainer

var selected_generator = null setget set_selected_generator
var selected_hype_points = [] setget set_selected_hype_points
var focus_hyper_point = null

var image_index_arr = []
var hyper_point_arr = []

var hype_index = -1 setget set_hype_index
var hype_curve_resolution = .1 setget set_hype_curve_resolution
var hype_line_image setget set_hype_line_image
var hype_line_image_locked setget set_hype_line_image_locked

func set_selected_generator(value): 
	selected_generator = value

func set_selected_hype_points(value):
	selected_hype_points = value
	if selected_generator != null:
		selected_hype_points = value
		focus_hyper_point = selected_hype_points[selected_hype_points.size()-1]
		hyper_point_arr = selected_generator.hyper_point_arr
		var selected_hype_point = hyper_point_arr[focus_hyper_point.index]
		#Set variables
		set_hype_curve_resolution(selected_hype_point.curve_resolution)
		set_hype_line_image(selected_hype_point.edge_image_index)
		set_ui_hype_line_image(selected_hype_point.edge_image_index)
		set_hype_line_image_locked(selected_hype_point.edge_image_locked)
		set_ui_hype_line_image_locked(selected_hype_point.edge_image_locked)
		#Set ui variables
		$PointIndex/SpinBox.set_value(focus_hyper_point.index)
		#Set image index array
		image_index_arr = []
		$LineImage/OptionButton.clear()
		for id in selected_generator.tile_set.get_tiles_ids():
			image_index_arr.append(selected_generator.tile_set.tile_get_name(id))
			$LineImage/OptionButton.add_item(selected_generator.tile_set.tile_get_name(id))
	
func set_hype_index(value):
	hype_index = value
	set_hype_line_image(hyper_point_arr[hype_index].edge_image_index)
	set_ui_hype_line_image(hyper_point_arr[hype_index].edge_image_index)
	set_hype_line_image_locked(hyper_point_arr[hype_index].edge_image_locked)
	set_ui_hype_line_image_locked(hyper_point_arr[hype_index].edge_image_locked)
	
	
func set_hype_curve_resolution(value):
	pass
	
func set_hype_line_image(value):
	hype_line_image = value
	#Set ui option
	#for item_idx in $LineImage/OptionButton.get_item_count():
	#	if $LineImage/OptionButton.get_item_text(item_idx) == hype_line_image:
	#		$LineImage/OptionButton.select(item_idx)
	pass
func set_ui_hype_line_image(value):
	#Set ui option
	for item_idx in $LineImage/OptionButton.get_item_count():
		if $LineImage/OptionButton.get_item_text(item_idx) == value:
			$LineImage/OptionButton.select(item_idx)
	
func set_hype_line_image_locked(value):
	hype_line_image_locked = value
func set_ui_hype_line_image_locked(value):
	#Set ui option
	$LineImage/CheckBox.pressed = hype_line_image_locked

func _ready():
	pass

func _on_point_index_value_changed(value):
	pass # replace with function body
	
func _on_curve_resolution_changed(value):
	"""
	Edit hyper line's curve resolution
	"""
	set_hype_curve_resolution(value)
	if selected_generator != null and selected_hype_points != []:
		for hype in selected_hype_points:
			selected_generator.hyper_point_arr[hype.index].curve_resolution = value
			#Update curve
			selected_generator.bake_curve(hype.index)
			selected_generator.update_edge_lines(hype.index)
			selected_generator.update_polygon_points()

func _on_line_image_selected(ID):
	set_hype_line_image($LineImage/OptionButton.get_item_text(ID))
	#Update hyper polygon's image
	if selected_generator != null and selected_hype_points != []:
		for hype in selected_hype_points:
			#Set line image in line
			selected_generator.hyper_point_arr[hype.index].edge_image_index = $LineImage/OptionButton.get_item_text(ID)
			#Set line image is locked in line
			selected_generator.hyper_point_arr[hype.index].edge_image_locked = true
			#Update line image
			selected_generator.update_edge_image(hype.index)
		#Set line image
		set_hype_line_image( $LineImage/OptionButton.get_item_text(ID) )
		set_ui_hype_line_image( $LineImage/OptionButton.get_item_text(ID) )
		#Set image is locked
		set_hype_line_image_locked(true)
		set_ui_hype_line_image_locked(true)

func _on_lime_image_locked_toggled(button_pressed):
	set_hype_line_image_locked(button_pressed)
	#Update hyper polygon's is image locked
	if selected_generator != null and selected_hype_points != []:
		for hype in selected_hype_points:
			hyper_point_arr[hype.index].edge_image_locked = button_pressed
