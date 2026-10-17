@tool
extends Control
## Selección de personajes: cada jugador elige un luchador del roster.

const STAGE_SELECT_PATH := "res://ui/menus/stage_select/stage_select.tscn"
const MAIN_MENU_PATH := "res://ui/menus/main_menu/menu.tscn"

var p1_selection: String = ""
var p2_selection: String = ""

@onready var p1_grid: GridContainer = $Center/Players/P1Panel/P1Grid
@onready var p2_grid: GridContainer = $Center/Players/P2Panel/P2Grid
@onready var fight_button: Button = $BottomBar/FightButton
@onready var back_button: Button = $BottomBar/BackButton


func _ready() -> void:
	_build_grids()
	fight_button.disabled = true
	fight_button.pressed.connect(_on_fight_pressed)
	back_button.pressed.connect(_on_back_pressed)


func _build_grids() -> void:
	for id in GameManager.ROSTER:
		var entry: Dictionary = GameManager.ROSTER[id]
		p1_grid.add_child(_make_button(1, id, entry))
		p2_grid.add_child(_make_button(2, id, entry))


func _make_button(player: int, id: String, entry: Dictionary) -> Button:
	var b := Button.new()
	b.toggle_mode = true
	b.text = entry["display_name"]
	b.icon = load(entry["icon"])
	b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
	b.custom_minimum_size = Vector2(160, 180)
	b.toggled.connect(_on_pick.bind(player, id))
	return b


func _on_pick(pressed: bool, player: int, id: String) -> void:
	if player == 1:
		p1_selection = id if pressed else ""
	else:
		p2_selection = id if pressed else ""
	_update_fight_button()


func _update_fight_button() -> void:
	fight_button.disabled = p1_selection == "" or p2_selection == ""


func _on_fight_pressed() -> void:
	if p1_selection == "" or p2_selection == "":
		return
	GameManager.pending_p1 = GameManager.ROSTER[p1_selection]["data"]
	GameManager.pending_p2 = GameManager.ROSTER[p2_selection]["data"]
	TransitionManager.transition(0.5, 0.3, 0.5, func():
		get_tree().change_scene_to_file(STAGE_SELECT_PATH))


func _on_back_pressed() -> void:
	TransitionManager.transition(0.5, 0.3, 0.5, func():
		get_tree().change_scene_to_file(MAIN_MENU_PATH))
