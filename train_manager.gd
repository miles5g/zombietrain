extends Node3D

@onready var caboose_scene = preload("res://caboose.tscn")
var car_length: float = 20.0
var spawn_index: int = 0
var cars: Array = []

func _ready():
	for i in range(3):
		spawn_next_car()

func spawn_next_car():
	var new_car = caboose_scene.instantiate()
	add_child(new_car)

	# Ensure new_car is aligned with the world floor (y = 0)
	var spawn_pos = global_transform.origin
	spawn_pos.z += spawn_index * car_length
	spawn_pos.y = 0
	new_car.global_position = spawn_pos
	new_car.global_position.y = 0 # Explicitly ensure y is 0
	
	spawn_index += 1

	# Safely connect signal if it exists
	if new_car.has_signal("player_reached_door"):
		new_car.player_reached_door.connect(spawn_next_car)
	cars.append(new_car)

	# Remove oldest car if there are more than 3
	if cars.size() > 3:
		var oldest_car = cars.pop_front()
		oldest_car.queue_free()
