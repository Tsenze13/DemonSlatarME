extends StaticBody3D
# Разрушаемый объект: забор, фонарь, стена дома, бочка.
# Если сила удара достаточна — рассыпается на обломки.

var brad := 1.0           # радиус для попадания
var need_power := 1       # 1 — любой удар, 2 — тяжёлый или форма
var col := Color(0.55, 0.38, 0.22)
var pieces := 8
var piece_size := 0.3
var hp := 1
var light: Light3D = null
var height := 1.0

func _ready() -> void:
	add_to_group("breakable")

func center() -> Vector3:
	return global_position + Vector3.UP * height * 0.5

# Звук материала: серое — камень, остальное — дерево/бумага.
func _mat_sound(vol: float) -> void:
	var stone := absf(col.r - col.g) < 0.05 and absf(col.g - col.b) < 0.06 and col.r > 0.4
	G.sfx.play("stone" if stone else "wood", vol)

func slash_hit(origin: Vector3, dir: Vector3, power: int) -> bool:
	if power < need_power:
		G.fx.sparks(center(), -dir, Color(1, 0.9, 0.6), 6)
		G.sfx.play("clang", -14.0, 1.6)
		_mat_sound(-8.0)
		return false
	hp -= 1
	if hp > 0:
		G.fx.debris_burst(center(), col, 2, piece_size, dir * 4.0, 2.0)
		G.sfx.play("crack", -6.0)
		_mat_sound(-4.0)
		return true
	G.fx.debris_burst(center(), col, pieces, piece_size, dir * 7.0 + Vector3.UP * 2.0, 3.5)
	G.fx.dust(global_position, 8)
	G.sfx.play("crack", -2.0, 0.8)
	_mat_sound(-2.0)
	G.add_shake(0.15)
	remove_from_group("breakable")
	queue_free()
	return true
