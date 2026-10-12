extends Node
# Сборка сцены: мир рендерится в низком разрешении и растягивается без
# сглаживания (пиксельный вид), поверх — пост-эффекты и интерфейс.

const World = preload("res://scripts/world.gd")
const Player = preload("res://scripts/player.gd")
const Demon = preload("res://scripts/demon.gd")
const CamRig = preload("res://scripts/camera_rig.gd")
const Fx = preload("res://scripts/fx.gd")
const Hud = preload("res://scripts/hud.gd")
const Sfx = preload("res://scripts/sfx.gd")
const SwordLib = preload("res://scripts/sword_lib.gd")

const BASE_H := 540.0   # высота «пиксельного» кадра (1080p → в 2 раза крупнее)

var container: SubViewportContainer
var vp: SubViewport
var world: Node3D
var hud: Control
var respawn_t := -1.0
var menu: Control
var vol_slider: HSlider
var sens_slider: HSlider
var settings := {"volume": 0.4, "sens": 1.0, "pixel": false, "sword": 0}
var sword_opt: OptionButton
var pixel_check: CheckBox
const SETTINGS_PATH := "user://settings.cfg"
var spawn_points := [Vector3(0, 0.5, -9), Vector3(-8, 0.5, 6), Vector3(10, 0.5, -4), Vector3(4, 0.5, 10)]

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	randomize()
	container = SubViewportContainer.new()
	container.stretch = true
	container.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(container)
	vp = SubViewport.new()
	vp.msaa_3d = Viewport.MSAA_DISABLED
	vp.audio_listener_enable_3d = true
	vp.positional_shadow_atlas_size = 1024
	container.add_child(vp)
	get_viewport().size_changed.connect(_on_resize)
	_on_resize()

	var sfx := Node.new()
	sfx.set_script(Sfx)
	add_child(sfx)
	G.sfx = sfx

	world = Node3D.new()
	world.set_script(World)
	vp.add_child(world)
	G.world = world
	world.build()

	var fx := Node3D.new()
	fx.set_script(Fx)
	world.add_child(fx)
	G.fx = fx

	var player := CharacterBody3D.new()
	player.set_script(Player)
	world.add_child(player)
	G.player = player

	var rig := Node3D.new()
	rig.set_script(CamRig)
	world.add_child(rig)
	G.cam_rig = rig

	# пост-эффекты внутри пиксельного кадра
	var post := ColorRect.new()
	post.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	post.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var pm := ShaderMaterial.new()
	pm.shader = load("res://shaders/post.gdshader")
	post.material = pm
	vp.add_child(post)
	G.post_mat = pm

	var layer := CanvasLayer.new()
	add_child(layer)
	hud = Control.new()
	hud.set_script(Hud)
	layer.add_child(hud)
	G.hud = hud

	_build_menu()
	_load_settings()
	_spawn_demon(spawn_points[0])
	if not G.autotest:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	else:
		var at := Node.new()
		at.set_script(load("res://scripts/autotest.gd"))
		add_child(at)

func _on_resize() -> void:
	var h := float(get_viewport().get_visible_rect().size.y)
	var shrink := maxi(1, int(round(h / BASE_H))) if settings.pixel else 1
	container.stretch_shrink = shrink
	vp.msaa_3d = Viewport.MSAA_DISABLED if settings.pixel else Viewport.MSAA_4X
	if G.post_mat:
		G.post_mat.set_shader_parameter("pixel_mode", settings.pixel)
	if hud:
		hud.px_scale = float(shrink)

func _spawn_demon(p: Vector3) -> void:
	var d := CharacterBody3D.new()
	d.set_script(Demon)
	world.add_child(d)
	d.global_position = p
	d.facing = randf() * TAU

func _process(_dt: float) -> void:
	if hud:
		hud.px_scale = float(container.stretch_shrink)
	# новый демон после гибели прошлого
	var alive := 0
	for e in G.enemies:
		if is_instance_valid(e) and not e.is_dead():
			alive += 1
	if alive == 0:
		if respawn_t < 0.0:
			respawn_t = 5.0
		respawn_t -= G.rdt
		if respawn_t <= 0.0:
			respawn_t = -1.0
			var best: Vector3 = spawn_points[0]
			var bd := 0.0
			for sp in spawn_points:
				var d: float = sp.distance_to(G.player.global_position)
				if d > bd:
					bd = d
					best = sp
			_spawn_demon(best)

# Мышь и клавиатуру передаём герою и камере отсюда: SubViewport с миром
# сам событий мыши не получает.
func _input(e: InputEvent) -> void:
	if G.paused:
		return
	if e is InputEventMouseButton and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED and not G.autotest:
		return   # этот клик только захватывает мышь, а не бьёт
	if G.player:
		G.player.handle_input(e)
	if G.cam_rig:
		G.cam_rig.handle_input(e)

func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventKey and e.pressed and not e.echo and (e.physical_keycode == KEY_MINUS or e.physical_keycode == KEY_KP_SUBTRACT):
		_set_volume(settings.volume - 0.1, true)
	elif e is InputEventKey and e.pressed and not e.echo and (e.physical_keycode == KEY_EQUAL or e.physical_keycode == KEY_KP_ADD):
		_set_volume(settings.volume + 0.1, true)
	elif e.is_action_pressed("pause"):
		_toggle_pause()
	elif e.is_action_pressed("daynight"):
		world.set_night(not world.night)
	elif e.is_action_pressed("help"):
		hud.help = not hud.help
		hud.help_t = 0.0
	elif e is InputEventKey and e.pressed and e.physical_keycode == KEY_F10:
		get_tree().quit()
	elif e is InputEventKey and e.pressed and e.physical_keycode == KEY_F11:
		var w := get_window()
		w.mode = Window.MODE_WINDOWED if w.mode == Window.MODE_FULLSCREEN else Window.MODE_FULLSCREEN
	elif e is InputEventMouseButton and e.pressed and not G.paused and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED and not G.autotest:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _toggle_pause() -> void:
	G.paused = not G.paused
	get_tree().paused = G.paused
	menu.visible = G.paused
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if G.paused else Input.MOUSE_MODE_CAPTURED
	if not G.paused:
		_save_settings()

# --- меню паузы: громкость, чувствительность мыши -----------------------
func _build_menu() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 10
	add_child(layer)
	menu = Control.new()
	menu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	menu.visible = false
	layer.add_child(menu)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0.05, 0.5)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	menu.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	menu.add_child(center)
	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.07, 0.15, 0.95)
	sb.border_color = Color(0.4, 0.65, 1.0)
	sb.set_border_width_all(2)
	sb.set_content_margin_all(28)
	panel.add_theme_stylebox_override("panel", sb)
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	box.custom_minimum_size = Vector2(460, 0)
	panel.add_child(box)
	var t := Label.new()
	t.text = "ПАУЗА"
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.add_theme_font_size_override("font_size", 40)
	box.add_child(t)
	vol_slider = _slider(box, "Громкость", 0.0, 1.0, 0.05, func(v): _set_volume(v, false))
	sens_slider = _slider(box, "Чувствительность мыши", 0.2, 3.0, 0.05, func(v): _set_sens(v))
	var sl := Label.new()
	sl.text = "Клинок"
	sl.add_theme_font_size_override("font_size", 20)
	box.add_child(sl)
	sword_opt = OptionButton.new()
	sword_opt.add_theme_font_size_override("font_size", 18)
	for nm in SwordLib.NAMES:
		sword_opt.add_item(nm)
	sword_opt.add_item("Кубический (свой)")
	sword_opt.item_selected.connect(func(idx): _set_sword(idx))
	box.add_child(sword_opt)
	pixel_check = CheckBox.new()
	pixel_check.text = "Пиксельный фильтр (крупные пиксели)"
	pixel_check.add_theme_font_size_override("font_size", 18)
	pixel_check.toggled.connect(func(on): settings.pixel = on; _on_resize())
	box.add_child(pixel_check)
	var b1 := Button.new()
	b1.text = "Продолжить"
	b1.add_theme_font_size_override("font_size", 22)
	b1.pressed.connect(_toggle_pause)
	box.add_child(b1)
	var b2 := Button.new()
	b2.text = "Выйти из игры"
	b2.add_theme_font_size_override("font_size", 22)
	b2.pressed.connect(func(): _save_settings(); get_tree().quit())
	box.add_child(b2)
	var hint := Label.new()
	hint.text = "Громкость во время игры: клавиши  −  и  +"
	hint.add_theme_font_size_override("font_size", 15)
	hint.modulate = Color(0.75, 0.82, 1.0)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(hint)

func _slider(parent: Control, title: String, lo: float, hi: float, step: float, cb: Callable) -> HSlider:
	var l := Label.new()
	l.text = title
	l.add_theme_font_size_override("font_size", 20)
	parent.add_child(l)
	var s := HSlider.new()
	s.min_value = lo
	s.max_value = hi
	s.step = step
	s.custom_minimum_size = Vector2(0, 28)
	s.value_changed.connect(cb)
	parent.add_child(s)
	return s

func _set_volume(v: float, show: bool) -> void:
	settings.volume = clampf(v, 0.0, 1.0)
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(0.0001, settings.volume * settings.volume)))
	AudioServer.set_bus_mute(0, settings.volume <= 0.001)
	if vol_slider and absf(vol_slider.value - settings.volume) > 0.001:
		vol_slider.set_value_no_signal(settings.volume)
	if show and hud:
		hud.notify("Громкость: %d%%" % int(round(settings.volume * 100)), 1.2)
		_save_settings()

func _set_sword(idx: int) -> void:
	var i := idx if idx < SwordLib.NAMES.size() else -1
	settings.sword = i
	if G.player:
		G.player.set_sword(i)

func _set_sens(v: float) -> void:
	settings.sens = v
	if G.cam_rig:
		G.cam_rig.sens_mult = v

func _load_settings() -> void:
	var cf := ConfigFile.new()
	if cf.load(SETTINGS_PATH) == OK:
		settings.volume = float(cf.get_value("main", "volume", 0.4))
		settings.sens = float(cf.get_value("main", "sens", 1.0))
		settings.pixel = bool(cf.get_value("main", "pixel", false))
		settings.sword = int(cf.get_value("main", "sword", 0))
	_set_volume(settings.volume, false)
	_set_sens(settings.sens)
	vol_slider.set_value_no_signal(settings.volume)
	sens_slider.set_value_no_signal(settings.sens)
	pixel_check.set_pressed_no_signal(settings.pixel)
	sword_opt.select(settings.sword if settings.sword >= 0 else SwordLib.NAMES.size())
	if G.player and G.player.sword_index != settings.sword:
		G.player.set_sword(settings.sword)
	_on_resize()

func _save_settings() -> void:
	var cf := ConfigFile.new()
	cf.set_value("main", "volume", settings.volume)
	cf.set_value("main", "sens", settings.sens)
	cf.set_value("main", "pixel", settings.pixel)
	cf.set_value("main", "sword", settings.sword)
	cf.save(SETTINGS_PATH)

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and not G.paused and not G.autotest:
		_toggle_pause()
