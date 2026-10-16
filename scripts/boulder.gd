extends StaticBody3D
# Огромный валун с верёвкой симэнава — последнее испытание обучения.
# Лёгкие удары отскакивают искрами. Тяжёлый удар — 1 трещина, форма — 2, последняя форма — 4.
# Набрал HP_MAX трещин — валун разваливается надвое по косой линии разреза.

const Vox = preload("res://scripts/vox.gd")
const HP_MAX := 10
var hp := HP_MAX
var brad := 3.0
var height := 6.0
var split := false
var half_a: Node3D
var half_b: Node3D
var cracks: Node3D
var split_t := -1.0
var cut_axis := Vector3(0.6, 0.0, -0.8)    # вдоль чего проходит плоскость разреза (наклонная)

func _ready() -> void:
	add_to_group("breakable")
	add_to_group("nobake")

func center() -> Vector3:
	return global_position + Vector3.UP * height * 0.5

# Валун — две половины (по разные стороны косого разреза); пока цел — стоят вплотную.
func build() -> void:
	var cs := CollisionShape3D.new()
	var sh := CylinderShape3D.new()
	sh.radius = 2.7
	sh.height = height
	cs.shape = sh
	cs.position = Vector3(0, height * 0.5, 0)
	add_child(cs)
	half_a = Node3D.new()
	half_b = Node3D.new()
	add_child(half_a)
	add_child(half_b)
	cracks = Node3D.new()
	add_child(cracks)
	# вокселями: шар неровный, слой за слоем; клетка попадает в ту половину, по какую сторону плоскости
	var cell := 0.6
	var nrm := cut_axis.cross(Vector3(0.25, 1, 0)).normalized()
	var r := RandomNumberGenerator.new()
	r.seed = 77
	for iy in 10:
		var y := (iy + 0.5) * cell
		var ky := y / height
		var rad := 2.95 * sqrt(clampf(1.0 - pow((ky - 0.38) / 0.66, 2.0), 0.04, 1.0))
		for ix in range(-5, 6):
			for iz in range(-5, 6):
				var p := Vector3(ix * cell, y, iz * cell)
				if Vector2(p.x, p.z).length() > rad + r.randf_range(-0.2, 0.2):
					continue
				var shade := 0.5 + r.randf_range(-0.05, 0.05) + ky * 0.06
				var col := Color(shade, shade, shade + 0.03)
				if iy == 0:
					col = col.darkened(0.15)
				if r.randf() < 0.08 and iy > 4:
					col = Color(0.3, 0.42, 0.25)          # мох
				var side := nrm.dot(p - Vector3(0, height * 0.5, 0)) > 0.0
				Vox.box(half_a if side else half_b, Vector3(cell, cell, cell) * 1.02, p, col, true, 0.0, "stone")
	# симэнава: толстая верёвка с бумажными молниями-сидэ
	var rope_y := height * 0.6
	for i in 24:
		var a := TAU * i / 24.0
		var rr := 2.75
		var holder := half_a if nrm.dot(Vector3(cos(a) * rr, rope_y - height * 0.5, sin(a) * rr)) > 0.0 else half_b
		var seg := Vox.box(holder, Vector3(0.28, 0.28, 0.85), Vector3(cos(a) * rr, rope_y, sin(a) * rr), Color(0.85, 0.75, 0.5), true, 0.0, "wood")
		seg.rotation.y = -a
		if i % 4 == 0:
			for k in 3:
				var sd := Vox.box(holder, Vector3(0.22, 0.2, 0.03), Vector3(cos(a) * (rr + 0.12), rope_y - 0.25 - k * 0.2, sin(a) * (rr + 0.12)), Color(0.97, 0.96, 0.92), false, 0.2)
				sd.rotation.y = -a + PI * 0.5
				sd.position.x += (0.08 if k % 2 == 0 else -0.08) * sin(a)
	# сотни блоков → по мешу на половину
	var all := func(_m) -> bool: return true
	Vox.bake(half_a, all, 1000.0)
	Vox.bake(half_b, all, 1000.0)

func slash_hit(_origin: Vector3, dir: Vector3, power: int) -> bool:
	if split:
		return false
	var p = G.player
	var a: Dictionary = p.atk if p and p.state == "attack" else {}
	var form := bool(a.get("form", false))
	var dmg := 0
	if bool(a.get("final", false)):
		dmg = 4
	elif form:
		dmg = 2
	elif power >= 2:
		dmg = 1
	var hitp := center() - dir * 2.2 + Vector3(randf_range(-0.6, 0.6), randf_range(-0.8, 0.6), randf_range(-0.6, 0.6))
	if dmg == 0:
		G.fx.sparks(hitp, -dir, Color(1, 0.9, 0.6), 10)
		G.sfx.play("clang", -8.0, 1.5)
		G.sfx.play("stone", -8.0)
		if G.hud:
			G.hud.notify("Камень не поддаётся: тяжёлый удар (ПКМ) или форма дыхания", 2.0)
		return false
	hp -= dmg
	_add_crack(hitp, dir)
	G.fx.debris_burst(hitp, Color(0.52, 0.52, 0.55), 3 + dmg * 2, 0.22, dir * 4.0 + Vector3.UP * 2.0, 2.5)
	G.fx.dust(hitp, 6)
	G.sfx.play("stone", -2.0)
	G.sfx.play("crack", -6.0, 0.8)
	G.add_shake(0.12 + dmg * 0.05)
	if G.hud:
		G.hud.notify("Валун: трещин %d/%d" % [HP_MAX - maxi(hp, 0), HP_MAX], 1.6)
	if hp <= 0:
		_split(dir)
	return true

# Трещина: ломаная тёмная линия на поверхности со стороны удара.
func _add_crack(hitp: Vector3, dir: Vector3) -> void:
	var lp := to_local(hitp)
	var d := Vector3(-dir.z, 0, dir.x).normalized()
	var cur := lp
	for k in 5:
		var nxt := cur + (d * randf_range(0.25, 0.45) + Vector3.UP * randf_range(-0.35, 0.35))
		var mid := (cur + nxt) * 0.5
		var ln := cur.distance_to(nxt)
		var m := Vox.box(cracks, Vector3(0.07, 0.07, ln + 0.05), mid, Color(0.12, 0.1, 0.1), false)
		m.look_at_from_position(mid, nxt, Vector3.UP if absf((nxt - cur).normalized().y) < 0.95 else Vector3.RIGHT)
		m.position = mid
		cur = nxt

func _split(dir: Vector3) -> void:
	split = true
	remove_from_group("breakable")
	split_t = 0.0
	var c := center()
	G.slowmo(0.15, 1.4)
	G.impact(0.12, 3)
	G.do_flash(0.5, Color(1, 1, 1))
	G.add_shake(0.8)
	G.fx.cut_flash(c, Vector3(0.25, 1, 0).normalized(), Color(1, 1, 1), 6.0)
	G.fx.dust(global_position, 30)
	G.fx.cracks(global_position, 9, 4.0)
	G.sfx.play("crack", 0.0, 0.6)
	G.sfx.play("stone", 0.0, 0.7)
	if G.hud:
		G.hud.big_text("ВАЛУН РАЗРУБЛЕН")
	cracks.visible = false
	for ch in get_children():
		if ch is CollisionShape3D:
			ch.queue_free()
	# у каждой половины своя коллизия — по ним можно ходить
	for hh in [half_a, half_b]:
		var sb := StaticBody3D.new()
		var cs := CollisionShape3D.new()
		var sh := BoxShape3D.new()
		sh.size = Vector3(2.6, height * 0.9, 2.6)
		cs.shape = sh
		cs.position = Vector3(0, height * 0.45, 0)
		sb.add_child(cs)
		hh.add_child(sb)

func _process(_dt: float) -> void:
	if split_t < 0.0 or split_t > 2.0:
		return
	split_t += G.rdt                     # в реальном времени: разлом идёт и в замедлении
	# половины расходятся по нормали разреза, одна заваливается
	var nrm := cut_axis.cross(Vector3(0.25, 1, 0)).normalized()
	var k := Vox.ease_out(clampf(split_t / 1.2, 0.0, 1.0))
	half_a.position = nrm * 2.0 * k + Vector3.DOWN * 0.35 * k
	half_b.position = -nrm * 0.6 * k
	half_a.rotation = Vector3.ZERO
	half_a.rotate(cut_axis.normalized(), -0.8 * k)
	half_b.rotation = Vector3.ZERO
	half_b.rotate(cut_axis.normalized(), 0.14 * k)
	# пыль из-под заваливающейся половины
	if split_t > 0.7 and split_t - G.rdt <= 0.7:
		G.fx.dust(global_position + nrm * 2.5, 24)
		G.add_shake(0.4)
		G.sfx.play("stone", 0.0, 0.5)
