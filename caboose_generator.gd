extends CSGCombiner3D

# Fired when player enters this car's gangway (from previous car) — used for spawn/despawn
signal player_reached_door
# Fired when player leaves gangway and enters main body (open door to next car) — start next wave here
signal player_entered_main_body

# --- Car Dimensions ---
var hull_size := Vector3(6.0, 4.0, 20.0) # (width, height, length)
var wall_thickness := 0.2
# Thicker roof so player doesn't clip through; must be >= wall_thickness and aligned with CSG
var roof_thickness := 0.4
# Small gangway flush between cars (short, narrow connector)
var gangway_length := 2.0
var gangway_width := 2.8
var gangway_height := hull_size.y

func _ready() -> void:
	# CSG collision often doesn't subtract doors reliably, causing an invisible wall.
	# Use explicit collision instead: floor, roof, and side walls only (no end walls = open doorways).
	use_collision = false

	# --- Hull (Outer Shell) ---
	var hull := CSGBox3D.new()
	hull.name = "Hull"
	hull.size = hull_size
	hull.position = Vector3(0, hull_size.y * 0.5, 0) # so floor sits at y=0
	hull.use_collision = false
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.13, 0.13, 0.16) # Slightly lighter than before (not 100% black)
	hull.material = mat
	add_child(hull)

	# --- Interior Subtraction (hollowing out except for floor & roof) ---
	# Use exact centered math so there are no ghost holes in the collision
	var interior_size := Vector3(
		hull_size.x - wall_thickness * 2.0,
		hull_size.y - wall_thickness * 2.0,
		hull_size.z - wall_thickness * 2.0
	)
	var interior := CSGBox3D.new()
	interior.size = interior_size
	interior.position = Vector3(0, hull_size.y * 0.5, 0)  # same center as hull = symmetric floor/roof
	interior.operation = CSGShape3D.OPERATION_SUBTRACTION

	# --- Interior Material (Dark Gray, not black) ---
	var interior_mat := StandardMaterial3D.new()
	interior_mat.albedo_color = Color(0.16, 0.16, 0.18)
	interior.material = interior_mat

	hull.add_child(interior)
	
	# --- Add Roof (thicker than wall to prevent player clipping) ---
	var roof_center_y := hull_size.y - roof_thickness * 0.5
	var roof := MeshInstance3D.new()
	var roof_mesh := BoxMesh.new()
	roof_mesh.size = Vector3(hull_size.x, roof_thickness, hull_size.z)
	roof.mesh = roof_mesh
	roof.position = Vector3(0, roof_center_y, 0)
	var roof_mat := StandardMaterial3D.new()
	roof_mat.albedo_color = Color(0.13, 0.13, 0.15)
	roof.material_override = roof_mat
	add_child(roof)
	# --- Explicit collision (no CSG): floor, roof, side walls only — no end walls so doorways are open ---
	var body := StaticBody3D.new()
	body.name = "CarCollision"

	# Single floor level for whole car + gangway (top of slab = walkable surface)
	var floor_top_y := wall_thickness
	var floor_center_y := floor_top_y * 0.5

	var floor_shape := CollisionShape3D.new()
	floor_shape.shape = BoxShape3D.new()
	floor_shape.shape.size = Vector3(hull_size.x, wall_thickness, hull_size.z)
	floor_shape.position = Vector3(0, floor_center_y, 0)
	body.add_child(floor_shape)

	var roof_shape := CollisionShape3D.new()
	roof_shape.shape = BoxShape3D.new()
	roof_shape.shape.size = Vector3(hull_size.x, roof_thickness, hull_size.z)
	roof_shape.position = Vector3(0, roof_center_y, 0)
	body.add_child(roof_shape)

	var wall_y := hull_size.y * 0.5
	var wall_depth := wall_thickness
	var left_x := -hull_size.x * 0.5 + wall_depth * 0.5
	var right_x := hull_size.x * 0.5 - wall_depth * 0.5
	var left_wall := CollisionShape3D.new()
	left_wall.shape = BoxShape3D.new()
	left_wall.shape.size = Vector3(wall_depth, hull_size.y, hull_size.z)
	left_wall.position = Vector3(left_x, wall_y, 0)
	body.add_child(left_wall)
	var right_wall := CollisionShape3D.new()
	right_wall.shape = BoxShape3D.new()
	right_wall.shape.size = Vector3(wall_depth, hull_size.y, hull_size.z)
	right_wall.position = Vector3(right_x, wall_y, 0)
	body.add_child(right_wall)

	# Gangway: floor at same level as main car (floor_center_y)
	var gangway_center_z := -hull_size.z * 0.5 - gangway_length * 0.5
	var gangway_floor_shape := CollisionShape3D.new()
	gangway_floor_shape.shape = BoxShape3D.new()
	gangway_floor_shape.shape.size = Vector3(gangway_width, wall_thickness, gangway_length)
	gangway_floor_shape.position = Vector3(0, floor_center_y, gangway_center_z)
	body.add_child(gangway_floor_shape)

	add_child(body)

	# --- Gangway (small, flush connector: floor same level as main car, then walls, ceiling) ---
	var gangway_floor_mesh := MeshInstance3D.new()
	var gw_floor_box := BoxMesh.new()
	gw_floor_box.size = Vector3(gangway_width, wall_thickness, gangway_length)
	gangway_floor_mesh.mesh = gw_floor_box
	gangway_floor_mesh.position = Vector3(0, floor_center_y, gangway_center_z)
	var gw_floor_mat := StandardMaterial3D.new()
	gw_floor_mat.albedo_color = Color(0.12, 0.12, 0.14)
	gw_floor_mat.metallic = 0.15
	gangway_floor_mesh.material_override = gw_floor_mat
	add_child(gangway_floor_mesh)

	var gw_wall_mat := StandardMaterial3D.new()
	gw_wall_mat.albedo_color = Color(0.5, 0.5, 0.52)
	gw_wall_mat.metallic = 0.6
	gw_wall_mat.roughness = 0.4
	var gw_wall_depth := wall_thickness
	var gw_left := MeshInstance3D.new()
	gw_left.mesh = BoxMesh.new()
	(gw_left.mesh as BoxMesh).size = Vector3(gw_wall_depth, gangway_height, gangway_length)
	gw_left.position = Vector3(-gangway_width * 0.5 + gw_wall_depth * 0.5, gangway_height * 0.5, gangway_center_z)
	gw_left.material_override = gw_wall_mat
	add_child(gw_left)
	var gw_right := MeshInstance3D.new()
	gw_right.mesh = BoxMesh.new()
	(gw_right.mesh as BoxMesh).size = Vector3(gw_wall_depth, gangway_height, gangway_length)
	gw_right.position = Vector3(gangway_width * 0.5 - gw_wall_depth * 0.5, gangway_height * 0.5, gangway_center_z)
	gw_right.material_override = gw_wall_mat
	add_child(gw_right)

	var gw_ceiling := MeshInstance3D.new()
	gw_ceiling.mesh = BoxMesh.new()
	(gw_ceiling.mesh as BoxMesh).size = Vector3(gangway_width, roof_thickness, gangway_length)
	gw_ceiling.position = Vector3(0, gangway_height - roof_thickness * 0.5, gangway_center_z)
	var gw_ceiling_mat := StandardMaterial3D.new()
	gw_ceiling_mat.albedo_color = Color(0.45, 0.45, 0.48)
	gw_ceiling_mat.metallic = 0.5
	gw_ceiling.material_override = gw_ceiling_mat
	add_child(gw_ceiling)

	var gw_left_col := CollisionShape3D.new()
	gw_left_col.shape = BoxShape3D.new()
	gw_left_col.shape.size = Vector3(gw_wall_depth, gangway_height, gangway_length)
	gw_left_col.position = Vector3(-gangway_width * 0.5 + gw_wall_depth * 0.5, gangway_height * 0.5, gangway_center_z)
	body.add_child(gw_left_col)
	var gw_right_col := CollisionShape3D.new()
	gw_right_col.shape = BoxShape3D.new()
	gw_right_col.shape.size = Vector3(gw_wall_depth, gangway_height, gangway_length)
	gw_right_col.position = Vector3(gangway_width * 0.5 - gw_wall_depth * 0.5, gangway_height * 0.5, gangway_center_z)
	body.add_child(gw_right_col)

	# Placeholder nodes for doors and stations (add level-up, shop, safe-zone content as children)
	var gangway_room := Node3D.new()
	gangway_room.name = "GangwayRoom"
	gangway_room.position = Vector3(0, 0, gangway_center_z)
	add_child(gangway_room)
	var door_prev := Node3D.new()
	door_prev.name = "DoorToPreviousCar"
	door_prev.position = Vector3(0, gangway_height * 0.5, -gangway_length * 0.5)
	gangway_room.add_child(door_prev)
	var door_next := Node3D.new()
	door_next.name = "DoorToNextCar"
	door_next.position = Vector3(0, gangway_height * 0.5, gangway_length * 0.5)
	gangway_room.add_child(door_next)
	var level_up := Node3D.new()
	level_up.name = "LevelUpStation"
	level_up.position = Vector3(-gangway_width * 0.25, 1.0, 0)
	gangway_room.add_child(level_up)
	var weapon_shop := Node3D.new()
	weapon_shop.name = "WeaponShop"
	weapon_shop.position = Vector3(gangway_width * 0.25, 1.0, 0)
	gangway_room.add_child(weapon_shop)
	var safe_zone := Node3D.new()
	safe_zone.name = "SafeZone"
	safe_zone.position = Vector3(0, 0, 0)
	gangway_room.add_child(safe_zone)

	var gw_light := OmniLight3D.new()
	gw_light.light_energy = 1.0
	gw_light.omni_range = 8.0
	gw_light.position = Vector3(0, gangway_height - 0.5, gangway_center_z)
	add_child(gw_light)

	# --- Interior Lighting (OmniLight at ceiling center) ---
	var ceiling_light := OmniLight3D.new()
	ceiling_light.light_energy = 1.5
	ceiling_light.omni_range = 15.0
	ceiling_light.position = Vector3(0, hull_size.y - roof_thickness - 0.2, 0)
	add_child(ceiling_light)

	# --- Windows: smaller, square, centered on side-wall vertical midpoint ---
	var window_size := Vector3(0.8, 0.8, 1.0)
	var window_y := hull_size.y * 0.5  # vertical midpoint of wall

	# Door and window placement: doors at ends, windows centered strictly on side-wall sections
	var door_width := hull_size.x * 0.33
	var door_height := hull_size.y * 0.75
	# Deep enough that the subtraction fully cuts through the end wall (no invisible barrier)
	var door_thickness := 1.0
	var z_offset := (hull_size.z / 2.0) - (door_thickness * 0.5)

	# Floor is top of floor slab (y = wall_thickness); door bottom slightly below = seamless, no ledge
	var floor_height := wall_thickness
	var door_bottom := floor_height - 0.1
	var door_center_y := door_bottom + door_height * 0.5
	var door_size := Vector3(door_width, door_height, door_thickness)

	# Space windows well away from doors so they sit on the main side-wall sections
	var door_edge_buffer := 2.2
	var side_zone_start := -hull_size.z * 0.5 + door_thickness + door_edge_buffer + window_size.z * 0.5
	var side_zone_end := hull_size.z * 0.5 - door_thickness - door_edge_buffer - window_size.z * 0.5
	var side_zone_length := side_zone_end - side_zone_start
	var num_windows_per_side := 3
	if side_zone_length >= window_size.z * 3.5:
		num_windows_per_side = 4

	for side in [-1, 1]:
		var x_offset := (hull_size.x * 0.5) - (wall_thickness * 0.5)
		for i in range(num_windows_per_side):
			var t := float(i) / (num_windows_per_side - 1) if num_windows_per_side > 1 else 0.5
			var window_z := lerpf(side_zone_start, side_zone_end, t)
			var window := CSGBox3D.new()
			window.size = window_size
			window.position = Vector3(side * x_offset, window_y, window_z)
			window.operation = CSGShape3D.OPERATION_SUBTRACTION
			hull.add_child(window)

	_setup_trigger()

	# --- End Doors last: so they definitely cut the collision shape (no invisible barrier) ---
	for door_z in [z_offset, -z_offset]:
		var door := CSGBox3D.new()
		door.size = door_size
		door.position = Vector3(0, door_center_y, door_z)
		door.operation = CSGShape3D.OPERATION_SUBTRACTION
		hull.add_child(door)

func _setup_trigger() -> void:
	var gw_center_z := -hull_size.z * 0.5 - gangway_length * 0.5
	# 1) Entrance to gangway: when player enters from previous car → spawn next car, despawn oldest
	var entrance_area := Area3D.new()
	entrance_area.name = "GangwayEntranceTrigger"
	entrance_area.position = Vector3(0, hull_size.y * 0.5, gw_center_z + 1.0)
	add_child(entrance_area)
	var entrance_shape := CollisionShape3D.new()
	entrance_shape.shape = BoxShape3D.new()
	entrance_shape.shape.size = Vector3(gangway_width * 0.9, hull_size.y, gangway_length * 0.8)
	entrance_area.add_child(entrance_shape)
	entrance_area.body_entered.connect(_on_entered_gangway)

	# 2) Door to main body: when player leaves gangway and enters main car → next wave/level starts here
	var main_body_area := Area3D.new()
	main_body_area.name = "DoorToNextCarTrigger"
	main_body_area.position = Vector3(0, hull_size.y * 0.5, -hull_size.z * 0.5 + 1.5)
	add_child(main_body_area)
	var main_body_shape := CollisionShape3D.new()
	main_body_shape.shape = BoxShape3D.new()
	main_body_shape.shape.size = Vector3(gangway_width * 0.9, hull_size.y, 2.0)
	main_body_area.add_child(main_body_shape)
	main_body_area.body_entered.connect(_on_entered_main_body)

func _on_entered_gangway(body: Node3D) -> void:
	if body.name == "Player":
		player_reached_door.emit()
		for c in get_children():
			if c.name == "GangwayEntranceTrigger":
				c.queue_free()
				break

func _on_entered_main_body(body: Node3D) -> void:
	if body.name == "Player":
		player_entered_main_body.emit()
		for c in get_children():
			if c.name == "DoorToNextCarTrigger":
				c.queue_free()
				break
