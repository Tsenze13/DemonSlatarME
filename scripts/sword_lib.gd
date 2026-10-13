extends RefCounted
# Мечи из модели игрока (assets/swords/swords.gltf, 9 штук).
# Для каждого меча сами находим гарду (самый широкий блок), сторону клинка
# (длинная часть от гарды) и плоскость лезвия, затем приводим к нашей
# системе: гарда в начале координат, клинок вдоль -Y, ширина лезвия вдоль Z.

const PATH := "res://assets/swords/swords.gltf"
const BLADE_LEN := 0.85

const NAMES := [
	"Синий клинок", "Бирюзовый клинок", "Волнистый клинок", "Огненный клинок", "Зелёный клинок",
	"Тонкий клинок", "Широкий клинок (левый)", "Широкий клинок (правый)", "Гибкий клинок",
]
const FLIP := []   # если автоматика перепутает рукоять и клинок — номер сюда

static var _scene: Node3D
static var _groups: Array = []
static var _info: Array = []

static func count() -> int:
	_ensure()
	return _groups.size()

static func info(i: int) -> Dictionary:
	_ensure()
	return _info[i]

static func _ensure() -> void:
	if _scene != null:
		return
	if not ResourceLoader.exists(PATH):
		# модели нет (например, проект взят из git без assets/swords) — будет свой кубический меч
		_scene = Node3D.new()
		return
	var ps: PackedScene = load(PATH)
	_scene = ps.instantiate()
	var bone := _scene.find_child("bone_277", true, false)
	for c in bone.get_children():
		_groups.append(c)
	for i in _groups.size():
		_info.append(_analyze(_groups[i], i in FLIP))

# Положение узла n в системе координат предка anc (без дерева сцены).
static func _rel(n: Node, anc: Node) -> Transform3D:
	var t := Transform3D.IDENTITY
	var cur := n
	while cur != null and cur != anc:
		if cur is Node3D:
			t = (cur as Node3D).transform * t
		cur = cur.get_parent()
	return t

static func _boxes(g: Node) -> Array:
	var out := []
	for mi in g.find_children("*", "MeshInstance3D", true, false):
		var xf := _rel(mi, g)
		out.append(xf * (mi as MeshInstance3D).get_aabb())
	return out

static func _analyze(g: Node, flip := false) -> Dictionary:
	var boxes := _boxes(g)
	var total: AABB = boxes[0]
	for b in boxes:
		total = total.merge(b)
	var axis := total.get_longest_axis_index()
	var lo: float = total.position[axis]
	var hi: float = lo + total.size[axis]
	# гарда — блок, шире всех поперёк оси меча
	var guard: AABB = boxes[0]
	var gw := 0.0
	for b in boxes:
		var w := 0.0
		var thin_side := 99.0
		for k in 3:
			if k != axis:
				w = maxf(w, b.size[k])
				thin_side = minf(thin_side, b.size[k])
		# плоские картинки (свёрнутый клинок хлыста) гардой не считаем
		if thin_side < 0.01:
			continue
		if w > gw:
			gw = w
			guard = b
	var gc: float = guard.get_center()[axis]
	var sgn := 1.0 if (hi - gc) > (gc - lo) else -1.0
	if flip:
		sgn = -sgn
	var blade_len := (hi - gc) if sgn > 0.0 else (gc - lo)
	var handle_len := (gc - lo) if sgn > 0.0 else (hi - gc)
	# плоскость клинка: по блокам дальше 30% длины от гарды
	var blade_box := AABB()
	var first := true
	for b in boxes:
		var c: float = b.get_center()[axis]
		if (c - gc) * sgn > blade_len * 0.3:
			if first:
				blade_box = b
				first = false
			else:
				blade_box = blade_box.merge(b)
	var others := []
	for k in 3:
		if k != axis:
			others.append(k)
	var a0: int = others[0]
	var a1: int = others[1]
	var wide := a0 if blade_box.size[a0] >= blade_box.size[a1] else a1
	var thin := a1 if wide == a0 else a0
	var dir := Vector3.ZERO
	dir[axis] = sgn
	var wv := Vector3.ZERO
	wv[wide] = 1.0
	var tv := Vector3.ZERO
	tv[thin] = 1.0
	var s := Basis(tv, -dir, wv)
	if s.determinant() < 0.0:
		s = Basis(-tv, -dir, wv)
	var m := s.inverse()
	var scale := BLADE_LEN / maxf(0.001, blade_len)
	var gp := total.get_center()
	gp[axis] = gc
	var basis := m.scaled(Vector3.ONE * scale)
	var xf := Transform3D(basis, -(basis * gp))
	return {"xform": xf, "handle": handle_len * scale, "guard_w": gw * scale,
		"blade_w": blade_box.size[wide] * scale, "blade_t": blade_box.size[thin] * scale}

# Цвета клинка (как у клинков, меняющих цвет под хозяина). Белый — как у модели.
const TINTS := [
	["Как у модели", Color(1, 1, 1)], ["Синий", Color(0.55, 0.75, 1.0)],
	["Алый", Color(1.0, 0.45, 0.42)], ["Золотой", Color(1.0, 0.85, 0.42)],
	["Зелёный", Color(0.55, 1.0, 0.6)], ["Фиолетовый", Color(0.78, 0.55, 1.0)],
	["Чёрный", Color(0.38, 0.38, 0.45)],
]

# Виды ножен: имя, цвет, текстура, цвет металла.
const SAYA := [
	["Чёрный лак", Color(0.13, 0.11, 0.16), "lacquer", Color(0.85, 0.7, 0.32)],
	["Алый лак", Color(0.62, 0.1, 0.12), "lacquer", Color(0.9, 0.75, 0.35)],
	["Синие волны", Color(0.2, 0.32, 0.68), "saya_wave", Color(0.85, 0.88, 0.95)],
	["Белый с золотом", Color(0.88, 0.85, 0.78), "saya_ring", Color(0.92, 0.75, 0.3)],
	["Обмотка ромбами", Color(0.25, 0.22, 0.32), "saya_diamond", Color(0.85, 0.7, 0.32)],
	["Тёмное дерево", Color(0.42, 0.27, 0.15), "wood", Color(0.3, 0.3, 0.33)],
]

static func _is_blade(copy: Node3D, mi: MeshInstance3D, xf: Transform3D) -> bool:
	var bb: AABB = xf * (_rel(mi, copy) * mi.get_aabb())
	return bb.get_center().y < -0.06

# Готовый меч: узел с моделью, гарда в (0,0,0), клинок вдоль -Y.
static func make(i: int, tint := Color(1, 1, 1)) -> Node3D:
	_ensure()
	var holder := Node3D.new()
	var copy: Node3D = _groups[i].duplicate()
	copy.transform = _info[i].xform
	holder.add_child(copy)
	for mi in copy.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		if tint != Color(1, 1, 1) and _is_blade(copy, m, _info[i].xform):
			var src := m.get_active_material(0)
			if src is StandardMaterial3D:
				var dm: StandardMaterial3D = src.duplicate()
				dm.albedo_color = tint
				dm.emission_enabled = true
				dm.emission = tint * 0.25
				m.material_override = dm
	return holder

# Части меча: "handle" — рукоять и гарда, "blade" — только клинок.
static func make_part(i: int, part: String) -> Node3D:
	var holder := make(i)
	var copy: Node3D = holder.get_child(0)
	var xf: Transform3D = _info[i].xform
	for mi in copy.find_children("*", "MeshInstance3D", true, false):
		var bb: AABB = xf * (_rel(mi, copy) * (mi as MeshInstance3D).get_aabb())
		var is_blade: bool = bb.get_center().y < -0.06
		if (part == "handle" and is_blade) or (part == "blade" and not is_blade):
			mi.visible = false
	return holder

const Vox = preload("res://scripts/vox.gd")

# ---------------------------------------------------------------------
# НОЖНЫ (сая). Гладкий лакированный корпус по изгибу и ширине клинка
# (профиль снимается с модели), роговое устье-койгути, кольца и шнур сагэо,
# выступ курикáта, металлический наконечник-кодзири. Одна сплошная модель
# со своим контуром — без «лесенки» от блоков клинка.
const SAYA_SEG := 16
const SAYA_T := 0.021                 # половина толщины ножен
static var _outline_sh: Shader

# Профиль клинка: середина по Z и ширина в SAYA_SEG+1 точках от гарды к острию.
static func blade_profile(i: int) -> Dictionary:
	_ensure()
	var zs := PackedFloat32Array()
	var ws := PackedFloat32Array()
	zs.resize(SAYA_SEG + 1)
	ws.resize(SAYA_SEG + 1)
	var boxes := []
	if i >= 0 and i < _groups.size():
		var xf: Transform3D = _info[i].xform
		for mi in _groups[i].find_children("*", "MeshInstance3D", true, false):
			var bb: AABB = xf * (_rel(mi, _groups[i]) * (mi as MeshInstance3D).get_aabb())
			if bb.get_center().y < -0.06:
				boxes.append(bb)
	var lz := 0.0
	var lw := 0.06
	for k in SAYA_SEG + 1:
		var y := -BLADE_LEN * float(k) / SAYA_SEG
		var half := BLADE_LEN / SAYA_SEG * 0.75
		var lo := 99.0
		var hi := -99.0
		for bb in boxes:
			if bb.position.y - half <= y and bb.end.y + half >= y:
				lo = minf(lo, bb.position.z)
				hi = maxf(hi, bb.end.z)
		if hi > lo:
			lz = (lo + hi) * 0.5
			lw = hi - lo
		zs[k] = lz
		ws[k] = lw
	# сглаживание — ножны гладкие, без ступенек клинка
	for pass_i in 3:
		var z2 := zs.duplicate()
		var w2 := ws.duplicate()
		for k in range(1, SAYA_SEG):
			z2[k] = (zs[k - 1] + zs[k] * 2.0 + zs[k + 1]) * 0.25
			w2[k] = (ws[k - 1] + ws[k] * 2.0 + ws[k + 1]) * 0.25
		zs = z2
		ws = w2
	# изгиб считаем от устья: устье в нуле
	var z0 := zs[0]
	for k in SAYA_SEG + 1:
		zs[k] -= z0
		ws[k] = maxf(ws[k], 0.04)
	return {"z": zs, "w": ws}

# Ножны по форме клинка i (или ровные, если клинка нет).
static func make_scabbard(i: int, style := 0) -> Node3D:
	return make_saya(blade_profile(i), style)

static func make_saya(prof: Dictionary, style := 0) -> Node3D:
	var st: Array = SAYA[clampi(style, 0, SAYA.size() - 1)]
	var root := Node3D.new()
	var zs: PackedFloat32Array = prof.z
	var ws: PackedFloat32Array = prof.w
	var L := BLADE_LEN + 0.03
	var metal: Color = st[3]
	var horn := Color(0.09, 0.08, 0.1)
	var cord := Color(0.72, 0.12, 0.16)
	# осевая линия ножен
	var pts := []
	var hws := []
	for k in SAYA_SEG + 1:
		var f := float(k) / SAYA_SEG
		# лёгкий изгиб (сори): к острию ножны уходят в сторону обуха (+Z)
		pts.append(Vector3(0, -L * f, zs[k] + 0.032 * f * f))
		hws.append(ws[k] * 0.5 + 0.013)
	# к острию ножны чуть сужаются и скругляются
	hws[SAYA_SEG] = hws[SAYA_SEG] * 0.8
	hws[SAYA_SEG - 1] = hws[SAYA_SEG - 1] * 0.93
	var body_mat: ShaderMaterial = Vox.cel_mat(st[1], false, 0.0, 0.0, st[2], true).duplicate()
	body_mat.set_shader_parameter("tex_scale", 7.0)
	body_mat.set_shader_parameter("rim", 0.5)
	var met_mat := Vox.cel_mat(metal, false, 0.12)
	var horn_mat := Vox.cel_mat(horn, false)
	var cord_mat := Vox.cel_mat(cord, false, 0.05)
	# корпус
	_tube(root, _part(pts, hws, 0.0, 1.0), SAYA_T, body_mat)
	# койгути — роговое устье
	_tube(root, _part(pts, hws, 0.0, 0.035, 0.006), SAYA_T + 0.006, horn_mat)
	# кольца сагэо
	_tube(root, _part(pts, hws, 0.1, 0.112, 0.005), SAYA_T + 0.005, cord_mat)
	_tube(root, _part(pts, hws, 0.13, 0.142, 0.005), SAYA_T + 0.005, cord_mat)
	# кодзири — металлический наконечник
	_tube(root, _part(pts, hws, 0.94, 1.0, 0.004), SAYA_T + 0.004, met_mat)
	# тонкий металлический поясок над наконечником
	_tube(root, _part(pts, hws, 0.9, 0.91, 0.004), SAYA_T + 0.004, met_mat)
	# курикáта — выступ сбоку, через него продет шнур
	var kp := _at(pts, 0.12)
	Vox.box(root, Vector3(0.018, 0.034, 0.022), kp + Vector3(SAYA_T + 0.009, 0, 0), horn, true)
	# сагэо — шнур свисает петлёй вдоль ножен
	var a := kp + Vector3(SAYA_T + 0.02, -0.01, 0.0)
	var b := _at(pts, 0.36) + Vector3(SAYA_T + 0.012, 0, 0.01)
	var c := _at(pts, 0.3) + Vector3(SAYA_T + 0.016, 0, -0.012)
	_cord(root, a, b, cord)
	_cord(root, b, c, cord)
	_cord(root, c, a + Vector3(0, -0.012, -0.01), cord)
	return root

# Кусок осевой линии от доли f0 до f1 длины (с утолщением grow).
static func _part(pts: Array, hws: Array, f0: float, f1: float, grow := 0.0) -> Array:
	var out := []
	var n := pts.size() - 1
	var steps := maxi(1, int(ceil((f1 - f0) * n)))
	for s in steps + 1:
		var f := lerpf(f0, f1, float(s) / steps)
		var x := f * n
		var k := mini(int(floor(x)), n - 1)
		var t := x - k
		var p: Vector3 = (pts[k] as Vector3).lerp(pts[k + 1], t)
		var hw: float = lerpf(hws[k], hws[k + 1], t) + grow
		out.append([p, hw])
	return out

static func _at(pts: Array, f: float) -> Vector3:
	var n := pts.size() - 1
	var x := f * n
	var k := mini(int(floor(x)), n - 1)
	return (pts[k] as Vector3).lerp(pts[k + 1], x - k)

static func _cord(root: Node3D, a: Vector3, b: Vector3, col: Color) -> void:
	var mi := Vox.box(root, Vector3(0.011, 0.011, a.distance_to(b) + 0.008), (a + b) * 0.5, col, false, 0.05)
	var z := (b - a).normalized()
	var up := Vector3.UP if absf(z.dot(Vector3.UP)) < 0.95 else Vector3.RIGHT
	var x := up.cross(z).normalized()
	mi.basis = Basis(x, z.cross(x), z)

# Трубка с восьмигранным сечением (скошенный прямоугольник) вдоль осевой линии
# + оболочка-контур. stations: [[точка, полуширина по Z]], hx — полутолщина по X.
static func _tube(root: Node3D, stations: Array, hx: float, mat: Material) -> void:
	var body := MeshInstance3D.new()
	body.mesh = _tube_mesh(stations, hx, 0.0)
	body.material_override = mat
	body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	root.add_child(body)
	if _outline_sh == null:
		_outline_sh = load("res://shaders/outline.gdshader")
	var om := ShaderMaterial.new()
	om.shader = _outline_sh
	om.set_shader_parameter("width", 0.0)
	om.set_shader_parameter("color", Color(0.03, 0.025, 0.04))
	var hull := MeshInstance3D.new()
	hull.mesh = _tube_mesh(stations, hx, 0.007)
	hull.material_override = om
	hull.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(hull)

static func _tube_mesh(stations: Array, hx: float, grow: float) -> ArrayMesh:
	var n := stations.size()
	var cs := []      # сечения: точки и нормали сторон для каждой станции
	for j in n:
		var p: Vector3 = stations[j][0]
		var hw: float = stations[j][1] + grow
		var a := hx + grow
		var prv: Vector3 = stations[maxi(0, j - 1)][0]
		var nxt: Vector3 = stations[mini(n - 1, j + 1)][0]
		var t := (nxt - prv).normalized()
		var nz := Vector3(0, t.z, -t.y).normalized()     # ось ширины, поперёк изгиба
		var ch := minf(a, hw) * 0.45
		var oct := [Vector2(a, hw - ch), Vector2(a - ch, hw), Vector2(-a + ch, hw), Vector2(-a, hw - ch),
			Vector2(-a, -hw + ch), Vector2(-a + ch, -hw), Vector2(a - ch, -hw), Vector2(a, -hw + ch)]
		var ring := []
		for q in oct:
			ring.append(p + Vector3.RIGHT * q.x + nz * q.y)
		cs.append({"ring": ring, "nz": nz, "p": p, "t": t})
	# концы оболочки чуть длиннее
	if grow > 0.0:
		var f: Dictionary = cs[0]
		var l: Dictionary = cs[n - 1]
		for k in 8:
			f.ring[k] -= f.t * grow
			l.ring[k] += l.t * grow
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for j in n - 1:
		var r0: Array = cs[j].ring
		var r1: Array = cs[j + 1].ring
		var mid: Vector3 = (cs[j].p + cs[j + 1].p) * 0.5
		for k in 8:
			var k2 := (k + 1) % 8
			var face_c: Vector3 = (r0[k] + r0[k2] + r1[k] + r1[k2]) * 0.25
			var nrm := (face_c - mid)
			nrm = (nrm - cs[j].t * nrm.dot(cs[j].t)).normalized()
			_tri(st, r0[k], r0[k2], r1[k2], nrm)
			_tri(st, r0[k], r1[k2], r1[k], nrm)
	# торцы
	for e in [0, n - 1]:
		var r: Array = cs[e].ring
		var c: Vector3 = cs[e].p - (cs[e].t * grow if e == 0 else -cs[e].t * grow)
		var nrm2: Vector3 = -cs[e].t if e == 0 else cs[e].t
		for k in 8:
			_tri(st, c, r[k], r[(k + 1) % 8], nrm2)
	return st.commit()

# Треугольник с плоской нормалью; обход подбирается так, чтобы лицевая сторона смотрела по нормали.
static func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, nrm: Vector3) -> void:
	if (b - a).cross(c - a).dot(nrm) > 0.0:
		var tmp := b
		b = c
		c = tmp
	st.set_normal(nrm)
	st.add_vertex(a)
	st.set_normal(nrm)
	st.add_vertex(b)
	st.set_normal(nrm)
	st.add_vertex(c)

static func cleanup() -> void:
	if _scene != null and is_instance_valid(_scene):
		_scene.free()
	_scene = null
	_groups.clear()
	_info.clear()
