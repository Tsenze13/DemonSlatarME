extends Node3D
# Шар на цепи: точка на физике, привязанная к кольцу топора верёвкой длины `length`.
# В ударе герой «ведёт» шар по траектории (driven + drive), иначе шар свободен:
# висит, раскачивается, волочится по земле.

const Vox = preload("res://scripts/vox.gd")

var anchor := Vector3.ZERO
var length := 2.6
var pos := Vector3.ZERO
var vel := Vector3.ZERO
var driven := false
var drive := Vector3.ZERO
var ball: Node3D
var spin := Vector3.ZERO

func setup(b: Node3D) -> void:
	top_level = true
	if ball:
		ball.queue_free()
	ball = b
	ball.top_level = true
	add_child(ball)
	reset()

func reset() -> void:
	pos = anchor + Vector3(0, -minf(length, 1.0), 0)
	vel = Vector3.ZERO

func _physics_process(dt: float) -> void:
	if dt <= 0.0 or not is_visible_in_tree():
		return
	dt = minf(dt, 1.0 / 30.0)
	if pos.distance_to(anchor) > length + 6.0:
		reset()
	if driven:
		var np := pos.lerp(drive, 1.0 - exp(-35.0 * dt))
		vel = (np - pos) / dt
		pos = np
	else:
		vel.y -= 22.0 * dt
		vel *= maxf(0.0, 1.0 - 0.9 * dt)
		pos += vel * dt
		var d := pos - anchor
		var l := d.length()
		if l > length:
			var n := d / l
			pos = anchor + n * length
			var out := vel.dot(n)
			if out > 0.0:
				vel -= n * out
		if pos.y < 0.2:
			pos.y = 0.2
			vel.y = maxf(vel.y, 0.0)
			vel.x *= 0.92
			vel.z *= 0.92
	spin = spin.lerp(Vector3(vel.z, 0, -vel.x) * 0.6, 0.1)
	ball.global_position = pos
	ball.rotate(Vector3.RIGHT, spin.x * dt)
	ball.rotate(Vector3.FORWARD, spin.z * dt)
