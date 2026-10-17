extends Control
## Selección de escenario antes de la pelea.

const CHARACTER_SELECT_PATH := "res://ui/menus/character_select/character_select.tscn"

var stage_selection: String = ""

@onready var grid: GridContainer = $Center/Grid
@onready var fight_button: Button = $BottomBar/FightButton
@onready var back_button: Button = $BottomBar/BackButton


func _ready() -> void:
	_build_grid()
	fight_button.disabled = true
	fight_button.pressed.connect(_on_fight_pressed)
	back_button.pressed.connect(_on_back_pressed)


func _build_grid() -> void:
	for id in GameManager.stages:
		var data: StageData = load(GameManager.stages[id])
		var b := Button.new()
		b.toggle_mode = true
		b.text = data.display_name if data else id
		b.custom_minimum_size = Vector2(150, 50)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.toggled.connect(_on_pick.bind(id))
		b.set_meta("stage_id", id)
		grid.add_child(b)


func _on_pick(pressed: bool, id: String) -> void:
	if pressed:
		for child in grid.get_children():
			if child is Button and child.get_meta("stage_id") != id:
				child.button_pressed = false
		stage_selection = id
	else:
		stage_selection = ""
	fight_button.disabled = stage_selection == ""


func _on_fight_pressed() -> void:
	if stage_selection == "":
		return
	var stage_path: String = GameManager.stages[stage_selection]
	GameManager.start_fight(GameManager.pending_p1, GameManager.pending_p2, stage_path)


func _on_back_pressed() -> void:
	TransitionManager.transition(0.5, 0.3, 0.5, func():
		get_tree().change_scene_to_file(CHARACTER_SELECT_PATH))
