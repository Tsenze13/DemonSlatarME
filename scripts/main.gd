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

const BASE_H := 540.0   # высота «пиксельного» кадра (1080p → в 2 раза крупнее)

var container: SubViewportContainer
var vp: SubViewport
var world: Node3D
var hud: Control
var respawn_t := -1.0
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

	_spawn_demon(spawn_points[0])
	if not G.autotest:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	else:
		var at := Node.new()
		at.set_script(load("res://scripts/autotest.gd"))
		add_child(at)

func _on_resize() -> void:
	var h := float(get_viewport().get_visible_rect().size.y)
	var shrink := maxi(1, int(round(h / BASE_H)))
	container.stretch_shrink = shrink
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

func _unhandled_input(e: InputEvent) -> void:
	if e.is_action_pressed("pause"):
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
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if G.paused else Input.MOUSE_MODE_CAPTURED

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and not G.paused and not G.autotest:
		_toggle_pause()
