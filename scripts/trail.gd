extends MeshInstance3D
# Мазок за клинком: запоминаем положения рукояти и острия, строим ленту.

var samples: Array = []   # [base, tip, age]
var life := 0.16
var extend := 0.0          # лента стихии выходит за острие (доля длины клинка)
var emitting := false
var im := ImmediateMesh.new()
var mat: ShaderMaterial

func _ready() -> void:
	top_level = true
	mesh = im
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mat = ShaderMaterial.new()
	mat.shader = load("res://shaders/trail.gdshader")
	material_override = mat
	global_transform = Transform3D.IDENTITY

func set_colors(core: Color, edge: Color) -> void:
	mat.set_shader_parameter("col_core", core)
	mat.set_shader_parameter("col_edge", edge)

# Вид мазка по стилю дыхания: kind 1 вода, 3 пламя, 4 молния (0 — простой срез).
func set_style(kind: int, a: Color, b: Color) -> void:
	mat.set_shader_parameter("style", kind)
	mat.set_shader_parameter("col_a", a)
	mat.set_shader_parameter("col_b", b)
	match kind:
		1:
			life = 0.34
			extend = 0.7
		3:
			life = 0.3
			extend = 0.6
		4:
			life = 0.2
			extend = 0.35
		_:
			life = 0.16
			extend = 0.0

func push(base: Vector3, tip: Vector3) -> void:
	if emitting:
		samples.push_front([base, tip + (tip - base) * extend, 0.0])
		if samples.size() > 60:
			samples.pop_back()

func _catmull(p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3, t: float) -> Vector3:
	var t2 := t * t
	var t3 := t2 * t
	return 0.5 * ((2.0 * p1) + (-p0 + p2) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2 + (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3)

func _process(dt: float) -> void:
	for s in samples:
		s[2] += dt
	while samples.size() > 0 and samples[samples.size() - 1][2] > life:
		samples.pop_back()
	im.clear_surfaces()
	var n := samples.size()
	if n < 2:
		return
	global_transform = Transform3D.IDENTITY
	im.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	var sub := 4
	for i in n - 1:
		var i0: int = maxi(i - 1, 0)
		var i3: int = mini(i + 2, n - 1)
		for k in sub:
			var t := float(k) / sub
			var b := _catmull(samples[i0][0], samples[i][0], samples[i + 1][0], samples[i3][0], t)
			var tp := _catmull(samples[i0][1], samples[i][1], samples[i + 1][1], samples[i3][1], t)
			var age: float = lerpf(samples[i][2], samples[i + 1][2], t) / life
			im.surface_set_uv(Vector2(age, 0.0))
			im.surface_add_vertex(b)
			im.surface_set_uv(Vector2(age, 1.0))
			im.surface_add_vertex(tp)
	var last: Array = samples[n - 1]
	im.surface_set_uv(Vector2(last[2] / life, 0.0))
	im.surface_add_vertex(last[0])
	im.surface_set_uv(Vector2(last[2] / life, 1.0))
	im.surface_add_vertex(last[1])
	im.surface_end()
