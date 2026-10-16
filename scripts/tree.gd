extends StaticBody3D
# Дерево или бамбук: от ствола можно оттолкнуться в прыжке,
# а сильным ударом — срубить, верхушка падает по направлению удара.

const Vox = preload("res://scripts/vox.gd")

var height := 7.0
var trunk_w := 0.6
var kind := "tree"
var cut := false
var cut_h := 1.1
var top: Node3D
var shape: BoxShape3D
var cshape: CollisionShape3D
var brad := 0.5
var need_power := 1
var col_trunk := Color(0.36, 0.24, 0.16)

func build(h: float, w: float, k: String, foliage_col: Color) -> void:
	height = h
	trunk_w = w
	kind = k
	brad = w * 0.5 + 0.3
	collision_layer = 1
	collision_mask = 0
	cshape = CollisionShape3D.new()
	shape = BoxShape3D.new()
	shape.size = Vector3(w, h, w)
	cshape.shape = shape
	cshape.position = Vector3(0, h * 0.5, 0)
	add_child(cshape)
	var stump_col := col_trunk if k == "tree" else Color(0.42, 0.6, 0.25)
	Vox.box(self, Vector3(w, cut_h, w), Vector3(0, cut_h * 0.5, 0), stump_col, true, 0.0, "bark")
	top = Node3D.new()
	top.position = Vector3(0, cut_h, 0)
	add_child(top)
	var th := h - cut_h
	if k == "tree":
		Vox.box(top, Vector3(w, th, w), Vector3(0, th * 0.5, 0), col_trunk, true, 0.0, "bark", true)
		# крона из нескольких блоков
		var base := th * 0.55
		var fc := foliage_col
		Vox.box(top, Vector3(3.4, 1.6, 3.4), Vector3(0, base + 0.6, 0), fc.darkened(0.2), true, 0.0, "leaves", true)
		Vox.box(top, Vector3(2.6, 1.4, 2.6), Vector3(0.3, base + 1.9, -0.2), fc, true, 0.0, "leaves", true)
		Vox.box(top, Vector3(1.6, 1.1, 1.6), Vector3(-0.2, base + 3.0, 0.2), fc.lightened(0.12), true, 0.0, "leaves", true)
		Vox.box(top, Vector3(1.4, 0.9, 1.2), Vector3(1.4, base + 1.0, 0.9), fc.darkened(0.08), true, 0.0, "leaves", true)
		Vox.box(top, Vector3(1.2, 0.8, 1.4), Vector3(-1.3, base + 1.3, -0.8), fc.darkened(0.12), true, 0.0, "leaves", true)
	else:
		# бамбук: зелёный ствол с узлами и листьями наверху
		var c := Color(0.42, 0.62, 0.25)
		Vox.box(top, Vector3(w, th, w), Vector3(0, th * 0.5, 0), c, true, 0.0, "bark", true)
		var y := 0.9
		while y < th:
			Vox.box(top, Vector3(w * 1.25, 0.08, w * 1.25), Vector3(0, y, 0), c.darkened(0.3), false)
			y += 1.3
		Vox.box(top, Vector3(1.2, 0.5, 1.2), Vector3(0.2, th - 0.3, 0), Color(0.35, 0.58, 0.2))
		Vox.box(top, Vector3(0.9, 0.4, 0.9), Vector3(-0.3, th - 1.2, 0.2), Color(0.4, 0.65, 0.22))
	add_to_group("breakable")
	add_to_group("kick")

func center() -> Vector3:
	return global_position + Vector3.UP * 1.3

func kick_info() -> Dictionary:
	return {"pos": global_position, "r": trunk_w * 0.5, "h": cut_h if cut else height}

func slash_hit(origin: Vector3, dir: Vector3, power: int) -> bool:
	if cut:
		return false
	if kind == "tree" and power < 2:
		G.fx.burst(center(), Color(0.5, 0.35, 0.2), 6, 5.0, 0.1, 0.4, 10.0, -dir, 0.6)
		G.fx.leaves(global_position + Vector3.UP * (height * 0.7), 4)
		G.sfx.play("crack", -10.0, 1.3)
		G.sfx.play("wood", -4.0)
		return false
	cut = true
	remove_from_group("breakable")
	remove_from_group("kick")
	shape.size = Vector3(trunk_w, cut_h, trunk_w)
	cshape.position = Vector3(0, cut_h * 0.5, 0)
	# верхушка становится падающим телом
	var rb := RigidBody3D.new()
	rb.collision_layer = 8
	rb.collision_mask = 1 | 8
	rb.mass = 30.0 if kind == "tree" else 6.0
	var th := height - cut_h
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = Vector3(trunk_w, th, trunk_w)
	cs.shape = sh
	cs.position = Vector3(0, th * 0.5, 0)
	rb.add_child(cs)
	rb.center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
	rb.center_of_mass = Vector3(0, th * 0.55, 0)
	G.fx.add_child(rb)
	rb.global_transform = top.global_transform
	rb.global_position += Vector3.UP * 0.08
	var gt := top.global_transform
	top.get_parent().remove_child(top)
	rb.add_child(top)
	top.global_transform = gt
	var d := Vector3(dir.x, 0, dir.z).normalized()
	rb.linear_velocity = d * 2.0 + Vector3.UP * 1.0
	rb.angular_velocity = Vector3.UP.cross(d) * (1.2 if kind == "tree" else 2.5)
	G.fx.adopt(rb, 25.0)
	G.fx.burst(center(), Color(0.85, 0.75, 0.55), 14, 7.0, 0.1, 0.5, 9.0, d, 0.8)
	G.fx.leaves(global_position + Vector3.UP * height * 0.8, 16)
	G.sfx.play("crack", 0.0, 0.7)
	return true
