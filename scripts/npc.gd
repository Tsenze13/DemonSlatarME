extends StaticBody3D
# Житель деревни (или ворон-посыльный): блочная модель, дышит, поворачивает
# голову к герою, жестикулирует в разговоре. Над головой — «!», если есть новости.
# Разговор начинается клавишей E рядом (story.gd ищет ближайшего).

const Vox = preload("res://scripts/vox.gd")

var id := ""                  # ключ в story.gd (gensai, tetsu, elder, ...)
var title := ""               # имя над головой и в окне диалога
var look := {}                # внешность: skin, hair, robe, robe2, style, prop, scale
var talking := false
var has_news := false
var model: Node3D
var head: Node3D
var torso: Node3D
var arm_r: Node3D
var arm_l: Node3D
var mark: Node3D
var base_rot := 0.0
var t := 0.0
var head_yaw := 0.0
# ворон
var is_crow := false
var wing_l: Node3D
var wing_r: Node3D
var fly_to := Vector3.ZERO
var flying := false
var home := Vector3.ZERO
var legs: Array = []
var path: Array = []           # маршрут прогулки (мировые точки); пусто — стоит на месте
var path_i := 0
var wait_t := 0.0
var walk_phase := 0.0
var lines: Array = []          # реплики прохожего
var walk_speed := 1.3
# Занятие, когда никто не говорит: forge (кузнец бьёт молотом по наковальне), sweep (метёт улицу),
# play (ребёнок бегает кругами), pace (ходит с тростью), meditate (наставник: руки на рукояти, глаза закрыты).
var activity := ""
var act_t := 0.0
var strike_done := false
var anvil := Vector3.ZERO
var greets: Array = []         # приветствия при встрече
var greet_cd := 0.0
var bow_t := -1.0              # поклон / взмах рукой
var hop_t := -1.0
var bubble: Label3D
var bubble_t := 0.0
var run_a := 0.0
var prop_node: Node3D = null

func setup(id_: String, title_: String, look_: Dictionary, pos: Vector3, rot := 0.0) -> void:
	id = id_
	title = title_
	look = look_
	is_crow = look.get("style", "") == "crow"
	position = pos
	home = pos
	base_rot = rot
	rotation.y = rot
	collision_layer = 1
	collision_mask = 0
	add_to_group("npc")
	if not is_crow:
		var cs := CollisionShape3D.new()
		var cap := CapsuleShape3D.new()
		cap.radius = 0.35
		cap.height = 1.7 * float(look.get("scale", 1.0))
		cs.shape = cap
		cs.position = Vector3(0, cap.height * 0.5, 0)
		add_child(cs)
	model = Node3D.new()
	add_child(model)
	if is_crow:
		_build_crow()
	else:
		_build_person()
	_build_mark()
	bubble = Label3D.new()
	bubble.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	bubble.no_depth_test = false
	bubble.font_size = 40
	bubble.pixel_size = 0.006
	bubble.outline_size = 12
	bubble.outline_modulate = Color(0.05, 0.04, 0.06, 0.9)
	bubble.modulate = Color(1, 0.97, 0.88)
	bubble.position = Vector3(0, (2.05 * float(look.get("scale", 1.0))) if not is_crow else 2.6, 0)
	bubble.visible = false
	add_child(bubble)

# Реплика над головой (на пару секунд).
func say_bubble(txt: String, t := 2.6) -> void:
	bubble.text = txt
	bubble.visible = true
	bubble_t = t

func hop() -> void:
	hop_t = 0.0

func _build_person() -> void:
	var sc: float = look.get("scale", 1.0)
	model.scale = Vector3.ONE * sc
	var skin: Color = look.get("skin", Color(0.95, 0.78, 0.64))
	var hair: Color = look.get("hair", Color(0.12, 0.1, 0.1))
	var robe: Color = look.get("robe", Color(0.35, 0.4, 0.5))
	var robe2: Color = look.get("robe2", robe.darkened(0.3))
	var st: String = look.get("style", "short")
	# ноги в хакама, сандалии (на шарнирах — чтобы ходить)
	for sx in [-1.0, 1.0]:
		var lg := Vox.pivot(model, Vector3(0.12 * sx, 0.66, 0))
		Vox.box(lg, Vector3(0.2, 0.62, 0.24), Vector3(0, -0.31, 0), robe2, true, 0.0, "cloth")
		Vox.box(lg, Vector3(0.18, 0.06, 0.28), Vector3(0, -0.63, 0.03), Color(0.55, 0.42, 0.28))
		legs.append(lg)
	torso = Vox.pivot(model, Vector3(0, 0.66, 0), "torso")
	Vox.box(torso, Vector3(0.48, 0.6, 0.3), Vector3(0, 0.3, 0), robe, true, 0.0, "cloth")
	# запахнутый ворот и пояс-оби
	Vox.box(torso, Vector3(0.08, 0.32, 0.02), Vector3(-0.04, 0.42, 0.155), robe.lightened(0.35), false)
	Vox.box(torso, Vector3(0.5, 0.12, 0.32), Vector3(0, 0.12, 0), look.get("obi", Color(0.3, 0.12, 0.1)))
	if look.get("prop", "") == "apron":
		Vox.box(torso, Vector3(0.4, 0.66, 0.02), Vector3(0, 0.06, 0.165), Color(0.36, 0.26, 0.18), true, 0.0, "cloth")
	for side in ["r", "l"]:
		var sx := -1.0 if side == "r" else 1.0
		var arm := Vox.pivot(torso, Vector3(0.31 * sx, 0.52, 0))
		# широкий рукав кимоно и кисть
		Vox.box(arm, Vector3(0.2, 0.44, 0.28), Vector3(0, -0.2, 0), robe, true, 0.0, "cloth")
		Vox.box(arm, Vector3(0.11, 0.11, 0.11), Vector3(0, -0.47, 0.02), skin)
		if side == "r":
			arm_r = arm
		else:
			arm_l = arm
	arm_r.rotation_degrees.z = -6
	arm_l.rotation_degrees.z = 6
	head = Vox.pivot(torso, Vector3(0, 0.62, 0), "head")
	Vox.box(head, Vector3(0.1, 0.08, 0.1), Vector3(0, 0.0, 0), skin.darkened(0.1))
	Vox.box(head, Vector3(0.32, 0.32, 0.3), Vector3(0, 0.2, 0), skin)
	# лицо пикселями: глаза с бликом, брови, рот, румянец
	var eye: Color = look.get("eye", Color(0.15, 0.1, 0.08))
	for sx in [-1.0, 1.0]:
		Vox.box(head, Vector3(0.05, 0.06, 0.01), Vector3(0.07 * sx, 0.21, 0.152), eye, false)
		Vox.box(head, Vector3(0.018, 0.018, 0.01), Vector3(0.07 * sx + 0.012, 0.228, 0.156), Color.WHITE, false, 0.6)
		var bw := Vox.box(head, Vector3(0.07, 0.016, 0.01), Vector3(0.07 * sx, 0.265, 0.153), hair.darkened(0.1) if st != "bald" else Color(0.85, 0.85, 0.85), false)
		bw.rotation_degrees.z = (8.0 if look.get("stern", false) else -4.0) * sx
		Vox.box(head, Vector3(0.04, 0.02, 0.008), Vector3(0.1 * sx, 0.165, 0.152), skin.lerp(Color(0.95, 0.45, 0.45), 0.35), false)
	Vox.box(head, Vector3(0.08, 0.018, 0.01), Vector3(0, 0.12, 0.152), Color(0.45, 0.2, 0.18), false)
	match st:
		"short":
			Vox.box(head, Vector3(0.34, 0.1, 0.32), Vector3(0, 0.38, -0.01), hair, true, 0.0, "hair")
			Vox.box(head, Vector3(0.34, 0.22, 0.08), Vector3(0, 0.28, -0.14), hair, true, 0.0, "hair")
			Vox.box(head, Vector3(0.3, 0.06, 0.04), Vector3(0, 0.33, 0.14), hair, false)
		"bun":
			Vox.box(head, Vector3(0.34, 0.12, 0.33), Vector3(0, 0.38, -0.01), hair, true, 0.0, "hair")
			Vox.box(head, Vector3(0.34, 0.3, 0.08), Vector3(0, 0.24, -0.14), hair, true, 0.0, "hair")
			Vox.box(head, Vector3(0.16, 0.16, 0.16), Vector3(0, 0.46, -0.1), hair, true, 0.0, "hair")
			Vox.box(head, Vector3(0.02, 0.02, 0.24), Vector3(0.06, 0.48, -0.1), Color(0.85, 0.2, 0.25), false, 0.4)
		"bald":
			Vox.box(head, Vector3(0.34, 0.1, 0.1), Vector3(0, 0.22, -0.12), Color(0.85, 0.85, 0.85))
			# длинная белая борода
			Vox.box(head, Vector3(0.2, 0.18, 0.06), Vector3(0, 0.04, 0.15), Color(0.92, 0.92, 0.9))
		"white":
			# наставник: белые волосы в хвост, борода, соломенная шляпа-каса за спиной
			Vox.box(head, Vector3(0.34, 0.1, 0.32), Vector3(0, 0.38, -0.01), Color(0.92, 0.92, 0.94), true, 0.0, "hair")
			Vox.box(head, Vector3(0.34, 0.24, 0.08), Vector3(0, 0.27, -0.14), Color(0.92, 0.92, 0.94), true, 0.0, "hair")
			Vox.box(head, Vector3(0.1, 0.3, 0.1), Vector3(0, 0.12, -0.2), Color(0.9, 0.9, 0.92))
			Vox.box(head, Vector3(0.24, 0.14, 0.06), Vector3(0, 0.05, 0.16), Color(0.94, 0.94, 0.94))
			var kasa := Vox.box(torso, Vector3(0.62, 0.08, 0.62), Vector3(0, 0.55, -0.24), Color(0.78, 0.66, 0.4), true, 0.0, "wood")
			kasa.rotation_degrees.x = 70
			# шрам через глаз
			Vox.box(head, Vector3(0.012, 0.12, 0.01), Vector3(0.07, 0.22, 0.157), Color(0.6, 0.3, 0.3), false)
		"band":
			# кузнец: повязка-хатимаки на лбу
			Vox.box(head, Vector3(0.34, 0.08, 0.32), Vector3(0, 0.38, -0.01), hair, true, 0.0, "hair")
			Vox.box(head, Vector3(0.35, 0.05, 0.33), Vector3(0, 0.31, 0), Color(0.95, 0.95, 0.92))
			Vox.box(head, Vector3(0.04, 0.12, 0.04), Vector3(0.06, 0.3, -0.18), Color(0.95, 0.95, 0.92))
			Vox.box(head, Vector3(0.2, 0.06, 0.05), Vector3(0, 0.08, 0.15), hair, false)   # усы
		"kid":
			Vox.box(head, Vector3(0.34, 0.12, 0.32), Vector3(0, 0.38, -0.01), hair, true, 0.0, "hair")
			Vox.box(head, Vector3(0.34, 0.18, 0.08), Vector3(0, 0.3, -0.14), hair, true, 0.0, "hair")
			Vox.box(head, Vector3(0.1, 0.1, 0.1), Vector3(0.12, 0.44, -0.04), hair, false)
	match look.get("prop", ""):
		"hammer":
			var h := Vox.pivot(arm_r, Vector3(0, -0.47, 0.06))
			Vox.box(h, Vector3(0.05, 0.05, 0.42), Vector3(0, 0, 0.16), Color(0.5, 0.35, 0.2))
			Vox.box(h, Vector3(0.12, 0.12, 0.2), Vector3(0, 0, 0.38), Color(0.3, 0.3, 0.34))
		"cane":
			var c := Vox.pivot(arm_r, Vector3(0, -0.47, 0.06))
			Vox.box(c, Vector3(0.05, 1.0, 0.05), Vector3(0, -0.34, 0.06), Color(0.45, 0.3, 0.18))
		"sword":
			# наставник носит старый клинок у пояса
			var sw := Vox.box(torso, Vector3(0.05, 0.05, 0.9), Vector3(0.28, 0.12, -0.05), Color(0.12, 0.1, 0.12))
			sw.rotation_degrees.x = -20
		"basket":
			Vox.box(arm_l, Vector3(0.3, 0.2, 0.26), Vector3(0.05, -0.55, 0.12), Color(0.72, 0.58, 0.32), true, 0.0, "wood")
	# имя над головой не рисуем — оно в окне диалога и в подсказке

func _build_crow() -> void:
	# ворон-посыльный: чёрный, с жёлтым клювом и белой лентой-посланием на лапе
	var blk := Color(0.08, 0.08, 0.12)
	Vox.box(model, Vector3(0.22, 0.2, 0.36), Vector3(0, 0.22, 0), blk)
	head = Vox.pivot(model, Vector3(0, 0.36, 0.14))
	Vox.box(head, Vector3(0.16, 0.15, 0.16), Vector3(0, 0, 0), blk)
	Vox.box(head, Vector3(0.05, 0.05, 0.12), Vector3(0, -0.01, 0.13), Color(0.95, 0.75, 0.2))
	for sx in [-1.0, 1.0]:
		Vox.box(head, Vector3(0.012, 0.035, 0.035), Vector3(0.082 * sx, 0.025, 0.04), Color(1.0, 0.85, 0.3), false, 1.0)
	Vox.box(model, Vector3(0.16, 0.05, 0.22), Vector3(0, 0.22, -0.26), blk)
	Vox.box(model, Vector3(0.03, 0.12, 0.03), Vector3(0.05, 0.06, 0.02), Color(0.3, 0.3, 0.3))
	Vox.box(model, Vector3(0.03, 0.12, 0.03), Vector3(-0.05, 0.06, 0.02), Color(0.3, 0.3, 0.3))
	Vox.box(model, Vector3(0.05, 0.05, 0.08), Vector3(0.05, 0.09, 0.02), Color(0.95, 0.95, 0.9), false)
	wing_l = Vox.pivot(model, Vector3(0.11, 0.28, 0))
	Vox.box(wing_l, Vector3(0.4, 0.03, 0.26), Vector3(0.2, 0, -0.02), blk)
	wing_r = Vox.pivot(model, Vector3(-0.11, 0.28, 0))
	Vox.box(wing_r, Vector3(0.4, 0.03, 0.26), Vector3(-0.2, 0, -0.02), blk)
	model.scale = Vector3.ONE * 1.8
	model.position.y = 1.25
	# насест: столб с перекладиной и табличкой «задания»
	var post := Vox.box(self, Vector3(0.18, 1.25, 0.18), Vector3(0, 0.62, 0), Color(0.42, 0.3, 0.2), true, 0.0, "wood")
	post.name = "post"
	Vox.box(self, Vector3(0.7, 0.1, 0.14), Vector3(0, 1.2, 0), Color(0.48, 0.34, 0.22), true, 0.0, "wood")
	Vox.box(self, Vector3(0.46, 0.34, 0.04), Vector3(0, 0.75, 0.11), Color(0.92, 0.86, 0.72), true, 0.0, "paper")
	Vox.box(self, Vector3(0.05, 0.22, 0.01), Vector3(0, 0.75, 0.135), Color(0.15, 0.1, 0.1), false)
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(0.3, 1.3, 0.3)
	cs.shape = bs
	cs.position = Vector3(0, 0.65, 0)
	add_child(cs)

func _build_mark() -> void:
	mark = Node3D.new()
	add_child(mark)
	var y := 2.3 * float(look.get("scale", 1.0)) if not is_crow else 2.4
	mark.position = Vector3(0, y, 0)
	Vox.box(mark, Vector3(0.1, 0.32, 0.1), Vector3(0, 0.12, 0), Color(1.0, 0.85, 0.25), true, 1.6)
	Vox.box(mark, Vector3(0.1, 0.1, 0.1), Vector3(0, -0.16, 0), Color(1.0, 0.85, 0.25), true, 1.6)
	mark.visible = false

func talk_pos() -> Vector3:
	return global_position + Vector3.UP * (1.6 * float(look.get("scale", 1.0)) if not is_crow else 1.8)

func _process(dt: float) -> void:
	t += dt
	mark.visible = has_news and not talking
	if mark.visible:
		mark.position.y = (2.3 * float(look.get("scale", 1.0)) if not is_crow else 2.4) + sin(t * 3.0) * 0.08
		mark.rotation.y = t * 2.0
	var p: Node3D = G.player
	if is_crow:
		_crow_tick(dt, p)
		return
	# прогулка по маршруту (останавливается поговорить)
	var walking := false
	if not path.is_empty() and not talking:
		if wait_t > 0.0:
			wait_t -= dt
		else:
			var tp: Vector3 = path[path_i]
			var to3 := Vector3(tp.x - global_position.x, 0, tp.z - global_position.z)
			if to3.length() < 0.3:
				path_i = (path_i + 1) % path.size()
				wait_t = randf_range(1.0, 4.0)
			else:
				walking = true
				var step := minf(to3.length(), walk_speed * dt)
				global_position += to3.normalized() * step
				if G.world and G.world.has_method("height_at"):
					global_position.y = G.world.height_at(global_position.x, global_position.z)
				base_rot = atan2(to3.x, to3.z)
				rotation.y = lerp_angle(rotation.y, base_rot, 1.0 - exp(-6.0 * dt))
	if activity == "play" and not talking and bow_t < 0.0:
		walking = _run_circle(dt)
	if walking:
		walk_phase += dt * (12.0 if activity == "play" else 7.0)
	else:
		walk_phase = lerpf(walk_phase, round(walk_phase / PI) * PI, 1.0 - exp(-8.0 * dt))
	var sw := sin(walk_phase) * (28.0 if walking else 0.0)
	for i in legs.size():
		legs[i].rotation_degrees.x = sw * (1.0 if i == 0 else -1.0)
	# дыхание
	torso.position.y = 0.66 + sin(t * 2.0) * 0.008 + absf(cos(walk_phase)) * (0.025 if walking else 0.0)
	torso.rotation_degrees.x = sin(t * 2.0) * 1.2
	torso.rotation_degrees.y = 0.0
	# смотрит на героя, если рядом
	var want := 0.0
	var d := 99.0
	if p:
		var to := p.global_position - global_position
		d = Vector2(to.x, to.z).length()
		if d < 7.0:
			want = wrapf(atan2(to.x, to.z) - rotation.y, -PI, PI)
	# в разговоре — разворачивается всем телом
	if talking and p:
		var to2 := p.global_position - global_position
		rotation.y = lerp_angle(rotation.y, atan2(to2.x, to2.z), 1.0 - exp(-5.0 * dt))
	elif d > 9.0 and not walking:
		rotation.y = lerp_angle(rotation.y, base_rot, 1.0 - exp(-1.5 * dt))
	head_yaw = lerpf(head_yaw, clampf(want, -1.1, 1.1), 1.0 - exp(-4.0 * dt))
	head.rotation.y = head_yaw
	# жесты в разговоре
	var g := sin(t * 5.0) * 0.5 + 0.5 if talking else 0.0
	var aw := -sw * 0.7
	arm_r.rotation_degrees.x = lerpf(arm_r.rotation_degrees.x, -35.0 * g - (10.0 if talking else 0.0) + aw, 1.0 - exp(-6.0 * dt))
	arm_l.rotation_degrees.x = lerpf(arm_l.rotation_degrees.x, -12.0 * (1.0 - g) * (1.0 if talking else 0.0) - aw, 1.0 - exp(-6.0 * dt))
	head.rotation_degrees.x = sin(t * 7.0) * 3.0 if talking else 0.0
	_greet_tick(dt, p, d)
	if not talking and bow_t < 0.0:
		_activity_tick(dt, p, d)
	_bow_pose()
	if hop_t >= 0.0:
		hop_t += dt
		model.position.y = maxf(0.0, sin(hop_t * PI / 0.45) * 0.45) if hop_t < 0.45 else 0.0
		if hop_t >= 0.45:
			hop_t = -1.0
	if bubble_t > 0.0:
		bubble_t -= dt
		bubble.visible = bubble_t > 0.0
		bubble.modulate.a = clampf(bubble_t * 3.0, 0.0, 1.0)

# Подошёл герой — житель отрывается от дела, кланяется (ребёнок машет) и здоровается.
func _greet_tick(dt: float, p: Node3D, d: float) -> void:
	greet_cd -= dt
	if p == null or greets.is_empty() or talking or G.dialog:
		return
	if d < 4.2 and greet_cd <= 0.0 and G.story and G.story.phase in ["day", "free"]:
		greet_cd = 50.0
		bow_t = 0.0
		say_bubble(greets[randi() % greets.size()], 3.0)
	if bow_t >= 0.0:
		bow_t += dt
		var to := p.global_position - global_position
		rotation.y = lerp_angle(rotation.y, atan2(to.x, to.z), 1.0 - exp(-8.0 * dt))
		if bow_t > 1.3:
			bow_t = -1.0

func _bow_pose() -> void:
	if bow_t < 0.0:
		return
	var k := sin(clampf(bow_t / 1.3, 0.0, 1.0) * PI)
	if activity == "play":
		# ребёнок машет рукой над головой
		arm_r.rotation_degrees.x = -160.0 * k
		arm_r.rotation_degrees.z = -20.0 + sin(bow_t * 18.0) * 25.0 * k
	else:
		torso.rotation_degrees.x = 32.0 * k
		head.rotation_degrees.x = 12.0 * k
		arm_r.rotation_degrees.x = 0.0
		arm_l.rotation_degrees.x = 0.0

func _activity_tick(dt: float, p: Node3D, d: float) -> void:
	act_t += dt
	match activity:
		"forge":
			# цикл 1,1 с: медленный замах — резкий удар — искры и звон
			var c := fmod(act_t, 1.1)
			var up := clampf(c / 0.75, 0.0, 1.0)
			var ang := -40.0 - 120.0 * Vox.ease_in_out(up)
			if c > 0.75:
				ang = lerpf(-160.0, -35.0, clampf((c - 0.75) / 0.08, 0.0, 1.0))
			arm_r.rotation_degrees.x = ang
			arm_r.rotation_degrees.z = -6.0
			arm_l.rotation_degrees.x = -45.0        # клещами держит заготовку
			torso.rotation_degrees.x = 12.0 + (6.0 if c > 0.78 and c < 0.95 else 0.0)
			head.rotation_degrees.x = 18.0
			if c > 0.83 and not strike_done:
				strike_done = true
				G.fx.sparks(anvil + Vector3.UP * 0.05, Vector3.UP, Color(1.0, 0.75, 0.3), 9)
				if d < 18.0 and G.sfx:
					G.sfx.play("clang", -14.0 - d * 0.6, randf_range(1.3, 1.5))
			elif c < 0.5:
				strike_done = false
		"sweep":
			# метёт: руки вперёд, метла ходит из стороны в сторону, пыль
			var sw := sin(act_t * 3.2)
			arm_r.rotation_degrees.x = -38.0
			arm_l.rotation_degrees.x = -50.0
			arm_r.rotation_degrees.z = -6.0 + sw * 14.0
			arm_l.rotation_degrees.z = 20.0 + sw * 14.0
			if prop_node:
				prop_node.rotation_degrees.y = sw * 25.0
			torso.rotation_degrees.x = 14.0
			torso.rotation_degrees.y = sw * 10.0
			if fmod(act_t, 1.96) < dt and d < 20.0:
				var bp := global_position + global_transform.basis.z * 1.0
				G.fx.dust(bp, 3)
		"play":
			arm_r.rotation_degrees.x = -sin(walk_phase) * 50.0
			arm_l.rotation_degrees.x = sin(walk_phase) * 50.0
			torso.rotation_degrees.x = 10.0
			if fmod(act_t, 4.3) < dt:
				hop()
		"pace":
			arm_l.rotation_degrees.x = -10.0
			torso.rotation_degrees.x = 8.0           # сутулится, руки за спиной
		"meditate":
			arm_r.rotation_degrees.x = -30.0
			arm_l.rotation_degrees.x = -30.0
			arm_r.rotation_degrees.z = 25.0
			arm_l.rotation_degrees.z = -25.0
			torso.rotation_degrees.x = sin(act_t * 0.9) * 2.0

# Ребёнок бегает кругами вокруг своего места (останавливается поговорить).
func _run_circle(dt: float) -> bool:
	run_a += dt * 1.15
	var tgt := home + Vector3(cos(run_a) * 2.6, 0, sin(run_a) * 2.6)
	var to := Vector3(tgt.x - global_position.x, 0, tgt.z - global_position.z)
	if to.length() > 0.05:
		global_position += to.normalized() * minf(to.length(), 3.4 * dt)
		if G.world and G.world.has_method("height_at"):
			global_position.y = G.world.height_at(global_position.x, global_position.z)
		rotation.y = lerp_angle(rotation.y, atan2(to.x, to.z), 1.0 - exp(-10.0 * dt))
	return true

func _crow_tick(dt: float, p: Node3D) -> void:
	var flap := 0.0
	if flying:
		var cur: Vector3 = model.global_position
		var to := fly_to - cur
		var dist := to.length()
		if dist < 0.2:
			flying = false
			model.global_position = fly_to
		else:
			model.global_position = cur + to / dist * minf(dist, 9.0 * dt)
			model.rotation.y = lerp_angle(model.rotation.y, atan2(to.x, to.z) - rotation.y, 1.0 - exp(-8.0 * dt))
			flap = sin(t * 22.0)
	elif p:
		var to2 := p.global_position - global_position
		if to2.length() < 6.0:
			rotation.y = lerp_angle(rotation.y, atan2(to2.x, to2.z), 1.0 - exp(-3.0 * dt))
		# переступает, поклёвывает
		head.rotation_degrees.x = 25.0 if fmod(t, 3.0) < 0.2 else 0.0
	var wa := flap * 50.0 if flying else (sin(t * 18.0) * 30.0 if talking else 0.0)
	wing_l.rotation_degrees.z = wa
	wing_r.rotation_degrees.z = -wa

func fly(to: Vector3) -> void:
	fly_to = to
	flying = true

# Ворон возвращается на насест.
func perch() -> void:
	fly(global_position + Vector3.UP * 1.25)
