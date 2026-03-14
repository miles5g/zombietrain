extends Node
## Autoload: persistent game state (weapon, coins, ammo, starter chosen, etc.)

const SAVE_PATH := "user://train_hole_save.json"

var current_weapon_id: String = ""
var second_weapon_id: String = ""  # two-weapon loadout; swap between current and second
var starter_chosen: bool = false
var coins: int = 0
var unlocked_cosmetics: Array[String] = []  # persist forever (save/load in future)
var ammo: Dictionary = {}  # weapon_id -> count, for guns later
var is_in_safe_zone: bool = false
var current_window_car: Node = null  # car script (caboose_generator) when player near a window
var current_window_index: int = -1
var player_max_health: float = 100.0
var player_health: float = 100.0
var is_dead: bool = false
var skill_damage_level: int = 0  # +10% per level
var skill_health_level: int = 0  # +10 max hp per level
var weapon_upgrade_level: int = 0  # +2 base damage per level (applied in combat)

func set_starter_weapon(weapon_id: String) -> void:
	current_weapon_id = weapon_id
	starter_chosen = true

func _get_weapon_registry() -> Node:
	return get_node_or_null("/root/WeaponRegistry")

func get_current_weapon_data() -> Resource:
	if current_weapon_id.is_empty():
		return null
	var wr := _get_weapon_registry()
	return wr.get_weapon(current_weapon_id) if wr else null

func get_secondary_weapon_data() -> Resource:
	if second_weapon_id.is_empty():
		return null
	var wr := _get_weapon_registry()
	return wr.get_weapon(second_weapon_id) if wr else null

func swap_weapons() -> void:
	var t := current_weapon_id
	current_weapon_id = second_weapon_id
	second_weapon_id = t

func has_weapon_slot_available() -> bool:
	return current_weapon_id.is_empty() or second_weapon_id.is_empty()

func add_weapon(weapon_id: String) -> bool:
	if current_weapon_id.is_empty():
		current_weapon_id = weapon_id
		return true
	if second_weapon_id.is_empty():
		second_weapon_id = weapon_id
		return true
	return false

func _ready() -> void:
	_load_cosmetics()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_save_cosmetics()

func _save_cosmetics() -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		return
	var d := { "cosmetics": unlocked_cosmetics }
	f.store_string(JSON.stringify(d))
	f.close()

func _load_cosmetics() -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return
	var json := JSON.new()
	var err := json.parse(f.get_as_text())
	f.close()
	if err != OK:
		return
	var d: Dictionary = json.get_data()
	if d.has("cosmetics") and d.cosmetics is Array:
		unlocked_cosmetics.clear()
		for c in d.cosmetics:
			if c is String:
				unlocked_cosmetics.append(c)
