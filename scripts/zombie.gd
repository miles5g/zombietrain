extends CharacterBody3D
## Simple zombie: moves toward player, takes melee damage, dies at 0 health.

signal died

var max_health: float = 30.0
var health: float = 30.0
var move_speed: float = 3.0
var damage_to_player: float = 10.0
var attack_range: float = 1.5
var attack_cooldown: float = 1.0
var _attack_timer: float = 0.0
var is_special: bool = false  # better loot, chance for cosmetics
# Climb through window: start outside, lerp to target inside over _climb_timer
var entry_target_global: Vector3 = Vector3.ZERO
var _climb_timer: float = 0.0
var _climb_start_pos: Vector3 = Vector3.ZERO

var _player: Node3D
var _game_state: Node = null

func _ready() -> void:
	_game_state = get_node_or_null("/root/GameState")
	add_to_group("zombies")
	health = max_health
	_build_humanoid_mesh()
	_player = get_tree().get_first_node_in_group("player")
	if _player == null:
		set_physics_process(false)

func _build_humanoid_mesh() -> void:
	# Remove default capsule mesh if present
	var old_mesh: Node = get_node_or_null("MeshInstance3D")
	if old_mesh != null:
		old_mesh.queue_free()
	var body := Node3D.new()
	body.name = "Body"
	add_child(body)
	var base_mat := StandardMaterial3D.new()
	base_mat.albedo_color = Color(0.2, 0.35, 0.2)
	if is_special:
		base_mat.albedo_color = Color(0.5, 0.2, 0.2)
	# Torso (capsule)
	var torso := MeshInstance3D.new()
	torso.name = "Torso"
	torso.mesh = CapsuleMesh.new()
	(torso.mesh as CapsuleMesh).radius = 0.28
	(torso.mesh as CapsuleMesh).height = 0.7
	torso.position = Vector3(0, 0.75, 0)
	torso.material_override = base_mat
	body.add_child(torso)
	# Head
	var head_mat := base_mat.duplicate() as StandardMaterial3D
	head_mat.albedo_color = head_mat.albedo_color.lerp(Color(0.55, 0.4, 0.35), 0.3)
	var head_mesh := MeshInstance3D.new()
	head_mesh.name = "Head"
	head_mesh.mesh = CapsuleMesh.new()
	(head_mesh.mesh as CapsuleMesh).radius = 0.2
	(head_mesh.mesh as CapsuleMesh).height = 0.35
	head_mesh.position = Vector3(0, 1.25, 0)
	head_mesh.material_override = head_mat
	body.add_child(head_mesh)
	# Arms (thin capsules)
	for side in [-1, 1]:
		var arm := MeshInstance3D.new()
		arm.name = "Arm_%d" % side
		arm.mesh = CapsuleMesh.new()
		(arm.mesh as CapsuleMesh).radius = 0.06
		(arm.mesh as CapsuleMesh).height = 0.4
		arm.position = Vector3(side * 0.35, 0.9, 0.1)
		arm.rotation.z = deg_to_rad(side * -25.0)
		arm.material_override = base_mat
		body.add_child(arm)
	# Legs
	for side in [-1, 1]:
		var leg := MeshInstance3D.new()
		leg.name = "Leg_%d" % side
		leg.mesh = CapsuleMesh.new()
		(leg.mesh as CapsuleMesh).radius = 0.08
		(leg.mesh as CapsuleMesh).height = 0.5
		leg.position = Vector3(side * 0.15, 0.35, 0)
		leg.material_override = base_mat
		body.add_child(leg)

func _physics_process(delta: float) -> void:
	_attack_timer -= delta
	if _climb_timer > 0.0:
		_climb_timer -= delta
		var t := 1.0 - (_climb_timer / 0.7)
		t = clampf(t, 0.0, 1.0)
		global_position = _climb_start_pos.lerp(entry_target_global, t)
		velocity = Vector3.ZERO
		velocity.y = -9.8 * delta
		move_and_slide()
		return
	if _game_state != null and _game_state.is_in_safe_zone:
		velocity.x = 0.0
		velocity.z = 0.0
		velocity.y -= 9.8 * delta
		move_and_slide()
		return
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player")
		if _player == null:
			return
	var to_player := _player.global_position - global_position
	to_player.y = 0.0
	var dist := to_player.length()
	if dist < attack_range and _attack_timer <= 0.0:
		_try_attack_player()
		_attack_timer = attack_cooldown
	elif dist > 0.01:
		to_player = to_player.normalized()
		velocity.x = to_player.x * move_speed
		velocity.z = to_player.z * move_speed
	else:
		velocity.x = 0.0
		velocity.z = 0.0
	velocity.y -= 9.8 * delta
	move_and_slide()

func _try_attack_player() -> void:
	if _player.has_method("take_damage"):
		_player.take_damage(damage_to_player)

func take_damage(amount: float) -> void:
	health -= amount
	if health <= 0.0:
		die()

func die() -> void:
	# Drops: coins; special zombies drop more and have chance for cosmetics
	var drop_coins := randi_range(2, 6)
	if _game_state != null:
		if is_special:
			drop_coins += randi_range(8, 15)
			if randf() < 0.25:
				var cosmetic_id := "cosmetic_%d" % randi_range(1, 5)
				if cosmetic_id not in _game_state.unlocked_cosmetics:
					_game_state.unlocked_cosmetics.append(cosmetic_id)
					_game_state._save_cosmetics()
		_game_state.coins += drop_coins
	died.emit()
	queue_free()
