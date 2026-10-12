extends Node3D
# Все визуальные эффекты: частицы, дуги стихий, кольца, остаточные
# силуэты, цифры урона, обломки.

const Vox = preload("res://scripts/vox.gd")

var parts: Array = []        # частицы: {n, v, life, max, g, drag, s0, spin}
var arcs: Array = []         # дуги: {n, mat, life, max, grow, kind}
var ghosts: Array = []
var debris: Array = []
var labels: Array = []
var _arc_shader: Shader
var _part_mesh: BoxMesh
const MAX_PARTS := 500
const MAX_DEBRIS := 140

func _ready() -> void:
	_arc_shader = load("res://shaders/arc.gdshader")
	_part_mesh = BoxMesh.new()
	_part_mesh.size = Vector3.ONE

# --- частицы ------------------------------------------------------------
func burst(pos: Vector3, col: Color, count: int, speed: float, size := 0.12,
		life := 0.5, grav := 9.0, dir := Vector3.ZERO, spread := 1.0, drag := 2.0) -> void:
	for i in count:
		if parts.size() >= MAX_PARTS:
			var old: Dictionary = parts.pop_front()
			old.n.queue_free()
		var mi := MeshInstance3D.new()
		mi.mesh = _part_mesh
		mi.material_override = Vox.flat_mat(col)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi)
		mi.global_position = pos
		var rv := Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)).normalized()
		var v := (dir * (1.0 - spread) + rv * spread).normalized() * speed * randf_range(0.5, 1.2) if dir != Vector3.ZERO else rv * speed * randf_range(0.3, 1.0)
		var s := size * randf_range(0.6, 1.3)
		mi.scale = Vector3.ONE * s
		var l := life * randf_range(0.6, 1.2)
		parts.append({"n": mi, "v": v, "life": l, "max": l, "g": grav, "drag": drag, "s0": s,
			"spin": Vector3(randf_range(-9, 9), randf_range(-9, 9), randf_range(-9, 9))})

func sparks(pos: Vector3, dir: Vector3, col := Color(1.0, 0.95, 0.7), n := 14) -> void:
	burst(pos, col, n, 14.0, 0.07, 0.25, 12.0, dir, 0.7, 4.0)
	burst(pos, Color.WHITE, n / 2, 9.0, 0.11, 0.15, 0.0, dir, 0.9, 6.0)

func blood(pos: Vector3, dir: Vector3, n := 12) -> void:
	burst(pos, Color(0.45, 0.02, 0.1), n, 8.0, 0.14, 0.6, 16.0, dir + Vector3.UP * 0.4, 0.6, 1.5)
	burst(pos, Color(0.75, 0.05, 0.15), n / 2, 11.0, 0.08, 0.4, 16.0, dir, 0.5, 1.5)

func dust(pos: Vector3, n := 10, col := Color(0.75, 0.68, 0.55)) -> void:
	burst(pos + Vector3.UP * 0.1, col, n, 4.0, 0.22, 0.6, -1.0, Vector3.UP * 0.2, 1.0, 3.0)

func ash(pos: Vector3, n := 6) -> void:
	burst(pos, Color(0.12, 0.1, 0.12), n, 1.5, 0.1, 1.6, -2.5, Vector3(0.6, 1.0, 0.2), 0.6, 0.5)
	burst(pos, Color(0.95, 0.35, 0.15), n / 3 + 1, 1.2, 0.06, 1.0, -3.0, Vector3.UP, 0.7, 0.5)

func droplets(pos: Vector3, dir: Vector3, n := 10) -> void:
	burst(pos, Color(0.85, 0.95, 1.0), n, 9.0, 0.08, 0.45, 14.0, dir + Vector3.UP * 0.5, 0.7, 1.0)
	burst(pos, Color(0.35, 0.65, 1.0), n, 6.0, 0.1, 0.5, 12.0, dir, 0.8, 1.0)

func leaves(pos: Vector3, n := 12) -> void:
	burst(pos, Color(0.3, 0.6, 0.2), n, 4.0, 0.15, 1.6, 2.5, Vector3.ZERO, 1.0, 2.5)

# --- дуги стихий --------------------------------------------------------
# center — центр дуги, basis — плоскость (x/z — плоскость дуги, y — нормаль),
# углы в радианах, kind: 0 срез, 1 волна, 2 кольцо.
func arc(center: Vector3, basis: Basis, radius: float, a0: float, a1: float, width: float,
		col_a: Color, col_b: Color, life := 0.45, kind := 1, grow := 0.0, draw_time := 0.12) -> Node3D:
	var im := ImmediateMesh.new()
	var segs := 40
	im.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	for i in segs + 1:
		var f := float(i) / segs
		var a := lerpf(a0, a1, f)
		var dirv := Vector3(cos(a), 0.0, sin(a))
		var wob := 1.0 + sin(f * 9.0) * 0.06 if kind == 1 else 1.0
		var r_in := (radius - width * 0.5) * wob
		var r_out := (radius + width * 0.5) * wob
		im.surface_set_uv(Vector2(f, 0.0))
		im.surface_add_vertex(dirv * r_in)
		im.surface_set_uv(Vector2(f, 1.0))
		im.surface_add_vertex(dirv * r_out)
	im.surface_end()
	var mi := MeshInstance3D.new()
	mi.mesh = im
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var m := ShaderMaterial.new()
	m.shader = _arc_shader
	m.set_shader_parameter("col_a", col_a)
	m.set_shader_parameter("col_b", col_b)
	m.set_shader_parameter("style", kind)
	m.set_shader_parameter("head", 0.0)
	m.set_shader_parameter("tail", 0.0)
	mi.material_override = m
	add_child(mi)
	mi.global_transform = Transform3D(basis, center)
	arcs.append({"n": mi, "mat": m, "life": 0.0, "max": life, "grow": grow, "draw": draw_time, "kind": kind})
	return mi

# Дуга по направлению удара: forward — куда смотрит герой, roll — наклон плоскости.
func slash_arc(origin: Vector3, forward: Vector3, roll_deg: float, radius: float, sweep_deg: float,
		width: float, col_a: Color, col_b: Color, kind := 1, life := 0.45, reverse := false) -> void:
	var f := Vector3(forward.x, 0, forward.z).normalized()
	if f == Vector3.ZERO:
		f = Vector3.FORWARD
	# базис: x = вправо от героя... строим плоскость с нормалью up, затем наклоняем
	var b := Basis.looking_at(-f, Vector3.UP)   # -z смотрит на -f => +z смотрит вперёд
	b = b * Basis(Vector3.FORWARD, deg_to_rad(roll_deg))
	var mid := PI * 0.5   # в локальных координатах угол PI/2 — это +z (вперёд)
	var half := deg_to_rad(sweep_deg) * 0.5
	var a0 := mid - half
	var a1 := mid + half
	if reverse:
		var tmp := a0
		a0 = a1
		a1 = tmp
	arc(origin, b, radius, a0, a1, width, col_a, col_b, life, kind)

func ring(pos: Vector3, radius: float, col_a: Color, col_b: Color, life := 0.4, grow := 3.0, width := 0.5, up := Vector3.UP) -> void:
	var b := Basis.IDENTITY
	if up != Vector3.UP:
		b = Basis(Quaternion(Vector3.UP, up.normalized()))
	arc(pos, b, radius, 0.0, TAU, width, col_a, col_b, life, 2, grow, 0.0)

# --- остаточный силуэт ---------------------------------------------------
func afterimage(root: Node3D, col: Color, life := 0.28) -> void:
	var holder := Node3D.new()
	add_child(holder)
	var mat := Vox.flat_mat(Color(col.r, col.g, col.b, 0.55), true)
	_copy_meshes(root, holder, mat)
	ghosts.append({"n": holder, "life": life, "max": life})

func _copy_meshes(src: Node, holder: Node3D, mat: Material) -> void:
	for c in src.get_children():
		if c is MeshInstance3D and c.visible and c.mesh is BoxMesh:
			var mi := MeshInstance3D.new()
			mi.mesh = c.mesh
			mi.material_override = mat
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			holder.add_child(mi)
			mi.global_transform = c.global_transform
		if c is Node3D:
			_copy_meshes(c, holder, mat)

# Прямая полоса от a до b (след шага-вспышки).
func streak(a: Vector3, b: Vector3, col: Color, life := 0.3, w := 0.25) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	var len := a.distance_to(b)
	if len < 0.1:
		return
	bm.size = Vector3(w, w * 0.6, len)
	mi.mesh = bm
	mi.material_override = Vox.flat_mat(col)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	mi.global_position = (a + b) * 0.5
	if absf((b - a).normalized().dot(Vector3.UP)) < 0.99:
		mi.look_at(b, Vector3.UP)
	ghosts.append({"n": mi, "life": life, "max": life, "thin": true})

func number(pos: Vector3, txt: String, col := Color.WHITE, big := false) -> void:
	var l := Label3D.new()
	l.text = txt
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.fixed_size = true
	l.pixel_size = 0.0014 if big else 0.001
	l.font_size = 48
	l.outline_size = 14
	l.modulate = col
	l.outline_modulate = Color(0.05, 0.02, 0.05)
	l.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	add_child(l)
	l.global_position = pos + Vector3(randf_range(-0.4, 0.4), randf_range(0.0, 0.4), randf_range(-0.4, 0.4))
	labels.append({"n": l, "life": 0.8, "max": 0.8, "v": Vector3(0, 2.5, 0)})

# --- обломки ------------------------------------------------------------
func debris_burst(pos: Vector3, col: Color, n: int, size: float, push: Vector3, spread := 4.0) -> void:
	for i in n:
		if debris.size() >= MAX_DEBRIS:
			var old: Dictionary = debris.pop_front()
			if is_instance_valid(old.n):
				old.n.queue_free()
		var rb := RigidBody3D.new()
		rb.collision_layer = 8
		rb.collision_mask = 1 | 8
		var s := size * randf_range(0.6, 1.3)
		var cs := CollisionShape3D.new()
		var sh := BoxShape3D.new()
		sh.size = Vector3.ONE * s
		cs.shape = sh
		rb.add_child(cs)
		Vox.box(rb, Vector3.ONE * s, Vector3.ZERO, col.lightened(randf_range(-0.1, 0.1)), true)
		add_child(rb)
		rb.global_position = pos + Vector3(randf_range(-0.4, 0.4), randf_range(0, 0.6), randf_range(-0.4, 0.4))
		rb.linear_velocity = push + Vector3(randf_range(-1, 1), randf_range(0.3, 1.5), randf_range(-1, 1)) * spread
		rb.angular_velocity = Vector3(randf_range(-10, 10), randf_range(-10, 10), randf_range(-10, 10))
		debris.append({"n": rb, "life": randf_range(4.0, 6.0)})

# Добавить готовое тело как обломок (упавшее дерево, отрубленная рука).
func adopt(rb: Node3D, life := 8.0) -> void:
	debris.append({"n": rb, "life": life})

func _process(dt: float) -> void:
	for i in range(parts.size() - 1, -1, -1):
		var p: Dictionary = parts[i]
		p.life -= dt
		if p.life <= 0.0:
			p.n.queue_free()
			parts.remove_at(i)
			continue
		p.v.y -= p.g * dt
		p.v *= maxf(0.0, 1.0 - p.drag * dt)
		var n: MeshInstance3D = p.n
		n.global_position += p.v * dt
		n.rotation += p.spin * dt
		n.scale = Vector3.ONE * p.s0 * clampf(p.life / p.max * 1.5, 0.0, 1.0)
	for i in range(arcs.size() - 1, -1, -1):
		var a: Dictionary = arcs[i]
		a.life += dt
		var k: float = a.life / a.max
		if k >= 1.0:
			a.n.queue_free()
			arcs.remove_at(i)
			continue
		var head := 1.0 if a.draw <= 0.0 else clampf(a.life / a.draw, 0.0, 1.0)
		var tail := clampf((k - 0.35) / 0.65, 0.0, 1.0)
		var m: ShaderMaterial = a.mat
		m.set_shader_parameter("head", Vox.ease_out(head))
		m.set_shader_parameter("tail", tail)
		m.set_shader_parameter("t", a.life)
		if a.kind == 2:
			m.set_shader_parameter("opacity", 1.0 - k)
			a.n.scale = Vector3.ONE * (1.0 + a.grow * Vox.ease_out(k))
		elif a.grow != 0.0:
			a.n.scale = Vector3.ONE * (1.0 + a.grow * k)
	for i in range(ghosts.size() - 1, -1, -1):
		var gh: Dictionary = ghosts[i]
		gh.life -= dt
		if gh.life <= 0.0:
			gh.n.queue_free()
			ghosts.remove_at(i)
			continue
		var f: float = gh.life / gh.max
		if gh.has("thin"):
			gh.n.scale = Vector3(f, f, 1.0)
		else:
			gh.n.scale = Vector3.ONE * (0.9 + 0.1 * f)
	for i in range(labels.size() - 1, -1, -1):
		var l: Dictionary = labels[i]
		l.life -= G.rdt
		if l.life <= 0.0:
			l.n.queue_free()
			labels.remove_at(i)
			continue
		l.n.global_position += l.v * G.rdt
		l.v *= 0.9
		l.n.modulate.a = clampf(l.life / l.max * 2.0, 0.0, 1.0)
		l.n.outline_modulate.a = l.n.modulate.a
	for i in range(debris.size() - 1, -1, -1):
		var d: Dictionary = debris[i]
		if not is_instance_valid(d.n):
			debris.remove_at(i)
			continue
		d.life -= dt
		if d.life <= 0.0:
			d.n.queue_free()
			debris.remove_at(i)
		elif d.life < 0.6:
			var s := Vector3.ONE * maxf(0.05, d.life / 0.6)
			for c in d.n.get_children():
				if c is MeshInstance3D or (c is Node3D and not c is CollisionShape3D):
					c.scale = s
