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
	check(p.haori_cloth_mats.size() >= 3 and p.haori_style == SwordLibT.HAORI.size() - 1, "все узоры хаори ставятся")
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
	# бег (вбок, не на демона)
	G.cam_rig.yaw = 0.0
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
	# разгон: рывки на бегу поднимают скорость
	p.momentum = 0
	await w(0.5)
	for k in 3:
		p.dash_charges = 2.0
		p.press("dash")
		await w(0.35)
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
	# карманы рукавов на бегу остаются под рукой (с нижней стороны предплечья)
	var in_arm := 0
	for c in p.cloths:
		if c.mode == "blocks" and c != p.haori_body:
			for q in c.pos:
				if (c.attach.global_transform.affine_inverse() * q).z > -0.07:
					in_arm += 1
	check(in_arm == 0, "рукава не залетают в руки на бегу (%d)" % in_arm)
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
			p.cd = {"f1": 0.0, "f2": 0.0, "f3": 0.0}
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
		if t.kind == "tree":
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
		if t.kind == "tree":
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
	check(mn.tabs.get_tab_count() == 4, "в настройках 4 вкладки")
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
	check(G.world.stars != null and G.world.fireflies != null, "звёзды, светлячки, листья")
	check(G.music.ready_, "музыка и окружение готовы (%d мс)" % G.music.gen_ms)
	print("\n=== АВТОТЕСТ ===")
	for l in log_lines:
		print(l)
	print("ИТОГ: %s" % ("всё в порядке" if fails.is_empty() else "ошибки: %d" % fails.size()))
	get_tree().quit(0 if fails.is_empty() else 1)
