extends CharacterBody3D

const WeaponDataScript = preload("res://resources/weapon_data.gd")
const SPEED := 5.0
const CROUCH_SPEED := 2.2
const SPRINT_SPEED := 8.0  # high-stakes: faster but e.g. louder for zombies later
const MOUSE_SENSITIVITY := 0.003
const PITCH_MIN := -80.0   # degrees
const PITCH_MAX := 80.0    # degrees
const STAND_HEIGHT := 2.0
const CROUCH_HEIGHT := 1.0
# Head (camera) Y position: stand vs crouch
const HEAD_STAND_Y := 1.7
const HEAD_CROUCH_Y := 1.0
const HEAD_LERP_SPEED := 10.0
# Variable jump: tap = min, hold = max; kept lower so head doesn't hit ceiling instantly
const MIN_JUMP_VELOCITY := 3.2
const MAX_JUMP_VELOCITY := 4.5
const JUMP_HOLD_TIME := 0.2
# Stronger gravity when falling so jump feels snappy, not floaty
const FALL_GRAVITY_MULTIPLIER := 2.5

var GRAVITY: float

@onready var head: Node3D = null
@onready var collision_shape: CollisionShape3D = $CollisionShape3D

var mouse_locked := true
var _standing_shape_height: float
var _jump_hold_timer := 0.0
var _melee_cooldown := 0.0
# Swing animation: 0 = idle, >0 = time left in current swing
var _swing_timer := 0.0
var _swing_duration := 0.0
var _weapon_pivot: Node3D = null
var _arms_pivot: Node3D = null
var _blocking := false  # melee block (right click held)
var _aiming := false   # gun aim (right click held); stub for later
var _last_weapon_id := ""  # to refresh weapon mesh when changed
var _game_state: Node = null

func _ready():
	_game_state = get_node_or_null("/root/GameState")
	add_to_group("player")
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	GRAVITY = ProjectSettings.get_setting("physics/3d/default_gravity") as float
	# Head (or Camera3D) for vertical look; use Camera3D if no Head node exists
	if has_node("Head"):
		head = get_node("Head")
	elif has_node("Camera3D"):
		head = get_node("Camera3D")
	else:
		print_debug("No Head or Camera3D found. Vertical mouse look will be disabled.")
	if head != null:
		head.position.y = HEAD_STAND_Y
	# Own copy of shape so we can change height for crouch
	if collision_shape != null and collision_shape.shape is CapsuleShape3D:
		collision_shape.shape = collision_shape.shape.duplicate()
		_standing_shape_height = (collision_shape.shape as CapsuleShape3D).height
	else:
		_standing_shape_height = STAND_HEIGHT

	# First-person arms + weapon pivot (arms move with swing/block)
	if head != null:
		_arms_pivot = Node3D.new()
		_arms_pivot.name = "ArmsPivot"
		_arms_pivot.position = Vector3(0.2, -0.15, -0.4)
		head.add_child(_arms_pivot)
		var skin_mat := StandardMaterial3D.new()
		skin_mat.albedo_color = Color(0.6, 0.45, 0.35)
		var left_arm := MeshInstance3D.new()
		left_arm.mesh = BoxMesh.new()
		(left_arm.mesh as BoxMesh).size = Vector3(0.08, 0.12, 0.25)
		left_arm.position = Vector3(-0.15, 0.02, -0.1)
		left_arm.rotation.z = deg_to_rad(10.0)
		left_arm.material_override = skin_mat
		_arms_pivot.add_child(left_arm)
		var right_arm := MeshInstance3D.new()
		right_arm.mesh = BoxMesh.new()
		(right_arm.mesh as BoxMesh).size = Vector3(0.08, 0.12, 0.28)
		right_arm.position = Vector3(0.15, 0.0, -0.12)
		right_arm.rotation.z = deg_to_rad(-8.0)
		right_arm.material_override = skin_mat
		_arms_pivot.add_child(right_arm)
		_weapon_pivot = Node3D.new()
		_weapon_pivot.name = "WeaponPivot"
		_weapon_pivot.position = Vector3(0.08, -0.05, -0.35)
		_arms_pivot.add_child(_weapon_pivot)
		_update_weapon_mesh()

	# Slightly larger safe_margin helps avoid tunneling through thin geometry (e.g. train roof)
	safe_margin = 0.1

	# --- PLAYER COLLISION SHAPE REMINDER ---
	# Make sure your player's CollisionShape3D is a CapsuleShape3D,
	# with radius = 0.4 and height = 1.8 in the Inspector.
	# This will help avoid getting stuck at train/hatch edges
	# when falling through holes.

func _unhandled_input(event):
	if event is InputEventMouseMotion and mouse_locked:
		# Horizontal: rotate Player on Y-axis (yaw)
		rotate_y(-event.relative.x * MOUSE_SENSITIVITY)
		# Vertical: rotate Head/Camera on X-axis only (pitch), clamped so you can't flip upside down
		if head != null:
			head.rotate_x(-event.relative.y * MOUSE_SENSITIVITY)
			head.rotation.x = clamp(head.rotation.x, deg_to_rad(PITCH_MIN), deg_to_rad(PITCH_MAX))
	elif event is InputEventKey:
		if event.pressed and event.keycode == KEY_ESCAPE:
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
			mouse_locked = false
		elif event.pressed and event.keycode == KEY_ENTER:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
			mouse_locked = true

func _process(delta: float) -> void:
	if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		mouse_locked = true
	# Refresh weapon mesh when equipped weapon changes (e.g. starter choice)
	if _weapon_pivot != null and GameState.current_weapon_id != _last_weapon_id:
		_last_weapon_id = GameState.current_weapon_id
		_update_weapon_mesh()
	# Swing/block: drive arms and weapon pivot together
	if _arms_pivot != null:
		_arms_pivot.visible = not GameState.current_weapon_id.is_empty()
	if _weapon_pivot != null:
		_weapon_pivot.visible = not GameState.current_weapon_id.is_empty()
	var pivot: Node3D = _arms_pivot if _arms_pivot != null else _weapon_pivot
	if pivot != null:
		if _swing_duration > 0.0 and _swing_timer > 0.0:
			_swing_timer -= delta
			if _swing_timer <= 0.0:
				_swing_timer = 0.0
				_swing_duration = 0.0
			else:
				var t := 1.0 - (_swing_timer / _swing_duration)
				pivot.rotation.x = -deg_to_rad(75.0) * sin(t * PI)
		elif _blocking:
			pivot.rotation.x = deg_to_rad(25.0)
		else:
			pivot.rotation.x = 0.0

func _physics_process(delta):
	# Use the built-in velocity from CharacterBody3D

	# Apply gravity; use stronger gravity when falling so jump feels snappier
	if not is_on_floor():
		var g: float = GRAVITY * delta
		if velocity.y < 0.0:
			g *= FALL_GRAVITY_MULTIPLIER
		velocity.y -= g
	else:
		velocity.y = 0.0

	# Crouch: collision height, speed, and lerp Head (camera) position down/up
	var crouching := Input.is_action_pressed("crouch")
	var sprinting := Input.is_action_pressed("sprint") and not crouching
	var move_speed: float = CROUCH_SPEED if crouching else (SPRINT_SPEED if sprinting else SPEED)
	if _blocking:
		move_speed *= 0.5
	if collision_shape != null and collision_shape.shape is CapsuleShape3D:
		var cap := collision_shape.shape as CapsuleShape3D
		if crouching:
			cap.height = CROUCH_HEIGHT
			collision_shape.position.y = (CROUCH_HEIGHT - _standing_shape_height) * 0.5
		else:
			cap.height = _standing_shape_height
			collision_shape.position.y = 0.0
	# Lerp Head/Camera Y: stand 1.7, crouch 1.0
	if head != null:
		var target_y := HEAD_CROUCH_Y if crouching else HEAD_STAND_Y
		head.position.y = lerpf(head.position.y, target_y, HEAD_LERP_SPEED * delta)

	# Variable jump: tap = MIN, hold = MAX for up to JUMP_HOLD_TIME
	_jump_hold_timer -= delta
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = MIN_JUMP_VELOCITY
		_jump_hold_timer = JUMP_HOLD_TIME
	if _jump_hold_timer > 0.0 and Input.is_action_pressed("jump") and velocity.y > 0.0:
		velocity.y = MAX_JUMP_VELOCITY

	# WASD input
	var dir := Vector3.ZERO
	if Input.is_action_pressed("move_forward"):
		dir.z += 1
	if Input.is_action_pressed("move_back"):
		dir.z -= 1
	if Input.is_action_pressed("move_left"):
		dir.x -= 1
	if Input.is_action_pressed("move_right"):
		dir.x += 1

	dir = dir.normalized()
	if dir != Vector3.ZERO:
		var my_basis = global_transform.basis
		var forward = -my_basis.z.normalized()
		var right = my_basis.x.normalized()
		var move_dir = (right * dir.x + forward * dir.z).normalized()
		velocity.x = move_dir.x * move_speed
		velocity.z = move_dir.z * move_speed
	else:
		# Use a lower step in move_toward to avoid 'ghost' collision jitters at rest
		velocity.x = move_toward(velocity.x, 0, move_speed * 0.2)
		velocity.z = move_toward(velocity.z, 0, move_speed * 0.2)

	# Block (melee) / Aim (gun): right click
	var w: Resource = _game_state.get_current_weapon_data() if _game_state else null
	var is_melee_weapon: bool = w != null and w.get("is_melee") == true
	if is_melee_weapon:
		_blocking = Input.is_action_pressed("secondary")
		_aiming = false
	else:
		_aiming = Input.is_action_pressed("secondary")
		_blocking = false
	# Melee attack (left click)
	_melee_cooldown -= delta
	if Input.is_action_just_pressed("attack") and _melee_cooldown <= 0.0 and not _blocking:
		_try_melee()
	# Hold R to repair barrier at window (cooldown so not instant 5)
	_repair_cooldown -= delta
	if Input.is_action_pressed("repair_barrier") and _repair_cooldown <= 0.0:
		if _try_repair_barrier():
			_repair_cooldown = 0.4
	if Input.is_action_just_pressed("swap_weapon"):
		if _game_state != null and not _game_state.second_weapon_id.is_empty():
			_game_state.swap_weapons()
			_update_weapon_mesh()

	# Continuous collision: call move_and_slide() at the very end of the physics loop
	move_and_slide()

	# Ceiling: stop upward velocity immediately so we don't tunnel through thin roof (applies next frame)
	if is_on_ceiling():
		velocity.y = 0.0
		_jump_hold_timer = 0.0

func _try_melee() -> void:
	if _game_state == null:
		return
	var w: Resource = _game_state.get_current_weapon_data()
	if w == null:
		return
	var weapon = w as WeaponDataScript
	if weapon == null or not weapon.is_melee:
		return
	_melee_cooldown = weapon.attack_cooldown
	# Start swing animation (slightly shorter than full cooldown so it snaps back)
	_swing_duration = weapon.attack_cooldown * 0.85
	_swing_timer = _swing_duration
	var space := get_world_3d().direct_space_state
	var shape := SphereShape3D.new()
	shape.radius = weapon.melee_range * 0.5
	var params := PhysicsShapeQueryParameters3D.new()
	params.shape = shape
	var forward := -global_transform.basis.z.normalized()
	forward.y = 0.0
	forward = forward.normalized()
	params.transform = global_transform.translated(forward * weapon.melee_range * 0.5)
	params.collision_mask = 2  # zombies on layer 2
	params.exclude = [get_rid()]
	var results := space.intersect_shape(params, 8)
	var damage_mult: float = 1.0 + 0.1 * float(GameState.skill_damage_level)
	var extra_weapon_dmg: float = float(GameState.weapon_upgrade_level) * 2.0
	var total_damage: float = (weapon.damage + extra_weapon_dmg) * damage_mult
	for r in results:
		var collider = r.collider
		if collider != null and collider.has_method("take_damage"):
			collider.take_damage(total_damage)

const BARRIER_COST := 10
var _repair_cooldown := 0.0

func _update_weapon_mesh() -> void:
	if _weapon_pivot == null:
		return
	for c in _weapon_pivot.get_children():
		c.queue_free()
	var id: String = _game_state.current_weapon_id if _game_state else ""
	if id.is_empty():
		return
	if id == "brass_knuckles":
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.72, 0.53, 0.25)
		mat.metallic = 0.8
		for i in 2:
			var m := MeshInstance3D.new()
			m.mesh = BoxMesh.new()
			(m.mesh as BoxMesh).size = Vector3(0.06, 0.05, 0.08)
			m.position = Vector3(i * 0.06 - 0.03, 0, -0.12)
			m.material_override = mat
			_weapon_pivot.add_child(m)
	elif id == "knife":
		var blade := MeshInstance3D.new()
		blade.mesh = BoxMesh.new()
		(blade.mesh as BoxMesh).size = Vector3(0.02, 0.04, 0.22)
		blade.position = Vector3(0, 0, -0.2)
		var bmat := StandardMaterial3D.new()
		bmat.albedo_color = Color(0.5, 0.5, 0.55)
		bmat.metallic = 0.7
		blade.material_override = bmat
		_weapon_pivot.add_child(blade)
		var handle := MeshInstance3D.new()
		handle.mesh = BoxMesh.new()
		(handle.mesh as BoxMesh).size = Vector3(0.04, 0.06, 0.1)
		handle.position = Vector3(0, 0, -0.05)
		var hmat := StandardMaterial3D.new()
		hmat.albedo_color = Color(0.2, 0.12, 0.08)
		handle.material_override = hmat
		_weapon_pivot.add_child(handle)
	elif id == "baseball_bat":
		var bat := MeshInstance3D.new()
		bat.mesh = CylinderMesh.new()
		(bat.mesh as CylinderMesh).top_radius = 0.03
		(bat.mesh as CylinderMesh).bottom_radius = 0.04
		(bat.mesh as CylinderMesh).height = 0.5
		bat.rotation.x = deg_to_rad(90.0)
		bat.position = Vector3(0, 0, -0.3)
		var wmat := StandardMaterial3D.new()
		wmat.albedo_color = Color(0.4, 0.28, 0.15)
		wmat.roughness = 0.9
		bat.material_override = wmat
		_weapon_pivot.add_child(bat)
	else:
		var m := MeshInstance3D.new()
		m.mesh = BoxMesh.new()
		(m.mesh as BoxMesh).size = Vector3(0.08, 0.08, 0.3)
		m.position = Vector3(0, 0, -0.15)
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.35, 0.25, 0.15)
		m.material_override = mat
		_weapon_pivot.add_child(m)

func _try_repair_barrier() -> bool:
	if GameState.current_window_car == null or GameState.current_window_index < 0:
		return false
	if GameState.coins < BARRIER_COST:
		return false
	var car = GameState.current_window_car
	if not car.has_method("add_barrier"):
		return false
	if car.add_barrier(GameState.current_window_index):
		GameState.coins -= BARRIER_COST
		return true
	return false

func take_damage(amount: float) -> void:
	if _game_state == null:
		return
	if _game_state.is_dead:
		return
	if _blocking:
		amount *= 0.35
	_game_state.player_health -= amount
	if _game_state.player_health < 0.0:
		_game_state.player_health = 0.0
		_game_state.is_dead = true
		set_process(false)
		set_physics_process(false)
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
