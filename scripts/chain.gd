extends Node3D
# Цепь между навершиями парных клинков: звенья на физике точек.
# Концы задаёт герой каждый кадр (pa, pb). Если клинки разошлись дальше
# длины цепи (бросок на цепи) — цепь «вытравливается» и натягивается.

const Vox = preload("res://scripts/vox.gd")

var pa := Vector3.ZERO
var pb := Vector3.ZERO
var length := 1.3                 # длина цепи в покое
var n := 18
var pos := PackedVector3Array()
var prev := PackedVector3Array()
var links: Array = []
var prev_dt := 1.0 / 60.0
var seg := 0.1

const LINK := 0.07                # длина звена — постоянная, цепь не растягивается
const MAX_LINKS := 120

func setup() -> void:
	top_level = true
	pos.resize(n)
	prev.resize(n)
	var dark := Vox.cel_mat(Color(0.42, 0.42, 0.48), true, 0.0, 0.004)
	var light := Vox.cel_mat(Color(0.7, 0.7, 0.76), true, 0.1, 0.004)
	var bm := _link_mesh()
	for i in MAX_LINKS:
		var mi := MeshInstance3D.new()
		mi.mesh = bm
		mi.material_override = dark if i % 2 == 0 else light
		mi.top_level = true
		mi.visible = false
		add_child(mi)
		links.append(mi)
	reset()

# Звено — настоящее кольцо: две продольные планки и две перемычки с дыркой посередине.
# Соседние звенья повёрнуты на 90° и заходят друг в друга.
static var _lm: ArrayMesh
static func _link_mesh() -> ArrayMesh:
	if _lm:
		return _lm
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var l := LINK * 1.45
	var w := 0.036
	var t := 0.011
	var parts := [
		[Vector3(t, t, l), Vector3(0, (w - t) * 0.5, 0)],
		[Vector3(t, t, l), Vector3(0, -(w - t) * 0.5, 0)],
		[Vector3(t, w, t), Vector3(0, 0, (l - t) * 0.5)],
		[Vector3(t, w, t), Vector3(0, 0, -(l - t) * 0.5)],
	]
	for pr in parts:
		var bm := BoxMesh.new()
		bm.size = pr[0]
		st.append_from(bm, 0, Transform3D(Basis.IDENTITY, pr[1]))
	_lm = st.commit()
	return _lm

func reset() -> void:
	for i in n:
		pos[i] = pa.lerp(pb, float(i) / (n - 1)) + Vector3(0, -0.05, 0)
		prev[i] = pos[i]

# Середина цепи (для проверок).
func middle() -> Vector3:
	return pos[n / 2]

func sag() -> float:
	var lo := 99.0
	for p in pos:
		lo = minf(lo, p.y)
	return minf(pa.y, pb.y) - lo

func _physics_process(dt: float) -> void:
	if dt <= 0.0 or not is_visible_in_tree():
		return
	dt = minf(dt, 1.0 / 30.0)
	if pa.distance_to(pos[0]) > 3.0 or pb.distance_to(pos[n - 1]) > 9.0:
		reset()
	# цепь движется вместе с героем (иначе на большой скорости и во вспышках
	# свободные звенья отстают и цепь растягивается на метры)
	var carry := pa - pos[0]
	for i in range(1, n - 1):
		pos[i] += carry
		prev[i] += carry
	var span := pa.distance_to(pb)
	seg = maxf(length, span * 1.02) / (n - 1)
	var ratio := dt / prev_dt
	prev_dt = dt
	for i in range(1, n - 1):
		var v := (pos[i] - prev[i]) * ratio * 0.96
		prev[i] = pos[i]
		pos[i] = pos[i] + v + Vector3(0, -16.0, 0) * dt * dt
	for it in 6:
		pos[0] = pa
		pos[n - 1] = pb
		for i in range(1, n):
			var d := pos[i] - pos[i - 1]
			var l := d.length()
			if l < 0.0001:
				continue
			var diff := (l - seg) / l
			var wa := 0.0 if i - 1 == 0 else 0.5
			var wb := 0.0 if i == n - 1 else 0.5
			var s := wa + wb
			if s <= 0.0:
				continue
			pos[i - 1] += d * diff * (wa / s)
			pos[i] -= d * diff * (wb / s)
			if pos[i].y < 0.03:
				pos[i].y = 0.03
	pos[0] = pa
	pos[n - 1] = pb
	# жёсткий предел длины звеньев: проход от одного конца и от другого
	# (иначе на резких ударах звенья не успевают сойтись и цепь тянется)
	var lim := seg * 1.03
	for pass_i in 3:
		for i in range(1, n - 1):
			var d := pos[i] - pos[i - 1]
			var l := d.length()
			if l > lim:
				var np := pos[i - 1] + d / l * lim
				prev[i] += np - pos[i]
				pos[i] = np
		for i in range(n - 2, 0, -1):
			var d := pos[i] - pos[i + 1]
			var l := d.length()
			if l > lim:
				var np := pos[i + 1] + d / l * lim
				prev[i] += np - pos[i]
				pos[i] = np
	# защита: если цепь всё же вытянулась вдвое длиннее нужного — уложить заново
	var total := 0.0
	for i in n - 1:
		total += pos[i].distance_to(pos[i + 1])
	if total > maxf(length, span) * 2.0 + 0.5:
		reset()
	_render()

# Звенья одинакового размера раскладываются вдоль ломаной цепи:
# длинная цепь — больше звеньев, а не растянутые звенья.
func _render() -> void:
	var used := 0
	var carry := 0.0
	for i in n - 1:
		var p0 := pos[i]
		var d := pos[i + 1] - p0
		var l := d.length()
		if l < 0.0001:
			continue
		var z := -d / l
		var up := Vector3.UP if absf(z.dot(Vector3.UP)) < 0.95 else Vector3.FORWARD
		var x := up.cross(z).normalized()
		var b := Basis(x, z.cross(x), z)
		var s := carry
		while s < l and used < MAX_LINKS:
			var mi: MeshInstance3D = links[used]
			var bb := b if used % 2 == 0 else b * Basis(Vector3.BACK, PI * 0.5)
			mi.global_transform = Transform3D(bb, p0 + d * ((s + LINK * 0.5) / l))
			mi.visible = true
			used += 1
			s += LINK
		carry = s - l
	for i in range(used, MAX_LINKS):
		links[i].visible = false
