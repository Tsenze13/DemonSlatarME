extends RefCounted
# Строительные блоки: блоки с аниме-светом и контуром.

static var _cel: Shader
static var _outline: Shader
static var _cache := {}
static var _unshaded := {}

const Tex = preload("res://scripts/tex.gd")

# tex: вид пиксельной текстуры ("" — без неё), tex_local — текстура едет вместе с объектом.
static func cel_mat(col: Color, outline := true, emission := 0.0, ow := 0.022, tex := "", tex_local := false) -> ShaderMaterial:
	var key := "%s|%s|%.2f|%.3f|%s|%s" % [col.to_html(), outline, emission, ow, tex, tex_local]
	if _cache.has(key):
		return _cache[key]
	if _cel == null:
		_cel = load("res://shaders/cel.gdshader")
		_outline = load("res://shaders/outline.gdshader")
	var m := ShaderMaterial.new()
	m.shader = _cel
	m.set_shader_parameter("albedo", col)
	m.set_shader_parameter("emission", emission)
	if tex != "":
		m.set_shader_parameter("tex", Tex.get_tex(tex))
		m.set_shader_parameter("use_tex", true)
		m.set_shader_parameter("tex_local", tex_local)
	if outline:
		var o := ShaderMaterial.new()
		o.shader = _outline
		o.set_shader_parameter("color", Color(col.r * 0.18, col.g * 0.14, col.b * 0.2))
		o.set_shader_parameter("width", ow)
		m.next_pass = o
	_cache[key] = m
	return m

static func flat_mat(col: Color, alpha := false) -> StandardMaterial3D:
	var key := "%s|%s" % [col.to_html(), alpha]
	if _unshaded.has(key):
		return _unshaded[key]
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = col
	if alpha:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	_unshaded[key] = m
	return m

static func box(parent: Node, size: Vector3, pos: Vector3, col: Color, outline := true, emission := 0.0, tex := "", tex_local := false) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = cel_mat(col, outline, emission, 0.022, tex, tex_local)
	mi.position = pos
	parent.add_child(mi)
	return mi

static func pivot(parent: Node, pos: Vector3, nm := "") -> Node3D:
	var n := Node3D.new()
	if nm != "":
		n.name = nm
	n.position = pos
	parent.add_child(n)
	return n

# Статичный блок с коллизией (для мира).
static func solid(parent: Node, size: Vector3, pos: Vector3, col: Color, outline := true, layer := 1, tex := "") -> StaticBody3D:
	var sb := StaticBody3D.new()
	sb.collision_layer = layer
	sb.collision_mask = 0
	sb.position = pos
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = size
	cs.shape = sh
	sb.add_child(cs)
	box(sb, size, Vector3.ZERO, col, outline, 0.0, tex)
	parent.add_child(sb)
	return sb

static func ease_out(x: float) -> float:
	x = clampf(x, 0.0, 1.0)
	return 1.0 - (1.0 - x) * (1.0 - x) * (1.0 - x)

static func ease_in_out(x: float) -> float:
	x = clampf(x, 0.0, 1.0)
	return x * x * (3.0 - 2.0 * x)

# --- Запекание статичных блоков ----------------------------------------------
# Тысячи отдельных блоков мира (каждый — свой вызов отрисовки, а с контуром — два)
# объединяются в несколько больших мешей: по материалу и по клеткам 32 м
# (чтобы невидимое за камерой отсекалось). Контур строится отдельным мешем
# из увеличенных копий блоков. Блоки с коллизией остаются — меняется только вид.
static var _baked := {}          # исходный материал → копия без контура
static var _vc_mat: ShaderMaterial
static var _copies := {}         # общие копии материалов для запекания (по «виду»)

static func baked_copy(m: Material) -> Material:
	return _baked.get(m, null)

# Задать параметр материалу и его запечённой копии.
static func mat_set(m: ShaderMaterial, param: String, v) -> void:
	m.set_shader_parameter(param, v)
	var c = _baked.get(m, null)
	if c:
		c.set_shader_parameter(param, v)

static func bake(root: Node3D, can_bake: Callable, chunk := 32.0) -> int:
	if _vc_mat == null:
		_vc_mat = ShaderMaterial.new()
		_vc_mat.shader = load("res://shaders/outline_vc.gdshader")
	var groups := {}            # ключ → [SurfaceTool, материал]
	var outl := {}              # клетка → SurfaceTool
	var inv := root.global_transform.affine_inverse()
	var n := 0
	for mi in root.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		if not (m.mesh is BoxMesh) or not m.visible or not can_bake.call(m):
			continue
		var mat := m.material_override
		if mat == null:
			continue
		var xf: Transform3D = inv * m.global_transform
		var cell := Vector2i(floori(xf.origin.x / chunk), floori(xf.origin.z / chunk)) if chunk < 500.0 else Vector2i.ZERO
		# блоки с одинаковым «видом» (текстура, свечение) — в один меш, цвет — в вершинах
		var sm := mat as ShaderMaterial
		var vcol: bool = sm != null and sm.shader == _cel
		var key: Array
		var col := Color.WHITE
		if vcol:
			var tx = sm.get_shader_parameter("tex")
			key = ["v", tx.get_instance_id() if tx else 0, sm.get_shader_parameter("emission"), sm.get_shader_parameter("shade_floor"), sm.get_shader_parameter("tex_local"), cell]
			col = sm.get_shader_parameter("albedo")
		else:
			key = [mat.get_instance_id(), cell]
		var ks := str(key)
		if not groups.has(ks):
			var st := SurfaceTool.new()
			st.begin(Mesh.PRIMITIVE_TRIANGLES)
			var bm: Material = mat
			var ck := str(key.slice(0, key.size() - 1))
			if _copies.has(ck):
				bm = _copies[ck]
			elif vcol:
				var cp: ShaderMaterial = sm.duplicate()
				cp.next_pass = null
				cp.set_shader_parameter("albedo", Color.WHITE)
				cp.set_shader_parameter("use_vcol", true)
				bm = cp
				_copies[ck] = bm
			elif mat is ShaderMaterial and mat.next_pass != null:
				var cp2: ShaderMaterial = mat.duplicate()
				cp2.next_pass = null
				bm = cp2
				_copies[ck] = bm
			groups[ks] = [st, bm]
		var g: Array = groups[ks]
		_baked[mat] = g[1]
		if vcol:
			_box_into(g[0], (m.mesh as BoxMesh).size, xf, col)
		else:
			(g[0] as SurfaceTool).append_from(m.mesh, 0, xf)
		# контур
		if mat is ShaderMaterial and mat.next_pass is ShaderMaterial:
			var op: ShaderMaterial = mat.next_pass
			var w: float = op.get_shader_parameter("width") if op.get_shader_parameter("width") != null else 0.022
			var oc: Color = op.get_shader_parameter("color") if op.get_shader_parameter("color") != null else Color(0.04, 0.03, 0.05)
			if not outl.has(cell):
				var so := SurfaceTool.new()
				so.begin(Mesh.PRIMITIVE_TRIANGLES)
				outl[cell] = so
			_box_into(outl[cell], (m.mesh as BoxMesh).size + Vector3.ONE * w * 2.0, xf, oc)
		m.queue_free()
		n += 1
	for key in groups:
		var g: Array = groups[key]
		var mi2 := MeshInstance3D.new()
		mi2.mesh = (g[0] as SurfaceTool).commit()
		mi2.material_override = g[1]
		root.add_child(mi2)
	for cell in outl:
		var mo := MeshInstance3D.new()
		mo.mesh = (outl[cell] as SurfaceTool).commit()
		mo.material_override = _vc_mat
		mo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(mo)
	return n

static func _box_into(st: SurfaceTool, size: Vector3, xf: Transform3D, col: Color) -> void:
	var h := size * 0.5
	var faces := [
		[Vector3(1, 0, 0), Vector3(0, 1, 0), Vector3(0, 0, 1)],
		[Vector3(-1, 0, 0), Vector3(0, 1, 0), Vector3(0, 0, -1)],
		[Vector3(0, 1, 0), Vector3(0, 0, 1), Vector3(1, 0, 0)],
		[Vector3(0, -1, 0), Vector3(0, 0, -1), Vector3(1, 0, 0)],
		[Vector3(0, 0, 1), Vector3(1, 0, 0), Vector3(0, 1, 0)],
		[Vector3(0, 0, -1), Vector3(-1, 0, 0), Vector3(0, 1, 0)],
	]
	for f in faces:
		var nrm: Vector3 = f[0]
		var u: Vector3 = f[1]
		var v: Vector3 = f[2]
		var c := nrm * h
		var du := u * h
		var dv := v * h
		var p := [c - du - dv, c + du - dv, c + du + dv, c - du + dv]
		var wn: Vector3 = (xf.basis * nrm).normalized()
		for idx in [0, 2, 1, 0, 3, 2]:
			st.set_color(col)
			st.set_normal(wn)
			st.add_vertex(xf * (p[idx] as Vector3))
