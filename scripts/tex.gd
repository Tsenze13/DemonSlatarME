extends RefCounted
# Пиксельные текстуры 16×16, нарисованные кодом (как в воксельных играх).
# Значения — яркость-множитель (0..1, в шейдере ×1.25), поэтому одна текстура
# подходит к любому цвету блока.

static var _cache := {}

static func get_tex(kind: String) -> Texture2D:
	if _cache.has(kind):
		return _cache[kind]
	var img: Image
	match kind:
		"grass": img = _grass()
		"dirt": img = _speckle(7, 0.72, 0.95, 0.12)
		"stone": img = _soft_stone()
		"wood": img = _soft_planks()
		"bark": img = _soft_bark()
		"leaves": img = _soft_leaves()
		"roof": img = _roof()
		"paper": img = _paper()
		"cloth": img = _speckle(11, 0.86, 0.94, 0.04)
		"twill": img = _twill()
		"t_grass": img = _t_grass()
		"t_dirt": img = _t_dirt()
		"t_rock": img = _t_rock()
		"t_side": img = _t_side()
		"t_moss": img = _t_moss()
		"hair": img = _hair()
		"wrap": img = _wrap()
		"obi": img = _obi()
		"haori": img = _haori()
		"haori_check": img = _haori_check()
		"haori_flame": img = _haori_flame()
		"haori_dusk": img = _haori_dusk()
		"haori_shell": img = _haori_shell()
		"haori_bolt": img = _haori_bolt()
		"haori_sakura": img = _haori_sakura()
		"haori_ichimatsu": img = _haori_ichimatsu()
		"haori_split": img = _haori_split()
		"haori_flame_white": img = _haori_flame_white()
		"haori_butterfly": img = _haori_butterfly()
		"haori_uroko": img = _haori_uroko()
		"haori_stripes": img = _haori_stripes()
		"demon_skin": img = _demon_skin()
		"demon_robe": img = _demon_robe()
		"saya_shark": img = _saya_shark()
		"saya_bolt": img = _saya_bolt()
		"saya_sakura": img = _saya_sakura()
		"saya_cord": img = _saya_cord()
		"lacquer": img = _lacquer()
		"saya_wave": img = _saya_wave()
		"saya_ring": img = _saya_ring()
		"saya_diamond": img = _saya_diamond()
		_: img = _speckle(3, 0.8, 0.95, 0.1)
	# узоры хаори — 32 пикселя по ширине: вся ширина = один оборот вокруг тела
	if kind.begins_with("haori") and img.get_width() == 16:
		var wide := Image.create(32, img.get_height(), false, Image.FORMAT_RGB8)
		wide.blit_rect(img, Rect2i(0, 0, 16, img.get_height()), Vector2i(0, 0))
		wide.blit_rect(img, Rect2i(0, 0, 16, img.get_height()), Vector2i(16, 0))
		img = wide
	var t := ImageTexture.create_from_image(img)
	_cache[kind] = t
	return t

static func _img(w := 16, h := 16) -> Image:
	return Image.create(w, h, false, Image.FORMAT_RGB8)

static func _g(v: float) -> Color:
	v = clampf(v, 0.0, 1.0)
	return Color(v, v, v)

static func _speckle(seed_: int, lo: float, hi: float, dark: float) -> Image:
	var r := RandomNumberGenerator.new()
	r.seed = seed_
	var im := _img()
	for y in 16:
		for x in 16:
			var v := r.randf_range(lo, hi)
			if r.randf() < dark:
				v *= 0.75
			im.set_pixel(x, y, _g(v))
	return im

# --- Мягкие цветные текстуры земли (как в Voxium): крупные пиксели,
# плавные переходы оттенков, без резкого шума. Цвет — прямо в текстуре.
static func _vn(r: RandomNumberGenerator, n: int) -> Array:
	# сглаженный шум 16×16 (значения 0..1), бесшовный
	var g := []
	for i in 16 * 16:
		g.append(r.randf())
	var out := []
	out.resize(256)
	for y in 16:
		for x in 16:
			var acc := 0.0
			var wsum := 0.0
			for dy in range(-n, n + 1):
				for dx in range(-n, n + 1):
					var wgt := 1.0 / (1.0 + dx * dx + dy * dy)
					acc += g[((y + dy + 16) % 16) * 16 + (x + dx + 16) % 16] * wgt
					wsum += wgt
			out[y * 16 + x] = acc / wsum
	# растянуть в 0..1
	var lo := 1.0
	var hi := 0.0
	for v in out:
		lo = minf(lo, v)
		hi = maxf(hi, v)
	for i in 256:
		out[i] = (out[i] - lo) / maxf(hi - lo, 0.001)
	return out

static func _pal(im: Image, field: Array, cols: Array) -> void:
	for y in 16:
		for x in 16:
			var v: float = field[y * 16 + x]
			var k := v * (cols.size() - 1)
			var i := mini(int(k), cols.size() - 2)
			im.set_pixel(x, y, (cols[i] as Color).lerp(cols[i + 1], smoothstep(0.35, 0.65, k - i)))

static func _t_grass() -> Image:
	var r := RandomNumberGenerator.new()
	r.seed = 31
	var im := _img()
	_pal(im, _vn(r, 2), [Color(0.33, 0.55, 0.2), Color(0.42, 0.66, 0.24), Color(0.5, 0.74, 0.28)])
	# редкие светлые травинки
	for i in 10:
		var x := r.randi() % 16
		var y := r.randi() % 15
		im.set_pixel(x, y, Color(0.6, 0.82, 0.34))
		im.set_pixel(x, y + 1, Color(0.52, 0.76, 0.3))
	return im

static func _t_moss() -> Image:
	var r := RandomNumberGenerator.new()
	r.seed = 32
	var im := _img()
	_pal(im, _vn(r, 2), [Color(0.24, 0.42, 0.2), Color(0.32, 0.5, 0.24), Color(0.38, 0.56, 0.26)])
	return im

static func _t_dirt() -> Image:
	var r := RandomNumberGenerator.new()
	r.seed = 33
	var im := _img()
	_pal(im, _vn(r, 1), [Color(0.5, 0.38, 0.26), Color(0.58, 0.45, 0.31), Color(0.64, 0.51, 0.36)])
	for i in 6:
		var x := r.randi() % 15
		var y := r.randi() % 16
		im.set_pixel(x, y, Color(0.72, 0.66, 0.58))   # камешки
		im.set_pixel(x + 1, y, Color(0.62, 0.57, 0.5))
	return im

static func _t_rock() -> Image:
	var r := RandomNumberGenerator.new()
	r.seed = 34
	var im := _img()
	_pal(im, _vn(r, 2), [Color(0.44, 0.44, 0.47), Color(0.53, 0.53, 0.55), Color(0.6, 0.6, 0.62)])
	# трещины
	var x := 3
	for y in 16:
		im.set_pixel(x, y, Color(0.38, 0.38, 0.41))
		x = (x + (1 if r.randf() < 0.4 else 0)) % 16
	return im

static func _t_side() -> Image:
	# бок уступа: полосы грунта (как срез почвы)
	var r := RandomNumberGenerator.new()
	r.seed = 35
	var im := _img()
	var f := _vn(r, 1)
	for y in 16:
		for x in 16:
			var band := 0.0 if y < 6 else (1.0 if y < 11 else 2.0)
			var cols := [Color(0.5, 0.37, 0.25), Color(0.45, 0.33, 0.23), Color(0.55, 0.43, 0.3)]
			var c: Color = cols[int(band)]
			var v: float = f[y * 16 + x]
			im.set_pixel(x, y, c.lerp(c.lightened(0.12), v))
	return im

# --- Мягкие серые текстуры блоков мира (цвет даёт материал): низкий контраст,
# плавные пятна — как в Voxium, без «телевизионного» шума.
static func _gray(field: Array, lo: float, hi: float) -> Image:
	var im := _img()
	for y in 16:
		for x in 16:
			var v: float = field[y * 16 + x]
			v = floor(v * 4.0) / 4.0           # 4 ступени — пиксельные пятна
			im.set_pixel(x, y, _g(lerpf(lo, hi, v)))
	return im

static func _soft_stone() -> Image:
	var r := RandomNumberGenerator.new()
	r.seed = 41
	var im := _gray(_vn(r, 1), 0.8, 0.96)
	# кладка: камни 8×5 со смещением, швы чуть темнее
	for y in 16:
		for x in 16:
			var row := y / 5
			var off := 4 if row % 2 == 1 else 0
			if y % 5 == 4 or (x + off) % 8 == 7:
				im.set_pixel(x, y, _g(im.get_pixel(x, y).r * 0.86))
	return im

static func _soft_planks() -> Image:
	var r := RandomNumberGenerator.new()
	r.seed = 42
	var f := _vn(r, 1)
	var im := _img()
	for y in 16:
		for x in 16:
			var plank := y / 4
			var v: float = 0.84 + 0.05 * float(plank % 2) + (f[y * 16 + x] - 0.5) * 0.08
			# волокна вдоль доски
			if (x + plank * 5) % 7 == 0:
				v -= 0.04
			if y % 4 == 3:
				v -= 0.12                        # щель между досками
			im.set_pixel(x, y, _g(v))
	return im

static func _soft_bark() -> Image:
	var r := RandomNumberGenerator.new()
	r.seed = 43
	var f := _vn(r, 1)
	var im := _img()
	for y in 16:
		for x in 16:
			var v: float = 0.82 + (f[y * 16 + x] - 0.5) * 0.12
			if x % 4 == 0:
				v -= 0.1                         # вертикальные борозды коры
			im.set_pixel(x, y, _g(v))
	return im

static func _soft_leaves() -> Image:
	var r := RandomNumberGenerator.new()
	r.seed = 44
	var f := _vn(r, 1)
	var im := _img()
	for y in 16:
		for x in 16:
			var v: float = f[y * 16 + x]
			var c: float = 0.74 + floor(v * 4.0) / 4.0 * 0.24
			# светлые «листики» сверху каждого пятна
			if v > 0.8:
				c = 1.0
			im.set_pixel(x, y, _g(c))
	return im

# Форма истребителя: плотная ткань — лёгкий шум, редкие складки-рубчики, шов.
static func _twill() -> Image:
	var r := RandomNumberGenerator.new()
	r.seed = 21
	var im := _img()
	for y in 16:
		for x in 16:
			var v := 0.9 + r.randf_range(-0.035, 0.035)
			if (x * 3 + y * 5) % 11 == 0:
				v -= 0.07          # складка
			if x == 7:
				v -= 0.08          # шов
			im.set_pixel(x, y, _g(v))
	return im

# Волосы: вертикальные пряди, светлые блики и тёмные промежутки.
static func _hair() -> Image:
	var r := RandomNumberGenerator.new()
	r.seed = 5
	var im := _img()
	var cols := []
	for x in 16:
		cols.append(r.randf_range(0.8, 1.0))
	for y in 16:
		for x in 16:
			var v: float = cols[x]
			if (x + int(y / 5)) % 3 == 0:
				v -= 0.18
			if y < 2 and x % 4 == 1:
				v += 0.12          # блик
			im.set_pixel(x, y, _g(v + r.randf_range(-0.03, 0.03)))
	return im

# Обмотки на голенях (кяхан): косые витки ленты.
static func _wrap() -> Image:
	var im := _img()
	for y in 16:
		for x in 16:
			var k := (y * 2 + x) % 8
			var v := 0.95 if k < 5 else (0.72 if k == 5 else 0.85)
			im.set_pixel(x, y, _g(v))
	return im

# Пояс-оби: продольные полосы тканого узора.
static func _obi() -> Image:
	var im := _img()
	for y in 16:
		for x in 16:
			var v := 0.9
			if y % 8 == 0:
				v = 0.7
			elif y % 8 == 4 and x % 2 == 0:
				v = 1.0
			im.set_pixel(x, y, _g(v))
	return im

static func _grass() -> Image:
	var r := RandomNumberGenerator.new()
	r.seed = 21
	var im := _img()
	for y in 16:
		for x in 16:
			var v := r.randf_range(0.74, 0.92)
			var k := r.randf()
			if k < 0.12:
				v = 1.0
			elif k < 0.22:
				v = 0.62
			im.set_pixel(x, y, _g(v))
	return im

static func _stone() -> Image:
	var r := RandomNumberGenerator.new()
	r.seed = 5
	var im := _img()
	for y in 16:
		for x in 16:
			var v := r.randf_range(0.72, 0.9)
			# швы между камнями
			if y % 8 == 0 or (x + (8 if (y / 8) % 2 == 1 else 0)) % 16 == 0:
				v = 0.5
			elif r.randf() < 0.08:
				v = 0.98
			im.set_pixel(x, y, _g(v))
	return im

static func _planks() -> Image:
	var r := RandomNumberGenerator.new()
	r.seed = 9
	var im := _img()
	for y in 16:
		var plank := y / 4
		var shade := 0.82 + 0.06 * sin(plank * 2.1)
		for x in 16:
			var v := shade + r.randf_range(-0.05, 0.05)
			if y % 4 == 3:
				v = 0.55
			elif (x + plank * 5) % 16 == 0:
				v = 0.6
			im.set_pixel(x, y, _g(v))
	return im

static func _bark() -> Image:
	var r := RandomNumberGenerator.new()
	r.seed = 13
	var im := _img()
	for x in 16:
		var col := r.randf_range(0.7, 0.9)
		for y in 16:
			var v := col + r.randf_range(-0.06, 0.06)
			if x % 4 == 0 and r.randf() < 0.8:
				v = 0.55
			im.set_pixel(x, y, _g(v))
	return im

static func _leaves() -> Image:
	var r := RandomNumberGenerator.new()
	r.seed = 17
	var im := _img()
	for y in 16:
		for x in 16:
			var k := r.randf()
			var v := 0.85
			if k < 0.25:
				v = 0.58
			elif k < 0.4:
				v = 1.0
			im.set_pixel(x, y, _g(v))
	return im

static func _roof() -> Image:
	var r := RandomNumberGenerator.new()
	r.seed = 23
	var im := _img()
	for y in 16:
		for x in 16:
			var v := 0.85 + r.randf_range(-0.04, 0.04)
			if y % 4 == 0:
				v = 0.55
			elif (x + (2 if (y / 4) % 2 == 1 else 0)) % 4 == 0:
				v = 0.68
			im.set_pixel(x, y, _g(v))
	return im

static func _paper() -> Image:
	var im := _img()
	for y in 16:
		for x in 16:
			var v := 0.95
			if x % 8 == 0 or y % 5 == 0:
				v = 0.55
			im.set_pixel(x, y, _g(v))
	return im

# Свой узор хаори: тёмное поле, ряды белых «гребней волн» внизу, кайма.
# Цветной (не множитель): используется как есть.
static func _haori() -> Image:
	var im := Image.create(16, 32, false, Image.FORMAT_RGB8)
	var base := Color(0.13, 0.21, 0.45)
	var dark := Color(0.08, 0.13, 0.3)
	var foam := Color(0.88, 0.93, 0.98)
	var mid := Color(0.25, 0.42, 0.75)
	for y in 32:
		for x in 16:
			var c := base
			if (x + y) % 7 == 0:
				c = dark
			if y >= 14:
				# волна: дуга из пикселей, повтор каждые 8 пикселей
				var lx := x % 8
				var row := (y - 14) % 6
				var arc := [3, 1, 0, 0, 1, 3, 5, 7]
				if row == 0 and lx >= 1 and lx <= 6:
					c = foam
				elif row == 1 and (lx == 0 or lx == 7):
					c = foam
				elif row >= 2 and row <= 3 and arc[lx] <= row:
					c = mid
			if y >= 30:
				c = Color(0.06, 0.06, 0.1)
			im.set_pixel(x, y, c)
	return im

# --- ножны -----------------------------------------------------------------
# Лак: ровный, с редкими бликами.
static func _lacquer() -> Image:
	var r := RandomNumberGenerator.new()
	r.seed = 31
	var im := _img()
	for y in 16:
		for x in 16:
			var v := 0.82 + r.randf_range(-0.03, 0.03)
			if (x + y * 3) % 17 == 0:
				v = 1.0
			im.set_pixel(x, y, _g(v))
	return im

# Волны поперёк ножен.
static func _saya_wave() -> Image:
	var im := _img()
	for y in 16:
		for x in 16:
			var v := 0.72
			var wy := int(round(2.0 * sin(x * 0.785)))
			if (y + wy + 16) % 8 == 0:
				v = 1.0
			elif (y + wy + 16) % 8 == 1:
				v = 0.9
			im.set_pixel(x, y, _g(v))
	return im

# Кольца-перетяжки.
static func _saya_ring() -> Image:
	var im := _img()
	for y in 16:
		for x in 16:
			var v := 0.9
			if y % 8 == 0 or y % 8 == 1:
				v = 0.6
			im.set_pixel(x, y, _g(v))
	return im

# Ромбы, как обмотка рукояти.
static func _saya_diamond() -> Image:
	var im := _img()
	for y in 16:
		for x in 16:
			var d: int = abs((x % 8) - 4) + abs((y % 8) - 4)
			var v := 1.0 if d < 3 else 0.6
			if d == 3:
				v = 0.45
			im.set_pixel(x, y, _g(v))
	return im

# --- хаори: свои узоры (16×32, низ — кайма с мотивом, самый низ — тёмный подгиб) ---
static func _h_img() -> Image:
	return Image.create(16, 32, false, Image.FORMAT_RGB8)

# Клетка: крупные квадраты двух цветов.
static func _haori_check() -> Image:
	var im := _h_img()
	var a := Color(0.55, 0.1, 0.12)
	var b := Color(0.1, 0.09, 0.11)
	for y in 32:
		for x in 16:
			var c := a if ((x / 4) + (y / 4)) % 2 == 0 else b
			if y >= 30:
				c = Color(0.05, 0.04, 0.05)
			im.set_pixel(x, y, c)
	return im

# Пламя: тёмная ткань, снизу поднимаются языки огня.
static func _haori_flame() -> Image:
	var im := _h_img()
	var base := Color(0.12, 0.1, 0.12)
	var red := Color(0.85, 0.2, 0.08)
	var orange := Color(1.0, 0.55, 0.12)
	var yellow := Color(1.0, 0.85, 0.35)
	for y in 32:
		for x in 16:
			var c := base
			# высота языка пламени по столбцу (повтор каждые 8 пикселей)
			var lx := x % 8
			var h: int = [6, 9, 13, 16, 12, 8, 10, 7][lx]
			var from_bottom := 31 - y
			if from_bottom < h:
				c = red
				if from_bottom < h - 3:
					c = orange
				if from_bottom < h - 7:
					c = yellow
			if y >= 30:
				c = Color(0.55, 0.12, 0.05)
			im.set_pixel(x, y, c)
	return im

# Сумерки: от светлого к фиолетовому, мелкие звёзды-искры.
static func _haori_dusk() -> Image:
	var im := _h_img()
	var top := Color(0.85, 0.82, 0.92)
	var bot := Color(0.35, 0.18, 0.55)
	for y in 32:
		for x in 16:
			var k := clampf((y - 6) / 22.0, 0.0, 1.0)
			var c := top.lerp(bot, k)
			if (x * 7 + y * 13) % 29 == 0 and y > 12:
				c = Color(1.0, 0.95, 0.75)
			if y >= 30:
				c = Color(0.18, 0.08, 0.28)
			im.set_pixel(x, y, c)
	return im

# Панцирь: шестиугольная сетка (кикко).
static func _haori_shell() -> Image:
	var im := _h_img()
	var base := Color(0.32, 0.36, 0.2)
	var line := Color(0.75, 0.65, 0.3)
	for y in 32:
		for x in 16:
			var c := base
			var row := y % 8
			var lx := (x + (4 if (y / 8) % 2 == 1 else 0)) % 8
			if row == 0 and lx >= 2 and lx <= 5:
				c = line
			elif row >= 1 and row <= 3 and (lx == 1 + (row - 1) / 2 or lx == 6 - (row - 1) / 2):
				pass
			if (row == 1 or row == 7) and (lx == 1 or lx == 6):
				c = line
			if row >= 2 and row <= 6 and (lx == 0 or lx == 7):
				c = line
			if y >= 30:
				c = Color(0.15, 0.17, 0.08)
			im.set_pixel(x, y, c)
	return im

# Молнии: зигзаги на чёрном.
static func _haori_bolt() -> Image:
	var im := _h_img()
	var base := Color(0.1, 0.1, 0.13)
	var bolt := Color(1.0, 0.85, 0.2)
	for y in 32:
		for x in 16:
			var c := base
			var zig: int = [0, 1, 2, 3, 2, 1][y % 6]
			if y >= 10 and (x % 8) == 2 + zig:
				c = bolt
			if y >= 10 and (x % 8) == 3 + zig and y % 6 < 3:
				c = bolt.darkened(0.25)
			if y >= 30:
				c = Color(0.6, 0.5, 0.1)
			im.set_pixel(x, y, c)
	return im

# Сакура: бледно-розовая ткань с лепестками.
static func _haori_sakura() -> Image:
	var im := _h_img()
	var base := Color(0.95, 0.85, 0.88)
	var petal := Color(0.92, 0.45, 0.6)
	for y in 32:
		for x in 16:
			var c := base
			var cx := x % 8
			var cy := (y + (x / 8) * 4) % 8
			var d: int = abs(cx - 4) + abs(cy - 4)
			if d == 0:
				c = Color(1.0, 0.9, 0.5)
			elif d == 1 and y > 8:
				c = petal
			if y >= 30:
				c = Color(0.7, 0.3, 0.45)
			im.set_pixel(x, y, c)
	return im

# --- ещё ножны ---
# Акулья кожа: светлые зёрна.
static func _saya_shark() -> Image:
	var r := RandomNumberGenerator.new()
	r.seed = 77
	var im := _img()
	for y in 16:
		for x in 16:
			var v := 0.78 + r.randf_range(-0.04, 0.04)
			if (x + (y % 2)) % 2 == 0 and r.randf() < 0.55:
				v = 1.0
			im.set_pixel(x, y, _g(v))
	return im

# Зигзаг-молния вдоль ножен.
static func _saya_bolt() -> Image:
	var im := _img()
	for y in 16:
		for x in 16:
			var zig: int = [0, 1, 2, 3, 2, 1, 0, 1][y % 8]
			var v := 0.65
			if x % 8 == 2 + zig:
				v = 1.0
			im.set_pixel(x, y, _g(v))
	return im

# Лепестки.
static func _saya_sakura() -> Image:
	var im := _img()
	for y in 16:
		for x in 16:
			var d: int = abs((x % 8) - 3) + abs(((y + (x / 8) * 4) % 8) - 3)
			var v := 0.82
			if d <= 1:
				v = 1.0
			im.set_pixel(x, y, _g(v))
	return im

# Обмотка шнуром наискось.
static func _saya_cord() -> Image:
	var im := _img()
	for y in 16:
		for x in 16:
			var k := (x + y) % 6
			var v := 1.0 if k < 3 else 0.55
			if k == 3:
				v = 0.4
			im.set_pixel(x, y, _g(v))
	return im

# --- узоры хаори как в аниме (традиционные японские узоры), 32×32 ---
static func _w_img() -> Image:
	return Image.create(32, 32, false, Image.FORMAT_RGB8)

# Ичимацу: зелёно-чёрная шахматная клетка.
static func _haori_ichimatsu() -> Image:
	var im := _w_img()
	var g := Color(0.12, 0.5, 0.36)
	var b := Color(0.07, 0.07, 0.08)
	for y in 32:
		for x in 32:
			im.set_pixel(x, y, g if ((x / 4) + (y / 4)) % 2 == 0 else b)
	return im

# Половинки: левая — гладкий бордо, правая — черепаший узор (кикко) жёлто-зелёно-оранжевый.
static func _haori_split() -> Image:
	var im := _w_img()
	var maroon := Color(0.45, 0.1, 0.13)
	var cols := [Color(0.85, 0.7, 0.2), Color(0.3, 0.55, 0.3), Color(0.9, 0.5, 0.15)]
	var line := Color(0.12, 0.1, 0.1)
	for y in 32:
		for x in 32:
			var c := maroon
			if x >= 16:
				var cy := y / 6
				var lx := (x - 16 + (3 if cy % 2 == 1 else 0)) % 6
				var ly := y % 6
				var cell := ((x - 16 + (3 if cy % 2 == 1 else 0)) / 6 + cy) % 3
				c = cols[cell]
				if ly == 0 or lx == 0:
					c = line
			im.set_pixel(x, y, c)
	return im

# Пламя на белом: белая ткань, снизу красно-оранжевые языки огня.
static func _haori_flame_white() -> Image:
	var im := _w_img()
	var white := Color(0.95, 0.94, 0.9)
	var red := Color(0.85, 0.15, 0.08)
	var orange := Color(1.0, 0.5, 0.1)
	var yellow := Color(1.0, 0.8, 0.3)
	var hs := [8, 12, 16, 13, 9, 11, 15, 10]
	for y in 32:
		for x in 32:
			var c := white
			var h: int = hs[(x / 4) % 8] + (2 if x % 4 == 1 or x % 4 == 2 else 0)
			var fb := 31 - y
			if fb < h:
				c = red
				if fb < h - 3:
					c = orange
				if fb < h - 7:
					c = yellow
			im.set_pixel(x, y, c)
	return im

# Крылья бабочки: сверху белое, к низу — бирюза и тёмная зелень, чёрные прожилки, белые пятна.
static func _haori_butterfly() -> Image:
	var im := _w_img()
	var top := Color(0.95, 0.95, 0.97)
	var mid := Color(0.35, 0.75, 0.72)
	var bot := Color(0.12, 0.3, 0.32)
	for y in 32:
		for x in 32:
			var k := clampf((y - 6) / 24.0, 0.0, 1.0)
			var c := top.lerp(mid, minf(1.0, k * 1.6)) if k < 0.6 else mid.lerp(bot, (k - 0.6) / 0.4)
			# прожилки — расходятся веером вниз
			var vx := (x % 8) - 4
			if y > 8 and abs(vx * 8 - (y - 8) * (1 if vx > 0 else -1)) < 3 and vx != 0:
				c = Color(0.08, 0.1, 0.1)
			if y > 8 and x % 8 == 0:
				c = Color(0.08, 0.1, 0.1)
			if y > 25 and (x + y) % 9 == 0:
				c = Color(0.95, 0.95, 0.95)
			im.set_pixel(x, y, c)
	return im

# Уроко: оранжево-жёлтая ткань с рядами белых треугольников (чешуя).
static func _haori_uroko() -> Image:
	var im := _w_img()
	for y in 32:
		for x in 32:
			var k := y / 31.0
			var c := Color(1.0, 0.78, 0.2).lerp(Color(0.95, 0.5, 0.1), k)
			var row := y / 8
			var lx := (x + (4 if row % 2 == 1 else 0)) % 8
			var ly := y % 8
			# треугольник остриём вверх: ширина растёт книзу
			if abs(lx - 4) <= ly / 2 and ly > 0:
				c = Color(0.97, 0.96, 0.9)
			im.set_pixel(x, y, c)
	return im

# Полосы: чёрно-белые наискось.
static func _haori_stripes() -> Image:
	var im := _w_img()
	for y in 32:
		for x in 32:
			var c := Color(0.92, 0.92, 0.9) if ((x + y) / 4) % 2 == 0 else Color(0.1, 0.1, 0.12)
			im.set_pixel(x, y, c)
	return im

# --- демон ---
# Кожа: ровная, с тёмными прожилками-венами.
static func _demon_skin() -> Image:
	var r := RandomNumberGenerator.new()
	r.seed = 666
	var im := _img()
	for y in 16:
		for x in 16:
			im.set_pixel(x, y, _g(0.86 + r.randf_range(-0.04, 0.04)))
	for k in 3:
		var x := r.randi_range(0, 15)
		for y in 16:
			im.set_pixel(x, y, _g(0.55))
			if r.randf() < 0.4:
				x = (x + (1 if r.randf() < 0.5 else -1) + 16) % 16
	return im

# Рваное кимоно: полосы ткани и тёмные пятна.
static func _demon_robe() -> Image:
	var r := RandomNumberGenerator.new()
	r.seed = 77
	var im := _img()
	for y in 16:
		for x in 16:
			var v := 0.85 + r.randf_range(-0.05, 0.05)
			if x % 5 == 0:
				v = 0.7
			if r.randf() < 0.05:
				v = 0.5
			im.set_pixel(x, y, _g(v))
	return im
