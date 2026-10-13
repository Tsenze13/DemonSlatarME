extends RefCounted
# Оружие без ножен, собранное из блоков: нагината (древковое) и
# «шар и топор на цепи». Начало координат — место хвата правой рукой,
# рабочая часть вдоль −Y (как у мечей из sword_lib), лезвие на стороне −Z.

const Vox = preload("res://scripts/vox.gd")

const NAG_TIP := 1.78           # острие нагинаты от хвата
const NAG_BASE := 1.18          # начало клинка
const AXE_BASE := 0.36          # обух топора
const AXE_TIP := 0.66

static func _tinted(c: Color, t: Color) -> Color:
	return Color(c.r * t.r, c.g * t.g, c.b * t.b)

# Нагината: красно-коричневое древко с обмотками, латунная гарда, изогнутый клинок.
static func naginata(tint := Color(1, 1, 1)) -> Node3D:
	var root := Node3D.new()
	var wood := Color(0.36, 0.13, 0.1)
	var wrap := Color(0.12, 0.1, 0.14)
	var brass := Color(0.85, 0.68, 0.3)
	var steel := _tinted(Color(0.84, 0.88, 0.94), tint)
	var edge := _tinted(Color(0.95, 0.97, 1.0), tint)
	# древко от пятки (+0.55) до гарды (−1.14)
	Vox.box(root, Vector3(0.045, 1.69, 0.045), Vector3(0, -0.295, 0), wood, true, 0.0, "wood", true)
	for y in [0.42, 0.05, -0.3, -0.75]:
		Vox.box(root, Vector3(0.052, 0.07, 0.052), Vector3(0, y, 0), wrap)
	Vox.box(root, Vector3(0.06, 0.08, 0.06), Vector3(0, 0.56, 0), brass, true, 0.15)        # пятка-исидзуки
	Vox.box(root, Vector3(0.055, 0.12, 0.055), Vector3(0, -1.08, 0), wrap)                    # обмотка у клинка
	Vox.box(root, Vector3(0.1, 0.025, 0.1), Vector3(0, -1.15, 0), brass, true, 0.2)           # гарда
	# клинок: 5 сегментов, изгиб к обуху (+Z), к острию уже
	var seg := (NAG_TIP - NAG_BASE) / 5.0
	for i in 5:
		var f := float(i) / 4.0
		var w := lerpf(0.075, 0.035, f * f)
		var y := -NAG_BASE - seg * (i + 0.5)
		var z := 0.008 + 0.06 * f * f
		var b := Vox.box(root, Vector3(0.018, seg * 1.12, w), Vector3(0, y, z), steel, true, 0.25)
		b.rotation_degrees = Vector3(-12.0 * f, 0, 0)
		var e := Vox.box(root, Vector3(0.02, seg * 1.12, 0.014), Vector3(0, y, z - w * 0.5 + 0.007), edge, false, 0.9)
		e.rotation_degrees = Vector3(-12.0 * f, 0, 0)
	return root

# Топор цепного оружия: короткая рукоять, широкое лезвие, шип на обухе, кольцо под цепь.
static func axe(tint := Color(1, 1, 1)) -> Node3D:
	var root := Node3D.new()
	var iron := _tinted(Color(0.38, 0.38, 0.42), tint)
	var edge := _tinted(Color(0.9, 0.92, 0.96), tint)
	var wood := Color(0.3, 0.2, 0.14)
	Vox.box(root, Vector3(0.05, 0.78, 0.05), Vector3(0, -0.27, 0), wood, true, 0.0, "wood", true)
	Vox.box(root, Vector3(0.06, 0.18, 0.06), Vector3(0, 0.02, 0), Color(0.15, 0.12, 0.12))      # обмотка хвата
	Vox.box(root, Vector3(0.07, 0.07, 0.07), Vector3(0, 0.15, 0), iron, true, 0.1)            # кольцо под цепь
	# лезвие — расширяется к краю (−Z)
	Vox.box(root, Vector3(0.035, 0.2, 0.1), Vector3(0, -0.53, -0.06), iron, true, 0.15)
	Vox.box(root, Vector3(0.03, 0.3, 0.1), Vector3(0, -0.53, -0.15), iron, true, 0.15)
	Vox.box(root, Vector3(0.032, 0.34, 0.03), Vector3(0, -0.53, -0.21), edge, true, 0.6)
	# шип на обухе
	Vox.box(root, Vector3(0.04, 0.06, 0.12), Vector3(0, -0.53, 0.08), iron, true, 0.1)
	Vox.box(root, Vector3(0.6 * 0.04, 0.6 * 0.06, 0.06), Vector3(0, -0.53, 0.16), iron, true, 0.1)
	# навершие
	Vox.box(root, Vector3(0.07, 0.04, 0.07), Vector3(0, -0.67, 0), iron, true, 0.1)
	return root

# Шар с шипами.
static func ball(tint := Color(1, 1, 1)) -> Node3D:
	var root := Node3D.new()
	var iron := _tinted(Color(0.3, 0.3, 0.34), tint)
	var spike := _tinted(Color(0.75, 0.75, 0.8), tint)
	Vox.box(root, Vector3(0.34, 0.34, 0.34), Vector3.ZERO, iron, true, 0.1)
	var b2 := Vox.box(root, Vector3(0.3, 0.3, 0.3), Vector3.ZERO, iron.lightened(0.1), true, 0.1)
	b2.rotation_degrees = Vector3(45, 45, 0)
	for d in [Vector3.RIGHT, Vector3.LEFT, Vector3.UP, Vector3.DOWN, Vector3.FORWARD, Vector3.BACK]:
		var sp := Vox.box(root, Vector3(0.07, 0.07, 0.12), d * 0.22, spike, true, 0.3)
		sp.transform = Transform3D(Basis.looking_at(d, Vector3.UP if absf(d.y) < 0.9 else Vector3.RIGHT), d * 0.22)
	for d in [Vector3(1, 1, 1), Vector3(-1, 1, -1), Vector3(1, -1, -1), Vector3(-1, -1, 1)]:
		var dn: Vector3 = d.normalized()
		var sp2 := Vox.box(root, Vector3(0.06, 0.06, 0.1), dn * 0.2, spike, true, 0.3)
		sp2.transform = Transform3D(Basis.looking_at(dn, Vector3.UP), dn * 0.2)
	# ушко под цепь
	Vox.box(root, Vector3(0.06, 0.08, 0.06), Vector3(0, 0.2, 0), iron.darkened(0.2))
	return root
