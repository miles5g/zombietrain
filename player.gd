extends CharacterBody3D

const SPEED := 5.0
const CROUCH_SPEED := 2.2
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

func _ready():
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
	var move_speed := CROUCH_SPEED if crouching else SPEED
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

	# Continuous collision: call move_and_slide() at the very end of the physics loop
	move_and_slide()

	# Ceiling: stop upward velocity immediately so we don't tunnel through thin roof (applies next frame)
	if is_on_ceiling():
		velocity.y = 0.0
		_jump_hold_timer = 0.0
