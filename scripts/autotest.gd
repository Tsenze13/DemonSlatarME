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
	for si in range(-1, 9):
		p.set_sword(si)
		p.set_drawn(true)
		await w(0.15)
		var bl: float = p.blade_base.global_position.distance_to(p.blade_tip.global_position)
		if p.sword_mode == "whip":
			bl = p.blade_base.global_position.distance_to(p.whip.tip())
			if bl < 0.8:
				ok_sw = false
				print("хлыст ", bl)
		elif bl < 0.6 or bl > 1.1:
			ok_sw = false
			print("меч ", si, " длина ", bl)
	check(ok_sw, "все виды оружия ставятся")
	for sa in SwordLibT.SAYA.size():
		p.set_look(sa, sa % SwordLibT.TINTS.size())
		await w(0.03)
	check(p.scabbard_node.get_child_count() > 0, "все виды ножен и цвета клинка ставятся")
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
	await w(1.5)
	check(p.state == "move", "герой поднялся")
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
	check(p.breath < 98.0, "бег тратит дыхание")
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
	for i in 4:
		p.press("light")
		await w(0.27 if i < 3 else 0.2)
		if i == 3:
			await shot("04_combo4")
	await w(0.5)
	check(p.hits_total > hits0, "удары комбо попадают (%d)" % (p.hits_total - hits0))
	check(d.wounds.size() > 0, "на демоне видны порезы (%d)" % d.wounds.size())
	# регенерация после паузы
	var hp_before: float = d.hp
	var dpos: Vector3 = d.global_position
	d.global_position = Vector3(70, 0.5, 70)
	d.state = "idle"
	d.hp = d.max_hp * 0.5
	hp_before = d.hp
	await w(4.0)
	check(d.hp > hp_before + 40.0, "демон регенерирует после паузы (+%.0f)" % (d.hp - hp_before))
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
	get_parent()._toggle_pause()
	await w(0.2)
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
	print("\n=== АВТОТЕСТ ===")
	for l in log_lines:
		print(l)
	print("ИТОГ: %s" % ("всё в порядке" if fails.is_empty() else "ошибки: %d" % fails.size()))
	get_tree().quit(0 if fails.is_empty() else 1)
