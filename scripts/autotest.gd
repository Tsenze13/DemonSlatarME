extends Node
const SwordLibT = preload("res://scripts/sword_lib.gd")
# Автотест: бот проходит по всем действиям, делает снимки экрана
# (если задан KLINOK_SHOTS) и печатает итог. Запуск: KLINOK_AUTOTEST=1.

var shots_dir := ""
var log_lines: Array = []
var fails: Array = []

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	shots_dir = OS.get_environment("KLINOK_SHOTS")
	seed(12345)
	_run()

func w(t: float) -> void:
	await get_tree().create_timer(t, true, false, true).timeout

func shot(nm: String) -> void:
	if shots_dir == "":
		return
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(shots_dir + "/" + nm + ".png")

func check(ok: bool, what: String) -> void:
	if ok:
		log_lines.append("OK   " + what)
	else:
		log_lines.append("FAIL " + what)
		fails.append(what)

func demon() -> Node:
	for e in G.enemies:
		if is_instance_valid(e) and not e.is_dead():
			return e
	return null

func approach(d: Node, max_t := 4.0) -> void:
	var p: Node = G.player
	var t := 0.0
	while t < max_t and is_instance_valid(d) and p.global_position.distance_to(d.global_position) > 3.0:
		var to: Vector3 = d.global_position - p.global_position
		G.cam_rig.yaw = atan2(-to.x, -to.z)
		p.auto_move = Vector2(0, -1)
		await w(0.05)
		t += 0.05
	p.auto_move = Vector2.ZERO

func _run() -> void:
	var p: Node = G.player
	await w(0.3)
	# демона пока в сторону, чтобы не мешал проверять движение
	var d_park := demon()
	var d_home: Vector3 = d_park.global_position
	d_park.global_position = Vector3(80, 0.5, -80)
	d_park.state = "idle"
	await w(0.9)
	# крупные планы героя
	G.cam_rig.dist = 2.6
	G.cam_rig.pitch = -0.12
	for v in [["00_front", PI], ["00_side", PI * 0.62], ["00_back", 0.15]]:
		G.cam_rig.yaw = v[1]
		await w(0.35)
		await shot(v[0])
	G.cam_rig.yaw = PI * 0.5
	p.auto_move = Vector2(-1, 0)
	await w(0.9)
	await shot("00_run_side")
	p.auto_move = Vector2.ZERO
	G.cam_rig.dist = 5.2
	G.cam_rig.pitch = -0.3
	p.global_position = Vector3(0, 0.5, 8)
	await w(0.5)
	await shot("01_start")
	check(not p.drawn, "в начале клинок в ножнах")
	# все мечи из набора ставятся в руку и в ножны
	var ok_sw := true
	for si in range(-1, 11):
		p.set_sword(si)
		p.set_drawn(true)
		await w(0.15)
		var bl: float = p.blade_base.global_position.distance_to(p.blade_tip.global_position)
		if p.sword_mode == "whip":
			bl = p.blade_base.global_position.distance_to(p.whip.tip())
			if bl < 0.8:
				ok_sw = false
				print("хлыст ", bl)
		elif bl < 0.25 or bl > 1.1:
			ok_sw = false
			print("меч ", si, " длина ", bl)
	check(ok_sw, "все виды оружия ставятся")
	p.set_sword(0)
	for sa in SwordLibT.SAYA.size():
		p.set_look(sa, sa % SwordLibT.TINTS.size())
		await w(0.03)
	check(p.scabbard_node.get_child_count() > 0, "все виды ножен и цвета клинка ставятся")
	for hi in SwordLibT.HAORI.size():
		p.set_haori(hi)
		await w(0.03)
	check(p.haori_cloth_mats.size() >= 1 and p.haori_style == SwordLibT.HAORI.size() - 1, "все узоры хаори ставятся")
	p.set_haori(0)
	# стили дыхания: эффекты и названия форм
	var ok_br := true
	for bi in G.BREATH_ORDER.size():
		p.set_breath(bi)
		var o2: Vector3 = p.global_position + Vector3.UP
		G.fx.breath_arc(o2, Vector3.FORWARD, 0.0, 2.5, 180.0, 1.0)
		G.fx.breath_burst(o2, Vector3.UP, 8)
		p.atk = p.ATK["f1"]
		p._form_big_fx(o2, p.atk)
		await w(0.25)
		if G.hud._form("f1")[1] != G.br().forms[0]:
			ok_br = false
	check(ok_br and G.fx.bolts.size() >= 0, "стили дыхания: вода, пламя, гром")
	p.set_breath(0)
	p.set_look(0, 0)
	# парные клинки: цепь, бинты за спиной, размотка при выхвате, намотка обратно, бросок на цепи
	if SwordLibT.count() >= 8:
		p.set_sword(6)
		p.set_drawn(false)
		G.cam_rig.dist = 2.6
		G.cam_rig.pitch = -0.12
		G.cam_rig.yaw = 0.35
		await w(0.5)
		await shot("00d_dual_back")
		check(p.bandage.visible_bands() >= 20, "парные за спиной в бинтах (%d витков)" % p.bandage.visible_bands())
		check(p.chain.visible and p.chain.pos[0].distance_to(p.chain.pa) < 0.01, "цепь между навершиями")
		p.press("draw")
		await w(0.1)
		await shot("00d_unwrap")
		check(p.bandage.strips.size() > 0, "бинты разматываются и спадают")
		await w(0.45)
		check(p.drawn and p.bandage.visible_bands() == 0, "парные в руках, бинтов нет")
		G.cam_rig.yaw = PI * 0.8
		await w(0.4)
		check(p.bandage.strips.size() == 0, "упавшие бинты исчезли")
		await shot("00d_dual_stance")
		check(p.chain.sag() > 0.08, "цепь провисает между руками (%.2f)" % p.chain.sag())
		check(SwordLibT.pommel(6) < SwordLibT.info(6).handle - 0.02, "цепь крепится к навершию, обрывок цепи модели спрятан")
		# цепь не растягивается в ударах
		var ch_pos: Vector3 = p.global_position
		var ch_face: float = p.facing
		var ch_worst := 0.0
		for k in 3:
			p.press("light")
			for f in 6:
				await w(0.03)
				var tot := 0.0
				for i in p.chain.n - 1:
					tot += p.chain.pos[i].distance_to(p.chain.pos[i + 1])
				ch_worst = maxf(ch_worst, tot / maxf(p.chain.length, p.chain.pa.distance_to(p.chain.pb)))
		check(ch_worst < 1.15, "цепь не растягивается в ударах (%.2f)" % ch_worst)
		await w(1.2)
		p.global_position = ch_pos
		p.facing = ch_face
		p.velocity = Vector3.ZERO
		G.cam_rig.dist = 4.5
		G.cam_rig.yaw = PI * 0.5
		var tp0: Vector3 = p.global_position
		p.press("heavy")
		await w(0.28)
		await shot("00d_throw")
		var far: float = p.thrown.global_position.distance_to(tp0) if p.thrown.visible else 0.0
		check(p.atk_name == "chain" and far > 3.5, "бросок клинка на цепи (%.1f м)" % far)
		check(p.chain.pa.distance_to(p.chain.pb) > 3.0, "цепь тянется за брошенным клинком")
		var nl := 0
		for lk in p.chain.links:
			if lk.visible:
				nl += 1
		check(nl > 45, "длинная цепь — больше звеньев, а не растянутые (%d)" % nl)
		await w(0.6)
		check(not p.thrown.visible and p.sword_vis.visible, "клинок вернулся в руку")
		G.cam_rig.dist = 2.6
		G.cam_rig.yaw = 0.35
		p.press("draw")
		await w(0.32)
		await shot("00d_wrap")
		await w(0.5)
		check(not p.drawn and p.bandage.is_wrapped(), "на спине бинты намотались обратно")
		await shot("00d_wrapped")
		G.cam_rig.dist = 5.2
		G.cam_rig.pitch = -0.3
	p.set_sword(0)
	p.set_drawn(false)
	# у каждого оружия свои удары
	var sets := [[6, "d1", "chain"], [7, "w1", "wheavy"], [9, "n1", "nheavy"], [10, "fl1", "flheavy"], [0, "l1", "heavy"]]
	var ok_sets := true
	for st in sets:
		p.set_sword(st[0])
		p.set_drawn(true)
		await w(0.1)
		p.press("light")
		await w(0.05)
		var a1: String = p.atk_name
		await w(0.5)
		p.press("heavy")
		await w(0.05)
		var a2: String = p.atk_name
		await w(0.9)
		if a1 != st[1] or a2 != st[2]:
			ok_sets = false
			print("оружие ", st[0], ": ", a1, " ", a2)
	check(ok_sets, "у каждого оружия свои удары")
	# нагината и шар на цепи: за спиной, выхват, шар летит
	p.set_sword(10)
	p.set_drawn(false)
	await w(0.3)
	check(p.back_sheath.visible and p.flail.visible, "топор за спиной, шар на цепи висит")
	p.press("draw")
	await w(0.6)
	check(p.drawn, "топор достаётся из-за спины")
	var bp0: Vector3 = p.global_position
	p.press("heavy")
	await w(0.42)
	var bd: float = p.flail.pos.distance_to(bp0)
	check(bd > 4.0, "шар бросается на цепи (%.1f м)" % bd)
	await w(0.8)
	p.set_sword(9)
	p.set_drawn(false)
	await w(0.2)
	p.press("draw")
	await w(0.6)
	check(p.drawn and p.sword_mode == "naginata", "нагината достаётся из-за спины")
	var tip_d: float = p.blade_tip.global_position.distance_to(p.J.sword.global_position)
	check(tip_d > 1.5, "нагината длинная (%.2f м)" % tip_d)
	p.set_sword(0)
	p.set_drawn(false)
	p.set_drawn(false)
	# анимации: прыжок с приземлением, сбивание с ног и подъём
	p.press("jump")
	await w(0.25)
	check(not p.is_on_floor(), "прыжок")
	await w(1.0)
	check(p.is_on_floor() and p.land_t < 1.2, "приземление отыграно (присед)")
	var hp0: float = p.hp
	p.receive_attack(20.0, p.global_position + Vector3(0, 0, 2), false)
	await w(0.1)
	check(p.state == "down", "сильный удар сбивает с ног")
	check(p.cut_count() > 0, "на герое виден порез (внутри текстуры)")
	# хаори: разрезы по бокам, ткань обтекает ноги, рвётся от удара
	var hb = p.haori_body
	# клинки игрока — свой шейдер: свет, кромка, блик, контур
	var sw_ok := false
	for mi in p.sword_vis.find_children("*", "MeshInstance3D", true, false):
		var sm = mi.material_override
		if sm is ShaderMaterial and sm.shader and sm.shader.resource_path.ends_with("sword.gdshader") and sm.next_pass != null:
			sw_ok = true
	check(sw_ok, "клинок с кромкой, бликом и контуром")
	check(hb.slit_cols.size() == 2 and hb.colliders.size() >= 4, "у хаори разрезы по бокам и ноги-капсулы")
	hb.mend()
	hb.tear(p.global_position + Vector3(0, 0.7, -0.3), 0.5)
	check(hb.tear_count() > 0, "хаори рвётся от удара")
	var spread := 0.0
	for k in 6:
		await w(0.05)
	for c in hb.tears:
		var r0: int = hb.tears[c].r0
		spread = maxf(spread, hb.pos[hb._idx(c, hb.rows - 1)].distance_to(hb.pos[hb._idx(c + 1, hb.rows - 1)]))
	check(spread > 0.0, "края разрыва свободны (%.2f)" % spread)
	await w(1.5)
	check(p.state == "move", "герой поднялся")
	await w(4.0)
	check(hb.tear_count() == 0, "разрыв хаори зашился")
	p.hp = hp0
	# настоящая мышь: поворот камеры и удар ЛКМ должны доходить до игры
	var y0: float = G.cam_rig.yaw
	var mm := InputEventMouseMotion.new()
	mm.relative = Vector2(200, 0)
	Input.parse_input_event(mm)
	await w(0.1)
	check(absf(G.cam_rig.yaw - y0) > 0.1, "мышь вращает камеру")
	var iai_from: Vector3 = p.global_position
	var mb := InputEventMouseButton.new()
	mb.button_index = MOUSE_BUTTON_LEFT
	mb.pressed = true
	Input.parse_input_event(mb)
	await w(0.15)
	var mb2 := InputEventMouseButton.new()
	mb2.button_index = MOUSE_BUTTON_LEFT
	mb2.pressed = false
	Input.parse_input_event(mb2)
	check(p.state == "attack" or p.atk_name == "l1", "ЛКМ бьёт")
	check(p.atk_name == "iai" and p.drawn, "первый удар — из ножен, клинок достан")
	await w(0.3)
	var iai_len: float = Vector3(p.global_position.x - iai_from.x, 0, p.global_position.z - iai_from.z).length()
	check(iai_len > 5.0, "удар из ножен — резкий рывок (%.1f м)" % iai_len)
	await w(0.2)
	p.press("draw")
	await w(0.45)
	check(not p.drawn, "F убирает клинок в ножны")
	p.press("draw")
	await w(0.45)
	check(p.drawn, "F достаёт клинок")
	G.cam_rig.dist = 2.6
	G.cam_rig.pitch = -0.12
	G.cam_rig.yaw = PI * 0.75
	await w(0.4)
	await shot("02c_grip")
	G.cam_rig.dist = 5.2
	G.cam_rig.pitch = -0.3
	G.cam_rig.yaw = 0.0
	# бег (вбок, не на демона) — по длинной улице деревни, там ничего не мешает
	p.global_position = Vector3(32, 0.5, -2)
	p.velocity = Vector3.ZERO
	G.cam_rig.yaw = -PI * 0.5
	await w(0.3)
	p.auto_move = Vector2(-1, 0)
	await w(1.0)
	if p.last_speed < 10.0:
		print("dbg run state ", p.state, " pos ", p.global_position, " vel ", p.velocity, " inp ", p._input_dir(), " am ", p.auto_move)
	check(p.last_speed > 10.0, "бег быстрый (%.1f м/с)" % p.last_speed)
	await shot("02_run")
	p.press("dash")
	await w(0.08)
	check(p.state == "dash", "рывок")
	await shot("03_dash")
	# бег на дыхании: держим Shift после рывка
	p.breath = 100.0
	p.auto_sprint = true
	p.press("dash")
	await w(0.7)
	check(p.sprinting and p.last_speed > 20.0, "быстрый бег (%.1f м/с)" % p.last_speed)
	check(p.breath < 98.0, "старт быстрого бега тратит дыхание")
	var b_run: float = p.breath
	await w(0.6)
	check(p.breath >= b_run - 0.5, "сам быстрый бег дыхание не тратит")
	p.auto_sprint = false
	# разгон: рывки на бегу поднимают скорость (по длинной улице деревни)
	p.global_position = Vector3(32, 0.5, -10)
	p.velocity = Vector3.ZERO
	G.cam_rig.yaw = -PI * 0.5
	p.momentum = 0
	await w(0.5)
	for k in 3:
		p.dash_charges = 2.0
		p.press("dash")
		await w(0.35)
	if p.momentum < 3: print("dbg mom ", p.global_position, " ", p.state, " ", p.velocity)
	check(p.momentum >= 3 and p.last_speed > 24.0, "разгон рывками (ступень %d, %.1f м/с)" % [p.momentum, p.last_speed])
	# перемещение стихией (E): у каждого стиля своя дальность
	p.auto_move = Vector2.ZERO
	var ok_fl := true
	for bi in G.BREATH_ORDER.size():
		p.set_breath(bi)
		p.global_position = Vector3(0, 0.5, 6)
		p.velocity = Vector3.ZERO
		p.facing = 0.0
		p.breath = 100.0
		await w(0.3)
		var fp0: Vector3 = p.global_position
		p.press("flash")
		await w(0.6)
		var fd: float = Vector3(p.global_position.x - fp0.x, 0, p.global_position.z - fp0.z).length()
		if fd < 8.0:
			ok_fl = false
			print("перемещение ", G.breath_style, " ", fd)
	check(ok_fl, "перемещение стихией на E: вода, огненный рывок, громовой шаг")
	p.set_breath(0)
	await shot("03b_sprint")
	p.auto_sprint = false
	# хаори не задирается выше плеч
	var torso: Node3D = p.J.torso
	var hi := -99.0
	for c in p.cloths:
		if c.mode == "blocks" and c.cols > 5:
			for q in c.pos:
				hi = maxf(hi, (torso.global_transform.affine_inverse() * q).y)
	check(hi < 0.5, "хаори не выше плеч (%.2f)" % hi)
	# рукава — цельные блоки с карманом (без физики-ткани — не ломаются)
	var sleeve_cloth := 0
	for c in p.cloths:
		if c.mode == "blocks" and c != p.haori_body:
			sleeve_cloth += 1
	check(sleeve_cloth == 0, "рукава цельные, ткань-карманы не болтаются")
	# тяжёлый удар с наклоном корпуса: хаори не тянется и не уходит вперёд, под живот
	p.auto_move = Vector2.ZERO
	p.sprinting = false
	await w(0.4)
	p.press("heavy")
	var worst := 0.0
	var front := -9.0
	var hb2 = p.haori_body
	for f in 12:
		await w(0.03)
		for c in hb2.cols:
			for r in range(1, hb2.rows):
				worst = maxf(worst, hb2.pos[hb2._idx(c, r)].distance_to(hb2.pos[hb2._idx(c, r - 1)]) / hb2.seg)
		var back_c: int = hb2.cols / 2
		var lp: Vector3 = p.J.torso.global_transform.affine_inverse() * hb2.pos[hb2._idx(back_c, 4)]
		front = maxf(front, lp.z)
	check(worst < 1.1, "хаори не растягивается в ударе (%.2f)" % worst)
	check(front < 0.05, "спинка хаори остаётся за спиной (%.2f)" % front)
	await w(0.6)
	p.auto_move = Vector2.ZERO
	p.sprinting = false
	p.global_position = Vector3(0, 0.5, 6)
	p.velocity = Vector3.ZERO
	await w(0.6)
	var d := demon()
	check(d != null, "демон есть")
	d.global_position = d_home
	d.noticed = false
	d.state = "idle"
	await w(1.2)
	await approach(d)
	p.press("lock")
	await w(0.1)
	check(p.lock_target != null, "захват цели")
	# комбо
	var hits0: int = p.hits_total
	var launched := false
	# чтобы прыжок демона не сбил героя посреди проверки комбо
	if d.state in ["leap_wind", "leap", "windup", "swing", "spikes"]:
		d._set_state("chase")
	d.atk_cd = 3.0
	for i in 4:
		p.press("light")
		for f in 9:
			await w(0.03)
			if d.state == "air":
				launched = true
		if i == 3:
			await shot("04_combo4")
	for f in 15:
		await w(0.03)
		if d.state == "air":
			launched = true
	check(p.hits_total - hits0 >= 3, "удары комбо попадают по движению клинка (%d)" % (p.hits_total - hits0))
	check(launched, "восходящий срез подбрасывает демона")
	await w(1.6)
	check(d.state != "down" and d.state != "air", "демон поднялся (%s)" % d.state)
	check(d.Wounds.count(d.wounds) > 0, "на демоне порезы внутри текстуры (%d)" % d.Wounds.count(d.wounds))
	# регенерация после паузы
	var hp_before: float = d.hp
	var dpos: Vector3 = d.global_position
	d.global_position = Vector3(70, 0.5, 70)
	d.state = "idle"
	d.hp = d.max_hp * 0.5
	hp_before = d.hp
	# отрубленная рука отрастает по вокселям: культя → кость → мышцы → кожа
	if d.arms_alive["l"]:
		d._cut_arm("l", Vector3.RIGHT)
	check(d.stumps.has("l"), "на месте отрубленной руки — культя")
	d.arm_regrow["l"] = 2.6
	await w(0.8)
	check(d.growers.has("l") and is_instance_valid(d.growers["l"]), "рука растёт по вокселям")
	await shot("04b_regrow")
	await w(3.2)
	check(d.hp > hp_before + 40.0, "демон регенерирует после паузы (+%.0f)" % (d.hp - hp_before))
	check(d.arms_alive["l"] and not d.growers.has("l") and not d.stumps.has("l"), "рука отросла целиком")
	# отрубленная нога: демон оседает на колено, нога отрастает
	d._cut_leg("r", Vector3.RIGHT)
	check(not d.legs_alive["r"] and d.stumps.has("leg_r"), "нога отрублена — культя")
	d.leg_regrow["r"] = 2.6
	await w(0.8)
	check(d.growers.has("leg_r"), "нога растёт по вокселям")
	await w(3.0)
	check(d.legs_alive["r"] and not d.stumps.has("leg_r"), "нога отросла")
	d.global_position = dpos
	await approach(d)
	p.press("heavy")
	await w(0.42)
	await shot("05_heavy")
	await w(0.6)
	p.breath = 100.0
	await approach(d)
	p.press("form1")
	await w(0.24)
	await shot("06_form1")
	await w(0.25)
	await shot("06b_form1_after")
	await w(0.6)
	p.breath = 100.0
	await approach(d)
	p.press("form2")
	await w(0.45)
	await shot("07_form2")
	await w(1.0)
	p.breath = 100.0
	p.press("form3")
	await w(0.3)
	await shot("08_form3")
	await w(1.2)
	# формы Пламени и Грома — свои движения и попадают по демону
	var ok_forms := true
	for bi in [1, 2]:
		p.set_breath(bi)
		for fi in 3:
			d = demon()
			if d == null:
				break
			d.hp = d.max_hp
			d.atk_cd = 3.0
			if d.state in ["leap_wind", "leap", "windup", "swing", "spikes", "air", "down"]:
				d._set_state("chase")
			p.global_position = d.global_position + Vector3(0, 0, 3.0)
			p.velocity = Vector3.ZERO
			p.hp = p.max_hp
			p.breath = 100.0
			p.cd.clear()
			await w(0.25)
			var h0: int = p.hits_total
			p.press("form%d" % (fi + 1))
			await w(0.08)
			var want: String = p.FORMS[G.breath_style][fi]
			if p.atk_name != want:
				ok_forms = false
				print("форма ", G.breath_style, " ", fi + 1, ": ", p.atk_name, " вместо ", want)
			await w(1.2)
			if p.hits_total <= h0:
				ok_forms = false
				print("форма ", want, " не попала")
	check(ok_forms, "формы Пламени и Грома свои и попадают")
	p.set_breath(0)
	# парирование: ждём замах демона
	var parried := false
	var tt := 0.0
	while tt < 8.0 and not parried:
		d = demon()
		if d == null:
			break
		p.hp = p.max_hp
		if d.state == "windup" and d.state_t > d.windup_time() - 0.14:
			p.press("parry")
			await w(0.3)
			if d.state == "stagger":
				parried = true
				await shot("09_parry")
		else:
			if p.global_position.distance_to(d.global_position) > 3.2:
				await approach(d, 1.0)
			await w(0.03)
			tt += 0.03
	check(parried, "парирование сработало")
	await w(0.5)
	# дыхание (демона отодвинем, чтобы не мешал)
	d = demon()
	if d:
		d.global_position = Vector3(60, 0.5, 60)
		d.state = "idle"
	p.hp = p.max_hp
	await w(0.3)
	p.auto_breathe = true
	p.breath = 20.0
	await w(1.0)
	check(p.breath > 40.0, "дыхание восстанавливается (%.0f)" % p.breath)
	await shot("10_breathe")
	p.auto_breathe = false
	await w(0.3)
	# добивание
	d = demon()
	if d:
		d.global_position = p.global_position + Vector3(0, 0.3, -3.0)
		await w(0.2)
		await approach(d)
		d.hp = 1.0
		d.state = "chase"
		p.press("light")
		await w(0.35)
		check(d.is_exposed(), "шея открыта при 0 здоровья")
		await shot("11_exposed")
		await approach(d)
		p.press("light")
		await w(0.12)
		check(p.state == "finisher", "добивание началось")
		await w(0.12)
		await shot("12_finisher_a")
		await w(0.5)
		await shot("13_finisher_b")
		await w(1.5)
		check(not is_instance_valid(d) or d.is_dead(), "демон обезглавлен")
		await shot("14_after")
	# отталкивание от дерева
	var tree: Node = null
	for t in get_tree().get_nodes_in_group("kick"):
		if t.get("kind") == "tree" and t.global_position.x < 1000.0:
			tree = t
			break
	if tree:
		p.global_position = tree.global_position + Vector3(1.0, 0.2, 0)
		p.velocity = Vector3.ZERO
		await w(0.3)
		p.press("jump")
		await w(0.25)
		p.press("jump")
		await w(0.05)
		var spd: float = Vector3(p.velocity.x, 0, p.velocity.z).length()
		check(spd > 12.0, "отталкивание от дерева (%.1f м/с)" % spd)
		await shot("15_kick")
		await w(1.0)
	# бег по стене (каменная стена на z=48)
	p.global_position = Vector3(0, 0.2, 42.0)
	p.velocity = Vector3.ZERO
	G.cam_rig.yaw = PI   # смотреть на +z
	await w(0.3)
	p.auto_move = Vector2(-0.5, -1)
	await w(0.3)
	p.press("jump")
	var seen_wall := false
	for i in 40:
		await w(0.025)
		if p.state == "wallrun":
			seen_wall = true
			break
	check(seen_wall, "бег по стене")
	await w(0.2)
	await shot("16_wallrun")
	p.auto_move = Vector2.ZERO
	await w(1.0)
	# разрушение: удар по забору (демона подальше)
	d = demon()
	if d:
		d.global_position = Vector3(80, 0.5, -80)
		d.state = "idle"
	var fence: Node = null
	for b in get_tree().get_nodes_in_group("breakable"):
		if b.get_script() == load("res://scripts/breakable.gd") and b.need_power == 1:
			fence = b
			break
	if fence:
		var fpos: Vector3 = fence.global_position
		p.global_position = fpos + Vector3(2.0, 0.3, 0)
		p.velocity = Vector3.ZERO
		p.facing = atan2(-1.0, 0.0)
		p.lock_target = null
		await w(0.3)
		p.press("heavy")
		await w(0.6)
		check(not is_instance_valid(fence), "забор разрушен")
		await shot("17_break")
	# срубить дерево формой
	var tree2: Node = null
	for t in get_tree().get_nodes_in_group("kick"):
		if t.get("kind") == "tree" and Vector2(t.global_position.x, t.global_position.z).length() < 60.0:
			tree2 = t
	if tree2:
		p.global_position = tree2.global_position + Vector3(2.5, 0.3, 0)
		p.velocity = Vector3.ZERO
		p.facing = atan2(-1.0, 0.0)
		p.breath = 100.0
		await w(0.3)
		p.press("form1")
		await w(0.6)
		check(tree2.cut, "дерево срублено")
		await w(0.6)
		await shot("18_tree_cut")
	# меню паузы
	get_parent()._toggle_pause()
	await w(0.3)
	await shot("20_pause")
	check(get_parent().menu.visible, "меню паузы открывается")
	get_parent()._set_volume(0.2, true)
	check(AudioServer.get_bus_volume_db(0) < -10.0, "громкость меняется")
	var mn = get_parent().menus
	check(mn.tabs.get_tab_count() == 5, "в паузе 5 вкладок (журнал + настройки)")
	for ti in mn.tabs.get_tab_count():
		mn.tabs.current_tab = ti
		await w(0.15)
		await shot("20_tab%d" % ti)
	check(AudioServer.get_bus_index("SFX") >= 0 and AudioServer.get_bus_index("Music") >= 0, "отдельные шины эффектов и музыки")
	# переназначение клавиши и возврат
	var ek := InputEventKey.new()
	ek.physical_keycode = KEY_G
	G.bind_key("draw", ek)
	check(G.key_text("draw") == "G", "клавиша переназначается (%s)" % G.key_text("draw"))
	G.reset_keys()
	check(G.key_text("draw") == "F", "клавиши по умолчанию возвращаются")
	mn.settings.render_scale = 0.7
	mn._apply_graphics()
	check(absf(get_parent().vp.scaling_3d_scale - 0.7) < 0.01, "чёткость 3D меняется")
	mn.settings.render_scale = 1.0
	mn.settings.grass = 0.5
	mn._apply_graphics()
	check(G.world.grass_mm.visible_instance_count < G.world.grass_mm.instance_count, "густота травы меняется")
	mn.settings.grass = 1.0
	mn._apply_graphics()
	# наборы качества: «Низкое» для слабых ПК и обратно «Высокое»
	mn.set_preset(0)
	check(get_parent().vp.msaa_3d == Viewport.MSAA_DISABLED and not G.world.env.glow_enabled and G.cam_rig.cam.far < 300.0, "набор «Низкое»: без сглаживания и свечения, даль ближе")
	mn.set_preset(2)
	check(get_parent().vp.msaa_3d == Viewport.MSAA_4X and G.world.env.glow_enabled and G.cam_rig.cam.far > 400.0, "набор «Высокое»")
	mn.settings.grass = 0.9
	mn._custom()
	check(mn.settings.preset == 3, "ручная правка — набор «Своё»")
	mn.set_preset(2)
	get_parent()._toggle_pause()
	await w(0.2)
	# главное меню
	mn.show_title()
	await w(0.3)
	await shot("21_title")
	check(mn.title_screen.visible and not G.started, "главное меню")
	mn._start_game()
	await w(0.2)
	check(G.started, "игра начинается из меню")
	# гибель и возрождение
	p.receive_attack(999.0, p.global_position + Vector3(0, 0, 2), false)
	await w(2.6)
	await shot("22_dead")
	check(p.state == "dead", "герой пал")
	p.press("jump")
	await w(0.2)
	check(p.state != "dead" and p.hp == p.max_hp, "возрождение по Пробелу")
	# день
	G.world.set_night(false)
	p.global_position = Vector3(0, 0.3, 6)
	G.cam_rig.yaw = 0.0
	await w(1.0)
	await shot("19_day")
	G.world.set_night(true)
	# новый демон
	await w(5.5)
	check(demon() != null, "новый демон появился")
	check(G.world.fireflies != null and G.world.leaves != null, "светлячки, листья")
	# идеальное парирование и ответ демона на долгое комбо
	var dd2 := demon()
	if dd2:
		p.global_position = Vector3(0, 0.5, 6)
		p.velocity = Vector3.ZERO
		p._set_state("move")
		p._set_state("parry")
		var r0: String = p.receive_attack(10.0, p.global_position + Vector3(0, 0, -2), true, dd2)
		check(r0 == "parry" and p.last_parry_perfect, "идеальное парирование в последний миг")
		await w(1.2)
		dd2.global_position = p.global_position + Vector3(0, 0.3, -2.0)
		dd2.state = "chase"
		dd2.combo_t = 0.0
		var ab := {"power": 1, "knock": 0.5, "stagger": 0.0}
		for k in 7:
			dd2.take_hit(1.0, Vector3(0, 0, -1), ab)
		await w(0.2)
		check(dd2.state == "air" or dd2.combo_hits == 0, "демон вырывается из долгого комбо")
		await w(2.0)
		p.hp = p.max_hp
	# прыжки по ветвям кедров: в воздухе Пробел — к ветке, в которую смотрит камера
	var cedar: Node3D = null
	var cbd := 999.0
	for c in get_tree().get_nodes_in_group("cedar"):
		var cdd: float = c.global_position.distance_to(Vector3(-15.5, 0, -12))
		if cdd < cbd:
			cbd = cdd
			cedar = c
	if cedar:
		var pad0: Vector3 = cedar.pads[0]
		var away := Vector3(pad0.x - cedar.global_position.x, 0, pad0.z - cedar.global_position.z).normalized()
		p.global_position = Vector3(pad0.x, 0.0, pad0.z) + away * 6.0
		p.velocity = Vector3.ZERO
		p._set_state("move")
		await w(0.3)
		G.cam_rig.yaw = atan2(away.x, away.z)
		p.press("jump")
		await w(0.2)
		var lc: int = p.leap_count
		p.press("jump")
		await w(1.0)
		check(p.leap_count > lc, "прыжок к ветке кедра")
		var on_pad := false
		for q in cedar.pads:
			if p.global_position.distance_to(q) < 1.6:
				on_pad = true
		check(on_pad and p.is_on_floor(), "герой стоит на ветке (%.1f м)" % p.global_position.y)
		# камера смотрит мимо веток — обычный двойной прыжок, без «магнита»
		p.global_position = Vector3(pad0.x, 0.0, pad0.z) + away * 6.0
		p.velocity = Vector3.ZERO
		p._set_state("move")
		await w(0.4)
		G.cam_rig.yaw = atan2(away.x, away.z) + PI
		p.press("jump")
		await w(0.2)
		var lc2: int = p.leap_count
		p.press("jump")
		await w(0.3)
		check(p.leap_count == lc2, "к ветке — только если смотришь на неё")
		p.global_position = Vector3(0, 0.5, 6)
		p.velocity = Vector3.ZERO
		await w(0.6)
	# титры мест не мелькают на бегу: место должно «устояться» 1,5 с
	var hud = G.hud
	hud.loc_t = 0.0
	hud.loc_seen.clear()
	hud.loc_name = ""
	var shown := 0
	for k in 12:
		p.global_position = Vector3(32, 0.5, -20) if k % 2 == 0 else Vector3(-34, 0.5, -16)
		await w(0.3)
		if hud.loc_t > 0.0:
			shown += 1
	check(shown == 0, "титры мест не спамят при быстром перемещении")
	p.global_position = Vector3(32, 0.5, -20)
	await w(2.2)
	check(hud.loc_name == "Деревня Ивакура", "титр места появляется, если задержаться")
	p.global_position = Vector3(0, 0.5, 6)
	await w(0.3)
	# мир: рельеф, пруд, кедры с ветками, время суток
	check(G.world.height_at(0, 0) == 0.0 and G.world.height_at(-34, -5) < 0.0 and G.world.height_at(0, -62) >= 3.0, "рельеф: поляна, пруд, холм святилища")
	check(G.world.cedar_pads.size() > 100, "кедры с ветками для прыжков (%d)" % G.world.cedar_pads.size())
	for tday in ["day", "sunset", "night"]:
		G.world.set_time(tday)
		await w(0.1)
	check(G.world.time_of_day == "night", "время суток: день, закат, ночь")
	# огненный тигр и стихия на хаори
	var tg0: int = G.fx.tigers.size()
	G.fx.flame_tiger(Vector3(0, 1.3, 0), Vector3.FORWARD, 9.0, 0.6)
	check(G.fx.tigers.size() == tg0 + 1, "огненный тигр появляется")
	p.set_breath(1)
	p.haori_element(1.0)
	await w(0.5)
	check(p.elem_k > 0.5, "стихия на хаори после формы (%.2f)" % p.elem_k)
	p.set_breath(0)
	check(G.music.ready_, "музыка и окружение готовы (%d мс)" % G.music.gen_ms)
	# ===== v0.46: серия в воздухе, кровь слабых демонов, клинок сам в ножны =====
	p._set_state("move")
	p.global_position = Vector3(0, 0.5, 12)
	p.set_sword(0)
	p.set_drawn(true)
	await w(0.3)
	p.press("jump")
	await w(0.12)
	var air_seq: Array = []
	for k in 3:
		p.press("light")
		await w(0.2)
		air_seq.append(p.atk_name)
	await w(0.8)
	check(air_seq.has("air2") or air_seq.has("air3"), "удары в прыжке идут серией, а не одним взмахом (%s)" % str(air_seq))
	var lowd = CharacterBody3D.new()
	lowd.set_script(load("res://scripts/demon.gd"))
	lowd.kind = "low"
	G.world.add_child(lowd)
	lowd.global_position = Vector3(40, 0.5, 40)
	lowd.noticed = true
	await w(0.1)
	lowd.hp = 20.0
	lowd.since_hit = 5.0
	await w(1.0)
	check(lowd.hp < 21.0, "низший демон без крови не лечится (%.0f)" % lowd.hp)
	lowd._feed(10.0)
	lowd.since_hit = 5.0
	await w(1.5)
	check(lowd.hp > 25.0, "выпив крови — лечится (%.0f)" % lowd.hp)
	lowd.queue_free()
	p.global_position = Vector3(60, 0.5, 60)
	for e in G.enemies:
		if is_instance_valid(e) and e != lowd:
			e.noticed = false
	p.set_drawn(true)
	p._set_state("move")
	await w(4.8)
	check(not p.drawn, "после боя клинок сам уходит в ножны")
	p.global_position = Vector3(0, 0.5, 4)
	check(SwordLib_len() > 1.0, "клинок длиннее (%.2f)" % SwordLib_len())
	# ===== Формы: все дыхания, столько форм, сколько в аниме =====
	var canon := {"water": 11, "flame": 9, "thunder": 7, "wind": 9, "stone": 5, "mist": 7, "flower": 7, "insect": 4,
		"serpent": 5, "love": 6, "sound": 5, "beast": 10, "dawn": 13, "moon": 16}
	var forms_ok := true
	var bad := ""
	for st_name in canon:
		if p.form_count(st_name) != canon[st_name] or G.BREATHS[st_name].forms.size() != canon[st_name]:
			forms_ok = false
			bad += "%s(%d) " % [st_name, p.form_count(st_name)]
	check(forms_ok and G.BREATH_ORDER.size() == 14, "14 дыханий, формы как в аниме %s" % bad)
	var dmo = G.enemies[0] if G.enemies.size() > 0 else null
	if dmo:
		dmo.global_position = p.global_position + Vector3(0, 0, -3)
		dmo.hp = 99999.0
		dmo.max_hp = 99999.0
	var ran := 0
	var total_forms := 0
	for bi in G.BREATH_ORDER.size():
		p.set_breath(bi)
		var st_n: String = G.breath_style
		for fk in p.FORMS[st_n]:
			total_forms += 1
			if fk == "stance":
				continue
			p.global_position = Vector3(0, 0.5, 4)
			p.velocity = Vector3.ZERO
			p._set_state("move")
			p._start_attack(fk)
			await w(minf(float(p.ATK[fk].dur) * 0.5 + 0.1, 0.9))
			ran += 1
	p._set_state("move")
	check(ran == total_forms - 1 and total_forms == 114, "все формы всех дыханий выполняются (%d из %d)" % [ran, total_forms])
	# кнопки: 0 — десятая форма, Ё — вторая страница (Луна: формы 11–16)
	p.set_breath(G.BREATH_ORDER.find("moon"))
	check(p.slot_key(10) == "moon_10", "клавиша 0 — десятая форма (%s)" % p.slot_key(10))
	p.toggle_form_page()
	check(p.slot_key(6) == "moon_16" and p.slot_key(7) == "", "Ё — вторая страница: 11–16 (%s)" % p.slot_key(6))
	p.toggle_form_page()
	# последняя форма — самая сильная: замедление, неуязвимость
	p.set_breath(0)
	p._set_state("move")
	p.breath = p.max_breath
	p.cd.clear()
	p.press("form10")
	await w(0.15)
	check(p.state == "attack" and p.atk.get("final", false) == false and p.atk_name == "water_10", "десятая форма Воды — с клавиши 0 (%s)" % p.atk_name)
	await w(2.0)
	p._set_state("move")
	p.set_breath(1)
	p.breath = p.max_breath
	p.cd.clear()
	p.press("form9")
	await w(0.15)
	check(p.atk.get("final", false) and p.invuln_t > 0.5, "последняя форма Пламени — финальная, с неуязвимостью")
	await w(2.0)
	p._set_state("move")
	p.set_breath(0)
	if dmo:
		dmo.max_hp = 240.0
		dmo.hp = 240.0
	# ===== СЮЖЕТ: пролог, глава, жители, прокачка, виды демонов =====
	var st = G.story
	st.fast = true
	st.new_game()
	await w(0.8)
	check(st.npcs.size() == 9 and st.npcs.has("gensai") and st.npcs.has("crow"), "жители, прохожие и ворон в деревне (%d)" % st.npcs.size())
	var jun_p0: Vector3 = st.npcs.jun.global_position
	await _skip_talk()
	check(st.phase == "tutorial", "пролог: обучение у наставника (%s)" % st.phase)
	var trm = G.world.train
	var TT: Vector3 = G.world.TRAIN
	check(G.world.in_train(p.global_position) and G.world.in_train(st.npcs.gensai.global_position), "обучение — на отдельной карте (гора Кирияма)")
	check(G.world.height_at(TT.x, 50.0) == 14.0 and G.world.height_at(TT.x, -38.0) == 0.0 and G.world.height_at(TT.x + trm.path_x(19.0), 19.0) < -5.0, "рельеф горы: вершина, поляна, расщелина")
	p.set_drawn(false)
	await w(0.1)
	p.set_drawn(true)
	await w(0.2)
	await _skip_talk()
	check(st.tut_step == 1 and trm.logs_on, "шаг 2: спуск по тропе, брёвна катятся")
	# бревно сбивает героя, стоящего на тропе
	var lz := 31.0
	st._place(TT + Vector3(trm.path_x(lz), 0, lz), PI)
	p.invuln_t = 0.0
	var hp_l: float = p.hp
	trm.log_t = 0.0
	var hit_l := false
	for i in 40:
		await w(0.1)
		if p.hp < hp_l:
			hit_l = true
			break
	check(hit_l, "бревно сбивает героя на тропе")
	# упал в расщелину — обратно на тропу
	st._place(TT + Vector3(trm.path_x(19.0), -6.0, 19.0), PI)
	await w(0.4)
	check(p.global_position.z - TT.z > 25.0 and p.global_position.y > 5.0, "из расщелины — обратно на тропу перед ней")
	st._place(TT + Vector3(0, 0, -14), PI)
	await w(0.4)
	await _skip_talk()
	check(st.tut_step == 2 and not trm.logs_on and p.breath < p.max_breath * 0.5, "шаг 3: дыхание у водопада (брёвна остановлены)")
	p.auto_breathe = true
	p.breath = p.max_breath * 0.96
	await w(1.0)
	p.auto_breathe = false
	await _skip_talk()
	check(st.tut_step == 3 and st.trial_dummies.size() == 4, "шаг 4: четыре чучела")
	for dmy in st.trial_dummies:
		if is_instance_valid(dmy):
			dmy.slash_hit(dmy.global_position - Vector3.FORWARD, Vector3.FORWARD, 2)
	await w(0.3)
	await _skip_talk()
	check(st.tut_step == 4, "чучела разрублены — шаг 5: форма")
	p._set_state("move")
	p.breath = 100.0
	p.press("form1")
	await w(0.4)
	await w(1.6)
	await _skip_talk()
	await w(0.3)
	check(st.phase == "fight" and st.alive.size() == 1 and trm.cage == null, "ночью из клетки выходит пойманный демон (%s)" % st.phase)
	await _kill_story_wave()
	await w(0.8)
	await _skip_talk()
	await w(0.6)
	check(st.phase == "tutorial" and st.tut_step == 6 and trm.boulder and not trm.boulder.split, "полгода спустя — валун (%s, шаг %d)" % [st.phase, st.tut_step])
	await _skip_talk()
	var bld = trm.boulder
	var bhp: int = bld.hp
	p._set_state("move")
	bld.slash_hit(p.global_position, Vector3.FORWARD, 1)
	check(bld.hp == bhp, "лёгкий удар валун не берёт")
	for i in 12:
		bld.slash_hit(p.global_position, Vector3.FORWARD, 2)
	check(bld.split, "тяжёлые удары разрубают валун надвое")
	await w(1.5)
	await _skip_talk()
	await w(0.8)
	await _skip_talk()
	await w(0.6)
	check(not G.world.in_train(p.global_position), "после обучения — в деревню (главная карта)")
	# ===== жители заняты делом и здороваются =====
	var okn = st.npcs.okiku
	var tkn = st.npcs.tetsu
	var trn = st.npcs.taro
	check(tkn.activity == "forge" and okn.activity == "sweep" and trn.activity == "play" and st.npcs.elder.activity == "pace", "жители заняты делом: кузнец, метла, игра, прогулка")
	var tr0: Vector3 = trn.global_position
	var at0: float = tkn.act_t
	await w(0.6)
	check(trn.global_position.distance_to(tr0) > 0.5 and tkn.act_t > at0, "Таро бегает, кузнец бьёт молотом")
	okn.greet_cd = 0.0
	st._place(okn.global_position + Vector3(2.0, 0, 0), -PI * 0.5)
	await w(0.3)
	check(okn.bubble.visible and okn.bow_t >= 0.0, "Окику кланяется и здоровается («%s»)" % okn.bubble.text)
	st.talk("elder")
	await _skip_talk()
	check(G.dialog_ui.buttons.size() == 4, "староста: разговор по темам (4 ответа)")
	G.dialog_ui._pick(1)
	await _skip_talk()
	check(not G.dialog, "тема «демоны» рассказана")
	st._place(trn.global_position + Vector3(3.0, 0, 0), -PI * 0.5)
	await w(0.2)
	trn.bubble_t = 0.0
	st._taro_pick(0)
	await _skip_talk()
	p.press("dash")
	await w(0.3)
	check(trn.bubble.visible and trn.bubble.text.find("!") >= 0 and st.taro_watch <= 0.0, "Таро смотрит рывок: «%s»" % trn.bubble.text)
	await w(0.4)
	check(st.chapter == 1 and st.phase == "day", "пролог пройден — день, глава 1 (%d, %s)" % [st.chapter, st.phase])
	check(st.crow.has_news and st.target != null, "ворон ждёт с заданием, метка на карте")
	st.talk("crow")
	await _skip_talk()
	check(G.dialog_ui.buttons.size() == 2, "в конце разговора — выбор")
	G.dialog_ui._pick(0)
	await w(0.3)
	check(st.phase == "go" and G.world.time_of_day == "night", "задание принято — ночь, идём к месту (%s, %s)" % [st.phase, G.world.time_of_day])
	p.global_position = st.target + Vector3.UP * 4.0
	await w(0.5)
	check(st.phase == "fight" and st.alive.size() == 2, "у места — волна демонов (%d)" % st.alive.size())
	for k in 3:
		if st.phase == "fight":
			await _kill_story_wave()
			await w(0.6)
	check(st.phase == "done" or st.phase == "day", "все волны Отбора пройдены (%s)" % st.phase)
	await w(0.5)
	await _skip_talk()
	await w(0.6)
	check(st.chapter == 2 and int(G.prog.ryo) >= 60 and st.rank_name() == "Десятая ступень", "награда и ранг (%d рё, %s)" % [int(G.prog.ryo), st.rank_name()])
	# прокачка у наставника и кузнеца
	G.prog.mastery = 5
	var st_hp0: float = p.max_hp
	st._train_pick(0)
	await _skip_talk()
	check(p.max_hp == st_hp0 + 20.0 and int(G.prog.hp) == 1, "тренировка: +20 здоровья")
	G.prog.ryo = 500
	st._tetsu_pick(0)
	await _skip_talk()
	check(int(G.prog.blade) == 1 and G.dmg_out_mult() > 1.05, "кузнец закалил клинок")
	# наставник учит формам
	G.prog.mastery = 20
	var lv0 := int((G.prog.formlv as Dictionary).get(G.breath_style, 3))
	st._forms_pick(0)
	await _skip_talk()
	if G.dialog_ui.buttons.size() > 0:
		G.dialog_ui._pick(G.dialog_ui.buttons.size() - 1)
	check(int((G.prog.formlv as Dictionary).get(G.breath_style, 3)) == lv0 + 1, "наставник учит новой форме")
	# разговоры со всеми жителями
	for id in ["elder", "okiku", "taro", "tetsu", "gensai"]:
		st.talk(id)
		check(G.dialog, "разговор: %s" % id)
		await _skip_talk()
		if G.dialog_ui.buttons.size() > 0:
			G.dialog_ui._pick(G.dialog_ui.buttons.size() - 1)
		await w(0.05)
	await shot("30_village_day")
	check(st.npcs.jun.global_position.distance_to(jun_p0) > 1.0, "прохожие гуляют по улице")
	st.talk("hana")
	check(G.dialog, "с прохожим можно поговорить")
	await _skip_talk()
	# онигири: подарок Окику, покупка у Ханы, H — лечит
	var oni0 := int(G.prog.onigiri)
	G.prog.gift = -1
	st.talk("okiku")
	await _skip_talk()
	check(int(G.prog.onigiri) == oni0 + 1, "Окику дарит онигири")
	G.prog.ryo = 100
	st._hana_pick(0)
	await _skip_talk()
	check(int(G.prog.onigiri) == oni0 + 2 and int(G.prog.ryo) == 80, "торговка продаёт онигири")
	p.hp = 30.0
	p.press("eat")
	await w(0.2)
	check(p.hp >= 69.0 and int(G.prog.onigiri) == oni0 + 1, "онигири лечит (+40)")
	# журнал и большая карта
	get_parent().menus.refresh_journal()
	check(get_parent().menus.journal.text.find("Отбор") >= 0, "журнал: главы сюжета")
	G.hud.big_map = true
	await w(0.1)
	G.hud.big_map = false
	# испытание наставника: чучела на время
	var m0 := int(G.prog.mastery)
	st._start_trial()
	await w(0.2)
	check(st.phase == "trial" and st.trial_dummies.size() == 6, "испытание: 6 чучел на поляне")
	for dmy in st.trial_dummies:
		if is_instance_valid(dmy):
			dmy.slash_hit(dmy.global_position - Vector3.FORWARD, Vector3.FORWARD, 1)
	await w(0.3)
	await _skip_talk()
	check(st.phase == "day" and int(G.prog.mastery) == m0 + 2, "испытание пройдено: +2 мастерства")
	# Метка охотника: ярость → V → сила и скорость, здоровье тает
	G.prog.chapter = 4
	p.fury = 0.0
	p.add_fury(200.0)
	check(p.fury >= 100.0, "шкала ярости копится")
	p.hp = p.max_hp
	p.press("mark")
	await w(0.3)
	check(p.mark_t > 0.0 and G.dmg_out_mult() > 1.3 and p.mark_face.visible, "Метка охотника: сила, узор на лице")
	await w(1.0)
	check(p.hp < p.max_hp, "Метка пьёт жизнь")
	p.mark_t = 0.01
	await w(0.2)
	check(not p.mark_face.visible, "Метка угасла")
	G.prog.chapter = 2
	# виды демонов
	st._clear_demons()
	await w(0.2)
	var kinds_ok := true
	for kd in ["low", "hermit", "brute", "weaver", "spider", "boss"]:
		var dm = CharacterBody3D.new()
		dm.set_script(load("res://scripts/demon.gd"))
		dm.kind = kd
		G.world.add_child(dm)
		dm.global_position = Vector3(randf_range(-6, 6), 0.5, randf_range(-8, -4))
		if dm.name_ru != dm.TYPES[kd].name or dm.max_hp != dm.TYPES[kd].hp:
			kinds_ok = false
	check(kinds_ok, "шесть видов демонов: низший, отшельник, громила, ткачиха, паучиха, Тень")
	p.webbed(1.0)
	check(p.web_t > 0.0, "паутина опутывает героя")
	p.global_position = Vector3(0, 0.5, 4)
	await w(1.5)
	await shot("31_demon_kinds")
	var boss = null
	for e in G.enemies:
		if is_instance_valid(e) and e.kind == "boss":
			boss = e
	boss.hp = 0.0
	boss._expose()
	boss.decapitate(Vector3.FORWARD)
	await w(0.1)
	check(not boss.is_dead() and boss.lives == 1, "у Тени шея срастается после добивания")
	check(boss.neck_t >= 0.0 and boss.tendrils.size() == 5 and boss.take_hit(50.0, Vector3.FORWARD, {"power": 1}).dmg == 0, "голова отлетает, кровавые нити тянут её назад (неуязвим)")
	for i in 40:
		if boss.neck_t < 0.0:
			break
		await w(0.1)
	check(boss.neck_t < 0.0 and boss.state != "locked" and boss.tendrils.is_empty(), "шея срослась — бой продолжается (%.2f, %s, %d)" % [boss.neck_t, boss.state, boss.tendrils.size()])
	check(G.world.blood == 1, "кровавая луна во 2-й фазе Тени")
	p.global_position = boss.global_position + Vector3(5, 0, 0)
	boss.pool_cd = 0.0
	await w(0.3)
	check(boss.pools.size() >= 1, "кровавые лужи под ногами героя")
	boss.hp = 0.0
	boss._expose()
	boss.decapitate(Vector3.FORWARD)
	for i in 40:
		if boss.neck_t < 0.0:
			break
		await w(0.1)
	await w(0.2)
	var shades: Array = []
	for e in G.enemies:
		if is_instance_valid(e) and e.kind == "shade" and not e.is_dead():
			shades.append(e)
	check(boss.lives == 0 and shades.size() == 3 and G.world.blood == 2, "3-я фаза: багровая луна и тени-двойники (жизни %d, теней %d, луна %d, %s, neck %.2f, ts %.2f, proc %s)" % [boss.lives, shades.size(), G.world.blood, boss.state, boss.neck_t, Engine.time_scale, boss.is_physics_processing()])
	if shades.size() > 0:
		shades[0].take_hit(30.0, Vector3.FORWARD, {"power": 1, "stagger": 0.2})
	check(shades.size() > 0 and shades[0].is_dead(), "тень рассыпается от удара")
	boss._summon(2)
	await w(0.1)
	var lows := 0
	for e in G.enemies:
		if is_instance_valid(e) and e.kind == "low":
			lows += 1
	check(lows >= 3, "Тень призывает низших")
	G.stat_add("arms", 10)
	G._check_ach()
	check(G.has_ach("arms") and G.has_ach("first"), "достижения открываются")
	st._clear_demons()
	# конец части первой: титры → часть вторая (глава 7, день)
	G.mode = "story"
	st.chapter = st.ARC1_END
	st.phase = "done"
	st.done_t = 0.0
	await w(0.3)
	await _skip_talk()
	await w(1.5)
	check(st.phase == "day" and st.chapter == st.ARC1_END + 1 and bool(G.prog.finished), "после Кагэцу — часть вторая (%s, гл. %d)" % [st.phase, st.chapter])
	st._clear_demons()
	var b2 = CharacterBody3D.new()
	b2.set_script(load("res://scripts/demon.gd"))
	b2.kind = "boss2"
	G.world.add_child(b2)
	b2.global_position = Vector3(4, 0.5, -6)
	await w(0.1)
	check(b2.lives == 2 and b2.max_hp > 800.0, "Сэйрэн, Вторая луна: две жизни шеи")
	p.global_position = b2.global_position + Vector3(4, 0, 0)
	b2._frost_ring()
	await w(0.6)
	check(b2.frost_spikes.size() > 10, "Сэйрэн: ледяное кольцо шипов")
	G.world.festival(true)
	check(G.world.fest != null and G.world.fest.visible, "праздник фонарей: гирлянды на улице")
	st._clear_demons()
	# финал части второй: слова наставника, титры, свободная охота
	st.chapter = st.CH.size() - 1
	st.phase = "done"
	st.done_t = 0.0
	await w(0.3)
	await _skip_talk()
	await w(1.5)
	check(st.phase == "free" and bool(G.prog.finished2), "финал части второй: титры и свободная охота (%s)" % st.phase)
	# охота на заказ у ворона (после сюжета)
	st.talk("crow")
	await _skip_talk()
	G.dialog_ui._pick(0)
	await w(0.3)
	check(st.phase == "go" and not st.cur.is_empty(), "заказ взят — идём к месту")
	p.global_position = st.target + Vector3.UP * 4.0
	await w(0.4)
	for k in 4:
		if st.phase == "fight":
			await _kill_story_wave()
			await w(0.5)
	await w(0.4)
	await _skip_talk()
	await w(0.6)
	check(st.phase == "free" and int(G.prog.hunts) == 1 and st.cur.is_empty(), "заказ выполнен — снова свободная охота (%s)" % st.phase)
	st.fast = false
	G.mode = "free"
	st.phase = "free"
	await w(0.3)
	print("\n=== АВТОТЕСТ ===")
	for l in log_lines:
		print(l)
	print("ИТОГ: %s" % ("всё в порядке" if fails.is_empty() else "ошибки: %d" % fails.size()))
	get_tree().quit(0 if fails.is_empty() else 1)

# Пролистать разговор до конца (или до выбора).
func _skip_talk() -> void:
	for i in 40:
		if not G.dialog or G.dialog_ui.buttons.size() > 0:
			return
		G.dialog_ui.shown = 9999.0
		G.dialog_ui.advance()
		await w(0.05)

# Добить всех демонов текущей волны сюжета.
func _kill_story_wave() -> void:
	var st = G.story
	for d in st.alive.duplicate():
		if is_instance_valid(d) and not d.is_dead():
			d.lives = 0
			d.hp = 0.0
			d._expose()
			d.decapitate(Vector3.FORWARD)
	await w(0.5)

func SwordLib_len() -> float:
	return load("res://scripts/sword_lib.gd").BLADE_LEN
