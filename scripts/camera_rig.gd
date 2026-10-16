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
var invert_y := false
var base_fov := 72.0
var fov_kick := 0.0
var fov_s := 72.0          # мгновенное расширение обзора (взрывной рывок)

func kick_fov(v: float) -> void:
	fov_kick = maxf(fov_kick, v)
var auto_cam := true
var idle_look := 9.0          # сколько секунд камеру не трогали
var flick := 0.0              # резкий рывок мышью при захвате — смена цели
var flick_t := 0.0

func handle_input(e: InputEvent) -> void:
	if e is InputEventMouseMotion and (Input.mouse_mode == Input.MOUSE_MODE_CAPTURED or G.autotest):
		var p: Node = G.player
		if p and p.lock_target:
			# при захвате мышь не крутит камеру, а резким движением переключает цель
			flick += e.relative.x
			if absf(flick) > 260.0:
				p.switch_lock(signf(flick))
				flick = 0.0
			return
		yaw -= e.relative.x * sens * sens_mult
		pitch = clampf(pitch - e.relative.y * sens * sens_mult * (-1.0 if invert_y else 1.0), -1.2, 0.55)
		if e.relative.length() > 2.0:
			idle_look = 0.0

func cinematic(target: Node, dur: float) -> void:
	cine_target = target
	cine_t = dur
	cine_side = 1.0 if randf() < 0.5 else -1.0

func _process(_delta: float) -> void:
	var dt: float = G.rdt
	var p: Node3D = G.player
	if p == null:
		return
	idle_look += dt
	flick = move_toward(flick, 0.0, 900.0 * dt)
	flick_t -= dt
	var jx := Input.get_joy_axis(0, JOY_AXIS_RIGHT_X)
	var jy := Input.get_joy_axis(0, JOY_AXIS_RIGHT_Y)
	if p.lock_target:
		# стик при захвате — смена цели
		if absf(jx) > 0.8 and flick_t <= 0.0:
			p.switch_lock(signf(jx))
			flick_t = 0.4
	else:
		if absf(jx) > 0.15:
			yaw -= jx * 2.8 * sens_mult * dt
			idle_look = 0.0
		if absf(jy) > 0.15:
			pitch = clampf(pitch - jy * 1.8 * sens_mult * (-1.0 if invert_y else 1.0) * dt, -1.2, 0.55)
			idle_look = 0.0
	var target := p.global_position + Vector3(0, 1.55, 0)
	# лёжа и при смерти камера ниже
	if p.state in ["down", "dead"]:
		target.y -= 0.7
	# на бегу камера сама заходит за спину, если её давно не трогали
	if auto_cam and G.started and idle_look > 1.2 and p.state == "move" and p.last_speed > 4.0:
		yaw = lerp_angle(yaw, p.facing + PI, 1.0 - exp(-1.4 * dt))
	# бег по стене: камера отходит от стены, чтобы видеть героя
	if p.state == "wallrun" and not p.wall_vertical:
		target += p.wall_n * 0.9 + Vector3.UP * 0.3
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
		fov_s = cam.fov
		return

	var b := Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, pitch)
	var sp: float = p.last_speed
	var d := dist + clampf(sp - 12.0, 0.0, 20.0) * 0.06
	# в бою с захватом цели — отойти, чтобы и герой, и демон были в кадре
	if p.lock_target and is_instance_valid(p.lock_target):
		var ed: float = p.global_position.distance_to(p.lock_target.global_position)
		d += clampf(ed * 0.3, 0.0, 3.0)
	var desired := target + b * Vector3(0, 0, d)
	# шар-проба от героя к камере: камера не залезает в стены
	var sq := PhysicsShapeQueryParameters3D.new()
	sq.shape = _probe
	sq.transform = Transform3D(Basis.IDENTITY, target)
	sq.motion = desired - target
	sq.collision_mask = 1 | 16
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
	var fov := base_fov + clampf(sp - 12.0, 0.0, 22.0) * 0.8
	if p.state in ["dash", "flash"]:
		fov += 8.0
	fov_kick = move_toward(fov_kick, 0.0, 30.0 * dt)
	fov_s = lerpf(fov_s, fov, 1.0 - exp(-8.0 * dt))
	cam.fov = minf(fov_s + fov_kick, 110.0)
