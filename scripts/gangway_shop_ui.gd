extends CanvasLayer
## Gangway shop: skills, weapons, ammo. Open with E when in safe zone.

var _game_state: Node = null
@onready var panel: PanelContainer = $CenterContainer/PanelContainer
@onready var damage_btn: Button = $CenterContainer/PanelContainer/VBox/Skills/DamageBtn
@onready var health_btn: Button = $CenterContainer/PanelContainer/VBox/Skills/HealthBtn
@onready var weapon_btn: Button = $CenterContainer/PanelContainer/VBox/Weapons/WeaponUpgradeBtn
@onready var buy_weapon_brass: Button = $CenterContainer/PanelContainer/VBox/Weapons/BuyBrass
@onready var buy_weapon_knife: Button = $CenterContainer/PanelContainer/VBox/Weapons/BuyKnife
@onready var buy_weapon_bat: Button = $CenterContainer/PanelContainer/VBox/Weapons/BuyBat
@onready var close_btn: Button = $CenterContainer/PanelContainer/VBox/CloseBtn

const DAMAGE_UPGRADE_COST := 50
const HEALTH_UPGRADE_COST := 50
const WEAPON_UPGRADE_COST := 75
const BUY_WEAPON_COST := 100

func _ready() -> void:
	_game_state = get_node_or_null("/root/GameState")
	visible = false
	damage_btn.pressed.connect(_on_damage)
	health_btn.pressed.connect(_on_health)
	weapon_btn.pressed.connect(_on_weapon_upgrade)
	buy_weapon_brass.pressed.connect(_on_buy_weapon.bind("brass_knuckles"))
	buy_weapon_knife.pressed.connect(_on_buy_weapon.bind("knife"))
	buy_weapon_bat.pressed.connect(_on_buy_weapon.bind("baseball_bat"))
	close_btn.pressed.connect(close)

func _input(event: InputEvent) -> void:
	if _game_state != null and event.is_action_pressed("interact") and _game_state.is_in_safe_zone and _game_state.starter_chosen:
		if visible:
			close()
		else:
			open()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_cancel") and visible:
		close()
		get_viewport().set_input_as_handled()

func open() -> void:
	visible = true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	_refresh_buttons()

func close() -> void:
	visible = false
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _refresh_buttons() -> void:
	if _game_state == null:
		return
	damage_btn.text = "Damage +10%% (Lv %d) - %d coins" % [_game_state.skill_damage_level + 1, DAMAGE_UPGRADE_COST]
	damage_btn.disabled = _game_state.coins < DAMAGE_UPGRADE_COST
	health_btn.text = "Health +10 (Lv %d) - %d coins" % [_game_state.skill_health_level + 1, HEALTH_UPGRADE_COST]
	health_btn.disabled = _game_state.coins < HEALTH_UPGRADE_COST
	weapon_btn.text = "Weapon +2 dmg (Lv %d) - %d coins" % [_game_state.weapon_upgrade_level + 1, WEAPON_UPGRADE_COST]
	weapon_btn.disabled = _game_state.coins < WEAPON_UPGRADE_COST
	var has_slot: bool = _game_state.has_weapon_slot_available()
	buy_weapon_brass.text = "Buy Brass Knuckles - %d coins" % BUY_WEAPON_COST
	buy_weapon_brass.disabled = not has_slot or _game_state.current_weapon_id == "brass_knuckles" or _game_state.second_weapon_id == "brass_knuckles" or _game_state.coins < BUY_WEAPON_COST
	buy_weapon_knife.text = "Buy Knife - %d coins" % BUY_WEAPON_COST
	buy_weapon_knife.disabled = not has_slot or _game_state.current_weapon_id == "knife" or _game_state.second_weapon_id == "knife" or _game_state.coins < BUY_WEAPON_COST
	buy_weapon_bat.text = "Buy Baseball Bat - %d coins" % BUY_WEAPON_COST
	buy_weapon_bat.disabled = not has_slot or _game_state.current_weapon_id == "baseball_bat" or _game_state.second_weapon_id == "baseball_bat" or _game_state.coins < BUY_WEAPON_COST

func _on_damage() -> void:
	if _game_state != null and _game_state.coins >= DAMAGE_UPGRADE_COST:
		_game_state.coins -= DAMAGE_UPGRADE_COST
		_game_state.skill_damage_level += 1
		_refresh_buttons()

func _on_health() -> void:
	if _game_state != null and _game_state.coins >= HEALTH_UPGRADE_COST:
		_game_state.coins -= HEALTH_UPGRADE_COST
		_game_state.skill_health_level += 1
		_game_state.player_max_health = 100.0 + _game_state.skill_health_level * 10.0
		_refresh_buttons()

func _on_weapon_upgrade() -> void:
	if _game_state != null and _game_state.coins >= WEAPON_UPGRADE_COST:
		_game_state.coins -= WEAPON_UPGRADE_COST
		_game_state.weapon_upgrade_level += 1
		_refresh_buttons()

func _on_buy_weapon(weapon_id: String) -> void:
	if _game_state == null or not _game_state.has_weapon_slot_available() or _game_state.coins < BUY_WEAPON_COST:
		return
	if _game_state.current_weapon_id == weapon_id or _game_state.second_weapon_id == weapon_id:
		return
	if _game_state.add_weapon(weapon_id):
		_game_state.coins -= BUY_WEAPON_COST
		_refresh_buttons()
