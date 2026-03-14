extends CharacterBody3D

const SPEED := 5.0
const MOUSE_SENSITIVITY := 0.003
var GRAVITY: float

@onready var head: Node3D = null

var mouse_locked := true

func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	GRAVITY = ProjectSettings.get_setting("physics/3d/default_gravity") as float
	# Try to get the Head node safely, in case it does not exist
	if has_node("Head"):
		head = get_node("Head")
	else:
		print_debug("Head node not found. Mouse look will be disabled.")

	# --- PLAYER COLLISION SHAPE REMINDER ---
	# Make sure your player's CollisionShape3D is a CapsuleShape3D,
	# with radius = 0.4 and height = 1.8 in the Inspector.
	# This will help avoid getting stuck at train/hatch edges
	# when falling through holes.

func _unhandled_input(event):
	if event is InputEventMouseMotion and mouse_locked:
		# Mouse look
		rotate_y(-event.relative.x * MOUSE_SENSITIVITY)
		if head != null:
			head.rotate_x(-event.relative.y * MOUSE_SENSITIVITY)
			# Clamp pitch to avoid flipping
			head.rotation.x = clamp(head.rotation.x, deg_to_rad(-89), deg_to_rad(89))
	elif event is InputEventKey:
		if event.pressed and event.keycode == KEY_ESCAPE:
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
			mouse_locked = false
		elif event.pressed and event.keycode == KEY_ENTER:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
			mouse_locked = true

func _physics_process(delta):
	# Use the built-in velocity from CharacterBody3D

	# Apply gravity
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	else:
		velocity.y = 0.0

	# WASD input
	var dir := Vector3.ZERO
	if Input.is_action_pressed("ui_up"):
		dir.z += 1
	if Input.is_action_pressed("ui_down"):
		dir.z -= 1
	if Input.is_action_pressed("ui_left"):
		dir.x -= 1
	if Input.is_action_pressed("ui_right"):
		dir.x += 1

	dir = dir.normalized()
	if dir != Vector3.ZERO:
		var my_basis = global_transform.basis
		var forward = -my_basis.z.normalized()
		var right = my_basis.x.normalized()
		var move_dir = (right * dir.x + forward * dir.z).normalized()
		velocity.x = move_dir.x * SPEED
		velocity.z = move_dir.z * SPEED
	else:
		# Use a lower step in move_toward to avoid 'ghost' collision jitters at rest
		velocity.x = move_toward(velocity.x, 0, SPEED * 0.2)
		velocity.z = move_toward(velocity.z, 0, SPEED * 0.2)

	# Move the player and avoid sticky ghost collisions
	# Use a floor_max_angle of PI/2 so the player doesn't 'ride' shallow lips
	move_and_slide()
