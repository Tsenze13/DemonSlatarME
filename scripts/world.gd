extends Node3D
# Арена: поляна для боя, лес и бамбук для прыжков, деревня с домами
# для бега по стенам, длинная каменная стена, разрушаемые заборы и фонари.

const Vox = preload("res://scripts/vox.gd")
const Breakable = preload("res://scripts/breakable.gd")
const TreeS = preload("res://scripts/tree.gd")
const Cedar = preload("res://scripts/cedar.gd")
const Tex = preload("res://scripts/tex.gd")

# Карта: центр — плоская поляна для боя; на востоке — деревня, на севере —
# святилище на холме среди кедров, на западе — бамбук и пруд с мостом,
# на юге — длинная стена. По краю — холмы уступами, за краем — горы.
const CELL := 2.0                  # размер клетки рельефа (м)
const HALF := 110.0                # край играбельной карты
const POND := Rect2(-46, -12, 24, 14)     # пруд (x, z, ширина, глубина)
const SHRINE := Vector3(0, 0, -62)        # святилище на холме
var noise := FastNoiseLite.new()
var noise2 := FastNoiseLite.new()
var cedar_pads: Array = []
var baked_count := 0         # ветки кедров, на которые можно запрыгнуть
var water_mat: ShaderMaterial
var paper_mat: ShaderMaterial
var village_view := Vector3(32, 0.5, -4)
var forest_view := Vector3(14, 0.5, -52)

var env: Environment
var sun: DirectionalLight3D
var sky_mat: ShaderMaterial
var night := true
var lantern_lights: Array = []
var grass_mat: ShaderMaterial
var grass_mm: MultiMesh
var moon: MeshInstance3D
var stars: MultiMeshInstance3D
var fireflies: CPUParticles3D
var leaves: CPUParticles3D
var petals: CPUParticles3D
var rng := RandomNumberGenerator.new()

func build() -> void:
	rng.seed = 7
	noise.seed = 11
	noise.frequency = 0.03
	noise.fractal_octaves = 3
	noise2.seed = 23
	noise2.frequency = 0.012
	_environment()
	_ground()
	_mountains()
	_water()
	_bridge()
	_grass()
	_forest()
	_bamboo()
	_cedars()
	_village()
	_stone_wall()
	_shrine()
	_props()
	_atmosphere()
	# объединить тысячи статичных блоков в несколько мешей (меньше вызовов отрисовки)
	baked_count = Vox.bake(self, Callable(self, "_can_bake"))
	# разрушаемые предметы и рубящиеся деревья — каждый в свой меш (они живут отдельно)
	var all := Callable(self, "_yes")
	for n in get_tree().get_nodes_in_group("breakable"):
		if n.get_script() == Breakable:
			baked_count += Vox.bake(n, all, 1000.0)
		elif n.get_script() == TreeS:
			baked_count += Vox.bake(n.top, all, 1000.0)
	_build_minimap()
	set_time("sunset")

func _environment() -> void:
	var we := WorldEnvironment.new()
	env = Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	sky_mat = ShaderMaterial.new()
	sky_mat.shader = load("res://shaders/sky.gdshader")
	sky.sky_material = sky_mat
	sky.radiance_size = Sky.RADIANCE_SIZE_32
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	# плёночный тон: светлое не выгорает в белое, тени мягче
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.0
	env.tonemap_white = 6.0
	# свечение: фонари, солнце, эффекты дыхания светятся
	env.glow_enabled = true
	env.glow_intensity = 0.4
	env.glow_strength = 0.9
	env.glow_bloom = 0.0
	env.glow_hdr_threshold = 1.15
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE
	# дымка: даль растворяется в цвете неба
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_EXPONENTIAL
	env.fog_density = 0.012
	env.fog_sky_affect = 0.0
	env.fog_height_density = 0.0
	env.adjustment_enabled = true
	we.environment = env
	add_child(we)
	sun = DirectionalLight3D.new()
	sun.shadow_enabled = true
	sun.shadow_blur = 1.6
	sun.shadow_bias = 0.04
	sun.shadow_normal_bias = 1.2
	sun.directional_shadow_max_distance = 70.0
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	add_child(sun)

# Время суток: "day" — день, "sunset" — закат (золотой час), "night" — ночь с фонарями.
# Клавиша N перебирает по кругу.
const TIMES := {
	"day": {
		"sun_rot": Vector3(-50, 35, 0), "sun_col": Color(1.0, 0.95, 0.86), "sun_e": 1.15,
		"top": Color(0.16, 0.38, 0.82), "hor": Color(0.58, 0.74, 0.94), "ground": Color(0.42, 0.5, 0.45),
		"sky_sun": Color(1.0, 0.93, 0.78), "halo": 0.35, "cl_lit": Color(1.0, 1.0, 1.0), "cl_sh": Color(0.68, 0.74, 0.86),
		"cover": 0.42, "stars": 0.0, "moon": 0.0,
		"amb": Color(0.55, 0.62, 0.8), "amb_e": 0.45, "fog": Color(0.46, 0.63, 0.9), "fog_d": 0.0028,
		"sat": 1.15, "con": 1.14, "bri": 0.92, "glow": 0.12, "lanterns": false,
	},
	"sunset": {
		"sun_rot": Vector3(-13, -62, 0), "sun_col": Color(1.0, 0.66, 0.42), "sun_e": 1.2,
		"top": Color(0.2, 0.25, 0.5), "hor": Color(1.0, 0.62, 0.42), "ground": Color(0.4, 0.3, 0.32),
		"sky_sun": Color(1.0, 0.7, 0.4), "halo": 1.1, "cl_lit": Color(1.0, 0.72, 0.5), "cl_sh": Color(0.45, 0.38, 0.55),
		"cover": 0.5, "stars": 0.0, "moon": 0.0,
		"amb": Color(0.46, 0.42, 0.62), "amb_e": 0.5, "fog": Color(0.78, 0.55, 0.58), "fog_d": 0.0065,
		"sat": 1.0, "con": 1.08, "bri": 0.95, "glow": 0.35, "lanterns": true,
	},
	"night": {
		"sun_rot": Vector3(-40, 140, 0), "sun_col": Color(0.55, 0.65, 1.0), "sun_e": 0.45,
		"top": Color(0.02, 0.03, 0.1), "hor": Color(0.1, 0.12, 0.26), "ground": Color(0.04, 0.05, 0.1),
		"sky_sun": Color(0.0, 0.0, 0.0), "halo": 0.0, "cl_lit": Color(0.32, 0.36, 0.55), "cl_sh": Color(0.08, 0.09, 0.18),
		"cover": 0.35, "stars": 1.0, "moon": 1.0,
		"amb": Color(0.24, 0.3, 0.55), "amb_e": 0.45, "fog": Color(0.06, 0.08, 0.18), "fog_d": 0.012,
		"sat": 0.95, "con": 1.08, "bri": 0.95, "glow": 0.6, "lanterns": true,
	},
}
var time_of_day := "sunset"

func set_time(t: String) -> void:
	if not TIMES.has(t):
		return
	time_of_day = t
	night = t == "night"
	var c: Dictionary = TIMES[t]
	sun.rotation_degrees = c.sun_rot
	sun.light_color = c.sun_col
	sun.light_energy = c.sun_e
	var sd: Vector3 = sun.global_transform.basis.z
	sky_mat.set_shader_parameter("sun_dir", sd)
	sky_mat.set_shader_parameter("top_col", c.top)
	sky_mat.set_shader_parameter("hor_col", c.hor)
	sky_mat.set_shader_parameter("ground_col", c.ground)
	sky_mat.set_shader_parameter("sun_col", c.sky_sun)
	sky_mat.set_shader_parameter("halo", c.halo)
	sky_mat.set_shader_parameter("cloud_lit", c.cl_lit)
	sky_mat.set_shader_parameter("cloud_shade", c.cl_sh)
	sky_mat.set_shader_parameter("cloud_cover", c.cover)
	sky_mat.set_shader_parameter("stars", c.stars)
	sky_mat.set_shader_parameter("moon", c.moon)
	# ночью «солнце» — это луна: её диск там, откуда идёт свет
	sky_mat.set_shader_parameter("moon_dir", sd if t == "night" else Vector3(-0.45, 0.55, -0.7))
	env.ambient_light_color = c.amb
	env.ambient_light_energy = c.amb_e
	env.fog_light_color = c.fog
	env.fog_density = c.fog_d * fog_mult
	env.adjustment_saturation = c.sat
	env.adjustment_contrast = c.con
	env.adjustment_brightness = c.bri
	env.glow_intensity = c.glow
	if fireflies:
		fireflies.emitting = t == "night"
	for l in lantern_lights:
		if is_instance_valid(l):
			l.visible = c.lanterns
	if G.post_mat:
		G.post_mat.set_shader_parameter("grade", ["day", "sunset", "night"].find(t))
	# окна-сёдзи светятся изнутри вечером и ночью
	var pe: float = {"day": 0.0, "sunset": 0.25, "night": 0.75}[t]
	Vox.mat_set(Vox.cel_mat(PAPER, true, 0.0, 0.022, "paper"), "emission", pe)
	Vox.mat_set(Vox.cel_mat(Color(0.92, 0.88, 0.76), true, 0.0, 0.022, "paper"), "emission", pe)
	if water_mat:
		water_mat.set_shader_parameter("sky", c.hor)
		water_mat.set_shader_parameter("deep", Color(0.1, 0.28, 0.42) if t != "night" else Color(0.08, 0.14, 0.3))
		water_mat.set_shader_parameter("shallow", Color(0.25, 0.52, 0.58) if t != "night" else Color(0.14, 0.24, 0.4))

# Кровавая луна (бой с Тенью): 0 — обычная ночь, 1 — небо алеет, 2 — багровая тьма.
var blood := 0
func blood_moon(level: int) -> void:
	blood = level
	if level <= 0:
		set_time(time_of_day)
		return
	var k := 0.6 if level == 1 else 1.0
	sky_mat.set_shader_parameter("top_col", Color(0.12, 0.02, 0.05).lerp(Color(0.05, 0.0, 0.02), k - 0.6))
	sky_mat.set_shader_parameter("hor_col", Color(0.55, 0.08, 0.1).lerp(Color(0.35, 0.02, 0.05), k - 0.6))
	sky_mat.set_shader_parameter("sun_col", Color(1.0, 0.2, 0.15))
	sky_mat.set_shader_parameter("moon", 1.0)
	sky_mat.set_shader_parameter("halo", 1.4)
	sky_mat.set_shader_parameter("cloud_lit", Color(0.6, 0.12, 0.12))
	sky_mat.set_shader_parameter("cloud_shade", Color(0.2, 0.03, 0.05))
	sun.light_color = Color(1.0, 0.55, 0.5)
	env.ambient_light_color = Color(0.36, 0.2, 0.26)
	env.fog_light_color = Color(0.3, 0.05, 0.08)
	env.fog_density = 0.007 * k * fog_mult
	env.adjustment_saturation = 1.0
	if G.sfx:
		G.sfx.play("gong", -2.0, 0.6)

# Праздник фонарей (часть вторая): гирлянды красных и белых бумажных фонарей
# поперёк улицы, ленты-флажки, тёплый свет. Строится один раз, дальше — вкл/выкл.
var fest: Node3D = null
func festival(on: bool) -> void:
	if fest == null:
		if not on:
			return
		fest = Node3D.new()
		add_child(fest)
		var z := -10.0
		var k := 0
		while z > -60.0:
			var a := Vector3(27.6, 4.3, z)
			var b := Vector3(36.6, 4.3, z - 2.0)
			var d := b - a
			var rope := Vox.box(fest, Vector3(0.03, 0.03, d.length()), (a + b) * 0.5 + Vector3.DOWN * 0.25, Color(0.3, 0.22, 0.16), false)
			rope.look_at_from_position((a + b) * 0.5 + Vector3.DOWN * 0.25, b + Vector3.DOWN * 0.25, Vector3.UP)
			var n := 7
			for i in n:
				var t := (i + 0.5) / n
				var p := a.lerp(b, t) + Vector3.DOWN * (0.3 + sin(t * PI) * 0.45)
				var red := (i + k) % 2 == 0
				var col := Color(0.95, 0.2, 0.15) if red else Color(0.98, 0.92, 0.78)
				Vox.box(fest, Vector3(0.34, 0.42, 0.34), p, col, true, 1.6 if red else 1.2, "paper")
				Vox.box(fest, Vector3(0.26, 0.05, 0.26), p + Vector3(0, 0.24, 0), Color(0.12, 0.08, 0.08))
				Vox.box(fest, Vector3(0.26, 0.05, 0.26), p + Vector3(0, -0.24, 0), Color(0.12, 0.08, 0.08))
				Vox.box(fest, Vector3(0.04, 0.16, 0.04), p + Vector3(0, -0.36, 0), Color(0.95, 0.75, 0.2), false)
			if k % 2 == 0:
				var l := OmniLight3D.new()
				l.light_color = Color(1.0, 0.45, 0.3)
				l.light_energy = 1.4
				l.omni_range = 8.0
				l.position = (a + b) * 0.5 + Vector3.DOWN * 0.8
				fest.add_child(l)
			z -= 8.0
			k += 1
		# ленты-флажки над входом в деревню
		for i in 12:
			var fx := 27.8 + i * 0.75
			var fl := Vox.box(fest, Vector3(0.35, 0.45, 0.03), Vector3(fx, 4.6 - absf(i - 5.5) * 0.04, -4.0), [Color(0.95, 0.2, 0.15), Color(0.98, 0.95, 0.85), Color(0.95, 0.75, 0.2)][i % 3], true, 0.0, "cloth")
			fl.rotation_degrees.z = 45.0
	fest.visible = on

func next_time() -> void:
	var order := ["day", "sunset", "night"]
	set_time(order[(order.find(time_of_day) + 1) % 3])

# Качество из настроек: тени (0 — нет, 1 — простые, 2 — чёткие) и густота травы.
var fog_mult := 1.0
var view_k := 1.0
# Качество графики: тени, доля травинок, свечение, дальность прорисовки
# (ближе даль — гуще дымка, чтобы край мира не «обрывался»).
func set_quality(shadows: int, grass: float, glow := true, view := 1.0) -> void:
	view_k = clampf(view, 0.3, 1.0)
	fog_mult = pow(1.0 / view_k, 1.6)
	if env:
		env.glow_enabled = glow
		env.fog_density = float(TIMES[time_of_day].fog_d) * fog_mult
	if G.cam_rig:
		G.cam_rig.cam.far = lerpf(120.0, 420.0, (view_k - 0.3) / 0.7)
	for mi in grass_mmis:
		(mi as MultiMeshInstance3D).visibility_range_end = lerpf(40.0, 110.0, (view_k - 0.3) / 0.7)
	if sun:
		sun.shadow_enabled = shadows > 0
		sun.directional_shadow_max_distance = 45.0 if shadows == 1 else 70.0
		RenderingServer.directional_shadow_atlas_set_size(2048 if shadows == 1 else 4096, true)
	for mm in grass_mms:
		mm.visible_instance_count = int(mm.instance_count * clampf(grass, 0.0, 1.0))

# Совместимость со старым переключателем день/ночь.
func set_night(on: bool) -> void:
	set_time("night" if on else "day")

# --- Рельеф -----------------------------------------------------------------
# Высота клетки (целые метры, уступами). Центр карты плоский — там бой.
func height_at(x: float, z: float) -> float:
	if POND.has_point(Vector2(x, z)):
		return -1.0
	# холм святилища: три уступа к площадке
	var sd := Vector2(x - SHRINE.x, z - SHRINE.z)
	var sh := 0.0
	if absf(sd.x) < 11 and absf(sd.y) < 9:
		sh = 3.0 if (absf(sd.x) < 7 and absf(sd.y) < 5) else (2.0 if (absf(sd.x) < 9 and absf(sd.y) < 7) else 1.0)
	# деревня, стена, бамбук — ровно
	if x > 12 and x < 64 and z < 0 and z > -70:
		return sh
	var r := Vector2(x, z).length()
	var n := noise.get_noise_2d(x, z)
	var e := clampf((r + n * 10.0 - 80.0) / 26.0, 0.0, 1.0)
	var h := e * e * (5.0 + (noise2.get_noise_2d(x, z) * 0.5 + 0.5) * 11.0)
	return maxf(sh, floor(h))

# Материал верха клетки: 0 трава, 0.5 земля (поляна, тропы), 1 камень.
func _ground_mat(x: float, z: float, h: float) -> float:
	if h < 0.0:
		return 1.0
	if h >= 9.0:
		return 1.0
	if Vector2(x, z).length() < 12.0 + noise.get_noise_2d(x * 3.0, z * 3.0) * 2.0:
		return 0.5
	if absf(x) < 2.2 and z < -10 and z > -56:
		return 0.5                   # тропа к святилищу
	if absf(z + 2.0) < 1.8 and x > 10 and x < 34:
		return 0.5                   # тропа в деревню
	if absf(x - 32.0) < 3.0 and z < -4 and z > -62:
		return 0.5                   # улица деревни
	var sd := Vector2(x - SHRINE.x, z - SHRINE.z)
	if absf(sd.x) < 7 and absf(sd.y) < 5:
		return 1.0                   # каменная площадка святилища
	return 0.0

func _ground() -> void:
	var sb := StaticBody3D.new()
	sb.collision_layer = 1
	add_child(sb)
	# коллизия: карта высот с шагом 0,5 м (сэмплы не попадают на границы клеток)
	var step := 0.5
	var n := int(HALF * 2.0 / step) + 1
	var data := PackedFloat32Array()
	data.resize(n * n)
	var x0 := -HALF - 0.25
	for j in n:
		for i in n:
			data[j * n + i] = height_at(x0 + i * step, x0 + j * step) / step
	var hm := HeightMapShape3D.new()
	hm.map_width = n
	hm.map_depth = n
	hm.map_data = data
	var cs := CollisionShape3D.new()
	cs.shape = hm
	cs.scale = Vector3.ONE * step
	cs.position = Vector3(x0 + (n - 1) * step * 0.5, 0, x0 + (n - 1) * step * 0.5)
	sb.add_child(cs)
	# видимая земля — один меш из клеток-вокселей
	var mi := MeshInstance3D.new()
	mi.mesh = _terrain_mesh(-HALF - 30.0, HALF + 30.0, CELL, Callable(self, "height_at"))
	mi.material_override = _terrain_mat()
	add_child(mi)
	# невидимые стены по краю карты
	for s in [Vector3(1, 0, 0), Vector3(-1, 0, 0), Vector3(0, 0, 1), Vector3(0, 0, -1)]:
		var w := StaticBody3D.new()
		var c2 := CollisionShape3D.new()
		var b2 := BoxShape3D.new()
		b2.size = Vector3(2 if s.x != 0 else 240, 80, 2 if s.z != 0 else 240)
		c2.shape = b2
		w.add_child(c2)
		w.position = s * HALF + Vector3.UP * 30
		add_child(w)

var _tmat: ShaderMaterial
func _terrain_mat() -> ShaderMaterial:
	if _tmat:
		return _tmat
	_tmat = ShaderMaterial.new()
	_tmat.shader = load("res://shaders/terrain.gdshader")
	_tmat.set_shader_parameter("tex_grass", Tex.get_tex("t_grass"))
	_tmat.set_shader_parameter("tex_dirt", Tex.get_tex("t_dirt"))
	_tmat.set_shader_parameter("tex_rock", Tex.get_tex("t_rock"))
	_tmat.set_shader_parameter("tex_side", Tex.get_tex("t_side"))
	return _tmat

# Меш земли из клеток: верх каждой клетки + бока там, где сосед ниже.
func _terrain_mesh(lo: float, hi: float, cell: float, hf: Callable, mat_fn := true) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := int((hi - lo) / cell)
	var hs := PackedFloat32Array()
	hs.resize((n + 2) * (n + 2))
	for j in n + 2:
		for i in n + 2:
			var x := lo + (i - 1 + 0.5) * cell
			var z := lo + (j - 1 + 0.5) * cell
			hs[j * (n + 2) + i] = hf.call(x, z)
	for j in n:
		for i in n:
			var h := hs[(j + 1) * (n + 2) + i + 1]
			var x0 := lo + i * cell
			var z0 := lo + j * cell
			var cx := x0 + cell * 0.5
			var cz := z0 + cell * 0.5
			var m := _ground_mat(cx, cz, h) if mat_fn else (1.0 if h > 30.0 else 0.0)
			var tint := Color(1, 1, 1, m)
			if not mat_fn and h > 52.0:
				tint = Color(1.25, 1.25, 1.3, 1.0)   # снег на вершинах
			_quad(st, Vector3(x0, h, z0), Vector3(x0 + cell, h, z0), Vector3(x0 + cell, h, z0 + cell), Vector3(x0, h, z0 + cell), Vector3.UP, tint)
			# бока к более низким соседям
			var nb := [[1, 0], [-1, 0], [0, 1], [0, -1]]
			for k in 4:
				var di: int = nb[k][0]
				var dj: int = nb[k][1]
				var h2 := hs[(j + 1 + dj) * (n + 2) + i + 1 + di]
				if h2 >= h:
					continue
				var side_m := m if m < 0.75 else 1.0
				var tc := Color(1, 1, 1, side_m)
				if di == 1:
					_quad(st, Vector3(x0 + cell, h, z0 + cell), Vector3(x0 + cell, h, z0), Vector3(x0 + cell, h2, z0), Vector3(x0 + cell, h2, z0 + cell), Vector3.RIGHT, tc)
				elif di == -1:
					_quad(st, Vector3(x0, h, z0), Vector3(x0, h, z0 + cell), Vector3(x0, h2, z0 + cell), Vector3(x0, h2, z0), Vector3.LEFT, tc)
				elif dj == 1:
					_quad(st, Vector3(x0, h, z0 + cell), Vector3(x0 + cell, h, z0 + cell), Vector3(x0 + cell, h2, z0 + cell), Vector3(x0, h2, z0 + cell), Vector3.BACK, tc)
				else:
					_quad(st, Vector3(x0 + cell, h, z0), Vector3(x0, h, z0), Vector3(x0, h2, z0), Vector3(x0 + cell, h2, z0), Vector3.FORWARD, tc)
	return st.commit()

func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, nrm: Vector3, col: Color) -> void:
	for v in [a, b, c, a, c, d]:
		st.set_normal(nrm)
		st.set_color(col)
		st.add_vertex(v)

# Горы за краем карты: крупные уступы, к вершинам — скала и снег. Без коллизии.
func _mountain_h(x: float, z: float) -> float:
	var r := Vector2(x, z).length()
	if r < HALF + 8.0:
		return -50.0
	var e := clampf((r - HALF - 8.0) / 70.0, 0.0, 1.0)
	var n := noise2.get_noise_2d(x * 0.6, z * 0.6) * 0.5 + 0.5
	var n2 := noise.get_noise_2d(x * 0.25, z * 0.25) * 0.5 + 0.5
	var h := 14.0 + e * (25.0 + n * 50.0) * (0.5 + n2)
	return floor(h / 3.0) * 3.0

func _mountains() -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = _terrain_mesh(-300.0, 300.0, 6.0, Callable(self, "_mountain_h"), false)
	mi.material_override = _terrain_mat()
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)

# Пруд: вода с бликами и пеной у берега.
func _water() -> void:
	var mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = POND.size
	pm.subdivide_width = 24
	pm.subdivide_depth = 14
	mi.mesh = pm
	mi.position = Vector3(POND.position.x + POND.size.x * 0.5, -0.3, POND.position.y + POND.size.y * 0.5)
	water_mat = ShaderMaterial.new()
	water_mat.shader = load("res://shaders/water.gdshader")
	water_mat.set_shader_parameter("rect", Vector4(POND.position.x, POND.position.y, POND.end.x, POND.end.y))
	mi.material_override = water_mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	# камни по берегу и кувшинки
	for i in 26:
		var t := rng.randf()
		var side := rng.randi() % 4
		var p: Vector3
		match side:
			0: p = Vector3(POND.position.x + t * POND.size.x, 0, POND.position.y - 0.3)
			1: p = Vector3(POND.position.x + t * POND.size.x, 0, POND.end.y + 0.3)
			2: p = Vector3(POND.position.x - 0.3, 0, POND.position.y + t * POND.size.y)
			_: p = Vector3(POND.end.x + 0.3, 0, POND.position.y + t * POND.size.y)
		var s := rng.randf_range(0.4, 1.0)
		Vox.box(self, Vector3(s * 1.3, s * 0.6, s), p + Vector3.UP * s * 0.2, Color(0.55, 0.55, 0.57), false, 0.0, "stone")
	for i in 12:
		var p := Vector3(rng.randf_range(POND.position.x + 1, POND.end.x - 1), -0.27, rng.randf_range(POND.position.y + 1, POND.end.y - 1))
		if absf(p.x - BRIDGE_X) < 2.5:
			continue
		Vox.box(self, Vector3(0.6, 0.03, 0.6), p, Color(0.3, 0.55, 0.25), false)
		if rng.randf() < 0.4:
			Vox.box(self, Vector3(0.18, 0.12, 0.18), p + Vector3(0.1, 0.07, 0), Color(1.0, 0.75, 0.85), false, 0.3)

# Мост-арка через пруд (красные перила, деревянный настил).
const BRIDGE_X := -34.0
func _bridge() -> void:
	var z0 := POND.position.y - 2.0
	var z1 := POND.end.y + 2.0
	var segs := 16
	var red := Color(0.72, 0.14, 0.1)
	var wood := Color(0.5, 0.36, 0.24)
	var prev := Vector3(BRIDGE_X, 0.0, z0)
	for i in segs:
		var t1 := float(i + 1) / segs
		var p1 := Vector3(BRIDGE_X, sin(t1 * PI) * 1.6, lerpf(z0, z1, t1))
		var mid := (prev + p1) * 0.5
		var d := p1 - prev
		var b := StaticBody3D.new()
		b.position = mid
		b.rotation.x = -atan2(d.y, d.z)
		add_child(b)
		var cs := CollisionShape3D.new()
		var sh := BoxShape3D.new()
		sh.size = Vector3(2.6, 0.2, d.length() + 0.04)
		cs.shape = sh
		b.add_child(cs)
		Vox.box(b, Vector3(2.6, 0.2, d.length() + 0.04), Vector3.ZERO, wood.lightened(0.04 * (i % 2)), true, 0.0, "wood")
		for sx in [-1.0, 1.0]:
			if i % 2 == 0:
				Vox.box(b, Vector3(0.16, 0.9, 0.16), Vector3(sx * 1.25, 0.5, 0), red, true)
			Vox.box(b, Vector3(0.12, 0.1, d.length() + 0.05), Vector3(sx * 1.25, 0.95, 0), red, true)
		prev = p1
	# опоры
	for t in [0.25, 0.5, 0.75]:
		var p := Vector3(BRIDGE_X, 0, lerpf(z0, z1, t))
		for sx in [-1.0, 1.0]:
			Vox.box(self, Vector3(0.3, 1.6 + sin(t * PI) * 1.6, 0.3), Vector3(p.x + sx * 1.1, -1.0 + (1.6 + sin(t * PI) * 1.6) * 0.5, p.z), wood.darkened(0.2), true)

# Трава: кустики из воксельных травинок (тонкие прямоугольники, цвет ступенями
# от корня к кончику), плюс цветы-кубики. Раскиданы по всей карте кусками 24 м
# (невидимое за камерой отсекается), под героем расступаются.
var grass_mms: Array = []
var grass_mmis: Array = []
var flower_mat: ShaderMaterial

func _grass_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var r := RandomNumberGenerator.new()
	r.seed = 5
	for k in 5:
		var a := r.randf() * TAU
		var off := Vector3(r.randf_range(-0.12, 0.12), 0, r.randf_range(-0.12, 0.12))
		var hgt := r.randf_range(0.28, 0.6)
		var wd := 0.055
		var side := Vector3(cos(a), 0, sin(a)) * wd
		var lean := Vector3(-sin(a), 0, cos(a)) * r.randf_range(-0.06, 0.06)
		var p0 := off - side
		var p1 := off + side
		var p2 := off + side * 0.6 + Vector3.UP * hgt + lean
		var p3 := off - side * 0.6 + Vector3.UP * hgt + lean
		for v in [p0, p1, p2, p0, p2, p3]:
			st.set_normal(Vector3.UP)
			st.add_vertex(v)
	return st.commit()

func _grass() -> void:
	var mesh := _grass_mesh()
	grass_mat = ShaderMaterial.new()
	grass_mat.shader = load("res://shaders/grass.gdshader")
	mesh.surface_set_material(0, grass_mat)
	# цветы: стебель + головка-кубик (цвет экземпляра идёт только в головку)
	var fst := SurfaceTool.new()
	fst.begin(Mesh.PRIMITIVE_TRIANGLES)
	var stem := BoxMesh.new()
	stem.size = Vector3(0.025, 0.32, 0.025)
	fst.append_from(stem, 0, Transform3D(Basis.IDENTITY, Vector3(0, 0.16, 0)))
	var head := BoxMesh.new()
	head.size = Vector3(0.11, 0.09, 0.11)
	fst.append_from(head, 0, Transform3D(Basis.IDENTITY, Vector3(0, 0.36, 0)))
	var fmesh := fst.commit()
	flower_mat = ShaderMaterial.new()
	flower_mat.shader = grass_mat.shader
	flower_mat.set_shader_parameter("flower", true)
	fmesh.surface_set_material(0, flower_mat)
	var chunk := 24.0
	var buckets := {}
	var fbuckets := {}
	var count := 46000
	var placed := 0
	var tries := 0
	var fcols := [Color(0.95, 0.3, 0.35), Color(1.0, 0.85, 0.3), Color(0.98, 0.97, 0.95), Color(0.7, 0.5, 1.0), Color(1.0, 0.6, 0.75)]
	while placed < count and tries < count * 4:
		tries += 1
		var p := Vector3(rng.randf_range(-100, 100), 0, rng.randf_range(-100, 100))
		var hy := height_at(p.x, p.z)
		if hy < 0.0 or POND.grow(0.4).has_point(Vector2(p.x, p.z)):
			continue
		var gm := _ground_mat(p.x, p.z, hy)
		if gm > 0.75:
			continue
		if gm > 0.25 and rng.randf() < 0.88:
			continue
		p.y = hy
		var s := rng.randf_range(0.75, 1.35)
		var t := Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s, s * rng.randf_range(0.8, 1.3), s)), p)
		var key := Vector2i(floori(p.x / chunk), floori(p.z / chunk))
		if not buckets.has(key):
			buckets[key] = []
		var tint := Color(1, 1, 1).lerp(Color(0.85, 0.95, 0.75), rng.randf()) * rng.randf_range(0.9, 1.08)
		(buckets[key] as Array).append([t, tint])
		placed += 1
		if gm < 0.25 and rng.randf() < 0.05:
			if not fbuckets.has(key):
				fbuckets[key] = []
			var ft := Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * rng.randf_range(0.8, 1.2)), p + Vector3(rng.randf_range(-0.2, 0.2), 0, rng.randf_range(-0.2, 0.2)))
			(fbuckets[key] as Array).append([ft, fcols[rng.randi() % fcols.size()]])
	var biggest := 0
	for key in buckets:
		var mm := _mm(mesh, buckets[key])
		grass_mms.append(mm)
		if mm.instance_count > biggest:
			biggest = mm.instance_count
			grass_mm = mm
	for key in fbuckets:
		grass_mms.append(_mm(fmesh, fbuckets[key]))

func _mm(mesh: Mesh, items: Array) -> MultiMesh:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = mesh
	mm.instance_count = items.size()
	# узел — в центре куска: дальность прорисовки считается от него
	var cen := Vector3.ZERO
	for it in items:
		cen += (it[0] as Transform3D).origin
	cen /= maxf(1.0, items.size())
	for i in items.size():
		var t: Transform3D = items[i][0]
		t.origin -= cen
		mm.set_instance_transform(i, t)
		mm.set_instance_color(i, items[i][1])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.position = cen
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mmi)
	grass_mmis.append(mmi)
	return mm

func _tree(p: Vector3, h: float, w: float, k: String, fc := Color(0.18, 0.42, 0.2)) -> void:
	var t = StaticBody3D.new()
	t.set_script(TreeS)
	add_child(t)
	t.position = Vector3(p.x, height_at(p.x, p.z), p.z)
	t.rotation.y = rng.randf() * TAU
	t.build(h, w, k, fc)

# Свободно ли место для дерева (не на деревне, пруду, тропах, холме святилища).
func _free_spot(p: Vector3, pad := 2.0) -> bool:
	if p.x > 14 - pad and p.x < 50 + pad and p.z < 0 + pad and p.z > -64 - pad:
		return false                       # деревня
	if p.x < -18 and p.z > 10 and p.z < 42 and p.x > -50:
		return false                       # бамбук
	if POND.grow(pad + 1.5).has_point(Vector2(p.x, p.z)):
		return false
	if absf(p.z - 48.0) < 3.0 + pad and absf(p.x) < 44:
		return false                       # стена
	if absf(p.x) < 4.0 + pad and p.z < -8 and p.z > -58:
		return false                       # тропа к святилищу
	if absf(p.x - SHRINE.x) < 12 + pad and absf(p.z - SHRINE.z) < 10 + pad:
		return false
	if Vector2(p.x, p.z).length() < 15.0:
		return false                       # поляна
	if absf(p.z + 2.0) < 2.5 + pad and p.x > 8 and p.x < 36:
		return false                       # тропа в деревню
	return true

func _forest() -> void:
	# лиственные деревья по всей карте, гуще к краю
	var n := 0
	var tries := 0
	while n < 70 and tries < 2000:
		tries += 1
		var a := rng.randf() * TAU
		var r := rng.randf_range(17.0, 96.0)
		var p := Vector3(cos(a) * r, 0, sin(a) * r)
		if not _free_spot(p):
			continue
		if p.z > 38 and absf(p.x) < 44:
			continue
		var fc := Color(0.16, 0.4, 0.2).lerp(Color(0.28, 0.5, 0.16), rng.randf())
		if rng.randf() < 0.18:
			fc = Color(0.85, 0.42, 0.18).lerp(Color(0.7, 0.2, 0.15), rng.randf())   # клёны осенние
		elif rng.randf() < 0.1:
			fc = Color(0.95, 0.68, 0.78)                                          # сакура
		_tree(p, rng.randf_range(6.0, 9.5), rng.randf_range(0.55, 0.8), "tree", fc)
		n += 1

# Кедры: роща вокруг святилища и старый лес на северо-западе.
func _cedars() -> void:
	var spots := []
	var tries := 0
	while spots.size() < 30 and tries < 3000:
		tries += 1
		var p: Vector3
		if spots.size() < 20:
			p = Vector3(rng.randf_range(-34, 34), 0, rng.randf_range(-96, -42))
		else:
			p = Vector3(rng.randf_range(-90, -48), 0, rng.randf_range(-80, -24))
		if not _free_spot(p, 1.5):
			continue
		var ok := true
		for q in spots:
			if (q as Vector3).distance_to(p) < 6.5:
				ok = false
				break
		if not ok:
			continue
		spots.append(p)
	# пара кедров у самой поляны — чтобы было куда запрыгнуть сразу
	spots.append(Vector3(-15.5, 0, -12.0))
	spots.append(Vector3(-19.0, 0, -18.5))
	spots.append(Vector3(12.0, 0, -16.0))
	var i := 0
	for p in spots:
		var c = StaticBody3D.new()
		c.set_script(Cedar)
		add_child(c)
		c.position = Vector3(p.x, height_at(p.x, p.z), p.z)
		var h := rng.randf_range(16.0, 24.0)
		var fc := Color(0.14, 0.32, 0.2).lerp(Color(0.2, 0.4, 0.22), rng.randf())
		c.build(h, rng.randf_range(1.1, 1.6), 100 + i, fc)
		cedar_pads.append_array(c.pads)
		i += 1

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

const PAPER := Color(0.9, 0.86, 0.74)

# Деревня: улица вдоль z (x = 32), дома с обеих сторон лицом к улице,
# фонари-тётин на столбах, флаги-нобори, бельё, бочки, колодец, пожарная вышка.
func _village() -> void:
	var left := [-12.0, -27.0, -42.0, -56.0]
	var right := [-10.0, -25.0, -40.0, -54.0]
	for z in left:
		_house(Vector3(23, 0, z), 0.0, 7.0, 9.0)
		_house_dress(Vector3(23, 0, z), 7.0, 9.0, 1.0, int(absf(z)))
	for z in right:
		_house(Vector3(42, 0, z), 0.0, 7.0, 9.0)
		_house_dress(Vector3(42, 0, z), 7.0, 9.0, -1.0, int(absf(z)) + 3)
	# фонари на столбах вдоль улицы
	var k := 0
	var z := -6.0
	while z > -62.0:
		for sx in [28.2, 36.3]:
			_street_lamp(Vector3(sx, 0, z + (0.0 if sx < 30 else 3.5)), sx < 30, k % 2 == 0)
			k += 1
		z -= 8.0
	# флаги-нобори у входов
	var cols := [Color(0.8, 0.15, 0.12), Color(0.15, 0.3, 0.6), Color(0.9, 0.75, 0.25), Color(0.2, 0.45, 0.3), Color(0.92, 0.9, 0.85)]
	for i in 7:
		var bz := -8.0 - i * 7.6
		var bx := 27.6 if i % 2 == 0 else 37.2
		var pole := Vector3(bx, 0, bz)
		Vox.box(self, Vector3(0.1, 4.6, 0.1), pole + Vector3(0, 2.3, 0), Color(0.3, 0.22, 0.15))
		Vox.box(self, Vector3(0.05, 3.2, 0.9), pole + Vector3(0, 2.6, 0.5), cols[i % cols.size()], true, 0.0, "cloth")
		Vox.box(self, Vector3(0.07, 0.06, 1.0), pole + Vector3(0, 4.25, 0.5), Color(0.3, 0.22, 0.15))
	# бельё на верёвках между домами (в проулках)
	for zz in [-19.5, -34.5, -49.0]:
		_laundry(Vector3(20.0, 3.0, zz), Vector3(26.0, 3.0, zz))
		_laundry(Vector3(39.0, 3.0, zz + 2.0), Vector3(45.0, 3.0, zz + 2.0))
	# бочки и ящики у домов (разрушаемые)
	for p in [Vector3(27.4, 0, -8), Vector3(27.2, 0, -9.1), Vector3(37.2, 0, -21), Vector3(27.5, 0, -36.5),
			Vector3(37.4, 0, -36), Vector3(37.3, 0, -37.1), Vector3(27.3, 0, -51), Vector3(37.4, 0, -50)]:
		if rng.randf() < 0.5:
			_crate(p)
		else:
			_barrel(p)
	# колодец на площади в конце улицы
	var wpos := Vector3(32, 0, -62)
	var st := Color(0.55, 0.55, 0.57)
	Vox.solid(self, Vector3(2.2, 0.9, 2.2), wpos + Vector3(0, 0.45, 0), st, true, 1, "stone")
	Vox.box(self, Vector3(1.6, 0.05, 1.6), wpos + Vector3(0, 0.88, 0), Color(0.1, 0.18, 0.25))
	for sx in [-1.0, 1.0]:
		Vox.box(self, Vector3(0.18, 2.2, 0.18), wpos + Vector3(sx * 1.0, 1.6, 0), Color(0.4, 0.28, 0.18), true, 0.0, "wood")
	Vox.box(self, Vector3(2.8, 0.2, 1.8), wpos + Vector3(0, 2.8, 0), Color(0.22, 0.2, 0.24), true, 0.0, "roof")
	Vox.box(self, Vector3(0.35, 0.4, 0.35), wpos + Vector3(0, 1.4, 0), Color(0.5, 0.36, 0.22), true, 0.0, "wood")
	# пожарная вышка-ягура: на неё можно забраться (бег по столбам / прыжки)
	_tower(Vector3(48, 0, -64))
	# дым из труб
	for hp in [Vector3(23, 6.0, -27), Vector3(42, 6.0, -40), Vector3(23, 6.0, -56)]:
		_smoke(hp)

# Убранство дома: фонари у входа, занавеска-норэн, ящики с цветами, вывеска.
# front — куда смотрит фасад (+1: к +x, −1: к −x).
func _house_dress(c: Vector3, w: float, d: float, front: float, seed_: int) -> void:
	var fx := c.x + front * (w * 0.5 + 0.2)
	var r2 := RandomNumberGenerator.new()
	r2.seed = seed_
	var noren: Color = [Color(0.15, 0.22, 0.45), Color(0.6, 0.12, 0.1), Color(0.2, 0.35, 0.25), Color(0.35, 0.2, 0.35)][r2.randi() % 4]
	# норэн: три полосы ткани над входом
	for k in 3:
		Vox.box(self, Vector3(0.05, 1.0, 0.62), Vector3(fx, 2.95, c.z - 0.66 + k * 0.66), noren, true, 0.0, "cloth")
	Vox.box(self, Vector3(0.06, 0.06, 2.2), Vector3(fx, 3.48, c.z), Color(0.3, 0.2, 0.12))
	# красные бумажные фонари по бокам входа
	for sz in [-1.4, 1.4]:
		var lp := Vector3(fx + front * 0.1, 3.1, c.z + sz)
		Vox.box(self, Vector3(0.36, 0.5, 0.36), lp, Color(0.95, 0.3, 0.18), true, 1.6)
		Vox.box(self, Vector3(0.3, 0.06, 0.3), lp + Vector3(0, 0.28, 0), Color(0.1, 0.08, 0.08))
		Vox.box(self, Vector3(0.3, 0.06, 0.3), lp + Vector3(0, -0.28, 0), Color(0.1, 0.08, 0.08))
	# ящики с цветами под окнами
	for sz in [-3.2, 3.2]:
		var bp := Vector3(fx + front * 0.1, 1.15, c.z + sz)
		Vox.box(self, Vector3(0.35, 0.3, 1.4), bp, Color(0.45, 0.3, 0.18), true, 0.0, "wood")
		for q in 5:
			var fc: Color = [Color(0.95, 0.35, 0.45), Color(1.0, 0.85, 0.3), Color(0.95, 0.95, 0.95), Color(0.6, 0.4, 0.9)][r2.randi() % 4]
			Vox.box(self, Vector3(0.16, 0.16, 0.16), bp + Vector3(0, 0.22, -0.55 + q * 0.27), fc, false, 0.15)
			Vox.box(self, Vector3(0.12, 0.12, 0.12), bp + Vector3(0, 0.12, -0.42 + q * 0.27), Color(0.3, 0.55, 0.25), false)
	# вывеска над входом
	Vox.box(self, Vector3(0.12, 0.6, 1.6), Vector3(fx + front * 0.05, 4.0, c.z), Color(0.18, 0.12, 0.08), true, 0.0, "wood")
	Vox.box(self, Vector3(0.14, 0.36, 0.2), Vector3(fx + front * 0.06, 4.0, c.z - 0.35), Color(0.9, 0.85, 0.7), false)
	Vox.box(self, Vector3(0.14, 0.36, 0.2), Vector3(fx + front * 0.06, 4.0, c.z + 0.35), Color(0.9, 0.85, 0.7), false)

func _street_lamp(p: Vector3, arm_pos: bool, lit: bool) -> void:
	var wood := Color(0.3, 0.22, 0.15)
	Vox.solid(self, Vector3(0.18, 3.4, 0.18), p + Vector3(0, 1.7, 0), wood, true, 1, "wood")
	var arm := 0.6 if arm_pos else -0.6
	Vox.box(self, Vector3(0.9, 0.1, 0.1), p + Vector3(arm * 0.5, 3.3, 0), wood)
	var lp := p + Vector3(arm, 2.85, 0)
	Vox.box(self, Vector3(0.4, 0.58, 0.4), lp, Color(1.0, 0.45, 0.2), true, 1.8)
	Vox.box(self, Vector3(0.32, 0.07, 0.32), lp + Vector3(0, 0.32, 0), Color(0.1, 0.08, 0.08))
	Vox.box(self, Vector3(0.32, 0.07, 0.32), lp + Vector3(0, -0.32, 0), Color(0.1, 0.08, 0.08))
	Vox.box(self, Vector3(0.03, 0.3, 0.03), lp + Vector3(0, 0.5, 0), Color(0.1, 0.08, 0.08))
	if lit:
		var l := OmniLight3D.new()
		l.light_color = Color(1.0, 0.55, 0.28)
		l.light_energy = 1.8
		l.omni_range = 7.0
		l.position = lp
		add_child(l)
		lantern_lights.append(l)

func _laundry(a: Vector3, b: Vector3) -> void:
	var d := b - a
	var rope := Vox.box(self, Vector3(0.03, 0.03, d.length()), (a + b) * 0.5, Color(0.8, 0.75, 0.6), false)
	rope.look_at_from_position((a + b) * 0.5, b, Vector3.UP)
	var cols := [Color(0.95, 0.95, 0.92), Color(0.3, 0.45, 0.7), Color(0.85, 0.5, 0.55), Color(0.9, 0.85, 0.6)]
	var n := int(d.length() / 1.1)
	for i in n:
		if rng.randf() < 0.25:
			continue
		var t := (i + 0.5) / n
		var p := a.lerp(b, t) + Vector3.DOWN * (0.12 + sin(t * PI) * 0.2)
		var sz := Vector3(0.04, rng.randf_range(0.5, 0.9), rng.randf_range(0.5, 0.8))
		var cl := Vox.box(self, sz, p + Vector3.DOWN * sz.y * 0.5, cols[rng.randi() % cols.size()], true, 0.0, "cloth")
		cl.look_at_from_position(cl.position, cl.position + d.normalized().cross(Vector3.UP), Vector3.UP)

func _crate(p: Vector3) -> void:
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
	var wc := Color(0.6, 0.45, 0.28)
	Vox.box(b, Vector3(0.9, 0.9, 0.9), Vector3(0, 0.45, 0), wc, true, 0.0, "wood")
	Vox.box(b, Vector3(0.94, 0.1, 0.94), Vector3(0, 0.82, 0), wc.darkened(0.25), false)
	Vox.box(b, Vector3(0.94, 0.1, 0.94), Vector3(0, 0.08, 0), wc.darkened(0.25), false)
	b.brad = 0.7
	b.col = wc
	b.pieces = 6
	b.piece_size = 0.25
	b.height = 0.9

func _barrel(p: Vector3) -> void:
	var b = StaticBody3D.new()
	b.set_script(Breakable)
	b.position = p
	add_child(b)
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = Vector3(0.8, 1.0, 0.8)
	cs.shape = sh
	cs.position = Vector3(0, 0.5, 0)
	b.add_child(cs)
	var wc := Color(0.55, 0.38, 0.22)
	Vox.box(b, Vector3(0.7, 1.0, 0.7), Vector3(0, 0.5, 0), wc, true, 0.0, "wood")
	Vox.box(b, Vector3(0.8, 0.8, 0.6), Vector3(0, 0.5, 0), wc.lightened(0.05), false, 0.0, "wood")
	Vox.box(b, Vector3(0.6, 0.8, 0.8), Vector3(0, 0.5, 0), wc.lightened(0.05), false, 0.0, "wood")
	for y in [0.2, 0.8]:
		Vox.box(b, Vector3(0.84, 0.07, 0.84), Vector3(0, y, 0), Color(0.25, 0.22, 0.2), false)
	b.brad = 0.6
	b.col = wc
	b.pieces = 6
	b.piece_size = 0.22
	b.height = 1.0

# Пожарная вышка: четыре столба, площадка на 8 м с крышей и колоколом.
func _tower(p: Vector3) -> void:
	var wood := Color(0.42, 0.3, 0.2)
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			Vox.solid(self, Vector3(0.35, 9.0, 0.35), p + Vector3(sx * 1.4, 4.5, sz * 1.4), wood, true, 1, "bark")
	for y in [2.5, 5.0]:
		for sz in [-1.0, 1.0]:
			Vox.box(self, Vector3(3.0, 0.15, 0.15), p + Vector3(0, y, sz * 1.4), wood)
			Vox.box(self, Vector3(0.15, 0.15, 3.0), p + Vector3(sz * 1.4, y, 0), wood)
	Vox.solid(self, Vector3(3.6, 0.3, 3.6), p + Vector3(0, 8.0, 0), wood.lightened(0.05), true, 1, "wood")
	for sx in [-1.0, 1.0]:
		Vox.box(self, Vector3(0.12, 0.8, 3.6), p + Vector3(sx * 1.75, 8.5, 0), wood)
		Vox.box(self, Vector3(3.6, 0.8, 0.12), p + Vector3(0, 8.5, sx * 1.75), wood)
	Vox.box(self, Vector3(4.6, 0.3, 4.6), p + Vector3(0, 10.6, 0), Color(0.22, 0.2, 0.24), true, 0.0, "roof")
	_cam_block(Vector3(4.6, 0.7, 4.6), p + Vector3(0, 10.8, 0))
	Vox.box(self, Vector3(2.4, 0.4, 2.4), p + Vector3(0, 10.95, 0), Color(0.22, 0.2, 0.24), true, 0.0, "roof")
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			Vox.box(self, Vector3(0.18, 2.4, 0.18), p + Vector3(sx * 1.6, 9.4, sz * 1.6), wood)
	Vox.box(self, Vector3(0.5, 0.6, 0.5), p + Vector3(0, 9.8, 0), Color(0.7, 0.55, 0.25), true, 0.3)
	# лестница
	for k in 12:
		Vox.box(self, Vector3(0.7, 0.08, 0.1), p + Vector3(0, 0.5 + k * 0.65, 1.55), wood.lightened(0.1))

func _smoke(p: Vector3) -> void:
	var sm := _particles(Color(0.75, 0.75, 0.78), 0.0, 14, 5.0, Vector3(0.2, 0.1, 0.2), Vector3.ZERO, 0.45, 0.0)
	sm.position = p
	sm.direction = Vector3(0.2, 1, 0)
	sm.spread = 12.0
	sm.initial_velocity_min = 0.6
	sm.initial_velocity_max = 0.9
	sm.gravity = Vector3(0.35, 0.15, 0.1)
	sm.scale_amount_min = 0.8
	sm.scale_amount_max = 2.2
	var g := Gradient.new()
	g.set_color(0, Color(0.8, 0.8, 0.82, 0.55))
	g.set_color(1, Color(0.8, 0.8, 0.82, 0.0))
	sm.color_ramp = g
	var mat: StandardMaterial3D = (sm.mesh as BoxMesh).material
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA

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
	var red := Color(0.78, 0.14, 0.1)
	var dark := Color(0.12, 0.1, 0.12)
	# ворота-тории на тропе и у подножия холма
	for z in [-24.0, -49.5]:
		Vox.solid(self, Vector3(0.6, 6.0, 0.6), Vector3(-2.8, 3.0, z), red, true, 1, "")
		Vox.solid(self, Vector3(0.6, 6.0, 0.6), Vector3(2.8, 3.0, z), red, true, 1, "")
		Vox.solid(self, Vector3(8.4, 0.5, 0.9), Vector3(0, 6.1, z), dark)
		Vox.solid(self, Vector3(7.0, 0.4, 0.6), Vector3(0, 5.1, z), red)
		Vox.box(self, Vector3(1.0, 0.8, 0.12), Vector3(0, 5.6, z + 0.35), Color(0.15, 0.12, 0.1))   # табличка
	# каменные фонари вдоль тропы
	for z in [-30.0, -38.0, -46.0]:
		for sx in [-1.0, 1.0]:
			_lantern(Vector3(sx * 3.4, 0, z), z == -38.0)
	# лестница на холм: пандус-коллизия + видимые ступени
	var z0 := -51.0
	var z1 := -57.0
	var st := StaticBody3D.new()
	st.position = Vector3(0, 1.5, (z0 + z1) * 0.5)
	st.rotation.x = atan2(3.0, z0 - z1)
	add_child(st)
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = Vector3(3.2, 0.2, Vector2(3.0, z0 - z1).length())
	cs.shape = sh
	st.add_child(cs)
	var stone := Color(0.6, 0.59, 0.56)
	for k in 12:
		var t := (k + 0.5) / 12.0
		Vox.box(self, Vector3(3.2, 0.25, 0.5), Vector3(0, t * 3.0 - 0.12, lerpf(z0, z1, t)), stone.lightened(0.03 * (k % 2)), true, 0.0, "stone")
		Vox.box(self, Vector3(3.2, t * 3.0, 0.5), Vector3(0, t * 3.0 * 0.5 - 0.2, lerpf(z0, z1, t)), stone.darkened(0.15), false, 0.0, "stone")
	# святилище на площадке (y = 3)
	var base := Vector3(0, 3.0, -64.0)
	var wood := Color(0.55, 0.3, 0.18)
	Vox.solid(self, Vector3(9.0, 0.8, 7.0), base + Vector3(0, 0.4, 0), Color(0.4, 0.3, 0.22), true, 1, "wood")
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			Vox.solid(self, Vector3(0.45, 3.4, 0.45), base + Vector3(sx * 4.0, 2.5, sz * 3.0), red, true, 1, "")
	# стены зала — тёмное дерево с белыми вставками
	Vox.box(self, Vector3(7.6, 2.8, 0.2), base + Vector3(0, 2.2, -3.0), wood, true, 0.0, "wood")
	Vox.box(self, Vector3(0.2, 2.8, 5.8), base + Vector3(-3.9, 2.2, 0), wood, true, 0.0, "wood")
	Vox.box(self, Vector3(0.2, 2.8, 5.8), base + Vector3(3.9, 2.2, 0), wood, true, 0.0, "wood")
	for k in 3:
		Vox.box(self, Vector3(1.8, 2.0, 0.12), base + Vector3(-2.4 + k * 2.4, 2.2, 2.9), Color(0.92, 0.88, 0.76), true, 0.0, "paper")
	# крыша в три яруса, свесы шире, конёк с золотом
	var roof := Color(0.2, 0.22, 0.24)
	Vox.box(self, Vector3(11.5, 0.45, 9.5), base + Vector3(0, 4.35, 0), roof, true, 0.0, "roof")
	Vox.box(self, Vector3(10.2, 0.6, 8.0), base + Vector3(0, 4.85, 0), roof.lightened(0.05), true, 0.0, "roof")
	Vox.box(self, Vector3(8.0, 0.7, 5.6), base + Vector3(0, 5.45, 0), roof, true, 0.0, "roof")
	Vox.box(self, Vector3(5.0, 0.6, 2.8), base + Vector3(0, 6.05, 0), roof.lightened(0.05), true, 0.0, "roof")
	Vox.box(self, Vector3(5.6, 0.25, 0.5), base + Vector3(0, 6.45, 0), Color(0.85, 0.65, 0.2), true, 0.6)
	_cam_block(Vector3(11.5, 2.4, 9.5), base + Vector3(0, 5.3, 0))
	for sx in [-1.0, 1.0]:
		Vox.box(self, Vector3(0.6, 0.6, 0.4), base + Vector3(sx * 5.9, 4.6, 4.6), roof.darkened(0.1))   # загнутые углы
		Vox.box(self, Vector3(0.6, 0.6, 0.4), base + Vector3(sx * 5.9, 4.6, -4.6), roof.darkened(0.1))
	# верёвка-симэнава с бумажными зигзагами
	Vox.box(self, Vector3(7.0, 0.22, 0.22), base + Vector3(0, 3.9, 3.2), Color(0.85, 0.75, 0.5), true)
	for k in 5:
		Vox.box(self, Vector3(0.18, 0.5, 0.04), base + Vector3(-2.6 + k * 1.3, 3.5, 3.25), Color(0.98, 0.98, 0.95), false, 0.2)
	# ящик для подношений, колокол
	Vox.solid(self, Vector3(2.0, 0.9, 0.9), base + Vector3(0, 1.25, 4.0), wood.darkened(0.2), true, 1, "wood")
	Vox.box(self, Vector3(0.5, 0.5, 0.5), base + Vector3(0, 3.4, 3.5), Color(0.75, 0.6, 0.25), true, 0.4)
	# каменные стражи-комаину и фонари на площадке
	for sx in [-1.0, 1.0]:
		var kp := base + Vector3(sx * 4.6, 0.0, 6.2)
		Vox.solid(self, Vector3(0.9, 0.6, 0.9), kp + Vector3(0, 0.3, 0), stone.darkened(0.1), true, 1, "stone")
		Vox.box(self, Vector3(0.7, 0.8, 0.8), kp + Vector3(0, 1.0, 0), stone, true, 0.0, "stone")
		Vox.box(self, Vector3(0.6, 0.55, 0.6), kp + Vector3(0, 1.6, 0.2), stone.lightened(0.05), true, 0.0, "stone")
		_lantern(base + Vector3(sx * 6.0, 0.0, 0.0), true)

func _lantern(p: Vector3, lit := true) -> void:
	var b = StaticBody3D.new()
	b.set_script(Breakable)
	b.position = Vector3(p.x, maxf(p.y, height_at(p.x, p.z)), p.z)
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
	if lit:
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
	for p in [Vector3(17, 0, -5), Vector3(17, 0, 1), Vector3(-10, 0, 10), Vector3(-10, 0, -10), Vector3(9, 0, 12)]:
		_lantern(p)
	_fence(Vector3(-12, 0, -12), Vector3(-12, 0, 6))
	_fence(Vector3(12, 0, 6), Vector3(12, 0, 12))
	_fence(Vector3(-46, 0, 5), Vector3(-36.5, 0, 5))
	_fence(Vector3(-31.5, 0, 5), Vector3(-22, 0, 5))
	# валуны (мшистые)
	var n := 0
	while n < 22:
		var a := rng.randf() * TAU
		var r := rng.randf_range(14, 92)
		var p := Vector3(cos(a) * r, 0, sin(a) * r)
		if not _free_spot(p, 0.5):
			continue
		var s := rng.randf_range(0.8, 2.4)
		var y := height_at(p.x, p.z)
		Vox.solid(self, Vector3(s * 1.3, s, s * 1.1), Vector3(p.x, y + s * 0.4, p.z), Color(0.52, 0.52, 0.55), true, 1, "stone")
		Vox.box(self, Vector3(s * 1.2, 0.15, s * 1.0), Vector3(p.x, y + s * 0.9, p.z), Color(0.3, 0.5, 0.25), false, 0.0, "leaves")
		n += 1
	# ящики у поляны
	_crate(Vector3(15.5, 0, -6.5))
	_barrel(Vector3(16.5, 0, -7.2))

# Невидимое препятствие только для камеры (слой 16): крыши без коллизии,
# чтобы камера не залезала внутрь.
func _cam_block(size: Vector3, pos: Vector3) -> void:
	var sb := StaticBody3D.new()
	sb.collision_layer = 16
	sb.collision_mask = 0
	sb.position = pos
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = size
	cs.shape = sh
	sb.add_child(cs)
	add_child(sb)

# Название места (для титров при входе): [имя, подпись].
func region_at(p: Vector3) -> Array:
	var v := Vector2(p.x, p.z)
	if v.length() < 16.0:
		return ["Поляна у старой стены", "здесь демон ждёт темноты"]
	if p.x > 14 and p.x < 64 and p.z < 2 and p.z > -72:
		return ["Деревня Ивакура", "улица бумажных фонарей"]
	if absf(p.x - SHRINE.x) < 18 and p.z < -44 and p.z > -78:
		return ["Святилище Кумо", "кедры старше самой деревни"]
	if POND.grow(6.0).has_point(v):
		return ["Пруд Цукими", "мост-арка над тихой водой"]
	if p.x < -18 and p.z > 10 and p.z < 42 and p.x > -50:
		return ["Бамбуковая роща", "стволы близко — прыгай от ствола к стволу"]
	if p.x < -44 and p.z < -20:
		return ["Старый кедровый лес", "по веткам — до самых верхушек"]
	if p.z > 44 and absf(p.x) < 46:
		return ["Каменная стена", "бег по стене — разбег и прыжок"]
	if v.length() > 78.0:
		return ["Холмы у гор", "уступы — только прыжком"]
	return ["Луга у деревни", ""]

# Картинка мини-карты: 1 пиксель = 1,5 м, север (−z) сверху.
var minimap: ImageTexture
const MAP_SCALE := 1.5
func _build_minimap() -> void:
	var n := int(HALF * 2.0 / MAP_SCALE)
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	for j in n:
		for i in n:
			var x := -HALF + (i + 0.5) * MAP_SCALE
			var z := -HALF + (j + 0.5) * MAP_SCALE
			var h := height_at(x, z)
			var m := _ground_mat(x, z, h)
			var c: Color
			if h < 0.0:
				c = Color(0.3, 0.55, 0.75)
			elif m > 0.75:
				c = Color(0.62, 0.6, 0.58)
			elif m > 0.25:
				c = Color(0.72, 0.6, 0.42)
			else:
				c = Color(0.42, 0.62, 0.32).darkened(clampf(h * 0.05, 0.0, 0.4))
			img.set_pixel(i, j, c)
	# дома, святилище, стена
	var rects := []
	for z in [-12.0, -27.0, -42.0, -56.0]:
		rects.append([Rect2(19.5, z - 4.5, 7, 9), Color(0.35, 0.3, 0.32)])
	for z in [-10.0, -25.0, -40.0, -54.0]:
		rects.append([Rect2(38.5, z - 4.5, 7, 9), Color(0.35, 0.3, 0.32)])
	rects.append([Rect2(-4.5, -67.5, 9, 7), Color(0.75, 0.2, 0.15)])
	rects.append([Rect2(-40, 47.3, 80, 1.4), Color(0.5, 0.5, 0.55)])
	for r in rects:
		var rr: Rect2 = r[0]
		for z2 in range(int(rr.position.y), int(rr.end.y)):
			for x2 in range(int(rr.position.x), int(rr.end.x)):
				var i2 := int((x2 + HALF) / MAP_SCALE)
				var j2 := int((z2 + HALF) / MAP_SCALE)
				if i2 >= 0 and j2 >= 0 and i2 < n and j2 < n:
					img.set_pixel(i2, j2, r[1])
	for c in get_tree().get_nodes_in_group("cedar"):
		var i3 := int((c.global_position.x + HALF) / MAP_SCALE)
		var j3 := int((c.global_position.z + HALF) / MAP_SCALE)
		for dj in range(-1, 2):
			for di in range(-1, 2):
				if i3 + di >= 0 and j3 + dj >= 0 and i3 + di < n and j3 + dj < n:
					img.set_pixel(i3 + di, j3 + dj, Color(0.16, 0.34, 0.2))
	minimap = ImageTexture.create_from_image(img)

func _yes(_m: Node) -> bool:
	return true

func _can_bake(m: Node) -> bool:
	var n := m.get_parent()
	while n != null and n != self:
		if n is RigidBody3D or n is CPUParticles3D:
			return false
		var sc = n.get_script()
		if sc == Breakable or sc == TreeS:
			return false
		n = n.get_parent()
	return n == self

func kick_points() -> Array:
	var out := []
	for n in get_tree().get_nodes_in_group("kick"):
		out.append(n.kick_info())
	return out

# Волна по траве от взрывного рывка или удара о землю.
var shock_age := 99.0
func grass_shock(p: Vector3) -> void:
	shock_age = 0.0
	for m in [grass_mat, flower_mat]:
		if m:
			m.set_shader_parameter("shock_pos", p)

func _process(_dt: float) -> void:
	shock_age += G.rdt
	if grass_mat:
		grass_mat.set_shader_parameter("shock_age", shock_age)
		flower_mat.set_shader_parameter("shock_age", shock_age)
	if grass_mat and G.player:
		grass_mat.set_shader_parameter("player_pos", G.player.global_position)
		flower_mat.set_shader_parameter("player_pos", G.player.global_position)
	# фонари мерцают, частицы летают вокруг героя
	var t := G.real_time
	for i in lantern_lights.size():
		var l = lantern_lights[i]
		if is_instance_valid(l):
			l.light_energy = 2.2 + sin(t * 9.0 + i * 1.7) * 0.18 + sin(t * 23.0 + i) * 0.1
	if G.player and fireflies:
		var pp: Vector3 = G.player.global_position
		fireflies.global_position = Vector3(pp.x, 0.0, pp.z)
		leaves.global_position = Vector3(pp.x, 9.0, pp.z)
		petals.global_position = Vector3(pp.x, 7.0, pp.z)

# Атмосфера: звёзды, светлячки ночью, падающие листья и лепестки.
func _atmosphere() -> void:
	# светлячки
	fireflies = _particles(Color(0.85, 1.0, 0.4), 2.5, 70, 6.0, Vector3(24, 1.5, 24), Vector3(0, 1.5, 0), 0.05, 0.0)
	fireflies.direction = Vector3(0, 1, 0)
	fireflies.spread = 180.0
	fireflies.initial_velocity_min = 0.1
	fireflies.initial_velocity_max = 0.5
	fireflies.gravity = Vector3(0, 0.05, 0)
	# листья (тёмно-красные и рыжие) и светлые лепестки — медленно кружат вниз
	leaves = _particles(Color(0.75, 0.3, 0.15), 0.0, 40, 9.0, Vector3(30, 1, 30), Vector3.ZERO, 0.12, 1.0)
	leaves.gravity = Vector3(0.6, -1.0, 0.3)
	leaves.color_ramp = _ramp(Color(0.8, 0.35, 0.15), Color(0.6, 0.2, 0.12))
	petals = _particles(Color(1.0, 0.8, 0.88), 0.0, 25, 9.0, Vector3(26, 1, 26), Vector3.ZERO, 0.07, 1.0)
	petals.gravity = Vector3(0.8, -0.7, 0.2)

func _particles(col: Color, glow: float, amount: int, life: float, box: Vector3, off: Vector3, size: float, spin: float) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = amount
	p.lifetime = life
	p.preprocess = life
	p.local_coords = false
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = box
	p.position = off
	var m := BoxMesh.new()
	m.size = Vector3(size, size * (0.25 if spin > 0.0 else 1.0), size)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	mat.albedo_color = col
	if glow > 0.0:
		mat.emission_enabled = true
		mat.emission = col * glow
	m.material = mat
	p.mesh = m
	p.color = col
	p.direction = Vector3(0, -1, 0)
	p.spread = 30.0
	p.initial_velocity_min = 0.2
	p.initial_velocity_max = 0.6
	if spin > 0.0:
		p.angular_velocity_min = -180.0
		p.angular_velocity_max = 180.0
		p.particle_flag_rotate_y = true
		p.angle_min = -180.0
		p.angle_max = 180.0
	p.damping_min = 0.3
	p.damping_max = 0.8
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.4
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(p)
	return p

func _ramp(a: Color, b: Color) -> Gradient:
	var g := Gradient.new()
	g.set_color(0, a)
	g.set_color(1, b)
	return g
