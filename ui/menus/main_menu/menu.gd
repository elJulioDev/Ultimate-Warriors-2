extends Control

const HOVER_SFX_PATH = "res://assets/audio/sfx/ui/Cursor.wav"
const CLICK_SFX_PATH = "res://assets/audio/sfx/ui/Decide_2.wav"


var hover_player: AudioStreamPlayer
var click_player: AudioStreamPlayer

@onready var logo = $LogoContainer/Logo
@onready var buttons_container = $VBoxContainer
@onready var version_label = $version

var last_hover_time: int = 0
var last_click_time: int = 0

var _busy := false
var _kb_active := false
var _btn_data: Dictionary = {}
var _hovered_btn: Button = null


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if _is_nav_key(event) and not _kb_active:
			_activate_kb_mode()
	elif event is InputEventMouseMotion:
		if _kb_active:
			_activate_mouse_mode()


func _is_nav_key(event: InputEventKey) -> bool:
	var kc := event.keycode if event.keycode else event.physical_keycode
	return kc in [KEY_UP, KEY_DOWN, KEY_W, KEY_S]


func _activate_kb_mode() -> void:
	_kb_active = true
	if _hovered_btn and is_instance_valid(_hovered_btn):
		_hovered_btn.visible = false
		_hovered_btn.visible = true
	for button in buttons_container.get_children():
		if button is Button and button.visible:
			button.grab_focus()
			break
	get_viewport().set_input_as_handled()


func _activate_mouse_mode() -> void:
	_kb_active = false
	get_viewport().gui_release_focus()
	for btn_name in _btn_data:
		var btn := buttons_container.get_node_or_null(str(btn_name))
		if btn is Button:
			btn.add_theme_stylebox_override("normal", _btn_data[btn_name].normal)
			btn.add_theme_stylebox_override("hover", _btn_data[btn_name].hover)


func _ready():
	_setup_audio()
	_connect_buttons()
	_start_logo_animation()
	var ver : Variant = "Version " + ProjectSettings.get_setting("application/config/version")
	if OS.is_debug_build():
		ver += " [DEBUG]"
	version_label.text = ver


func _setup_audio():
	hover_player = AudioStreamPlayer.new()
	hover_player.stream = preload(HOVER_SFX_PATH)
	hover_player.volume_db = -10
	hover_player.max_polyphony = 4
	add_child(hover_player)

	click_player = AudioStreamPlayer.new()
	click_player.stream = preload(CLICK_SFX_PATH)
	click_player.volume_db = -10
	add_child(click_player)


func _connect_buttons():
	for button in buttons_container.get_children():
		if not button is Button:
			continue
		_setup_button_visual(button)
		button.focus_entered.connect(_on_focus_entered.bind(button))
		button.focus_exited.connect(_on_focus_exited.bind(button))
		button.mouse_entered.connect(_on_mouse_entered.bind(button))
		button.pressed.connect(_on_button_pressed)
		if button.name == "play":
			button.pressed.connect(_on_play_pressed)
		elif button.name == "settings":
			button.pressed.connect(_on_settings_pressed)
		elif button.name == "exit":
			button.pressed.connect(_on_exit_pressed)


func _setup_button_visual(button: Button) -> void:
	var normal: StyleBoxFlat = button.get_theme_stylebox("normal").duplicate()
	var hover: StyleBoxFlat = button.get_theme_stylebox("hover").duplicate()
	hover.content_margin_top = normal.content_margin_top
	hover.content_margin_bottom = normal.content_margin_bottom
	hover.content_margin_left = normal.content_margin_left
	hover.content_margin_right = normal.content_margin_right
	button.add_theme_stylebox_override("hover", hover)
	var focus := StyleBoxFlat.new()
	focus.bg_color = Color.TRANSPARENT
	button.add_theme_stylebox_override("focus", focus)
	_btn_data[button.name] = {"normal": normal, "hover": hover, "kb_hover": hover}


func _on_focus_entered(button: Button) -> void:
	if not _kb_active:
		return
	hover_player.play()
	if button.name in _btn_data:
		button.add_theme_stylebox_override("normal", _btn_data[button.name].kb_hover)


func _on_focus_exited(button: Button) -> void:
	if button.name in _btn_data:
		button.add_theme_stylebox_override("normal", _btn_data[button.name].normal)


func _on_mouse_entered(button: Button) -> void:
	_hovered_btn = button
	if _kb_active:
		get_viewport().gui_release_focus()
		return
	var current_time = Time.get_ticks_msec()
	if current_time - last_hover_time > 150:
		hover_player.play()
		last_hover_time = current_time


func _set_busy(value: bool) -> void:
	_busy = value
	for button in buttons_container.get_children():
		if button is Button:
			button.mouse_filter = Control.MOUSE_FILTER_IGNORE if value else Control.MOUSE_FILTER_STOP


func _on_play_pressed():
	if _busy:
		return
	_set_busy(true)
	TransitionManager.transition(0.5, 0.3, 0.5, func():
		get_tree().change_scene_to_file("res://ui/menus/character_select/character_select.tscn"))

func _on_settings_pressed():
	if _busy:
		return
	_set_busy(true)
	TransitionManager.transition(0.5, 0.3, 0.5, func():
		get_tree().change_scene_to_file("res://ui/menus/settings_menu/settings_menu.tscn"))

func _on_exit_pressed():
	if _busy:
		return
	_set_busy(true)
	get_tree().quit()

func _on_button_pressed():
	var current_time = Time.get_ticks_msec()
	if current_time - last_click_time > 150:
		click_player.play()
		last_click_time = current_time

func _start_logo_animation():
	var base_scale = logo.scale
	var target_scale = base_scale * 1.04
	var tween = create_tween().set_loops()
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(logo, "scale", target_scale, 2.0)
	tween.tween_property(logo, "scale", base_scale, 2.0)
