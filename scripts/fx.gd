extends Node3D
# Все визуальные эффекты: частицы, дуги стихий, кольца, остаточные
# силуэты, цифры урона, обломки.

const Vox = preload("res://scripts/vox.gd")

var parts: Array = []        # частицы: {n, v, life, max, g, drag, s0, spin}
var arcs: Array = []         # дуги: {n, mat, life, max, grow, kind}
var ghosts: Array = []
var tigers: Array = []
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
		life := 0.5, grav := 9.0, dir := Vector3.ZERO, spread := 1.0, drag := 2.0, stretch := 0.0) -> void:
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
		parts.append({"n": mi, "v": v, "life": l, "max": l, "g": grav, "drag": drag, "s0": s, "st": stretch,
			"spin": Vector3(randf_range(-9, 9), randf_range(-9, 9), randf_range(-9, 9))})

func sparks(pos: Vector3, dir: Vector3, col := Color(1.0, 0.95, 0.7), n := 14) -> void:
	burst(pos, col, n, 14.0, 0.07, 0.25, 12.0, dir, 0.7, 4.0, 0.09)
	burst(pos, Color.WHITE, n / 2, 9.0, 0.11, 0.15, 0.0, dir, 0.9, 6.0, 0.06)

func blood(pos: Vector3, dir: Vector3, n := 12) -> void:
	# брызги крови вытянуты по полёту, как мазки туши
	burst(pos, Color(0.45, 0.02, 0.1), n, 8.0, 0.12, 0.6, 16.0, dir + Vector3.UP * 0.4, 0.6, 1.5, 0.12)
	burst(pos, Color(0.75, 0.05, 0.15), n / 2, 11.0, 0.07, 0.4, 16.0, dir, 0.5, 1.5, 0.1)

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
	# полупрозрачный силуэт, тает к концу жизни
	var mat: StandardMaterial3D = Vox.flat_mat(Color(col.r, col.g, col.b, 0.4), true).duplicate()
	_copy_meshes(root, holder, mat)
	ghosts.append({"n": holder, "life": life, "max": life, "mat": mat})

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

# Вспышка разреза как в аниме: длинная белая линия поперёк цели по плоскости удара
# и цветной ореол вокруг неё, тут же истончаются.
func cut_flash(p: Vector3, line_dir: Vector3, col: Color, length := 1.5) -> void:
	var d := line_dir.normalized()
	streak(p - d * length, p + d * length, col, 0.2, 0.2)
	streak(p - d * length * 1.15, p + d * length * 1.15, Color(1, 1, 1), 0.14, 0.07)

# Трещины в земле от сильного удара: тёмные лучи, медленно тают.
func cracks(p: Vector3, n := 7, length := 1.8) -> void:
	var g := Vector3(p.x, 0.03, p.z)
	for i in n:
		var a := TAU * float(i) / n + randf_range(-0.3, 0.3)
		var d := Vector3(cos(a), 0, sin(a))
		var mid := g + d * length * randf_range(0.4, 0.6) + d.cross(Vector3.UP) * randf_range(-0.2, 0.2)
		var end := g + d * length * randf_range(0.8, 1.2)
		streak(g, mid, Color(0.12, 0.1, 0.1), 2.5, 0.09)
		streak(mid, end, Color(0.12, 0.1, 0.1), 2.5, 0.06)

# Звезда удара: тонкие лучи во все стороны из точки попадания.
func hit_star(p: Vector3, col: Color, n := 7, size := 0.9) -> void:
	for i in n:
		var d := Vector3(randf_range(-1, 1), randf_range(-0.6, 1), randf_range(-1, 1)).normalized()
		streak(p, p + d * size * randf_range(0.5, 1.1), Color(1, 1, 1) if i % 2 == 0 else col, 0.1, 0.05)

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

# --- молнии -----------------------------------------------------------
var bolts: Array = []

# Молния из a в b: ломаная с отростками, золотая с белой сердцевиной, мерцает.
func lightning(a: Vector3, b: Vector3, col := Color(1.0, 0.8, 0.15), life := 0.25, jag := 0.35, branches := 2, width := 0.07) -> void:
	var holder := Node3D.new()
	add_child(holder)
	_bolt_path(holder, a, b, col, jag, width)
	for k in branches:
		var f := randf_range(0.25, 0.75)
		var p := a.lerp(b, f)
		var dirv := (b - a).normalized()
		var side := dirv.cross(Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1))).normalized()
		_bolt_path(holder, p, p + (dirv * 0.6 + side) * a.distance_to(b) * randf_range(0.15, 0.3), col, jag * 0.6, width * 0.6)
	bolts.append({"n": holder, "life": life})

func _bolt_path(holder: Node3D, a: Vector3, b: Vector3, col: Color, jag: float, width: float) -> void:
	var n := maxi(3, int(a.distance_to(b) / 0.35))
	var dirv := (b - a).normalized()
	var s1 := dirv.cross(Vector3.UP)
	if s1.length() < 0.1:
		s1 = dirv.cross(Vector3.RIGHT)
	s1 = s1.normalized()
	var s2 := dirv.cross(s1).normalized()
	var prev := a
	for i in range(1, n + 1):
		var f := float(i) / n
		var p := a.lerp(b, f)
		if i < n:
			p += (s1 * randf_range(-1, 1) + s2 * randf_range(-1, 1)) * jag
		for layer in 2:
			var mi := MeshInstance3D.new()
			var bm := BoxMesh.new()
			var w := width * (1.0 if layer == 0 else 0.4)
			bm.size = Vector3(w, w, prev.distance_to(p) + w)
			mi.mesh = bm
			mi.material_override = Vox.flat_mat(col if layer == 0 else Color(1, 1, 0.95))
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			holder.add_child(mi)
			var z := (p - prev).normalized()
			var up := Vector3.UP if absf(z.dot(Vector3.UP)) < 0.95 else Vector3.RIGHT
			mi.global_transform = Transform3D(Basis.looking_at(z, up), (prev + p) * 0.5)
		prev = p

# Искры огня — поднимаются вверх и гаснут.
func embers(pos: Vector3, n := 12, spread := 1.0) -> void:
	burst(pos, Color(1.0, 0.55, 0.1), n, 4.0 * spread, 0.09, 0.8, -6.0, Vector3.UP, 0.8, 1.5)
	burst(pos, Color(1.0, 0.9, 0.4), n / 2, 3.0 * spread, 0.06, 0.6, -8.0, Vector3.UP, 0.7, 1.5)

# --- эффекты стиля дыхания ---------------------------------------------
func breath_arc(origin: Vector3, forward: Vector3, roll_deg: float, radius: float, sweep_deg: float,
		width: float, life := 0.45, reverse := false) -> void:
	var b: Dictionary = G.br()
	slash_arc(origin, forward, roll_deg, radius, sweep_deg, width, b.a, b.b, b.kind, life, reverse)

func breath_ring_arc(center: Vector3, basis: Basis, radius: float, a0: float, a1: float, width: float, life := 0.45, grow := 0.0, draw_time := 0.12) -> void:
	var b: Dictionary = G.br()
	arc(center, basis, radius, a0, a1, width, b.a, b.b, life, b.kind, grow, draw_time)

# Брызги стиля: вода — капли, пламя — искры, гром — разряды.
func breath_burst(pos: Vector3, dir: Vector3, n := 10) -> void:
	match G.fx_style():
		"flame":
			embers(pos, n, 1.2)
		"thunder":
			sparks(pos, dir, Color(1.0, 0.85, 0.3), n)
			for k in 2:
				var d := (dir + Vector3(randf_range(-1, 1), randf_range(-0.3, 1), randf_range(-1, 1))).normalized()
				lightning(pos, pos + d * randf_range(1.0, 2.0), Color(1.0, 0.8, 0.15), 0.15, 0.25, 0, 0.05)
		"water":
			droplets(pos, dir, n)
		_:
			family_burst(G.fx_style(), pos, dir, n)

# Частицы стиля для остальных дыханий: у каждого своё «вещество» стихии.
func family_burst(fam: String, pos: Vector3, dir: Vector3, n := 10) -> void:
	var b: Dictionary = G.br()
	match fam:
		"wind":
			# листья и порывы: зелёные пластинки летят вбок, вытягиваются по ветру
			burst(pos, Color(0.45, 0.8, 0.4), n, 7.0, 0.07, 0.6, 1.0, dir + Vector3.UP * 0.2, 0.9, 1.5, 0.6)
			burst(pos, Color(0.92, 1.0, 0.94), n / 2, 9.0, 0.05, 0.4, 0.0, dir, 0.6, 1.0, 1.0)
		"stone":
			debris_burst(pos, Color(0.5, 0.47, 0.44), maxi(2, n / 3), 0.22, dir * 3.0 + Vector3.UP * 2.0, 2.5)
			dust(pos, n, Color(0.7, 0.66, 0.6))
		"mist":
			burst(pos, Color(0.92, 0.95, 1.0), n, 1.5, 0.35, 0.9, -0.5, dir, 1.0, 3.0)
		"flower", "love":
			# лепестки: медленно кружатся и опадают
			var pc := Color(1.0, 0.7, 0.82) if fam == "flower" else Color(1.0, 0.55, 0.75)
			burst(pos, pc, n, 3.0, 0.07, 1.2, 1.5, dir + Vector3.UP * 0.6, 1.0, 3.0)
			burst(pos, Color(1.0, 0.95, 0.97), n / 3, 2.5, 0.05, 1.0, 1.5, Vector3.UP, 1.0, 3.0)
		"insect":
			# бабочки: фиолетовые пары крылышек вспархивают вверх
			burst(pos, Color(0.65, 0.45, 1.0), n, 2.5, 0.08, 1.1, -1.5, Vector3.UP + dir * 0.4, 1.0, 2.5)
			burst(pos, Color(0.85, 0.95, 1.0), n / 2, 2.0, 0.05, 0.9, -1.0, Vector3.UP, 1.0, 2.5)
		"serpent":
			burst(pos, b.a, n, 5.0, 0.08, 0.6, 0.0, dir, 0.5, 2.0, 0.8)
		"sound":
			# звук: искры-взрывы и кольцо ударной волны
			sparks(pos, dir, Color(1.0, 0.75, 0.3), n)
			ring(pos, 0.3, b.a, b.b, 0.25, 4.0, 0.2, dir)
		"beast":
			burst(pos, Color(0.75, 0.8, 0.9), n, 8.0, 0.06, 0.35, 4.0, dir, 1.0, 2.0, 0.8)
			dust(pos, n / 2)
		"moon":
			# луна: маленькие полумесяцы разлетаются от удара
			for k in maxi(2, n / 4):
				var d2 := (dir + Vector3(randf_range(-1, 1), randf_range(-0.4, 0.8), randf_range(-1, 1))).normalized()
				var bs := Basis(Quaternion(Vector3.UP, d2)) * Basis(Vector3.UP, randf() * TAU)
				arc(pos + d2 * randf_range(0.5, 2.0), bs, randf_range(0.3, 0.7), 0.0, PI * 1.1, 0.1, b.a, b.b, 0.5, 0)
			burst(pos, b.a, n / 2, 3.0, 0.06, 0.6, 0.0, dir, 1.0, 2.0)
		_:
			droplets(pos, dir, n)

func breath_sound(vol := 0.0, pitch := 1.0) -> void:
	match G.fx_style():
		"flame":
			G.sfx.play("fire", vol, pitch)
		"thunder":
			G.sfx.play("thunder", vol, pitch)
		"wind", "beast", "insect":
			G.sfx.play("whoosh_big", vol, pitch * 1.2)
		"stone":
			G.sfx.play("stone", vol, pitch * 0.8)
			G.sfx.play("boom", vol - 6.0, pitch)
		"mist", "moon", "serpent":
			G.sfx.play("whoosh_big", vol - 2.0, pitch * 0.75)
		"flower", "love":
			G.sfx.play("shing", vol - 4.0, pitch * 1.3)
		"sound":
			G.sfx.play("boom", vol, pitch * 1.2)
			G.sfx.play("clang", vol - 6.0, pitch * 1.4)
		_:
			G.sfx.play("water", vol, pitch)

# Огненный тигр (как у мастера пламени): голова зверя из пламени-блоков
# с раскрытой пастью летит вперёд по линии удара, растёт, оставляет огонь и гаснет.
func _fire_mat(c: Color, a: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.no_depth_test = false
	m.albedo_color = Color(c.r, c.g, c.b, a)
	return m

# Пламенный тигр: голова-призрак из огня (слои светящихся блоков без контура,
# складываются светом), пасть кусает, грива — языки пламени, всё дрожит как огонь.
func flame_tiger(pos: Vector3, dir: Vector3, dist := 9.0, life := 0.6) -> void:
	var root := Node3D.new()
	add_child(root)
	var d := Vector3(dir.x, 0, dir.z).normalized()
	root.global_position = pos
	root.look_at(pos + d, Vector3.UP)
	var org := Color(1.0, 0.42, 0.06)
	var yel := Color(1.0, 0.85, 0.35)
	var red := Color(0.9, 0.12, 0.02)
	var wht := Color(1.0, 0.97, 0.85)
	var parts_ := [
		# [размер, позиция (−z — вперёд), цвет, прозрачность, роль]
		[Vector3(1.9, 1.4, 1.7), Vector3(0, 0.25, 0.4), red, 0.45, ""],         # череп (внешний слой)
		[Vector3(1.4, 1.0, 1.3), Vector3(0, 0.25, 0.3), org, 0.6, ""],          # череп (ядро)
		[Vector3(1.3, 0.5, 1.3), Vector3(0, 0.45, -0.9), yel, 0.7, "up"],       # верхняя челюсть-морда
		[Vector3(0.6, 0.3, 0.4), Vector3(0, 0.55, -1.45), wht, 0.8, "up"],      # нос
		[Vector3(1.1, 0.35, 1.1), Vector3(0, -0.45, -0.75), org, 0.65, "jaw"],  # нижняя челюсть
		[Vector3(0.2, 0.42, 0.18), Vector3(-0.4, 0.05, -1.4), wht, 1.0, "up"],  # клыки
		[Vector3(0.2, 0.42, 0.18), Vector3(0.4, 0.05, -1.4), wht, 1.0, "up"],
		[Vector3(0.16, 0.3, 0.16), Vector3(-0.32, -0.15, -1.2), wht, 1.0, "jaw"],
		[Vector3(0.16, 0.3, 0.16), Vector3(0.32, -0.15, -1.2), wht, 1.0, "jaw"],
		[Vector3(0.5, 0.14, 0.1), Vector3(-0.45, 0.72, -0.55), wht, 1.0, "eye"], # глаза — белое пламя
		[Vector3(0.5, 0.14, 0.1), Vector3(0.45, 0.72, -0.55), wht, 1.0, "eye"],
		[Vector3(0.4, 0.55, 0.3), Vector3(-0.72, 1.1, 0.5), red, 0.7, "ear"],   # уши
		[Vector3(0.4, 0.55, 0.3), Vector3(0.72, 1.1, 0.5), red, 0.7, "ear"],
		[Vector3(0.1, 0.18, 1.0), Vector3(-0.96, 0.5, 0.3), red, 0.9, ""],     # полосы тигра
		[Vector3(0.1, 0.18, 1.0), Vector3(0.96, 0.5, 0.3), red, 0.9, ""],
		[Vector3(0.1, 0.18, 0.8), Vector3(-0.96, 0.05, 0.4), red, 0.9, ""],
		[Vector3(0.1, 0.18, 0.8), Vector3(0.96, 0.05, 0.4), red, 0.9, ""],
	]
	var nodes: Array = []
	for pr in parts_:
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = pr[0]
		mi.mesh = bm
		mi.material_override = _fire_mat(pr[2], pr[3])
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.position = pr[1]
		root.add_child(mi)
		nodes.append({"n": mi, "p": pr[1], "role": pr[4], "a": pr[3]})
	# грива и хвост — языки пламени назад и вверх, каждый дрожит сам
	for k in 14:
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		var ln := randf_range(0.8, 1.8)
		bm.size = Vector3(randf_range(0.3, 0.55), randf_range(0.3, 0.55), ln)
		mi.mesh = bm
		var a := randf_range(-PI * 0.9, PI * 0.9)
		var c: Color = [red, org, yel][k % 3]
		mi.material_override = _fire_mat(c, 0.55)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var p0 := Vector3(sin(a) * 0.9, cos(a) * 0.75 + 0.3, 0.9 + ln * 0.5)
		mi.position = p0
		mi.rotation = Vector3(-cos(a) * 0.5, sin(a) * 0.5, 0)
		root.add_child(mi)
		nodes.append({"n": mi, "p": p0, "role": "mane", "a": 0.55, "ph": randf() * TAU})
	var lt := OmniLight3D.new()
	lt.light_color = Color(1.0, 0.55, 0.2)
	lt.light_energy = 3.0
	lt.omni_range = 7.0
	lt.shadow_enabled = false
	root.add_child(lt)
	tigers.append({"n": root, "life": 0.0, "max": life, "from": pos, "dir": d, "dist": dist, "parts": nodes})

func _process(dt: float) -> void:
	for i in range(tigers.size() - 1, -1, -1):
		var tg: Dictionary = tigers[i]
		tg.life += dt
		var k: float = tg.life / tg.max
		if k >= 1.0:
			tg.n.queue_free()
			tigers.remove_at(i)
			continue
		var pos: Vector3 = tg.from + tg.dir * tg.dist * Vox.ease_out(k)
		tg.n.global_position = pos + Vector3.UP * sin(k * PI) * 0.4
		var sc := lerpf(0.6, 1.5, Vox.ease_out(k))
		tg.n.scale = Vector3.ONE * sc * (1.0 + sin(tg.life * 60.0) * 0.04)
		# пасть: раскрыта в броске, щёлкает в конце; к концу тигр тает
		var bite: float = 1.0 - smoothstep(0.55, 0.75, k)
		var fade: float = 1.0 - smoothstep(0.7, 1.0, k)
		for pt in tg.parts:
			var mi: MeshInstance3D = pt.n
			var p0: Vector3 = pt.p
			match pt.role:
				"jaw":
					mi.position = p0 + Vector3(0, -0.35 * bite, 0.1 * bite)
					mi.rotation.x = 0.45 * bite
				"up":
					mi.position = p0 + Vector3(0, 0.12 * bite, 0)
					mi.rotation.x = -0.15 * bite
				"mane":
					var fl: float = 1.0 + sin(tg.life * 30.0 + pt.ph) * 0.25 + randf() * 0.15
					mi.scale = Vector3(1.0, 1.0, fl)
					mi.position = p0 + Vector3(0, 0, (fl - 1.0) * 0.5)
				"ear":
					mi.scale.y = 1.0 + sin(tg.life * 25.0) * 0.15
			var m: StandardMaterial3D = mi.material_override
			m.albedo_color.a = pt.a * fade * (0.85 + randf() * 0.15)
		if randf() < 0.8:
			burst(pos + Vector3(randf_range(-0.8, 0.8), randf_range(-0.2, 1.0), randf_range(-0.8, 0.8)), Color(1.0, 0.5, 0.1) if randf() < 0.5 else Color(1.0, 0.85, 0.3), 2, 3.0, 0.3, 0.4, -4.0, Vector3.UP, 0.3, 2.0)
	for i in range(bolts.size() - 1, -1, -1):
		var bo: Dictionary = bolts[i]
		bo.life -= dt
		if bo.life <= 0.0:
			bo.n.queue_free()
			bolts.remove_at(i)
		else:
			bo.n.visible = randf() > 0.3
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
		var k: float = p.s0 * clampf(p.life / p.max * 1.5, 0.0, 1.0)
		var vl: float = p.v.length()
		if p.st > 0.0 and vl > 0.5:
			# капля вытянута по направлению полёта
			var z: Vector3 = p.v / vl
			var up := Vector3.UP if absf(z.dot(Vector3.UP)) < 0.95 else Vector3.RIGHT
			n.global_transform.basis = Basis.looking_at(z, up).scaled(Vector3(k, k, k * (1.0 + vl * p.st * 3.0)))
		else:
			n.rotation += p.spin * dt
			n.scale = Vector3.ONE * k
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
		if gh.has("mat"):
			var gm: StandardMaterial3D = gh.mat
			gm.albedo_color.a = 0.4 * f
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
