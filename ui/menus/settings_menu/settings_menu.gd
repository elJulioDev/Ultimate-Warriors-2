extends Control
## Menú de configuraciones, inspirado en la interfaz del mod Sodium de
## Minecraft: categorías a la izquierda, opciones agrupadas en paneles a la
## derecha. Toda la disposición visual vive en la escena (settings_menu.tscn);
## este script solo se encarga de:
##   1) mostrar la página de opciones según la categoría activa
##   2) filtrar filas con la barra de búsqueda
##   3) aplicar efectos en vivo (volumen general, modo de ventana)
##   4) guardar / cargar / restablecer valores
##   5) volver al menú principal
##   6) animaciones de entrada, transición entre categorías y glow

const MAIN_MENU_PATH := "res://ui/menus/main_menu/menu.tscn"
const SAVE_PATH := "user://settings.cfg"
const SAVE_SECTION := "settings"
const HOVER_SFX_PATH := "res://assets/audio/sfx/ui/Cursor.wav"
const CLICK_SFX_PATH := "res://assets/audio/sfx/ui/Decide_2.wav"

@onready var _search: LineEdit = $Root/Layout/TopBar/SearchField
@onready var _reset_button: Button = $Root/Layout/TopBar/ResetButton
@onready var _apply_button: Button = $Root/Layout/BottomBar/ApplyButton
@onready var _done_button: Button = $Root/Layout/BottomBar/DoneButton

@onready var _cat_display: Button = $Root/Layout/MainArea/Sidebar/CategoryList/CatDisplay
@onready var _cat_sound: Button = $Root/Layout/MainArea/Sidebar/CategoryList/CatSound
@onready var _cat_game: Button = $Root/Layout/MainArea/Sidebar/CategoryList/CatGame

@onready var _page_display: VBoxContainer = $Root/Layout/MainArea/OptionsScroll/Pages/PageDisplay
@onready var _page_sound: VBoxContainer = $Root/Layout/MainArea/OptionsScroll/Pages/PageSound
@onready var _page_game: VBoxContainer = $Root/Layout/MainArea/OptionsScroll/Pages/PageGame

## Filas con integración real a sistemas del motor (ver _apply_live_effects).
@onready var _window_mode_row: CycleRow = $Root/Layout/MainArea/OptionsScroll/Pages/PageDisplay/PanelWindowMode/RowWindowMode
@onready var _resolution_row: CycleRow = $Root/Layout/MainArea/OptionsScroll/Pages/PageDisplay/PanelResolution/RowResolution
@onready var _fps_row: SliderRow = $Root/Layout/MainArea/OptionsScroll/Pages/PageDisplay/PanelPerformance/VBox/RowFPS
@onready var _texture_filter_row: CycleRow = $Root/Layout/MainArea/OptionsScroll/Pages/PageDisplay/PanelTextures/RowTextureFilter
@onready var _antialiasing_row: CycleRow = $Root/Layout/MainArea/OptionsScroll/Pages/PageDisplay/PanelAntialiasing/RowAntialiasing
@onready var _master_volume_row: SliderRow = $Root/Layout/MainArea/OptionsScroll/Pages/PageSound/PanelMasterVolume/RowMasterVolume

var _pages: Array = []
var _category_buttons: Array = []
var _default_snapshot: Dictionary = {}
var _page_tween: Tween = null
var _glow_tween: Tween = null
var _current_glow_btn: Button = null
var _hover_player: AudioStreamPlayer
var _click_player: AudioStreamPlayer
var _last_hover_time: int = 0
var _last_click_time: int = 0


func _ready() -> void:
	_setup_audio()
	_connect_buttons()
	_pages = [_page_display, _page_sound, _page_game]
	_category_buttons = [_cat_display, _cat_sound, _cat_game]
	for i in _category_buttons.size():
		_category_buttons[i].toggled.connect(_on_category_toggled.bind(i))
	_search.text_changed.connect(_on_search_text_changed)
	_reset_button.pressed.connect(_on_reset_pressed)
	_apply_button.pressed.connect(_on_apply_pressed)
	_done_button.pressed.connect(_on_done_pressed)
	if _fps_row:
		_fps_row.special_labels = {240.0: "Sin límite"}
	_show_page(0, false)
	_store_defaults()
	_load_settings()
	_apply_live_effects()
	_animate_entry()


# ─── Animaciones de entrada ─────────────────────────────────────────────────

func _animate_entry() -> void:
	var panels: Array[PanelContainer] = []
	for page in _pages:
		for child in page.get_children():
			if child is PanelContainer:
				panels.append(child)
	# Sidebar fade-in
	for cat_btn in _category_buttons:
		cat_btn.modulate.a = 0.0
		var tw := create_tween()
		tw.tween_property(cat_btn, "modulate:a", 1.0, 0.3)
		tw.set_parallel(false)
	# Panels fade-in staggered (no position — VBoxContainer handles layout)
	for i in panels.size():
		panels[i].modulate.a = 0.0
		var tw := create_tween()
		tw.tween_interval(0.1 + i * 0.06)
		tw.tween_property(panels[i], "modulate:a", 1.0, 0.25)
	# Bottom bar fade-in
	var bottom_bar := $Root/Layout/BottomBar
	bottom_bar.modulate.a = 0.0
	var tw_b := create_tween()
	tw_b.tween_interval(0.4)
	tw_b.tween_property(bottom_bar, "modulate:a", 1.0, 0.3)


# ─── Audio ──────────────────────────────────────────────────────────────────

func _setup_audio() -> void:
	_hover_player = AudioStreamPlayer.new()
	_hover_player.stream = preload(HOVER_SFX_PATH)
	_hover_player.volume_db = -10
	_hover_player.max_polyphony = 4
	add_child(_hover_player)

	_click_player = AudioStreamPlayer.new()
	_click_player.stream = preload(CLICK_SFX_PATH)
	_click_player.volume_db = -10
	add_child(_click_player)


func _connect_buttons() -> void:
	var all_buttons: Array[Button] = [
		_reset_button, _apply_button, _done_button,
		_cat_display, _cat_sound, _cat_game,
	]
	for btn in all_buttons:
		btn.mouse_entered.connect(_on_button_hover.bind(btn))
		btn.pressed.connect(_on_button_click)
	# Conectar widgets de opciones (ValueButton, CheckBox, Slider) en todas las páginas
	_connect_option_widgets()


func _connect_option_widgets() -> void:
	for page in _pages:
		_connect_widgets_recursive(page)


func _connect_widgets_recursive(node: Node) -> void:
	for child in node.get_children():
		if child is Button and child.name == "ValueButton":
			child.mouse_entered.connect(_on_button_hover.bind(child))
			child.pressed.connect(_on_button_click)
		elif child is CheckBox:
			child.pressed.connect(_on_button_click)
		elif child is HSlider:
			child.value_changed.connect(_on_slider_changed)
		_connect_widgets_recursive(child)


func _on_slider_changed(_value: float) -> void:
	_click_player.play()


func _on_button_hover(_btn: Button) -> void:
	var now := Time.get_ticks_msec()
	if now - _last_hover_time > 150:
		_hover_player.play()
		_last_hover_time = now


func _on_button_click() -> void:
	var now := Time.get_ticks_msec()
	if now - _last_click_time > 150:
		_click_player.play()
		_last_click_time = now


# ─── Categorías (sidebar → página) ──────────────────────────────────────────

func _on_category_toggled(pressed: bool, index: int) -> void:
	if pressed:
		_show_page(index, true)


func _show_page(index: int, animate: bool = true) -> void:
	var old_page := -1
	for i in _pages.size():
		if _pages[i].visible:
			old_page = i
			break
	if old_page == index:
		return
	_stop_glow()
	if animate and old_page >= 0:
		_crossfade_pages(old_page, index)
	else:
		for i in _pages.size():
			_pages[i].visible = (i == index)
	if _search:
		_search.text = ""
	_on_search_text_changed("")
	if animate:
		_start_glow(_category_buttons[index])


func _crossfade_pages(old_idx: int, new_idx: int) -> void:
	if _page_tween and _page_tween.is_valid():
		_page_tween.kill()
	var old_page: VBoxContainer = _pages[old_idx]
	var new_page: VBoxContainer = _pages[new_idx]
	# Fade out old
	_page_tween = create_tween().set_parallel(true)
	_page_tween.tween_property(old_page, "modulate:a", 0.0, 0.12).set_trans(Tween.TRANS_QUAD)
	_page_tween.chain().tween_callback(func():
		old_page.visible = false
		old_page.modulate.a = 1.0
		# Show and fade in new
		new_page.visible = true
		new_page.modulate.a = 0.0
		var tw := create_tween()
		tw.tween_property(new_page, "modulate:a", 1.0, 0.18).set_trans(Tween.TRANS_QUAD)
	)


# ─── Glow en categoría activa ───────────────────────────────────────────────

func _start_glow(btn: Button) -> void:
	_current_glow_btn = btn
	var style: StyleBoxFlat = btn.get_theme_stylebox("pressed").duplicate() as StyleBoxFlat
	if style == null:
		return
	var base_color := style.border_color
	_glow_tween = create_tween().set_loops()
	_glow_tween.tween_property(style, "border_color:a", 0.4, 0.7).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_glow_tween.tween_property(style, "border_color:a", 1.0, 0.7).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	style.border_color = base_color
	btn.add_theme_stylebox_override("pressed", style)
	btn.add_theme_stylebox_override("hover_pressed", style)


func _stop_glow() -> void:
	if _glow_tween and _glow_tween.is_valid():
		_glow_tween.kill()
		_glow_tween = null
	if _current_glow_btn and is_instance_valid(_current_glow_btn):
		var style: StyleBoxFlat = _current_glow_btn.get_theme_stylebox("pressed").duplicate() as StyleBoxFlat
		if style:
			style.border_color.a = 1.0
			_current_glow_btn.add_theme_stylebox_override("pressed", style)
			_current_glow_btn.add_theme_stylebox_override("hover_pressed", style)
	_current_glow_btn = null


# ─── Búsqueda ───────────────────────────────────────────────────────────────

func _on_search_text_changed(text: String) -> void:
	var query := text.to_lower().strip_edges()
	for page in _pages:
		if page.visible:
			_filter_page(page, query)


func _filter_page(page: VBoxContainer, query: String) -> void:
	for panel in page.get_children():
		var any_visible := false
		for row in _rows_in(panel):
			var shown := query.is_empty() or _row_label(row).to_lower().contains(query)
			row.visible = shown
			any_visible = any_visible or shown
		if panel is CanvasItem:
			panel.visible = any_visible


func _row_label(row: Node) -> String:
	var lt = row.get("label_text")
	if lt != null:
		return str(lt)
	var lbl := row.get_node_or_null("Label")
	return lbl.text if lbl else ""


## Un panel envuelve directamente una fila suelta (ej. una única opción de
## ciclo) o un VBoxContainer con varias filas agrupadas, como en Sodium.
func _rows_in(panel: Node) -> Array:
	if panel.get_child_count() == 0:
		return []
	var inner: Node = panel.get_child(0)
	if inner is VBoxContainer:
		return inner.get_children()
	return [inner]


func _all_rows() -> Array:
	var rows: Array = []
	for page in _pages:
		for panel in page.get_children():
			rows.append_array(_rows_in(panel))
	return rows


# ─── Lectura/escritura genérica de filas ────────────────────────────────────
# Soporta los 3 tipos de fila usados en la escena: SliderRow, CycleRow y el
# CheckBox simple (fila HBoxContainer "Label" + "Check", sin script).

func _get_row_state(row: Node) -> Variant:
	if row.has_method("set_value"):
		return row.get_value()
	if row.has_method("set_selected_index"):
		return row.selected_index
	var chk := row.get_node_or_null("Check")
	if chk is CheckBox:
		return chk.button_pressed
	return null


func _set_row_state(row: Node, value: Variant) -> void:
	if value == null:
		return
	if row.has_method("set_value"):
		row.set_value(float(value))
	elif row.has_method("set_selected_index"):
		row.set_selected_index(int(value))
	else:
		var chk := row.get_node_or_null("Check")
		if chk is CheckBox:
			chk.button_pressed = bool(value)


# ─── Restablecer ────────────────────────────────────────────────────────────

func _store_defaults() -> void:
	_default_snapshot.clear()
	for row in _all_rows():
		_default_snapshot[row.name] = _get_row_state(row)


func _on_reset_pressed() -> void:
	for row in _all_rows():
		if _default_snapshot.has(row.name):
			_set_row_state(row, _default_snapshot[row.name])


# ─── Aplicar / Guardar / Cargar ─────────────────────────────────────────────

func _on_apply_pressed() -> void:
	_apply_live_effects()
	_save_settings()


func _on_done_pressed() -> void:
	_apply_live_effects()
	_save_settings()
	TransitionManager.transition(0.5, 0.3, 0.5, func():
		get_tree().change_scene_to_file(MAIN_MENU_PATH))


## Efectos con integración real ya disponible en el proyecto: volumen general
## (bus "Master") y modo de ventana. El resto de opciones (música/efectos,
## dificultad de IA, duración de ronda, etc.) quedan guardadas y accesibles
## vía _all_rows()/_get_row_state() para conectarse a sus sistemas cuando
## existan (buses de audio dedicados, ajustes de FightManager, etc.), sin
## tener que tocar esta escena.
func _apply_live_effects() -> void:
	if _master_volume_row:
		var bus_idx := AudioServer.get_bus_index("Master")
		if bus_idx >= 0:
			var v: float = clampf(_master_volume_row.get_value(), 0.0001, 1.0)
			AudioServer.set_bus_volume_db(bus_idx, linear_to_db(v))
	if _window_mode_row:
		var target_mode: DisplayServer.WindowMode
		var target_borderless: bool
		match _window_mode_row.get_value():
			"Pantalla completa":
				target_mode = DisplayServer.WINDOW_MODE_FULLSCREEN
				target_borderless = false
			"Sin bordes":
				target_mode = DisplayServer.WINDOW_MODE_WINDOWED
				target_borderless = true
			_:
				target_mode = DisplayServer.WINDOW_MODE_WINDOWED
				target_borderless = false
		var current_mode := DisplayServer.window_get_mode()
		var current_borderless := DisplayServer.window_get_flag(DisplayServer.WINDOW_FLAG_BORDERLESS)
		if current_mode != target_mode or current_borderless != target_borderless:
			DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, target_borderless)
			DisplayServer.window_set_mode(target_mode)
	if _resolution_row:
		var res_str: String = _resolution_row.get_value()
		var parts := res_str.split("×")
		if parts.size() == 2:
			var w := int(parts[0])
			var h := int(parts[1])
			if DisplayServer.window_get_size() != Vector2i(w, h):
				DisplayServer.window_set_size(Vector2i(w, h))
	if _fps_row:
		var fps_val: float = _fps_row.get_value()
		Engine.max_fps = 0 if fps_val >= 240.0 else int(fps_val)
	if _texture_filter_row:
		var filter_val: String = _texture_filter_row.get_value()
		var vp := get_viewport()
		match filter_val:
			"Nearest (Pixel Art)":
				vp.set("canvas_item_default_texture_filter", 0)
			"Linear (Suave)":
				vp.set("canvas_item_default_texture_filter", 1)
	if _antialiasing_row:
		var aa_val: String = _antialiasing_row.get_value()
		match aa_val:
			"Off":
				get_viewport().msaa_2d = Viewport.MSAA_DISABLED
			"FXAA":
				get_viewport().msaa_2d = Viewport.MSAA_DISABLED
				get_viewport().screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA
			"MSAA 2x":
				get_viewport().screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
				get_viewport().msaa_2d = Viewport.MSAA_2X
			"MSAA 4x":
				get_viewport().screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
				get_viewport().msaa_2d = Viewport.MSAA_4X


func _save_settings() -> void:
	var cfg := ConfigFile.new()
	for row in _all_rows():
		cfg.set_value(SAVE_SECTION, row.name, _get_row_state(row))
	cfg.save(SAVE_PATH)


func _load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return
	for row in _all_rows():
		if cfg.has_section_key(SAVE_SECTION, row.name):
			_set_row_state(row, cfg.get_value(SAVE_SECTION, row.name))
