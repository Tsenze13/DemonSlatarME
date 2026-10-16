extends Node
# Витрина для проверки картинки глазами: ставит героя в разные места,
# снимает кадры днём, на закате и ночью; режим "move" — сценарий движения
# для записи видео (godot --write-movie). Запуск: KLINOK_AUTOTEST=1 KLINOK_SHOWCASE=shots|move
# KLINOK_SHOTS=<папка>.

var dir := ""
var mode := "shots"

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	dir = OS.get_environment("KLINOK_SHOTS")
	mode = OS.get_environment("KLINOK_SHOWCASE")
	if mode == "move":
		_move()
	else:
		_shots()

func w(t: float) -> void:
	await get_tree().create_timer(t, true, false, true).timeout

func shot(nm: String) -> void:
	if dir == "":
		return
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(dir + "/" + nm + ".png")

func _park_demons(far := true) -> void:
	for e in G.enemies:
		if is_instance_valid(e):
			if far:
				e.global_position = Vector3(90, 0.5, 90)
			e.set_physics_process(not far)

# Камера: смотрит на точку look из точки from.
func cam(from: Vector3, look: Vector3) -> void:
	var c: Camera3D = G.cam_rig.cam
	c.global_position = from
	c.look_at(look)

func _place(p: Vector3, face: float) -> void:
	var pl: Node3D = G.player
	pl.global_position = p
	pl.velocity = Vector3.ZERO
	pl.facing = face

func _times() -> Array:
	return ["day", "sunset", "night"]

func _set_time(t: String) -> void:
	if G.world.has_method("set_time"):
		G.world.set_time(t)
	else:
		G.world.set_night(t == "night")

func _shots() -> void:
	await w(0.6)
	G.hud.help = false
	_park_demons()
	G.cam_rig.set_process(false)
	var pl: Node3D = G.player
	for t in _times():
		_set_time(t)
		await w(0.3)
		# 1. герой крупно, 3/4
		_place(Vector3(0, 0.5, 2), 0.4)
		await w(0.4)
		cam(pl.global_position + Vector3(1.8, 1.5, 2.6), pl.global_position + Vector3(0, 1.1, 0))
		await shot("%s_1_hero" % t)
		# 2. общий план поляны и леса сверху
		cam(Vector3(-14, 9, 22), Vector3(4, 2, -10))
		await shot("%s_2_vista" % t)
		# 3. деревня
		var vp: Vector3 = G.world.get("village_view") if G.world.get("village_view") != null else Vector3(20, 0.5, -10)
		_place(vp, PI)
		await w(0.4)
		cam(pl.global_position + Vector3(-3.0, 2.2, 5.5), pl.global_position + Vector3(2.0, 1.5, -6.0))
		await shot("%s_3_village" % t)
		# 4. святилище среди кедров
		_place(Vector3(0, 0.5, -44), PI)
		await w(0.4)
		cam(Vector3(5, 3.0, -36), Vector3(0, 5.0, -62))
		await shot("%s_4_shrine" % t)
		# 5. пруд и мост
		_place(Vector3(-34, 2.0, -5), PI * 0.5)
		await w(0.4)
		cam(Vector3(-20, 3.5, 6), Vector3(-36, 0.5, -6))
		await shot("%s_5_pond" % t)
		# 6. кедр снизу вверх
		cam(Vector3(-24, 1.5, -2), Vector3(-17, 10.0, -16))
		await shot("%s_6_cedar" % t)
		# 7. вид с вышки на деревню и горы
		cam(Vector3(49.5, 9.3, -62.2), Vector3(30, 3.0, -20))
		await shot("%s_7_tower" % t)
	# 5. бой: форма дыхания рядом с демоном
	_set_time("sunset")
	G.cam_rig.set_process(true)
	_place(Vector3(0, 0.5, 4), PI)
	var d = G.enemies[0] if G.enemies.size() > 0 else null
	if d:
		d.global_position = Vector3(0, 0.5, 0.5)
		d.set_physics_process(true)
		d.state = "idle"
	pl.set_drawn(true)
	await w(0.8)
	pl.breath = 100.0
	pl.press("form1")
	await w(0.22)
	await shot("fight_1")
	await w(0.25)
	await shot("fight_2")
	get_tree().quit()

# Сценарий движения для видео: бег, рывки, прыжки, удары, форма.
func _move() -> void:
	await w(0.5)
	G.hud.help = false
	_park_demons()
	var pl: Node3D = G.player
	_set_time(OS.get_environment("KLINOK_TIME") if OS.get_environment("KLINOK_TIME") != "" else "sunset")
	_place(Vector3(0, 0.5, 8), PI)
	G.cam_rig.yaw = 0.0
	await w(0.5)
	pl.auto_move = Vector2(0, -1)
	await w(1.2)
	pl.press("dash")
	await w(0.5)
	pl.auto_sprint = true
	pl.press("dash")
	await w(1.0)
	pl.press("dash")
	await w(0.8)
	pl.auto_sprint = false
	pl.press("jump")
	await w(0.25)
	pl.press("jump")
	await w(1.2)
	pl.auto_move = Vector2.ZERO
	await w(0.4)
	if G.enemies.size() > 0:
		var d = G.enemies[0]
		d.global_position = pl.global_position + Vector3(0, 0, -3.5).rotated(Vector3.UP, pl.facing + PI)
		d.set_physics_process(true)
		d.state = "idle"
	for k in 4:
		pl.press("light")
		await w(0.3)
	await w(0.3)
	pl.breath = 100.0
	pl.press("form1")
	await w(1.4)
	pl.press("heavy")
	await w(1.2)
	get_tree().quit()
