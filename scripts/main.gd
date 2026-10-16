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
var menu: Control                  # панель паузы (для автотеста)
var menus                          # menu.gd: главное меню, пауза, настройки
var settings: Dictionary = {}
var spawn_points := [Vector3(0, 0.5, -9), Vector3(-8, 0.5, 6), Vector3(10, 0.5, -4), Vector3(4, 0.5, 10)]
const Menu = preload("res://scripts/menu.gd")

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

	# шины звука: эффекты и музыка — со своей громкостью
	for bn in ["SFX", "Music"]:
		if AudioServer.get_bus_index(bn) < 0:
			AudioServer.add_bus()
			var bi := AudioServer.bus_count - 1
			AudioServer.set_bus_name(bi, bn)
			AudioServer.set_bus_send(bi, "Master")
	var sfx := Node.new()
	sfx.set_script(Sfx)
	add_child(sfx)
	G.sfx = sfx
	var mus := Node.new()
	mus.set_script(load("res://scripts/music.gd"))
	add_child(mus)
	G.music = mus

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

	var ml := CanvasLayer.new()
	ml.layer = 10
	add_child(ml)
	menus = Control.new()
	menus.set_script(Menu)
	menus.main = self
	ml.add_child(menus)
	menu = menus.pause_panel
	settings = menus.settings
	menus.load_settings()
	_spawn_demon(spawn_points[0])
	if not G.autotest:
		menus.show_title()
	else:
		G.started = true
		menus.title_screen.visible = false
		var at := Node.new()
		# KLINOK_SHOWCASE — витрина кадров/видео вместо автотеста
		at.set_script(load("res://scripts/showcase.gd" if OS.get_environment("KLINOK_SHOWCASE") != "" else "res://scripts/autotest.gd"))
		add_child(at)

func _on_resize() -> void:
	if settings.is_empty():
		return
	apply_view(settings)

# Пиксельный фильтр, сглаживание и чёткость 3D (из настроек).
func apply_view(st: Dictionary) -> void:
	var h := float(get_viewport().get_visible_rect().size.y)
	var shrink := maxi(1, int(round(h / BASE_H))) if st.pixel else 1
	container.stretch_shrink = shrink
	vp.msaa_3d = Viewport.MSAA_DISABLED if st.pixel else Viewport.MSAA_4X
	vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
	vp.scaling_3d_scale = 1.0 if st.pixel else clampf(float(st.render_scale), 0.5, 1.0)
	if G.post_mat:
		G.post_mat.set_shader_parameter("pixel_mode", st.pixel)
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
		hud.visible = G.started
	if not G.started and G.cam_rig:
		# главное меню: камера медленно облетает героя
		G.cam_rig.yaw += G.rdt * 0.12
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
	if G.paused or not G.started:
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
		if menus.capture_action != "":
			return
		if not G.started:
			if menus.is_open():
				menus.close_menu()
			return
		_toggle_pause()
	elif not G.started:
		return
	elif e.is_action_pressed("daynight"):
		world.next_time()
	elif e.is_action_pressed("help"):
		hud.help = not hud.help
		hud.help_t = 0.0
	elif e is InputEventKey and e.pressed and e.physical_keycode == KEY_F10:
		menus.save()
		get_tree().quit()
	elif e is InputEventKey and e.pressed and e.physical_keycode == KEY_F11:
		settings.window = 0 if settings.window != 0 else 1
		menus.apply_all()
	elif e is InputEventMouseButton and e.pressed and not G.paused and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED and not G.autotest:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _toggle_pause() -> void:
	if G.paused:
		menus.close_menu()
	else:
		menus.open_pause()

func _set_volume(v: float, show: bool) -> void:
	menus.set_volume(v, show)

func _exit_tree() -> void:
	G.save_stats()
	SwordLib.cleanup()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and not G.paused and G.started and not G.autotest:
		_toggle_pause()
