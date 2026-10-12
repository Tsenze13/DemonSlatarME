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

func setup() -> void:
	top_level = true
	pos.resize(n)
	prev.resize(n)
	var dark := Vox.cel_mat(Color(0.42, 0.42, 0.48), true, 0.0, 0.012)
	var light := Vox.cel_mat(Color(0.7, 0.7, 0.76), true, 0.1, 0.012)
	for i in n - 1:
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.014, 0.034, 1.0)
		mi.mesh = bm
		mi.material_override = dark if i % 2 == 0 else light
		mi.top_level = true
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		add_child(mi)
		links.append(mi)
	reset()

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
	# звенья: соседние повёрнуты на 90° — получается цепь, а не лента
	for i in n - 1:
		var mi: MeshInstance3D = links[i]
		var p0 := pos[i]
		var p1 := pos[i + 1]
		var d2 := p1 - p0
		var l2 := d2.length()
		if l2 < 0.001:
			continue
		var z := -d2 / l2
		var up := Vector3.UP if absf(z.dot(Vector3.UP)) < 0.95 else Vector3.FORWARD
		var x := up.cross(z).normalized()
		var y := z.cross(x)
		var b := Basis(x, y, z)
		if i % 2 == 1:
			b = b * Basis(Vector3.BACK, PI * 0.5)
		mi.global_transform = Transform3D(b * Basis.from_scale(Vector3(1, 1, l2 * 1.25)), (p0 + p1) * 0.5)
