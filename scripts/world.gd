extends Node3D
# Арена: поляна для боя, лес и бамбук для прыжков, деревня с домами
# для бега по стенам, длинная каменная стена, разрушаемые заборы и фонари.

const Vox = preload("res://scripts/vox.gd")
const Breakable = preload("res://scripts/breakable.gd")
const TreeS = preload("res://scripts/tree.gd")

var env: Environment
var sun: DirectionalLight3D
var sky_mat: ProceduralSkyMaterial
var night := true
var lantern_lights: Array = []
var grass_mat: ShaderMaterial
var grass_mm: MultiMesh
var moon: MeshInstance3D
var rng := RandomNumberGenerator.new()

func build() -> void:
	rng.seed = 7
	_environment()
	_ground()
	_grass()
	_forest()
	_bamboo()
	_village()
	_stone_wall()
	_shrine()
	_props()
	set_night(true)

func _environment() -> void:
	var we := WorldEnvironment.new()
	env = Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	sky_mat = ProceduralSkyMaterial.new()
	sky.sky_material = sky_mat
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_DEPTH
	env.fog_depth_begin = 30.0
	env.fog_depth_end = 140.0
	we.environment = env
	add_child(we)
	sun = DirectionalLight3D.new()
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 60.0
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	add_child(sun)
	moon = MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 9.0
	sm.height = 18.0
	sm.radial_segments = 12
	sm.rings = 6
	moon.mesh = sm
	var mm := StandardMaterial3D.new()
	mm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mm.albedo_color = Color(1.0, 0.96, 0.82)
	mm.set("disable_fog", true)
	moon.material_override = mm
	moon.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	moon.position = Vector3(-90, 110, -160)
	add_child(moon)

# Качество из настроек: тени (0 — нет, 1 — простые, 2 — чёткие) и густота травы.
func set_quality(shadows: int, grass: float) -> void:
	if sun:
		sun.shadow_enabled = shadows > 0
		sun.directional_shadow_max_distance = 40.0 if shadows == 1 else 60.0
		RenderingServer.directional_shadow_atlas_set_size(2048 if shadows == 1 else 4096, true)
	if grass_mm:
		grass_mm.visible_instance_count = int(grass_mm.instance_count * clampf(grass, 0.0, 1.0))

func set_night(on: bool) -> void:
	night = on
	if on:
		sky_mat.sky_top_color = Color(0.03, 0.04, 0.12)
		sky_mat.sky_horizon_color = Color(0.16, 0.16, 0.32)
		sky_mat.ground_horizon_color = Color(0.1, 0.1, 0.2)
		sky_mat.ground_bottom_color = Color(0.03, 0.03, 0.06)
		sky_mat.sun_angle_max = 0.0
		env.ambient_light_color = Color(0.36, 0.42, 0.72)
		env.ambient_light_energy = 0.75
		env.fog_light_color = Color(0.12, 0.13, 0.27)
		sun.light_color = Color(0.7, 0.8, 1.0)
		sun.light_energy = 1.0
		sun.rotation_degrees = Vector3(-48, -35, 0)
		moon.visible = true
		for l in lantern_lights:
			if is_instance_valid(l):
				l.visible = true
	else:
		sky_mat.sky_top_color = Color(0.25, 0.48, 0.85)
		sky_mat.sky_horizon_color = Color(0.72, 0.82, 0.92)
		sky_mat.ground_horizon_color = Color(0.6, 0.7, 0.75)
		sky_mat.ground_bottom_color = Color(0.3, 0.35, 0.3)
		env.ambient_light_color = Color(0.6, 0.66, 0.78)
		env.ambient_light_energy = 0.7
		env.fog_light_color = Color(0.7, 0.8, 0.9)
		sun.light_color = Color(1.0, 0.95, 0.85)
		sun.light_energy = 1.25
		sun.rotation_degrees = Vector3(-55, 30, 0)
		moon.visible = false
		for l in lantern_lights:
			if is_instance_valid(l):
				l.visible = false

func _ground() -> void:
	var sb := StaticBody3D.new()
	sb.collision_layer = 1
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = Vector3(500, 2, 500)
	cs.shape = sh
	cs.position = Vector3(0, -1, 0)
	sb.add_child(cs)
	var mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(500, 500)
	mi.mesh = pm
	mi.material_override = Vox.cel_mat(Color(0.2, 0.42, 0.17), false, 0.0, 0.022, "grass")
	sb.add_child(mi)
	add_child(sb)
	# невидимые стены по краю карты
	for s in [Vector3(1, 0, 0), Vector3(-1, 0, 0), Vector3(0, 0, 1), Vector3(0, 0, -1)]:
		var w := StaticBody3D.new()
		var c2 := CollisionShape3D.new()
		var b2 := BoxShape3D.new()
		b2.size = Vector3(2 if s.x != 0 else 240, 60, 2 if s.z != 0 else 240)
		c2.shape = b2
		w.add_child(c2)
		w.position = s * 110 + Vector3.UP * 30
		add_child(w)
	# вытоптанная земля на поляне и тропинки
	Vox.box(self, Vector3(22, 0.04, 22), Vector3(0, 0.02, 0), Color(0.4, 0.33, 0.23), false, 0.0, "dirt")
	Vox.box(self, Vector3(4, 0.04, 40), Vector3(0, 0.02, -30), Color(0.4, 0.33, 0.23), false, 0.0, "dirt")
	Vox.box(self, Vector3(34, 0.04, 4), Vector3(26, 0.02, 0), Color(0.4, 0.33, 0.23), false, 0.0, "dirt")

func _grass() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for k in 3:
		var a := k * PI / 3.0
		var dx := Vector3(cos(a), 0, sin(a)) * 0.07
		var lean := Vector3(sin(a * 2.0), 0, cos(a)) * 0.08
		st.add_vertex(-dx)
		st.add_vertex(dx)
		st.add_vertex(Vector3(0, 0.5, 0) + lean)
	var mesh := st.commit()
	grass_mat = ShaderMaterial.new()
	grass_mat.shader = load("res://shaders/grass.gdshader")
	mesh.surface_set_material(0, grass_mat)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	var count := 26000
	mm.instance_count = count
	var placed := 0
	while placed < count:
		var p := Vector3(rng.randf_range(-75, 75), 0, rng.randf_range(-75, 75))
		# на вытоптанной поляне травы меньше
		if absf(p.x) < 10 and absf(p.z) < 10 and rng.randf() < 0.85:
			continue
		var s := rng.randf_range(0.6, 1.4)
		var t := Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s, s * rng.randf_range(0.7, 1.3), s)), p)
		mm.set_instance_transform(placed, t)
		placed += 1
	grass_mm = mm
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mmi)

func _tree(p: Vector3, h: float, w: float, k: String, fc := Color(0.18, 0.42, 0.2)) -> void:
	var t = StaticBody3D.new()
	t.set_script(TreeS)
	add_child(t)
	t.position = p
	t.rotation.y = rng.randf() * TAU
	t.build(h, w, k, fc)

func _forest() -> void:
	# кольцо деревьев вокруг поляны и лес на севере
	var n := 0
	while n < 46:
		var a := rng.randf() * TAU
		var r := rng.randf_range(17.0, 60.0)
		var p := Vector3(cos(a) * r, 0, sin(a) * r)
		# не ставить на деревню, бамбук, стену
		if p.x > 14 and p.z < -6 and p.z > -42 and p.x < 52:
			continue
		if p.x < -18 and p.z > 10 and p.z < 42 and p.x > -50:
			continue
		if p.z > 38:
			continue
		if absf(p.x) < 4 and p.z < -15:
			continue
		var fc := Color(0.16, 0.4, 0.2).lerp(Color(0.25, 0.48, 0.16), rng.randf())
		_tree(p, rng.randf_range(6.0, 9.0), rng.randf_range(0.55, 0.8), "tree", fc)
		n += 1

func _bamboo() -> void:
	# роща бамбука: стволы близко — идеально для прыжков от ствола к стволу
	for i in 46:
		var p := Vector3(rng.randf_range(-48, -20), 0, rng.randf_range(12, 40))
		_tree(p, rng.randf_range(8.0, 11.5), 0.28, "bamboo")

func _house(c: Vector3, rot: float, w: float, d: float) -> void:
	var h := Node3D.new()
	h.position = c
	h.rotation.y = rot
	add_child(h)
	var wall_h := 3.2
	var wood := Color(0.5, 0.34, 0.2)
	var paper := Color(0.9, 0.86, 0.74)
	# пол-веранда
	Vox.solid(h, Vector3(w + 1.6, 0.5, d + 1.6), Vector3(0, 0.25, 0), Color(0.42, 0.3, 0.2), true, 1, "wood")
	# угловые столбы
	for sx in [-1, 1]:
		for sz in [-1, 1]:
			Vox.solid(h, Vector3(0.35, wall_h, 0.35), Vector3(sx * w * 0.5, 0.5 + wall_h * 0.5, sz * d * 0.5), wood, true, 1, "bark")
	# стены из разрушаемых панелей (сёдзи)
	var panel_w := 2.0
	for side in 4:
		var along := w if side < 2 else d
		var nn := int(along / panel_w)
		for i in nn:
			var off := -along * 0.5 + panel_w * (i + 0.5)
			var pos: Vector3
			var size: Vector3
			if side == 0:
				pos = Vector3(off, 0.5, -d * 0.5)
				size = Vector3(panel_w - 0.05, wall_h, 0.25)
			elif side == 1:
				pos = Vector3(off, 0.5, d * 0.5)
				size = Vector3(panel_w - 0.05, wall_h, 0.25)
			elif side == 2:
				pos = Vector3(-w * 0.5, 0.5, off)
				size = Vector3(0.25, wall_h, panel_w - 0.05)
			else:
				pos = Vector3(w * 0.5, 0.5, off)
				size = Vector3(0.25, wall_h, panel_w - 0.05)
			_panel(h, pos, size, paper, wood)
	# крыша
	var roof := Color(0.22, 0.2, 0.26)
	Vox.solid(h, Vector3(w + 2.6, 0.4, d + 2.6), Vector3(0, 0.5 + wall_h + 0.2, 0), roof, true, 1, "roof")
	Vox.solid(h, Vector3(w + 1.4, 0.6, d + 0.6), Vector3(0, 0.5 + wall_h + 0.7, 0), roof.lightened(0.05), true, 1, "roof")
	Vox.solid(h, Vector3(w * 0.5, 0.5, d * 0.25), Vector3(0, 0.5 + wall_h + 1.2, 0), roof.darkened(0.1), true, 1, "roof")

func _panel(parent: Node3D, pos: Vector3, size: Vector3, paper: Color, wood: Color) -> void:
	var b = StaticBody3D.new()
	b.set_script(Breakable)
	b.collision_layer = 1
	b.position = pos
	parent.add_child(b)
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = size
	cs.shape = sh
	cs.position = Vector3(0, size.y * 0.5, 0)
	b.add_child(cs)
	Vox.box(b, size, Vector3(0, size.y * 0.5, 0), paper, true, 0.0, "paper")
	# деревянная решётка
	var thin := Vector3(size.x * 1.02, 0.07, size.z * 1.05) if size.x > size.z else Vector3(size.x * 1.05, 0.07, size.z * 1.02)
	for k in 3:
		Vox.box(b, thin, Vector3(0, size.y * (0.25 + k * 0.25), 0), wood, false)
	b.brad = 1.2
	b.need_power = 2
	b.col = paper
	b.pieces = 10
	b.piece_size = 0.35
	b.height = size.y

func _village() -> void:
	_house(Vector3(24, 0, -14), 0.0, 8.0, 6.0)
	_house(Vector3(38, 0, -28), 0.3, 6.0, 6.0)
	_house(Vector3(24, 0, -34), -0.15, 10.0, 6.0)

func _stone_wall() -> void:
	# длинная стена — для бега по стене
	var stone := Color(0.5, 0.5, 0.55)
	for i in 10:
		var x := -40.0 + i * 8.0
		Vox.solid(self, Vector3(8.0, 5.0, 1.4), Vector3(x + 4.0, 2.5, 48), stone.lightened(rng.randf_range(-0.06, 0.06)), true, 1, "stone")
		Vox.solid(self, Vector3(8.2, 0.5, 1.8), Vector3(x + 4.0, 5.2, 48), Color(0.3, 0.28, 0.32), true, 1, "roof")
	# стенки поменьше на поляне
	Vox.solid(self, Vector3(1.2, 4.0, 10.0), Vector3(-13, 2.0, -6), stone, true, 1, "stone")
	Vox.solid(self, Vector3(9.0, 3.5, 1.2), Vector3(9, 1.75, 14), stone.darkened(0.08), true, 1, "stone")

func _shrine() -> void:
	# ворота-тории на тропинке
	var red := Color(0.78, 0.14, 0.1)
	var dark := Color(0.12, 0.1, 0.12)
	var z := -24.0
	Vox.solid(self, Vector3(0.6, 6.0, 0.6), Vector3(-2.8, 3.0, z), red)
	Vox.solid(self, Vector3(0.6, 6.0, 0.6), Vector3(2.8, 3.0, z), red)
	Vox.solid(self, Vector3(8.4, 0.5, 0.9), Vector3(0, 6.1, z), dark)
	Vox.solid(self, Vector3(7.0, 0.4, 0.6), Vector3(0, 5.1, z), red)

func _lantern(p: Vector3) -> void:
	var b = StaticBody3D.new()
	b.set_script(Breakable)
	b.position = p
	add_child(b)
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = Vector3(0.7, 1.9, 0.7)
	cs.shape = sh
	cs.position = Vector3(0, 0.95, 0)
	b.add_child(cs)
	var st := Color(0.55, 0.55, 0.58)
	Vox.box(b, Vector3(0.8, 0.25, 0.8), Vector3(0, 0.12, 0), st, true, 0.0, "stone")
	Vox.box(b, Vector3(0.3, 0.8, 0.3), Vector3(0, 0.65, 0), st, true, 0.0, "stone")
	Vox.box(b, Vector3(0.6, 0.5, 0.6), Vector3(0, 1.3, 0), Color(1.0, 0.75, 0.35), true, 1.6)
	Vox.box(b, Vector3(0.95, 0.2, 0.95), Vector3(0, 1.65, 0), st.darkened(0.2), true, 0.0, "stone")
	Vox.box(b, Vector3(0.3, 0.2, 0.3), Vector3(0, 1.85, 0), st.darkened(0.2))
	var l := OmniLight3D.new()
	l.light_color = Color(1.0, 0.65, 0.3)
	l.light_energy = 2.2
	l.omni_range = 8.0
	l.position = Vector3(0, 1.3, 0)
	b.add_child(l)
	lantern_lights.append(l)
	b.brad = 0.7
	b.need_power = 1
	b.col = st
	b.pieces = 7
	b.piece_size = 0.28
	b.height = 1.9

func _fence(a: Vector3, b: Vector3) -> void:
	var len := a.distance_to(b)
	var n := int(len / 2.0)
	var dir := (b - a).normalized()
	for i in n:
		var p := a + dir * (2.0 * i + 1.0)
		var f = StaticBody3D.new()
		f.set_script(Breakable)
		f.position = p
		f.rotation.y = atan2(dir.x, dir.z)
		add_child(f)
		var cs := CollisionShape3D.new()
		var sh := BoxShape3D.new()
		sh.size = Vector3(0.2, 1.2, 2.0)
		cs.shape = sh
		cs.position = Vector3(0, 0.6, 0)
		f.add_child(cs)
		var wood := Color(0.55, 0.4, 0.25)
		Vox.box(f, Vector3(0.18, 1.3, 0.18), Vector3(0, 0.65, -0.9), wood, true, 0.0, "bark")
		Vox.box(f, Vector3(0.1, 0.15, 2.0), Vector3(0, 1.0, 0), wood.lightened(0.08), true, 0.0, "wood")
		Vox.box(f, Vector3(0.1, 0.15, 2.0), Vector3(0, 0.55, 0), wood.lightened(0.08), true, 0.0, "wood")
		f.brad = 1.0
		f.col = wood
		f.pieces = 5
		f.piece_size = 0.25
		f.height = 1.2

func _props() -> void:
	for p in [Vector3(-3.5, 0, -16), Vector3(3.5, 0, -16), Vector3(-3.5, 0, -32), Vector3(3.5, 0, -32),
			Vector3(17, 0, -3), Vector3(17, 0, 3), Vector3(-10, 0, 10)]:
		_lantern(p)
	_fence(Vector3(-12, 0, -12), Vector3(-12, 0, 6))
	_fence(Vector3(12, 0, 6), Vector3(12, 0, 12))
	_fence(Vector3(18, 0, -44), Vector3(48, 0, -44))
	# валуны
	for i in 14:
		var a := rng.randf() * TAU
		var r := rng.randf_range(14, 50)
		var s := rng.randf_range(0.8, 2.2)
		Vox.solid(self, Vector3(s * 1.3, s, s * 1.1), Vector3(cos(a) * r, s * 0.4, sin(a) * r), Color(0.5, 0.5, 0.53), true, 1, "stone")
	# ящики и бочки в деревне
	for p in [Vector3(19, 0, -9), Vector3(20, 0, -9), Vector3(30, 0, -21), Vector3(31, 0, -22)]:
		var b = StaticBody3D.new()
		b.set_script(Breakable)
		b.position = p
		add_child(b)
		var cs := CollisionShape3D.new()
		var sh := BoxShape3D.new()
		sh.size = Vector3(0.9, 0.9, 0.9)
		cs.shape = sh
		cs.position = Vector3(0, 0.45, 0)
		b.add_child(cs)
		Vox.box(b, Vector3(0.9, 0.9, 0.9), Vector3(0, 0.45, 0), Color(0.6, 0.45, 0.28), true, 0.0, "wood")
		b.brad = 0.7
		b.col = Color(0.6, 0.45, 0.28)
		b.pieces = 6
		b.piece_size = 0.25
		b.height = 0.9

func kick_points() -> Array:
	var out := []
	for n in get_tree().get_nodes_in_group("kick"):
		out.append(n.kick_info())
	return out

func _process(_dt: float) -> void:
	if grass_mat and G.player:
		grass_mat.set_shader_parameter("player_pos", G.player.global_position)
