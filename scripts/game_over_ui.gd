extends CanvasLayer
## Shown when player dies. Restart reloads scene; Quit exits.

@onready var panel: PanelContainer = $CenterContainer/PanelContainer
@onready var restart_btn: Button = $CenterContainer/PanelContainer/VBox/RestartBtn
@onready var quit_btn: Button = $CenterContainer/PanelContainer/VBox/QuitBtn
var _game_state: Node = null

func _ready() -> void:
	_game_state = get_node_or_null("/root/GameState")
	visible = false
	restart_btn.pressed.connect(_on_restart)
	quit_btn.pressed.connect(_on_quit)

func _process(_delta: float) -> void:
	if _game_state != null and _game_state.is_dead and not visible:
		visible = true

func _on_restart() -> void:
	if _game_state != null:
		_game_state.is_dead = false
		_game_state.player_health = _game_state.player_max_health
	get_tree().reload_current_scene()

func _on_quit() -> void:
	get_tree().quit()
