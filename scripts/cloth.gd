extends MeshInstance3D
# Ткань и пряди на физике точек (verlet): верхний ряд пришит к телу,
# остальное болтается от движения, гравитации и ветра.
# mode "sheet" — полотно (хаори), "chain" — цепочка блоков (хвост волос, ленты).

const Vox = preload("res://scripts/vox.gd")

var attach: Node3D               # к чему пришито (торс / голова)
var anchors: Array = []          # точки крепления: Vector3 в attach или [узел, Vector3]
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
var push_ellipse := Vector2.ZERO # ненулевой — ткань обтекает тело по эллипсу (rx, rz)
var stiff := 0.0                 # 0..1: насколько ткань держит форму (меньше полощется)
var rest_h: Array = []
var rest_b: Array = []
var max_lift := 0.3              # ткань не задирается выше уровня крепления (на голову не залетает)
var lift_ref: Node3D             # в чьей системе считать «вверх» для max_lift (по умолчанию attach).
                                 # Для хаори — модель героя: при наклоне корпуса (тяжёлый удар)
                                 # «низ» корпуса смотрит вперёд, и ткань загоняло под живот
var thick := 0.04                # толщина ткани в режиме "blocks"
var u_step := 0.25               # сколько текстуры по ширине на одну клетку
var v_from := 0.0                # какая часть узора по высоте приходится на полотно
var v_to := 1.0
var chain_size := Vector3(0.1, 0.1, 0.1)
var chain_col := Color.BLACK
var chain_taper := 0.6
var iters := 5                   # итераций связей за кадр (больше — плотнее ткань)
var bend_w := 0.0                # жёсткость поперёк (полотно не складывается гармошкой)
# Разрезы по бокам: столбец c — двойник c-1 (то же крепление), ниже slit_row
# они не связаны — перед и спинка развеваются отдельно.
var slit_cols: Array = []
var slit_row := 2
# Капсулы тела, которые ткань обтекает: [узел, точка A, точка B, радиус, (режим)] (A, B — в узле).
var colliders: Array = []
# Разрывы: {столбец клетки: {"r0": с какого ряда, "life": сколько держится}}.
var tears := {}
var u_of: Array = []
var lining_side := 0             # сторона подкладки у полотна (см. _cell)
var vn := PackedVector3Array()    # сглаженные нормали в узлах
var home := PackedVector2Array()  # куда выталкивать каждый столбец (направление его крепления)              # координата узора у каждого столбца

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
	rest_h.clear()
	u_of.clear()
	var uc := 0
	for c in cols:
		rest_h.append(0.0 if c == 0 else _aw(c).distance_to(_aw(c - 1)))
		if c > 0 and not slit_cols.has(c):
			uc += 1
		u_of.append(uc * u_step)
	rest_b.clear()
	for c in cols:
		rest_b.append(0.0 if c < 2 else _aw(c).distance_to(_aw(c - 2)))
	reset()
	if mode == "sheet" or mode == "blocks":
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

func _aw(c: int) -> Vector3:
	var a = anchors[c]
	if a is Array:
		return a[0].to_global(a[1])
	return attach.to_global(a)

func reset() -> void:
	for c in cols:
		var a: Vector3 = _aw(c)
		var down := -attach.global_transform.basis.y.normalized()
		for r in rows:
			var p := a + down * seg * r
			pos[_idx(c, r)] = p
			prev[_idx(c, r)] = p

func _physics_process(dt: float) -> void:
	if dt <= 0.0 or attach == null or pos.size() == 0:
		return
	t += dt
	dt = minf(dt, 1.0 / 30.0)
	# сбросить при телепорте
	var a0: Vector3 = _aw(0)
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
	_update_tears(dt)
	var inv := attach.global_transform.affine_inverse()
	var lxf: Transform3D = (lift_ref if lift_ref else attach).global_transform
	var linv := lxf.affine_inverse()
	for it in iters:
		for c in cols:
			pos[_idx(c, 0)] = _aw(c)
		for c in cols:
			for r in range(1, rows):
				_constrain(_idx(c, r - 1), _idx(c, r), seg, r - 1 == 0)
				if stiff > 0.0 and r >= 2:
					_constrain_soft(_idx(c, r - 2), _idx(c, r), seg * 2.0, stiff)
				if c > 0 and _linked(c - 1, r):
					_constrain(_idx(c - 1, r), _idx(c, r), rest_h[c], false)
				if bend_w > 0.0 and c >= 2 and _linked(c - 2, r) and _linked(c - 1, r):
					_constrain_soft(_idx(c - 2, r), _idx(c, r), rest_b[c], bend_w)
		_collide()
		# не пускать ткань внутрь тела и не давать ей задраться к голове
		if it == 0 and push_ellipse != Vector2.ZERO:
			home.resize(cols)
			for c in cols:
				var la: Vector3 = inv * _aw(c)
				var hv := Vector2(la.x / push_ellipse.x, la.z / push_ellipse.y)
				home[c] = hv.normalized() if hv.length() > 0.001 else Vector2(0, -1)
		for c in cols:
			var anchor_y: float = (linv * _aw(c)).y
			for r in range(1, rows):
				var i := _idx(c, r)
				var ll: Vector3 = linv * pos[i]
				var top_y := anchor_y - seg * r * max_lift
				if ll.y > top_y:
					ll.y = top_y
					pos[i] = lxf * ll
				var lp: Vector3 = inv * pos[i]
				if lp.y >= push_y_max:
					continue
				if push_ellipse != Vector2.ZERO:
					var q := Vector2(lp.x / push_ellipse.x, lp.z / push_ellipse.y)
					var ql := q.length()
					if ql < 1.0:
						# выталкивать на свою сторону: спинку — назад, полы — вперёд.
						# Иначе при наклоне корпуса спинка проходила через центр
						# и её выбрасывало вперёд, под живот (хаори «исчезало»)
						var hm := home[c]
						if ql < 0.001 or q.dot(hm) < 0.3 * ql:
							q = hm
							ql = 1.0
						q = q / ql
						lp.x = q.x * push_ellipse.x
						lp.z = q.y * push_ellipse.y
						pos[i] = attach.global_transform * lp
				elif (lp.z - push_plane_z) * push_dir < 0.0:
					lp.z = push_plane_z
					pos[i] = attach.global_transform * lp
	_no_stretch()
	_draw_cloth()

# Защита от растягивания (после всех связей и столкновений): каждый ряд не дальше
# длины клетки от ряда выше (идём от крепления вниз), а поперечные связи — не длиннее
# 1,15 нормы. Поправка уходит и в prev — растяжение не превращается в рывок скорости.
func _no_stretch() -> void:
	var lim := seg * 1.04
	for c in cols:
		for r in range(1, rows):
			var i := _idx(c, r)
			var j := _idx(c, r - 1)
			var d := pos[i] - pos[j]
			var l := d.length()
			if l > lim:
				var np: Vector3 = pos[j] + d / l * lim
				prev[i] += np - pos[i]
				pos[i] = np
	if mode != "blocks" and mode != "sheet":
		return
	for r in range(1, rows):
		for c in range(1, cols):
			if not _linked(c - 1, r) or rest_h[c] < 0.001:
				continue
			var a := _idx(c - 1, r)
			var b := _idx(c, r)
			var d2 := pos[b] - pos[a]
			var l2 := d2.length()
			var mx: float = rest_h[c] * 1.15
			if l2 > mx:
				var corr := d2 / l2 * (l2 - mx) * 0.5
				pos[a] += corr
				pos[b] -= corr
				prev[a] += corr
				prev[b] -= corr

# Связаны ли столбцы c и c+1 в ряду r (разрез сбоку или разрыв — нет).
func _linked(c: int, r: int) -> bool:
	if slit_cols.has(c + 1) and r >= slit_row:
		return false
	if tears.has(c) and r >= tears[c].r0:
		return false
	return true

# Ткань обтекает ноги (капсулы): точку выталкивает на поверхность.
func _collide() -> void:
	for cl in colliders:
		var n: Node3D = cl[0]
		if not is_instance_valid(n):
			continue
		var a: Vector3 = n.to_global(cl[1])
		var b: Vector3 = n.to_global(cl[2])
		# 5-й элемент "behind": капсула работает, только когда ушла за спину
		# (локти при замахе), иначе висящая рядом рука спорила бы с тканью
		if cl.size() > 4 and cl[4] == "behind":
			var mid: Vector3 = attach.global_transform.affine_inverse() * ((a + b) * 0.5)
			if mid.z > -0.12:
				continue
		var rad: float = cl[3] + thick * 0.5
		var ab := b - a
		var l2 := ab.length_squared()
		for c in cols:
			for r in range(1, rows):
				var i := _idx(c, r)
				var p := pos[i]
				var t := clampf((p - a).dot(ab) / l2, 0.0, 1.0) if l2 > 0.0 else 0.0
				var q := a + ab * t
				var d := p - q
				var dl := d.length()
				if dl < rad:
					if dl < 0.0001:
						d = Vector3.BACK
						dl = 1.0
					pos[i] = q + d / dl * rad

# Толчок: ткань получает скорость v (м/с); низ ткани — сильнее.
func impulse(v: Vector3) -> void:
	if pos.size() == 0:
		return
	for c in cols:
		for r in range(1, rows):
			var k := 0.4 + 0.6 * float(r) / maxf(1.0, rows - 1)
			prev[_idx(c, r)] -= v * prev_dt * k

# Ткань раскрывается колоколом: толчок от оси крепления наружу (приземление, вращение).
func flare(k: float, swirl := 0.0) -> void:
	if pos.size() == 0:
		return
	var o := attach.global_position
	for c in cols:
		for r in range(1, rows):
			var i := _idx(c, r)
			var d := pos[i] - o
			d.y = 0.0
			if d.length() < 0.001:
				continue
			d = d.normalized()
			var v := d * k + Vector3.UP.cross(d) * swirl
			prev[i] -= v * prev_dt * (0.3 + 0.7 * float(r) / maxf(1.0, rows - 1))

# Разрыв ткани от удара: ближайшая к точке клетка расходится от этого ряда до низа.
# Через life секунд разрыв зашивается сверху вниз.
func tear(wp: Vector3, life := 20.0) -> bool:
	if pos.size() == 0 or rows < 3:
		return false
	var best := -1
	var br := 0
	var bd := 99.0
	for c in cols - 1:
		if slit_cols.has(c + 1):
			continue
		for r in range(1, rows - 1):
			var m := (pos[_idx(c, r)] + pos[_idx(c + 1, r)]) * 0.5
			var d := m.distance_to(wp)
			if d < bd:
				bd = d
				best = c
				br = r
	if best < 0:
		return false
	tears[best] = {"r0": maxi(1, br), "life": life}
	impulse(Vector3(0, 2.0, 0))
	return true

func tear_count() -> int:
	return tears.size()

func mend() -> void:
	tears.clear()

func _update_tears(dt: float) -> void:
	for c in tears.keys():
		var tr: Dictionary = tears[c]
		tr.life -= dt
		if tr.life <= 0.0:
			# зашивается: ряд за рядом
			tr.r0 += 1
			tr.life = 0.35
			if tr.r0 >= rows:
				tears.erase(c)

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

func _constrain_soft(i: int, j: int, rest: float, k: float) -> void:
	var d := pos[j] - pos[i]
	var l := d.length()
	if l < 0.0001 or l > rest:
		return
	var diff := (l - rest) / l * k
	pos[i] += d * diff * 0.5
	pos[j] -= d * diff * 0.5

func _draw_cloth() -> void:
	global_transform = Transform3D.IDENTITY
	if mode == "blocks":
		_draw_blocks()
		return
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

# Каждая клетка ткани — толстая плитка: лицо, изнанка и четыре торца.
func _draw_blocks() -> void:
	im.clear_surfaces()
	im.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	var h := thick * 0.5
	# нормали в узлах — среднее соседних клеток: ткань — цельная толстая пластина,
	# свет по ней идёт плавно, без тёмных полос между клетками
	vn.resize(cols * rows)
	vn.fill(Vector3.ZERO)
	for c in cols - 1:
		if slit_cols.has(c + 1) and rest_h[c + 1] < 0.001:
			continue
		for r in rows - 1:
			if not _linked(c, r + 1):
				continue
			var ia := _idx(c, r)
			var ib := _idx(c + 1, r)
			var ic := _idx(c, r + 1)
			var id := _idx(c + 1, r + 1)
			var fn := (pos[ib] - pos[ia]).cross(pos[ic] - pos[ia]) + (pos[id] - pos[ic]).cross(pos[id] - pos[ib])
			vn[ia] += fn
			vn[ib] += fn
			vn[ic] += fn
			vn[id] += fn
	# двойники в разрезе выше разреза — одна точка: общая нормаль
	for sc in slit_cols:
		for r in slit_row:
			var s2: Vector3 = vn[_idx(sc, r)] + vn[_idx(sc - 1, r)]
			vn[_idx(sc, r)] = s2
			vn[_idx(sc - 1, r)] = s2
	for i in vn.size():
		vn[i] = vn[i].normalized() if vn[i].length() > 0.000001 else Vector3.ZERO
	for c in cols - 1:
		if slit_cols.has(c + 1) and rest_h[c + 1] < 0.001:
			continue
		for r in rows - 1:
			var a := pos[_idx(c, r)]
			var b := pos[_idx(c + 1, r)]
			var cc := pos[_idx(c, r + 1)]
			var d := pos[_idx(c + 1, r + 1)]
			var u0: float = u_of[c]
			var u1: float = u_of[c] + u_step
			if not _linked(c, r + 1):
				# разрыв: края расходятся, от каждого свисает рваный лоскут
				var w0: float = rest_h[c + 1] * 0.22
				var rl := (b - a).normalized() if (b - a).length() > 0.001 else Vector3.RIGHT
				var rl2 := (d - cc).normalized() if (d - cc).length() > 0.001 else rl
				var jag := 0.7 + 0.3 * float((c * 7 + r * 3) % 3)
				var um := u0 + u_step * 0.5
				if _linked(c, r):
					# верх разрыва — клетка расходится углом
					var mt := (a + b) * 0.5
					_cell(a, mt, cc, cc + rl2 * w0 * jag, u0, um, r, h, _free_l(c, r), true)
					_cell(mt, b, d - rl2 * w0 * (1.6 - jag * 0.5), d, um, u1, r, h, true, _free_r(c, r))
				else:
					_cell(a, a + rl * w0, cc, cc + rl2 * w0 * jag, u0, u0 + u_step * 0.22, r, h, _free_l(c, r), true)
					_cell(b - rl * w0, b, d - rl2 * w0 * (1.6 - jag * 0.5), d, u1 - u_step * 0.22, u1, r, h, true, _free_r(c, r))
				continue
			_cell(a, b, cc, d, u0, u1, r, h, _free_l(c, r), _free_r(c, r), [vn[_idx(c, r)], vn[_idx(c + 1, r)], vn[_idx(c, r + 1)], vn[_idx(c + 1, r + 1)]])
	im.surface_end()

# Торцы клетки рисуются только на свободных краях (край полы, разрез, разрыв) —
# между соседними клетками тёмных щелей нет, ткань выглядит цельной.
func _free_l(c: int, r: int) -> bool:
	if c == 0:
		return true
	if slit_cols.has(c):
		return r >= slit_row
	return not _linked(c - 1, r + 1)

func _free_r(c: int, r: int) -> bool:
	if c + 1 >= cols - 1:
		return true
	if slit_cols.has(c + 2):
		return r >= slit_row
	return not _linked(c + 1, r + 1)

func _cell(a: Vector3, b: Vector3, cc: Vector3, d: Vector3, u0: float, u1: float, r: int, h: float, side_l := true, side_r := true, ns: Array = []) -> void:
	var n := (b - a).cross(cc - a)
	if n.length() < 0.000001:
		n = (cc - d).cross(b - d)
		if n.length() < 0.000001:
			return
	n = n.normalized()
	var na: Vector3 = n
	var nb: Vector3 = n
	var nc: Vector3 = n
	var nd: Vector3 = n
	if ns.size() == 4:
		na = ns[0] if ns[0] != Vector3.ZERO else n
		nb = ns[1] if ns[1] != Vector3.ZERO else n
		nc = ns[2] if ns[2] != Vector3.ZERO else n
		nd = ns[3] if ns[3] != Vector3.ZERO else n
	var v0 := lerpf(v_from, v_to, float(r) / (rows - 1))
	var v1 := lerpf(v_from, v_to, float(r + 1) / (rows - 1))
	var fa := a + na * h
	var fb := b + nb * h
	var fc := cc + nc * h
	var fd := d + nd * h
	var ba := a - na * h
	var bb := b - nb * h
	var bc := cc - nc * h
	var bd := d - nd * h
	var side := Color(0.55, 0.55, 0.6)
	# lining_side: на какой стороне подкладка (+1 — по нормали, −1 — против, 0 — узор с обеих)
	_quad_n(fa, fb, fc, fd, na, nb, nc, nd, u0, u1, v0, v1, Color(1, 1, 1, 0.0 if lining_side > 0 else 1.0))
	_quad_n(bb, ba, bd, bc, -nb, -na, -nd, -nc, u1, u0, v0, v1, Color(1, 1, 1, 0.0 if lining_side < 0 else 1.0))
	if side_l:
		_quad(ba, fa, bc, fc, (a - b).normalized(), u0, u0, v0, v1, side)
	if side_r:
		_quad(fb, bb, fd, bd, (b - a).normalized(), u1, u1, v0, v1, side)
	if r == rows - 2:
		_quad(fc, fd, bc, bd, (cc - a).normalized(), u0, u1, v1, v1, side)

func _quad_n(p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3, n0: Vector3, n1: Vector3, n2: Vector3, n3: Vector3, u0: float, u1: float, v0: float, v1: float, col: Color) -> void:
	for t in [[p0, n0, u0, v0], [p1, n1, u1, v0], [p2, n2, u0, v1], [p1, n1, u1, v0], [p3, n3, u1, v1], [p2, n2, u0, v1]]:
		im.surface_set_normal(t[1])
		im.surface_set_color(col)
		im.surface_set_uv(Vector2(t[2], t[3]))
		im.surface_add_vertex(t[0])

func _quad(p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3, n: Vector3, u0: float, u1: float, v0: float, v1: float, col: Color) -> void:
	var nn := n.normalized()
	for t in [[p0, u0, v0], [p1, u1, v0], [p2, u0, v1], [p1, u1, v0], [p3, u1, v1], [p2, u0, v1]]:
		im.surface_set_normal(nn)
		im.surface_set_color(col)
		im.surface_set_uv(Vector2(t[1], t[2]))
		im.surface_add_vertex(t[0])
