extends StaticBody3D
# Высокий кедр (сугú) у святилища и в старом лесу: толстый ствол до 20+ м,
# хвоя — «облаками» на ветвях по спирали. На каждое облако можно встать
# (плоская коллизия сверху), с ветки на ветку — прыжками. От ствола —
# отталкиваются, как от обычного дерева. Срубить нельзя — слишком толстый.

const Vox = preload("res://scripts/vox.gd")

var height := 20.0
var trunk_w := 1.3
var pads: Array = []          # верх каждой ветки-облака (мировые координаты) — цели прыжка
var rng := RandomNumberGenerator.new()

func build(h: float, w: float, seed_: int, foliage: Color) -> void:
	height = h
	trunk_w = w
	rng.seed = seed_
	collision_layer = 1
	collision_mask = 0
	var bark := Color(0.42, 0.26, 0.18)
	# ствол — сужается кверху тремя ярусами, внизу корни
	var tiers := [[0.0, h * 0.4, w], [h * 0.4, h * 0.75, w * 0.8], [h * 0.75, h, w * 0.6]]
	for t in tiers:
		var y0: float = t[0]
		var y1: float = t[1]
		var tw: float = t[2]
		_shape(Vector3(tw, y1 - y0, tw), Vector3(0, (y0 + y1) * 0.5, 0))
		Vox.box(self, Vector3(tw, y1 - y0, tw), Vector3(0, (y0 + y1) * 0.5, 0), bark, true, 0.0, "bark")
	for k in 4:
		var a := k * PI * 0.5 + rng.randf_range(-0.3, 0.3)
		var d := Vector3(cos(a), 0, sin(a))
		Vox.box(self, Vector3(0.5, 0.7, 0.5), d * (w * 0.5 + 0.2) + Vector3.UP * 0.3, bark.darkened(0.1), true, 0.0, "bark")
	# хвойный «конус» вокруг ствола (без коллизии): ярусы-кресты сужаются кверху,
	# по краям — неровные пучки, чтобы силуэт не был стопкой плит
	var cy := h * 0.3
	while cy < h:
		var k0 := (cy - h * 0.3) / (h * 0.7)
		var cw := lerpf(3.6, 1.1, k0)
		var cf := foliage.darkened(0.22).lerp(foliage.darkened(0.06), k0)
		Vox.box(self, Vector3(cw, 0.9, cw * 0.62), Vector3.UP * cy, cf, true, 0.0, "leaves")
		Vox.box(self, Vector3(cw * 0.62, 0.9, cw), Vector3.UP * (cy + 0.1), cf.lightened(0.03), true, 0.0, "leaves")
		for q in 3:
			var a := rng.randf() * TAU
			var r := cw * rng.randf_range(0.3, 0.5)
			var sz := cw * rng.randf_range(0.25, 0.38)
			Vox.box(self, Vector3(sz, 0.6, sz), Vector3(cos(a) * r, cy - 0.25 + rng.randf() * 0.3, sin(a) * r), cf.darkened(0.08 * q), false, 0.0, "leaves")
		cy += 1.5
	# ветви с хвоей по спирали — облака, на которые можно встать
	var y := h * 0.32
	var ang := rng.randf() * TAU
	while y < h - 1.5:
		var k := (y - h * 0.32) / (h * 0.68)        # 0 внизу кроны, 1 наверху
		var reach := lerpf(3.2, 1.6, k) + rng.randf_range(-0.2, 0.3)
		for side in 2:
			var a2 := ang + side * PI + rng.randf_range(-0.4, 0.4)
			var d := Vector3(cos(a2), 0, sin(a2))
			var yy := y + side * 0.9
			var limb := Vox.box(self, Vector3(0.3, 0.3, reach), d * (reach * 0.5) + Vector3.UP * yy, bark, true, 0.0, "bark")
			limb.rotation.y = atan2(d.x, d.z)
			var ps := lerpf(3.0, 1.9, k)
			var c := d * (reach + 0.1) + Vector3.UP * (yy + 0.25)
			var fc := foliage.lerp(foliage.lightened(0.15), k).lerp(foliage.darkened(0.12), rng.randf() * 0.4)
			# облако хвои: плоская подушка (на неё встают) + пучки по краям, свисающий низ,
			# светлая «шапка» сверху — как подстриженные сосны в японских садах
			Vox.box(self, Vector3(ps, 0.6, ps * 0.8), c, fc, true, 0.0, "leaves")
			Vox.box(self, Vector3(ps * 0.8, 0.6, ps), c + Vector3(0, 0.02, 0), fc.lightened(0.03), true, 0.0, "leaves")
			for q in 4:
				var qa := q * PI * 0.5 + rng.randf_range(-0.4, 0.4)
				var qs := ps * rng.randf_range(0.28, 0.4)
				Vox.box(self, Vector3(qs, 0.5, qs), c + Vector3(cos(qa) * ps * 0.5, -0.2 + rng.randf() * 0.2, sin(qa) * ps * 0.5), fc.darkened(0.1), false, 0.0, "leaves")
			Vox.box(self, Vector3(ps * 0.7, 0.45, ps * 0.7), c + Vector3(0, -0.45, 0), fc.darkened(0.2), false, 0.0, "leaves")
			Vox.box(self, Vector3(ps * 0.5, 0.3, ps * 0.5), c + Vector3(rng.randf_range(-0.2, 0.2), 0.42, rng.randf_range(-0.2, 0.2)), fc.lightened(0.14), false, 0.0, "leaves")
			_shape(Vector3(ps, 0.6, ps), c)
			pads.append(to_global(c + Vector3.UP * 0.3))
		ang += 2.4 + rng.randf_range(-0.3, 0.3)
		y += rng.randf_range(2.2, 2.9)
	# верхушка
	var top := Vector3.UP * (h + 0.4)
	Vox.box(self, Vector3(2.0, 1.2, 2.0), top, foliage.lightened(0.12), true, 0.0, "leaves")
	Vox.box(self, Vector3(1.1, 1.0, 1.1), top + Vector3.UP * 1.0, foliage.lightened(0.2), true, 0.0, "leaves")
	_shape(Vector3(2.0, 1.2, 2.0), top)
	pads.append(to_global(top + Vector3.UP * 0.6))
	add_to_group("kick")
	add_to_group("cedar")

func _shape(size: Vector3, pos: Vector3) -> void:
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = size
	cs.shape = sh
	cs.position = pos
	add_child(cs)

func kick_info() -> Dictionary:
	return {"pos": global_position, "r": trunk_w * 0.5, "h": height}

# Удар по кедру — щепки и хвоя, но ствол не рубится.
func slash_hit(origin: Vector3, dir: Vector3, power: int) -> bool:
	G.fx.burst(global_position + Vector3.UP * 1.3, Color(0.5, 0.35, 0.2), 6, 5.0, 0.1, 0.4, 10.0, -dir, 0.6)
	G.sfx.play("wood", -4.0, 0.8)
	return false

func center() -> Vector3:
	return global_position + Vector3.UP * 1.3
