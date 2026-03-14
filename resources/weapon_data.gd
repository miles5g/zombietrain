@tool
class_name WeaponData
extends Resource

@export var id: String = ""
@export var display_name: String = ""
@export var is_melee: bool = true
## Damage per hit (melee) or per bullet (gun)
@export var damage: float = 10.0
## Seconds between attacks (melee) or shots (gun)
@export var attack_cooldown: float = 0.6
## Melee range in units; unused for guns
@export var melee_range: float = 2.0

func get_dps() -> float:
	if attack_cooldown <= 0.0:
		return 0.0
	return damage / attack_cooldown
