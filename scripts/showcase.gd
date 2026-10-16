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
	elif mode == "fx":
		_fx()
	elif mode == "flame":
		_flame()
	elif mode == "new":
		_new()
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
	for t in (_times() if OS.get_environment("KLINOK_TIME") == "" else [OS.get_environment("KLINOK_TIME")]):
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

# Сценарий движения для видео: бег, взрывные рывки, прыжки по веткам кедра, бой.
func _aim(t: Vector3) -> void:
	var d: Vector3 = t - G.player.global_position
	G.cam_rig.yaw = atan2(-d.x, -d.z)

func _move() -> void:
	await w(0.5)
	G.hud.help = false
	_park_demons()
	var pl: Node3D = G.player
	_set_time(OS.get_environment("KLINOK_TIME") if OS.get_environment("KLINOK_TIME") != "" else "sunset")
	# старт на поляне, бежим к кедрам у западного края
	_place(Vector3(4, 0.5, 6), PI)
	var cedar: Node3D = null
	var bd := 999.0
	for c in get_tree().get_nodes_in_group("cedar"):
		var dd: float = c.global_position.distance_to(Vector3(-15.5, 0, -12))
		if dd < bd:
			bd = dd
			cedar = c
	_aim(cedar.global_position)
	await w(0.4)
	pl.auto_move = Vector2(0, -1)
	await w(0.5)
	pl.press("dash")
	await w(0.45)
	pl.press("dash")
	await w(0.45)
	pl.auto_move = Vector2.ZERO
	# по веткам вверх
	var pads: Array = cedar.pads.duplicate()
	pads.sort_custom(func(a, b): return a.y < b.y)
	var k := 0
	for q in pads:
		if k >= 6:
			break
		if q.y < pl.global_position.y + 0.8:
			continue
		pl.press("jump")
		await w(0.16)
		_aim(q)
		pl.press("jump")
		await w(0.75)
		k += 1
	await w(0.3)
	# прыжок вниз к поляне, рывок, бой
	_aim(Vector3(0, 0, 0))
	pl.auto_move = Vector2(0, -1)
	pl.press("jump")
	await w(1.6)
	pl.press("dash")
	await w(0.5)
	pl.auto_move = Vector2.ZERO
	if G.enemies.size() > 0:
		var d = G.enemies[0]
		d.global_position = pl.global_position + Vector3(sin(pl.facing), 0, cos(pl.facing)) * 3.5
		d.set_physics_process(true)
		d.state = "idle"
	for i in 4:
		pl.press("light")
		await w(0.3)
	await w(0.3)
	pl.breath = 100.0
	pl.press("form1")
	await w(1.4)
	get_tree().quit()

# Эффекты ударов по стилям дыхания: кадры на середине взмаха.
func _fx() -> void:
	await w(0.6)
	G.hud.help = false
	var pl: Node3D = G.player
	_set_time("sunset")
	G.cam_rig.set_process(false)
	var d = G.enemies[0]
	for st in 3:
		pl.set_breath(st)
		_place(Vector3(0, 0.5, 4), PI)
		d.global_position = Vector3(0, 0.5, 1.5)
		d.set_physics_process(false)
		pl.set_drawn(true)
		await w(0.6)
		for k in 3:
			pl.press("light")
			await w(0.16)
			cam(pl.global_position + Vector3(3.2, 1.8, 1.2), pl.global_position + Vector3(0, 1.0, -1.0))
			await shot("fx%d_%d" % [st, k])
			await w(0.18)
		pl.breath = 100.0
		pl.press("form1")
		await w(0.25)
		cam(pl.global_position + Vector3(4.0, 2.5, 3.0), pl.global_position + Vector3(0, 1.0, -1.0))
		await shot("fx%d_form" % st)
		await w(1.2)
	get_tree().quit()

# Огненный рывок (E со стилем пламени) — для видео.
func _flame() -> void:
	await w(0.5)
	G.hud.help = false
	_park_demons()
	var pl: Node3D = G.player
	_set_time("sunset")
	pl.set_breath(1)
	pl.set_drawn(true)
	_place(Vector3(0, 0.5, 14), PI)
	G.cam_rig.yaw = 0.0
	await w(0.8)
	for k in 3:
		pl.breath = 100.0
		pl.press("flash")
		await w(1.0)
	get_tree().quit()

# Новое в v0.37: кедры, огненный тигр, стихия на хаори, демон без ноги.
func _new() -> void:
	await w(0.6)
	G.hud.help = false
	var pl: Node3D = G.player
	_set_time(OS.get_environment("KLINOK_TIME") if OS.get_environment("KLINOK_TIME") != "" else "sunset")
	G.cam_rig.set_process(false)
	var d = G.enemies[0]
	_park_demons()
	# кедры
	_place(Vector3(-10, 0.5, 0), PI)
	await w(0.4)
	cam(Vector3(-6, 2.0, 6), Vector3(-17, 9.0, -14))
	await shot("n1_cedars")
	# огненный тигр (третья форма пламени)
	pl.set_breath(1)
	pl.set_drawn(true)
	_place(Vector3(0, 0.5, 6), PI)
	await w(0.6)
	pl.breath = 100.0
	pl.press("form3")
	await w(0.55)
	cam(pl.global_position + Vector3(5.0, 2.2, -1.0), pl.global_position + Vector3(0, 1.3, -4.0))
	await shot("n2_tiger_a")
	await w(0.2)
	await shot("n2_tiger_b")
	await w(1.0)
	# тигр отдельно, сбоку
	_place(Vector3(0, 0.5, 12), PI)
	G.fx.flame_tiger(Vector3(0, 1.6, 4), Vector3.FORWARD, 9.0, 1.6)
	await w(0.5)
	cam(Vector3(7, 2.5, 0), Vector3(0, 1.8, -1.0))
	await shot("n2_tiger_side")
	cam(Vector3(2, 2.0, -9), Vector3(0, 1.8, 0))
	await shot("n2_tiger_front")
	await w(1.2)
	# стихия на хаори: вода, пламя, гром
	for st in 3:
		pl.set_breath(st)
		_place(Vector3(0, 0.5, 6), 0.0)
		pl.haori_element(1.0)
		await w(0.5)
		cam(pl.global_position + Vector3(1.6, 1.4, -2.4), pl.global_position + Vector3(0, 0.9, 0))
		await shot("n3_haori_%d" % st)
	# демон без ноги
	d.global_position = Vector3(0, 0.5, 0)
	d.set_physics_process(true)
	d.state = "idle"
	_place(Vector3(0, 0.5, 5), PI)
	d._cut_leg("r", Vector3.RIGHT)
	await w(0.8)
	cam(Vector3(5.0, 2.4, 5.0), d.global_position + Vector3(0, 1.0, 0))
	await shot("n4_demon_leg")
	get_tree().quit()
