extends CanvasLayer
## Shows coins, health, safe zone indicator, and prompts for shop.

@onready var coins_label: Label = $MarginContainer/TopLeft/CoinsLabel
@onready var health_label: Label = $MarginContainer/TopLeft/HealthLabel
@onready var weapons_label: Label = $MarginContainer/TopLeft/WeaponsLabel
@onready var cosmetics_label: Label = $MarginContainer/TopLeft/CosmeticsLabel
@onready var safe_label: Label = $MarginContainer/TopLeft/SafeLabel
@onready var shop_prompt: Label = $MarginContainer/BottomCenter/ShopPrompt
var _game_state: Node = null

func _ready() -> void:
	_game_state = get_node_or_null("/root/GameState")
	if _game_state != null:
		_game_state.player_max_health = 100.0 + _game_state.skill_health_level * 10.0
		if _game_state.player_health <= 0.0:
			_game_state.player_health = _game_state.player_max_health

func _process(_delta: float) -> void:
	if _game_state == null:
		return
	coins_label.text = "Coins: %d" % _game_state.coins
	health_label.text = "HP: %d / %d" % [int(_game_state.player_health), int(_game_state.player_max_health)]
	var w1: String = _game_state.current_weapon_id if _game_state.current_weapon_id else "—"
	var w2: String = _game_state.second_weapon_id if _game_state.second_weapon_id else "—"
	weapons_label.text = "Weapon 1: %s | Weapon 2: %s (Q swap)" % [w1, w2]
	cosmetics_label.text = "Cosmetics: %d" % _game_state.unlocked_cosmetics.size()
	safe_label.visible = _game_state.is_in_safe_zone
	shop_prompt.visible = _game_state.is_in_safe_zone
