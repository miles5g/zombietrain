extends Node
## Autoload: weapon definitions (starters + shop). Use get_weapon(id).

const STARTER_IDS := ["brass_knuckles", "knife", "baseball_bat"]

static func get_weapon(id: String) -> Resource:
	var w := WeaponData.new()
	match id:
		"brass_knuckles":
			w.id = "brass_knuckles"
			w.display_name = "Brass Knuckles"
			w.damage = 8.0
			w.attack_cooldown = 0.5
			w.melee_range = 1.4
		"knife":
			w.id = "knife"
			w.display_name = "Knife"
			w.damage = 15.0
			w.attack_cooldown = 0.4
			w.melee_range = 1.6
		"baseball_bat":
			w.id = "baseball_bat"
			w.display_name = "Baseball Bat"
			w.damage = 22.0
			w.attack_cooldown = 0.85
			w.melee_range = 2.2
		_:
			return null
	w.is_melee = true
	return w

static func get_starter_weapons() -> Array[Resource]:
	var out: Array[Resource] = []
	for id in STARTER_IDS:
		out.append(get_weapon(id))
	return out
