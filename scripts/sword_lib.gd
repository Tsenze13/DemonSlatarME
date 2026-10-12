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

# Готовый меч: узел с моделью, гарда в (0,0,0), клинок вдоль -Y.
static func make(i: int) -> Node3D:
	_ensure()
	var holder := Node3D.new()
	var copy: Node3D = _groups[i].duplicate()
	copy.transform = _info[i].xform
	holder.add_child(copy)
	for mi in copy.find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	return holder
