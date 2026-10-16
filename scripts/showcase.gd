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
	elif mode == "story":
		_story()
	elif mode == "play":
		_play()
	elif mode == "v39":
		_v39()
	elif mode == "boss":
		_boss()
	elif mode == "kinds":
		_kinds()
	elif mode == "fest":
		_fest()
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

# Сюжет: жители, разговор, задание с меткой, виды демонов.
func _story() -> void:
	await w(0.6)
	G.hud.help = false
	var st = G.story
	_park_demons()
	st._clear_demons()
	G.mode = "story"
	st._spawn_npcs()
	st.chapter = 2
	G.prog.chapter = 2
	G.prog.ryo = 140
	G.prog.mastery = 3
	st._day()
	await w(1.0)
	G.cam_rig.set_process(false)
	var pl: Node3D = G.player
	# наставник крупно
	var gn: Node3D = st.npcs.gensai
	cam(gn.global_position + Vector3(-1.2, 1.5, -2.2), gn.global_position + Vector3(0, 1.2, 0))
	await w(0.2)
	await shot("s1_gensai")
	# улица: староста, Окику, Таро
	_place(Vector3(32, 0.5, -24), PI)
	await w(0.3)
	cam(Vector3(33.5, 2.2, -10), Vector3(31, 1.0, -30))
	await shot("s2_street")
	var tt: Node3D = st.npcs.tetsu
	cam(tt.global_position + Vector3(-2.4, 1.4, 0.8), tt.global_position + Vector3(0, 1.1, 0))
	await shot("s3_smith")
	# ворон и подсказка «E — поговорить», задание
	G.cam_rig.set_process(true)
	_place(st.crow.global_position + Vector3(0, 0.5, 2.0), PI)
	await w(0.8)
	await shot("s4_crow")
	# разговор
	st.talk("crow")
	await w(1.6)
	await shot("s5_dialog")
	G.dialog_ui.shown = 9999.0
	for i in 3:
		G.dialog_ui.advance()
		await w(0.1)
	G.dialog_ui.shown = 9999.0
	await w(0.5)
	await shot("s6_choice")
	G.dialog_ui._pick(0)
	await w(1.6)
	await shot("s7_go")
	# виды демонов в ряд
	st.phase = "free"
	st.target = null
	G.cam_rig.set_process(false)
	_set_time("sunset")
	var x := -8.0
	for kd in ["low", "weaver", "hermit", "brute", "boss"]:
		var dm = CharacterBody3D.new()
		dm.set_script(load("res://scripts/demon.gd"))
		dm.kind = kd
		G.world.add_child(dm)
		dm.global_position = Vector3(x, 0.5, -2)
		dm.facing = 0.0
		dm.set_physics_process(false)
		x += 4.0
	_place(Vector3(0, 0.5, 30), PI)
	await w(0.8)
	cam(Vector3(0, 2.4, 9), Vector3(0, 1.6, -2))
	await shot("s8_demons")
	cam(Vector3(8.8, 2.6, 2.2), Vector3(8, 2.0, -2))
	await shot("s9_boss")
	# титры главы
	st._card("Глава 3", "Отшельник старого леса", 3.0)
	cam(Vector3(-14, 9, 22), Vector3(4, 2, -10))
	await w(0.8)
	await shot("s10_card")
	get_tree().quit()

# Настоящее начало игры для видео: титры, обучение, первый демон (бот жмёт клавиши).
func _talk_auto() -> void:
	while G.dialog:
		await w(1.3)
		G.dialog_ui.shown = 9999.0
		await w(0.5)
		if G.dialog_ui.buttons.size() > 0:
			G.dialog_ui._pick(0)
		else:
			G.dialog_ui.advance()

func _play() -> void:
	await w(0.5)
	G.hud.help = false
	var st = G.story
	var pl: Node3D = G.player
	st.new_game()
	await w(12.0)
	await _talk_auto()
	await w(0.8)
	pl.set_drawn(true)
	await w(1.0)
	await _talk_auto()
	pl.press("dash")
	await w(0.8)
	await _talk_auto()
	for k in 3:
		pl.press("light")
		await w(0.32)
	await w(0.8)
	await _talk_auto()
	pl.breath = 100.0
	pl.press("form1")
	await w(1.5)
	await _talk_auto()
	pl.press("parry")
	await w(0.8)
	await _talk_auto()
	await w(0.5)
	await _talk_auto()
	# бой с первым демоном
	var t := 0.0
	while st.phase == "fight" and t < 25.0:
		var d = null
		for e in st.alive:
			if is_instance_valid(e) and not e.is_dead():
				d = e
		if d == null:
			break
		var to: Vector3 = d.global_position - pl.global_position
		_aim(d.global_position)
		pl.auto_move = Vector2(0, -1) if Vector2(to.x, to.z).length() > 2.4 else Vector2.ZERO
		if Vector2(to.x, to.z).length() < 3.0:
			pl.press("light")
		await w(0.25)
		t += 0.25
	pl.auto_move = Vector2.ZERO
	await w(4.0)
	await _talk_auto()
	await w(3.0)
	get_tree().quit()

# v0.39: Метка охотника, большая карта, журнал, прохожие.
func _v39() -> void:
	await w(0.6)
	G.hud.help = false
	var st = G.story
	var pl: Node3D = G.player
	_park_demons()
	st._clear_demons()
	G.mode = "story"
	st._spawn_npcs()
	st.chapter = 4
	G.prog.chapter = 4
	G.prog.ryo = 320
	G.prog.mastery = 4
	st._day()
	await w(4.0)
	G.cam_rig.set_process(false)
	# прохожие на улице
	_place(Vector3(32, 0.5, -14), PI)
	await w(0.4)
	cam(Vector3(31.0, 2.0, -8), Vector3(31.5, 1.0, -30))
	await shot("v1_street")
	# Метка: лицо крупно
	_set_time("sunset")
	_place(Vector3(0, 0.5, 6), 0.0)
	pl.set_drawn(true)
	pl.add_fury(200.0)
	await w(0.5)
	pl.press("mark")
	await w(1.6)
	G.hud.big_t = 0.0
	st.card_t = 0.0
	cam(pl.global_position + Vector3(0.25, 1.72, 1.1), pl.global_position + Vector3(0, 1.62, 0))
	await shot("v2_mark_face")
	cam(pl.global_position + Vector3(2.2, 1.6, 3.2), pl.global_position + Vector3(0, 1.1, 0))
	await shot("v3_mark")
	# большая карта
	G.cam_rig.set_process(true)
	st.target = Vector3(-34, 0, 8)
	G.hud.big_map = true
	await w(0.4)
	await shot("v4_map")
	G.hud.big_map = false
	# журнал в паузе
	get_parent().menus.open_pause()
	await w(0.5)
	await shot("v5_journal")
	get_parent().menus.close_menu()
	get_tree().quit()

# Бой с Тенью: фазы кровавой луны и лужи.
func _boss() -> void:
	await w(0.6)
	G.hud.help = false
	var st = G.story
	var pl: Node3D = G.player
	st._clear_demons()
	_set_time("night")
	var b = CharacterBody3D.new()
	b.set_script(load("res://scripts/demon.gd"))
	b.kind = "boss"
	G.world.add_child(b)
	b.global_position = Vector3(0, 3.6, -60)
	_place(Vector3(0, 3.6, -54), PI)
	pl.set_drawn(true)
	await w(1.5)
	G.cam_rig.set_process(false)
	cam(Vector3(5, 5.5, -48), Vector3(0, 4.5, -59))
	await shot("b1_phase1")
	b.hp = 0.0
	b._expose()
	b.decapitate(Vector3.FORWARD)
	b.pool_cd = 0.0
	await w(1.6)
	cam(Vector3(6, 6.5, -46), Vector3(0, 4.0, -58))
	await shot("b2_phase2")
	b.hp = 0.0
	b._expose()
	b.decapitate(Vector3.FORWARD)
	b.pool_cd = 0.0
	await w(1.8)
	cam(Vector3(-6, 6.0, -47), Vector3(0, 4.0, -58))
	await shot("b3_phase3")
	get_tree().quit()

func _kinds() -> void:
	await w(0.6)
	G.hud.help = false
	G.story._clear_demons()
	_set_time("sunset")
	var x := -10.0
	var sp_d = null
	for kd in ["low", "weaver", "spider", "brute", "boss", "boss2"]:
		var dm = CharacterBody3D.new()
		dm.set_script(load("res://scripts/demon.gd"))
		dm.kind = kd
		G.world.add_child(dm)
		dm.global_position = Vector3(x, 0.5, -2)
		dm.facing = 0.0
		dm.set_physics_process(false)
		if kd == "boss2":
			sp_d = dm
		x += 4.0
	_place(Vector3(0, 0.5, 60), PI)
	await w(1.0)
	G.cam_rig.set_process(false)
	cam(Vector3(0, 2.6, 10), Vector3(0, 1.4, -2))
	await shot("k1_lineup")
	cam(sp_d.global_position + Vector3(2.4, 1.6, 2.6), sp_d.global_position + Vector3(0, 0.8, 0))
	await shot("k2_spider")
	get_tree().quit()

func _fest() -> void:
	await w(0.6)
	G.hud.help = false
	var st = G.story
	var pl: Node3D = G.player
	st._clear_demons()
	G.world.festival(true)
	_set_time("night")
	_place(Vector3(32, 0.5, -20), PI)
	await w(0.6)
	G.cam_rig.set_process(false)
	cam(Vector3(32, 2.2, -4), Vector3(32, 3.0, -30))
	await shot("f1_fest_night")
	_set_time("sunset")
	await w(0.3)
	await shot("f2_fest_sunset")
	# ледяное кольцо Сэйрэн
	_set_time("night")
	var b = CharacterBody3D.new()
	b.set_script(load("res://scripts/demon.gd"))
	b.kind = "boss2"
	G.world.add_child(b)
	b.global_position = Vector3(0, 0.5, -4)
	_place(Vector3(0, 0.5, 10), PI)
	await w(0.8)
	b._frost_ring()
	await w(0.5)
	cam(Vector3(8, 4.5, 8), Vector3(0, 0.5, -3))
	await shot("f3_frost")
	get_tree().quit()
