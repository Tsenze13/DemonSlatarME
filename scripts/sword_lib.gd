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
const FLIP := [8]   # у гибкого клинка автоматика путает рукоять и лезвие

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
		for k in 3:
			if k != axis:
				w = maxf(w, b.size[k])
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

# Ножны по форме клинка: та же геометрия, толще и шире, свой цвет и пиксельный узор,
# металлическое кольцо у устья, наконечник и шнур-сагэо.
static func make_scabbard(i: int, style := 0) -> Node3D:
	var st: Array = SAYA[clampi(style, 0, SAYA.size() - 1)]
	var root := Node3D.new()
	var body := make_part(i, "blade")
	var copy: Node3D = body.get_child(0)
	var mat: ShaderMaterial = Vox.cel_mat(st[1], false, 0.0, 0.022, st[2], true).duplicate()
	mat.set_shader_parameter("tex_scale", 6.0)
	mat.set_shader_parameter("rim", 0.45)
	for mi in copy.find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).material_override = mat
	body.scale = Vector3(2.6, 1.03, 1.3)
	root.add_child(body)
	var inf: Dictionary = _info[i]
	var w: float = inf.blade_w
	var metal: Color = st[3]
	# кольцо устья, наконечник ножен, шнур
	Vox.box(root, Vector3(0.06, 0.04, w + 0.05), Vector3(0, -0.03, 0), metal, true, 0.15)
	Vox.box(root, Vector3(0.055, 0.05, w * 0.9 + 0.03), Vector3(0, -BLADE_LEN - 0.01, 0), metal, true, 0.15)
	Vox.box(root, Vector3(0.065, 0.025, w + 0.055), Vector3(0, -0.13, 0), Color(0.75, 0.15, 0.2))
	return root

static func cleanup() -> void:
	if _scene != null and is_instance_valid(_scene):
		_scene.free()
	_scene = null
	_groups.clear()
	_info.clear()
