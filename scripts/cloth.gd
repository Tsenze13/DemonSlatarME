extends MeshInstance3D
# Ткань и пряди на физике точек (verlet): верхний ряд пришит к телу,
# остальное болтается от движения, гравитации и ветра.
# mode "sheet" — полотно (хаори), "chain" — цепочка блоков (хвост волос, ленты).

const Vox = preload("res://scripts/vox.gd")

var attach: Node3D               # к чему пришито (торс / голова)
var anchors: Array = []          # локальные точки крепления в attach
var cols := 1
var rows := 4
var seg := 0.15
var mode := "sheet"
var gravity := 14.0
var drag := 0.04
var wind := 1.0
var push_plane_z := 0.0          # не пускать ткань внутрь тела: z в системе attach
var push_dir := -1.0             # -1: ткань должна быть позади (z <= plane), +1: впереди
var push_y_max := 99.0
var chain_size := Vector3(0.1, 0.1, 0.1)
var chain_col := Color.BLACK
var chain_taper := 0.6

var pos: PackedVector3Array
var prev: PackedVector3Array
var prev_dt := 1.0 / 60.0
var im: ImmediateMesh
var blocks: Array = []
var t := 0.0

func setup() -> void:
	top_level = true
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	pos = PackedVector3Array()
	prev = PackedVector3Array()
	pos.resize(cols * rows)
	prev.resize(cols * rows)
	reset()
	if mode == "sheet":
		im = ImmediateMesh.new()
		mesh = im
	else:
		for r in rows - 1:
			var k := 1.0 - (1.0 - chain_taper) * float(r) / maxf(1.0, rows - 2)
			var mi := MeshInstance3D.new()
			var bm := BoxMesh.new()
			bm.size = Vector3(chain_size.x * k, chain_size.y * k, seg * 1.15)
			mi.mesh = bm
			mi.material_override = Vox.cel_mat(chain_col, true)
			mi.top_level = true
			add_child(mi)
			blocks.append(mi)

func _idx(c: int, r: int) -> int:
	return r * cols + c

func reset() -> void:
	for c in cols:
		var a: Vector3 = attach.to_global(anchors[c])
		var down := -attach.global_transform.basis.y.normalized()
		for r in rows:
			var p := a + down * seg * r
			pos[_idx(c, r)] = p
			prev[_idx(c, r)] = p

func _physics_process(dt: float) -> void:
	if dt <= 0.0 or attach == null:
		return
	t += dt
	dt = minf(dt, 1.0 / 30.0)
	# сбросить при телепорте
	var a0: Vector3 = attach.to_global(anchors[0])
	if a0.distance_to(pos[0]) > 2.0:
		reset()
	var ratio := dt / prev_dt
	prev_dt = dt
	var wind_v := Vector3(sin(t * 1.7) * 1.5 + sin(t * 4.1) * 0.6, 0.0, cos(t * 1.3) * 1.2) * wind
	for c in cols:
		for r in range(1, rows):
			var i := _idx(c, r)
			var v := (pos[i] - prev[i]) * ratio * (1.0 - drag)
			prev[i] = pos[i]
			var acc := Vector3(0, -gravity, 0) + wind_v * (0.5 + 0.5 * float(r) / rows)
			pos[i] = pos[i] + v + acc * dt * dt
	var inv := attach.global_transform.affine_inverse()
	for it in 5:
		for c in cols:
			pos[_idx(c, 0)] = attach.to_global(anchors[c])
		for c in cols:
			for r in range(1, rows):
				_constrain(_idx(c, r - 1), _idx(c, r), seg, r - 1 == 0)
				if c > 0:
					var rest: float = (anchors[c] - anchors[c - 1]).length()
					_constrain(_idx(c - 1, r), _idx(c, r), rest, false)
		# не пускать ткань внутрь тела
		for c in cols:
			for r in range(1, rows):
				var i := _idx(c, r)
				var lp: Vector3 = inv * pos[i]
				if lp.y < push_y_max and (lp.z - push_plane_z) * push_dir < 0.0:
					lp.z = push_plane_z
					pos[i] = attach.global_transform * lp
	_draw_cloth()

func _constrain(i: int, j: int, rest: float, i_pinned: bool) -> void:
	var d := pos[j] - pos[i]
	var l := d.length()
	if l < 0.0001:
		return
	var diff := (l - rest) / l
	if i_pinned:
		pos[j] -= d * diff
	else:
		pos[i] += d * diff * 0.5
		pos[j] -= d * diff * 0.5

func _draw_cloth() -> void:
	global_transform = Transform3D.IDENTITY
	if mode == "sheet":
		im.clear_surfaces()
		im.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
		for c in cols - 1:
			for r in rows - 1:
				var a := _idx(c, r)
				var b := _idx(c + 1, r)
				var cc := _idx(c, r + 1)
				var d := _idx(c + 1, r + 1)
				var n := (pos[b] - pos[a]).cross(pos[cc] - pos[a]).normalized()
				var u0 := float(c) / (cols - 1)
				var u1 := float(c + 1) / (cols - 1)
				var v0 := float(r) / (rows - 1)
				var v1 := float(r + 1) / (rows - 1)
				_v(a, n, u0, v0)
				_v(b, n, u1, v0)
				_v(cc, n, u0, v1)
				_v(b, n, u1, v0)
				_v(d, n, u1, v1)
				_v(cc, n, u0, v1)
		im.surface_end()
	else:
		for r in rows - 1:
			var p0 := pos[_idx(0, r)]
			var p1 := pos[_idx(0, r + 1)]
			var mi: MeshInstance3D = blocks[r]
			mi.global_position = (p0 + p1) * 0.5
			var dir := p1 - p0
			if dir.length() > 0.001 and absf(dir.normalized().dot(Vector3.UP)) < 0.995:
				mi.look_at(p1, Vector3.UP)
			elif dir.length() > 0.001:
				mi.look_at(p1, Vector3.FORWARD)

func _v(i: int, n: Vector3, u: float, v: float) -> void:
	im.surface_set_normal(n)
	im.surface_set_uv(Vector2(u, v))
	im.surface_add_vertex(pos[i])
