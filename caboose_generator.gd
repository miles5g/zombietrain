extends CSGCombiner3D

# Fired when player enters this car's gangway (from previous car) — used for spawn/despawn
signal player_reached_door
# Fired when player leaves gangway and enters main body (open door to next car) — start next wave here
signal player_entered_main_body

# --- Car Dimensions ---
# When true (first car only), use smaller caboose dimensions; otherwise normal train car
@export var is_caboose := false
var hull_size := Vector3(6.0, 5.5, 20.0) # (width, height, length); overridden in _ready if is_caboose
var wall_thickness := 0.2
var floor_thickness := 0.08  # thinner than walls
# Same thickness as walls for consistent look; must be >= wall_thickness and aligned with CSG
var roof_thickness := 0.2
# Small gangway flush between cars (short, narrow connector)
var gangway_length := 2.0
var gangway_width := 2.8
var gangway_height := hull_size.y

# Flicker: ~30% of cars get flickering lights (industrial, slightly "off")
var _ceiling_light: OmniLight3D
var _gw_light: OmniLight3D
var _flicker_enabled := false
var _flicker_t := 0.0
# Window spawn points and barriers (0-5 per window)
var barrier_counts: Array[int] = []
var _window_spawn_parent: Node3D
var _window_frames_parent: Node3D
var _barrier_visual_nodes: Array[Node3D] = []  # one node per window, each has 5 plank MeshInstance3D children
var _game_state: Node = null

func _ready() -> void:
	_game_state = get_node_or_null("/root/GameState")
	if is_caboose:
		hull_size = Vector3(5.0, 5.0, 14.0)  # smaller: caboose
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
	# Floor and roof can have different thicknesses; interior box leaves floor_thickness and roof_thickness
	var interior_size := Vector3(
		hull_size.x - wall_thickness * 2.0,
		hull_size.y - floor_thickness - roof_thickness,
		hull_size.z - wall_thickness * 2.0
	)
	var interior := CSGBox3D.new()
	interior.size = interior_size
	# In hull local space: center interior so remaining floor = floor_thickness, roof = roof_thickness
	interior.position = Vector3(0, (floor_thickness - roof_thickness) * 0.5, 0)
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
	var floor_top_y := floor_thickness
	var floor_center_y := floor_top_y * 0.5

	var floor_shape := CollisionShape3D.new()
	floor_shape.shape = BoxShape3D.new()
	floor_shape.shape.size = Vector3(hull_size.x, floor_thickness, hull_size.z)
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

	# Gangway: exact same floor level as main car (floor_top_y = floor_thickness); overlap Z so no crack
	var gangway_center_z := -hull_size.z * 0.5 - gangway_length * 0.5
	var gangway_floor_overlap := 0.25
	var gw_floor_len := gangway_length + gangway_floor_overlap
	var gw_floor_center_z := gangway_center_z + gangway_floor_overlap * 0.5
	var gangway_floor_shape := CollisionShape3D.new()
	gangway_floor_shape.shape = BoxShape3D.new()
	gangway_floor_shape.shape.size = Vector3(gangway_width, floor_thickness, gw_floor_len)
	gangway_floor_shape.position = Vector3(0, floor_center_y, gw_floor_center_z)
	body.add_child(gangway_floor_shape)

	add_child(body)

	# --- Gangway (small, flush connector: floor same level as main car, then walls, ceiling) ---
	var gangway_floor_mesh := MeshInstance3D.new()
	var gw_floor_box := BoxMesh.new()
	gw_floor_box.size = Vector3(gangway_width, floor_thickness, gw_floor_len)
	gangway_floor_mesh.mesh = gw_floor_box
	gangway_floor_mesh.position = Vector3(0, floor_center_y, gw_floor_center_z)
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
	var door_frame_mat := StandardMaterial3D.new()
	door_frame_mat.albedo_color = Color(0.12, 0.12, 0.14)
	door_frame_mat.metallic = 0.5
	for door_node in [door_prev, door_next]:
		var depth := 0.08
		var thick := 0.06
		var hw := gangway_width * 0.5
		var hh := gangway_height * 0.5
		var top := MeshInstance3D.new()
		top.mesh = BoxMesh.new()
		(top.mesh as BoxMesh).size = Vector3(depth, thick, gangway_width + thick * 2.0)
		top.position = Vector3(0, hh + thick * 0.5, 0)
		top.material_override = door_frame_mat
		door_node.add_child(top)
		var bot := MeshInstance3D.new()
		bot.mesh = BoxMesh.new()
		(bot.mesh as BoxMesh).size = Vector3(depth, thick, gangway_width + thick * 2.0)
		bot.position = Vector3(0, -hh - thick * 0.5, 0)
		bot.material_override = door_frame_mat
		door_node.add_child(bot)
		var left := MeshInstance3D.new()
		left.mesh = BoxMesh.new()
		(left.mesh as BoxMesh).size = Vector3(depth, gangway_height + thick * 2.0, thick)
		left.position = Vector3(0, 0, -hw - thick * 0.5)
		left.material_override = door_frame_mat
		door_node.add_child(left)
		var right := MeshInstance3D.new()
		right.mesh = BoxMesh.new()
		(right.mesh as BoxMesh).size = Vector3(depth, gangway_height + thick * 2.0, thick)
		right.position = Vector3(0, 0, hw + thick * 0.5)
		right.material_override = door_frame_mat
		door_node.add_child(right)
		var door_mat := StandardMaterial3D.new()
		door_mat.albedo_color = Color(0.2, 0.18, 0.16)
		var door_mesh := MeshInstance3D.new()
		door_mesh.mesh = BoxMesh.new()
		(door_mesh.mesh as BoxMesh).size = Vector3(depth * 0.5, gangway_height - 0.2, gangway_width - 0.2)
		door_mesh.material_override = door_mat
		door_node.add_child(door_mesh)
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
	# Safe zone area: when player is inside, GameState.is_in_safe_zone = true (no zombie attack)
	var safe_area := Area3D.new()
	safe_area.name = "SafeZoneArea"
	safe_area.position = Vector3(0, gangway_height * 0.5, 0)
	gangway_room.add_child(safe_area)
	var safe_shape := CollisionShape3D.new()
	safe_shape.shape = BoxShape3D.new()
	safe_shape.shape.size = Vector3(gangway_width * 1.2, gangway_height, gangway_length * 1.2)
	safe_area.add_child(safe_shape)
	safe_area.body_entered.connect(_on_safe_zone_body_entered)
	safe_area.body_exited.connect(_on_safe_zone_body_exited)

	_gw_light = OmniLight3D.new()
	_gw_light.name = "GangwayLight"
	_gw_light.light_energy = 1.0
	_gw_light.omni_range = 8.0
	_gw_light.position = Vector3(0, gangway_height - 0.5, gangway_center_z)
	add_child(_gw_light)

	# --- Interior Lighting (OmniLight at ceiling center) ---
	_ceiling_light = OmniLight3D.new()
	_ceiling_light.name = "CeilingLight"
	_ceiling_light.light_energy = 1.5
	_ceiling_light.omni_range = 15.0
	_ceiling_light.position = Vector3(0, hull_size.y - roof_thickness - 0.2, 0)
	add_child(_ceiling_light)
	_flicker_enabled = randf() < 0.3

	# --- Window spawn points (zombies enter only via windows); one Area3D per window for barrier placement ---
	_window_spawn_parent = Node3D.new()
	_window_spawn_parent.name = "WindowSpawnPoints"
	add_child(_window_spawn_parent)
	_window_frames_parent = Node3D.new()
	_window_frames_parent.name = "WindowFrames"
	add_child(_window_frames_parent)

	# --- Windows: smaller, square, centered on interior wall (well above floor) ---
	var window_size := Vector3(0.8, 0.8, 1.0)
	# Caboose space: floor top = floor_thickness; interior center so window sits clearly above floor
	var interior_height := hull_size.y - floor_thickness - roof_thickness
	var window_y_caboose := floor_thickness + interior_height * 0.5  # center of interior wall
	# Hull is at (0, hull_size.y*0.5, 0), so hull local y = caboose y - hull_size.y*0.5
	var window_y_hull_local := window_y_caboose - hull_size.y * 0.5

	# Door and window placement: doors at ends, windows centered strictly on side-wall sections
	var door_width := hull_size.x * 0.33
	var door_height := hull_size.y * 0.75
	# Deep enough that the subtraction fully cuts through the end wall (no invisible barrier)
	var door_thickness := 1.0
	var z_offset := (hull_size.z / 2.0) - (door_thickness * 0.5)

	# Floor is top of floor slab (y = floor_thickness); door bottom slightly below = seamless, no ledge
	var floor_height := floor_thickness
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

	# Window frame: visible dark metal/wood so the opening reads clearly
	var frame_mat := StandardMaterial3D.new()
	frame_mat.albedo_color = Color(0.14, 0.11, 0.09)
	frame_mat.roughness = 0.7
	frame_mat.metallic = 0.15
	# Pane: semi-transparent glass with slight sky tint and soft emission for "outside light"
	var pane_mat := StandardMaterial3D.new()
	pane_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	pane_mat.albedo_color = Color(0.42, 0.48, 0.58, 0.55)
	pane_mat.roughness = 0.25
	pane_mat.metallic = 0.05
	pane_mat.emission_enabled = true
	pane_mat.emission = Color(0.06, 0.07, 0.1)
	pane_mat.emission_energy_multiplier = 0.8
	# Dark reveal behind glass so the opening has depth
	var reveal_mat := StandardMaterial3D.new()
	reveal_mat.albedo_color = Color(0.05, 0.06, 0.08)
	reveal_mat.roughness = 1.0

	var window_index := 0
	for side in [-1, 1]:
		var x_offset := (hull_size.x * 0.5) - (wall_thickness * 0.5)
		for i in range(num_windows_per_side):
			var t := float(i) / (num_windows_per_side - 1) if num_windows_per_side > 1 else 0.5
			var window_z := lerpf(side_zone_start, side_zone_end, t)
			var window := CSGBox3D.new()
			window.size = window_size
			window.position = Vector3(side * x_offset, window_y_hull_local, window_z)
			window.operation = CSGShape3D.OPERATION_SUBTRACTION
			hull.add_child(window)
			# Interior window frame + pane so the hole reads as a window
			var frame_node := Node3D.new()
			frame_node.name = "WindowFrame_%d" % window_index
			frame_node.position = Vector3(side * x_offset - side * (wall_thickness * 0.5), window_y_caboose, window_z)
			var bar_depth := 0.08
			var bar_thick := 0.06
			var hw := window_size.z * 0.5
			var hh := window_size.y * 0.5
			# Top bar
			var top := MeshInstance3D.new()
			top.mesh = BoxMesh.new()
			(top.mesh as BoxMesh).size = Vector3(bar_depth, bar_thick, window_size.z + bar_thick * 2.0)
			top.position = Vector3(0, hh + bar_thick * 0.5, 0)
			top.material_override = frame_mat
			frame_node.add_child(top)
			var bot := MeshInstance3D.new()
			bot.mesh = BoxMesh.new()
			(bot.mesh as BoxMesh).size = Vector3(bar_depth, bar_thick, window_size.z + bar_thick * 2.0)
			bot.position = Vector3(0, -hh - bar_thick * 0.5, 0)
			bot.material_override = frame_mat
			frame_node.add_child(bot)
			var left := MeshInstance3D.new()
			left.mesh = BoxMesh.new()
			(left.mesh as BoxMesh).size = Vector3(bar_depth, window_size.y + bar_thick * 2.0, bar_thick)
			left.position = Vector3(0, 0, -hw - bar_thick * 0.5)
			left.material_override = frame_mat
			frame_node.add_child(left)
			var right := MeshInstance3D.new()
			right.mesh = BoxMesh.new()
			(right.mesh as BoxMesh).size = Vector3(bar_depth, window_size.y + bar_thick * 2.0, bar_thick)
			right.position = Vector3(0, 0, hw + bar_thick * 0.5)
			right.material_override = frame_mat
			frame_node.add_child(right)
			# Dark recess behind glass (depth)
			var pane_inner := window_size.y - bar_thick * 2.0
			var pane_inner_z := window_size.z - bar_thick * 2.0
			var reveal := MeshInstance3D.new()
			reveal.mesh = BoxMesh.new()
			(reveal.mesh as BoxMesh).size = Vector3(0.02, pane_inner, pane_inner_z)
			reveal.position = Vector3(-side * (bar_depth * 0.4), 0, 0)
			reveal.material_override = reveal_mat
			frame_node.add_child(reveal)
			var pane := MeshInstance3D.new()
			pane.mesh = BoxMesh.new()
			(pane.mesh as BoxMesh).size = Vector3(0.02, pane_inner, pane_inner_z)
			pane.position = Vector3(side * 0.01, 0, 0)
			pane.material_override = pane_mat
			frame_node.add_child(pane)
			# Barrier planks (0-5 visible)
			var barriers_node := Node3D.new()
			barriers_node.name = "Barriers"
			var plank_mat := StandardMaterial3D.new()
			plank_mat.albedo_color = Color(0.45, 0.28, 0.15)
			for p in range(5):
				var plank := MeshInstance3D.new()
				plank.name = "Plank_%d" % p
				plank.mesh = BoxMesh.new()
				(plank.mesh as BoxMesh).size = Vector3(0.04, 0.35, 0.08)
				plank.position = Vector3(side * 0.03, -0.2 + p * 0.18, 0.2 - (p % 2) * 0.1)
				plank.material_override = plank_mat
				plank.visible = false
				barriers_node.add_child(plank)
			frame_node.add_child(barriers_node)
			_barrier_visual_nodes.append(barriers_node)
			_window_frames_parent.add_child(frame_node)
			# Spawn point at window (zombies enter only via windows)
			var area := Area3D.new()
			area.name = "WindowSpawn_%d" % window_index
			area.position = Vector3(side * x_offset, window_y_caboose, window_z)
			var area_shape := CollisionShape3D.new()
			area_shape.shape = BoxShape3D.new()
			area_shape.shape.size = Vector3(1.2, 1.2, 0.5)
			area.add_child(area_shape)
			_window_spawn_parent.add_child(area)
			area.body_entered.connect(_on_window_body_entered.bind(window_index))
			area.body_exited.connect(_on_window_body_exited.bind(window_index))
			window_index += 1
	barrier_counts.resize(window_index)
	barrier_counts.fill(0)
	for wi in range(window_index):
		_refresh_barrier_visuals(wi)

	_setup_trigger()

	# --- End Doors last: so they definitely cut the collision shape (no invisible barrier) ---
	# Doors are children of hull → position in hull local space (hull center at 0, floor at -hull_size.y/2)
	var door_center_y_hull := door_center_y - hull_size.y * 0.5
	for door_z in [z_offset, -z_offset]:
		var door := CSGBox3D.new()
		door.size = door_size
		door.position = Vector3(0, door_center_y_hull, door_z)
		door.operation = CSGShape3D.OPERATION_SUBTRACTION
		hull.add_child(door)

func _setup_trigger() -> void:
	var gw_center_z := -hull_size.z * 0.5 - gangway_length * 0.5
	# Interior vertical center (for trigger boxes)
	var trigger_center_y := floor_thickness + (hull_size.y - floor_thickness - roof_thickness) * 0.5
	# 1) Entrance to gangway: when player enters from previous car → spawn next car, despawn oldest
	var entrance_area := Area3D.new()
	entrance_area.name = "GangwayEntranceTrigger"
	entrance_area.position = Vector3(0, trigger_center_y, gw_center_z + 1.0)
	add_child(entrance_area)
	var entrance_shape := CollisionShape3D.new()
	entrance_shape.shape = BoxShape3D.new()
	entrance_shape.shape.size = Vector3(gangway_width * 0.9, hull_size.y - floor_thickness - roof_thickness, gangway_length * 0.8)
	entrance_area.add_child(entrance_shape)
	entrance_area.body_entered.connect(_on_entered_gangway)

	# 2) Door to main body: when player leaves gangway and enters main car → next wave/level starts here
	var main_body_area := Area3D.new()
	main_body_area.name = "DoorToNextCarTrigger"
	main_body_area.position = Vector3(0, trigger_center_y, -hull_size.z * 0.5 + 1.5)
	add_child(main_body_area)
	var main_body_shape := CollisionShape3D.new()
	main_body_shape.shape = BoxShape3D.new()
	main_body_shape.shape.size = Vector3(gangway_width * 0.9, hull_size.y - floor_thickness - roof_thickness, 2.0)
	main_body_area.add_child(main_body_shape)
	main_body_area.body_entered.connect(_on_entered_main_body)

func _on_entered_gangway(body: Node3D) -> void:
	if body.name == "Player" and _game_state != null:
		_game_state.coins += 20
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

func _on_safe_zone_body_entered(body: Node3D) -> void:
	if body.name == "Player" and _game_state != null:
		_game_state.is_in_safe_zone = true

func _on_safe_zone_body_exited(body: Node3D) -> void:
	if body.name == "Player" and _game_state != null:
		_game_state.is_in_safe_zone = false

func _on_window_body_entered(body: Node3D, window_index: int) -> void:
	if body.name == "Player" and _game_state != null:
		_game_state.current_window_car = self
		_game_state.current_window_index = window_index

func _on_window_body_exited(body: Node3D, window_index: int) -> void:
	if body.name == "Player" and _game_state != null and _game_state.current_window_car == self and _game_state.current_window_index == window_index:
		_game_state.current_window_car = null
		_game_state.current_window_index = -1

func consume_barrier(window_index: int) -> void:
	if window_index >= 0 and window_index < barrier_counts.size() and barrier_counts[window_index] > 0:
		barrier_counts[window_index] -= 1
		_refresh_barrier_visuals(window_index)

func add_barrier(window_index: int) -> bool:
	if window_index < 0 or window_index >= barrier_counts.size():
		return false
	if barrier_counts[window_index] >= 5:
		return false
	barrier_counts[window_index] += 1
	_refresh_barrier_visuals(window_index)
	return true

func _refresh_barrier_visuals(window_index: int) -> void:
	if window_index < 0 or window_index >= _barrier_visual_nodes.size():
		return
	var node: Node3D = _barrier_visual_nodes[window_index]
	var n := barrier_counts[window_index]
	for i in range(5):
		node.get_child(i).visible = i < n

func get_barrier_count(window_index: int) -> int:
	if window_index < 0 or window_index >= barrier_counts.size():
		return 0
	return barrier_counts[window_index]

func get_window_spawn_points() -> Array[Node3D]:
	var out: Array[Node3D] = []
	for c in _window_spawn_parent.get_children():
		out.append(c as Node3D)
	return out

func _process(delta: float) -> void:
	if not _flicker_enabled:
		return
	_flicker_t += delta
	# Slight industrial flicker: modulate energy around base
	var flicker := 0.92 + 0.16 * (sin(_flicker_t * 18.0) * sin(_flicker_t * 7.0 + 1.0) + 1.0) * 0.5
	if _ceiling_light != null:
		_ceiling_light.light_energy = 1.5 * flicker
	if _gw_light != null:
		_gw_light.light_energy = 1.0 * flicker
