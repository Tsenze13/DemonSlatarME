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
		"stone": img = _stone()
		"wood": img = _planks()
		"bark": img = _bark()
		"leaves": img = _leaves()
		"roof": img = _roof()
		"paper": img = _paper()
		"cloth": img = _speckle(11, 0.86, 0.94, 0.04)
		"haori": img = _haori()
		"lacquer": img = _lacquer()
		"saya_wave": img = _saya_wave()
		"saya_ring": img = _saya_ring()
		"saya_diamond": img = _saya_diamond()
		_: img = _speckle(3, 0.8, 0.95, 0.1)
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
