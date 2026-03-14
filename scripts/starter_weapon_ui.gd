extends CanvasLayer
## Shown at start until player picks one of three starter melee weapons.

var mouse_locked := false
var _game_state: Node = null
@onready var brass: Button = $CenterContainer/PanelContainer/VBoxContainer/BrassKnuckles
@onready var knife: Button = $CenterContainer/PanelContainer/VBoxContainer/Knife
@onready var bat: Button = $CenterContainer/PanelContainer/VBoxContainer/BaseballBat

func _ready() -> void:
	_game_state = get_node_or_null("/root/GameState")
	if _game_state != null and _game_state.starter_chosen:
		hide_ui()
		return
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	mouse_locked = false
	brass.pressed.connect(_on_brass)
	knife.pressed.connect(_on_knife)
	bat.pressed.connect(_on_bat)

func _on_brass() -> void:
	_choose("brass_knuckles")

func _on_knife() -> void:
	_choose("knife")

func _on_bat() -> void:
	_choose("baseball_bat")

func _choose(weapon_id: String) -> void:
	if _game_state != null:
		_game_state.set_starter_weapon(weapon_id)
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	hide_ui()

func hide_ui() -> void:
	visible = false
