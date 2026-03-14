extends Node3D

@onready var caboose_scene = preload("res://caboose.tscn")
@onready var zombie_scene = preload("res://scenes/zombie.tscn")
# Normal car body length (must match default hull_size.z in caboose_generator)
var car_body_length: float = 20.0
# Caboose (first car) is smaller
var caboose_body_length: float = 14.0
# Gap between cars = gangway
var gangway_length: float = 2.0
# Spacing: from caboose center to next car center; then normal car to car
var car_length_normal: float = 22.0  # car_body_length + gangway_length
var spawn_index: int = 0
var cars: Array = []
var cars_entered_count: int = 0  # difficulty: scales zombie stats and special chance

func _ready():
	car_length_normal = car_body_length + gangway_length
	for i in range(3):
		spawn_next_car()

func spawn_next_car():
	var new_car = caboose_scene.instantiate()
	new_car.set("is_caboose", spawn_index == 0)
	add_child(new_car)

	var spawn_pos := global_transform.origin
	spawn_pos.y = 0
	if spawn_index == 0:
		spawn_pos.z = 0.0  # caboose at origin; player spawns inside it
	else:
		# First gap: caboose back + gangway + normal car half; then normal spacing
		var first_car_center_z := caboose_body_length * 0.5 + gangway_length + car_body_length * 0.5
		spawn_pos.z = first_car_center_z + (spawn_index - 1) * car_length_normal
	new_car.global_position = spawn_pos

	spawn_index += 1

	if new_car.has_signal("player_reached_door"):
		new_car.player_reached_door.connect(spawn_next_car)
	if new_car.has_signal("player_entered_main_body"):
		new_car.player_entered_main_body.connect(_on_player_entered_car_main_body.bind(new_car))
	cars.append(new_car)

	if cars.size() > 3:
		var oldest_car = cars.pop_front()
		oldest_car.queue_free()

func _on_player_entered_car_main_body(car: Node3D) -> void:
	if car.get("is_caboose") == true:
		return
	cars_entered_count += 1
	var car_depth: int = cars_entered_count
	# Zombies enter only via windows; spawn at window positions
	if not car.has_method("get_window_spawn_points"):
		return
	var spawn_points: Array = car.get_window_spawn_points()
	if spawn_points.is_empty():
		return
	var count := 2
	var special_chance := minf(0.35, 0.05 * car_depth)
	for i in count:
		var idx := randi() % spawn_points.size()
		var spawn_node: Node3D = spawn_points[idx]
		if spawn_node == null:
			continue
		car.consume_barrier(idx)
		var zombie := zombie_scene.instantiate()
		# Difficulty scaling (set before add_child so _ready sees them)
		zombie.max_health = 30.0 + 5.0 * car_depth
		zombie.damage_to_player = 10.0 + 2.0 * car_depth
		zombie.move_speed = 3.0 + 0.1 * car_depth
		zombie.is_special = randf() < special_chance
		if zombie.is_special:
			zombie.max_health *= 2.0
			zombie.damage_to_player *= 1.5
		zombie.health = zombie.max_health
		# Spawn outside window; zombie will climb in (lerp to inside over 0.7s)
		var side_sign: float = 1.0 if spawn_node.position.x > 0 else -1.0
		var outside_offset: Vector3 = car.global_transform.basis.x * side_sign * 0.8
		zombie.entry_target_global = spawn_node.global_position + Vector3(0, 0, randf_range(-0.15, 0.15))
		zombie._climb_timer = 0.7
		car.add_child(zombie)
		zombie._climb_start_pos = spawn_node.global_position + outside_offset
		zombie.global_position = zombie._climb_start_pos
