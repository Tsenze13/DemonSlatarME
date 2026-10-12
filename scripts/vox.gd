extends RefCounted
# Строительные блоки: блоки с аниме-светом и контуром.

static var _cel: Shader
static var _outline: Shader
static var _cache := {}
static var _unshaded := {}

static func cel_mat(col: Color, outline := true, emission := 0.0, ow := 0.022) -> ShaderMaterial:
	var key := "%s|%s|%.2f|%.3f" % [col.to_html(), outline, emission, ow]
	if _cache.has(key):
		return _cache[key]
	if _cel == null:
		_cel = load("res://shaders/cel.gdshader")
		_outline = load("res://shaders/outline.gdshader")
	var m := ShaderMaterial.new()
	m.shader = _cel
	m.set_shader_parameter("albedo", col)
	m.set_shader_parameter("emission", emission)
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

static func box(parent: Node, size: Vector3, pos: Vector3, col: Color, outline := true, emission := 0.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = cel_mat(col, outline, emission)
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
static func solid(parent: Node, size: Vector3, pos: Vector3, col: Color, outline := true, layer := 1) -> StaticBody3D:
	var sb := StaticBody3D.new()
	sb.collision_layer = layer
	sb.collision_mask = 0
	sb.position = pos
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = size
	cs.shape = sh
	sb.add_child(cs)
	box(sb, size, Vector3.ZERO, col, outline)
	parent.add_child(sb)
	return sb

static func ease_out(x: float) -> float:
	x = clampf(x, 0.0, 1.0)
	return 1.0 - (1.0 - x) * (1.0 - x) * (1.0 - x)

static func ease_in_out(x: float) -> float:
	x = clampf(x, 0.0, 1.0)
	return x * x * (3.0 - 2.0 * x)
