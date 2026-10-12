extends Node3D
# Гибкий клинок-хлыст: лента из звеньев на физике точек.
# Начало пришито к гарде меча. В покое свисает и волочится по земле,
# во время удара распрямляется вдоль направления клинка и хлещет.

const Vox = preload("res://scripts/vox.gd")

var anchor: Node3D            # узел клинка (гарда в начале, клинок вдоль -Y)
var n := 15
var seg := 0.17
var extend := 0.0             # 0 — висит, 1 — вытянут в струну
var pos := PackedVector3Array()
var prev := PackedVector3Array()
var blocks: Array = []
var prev_dt := 1.0 / 60.0
var col_a := Color(0.85, 0.32, 0.55)
var col_b := Color(0.2, 0.16, 0.28)

func setup() -> void:
	top_level = true
	pos.resize(n)
	prev.resize(n)
	for i in n - 1:
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		var k := 1.0 - 0.45 * float(i) / (n - 2)
		bm.size = Vector3(0.016, 0.075 * k, seg * 1.12)
		mi.mesh = bm
		mi.material_override = Vox.cel_mat(col_a if i % 3 != 2 else col_b, true, 0.35)
		mi.top_level = true
		add_child(mi)
		blocks.append(mi)
	reset()

func tip() -> Vector3:
	return pos[n - 1]

func reset() -> void:
	var a := anchor.global_position
	var d := -anchor.global_transform.basis.y.normalized()
	for i in n:
		pos[i] = a + d * seg * i
		prev[i] = pos[i]

func _physics_process(dt: float) -> void:
	if dt <= 0.0 or anchor == null or not is_visible_in_tree():
		return
	dt = minf(dt, 1.0 / 30.0)
	var a := anchor.global_position
	if a.distance_to(pos[0]) > 3.0:
		reset()
	var dir := -anchor.global_transform.basis.y.normalized()
	var ratio := dt / prev_dt
	prev_dt = dt
	for i in range(1, n):
		var v := (pos[i] - prev[i]) * ratio * 0.97
		prev[i] = pos[i]
		pos[i] = pos[i] + v + Vector3(0, -14.0 * (1.0 - extend), 0) * dt * dt
	# удар: звенья тянутся к прямой линии вдоль клинка
	if extend > 0.01:
		for i in range(1, n):
			var target := a + dir * seg * i
			pos[i] = pos[i].lerp(target, 0.32 * extend)
	for it in 4:
		pos[0] = a
		for i in range(1, n):
			var d := pos[i] - pos[i - 1]
			var l := d.length()
			if l < 0.0001:
				continue
			var diff := (l - seg) / l
			if i == 1:
				pos[i] -= d * diff
			else:
				pos[i - 1] += d * diff * 0.5
				pos[i] -= d * diff * 0.5
			if pos[i].y < 0.03:
				pos[i].y = 0.03
	for i in n - 1:
		var mi: MeshInstance3D = blocks[i]
		var p0 := pos[i]
		var p1 := pos[i + 1]
		mi.global_position = (p0 + p1) * 0.5
		var d2 := p1 - p0
		if d2.length() > 0.001:
			var up := Vector3.UP if absf(d2.normalized().dot(Vector3.UP)) < 0.95 else Vector3.FORWARD
			mi.look_at(p1, up)
