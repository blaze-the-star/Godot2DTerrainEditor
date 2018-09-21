tool
extends Node2D

export(int, "Closed", "Pulled", "Extruded") var generation_mode = 0
export(TileSet) var tile_set = load("res://addons/terrain_editor/resources/default_tileset/mesa_tile_set.tres") setget set_tile_set
export var create_collision_shape = false setget set_create_collision_shape
export var body_tile_name = "Body"
export var top_edge_tile_name = "EdgeTop"
export var bottom_edge_tile_name = "EdgeBottom"
export var left_edge_tile_name = "EdgeLeft"
export var right_edge_tile_name = "EdgeRight"

const GENERATION_MODE_CLOSED = 0
const GENERATION_MODE_PULLED = 1
const GENERATION_MODE_EXTRUDED = 2

var line_material = preload("res://addons/terrain_editor/resources/mask_shader/mask_shader.material")

const POINT_SIZE = 5

const hyper_point_ref = {
	"curve_resolution":.1,
	"mid_point":Vector2(0,0), 
	"line_normal":Vector2(1,0),
	"baked_curve":PoolVector2Array(),
	"point":Vector2(0,0), 
	"control_past":Vector2(0,0), 
	"control_post":Vector2(0,0), 
	"point_selected":false, 
	"control_past_selected":false, 
	"control_post_selected":false,
	"edge_instance":null,
	"edge_image_index":"EdgeTop",
	"edge_image_locked":false
}

var poly_build_dir = "clockwise"
var hyper_point_arr = []
var hyper_point_ang_arr = []
var baked_poly = PoolVector2Array()
var selected_line_idx = -1

var line_2d_ref = Line2D.new()
var polygon_2d_inst = Polygon2D.new()
var col_poly_inst = CollisionPolygon2D.new()
var line_2d_inst = line_2d_ref.duplicate()

func _ready():
	if name != "":
		set_process(true)
		
func _enter_tree():
	if name != "":
		var root_node = get_tree().get_edited_scene_root()
		#Signals
		connect("item_rect_changed", self, "_item_rect_changed")
		connect("tree_exiting", self, "_tree_exiting")
		#Line reference
		line_2d_ref.set_name("EdgeLine2D")
		line_2d_ref.show_behind_parent = true
		#Line reference
		line_2d_ref.set_name("EdgeLine2D")
		line_2d_ref.show_behind_parent = true
		#Collision shape
		add_collision_instance()
	
func _process(delta):
	if name != "":
		update()
		col_poly_inst.set_global_position( get_global_position() )
	
func generate_curve(hyper_point_a, hyper_point_b):
	"""
	Generate and return a list of points following a curve
	"""
	if name != "":
		var curve_points = PoolVector2Array()
		var curr_interval = 0.0
		while curr_interval <= 1-hyper_point_a.curve_resolution-.1:
			#Get interval
			curr_interval += hyper_point_a.curve_resolution
			if curr_interval >= 1-.1:
				break
			
			#Add point
			if curr_interval < 1-.1:
				curve_points.append(generate_point(curr_interval, hyper_point_a, hyper_point_b))
			
		return curve_points
	
func generate_point(progress, hyper_point_a, hyper_point_b):
	if name != "":
		#Get offset
		var offset_a = Vector2(0,0)
		offset_a.x = hyper_point_a.point.x
		offset_a.y = hyper_point_a.point.y
		var offset_b = Vector2(0,0)
		offset_b.x = hyper_point_b.point.x
		offset_b.y = hyper_point_b.point.y
		
		#Point generation math
		var calc_point_a = Vector2(0,0)
		calc_point_a.x = ((2.0*pow(progress, 3.0))-(3.0*pow(progress, 2.0))+1.0)*(hyper_point_a.point.x)
		calc_point_a.y = ((2.0*pow(progress, 3.0))-(3.0*pow(progress, 2.0))+1.0)*(hyper_point_a.point.y)
		var calc_point_b = Vector2(0,0)
		calc_point_b.x = ((-2.0*pow(progress, 3.0))+(3.0*pow(progress, 2.0)))*(hyper_point_b.point.x)
		calc_point_b.y = ((-2.0*pow(progress, 3.0))+(3.0*pow(progress, 2.0)))*(hyper_point_b.point.y)
		var calc_control_a = Vector2(0,0)
		calc_control_a.x = ((pow(progress, 3.0))-(2.0*pow(progress, 2.0))+progress)*(hyper_point_a.control_post.x-offset_a.x)*2
		calc_control_a.y = ((pow(progress, 3.0))-(2.0*pow(progress, 2.0))+progress)*(hyper_point_a.control_post.y-offset_a.y)*2
		var calc_control_b = Vector2(0,0)
		calc_control_b.x = ((pow(progress, 3.0))-(pow(progress, 2.0)))*-(hyper_point_b.control_past.x-offset_b.x)*2
		calc_control_b.y = ((pow(progress, 3.0))-(pow(progress, 2.0)))*-(hyper_point_b.control_past.y-offset_b.y)*2
		
		#Construct point
		var product = Vector2(0,0)
		product.x = (calc_point_a.x + calc_point_b.x + calc_control_a.x + calc_control_b.x)
		product.y = (calc_point_a.y + calc_point_b.y + calc_control_a.y + calc_control_b.y)
		
		return product
		
func bake_curve(hyper_point_index):
	"""
	Creates a curve for every hyper point and adds it to the hyper point
	"""
	if name != "":
		var baked_curve = PoolVector2Array()
		#Get post and past hyper poi
		hyper_point_index = wrapi(hyper_point_index, 0, hyper_point_arr.size())
		var post_point_index = 0
		if hyper_point_arr.size() > 1:
			post_point_index = wrapi(hyper_point_index+1, 0, hyper_point_arr.size())
		var curr_hyp_point = hyper_point_arr[hyper_point_index]
		var post_hyp_point = hyper_point_arr[post_point_index]
		#Add current point
		#baked_curve.append(curr_hyp_point.point)
		#Add points in curve
		if hyper_point_arr.size() > 1 and (curr_hyp_point.point != curr_hyp_point.control_post or post_hyp_point.point != post_hyp_point.control_past):
			for pos in generate_curve(curr_hyp_point, post_hyp_point):
				baked_curve.append(pos)
		#Set hyper point's baked curve
		curr_hyp_point.baked_curve = baked_curve
				
func get_image_section(tile_name, image_get_mode = 0):
	if name != "" and tile_set != null:
		#Get tileset texture information
		var tile_image_index = tile_set.find_tile_by_name(tile_name)
		var tile_image = tile_set.tile_get_texture(tile_image_index)
		if image_get_mode == 1:
			tile_image = tile_set.tile_get_normal_map(tile_image_index)
		var tile_image_region = tile_set.tile_get_region(tile_image_index)
		#Get image data
		var image = tile_image.get_data()
		tile_image_region.position.y += image.get_height()-tile_image.get_height()
		var image_section = image.get_rect( tile_image_region )
		#Offset image
		if tile_name != body_tile_name:
			image_section.flip_y()
			image_section.crop(tile_image_region.size.x, tile_image_region.size.y*2)
			image_section.flip_y()
		#Create texture from image and return
		var texture = ImageTexture.new()
		texture.create_from_image(image_section)
		texture.set_flags(texture.FLAG_REPEAT)
		return texture
		
	return null
		
func get_point_angle(hyper_index):
	"""
	Get the difference in angle between hyper_index line and the previous hyper_point
	"""
	if hyper_point_arr.size() > 2:
		#Get past and post indexes
		var hyper_index_past = wrapi(hyper_index-1, 0, hyper_point_arr.size())
		var hyper_index_post = wrapi(hyper_index+1, 0, hyper_point_arr.size())
		#Initialise angle
		var line_angle = wrapf(hyper_point_arr[hyper_index].point.angle_to_point(hyper_point_arr[hyper_index_post].point), -PI, PI)
		var past_line_angle = 0
		var curr_line_angle = 0
		#Get past line angle
		var baked_curve_past = hyper_point_arr[hyper_index_past].baked_curve
		if baked_curve_past.size() > 0: #Get angle from point to previouse baked point
			past_line_angle = hyper_point_arr[hyper_index].point.angle_to_point(baked_curve_past[baked_curve_past.size()-1])
		else: #Get angle from point to previouse point
			past_line_angle = hyper_point_arr[hyper_index].point.angle_to_point(hyper_point_arr[hyper_index_past].point)
		#Get current line angle
		var baked_curve_pres = hyper_point_arr[hyper_index].baked_curve
		if baked_curve_pres.size() > 0: #Get angle from point to previouse baked point
			curr_line_angle = hyper_point_arr[hyper_index].point.angle_to_point(baked_curve_pres[0])
		else: #Get angle from point to previouse point
			curr_line_angle = hyper_point_arr[hyper_index].point.angle_to_point(hyper_point_arr[hyper_index_post].point)
		
		#Get difference between current point
		var ang_diff = wrapf((curr_line_angle + PI)-past_line_angle, -PI, PI)
		
		return ang_diff
		
func create_edge_instance(hyper_point_index):
	"""
	Create a Line2D instance with proper settings for edge
	"""
	#Remove edge instances from self
	if hyper_point_arr[hyper_point_index].edge_instance != null and hyper_point_arr[hyper_point_index].edge_instance.get_parent() != null:
		remove_child(hyper_point_arr[hyper_point_index].edge_instance)
	#Create new instances
	hyper_point_arr[hyper_point_index].edge_instance = line_2d_ref.duplicate()
	hyper_point_arr[hyper_point_index].edge_instance.set_name("EdgeLine"+str(hyper_point_index))
	hyper_point_arr[hyper_point_index].edge_instance.set_default_color(Color(1,1,1))
	hyper_point_arr[hyper_point_index].edge_instance.set_joint_mode(1)
	hyper_point_arr[hyper_point_index].edge_instance.show_behind_parent = true
	
func update_polygon_body():
	"""
	Updates the shape of the polygon
	"""
	var root_node = get_tree().get_edited_scene_root()
	add_polygon_instance()
	#Get point for polygon
	var baked_polygon = PoolVector2Array()
	for hyper_index in range(hyper_point_arr.size()):
		baked_polygon.append(hyper_point_arr[hyper_index].point)
		if hyper_point_arr[hyper_index].baked_curve.size() > 0:
			for point in hyper_point_arr[hyper_index].baked_curve:
				baked_polygon.append(point)
	#Set polygon points
	polygon_2d_inst.set_polygon(baked_polygon)
	col_poly_inst.set_polygon(baked_polygon)
	
func update_polygon_texture():
	"""
	Update the texture on the polygon
	"""
	#Create polygon
	var polygon_image = get_image_section(body_tile_name)
	if polygon_image != null:
		polygon_2d_inst.set_texture(polygon_image)
	
func update_edge_image(hyper_index):
	"""
	Update the texture for the specified line
	"""
	var image = get_image_section(hyper_point_arr[hyper_index].edge_image_index)
	hyper_point_arr[hyper_index].edge_instance.set_texture(image)
	hyper_point_arr[hyper_index].edge_instance.set_width(image.get_height())
	
func add_polygon_instance():
	var poly_name = "Polygon2D"
	if get_node(poly_name) == null:
		#Add new line instance
		if polygon_2d_inst.get_parent() == null:
			add_child(polygon_2d_inst)
			polygon_2d_inst.set_z_index(-5)
			polygon_2d_inst.set_name("Polygon2D")
			polygon_2d_inst.set_owner( get_tree().get_edited_scene_root() )
	else:
		#Get the already added line object
		polygon_2d_inst = get_node(poly_name)
	
func add_line_instance(hyper_index):
	var line_name = "EdgeLine"+str(hyper_index)
	if get_node(line_name) == null:
		#Add new line instance
		if hyper_point_arr[hyper_index].edge_instance.get_parent() == null:
			add_child(hyper_point_arr[hyper_index].edge_instance)
			hyper_point_arr[hyper_index].edge_instance.set_owner( get_tree().get_edited_scene_root() )
	else:
		#Get the already added line object
		hyper_point_arr[hyper_index].edge_instance = get_node(line_name)
		
func add_collision_instance():
	if Engine.is_editor_hint():
		var line_name = get_name()+"-CollisionPolygon2D"
		if get_node("../"+line_name) == null:
			#Add collision shape
			if col_poly_inst.get_parent() == null and get_tree() != null:
				var root_node = get_tree().get_edited_scene_root()
				col_poly_inst.set_name(get_name() + "-CollisionPolygon2D")
				col_poly_inst.hide()
				get_parent().add_child( col_poly_inst )
				col_poly_inst.set_owner( root_node )
		else:
			#Get already existing collision shape
			col_poly_inst = get_node("../"+line_name)
		
func bake_polygon():
	"""
	Updates the visuals of the entire terrain
	"""
	if name != "":
		update_polygon_texture()
		#Remove chlidren
		#remove_children()
		for hyper_index in range(hyper_point_arr.size()):
			#Create edge instances
			create_edge_instance(hyper_index)
			if hyper_index == 0: #Create instance of final line if starting polygon
				create_edge_instance(hyper_point_arr.size()-1)
			#Update edge lines
			update_edge_lines(hyper_index)
		update_polygon_body()
		
func remove_children():
	"""
	Removes and line edges, polygons, other nodes 
	"""
	remove_child(polygon_2d_inst)
	for hyper_point in hyper_point_arr:
		remove_child(hyper_point.edge_instance)
	for child in get_children():
		child.queue_free()
		
func update_edge_lines(hyper_index):
	hyper_index = wrapi(hyper_index, 0, hyper_point_arr.size())
	var hyper_index_past = 0
	var hyper_index_post = 0
	if hyper_point_arr.size() > 1:
		hyper_index_past = wrapi(hyper_index-1, 0, hyper_point_arr.size())
		hyper_index_post = wrapi(hyper_index+1, 0, hyper_point_arr.size())
		
	#Add edge line
	if hyper_point_arr.size() > 2:
		if poly_build_dir == "clockwise":
			var line_angle = wrapf(hyper_point_arr[hyper_index].point.angle_to_point(hyper_point_arr[hyper_index_post].point), -PI, PI)
			#Calculate edge index
			if not hyper_point_arr[hyper_index].edge_image_locked:
				var anylising_line = wrapf(line_angle-(PI), -PI, PI)
				if anylising_line <= PI/4 and anylising_line >= -PI/4: #Top edge
					hyper_point_arr[hyper_index].edge_image_index = top_edge_tile_name
				elif anylising_line >= (-PI)+(PI/4) and anylising_line <= -PI/4: #Left edge
					hyper_point_arr[hyper_index].edge_image_index = left_edge_tile_name
				elif anylising_line <= (PI)-(PI/4) and anylising_line >= PI/4: #Right edge
					hyper_point_arr[hyper_index].edge_image_index = right_edge_tile_name
				else:# anylising_line >= PI-(PI/4) and anylising_line <= -PI-(PI/4): #Bottom edge
					hyper_point_arr[hyper_index].edge_image_index = bottom_edge_tile_name
			#Set line texture
			var line_texture = get_image_section(hyper_point_arr[hyper_index].edge_image_index)
			if line_texture != null:
				hyper_point_arr[hyper_index].edge_instance.set_texture(line_texture)
				hyper_point_arr[hyper_index].edge_instance.set_width(line_texture.get_height())
			#Set line z-index
			hyper_point_arr[hyper_index].edge_instance.set_z_as_relative(false)
			if hyper_point_arr[hyper_index].edge_image_index == top_edge_tile_name:
				hyper_point_arr[hyper_index].edge_instance.set_z_index(-1)
			elif hyper_point_arr[hyper_index].edge_image_index == bottom_edge_tile_name:
				hyper_point_arr[hyper_index].edge_instance.set_z_index(-2)
			elif hyper_point_arr[hyper_index].edge_image_index == left_edge_tile_name:
				hyper_point_arr[hyper_index].edge_instance.set_z_index(-3)
			elif hyper_point_arr[hyper_index].edge_image_index == right_edge_tile_name:
				hyper_point_arr[hyper_index].edge_instance.set_z_index(-4)
			#Set line variables
			hyper_point_arr[hyper_index].edge_instance.set_texture_mode(1)
			
			# ===== Create and add edge line instances =====
			#Get line points
			var point_arr = Array(hyper_point_arr[hyper_index].baked_curve)
			point_arr.push_front(hyper_point_arr[hyper_index].point)
			#Add point from this line to the previouse line 
			var self_point = hyper_point_arr[hyper_index].point
			#Get point of next hyper point
			point_arr.push_back(hyper_point_arr[hyper_index_post].point)
			#Set line points
			hyper_point_arr[hyper_index].edge_instance.set_points(point_arr)
			# ===== Decide line edge caps =====
			var past_line_angle = 0
			var curr_line_angle = 0
			#Get current line angle
			var baked_curve_pres = hyper_point_arr[hyper_index].baked_curve
			if baked_curve_pres.size() > 0: #Get angle from point to previouse baked point
				curr_line_angle = hyper_point_arr[hyper_index].point.angle_to_point(baked_curve_pres[0])
			else: #Get angle from point to previouse point
				curr_line_angle = hyper_point_arr[hyper_index].point.angle_to_point(hyper_point_arr[hyper_index_post].point)
			#Get past line angle
			var baked_curve_past = hyper_point_arr[hyper_index_past].baked_curve
			if baked_curve_past.size() > 0: #Get angle from point to previouse baked point
				past_line_angle = hyper_point_arr[hyper_index].point.angle_to_point(baked_curve_past[baked_curve_past.size()-1])
			else: #Get angle from point to previouse point
				past_line_angle = hyper_point_arr[hyper_index].point.angle_to_point(hyper_point_arr[hyper_index_past].point)
			#Get difference between current point
			var ang_diff = wrapf((curr_line_angle + PI)-past_line_angle, -PI, PI)
			#Set the end cap mode
			if ang_diff < 0:
				hyper_point_arr[hyper_index_past].edge_instance.set_end_cap_mode(2)
				hyper_point_arr[hyper_index].edge_instance.set_begin_cap_mode(2)
			else:
				hyper_point_arr[hyper_index_past].edge_instance.set_end_cap_mode(0)
				hyper_point_arr[hyper_index].edge_instance.set_begin_cap_mode(0)
			# ----- Decide line edge caps -----
			#Set line variables
			hyper_point_arr[hyper_index].edge_instance.set_texture_mode(1)
			hyper_point_arr[hyper_index].edge_instance.set_default_color(Color(1,1,1))
			#Add line
			add_line_instance(hyper_index)
			#Run loop last time for first point again
			if hyper_index == hyper_point_arr.size()-1: #If current hyper point is last in list
				###Edge instance is new instance and needs to be added
				#Get line points
				var new_point_arr = Array(hyper_point_arr[hyper_index].baked_curve)
				new_point_arr.push_front(hyper_point_arr[hyper_index].point)
				#Checking array size here is redundent
				new_point_arr.push_back(hyper_point_arr[hyper_index_post].point)
				#Set line points
				hyper_point_arr[hyper_index].edge_instance.set_points(new_point_arr)
				# ===== Decide line edge caps =====
				past_line_angle = 0 #Already initialised
				curr_line_angle = 0 #Already initialised
				#Get current line angle
				baked_curve_pres = hyper_point_arr[hyper_index].baked_curve #Already intialised
				if baked_curve_pres.size() > 0: #Get angle from point to previouse baked point
					curr_line_angle = hyper_point_arr[hyper_index].point.angle_to_point(baked_curve_pres[0])
				else: #Get angle from point to previouse point
					curr_line_angle = hyper_point_arr[hyper_index].point.angle_to_point(hyper_point_arr[hyper_index_post].point)
				#Get past line angle
				baked_curve_past = hyper_point_arr[hyper_index_past].baked_curve #Already initialised
				if baked_curve_past.size() > 0: #Get angle from point to previouse baked point
					past_line_angle = hyper_point_arr[hyper_index].point.angle_to_point(baked_curve_past[baked_curve_past.size()-1])
				else: #Get angle from point to previouse point
					past_line_angle = hyper_point_arr[hyper_index].point.angle_to_point(hyper_point_arr[hyper_index_past].point)
				#Get difference between current point
				ang_diff = wrapf((curr_line_angle + PI)-past_line_angle, -PI, PI) #Already initialised
				#Set the end cap mode
				if ang_diff < 0:
					hyper_point_arr[hyper_index_past].edge_instance.set_end_cap_mode(2)
					hyper_point_arr[hyper_index].edge_instance.set_begin_cap_mode(2)
				else:
					hyper_point_arr[hyper_index_past].edge_instance.set_end_cap_mode(0)
					hyper_point_arr[hyper_index].edge_instance.set_begin_cap_mode(0)
				# ----- Decide line edge caps -----
				#Add line
				add_line_instance(hyper_index)
			# ------ Create and add edge line instances -----
			
func update_line_edge_culling(hyper_point_index):
	hyper_point_index = wrapi(hyper_point_index, 0, hyper_point_arr.size())
	if hyper_point_arr[hyper_point_index].edge_instance != null: #Point array has hyper_point_index
		#Get past and post indexes
		var hyper_point_past_index = wrapi(hyper_point_index-1, 0, hyper_point_arr.size() )
		var hyper_point_post_index = wrapi(hyper_point_index+1, 0, hyper_point_arr.size() )
		var hyper_point_post_post_index = wrapi(hyper_point_post_index+1, 0, hyper_point_arr.size())
		#Get previouse baked point
		var point_past = hyper_point_arr[hyper_point_past_index].point
		if hyper_point_arr[hyper_point_past_index].baked_curve.size() > 0:
			point_past = Array(hyper_point_arr[hyper_point_past_index].baked_curve).back()
		#Get post baked point
		var point_post = hyper_point_arr[hyper_point_post_index].point
		if hyper_point_arr[hyper_point_index].baked_curve.size() > 0:
			point_post = hyper_point_arr[hyper_point_index].baked_curve[0]
		#Get post post baked point
		var point_post_post = hyper_point_arr[hyper_point_post_index].point
		if hyper_point_arr[hyper_point_post_index].baked_curve.size() > 0:
			point_post_post = hyper_point_arr[hyper_point_post_index].baked_curve[0]
		#Get post first baked point
		var post_point_post = hyper_point_arr[hyper_point_post_post_index].point
		if hyper_point_arr[hyper_point_post_index].baked_curve.size() > 0:
			post_point_post = hyper_point_arr[hyper_point_post_index].baked_curve[0]
		#Get past point of post hyper point
		var post_point_past = hyper_point_arr[hyper_point_index].point
		if hyper_point_arr[hyper_point_index].baked_curve.size() > 0:
			post_point_past = Array(hyper_point_arr[hyper_point_index].baked_curve).back()
		#var hyper_point_post_post = hyper_point_arr[hyper_point_post_point_index].point
		var hyp_point = hyper_point_arr[hyper_point_index].point
		var hyp_point_post = hyper_point_arr[hyper_point_post_index].point
		#Set point begin
		var line_angle = get_point_angle(hyper_point_index)
		if line_angle > PI/2:
			var product_begin = Vector2(point_past.x-hyp_point.x, point_past.y-hyp_point.y)
			product_begin = product_begin.rotated(-hyp_point.angle_to_point(point_post))
			product_begin.x *= -1
			product_begin.y *= -1
			line_material.set_shader_param("point_begin", product_begin) 
			line_material.set_shader_param("will_cull_begin", true) 
		else:
			line_material.set_shader_param("will_cull_begin", false) 
		#Set point end
		var line_angle_post = get_point_angle(hyper_point_post_index)
		if line_angle_post > PI/2:
			var product_end = Vector2(post_point_past.x-hyp_point_post.x, post_point_past.y-hyp_point_post.y)
			product_end = product_end.rotated(-hyp_point_post.angle_to_point(post_point_post))
			product_end.x *= 1
			product_end.y *= 1
			line_material.set_shader_param("point_end", product_end)
			line_material.set_shader_param("will_cull_end", true) 
		else:
			line_material.set_shader_param("will_cull_end", false) 
		#Set line length
		#Get length of curve
		var baked_curve = Array(hyper_point_arr[hyper_point_index].baked_curve)
		var curve_length = 0
		if baked_curve.size() > 0:
			curve_length += hyp_point.distance_to(baked_curve[0])
			for i in range(baked_curve.size()):
				if i != 0:
					curve_length += baked_curve[i-1].distance_to(baked_curve[i])
			curve_length += baked_curve.back().distance_to(hyp_point_post)
		else:
			curve_length = hyp_point.distance_to(hyp_point_post)
		#Set marerials's line length
		var edge_texture = hyper_point_arr[hyper_point_index].edge_instance.get_texture()
		if edge_texture != null:
			var line_image_repetition = curve_length/(edge_texture.get_width())
			line_material.set_shader_param("line_length", line_image_repetition)
		#Set bits
		if hyper_point_arr[hyper_point_index].edge_instance.get_begin_cap_mode() != 0:
			line_material.set_shader_param("has_begin_cap", true)
		else:
			line_material.set_shader_param("has_begin_cap", false)
		#Set line material
		hyper_point_arr[hyper_point_index].edge_instance.set_material(line_material.duplicate())
	
func update_polygon_add_point(index):
	"""
	Update the polygon at a specific index when a new point is added
	"""
	#Get past and post hyper points
	var index_past = 0
	var index_past_past = 0
	var index_post = 0
	if hyper_point_arr.size() > 1:
		index_past = wrapi(index-1, 0, hyper_point_arr.size())
		index_post = wrapi(index+1, 0, hyper_point_arr.size())
		if hyper_point_arr.size() > 2:
			index_past_past = wrapi(index-2, 0, hyper_point_arr.size())
	
	#Update line
	bake_curve(index)
	update_line_midpoint(index)
		
	#Update visuals
	create_edge_instance(index) #Set hyper point's edge instance
	update_polygon_texture()
	
	#Update polygon points
	if index == 2: #Update whole polygon
		bake_polygon()
	elif index > 2: #Update edited piece of polygon
		update_edge_lines(index_past)
		update_edge_lines(index)
		#Update line edge culling
		update_line_edge_culling(index_past_past)
		update_line_edge_culling(index_past)
		update_line_edge_culling(index)
		update_line_edge_culling(index_post)
			
	update_polygon_body()
		
	#Set line instance's owner
	hyper_point_arr[index].edge_instance.set_owner( get_tree().get_edited_scene_root() )
	
func update_polygon_move_point(index, point_type):
	"""
	Update the polygon at a specific index when a point is moved
	"""
	if hyper_point_arr.size() > 1:
		#Get past and post hyper points
		var index_past = 0
		var index_past_past = 0
		var index_post = 0
		if hyper_point_arr.size() > 1:
			index_past = wrapi(index-1, 0, hyper_point_arr.size())
			index_post = wrapi(index+1, 0, hyper_point_arr.size())
			if hyper_point_arr.size() > 2:
				index_past_past = wrapi(index-2, 0, hyper_point_arr.size())
		###Update visuals###
		#Update line curve
		bake_curve(index_past)
		if not hyper_point_arr[index_post][point_type+"_selected"]: #Don't update this point if next point is selected
			bake_curve(index)
		#Update edge line
		update_line_midpoint(index)
		update_edge_lines(index_past)
		if not hyper_point_arr[index_post][point_type+"_selected"]: #Don't update current point if next is selected
			update_edge_lines(index)
		if not hyper_point_arr[index_post][point_type+"_selected"]: #Don't update next point if next is selected
			update_edge_lines(index_post)
		#Update line edge culling
		if hyper_point_arr.size() > 2:
			update_line_edge_culling(index_past_past)
			update_line_edge_culling(index_past)
			update_line_edge_culling(index)
			if not hyper_point_arr[index_post][point_type+"_selected"]: #Don't update next point if it's selected
				update_line_edge_culling(index_post)
		#Update polygon
		update_polygon_body()
		
func update_polygon_remove_point(index):
	"""
	Update the polygon at a specific index when a point is removed
	"""
	if hyper_point_arr.size() > 1:
		#Get past and post hyper points
		var index_past = 0
		var index_past_past = 0
		var index_post = 0
		if hyper_point_arr.size() > 1:
			index_past = wrapi(index-1, 0, hyper_point_arr.size())
			index_post = wrapi(index+1, 0, hyper_point_arr.size())
			if hyper_point_arr.size() > 2:
				index_past_past = wrapi(index-2, 0, hyper_point_arr.size())
		#Bake curve
		bake_curve(wrapi(index-1, 0, hyper_point_arr.size() ))
		bake_curve(index)
		#Update midpoints
		update_line_midpoint(index)
		update_line_midpoint(index_past)
		update_line_midpoint(index_post)
		#Update edge line visuals
		update_edge_lines(index_past)
		update_edge_lines(index)
		#Update line edge culling
		if hyper_point_arr.size() > 2:
			update_line_edge_culling(index_past_past)
			update_line_edge_culling(index_past)
			update_line_edge_culling(index)
			update_line_edge_culling(index_post)
		#Update polygon
		update_polygon_body()
	
func point_selected(is_selected, index, point_type):
	hyper_point_arr[index][point_type+"_selected"] = is_selected
	selected_line_idx = index
func deselect_points():
	for hype in hyper_point_arr:
		hype["point"+"_selected"] = false
		hype["control_post"+"_selected"] = false
		hype["control_past"+"_selected"] = false
		
func add_point(point_position, index = -1):
	"""
	Adds a hyper point to the hyper polygon. This function is called from the add_point setget function
	"""
	if name != "":
		if index == -1:
			if hyper_point_arr.size() > 0:
				index = hyper_point_arr.size()
			else:
				index = 0
				
		#Increment all *point indexes* ahead of *added position* forward by one
		var counter = index
		while counter < hyper_point_arr.size():
			var hyper_poly_index = ((hyper_point_arr.size()-1)-counter)+index #Invert index to start from the end of the list
			#Rename edge instance
			if hyper_poly_index >= index:
				hyper_point_arr[hyper_poly_index].edge_instance.set_name("EdgeLine"+str(hyper_poly_index+1))
			counter += 1
				
		#Get past and post hyper points
		var index_past = 0
		var index_post = 0
		if hyper_point_arr.size() > 1:
			index_past = wrapi(index-1, 0, hyper_point_arr.size())
			index_post = wrapi(index+1, 0, hyper_point_arr.size())
		
		#Add point
		var new_point = hyper_point_ref.duplicate()
		new_point.point = point_position
		new_point.control_post = point_position
		new_point.control_past = point_position
		hyper_point_arr.insert(index, new_point)
			
		#Reset control points of surrounding hyper points if added inside of polygon
		if hyper_point_arr.size() > 1:
			#Set point positions
			hyper_point_arr[index_past].control_post = hyper_point_arr[index_past].point
			hyper_point_arr[index_post].control_past = hyper_point_arr[index_post].point
			
		#Update lines
		update_polygon_add_point(index)
	
func move_point(new_point, index, point_type):
	if name != "":
		if point_type == "point":
			###Set control points relative to position to new_point's relative position
			#Get control point's relative positions
			var control_post_rel = Vector2(0,0)
			control_post_rel.x = hyper_point_arr[index].control_post.x-hyper_point_arr[index].point.x
			control_post_rel.y = hyper_point_arr[index].control_post.y-hyper_point_arr[index].point.y
			var control_past_rel = Vector2(0,0)
			control_past_rel.x = hyper_point_arr[index].control_past.x-hyper_point_arr[index].point.x
			control_past_rel.y = hyper_point_arr[index].control_past.y-hyper_point_arr[index].point.y
			#Create control point's new point
			var control_post_new = Vector2(0,0)
			control_post_new.x = new_point.x + control_post_rel.x
			control_post_new.y = new_point.y + control_post_rel.y
			var control_past_new = Vector2(0,0)
			control_past_new.x = new_point.x + control_past_rel.x
			control_past_new.y = new_point.y + control_past_rel.y
			#Set control points' new position 
			hyper_point_arr[index].control_post = control_post_new
			hyper_point_arr[index].control_past = control_past_new
			
		hyper_point_arr[index][point_type] = new_point
		
		update_polygon_move_point(index, point_type)
		
func remove_point(index, point_type):
	if name != "":
		if point_type == "point":
			#Remove line instance
			if weakref(hyper_point_arr[index].edge_instance) and hyper_point_arr[index].edge_instance.get_parent() != null:
				remove_child(hyper_point_arr[index].edge_instance)
			#Remove point
			hyper_point_arr.remove(index)
		if point_type == "control_post":
			hyper_point_arr[index].control_post = hyper_point_arr[index].point
		if point_type == "control_past":
			hyper_point_arr[index].control_past = hyper_point_arr[index].point
			
		#Increment all *point indexes* ahead of *added position* forward by one
		var counter = -index
		while counter < hyper_point_arr.size():
			#Rename edge instance
			hyper_point_arr[counter].edge_instance.set_name("EdgeLine"+str(counter))
			counter += 1
			
		update_polygon_remove_point(index)
	
func update_line_midpoint(hyper_point_index):
	if name != "":
		hyper_point_index = wrapi(hyper_point_index, 0, hyper_point_arr.size())
		#Get past and post hyper points
		var hyper_point_past_index = hyper_point_arr.size()-1
		var hyper_point_post_index = 0
		if hyper_point_index-1 >= 0:
			hyper_point_past_index = hyper_point_index-1
		if hyper_point_index+1 < hyper_point_arr.size():
			hyper_point_post_index = hyper_point_index+1
		#Generate midpoints
		hyper_point_arr[hyper_point_index].mid_point = generate_point(.5, hyper_point_arr[hyper_point_index], hyper_point_arr[hyper_point_post_index])
		hyper_point_arr[hyper_point_past_index].mid_point = generate_point(.5, hyper_point_arr[hyper_point_past_index], hyper_point_arr[hyper_point_index])
	
func _draw():
	if name != "" and Engine.is_editor_hint():
		var baked_points = PoolVector2Array()
		var counter = 0
		for hyper_point in hyper_point_arr:
			baked_points.append(hyper_point.point)
			for point in hyper_point.baked_curve:
				baked_points.append(point)
			#Get next point index
			var counter_post = 0
			if counter+1 < hyper_point_arr.size():
				counter_post = counter+1
			#Get previous point index
			var counter_past = hyper_point_arr.size()-1
			if hyper_point_arr.size() > 1:
				counter_past = wrapi(counter-1, 0, hyper_point_arr.size())
				
			#Draw selected line selecetion
			if counter == selected_line_idx:
				var baked_curve = hyper_point_arr[counter].baked_curve
				if baked_curve.size() == 0:
					draw_line( hyper_point_arr[counter].point, hyper_point_arr[counter_post].point, Color(0,1,0), 3 )
				else:
					draw_line( hyper_point_arr[counter].point, baked_curve[0], Color(0,1,0), 3 )
					for point_idx in range(baked_curve.size()):
						if point_idx != baked_curve.size()-1:
							draw_line( baked_curve[point_idx], baked_curve[wrapi(point_idx+1, 0, baked_curve.size())], Color(0,1,0), 3 )
					draw_line( baked_curve[baked_curve.size()-1], hyper_point_arr[counter_post].point, Color(0,1,0), 3 )
			#Controls point lines
			draw_line( hyper_point.point, hyper_point.control_past, Color(1,1,1), POINT_SIZE/3 )
			draw_line( hyper_point.point, hyper_point.control_post, Color(1,1,1), POINT_SIZE/3 )
			#Control point post drawing
			if hyper_point.control_post_selected:
				draw_circle( hyper_point.control_post, POINT_SIZE+1, Color(1,1,0) )
			draw_circle( hyper_point.control_post, POINT_SIZE, Color(0,1,0) )
			#Control point past drawing
			if hyper_point.control_past_selected:
				draw_circle( hyper_point.control_past, POINT_SIZE+1, Color(1,1,0) )
			draw_circle( hyper_point.control_past, POINT_SIZE, Color(0,0,1) )
			#Point drawing
			if hyper_point.point_selected:
				draw_circle( hyper_point.point, POINT_SIZE+1, Color(1,1,0) )
			draw_circle( hyper_point.point, POINT_SIZE, Color(1,0,0) )
			#Draw line midpoint
			draw_circle( hyper_point.mid_point, POINT_SIZE*.75, Color(1,1,1) )
			
			counter += 1
			
		if baked_points.size() > 1:
			for point_index in range(baked_points.size()):
				var point_post_index = wrapi(point_index+1, 0, baked_points.size())
				draw_line( baked_points[point_index], baked_points[point_post_index], Color(.5,.5,2), 1 )
		pass
		
### Signals ###
		
func _item_rect_changed():
	col_poly_inst.set_global_position( get_global_position() )
	
func _tree_exiting():
	col_poly_inst.remove_and_skip()
		
### Set get ###

func set_tile_set(val):
	tile_set = val
	if tile_set != null:
		update_polygon_texture()
		for hyper_index in range(hyper_point_arr.size()):
			update_edge_image(hyper_index)
			
func set_create_collision_shape(val):
	create_collision_shape = val
	if val:
		add_collision_instance()
	else:
		#Remove collision shape
		if col_poly_inst.get_parent() != null:
			get_parent().remove_child(col_poly_inst)
			

### Virtual function overides ###
func _get_property_list():
    return [
        {
            "name": "hyper_point_arr",
            "type": TYPE_ARRAY,
            "usage": PROPERTY_USAGE_STORAGE
        }
    ]
	
	
	
	
	