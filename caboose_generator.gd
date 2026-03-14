extends Node3D

signal player_reached_door

# --- Car Dimensions ---
var hull_size := Vector3(6.0, 4.0, 20.0) # (width, height, length)
var wall_thickness := 0.2

func _ready() -> void:
	# --- Hull (Outer Shell) ---
	var hull := CSGBox3D.new()
	hull.size = hull_size
	hull.position = Vector3(0, hull_size.y * 0.5, 0) # so floor sits at y=0
	hull.use_collision = true
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.13, 0.13, 0.16) # Slightly lighter than before (not 100% black)
	hull.material = mat
	add_child(hull)

	# --- Interior Subtraction (hollowing out except for floor & roof) ---
	var interior_size = Vector3(
		hull_size.x - wall_thickness * 2,
		hull_size.y - wall_thickness * 2,
		hull_size.z - wall_thickness * 2
	)
	var interior := CSGBox3D.new()
	interior.size = interior_size
	# Place so floor & roof have equal thickness:
	interior.position = Vector3(0, hull_size.y * 0.5, 0) 
	interior.operation = CSGShape3D.OPERATION_SUBTRACTION

	# --- Interior Material (Dark Gray, not black) ---
	var interior_mat := StandardMaterial3D.new()
	interior_mat.albedo_color = Color(0.16, 0.16, 0.18)
	interior.material = interior_mat

	hull.add_child(interior)
	
	# --- Add Roof (as a separate mesh/box) ---
	var roof := MeshInstance3D.new()
	var roof_mesh := BoxMesh.new()
	roof_mesh.size = Vector3(hull_size.x, wall_thickness, hull_size.z)
	roof.mesh = roof_mesh
	roof.position = Vector3(0, hull_size.y - (wall_thickness * 0.5), 0)
	var roof_mat := StandardMaterial3D.new()
	roof_mat.albedo_color = Color(0.13, 0.13, 0.15)
	roof.material_override = roof_mat
	add_child(roof)
	# Give roof collision
	var roof_collision := CollisionShape3D.new()
	roof_collision.shape = BoxShape3D.new()
	roof_collision.shape.size = Vector3(hull_size.x, wall_thickness, hull_size.z)
	roof_collision.position = Vector3(0, hull_size.y - (wall_thickness * 0.5), 0)
	add_child(roof_collision)
	
	# --- Interior Lighting (OmniLight at ceiling center) ---
	var ceiling_light := OmniLight3D.new()
	ceiling_light.light_energy = 1.5
	ceiling_light.omni_range = 15.0
	ceiling_light.position = Vector3(0, hull_size.y - wall_thickness - 0.2, 0)
	add_child(ceiling_light)

	# --- Windows (side cutouts), spaced along Z, at 'eye level', avoiding doors ---
	var player_eye_level := 1.5 # meters above ground
	var bench_height := 0.6     # meters, space beneath window for bench
	var window_clear_above_bench := 0.2 # extra gap above bench

	# Calculate window vertical placement: ideally just above the bench area, but still aesthetically spaced
	var window_bottom = bench_height + window_clear_above_bench
	var window_height = hull_size.y * 0.34
	var eye_level_y = window_bottom + (window_height * 0.5)

	# Ensure does not exceed hull
	var max_window_y = hull_size.y - wall_thickness - (window_height * 0.5) - 0.15
	var window_y = min(eye_level_y, max_window_y)
	var window_width = 1.05
	var window_length = 2.2

	# Calculate window count & placement so they do not overlap with doors
	var door_width = hull_size.x * 0.33
	var door_height = hull_size.y * 0.75
	var door_thickness = wall_thickness + 0.05
	var door_size = Vector3(door_width, door_height, door_thickness)
	var door_y = (door_height * 0.5) + (hull_size.y - door_height) * 0.5
	var z_offset = (hull_size.z/2) - (door_thickness*0.5)
	var door_edge_buffer = window_length * 0.6 # don't let windows overlap with doors

	var side_zone_start = -hull_size.z*0.5 + door_thickness + door_edge_buffer + window_length*0.5
	var side_zone_end   =  hull_size.z*0.5 - door_thickness - door_edge_buffer - window_length*0.5

	var num_windows_per_side = 3 # Default to 3, try 4 if spacing allows
	var side_zone_length = side_zone_end - side_zone_start
	if side_zone_length >= (window_length * 3.8): # favor 4 if there's room
		num_windows_per_side = 4

	# Place windows evenly in side zones
	for side in [-1, 1]: # left (-1) and right (+1)
		var x_offset = (hull_size.x * 0.5) - (wall_thickness * 0.5)
		for i in range(num_windows_per_side):
			var t = float(i)/(num_windows_per_side-1) if num_windows_per_side>1 else 0.5
			var window_z = lerp(side_zone_start, side_zone_end, t)
			var window := CSGBox3D.new()
			window.size = Vector3(window_width, window_height, window_length)
			window.position = Vector3(side * x_offset, window_y, window_z)
			window.operation = CSGShape3D.OPERATION_SUBTRACTION
			hull.add_child(window)

	# --- End Doors (front & back), size relative to hull height ---
	for door_z in [z_offset, -z_offset]:
		var door := CSGBox3D.new()
		door.size = door_size
		door.position = Vector3(0, door_y, door_z)
		door.operation = CSGShape3D.OPERATION_SUBTRACTION
		hull.add_child(door)

	_setup_trigger()

func _setup_trigger() -> void:
	var area := Area3D.new()
	area.position = Vector3(0, hull_size.y * 0.5, hull_size.z * 0.5 - 0.5)
	add_child(area)
	var shape := CollisionShape3D.new()
	shape.shape = BoxShape3D.new()
	shape.shape.size = Vector3(hull_size.x * 0.67, hull_size.y, 1)
	area.add_child(shape)
	area.body_entered.connect(func(body):
		if body.name == "Player":
			player_reached_door.emit()
			area.queue_free()
	)
