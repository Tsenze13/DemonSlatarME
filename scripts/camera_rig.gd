extends Node3D
# Камера от третьего лица: мышь/стик, захват цели, обход стен,
# расширение обзора на скорости, тряска, кинематографичный облёт при добивании.

var yaw := 0.0
var pitch := -0.3
var dist := 5.2
var cam: Camera3D
var sens := 0.0026
var cur_pos := Vector3.ZERO
var cine_target: Node = null
var cine_t := 0.0
var cine_side := 1.0
var _inited := false
var _probe := SphereShape3D.new()

func _ready() -> void:
	_probe.radius = 0.35
	cam = Camera3D.new()
	cam.fov = 72.0
	cam.near = 0.1
	cam.far = 420.0
	add_child(cam)
	cam.current = true

var sens_mult := 1.0

func handle_input(e: InputEvent) -> void:
	if e is InputEventMouseMotion and (Input.mouse_mode == Input.MOUSE_MODE_CAPTURED or G.autotest):
		yaw -= e.relative.x * sens * sens_mult
		pitch = clampf(pitch - e.relative.y * sens * sens_mult, -1.2, 0.55)

func cinematic(target: Node, dur: float) -> void:
	cine_target = target
	cine_t = dur
	cine_side = 1.0 if randf() < 0.5 else -1.0

func _process(_delta: float) -> void:
	var dt: float = G.rdt
	var p: Node3D = G.player
	if p == null:
		return
	var jx := Input.get_joy_axis(0, JOY_AXIS_RIGHT_X)
	var jy := Input.get_joy_axis(0, JOY_AXIS_RIGHT_Y)
	if absf(jx) > 0.15:
		yaw -= jx * 2.8 * dt
	if absf(jy) > 0.15:
		pitch = clampf(pitch - jy * 1.8 * dt, -1.2, 0.55)
	var target := p.global_position + Vector3(0, 1.55, 0)
	var lock: Node = p.lock_target
	if lock and is_instance_valid(lock):
		var to: Vector3 = lock.global_position - p.global_position
		to.y = 0
		if to.length() > 0.5:
			var want := atan2(-to.x, -to.z)
			yaw = lerp_angle(yaw, want, 1.0 - exp(-6.0 * dt))
			target = target.lerp(lock.global_position + Vector3.UP * 1.5, 0.22)

	var shake_off := Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * G.shake * 0.32

	if cine_t > 0.0 and cine_target and is_instance_valid(cine_target):
		cine_t -= dt
		var c: Vector3 = cine_target.global_position + Vector3.UP * 2.0
		var pp := p.global_position + Vector3.UP * 1.2
		var axis := (c - pp)
		axis.y = 0
		axis = axis.normalized()
		var side := axis.cross(Vector3.UP) * cine_side
		var k := 1.0 - cine_t / 2.2
		var mid := (c + pp) * 0.5
		var orbit := side.rotated(Vector3.UP, k * 0.9 * cine_side)
		var cp := mid + orbit * 5.0 + Vector3.UP * (0.2 + k * 0.8)
		cur_pos = cur_pos.lerp(cp, 1.0 - exp(-10.0 * dt)) if _inited else cp
		cam.global_position = cur_pos + shake_off
		cam.look_at(mid + Vector3.UP * 0.3, Vector3.UP)
		cam.fov = lerpf(cam.fov, 58.0, 1.0 - exp(-6.0 * dt))
		return

	var b := Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, pitch)
	var sp: float = p.last_speed
	var d := dist + clampf(sp - 12.0, 0.0, 20.0) * 0.06
	var desired := target + b * Vector3(0, 0, d)
	# шар-проба от героя к камере: камера не залезает в стены
	var sq := PhysicsShapeQueryParameters3D.new()
	sq.shape = _probe
	sq.transform = Transform3D(Basis.IDENTITY, target)
	sq.motion = desired - target
	sq.collision_mask = 1
	var frac := get_world_3d().direct_space_state.cast_motion(sq)
	if frac.size() > 0 and frac[0] < 1.0:
		desired = target + (desired - target) * maxf(0.12, frac[0])
	if not _inited:
		cur_pos = desired
		_inited = true
	cur_pos = cur_pos.lerp(desired, 1.0 - exp(-22.0 * dt))
	if desired.distance_to(target) < cur_pos.distance_to(target):
		cur_pos = desired
	cam.global_position = cur_pos + shake_off
	if cam.global_position.distance_to(target) > 0.05:
		cam.look_at(target + shake_off * 0.5, Vector3.UP)
	var fov := 72.0 + clampf(sp - 12.0, 0.0, 22.0) * 0.8
	if p.state in ["dash", "flash"]:
		fov += 8.0
	cam.fov = lerpf(cam.fov, fov, 1.0 - exp(-8.0 * dt))
