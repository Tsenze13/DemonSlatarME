extends Node3D
# Учебная гора Кирияма — отдельная карта обучения (далеко от деревни, её не видно).
# Вершина с хижиной наставника → тропа вниз с ловушками (катящиеся брёвна, расщелина) →
# поляна внизу: водопад (дыхание), чучела, клетка с пойманным демоном, огромный валун
# с верёвкой симэнава — его надо разрубить в конце обучения.
# Координаты здесь локальные (lx, lz); в мире карта сдвинута на world.TRAIN.

const Vox = preload("res://scripts/vox.gd")
const Cedar = preload("res://scripts/cedar.gd")

var w: Node3D                          # мир (world.gd)
const SUMMIT_H := 14.0
const CLEAR_C := Vector2(0, -38)       # центр поляны
const CLEAR_R := 33.0
const POOL := Vector2(-25, -40)         # заводь под водопадом
const POOL_R := 5.0
const GAP := Vector2(16.0, 22.0)        # расщелина поперёк тропы (lz от, до)
const BOULDER := Vector3(0, 0, -62)
const DUMMIES := [Vector3(13, 0, -24), Vector3(18, 0, -29), Vector3(12, 0, -33), Vector3(19, 0, -37)]
const CAGE := Vector3(-8, 0, -50)
const START := Vector3(0, 0, 50)        # где герой просыпается (вершина)
const CHECKPOINT := Vector3(0, 0, 28)   # перед расщелиной

var logs: Array = []                   # катящиеся брёвна [узел, z, скорость, задет]
var logs_on := false
var log_t := 0.0
var boulder = null
var cage: Node3D = null

# Центр тропы по x — тропа петляет.
static func path_x(z: float) -> float:
	return sin(z * 0.09) * 5.0

static func path_h(z: float) -> float:
	return clampf(floor((z + 6.0) / 3.3), 0.0, SUMMIT_H - 1.0)

# Высота рельефа (локальные координаты). Ровные площадки + стены-уступы вокруг.
func h(x: float, z: float) -> float:
	var n: float = w.noise.get_noise_2d(x * 1.7 + 300.0, z * 1.7) if w else 0.0
	# расстояния до трёх площадок: вершина (прямоугольник), тропа (коридор), поляна (круг)
	var ds := maxf(absf(x) - 13.0, maxf(38.0 - z, z - 60.0))
	var dp := 99.0
	if z > -10.0 and z < 42.0:
		dp = absf(x - path_x(z)) - 3.5
	var r := Vector2(x, z).distance_to(CLEAR_C)
	var dc := r - (CLEAR_R + n * 4.0)
	var best := 99.0
	for f in [[ds, SUMMIT_H], [dp, path_h(z)], [dc, 0.0]]:
		var d: float = f[0]
		var base: float = f[1]
		var v: float = base if d <= 0.0 else base + 2.0 + floor(d * 0.85 + n * 1.5)
		best = minf(best, v)
	# расщелина: провал поперёк тропы
	if dp <= 0.0 and z >= GAP.x and z < GAP.y:
		return -8.0
	# заводь под водопадом и скала, с которой он падает
	if Vector2(x, z).distance_to(POOL) < POOL_R:
		return -1.0
	if x < POOL.x - 4.0 and absf(z - POOL.y) < 4.0:
		return 16.0
	return clampf(best, -8.0, 34.0)

# Материал верха клетки: 0 трава, 0.5 земля, 1 камень.
func mat(x: float, z: float, hh: float) -> float:
	if hh < 0.0:
		return 1.0
	if z > -10.0 and z < 42.0 and absf(x - path_x(z)) < 2.2:
		return 0.5
	var floor_h := SUMMIT_H if (z >= 38.0 and absf(x) <= 13.0) else (path_h(z) if (z > -10.0 and z < 42.0 and absf(x - path_x(z)) <= 3.5) else 0.0)
	if hh > floor_h + 2.5:
		return 1.0                       # стены и скалы
	if z >= 38.0 and absf(x) < 5.0 and z < 50.0:
		return 0.5                       # двор хижины
	if Vector2(x, z).distance_to(Vector2(BOULDER.x, BOULDER.z)) < 7.0:
		return 0.5
	return 0.0

# Горы вокруг (без коллизии) — высокие пики со снегом, чтобы было видно: мы в горах.
func mountain_h(x: float, z: float) -> float:
	var r := Vector2(x, z - 5.0).length()
	if r < 92.0:
		return -50.0
	var e := clampf((r - 92.0) / 60.0, 0.0, 1.0)
	var n: float = w.noise2.get_noise_2d(x * 0.7 + 500.0, z * 0.7) * 0.5 + 0.5
	var n2: float = w.noise.get_noise_2d(x * 0.3 + 500.0, z * 0.3) * 0.5 + 0.5
	return floor((28.0 + e * (30.0 + n * 55.0) * (0.5 + n2)) / 3.0) * 3.0

func mountain_h_w(x: float, z: float) -> float:
	return mountain_h(x - w.TRAIN.x, z - w.TRAIN.z)

func wp(x: float, z: float, up := 0.0) -> Vector3:
	return Vector3(x, h(x, z) + up, z)

func build() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 41
	_hut()
	_path_props(rng)
	_waterfall()
	_clearing(rng)
	_boulder()
	_cage()
	_trees(rng)

# --- вершина: хижина наставника --------------------------------------------
func _hut() -> void:
	var c := Vector3(6, SUMMIT_H, 53)
	var hut := Node3D.new()
	hut.position = c
	add_child(hut)
	var wood := Color(0.48, 0.33, 0.2)
	Vox.solid(hut, Vector3(8, 0.45, 6), Vector3(0, 0.22, 0), Color(0.4, 0.29, 0.19), true, 1, "wood")
	for sx in [-1, 1]:
		for sz in [-1, 1]:
			Vox.solid(hut, Vector3(0.32, 3.0, 0.32), Vector3(sx * 3.6, 1.95, sz * 2.6), wood, true, 1, "bark")
	# стены: доски и бумажные сёдзи спереди
	Vox.solid(hut, Vector3(7.2, 3.0, 0.2), Vector3(0, 1.95, 2.6), wood.darkened(0.1), true, 1, "wood")
	Vox.solid(hut, Vector3(0.2, 3.0, 5.2), Vector3(-3.6, 1.95, 0), wood.darkened(0.1), true, 1, "wood")
	Vox.solid(hut, Vector3(0.2, 3.0, 5.2), Vector3(3.6, 1.95, 0), wood.darkened(0.1), true, 1, "wood")
	for i in 3:
		Vox.box(hut, Vector3(1.9, 2.4, 0.12), Vector3(-2.2 + i * 2.2, 1.75, -2.6), Color(0.9, 0.86, 0.74), true, 0.0, "paper")
		Vox.box(hut, Vector3(0.12, 2.5, 0.16), Vector3(-3.25 + i * 2.2, 1.75, -2.6), wood)
	Vox.solid(hut, Vector3(7.2, 0.25, 0.4), Vector3(0, 3.1, -2.6), wood, true, 1, "wood")
	# соломенная крыша скатом
	var straw := Color(0.62, 0.52, 0.3)
	Vox.solid(hut, Vector3(9.4, 0.5, 7.6), Vector3(0, 3.65, 0), straw, true, 1, "roof")
	Vox.solid(hut, Vector3(8.4, 0.6, 5.0), Vector3(0, 4.15, 0), straw.darkened(0.08), true, 1, "roof")
	Vox.solid(hut, Vector3(7.0, 0.6, 2.4), Vector3(0, 4.7, 0), straw.darkened(0.15), true, 1, "roof")
	Vox.box(hut, Vector3(7.4, 0.25, 0.5), Vector3(0, 5.1, 0), Color(0.3, 0.22, 0.16))
	# дым из очага, дрова, бочка с водой, точильный камень
	if w.has_method("_smoke"):
		w.call("_smoke", w.TRAIN + c + Vector3(-2.0, 5.4, 0.5))
	for i in 4:
		Vox.box(self, Vector3(1.4, 0.32, 0.32), c + Vector3(-5.4, 0.2 + i * 0.3, -1.0 + (i % 2) * 0.2), Color(0.55, 0.38, 0.22), true, 0.0, "bark")
	Vox.box(self, Vector3(0.9, 1.0, 0.9), c + Vector3(5.0, 0.5, -1.6), Color(0.45, 0.32, 0.2), true, 0.0, "wood")
	Vox.box(self, Vector3(0.75, 0.05, 0.75), c + Vector3(5.0, 0.98, -1.6), Color(0.3, 0.5, 0.6), false)
	Vox.box(self, Vector3(1.0, 0.4, 0.5), c + Vector3(-4.6, 0.2, -3.6), Color(0.6, 0.6, 0.62), true, 0.0, "stone")
	# фонари у двора и тории над началом тропы
	w._lantern(w.TRAIN + Vector3(-3.5, 0, 44))
	w._lantern(w.TRAIN + Vector3(3.5, 0, 44))
	_torii(Vector3(path_x(40.0), SUMMIT_H, 40.5), 0.0, 4.2)

func _torii(p: Vector3, rot: float, span: float) -> void:
	var t := Node3D.new()
	t.position = p
	t.rotation.y = rot
	add_child(t)
	var red := Color(0.78, 0.16, 0.1)
	for s in [-1, 1]:
		Vox.solid(t, Vector3(0.45, 4.2, 0.45), Vector3(s * span * 0.5, 2.1, 0), red, true, 1, "wood")
		Vox.box(t, Vector3(0.6, 0.4, 0.6), Vector3(s * span * 0.5, 0.2, 0), Color(0.15, 0.13, 0.13))
	Vox.box(t, Vector3(span + 1.8, 0.4, 0.55), Vector3(0, 4.35, 0), Color(0.15, 0.12, 0.12))
	Vox.box(t, Vector3(span + 1.2, 0.3, 0.45), Vector3(0, 3.95, 0), red, true, 0.0, "wood")
	Vox.box(t, Vector3(span + 0.6, 0.25, 0.35), Vector3(0, 3.3, 0), red, true, 0.0, "wood")
	Vox.box(t, Vector3(0.6, 0.8, 0.1), Vector3(0, 3.62, -0.05), Color(0.12, 0.1, 0.1))

# --- тропа: каменные фонари, верёвки, поваленный ствол, мостик-бревно над расщелиной (сломан) ---
func _path_props(rng: RandomNumberGenerator) -> void:
	var z := 36.0
	while z > -6.0:
		if z < GAP.x - 1.0 or z > GAP.y + 1.0:
			for s in [-1, 1]:
				if rng.randf() < 0.55:
					var x: float = path_x(z) + s * 3.0
					var hh := path_h(z)
					Vox.box(self, Vector3(0.5, 0.9, 0.5), Vector3(x, hh + 0.45, z), Color(0.55, 0.55, 0.57), true, 0.0, "stone")
					Vox.box(self, Vector3(0.7, 0.25, 0.7), Vector3(x, hh + 1.0, z), Color(0.48, 0.48, 0.5), true, 0.0, "stone")
		z -= 4.0
	# поваленный ствол поперёк тропы — перепрыгнуть
	var lz := 9.0
	Vox.solid(self, Vector3(6.0, 0.8, 0.8), Vector3(path_x(lz), path_h(lz) + 0.4, lz), Color(0.42, 0.3, 0.2), true, 1, "bark")
	Vox.box(self, Vector3(0.8, 0.7, 0.7), Vector3(path_x(lz) + 2.6, path_h(lz) + 1.0, lz + 0.2), Color(0.25, 0.42, 0.2), true, 0.0, "leaves")
	# обломки мостика у края расщелины и табличка
	for s in [GAP.y + 0.3, GAP.x - 0.3]:
		Vox.box(self, Vector3(0.4, 0.3, 1.6), Vector3(path_x(s) - 1.2, path_h(s) + 0.15, s + (0.5 if s > 20 else -0.5)), Color(0.45, 0.32, 0.2), true, 0.0, "wood")
		Vox.box(self, Vector3(0.4, 0.3, 1.2), Vector3(path_x(s) + 1.2, path_h(s) + 0.15, s + (0.4 if s > 20 else -0.4)), Color(0.45, 0.32, 0.2), true, 0.0, "wood")
	var sz := GAP.y + 2.5
	var sx := path_x(sz) + 3.0
	Vox.box(self, Vector3(0.14, 1.4, 0.14), Vector3(sx, path_h(sz) + 0.7, sz), Color(0.4, 0.3, 0.2))
	Vox.box(self, Vector3(0.9, 0.5, 0.08), Vector3(sx, path_h(sz) + 1.35, sz), Color(0.75, 0.66, 0.5), true, 0.0, "wood")

# --- водопад: падающая вода, пена, брызги, заводь ---------------------------
func _waterfall() -> void:
	var x := POOL.x - 3.9
	var top := 16.0
	var mi := MeshInstance3D.new()
	var qm := QuadMesh.new()
	qm.size = Vector2(3.2, top + 1.0)
	mi.mesh = qm
	mi.position = Vector3(x, top * 0.5 - 0.5, POOL.y)
	mi.rotation.y = PI * 0.5
	var sm := ShaderMaterial.new()
	sm.shader = load("res://shaders/waterfall.gdshader")
	mi.material_override = sm
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	# заводь
	var pm := PlaneMesh.new()
	pm.size = Vector2(POOL_R * 2.0, POOL_R * 2.0)
	pm.subdivide_width = 10
	pm.subdivide_depth = 10
	var wm := MeshInstance3D.new()
	wm.mesh = pm
	wm.position = Vector3(POOL.x, -0.3, POOL.y)
	var wmat := ShaderMaterial.new()
	wmat.shader = load("res://shaders/water.gdshader")
	wmat.set_shader_parameter("rect", Vector4(w.TRAIN.x + POOL.x - POOL_R, POOL.y - POOL_R, w.TRAIN.x + POOL.x + POOL_R, POOL.y + POOL_R))
	wm.material_override = wmat
	wm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(wm)
	# брызги и пена у подножия
	var sp := CPUParticles3D.new()
	sp.amount = 60
	sp.lifetime = 1.2
	sp.preprocess = 1.2
	sp.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	sp.emission_box_extents = Vector3(0.6, 0.1, 1.4)
	sp.position = Vector3(x + 1.0, 0.0, POOL.y)
	sp.direction = Vector3(1, 1.5, 0)
	sp.spread = 40.0
	sp.initial_velocity_min = 1.5
	sp.initial_velocity_max = 3.5
	sp.gravity = Vector3(0, -6, 0)
	var bm := BoxMesh.new()
	bm.size = Vector3(0.12, 0.12, 0.12)
	var mm := StandardMaterial3D.new()
	mm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mm.albedo_color = Color(0.92, 0.97, 1.0)
	bm.material = mm
	sp.mesh = bm
	sp.scale_amount_min = 0.5
	sp.scale_amount_max = 1.6
	add_child(sp)
	# плоский камень для медитации в заводи
	Vox.solid(self, Vector3(2.2, 1.1, 2.2), Vector3(POOL.x + 1.0, -0.45, POOL.y), Color(0.5, 0.5, 0.53), true, 1, "stone")
	for i in 14:
		var a := TAU * i / 14.0
		var p := Vector3(POOL.x + cos(a) * (POOL_R + 0.3), 0, POOL.y + sin(a) * (POOL_R + 0.3))
		if p.x < POOL.x - 3.0:
			continue
		var s := 0.5 + 0.4 * absf(sin(i * 3.7))
		Vox.box(self, Vector3(s * 1.3, s * 0.6, s), p + Vector3.UP * s * 0.2, Color(0.55, 0.55, 0.57), false, 0.0, "stone")

func meditate_spot() -> Vector3:
	return Vector3(POOL.x + 1.0, 0.1, POOL.y)

# --- поляна: столбы для чучел, стойка с деревянными мечами ------------------
func _clearing(rng: RandomNumberGenerator) -> void:
	# стойка с бокенами
	var rack := Vector3(8, 0, -16)
	Vox.box(self, Vector3(2.4, 0.15, 0.3), rack + Vector3(0, 1.2, 0), Color(0.45, 0.32, 0.2), true, 0.0, "wood")
	Vox.box(self, Vector3(2.4, 0.15, 0.3), rack + Vector3(0, 0.5, 0), Color(0.45, 0.32, 0.2), true, 0.0, "wood")
	for s in [-1, 1]:
		Vox.box(self, Vector3(0.15, 1.4, 0.3), rack + Vector3(s * 1.1, 0.7, 0), Color(0.4, 0.28, 0.18), true, 0.0, "wood")
	for i in 3:
		Vox.box(self, Vector3(0.08, 1.2, 0.1), rack + Vector3(-0.6 + i * 0.6, 0.9, 0.18), Color(0.7, 0.55, 0.35))
	# камни по поляне
	for i in 18:
		var a := rng.randf() * TAU
		var r := rng.randf_range(20.0, CLEAR_R - 2.0)
		var p := Vector3(CLEAR_C.x + cos(a) * r, 0, CLEAR_C.y + sin(a) * r)
		if p.distance_to(BOULDER) < 9.0 or Vector2(p.x, p.z).distance_to(POOL) < POOL_R + 2.0 or h(p.x, p.z) != 0.0:
			continue
		var s := rng.randf_range(0.4, 1.2)
		Vox.box(self, Vector3(s * 1.4, s * 0.8, s * 1.1), p + Vector3.UP * s * 0.3, Color(0.52, 0.52, 0.55), true, 0.0, "stone")
	w._lantern(w.TRAIN + Vector3(-4, 0, -14))
	w._lantern(w.TRAIN + Vector3(4, 0, -14))

# --- валун ------------------------------------------------------------------
func _boulder() -> void:
	var b = StaticBody3D.new()
	b.set_script(load("res://scripts/boulder.gd"))
	b.position = BOULDER
	add_child(b)
	b.build()
	boulder = b

# --- клетка с пойманным демоном (бамбук, верёвки, офуда) --------------------
func _cage() -> void:
	cage = Node3D.new()
	cage.position = CAGE
	add_child(cage)
	var bam := Color(0.55, 0.62, 0.3)
	for i in 10:
		var a := TAU * i / 10.0
		Vox.box(cage, Vector3(0.14, 2.6, 0.14), Vector3(cos(a) * 1.4, 1.3, sin(a) * 1.4), bam, true, 0.0, "bark")
	for y in [0.3, 1.4, 2.5]:
		for s in [Vector3(1, 0, 0), Vector3(0, 0, 1)]:
			Vox.box(cage, Vector3(3.0, 0.1, 0.1) if s.x > 0 else Vector3(0.1, 0.1, 3.0), Vector3(0, y, 0), Color(0.45, 0.35, 0.22))
	Vox.box(cage, Vector3(3.2, 0.2, 3.2), Vector3(0, 2.7, 0), Color(0.45, 0.36, 0.24), true, 0.0, "wood")
	for i in 4:
		Vox.box(cage, Vector3(0.18, 0.4, 0.04), Vector3(-0.6 + i * 0.4, 1.9, -1.45), Color(0.95, 0.9, 0.75), false, 0.3)

# Клетку открывают: прутья разлетаются.
func open_cage() -> void:
	if cage == null:
		return
	G.fx.debris_burst(cage.global_position + Vector3.UP * 1.2, Color(0.55, 0.62, 0.3), 14, 0.2, Vector3.UP * 3.0, 5.0)
	G.sfx.play("wood", -2.0)
	cage.queue_free()
	cage = null

# --- деревья: кедры по краю поляны, сосны на склонах ------------------------
func _trees(rng: RandomNumberGenerator) -> void:
	var spots := []
	var tries := 0
	while spots.size() < 16 and tries < 600:
		tries += 1
		var a := rng.randf() * TAU
		var r := rng.randf_range(CLEAR_R - 9.0, CLEAR_R + 2.0)
		var p := Vector3(CLEAR_C.x + cos(a) * r, 0, CLEAR_C.y + sin(a) * r)
		if h(p.x, p.z) > 1.5 or p.distance_to(BOULDER) < 9.0 or Vector2(p.x, p.z).distance_to(POOL) < 8.0 or (absf(p.x - path_x(p.z)) < 6.0 and p.z > -16.0):
			continue
		var ok := true
		for q in spots:
			if (q as Vector3).distance_to(p) < 7.0:
				ok = false
				break
		if ok:
			spots.append(p)
	var i := 0
	for p in spots:
		var c = StaticBody3D.new()
		c.set_script(Cedar)
		add_child(c)
		c.position = Vector3(p.x, h(p.x, p.z), p.z)
		c.build(rng.randf_range(15.0, 22.0), rng.randf_range(1.0, 1.4), 300 + i, Color(0.14, 0.32, 0.2).lerp(Color(0.2, 0.4, 0.22), rng.randf()))
		w.cedar_pads.append_array(c.pads)
		i += 1
	# хвойные на склонах вдоль тропы и у хижины (обычные деревья мира)
	var n := 0
	tries = 0
	while n < 26 and tries < 800:
		tries += 1
		var p := Vector3(rng.randf_range(-24, 24), 0, rng.randf_range(-4, 60))
		var hh := h(p.x, p.z)
		var floor_h := path_h(p.z)
		if absf(p.x - path_x(p.z)) < 5.5 or (p.z > 36 and absf(p.x) < 15) or hh < floor_h + 2.0 or hh > 26.0:
			continue
		w._tree(w.TRAIN + p, rng.randf_range(5.5, 8.5), rng.randf_range(0.5, 0.75), "tree", Color(0.12, 0.3, 0.18).lerp(Color(0.2, 0.38, 0.2), rng.randf()))
		n += 1

# --- ловушки: брёвна катятся по тропе (выше расщелины) ------------------------
func _physics_process(dt: float) -> void:
	if logs_on:
		log_t -= dt
		if log_t <= 0.0:
			log_t = 2.3
			_spawn_log()
	var p = G.player
	for i in range(logs.size() - 1, -1, -1):
		var L: Array = logs[i]
		var n: Node3D = L[0]
		L[1] -= L[2] * dt
		L[2] = minf(L[2] + dt * 3.0, 11.0)
		var z: float = L[1]
		if z < GAP.y - 0.5:
			# падает в расщелину
			n.position.y -= dt * 14.0
			if n.position.y < -9.0:
				n.queue_free()
				logs.remove_at(i)
			continue
		var gy := path_h(z) + 0.45
		n.position = Vector3(path_x(z), lerpf(n.position.y, gy, 1.0 - exp(-14.0 * dt)), z)
		n.rotation.x -= L[2] * dt / 0.45
		if p and not L[3]:
			var to: Vector3 = p.global_position - n.global_position
			if absf(to.z) < 0.75 and absf(to.x) < 3.3 and to.y < 0.55 and to.y > -1.2:
				L[3] = true
				var res: String = p.receive_attack(9.0, n.global_position - Vector3(0, 0, 1.0), false, null)
				if res == "hit":
					G.fx.debris_burst(n.global_position, Color(0.42, 0.3, 0.2), 4, 0.18, Vector3(0, 3, -3), 2.0)
					G.sfx.play("wood", -3.0)

func _spawn_log() -> void:
	var z := 38.0
	var n := Node3D.new()
	add_child(n)
	n.position = Vector3(path_x(z), path_h(z) + 0.45, z)
	var m := Vox.box(n, Vector3(6.2, 0.75, 0.75), Vector3.ZERO, Color(0.45, 0.32, 0.2), true, 0.0, "bark")
	m.rotation.x = 0.0
	Vox.box(n, Vector3(0.1, 0.62, 0.62), Vector3(3.12, 0, 0), Color(0.75, 0.6, 0.4))
	Vox.box(n, Vector3(0.1, 0.62, 0.62), Vector3(-3.12, 0, 0), Color(0.75, 0.6, 0.4))
	logs.append([n, z, 5.0, false])

# Новая игра: валун снова цел, демон снова в клетке.
func reset_tutorial() -> void:
	stop_logs()
	if boulder == null or boulder.split:
		if boulder:
			boulder.queue_free()
		_boulder()
	if cage == null:
		_cage()

func stop_logs() -> void:
	logs_on = false
	for L in logs:
		if is_instance_valid(L[0]):
			L[0].queue_free()
	logs.clear()
