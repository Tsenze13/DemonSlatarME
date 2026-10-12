extends CharacterBody3D
# Демон: гонится, бьёт когтями (можно парировать), прыгает с ударной волной
# (только уворачиваться), метает копья из крови. Регенерирует, отращивает
# отрубленные руки. Умирает только от добивания в шею.

const Vox = preload("res://scripts/vox.gd")
const Cloth = preload("res://scripts/cloth.gd")

var radius := 0.75
var max_hp := 240.0
var hp := 240.0
var state := "idle"
var state_t := 0.0
var facing := 0.0
var model: Node3D
var J := {}
var rest := {}
var meshes: Array = []
var eye_mats: Array = []
var neck_glow: MeshInstance3D
var arms_alive := {"r": true, "l": true}
var arm_regrow := {"r": 0.0, "l": 0.0}
var swings_left := 0
var swing_arm := "r"
var atk_cd := 1.0
var since_hit := 10.0
var rage := false
var noticed := false
var stagger_time := 0.0
var leap_from := Vector3.ZERO
var leap_to := Vector3.ZERO
var spears: Array = []
var flash_t := 0.0
var overlay_mat: StandardMaterial3D
var ash_t := 0.0
var ash_parts: Array = []
var head_body: RigidBody3D = null
var name_ru := "Демон-отшельник"
var hit_this_swing := false
var run_phase := 0.0
var exposed_time := 3.5
var regen_count := 0
var wounds: Array = []     # порезы: {n, life}

func _ready() -> void:
	collision_layer = 4
	collision_mask = 1
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.6
	cap.height = 2.4
	cs.shape = cap
	cs.position = Vector3(0, 1.2, 0)
	add_child(cs)
	overlay_mat = StandardMaterial3D.new()
	overlay_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	overlay_mat.albedo_color = Color(1, 1, 1, 0.85)
	overlay_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_build_model()
	G.enemies.append(self)

func _exit_tree() -> void:
	G.enemies.erase(self)

func is_dead() -> bool:
	return state == "dead"

func is_exposed() -> bool:
	return state == "exposed"

func windup_time() -> float:
	return 0.32 if rage else 0.45

func neck_pos() -> Vector3:
	return J.head.global_position

# =====================================================================
func _build_model() -> void:
	model = Node3D.new()
	add_child(model)
	model.scale = Vector3.ONE * 1.35
	var skin := Color(0.5, 0.42, 0.52)
	var skin_d := Color(0.36, 0.28, 0.4)
	var robe := Color(0.42, 0.08, 0.1)
	var robe_d := Color(0.25, 0.05, 0.08)
	var bone := Color(0.92, 0.88, 0.78)
	var hair := Color(0.88, 0.88, 0.92)
	var hips := Vox.pivot(model, Vector3(0, 0.95, 0), "hips")
	Vox.box(hips, Vector3(0.42, 0.26, 0.28), Vector3.ZERO, robe_d)
	var torso := Vox.pivot(hips, Vector3(0, 0.1, 0), "torso")
	Vox.box(torso, Vector3(0.5, 0.56, 0.3), Vector3(0, 0.3, 0), robe)
	Vox.box(torso, Vector3(0.2, 0.4, 0.04), Vector3(0, 0.36, 0.15), skin_d)   # открытая грудь
	Vox.box(torso, Vector3(0.52, 0.08, 0.32), Vector3(0, 0.05, 0), Color(0.1, 0.08, 0.1))
	# рваные полы одежды
	for i in 4:
		var x := -0.18 + i * 0.12
		Vox.box(hips, Vector3(0.1, 0.35 + (i % 2) * 0.12, 0.3), Vector3(x, -0.3, 0), robe if i % 2 == 0 else robe_d)
	var head := Vox.pivot(torso, Vector3(0, 0.6, 0.05), "head")
	Vox.box(head, Vector3(0.13, 0.1, 0.13), Vector3(0, 0.02, 0), skin_d)
	Vox.box(head, Vector3(0.32, 0.34, 0.32), Vector3(0, 0.22, 0), skin)
	Vox.box(head, Vector3(0.26, 0.08, 0.06), Vector3(0, 0.1, 0.15), Color(0.15, 0.05, 0.08), false)  # пасть
	for x in [-0.06, -0.02, 0.02, 0.06]:
		Vox.box(head, Vector3(0.025, 0.05, 0.02), Vector3(x, 0.12, 0.18), bone, false)
	for x in [-0.08, 0.08]:
		var e := Vox.box(head, Vector3(0.08, 0.05, 0.02), Vector3(x, 0.25, 0.165), Color(1.0, 0.85, 0.2), false, 2.5)
		e.material_override = e.material_override.duplicate()
		eye_mats.append(e)
	var e3 := Vox.box(head, Vector3(0.05, 0.08, 0.02), Vector3(0, 0.34, 0.165), Color(1.0, 0.3, 0.2), false, 2.5)
	e3.material_override = e3.material_override.duplicate()
	eye_mats.append(e3)
	# рога: целый и обломанный
	var horn := Vox.pivot(head, Vector3(-0.1, 0.38, 0.02))
	horn.rotation_degrees = Vector3(-20, 0, 25)
	Vox.box(horn, Vector3(0.07, 0.3, 0.07), Vector3(0, 0.15, 0), bone)
	Vox.box(horn, Vector3(0.05, 0.15, 0.05), Vector3(0.03, 0.32, -0.03), bone)
	var horn2 := Vox.pivot(head, Vector3(0.1, 0.38, 0.02))
	horn2.rotation_degrees = Vector3(-20, 0, -25)
	Vox.box(horn2, Vector3(0.07, 0.13, 0.07), Vector3(0, 0.06, 0), bone)
	Vox.box(head, Vector3(0.36, 0.12, 0.36), Vector3(0, 0.38, -0.02), hair)
	Vox.box(head, Vector3(0.36, 0.3, 0.1), Vector3(0, 0.25, -0.16), hair)
	var hair_anchor := Vox.pivot(head, Vector3(0, 0.3, -0.2), "hair")
	neck_glow = Vox.box(head, Vector3(0.2, 0.05, 0.2), Vector3(0, 0.03, 0), Color(1.0, 0.25, 0.2), false, 3.0)
	neck_glow.visible = false

	for side in ["r", "l"]:
		var sx := -1.0 if side == "r" else 1.0
		var arm := Vox.pivot(torso, Vector3(0.33 * sx, 0.5, 0), "arm_" + side)
		Vox.box(arm, Vector3(0.16, 0.42, 0.16), Vector3(0, -0.2, 0), robe)
		var fore := Vox.pivot(arm, Vector3(0, -0.4, 0), "fore_" + side)
		Vox.box(fore, Vector3(0.13, 0.42, 0.13), Vector3(0, -0.2, 0), skin)
		var hand := Vox.pivot(fore, Vector3(0, -0.44, 0), "hand_" + side)
		Vox.box(hand, Vector3(0.16, 0.12, 0.12), Vector3(0, -0.04, 0), skin_d)
		for k in 3:
			var cl := Vox.box(hand, Vector3(0.03, 0.22, 0.03), Vector3(-0.05 + k * 0.05, -0.2, 0.03), bone)
			cl.rotation_degrees = Vector3(-20, 0, 0)
		var leg := Vox.pivot(hips, Vector3(0.12 * sx, -0.08, 0), "leg_" + side)
		Vox.box(leg, Vector3(0.17, 0.44, 0.18), Vector3(0, -0.2, 0), skin_d)
		var shin := Vox.pivot(leg, Vector3(0, -0.42, 0), "shin_" + side)
		Vox.box(shin, Vector3(0.14, 0.42, 0.15), Vector3(0, -0.2, 0), skin)
		Vox.box(shin, Vector3(0.16, 0.06, 0.26), Vector3(0, -0.42, 0.05), skin_d)
	for n in ["hips", "torso", "head", "arm_r", "fore_r", "arm_l", "fore_l", "leg_r", "shin_r", "leg_l", "shin_l", "hand_r", "hand_l"]:
		J[n] = model.find_child(n, true, false)
		rest[n] = Vector3.ZERO
	_collect_meshes(model)
	# длинные белые волосы
	for i in 3:
		var c = MeshInstance3D.new()
		c.set_script(Cloth)
		c.attach = hair_anchor
		c.anchors = [Vector3(-0.12 + i * 0.12, 0, 0)]
		c.cols = 1
		c.rows = 6
		c.seg = 0.14
		c.mode = "chain"
		c.chain_size = Vector3(0.1, 0.1, 0.1)
		c.chain_col = hair
		c.gravity = 10.0
		model.add_child(c)
		c.setup()

func _collect_meshes(n: Node) -> void:
	for c in n.get_children():
		if c is MeshInstance3D:
			meshes.append(c)
		_collect_meshes(c)

# =====================================================================
func _set_state(s: String) -> void:
	state = s
	state_t = 0.0

func _physics_process(dt: float) -> void:
	if dt <= 0.0:
		return
	state_t += dt
	atk_cd -= dt
	since_hit += dt
	_update_spears(dt)
	_update_flash(dt)
	var p: Node3D = G.player
	if state == "dead":
		_dead_tick(dt)
		return
	# регенерация
	for s in ["r", "l"]:
		if not arms_alive[s]:
			arm_regrow[s] -= dt
			if arm_regrow[s] <= 0.0:
				_regrow_arm(s)
	# регенерация: пока бьют — нет, после паузы ~2 с разгоняется до 35 ед/с
	if since_hit > 2.0 and state != "exposed" and hp < max_hp:
		var rate := lerpf(8.0, 35.0, clampf((since_hit - 2.0) / 2.0, 0.0, 1.0))
		hp = minf(max_hp, hp + rate * dt)
		if randf() < dt * 6.0:
			G.fx.burst(global_position + Vector3(randf_range(-0.4, 0.4), randf_range(0.8, 2.6), randf_range(-0.4, 0.4)), Color(0.75, 0.1, 0.2), 1, 1.0, 0.07, 0.5, -1.0)
	_update_wounds(dt)
	var to := p.global_position - global_position
	to.y = 0
	var dist := to.length()
	var dirp := to.normalized() if dist > 0.01 else Vector3.FORWARD
	if p.is_dead():
		dist = 999.0
	match state:
		"idle":
			_gravity(dt)
			_brake(dt)
			if dist < 32.0:
				noticed = true
				_roar()
				_set_state("roar")
		"roar":
			_gravity(dt)
			_brake(dt)
			if state_t > 1.0:
				_set_state("chase")
		"chase":
			_gravity(dt)
			var spd := 8.0 if rage else 6.2
			if dist > 2.6:
				var hv := Vector3(velocity.x, 0, velocity.z).move_toward(dirp * spd, 30.0 * dt)
				velocity.x = hv.x
				velocity.z = hv.z
			else:
				_brake(dt)
			_face(dirp, dt, 7.0)
			if atk_cd <= 0.0 and dist < 3.4 and (arms_alive.r or arms_alive.l):
				swings_left = 3 if rage else 2
				_start_swing()
			elif atk_cd <= 0.0 and dist > 7.0 and dist < 18.0:
				if randf() < 0.5:
					_set_state("leap_wind")
					G.sfx.play("roar", -10.0, 1.4)
				else:
					_set_state("spikes")
				atk_cd = 2.5
			elif dist < 3.4 and not (arms_alive.r or arms_alive.l) and atk_cd <= 0.0:
				_set_state("leap_wind")
				atk_cd = 2.5
		"windup":
			_gravity(dt)
			_brake(dt)
			_face(dirp, dt, 10.0)
			var wt := windup_time()
			_eyes(2.5 + state_t * 12.0)
			if state_t >= wt:
				_set_state("swing")
				hit_this_swing = false
				velocity += _fwd() * 7.0
				G.sfx.play("whoosh", -3.0, 0.7)
		"swing":
			_gravity(dt)
			velocity.x = move_toward(velocity.x, 0, 30 * dt)
			velocity.z = move_toward(velocity.z, 0, 30 * dt)
			if state_t > 0.04 and not hit_this_swing:
				hit_this_swing = true
				_eyes(2.5)
				if dist < 3.6 and _fwd().dot(dirp) > 0.3 and absf(p.global_position.y - global_position.y) < 2.2:
					var r: String = p.receive_attack(15.0 if not rage else 18.0, global_position, true, self)
					if r == "parry":
						stagger(1.4)
						return
					elif r == "counter":
						return
				G.fx.slash_arc(global_position + Vector3.UP * 1.6, _fwd(), 60.0 if swing_arm == "r" else -60.0, 2.0, 120.0, 0.35,
					Color(0.6, 0.05, 0.12), Color(1.0, 0.4, 0.3), 0, 0.22, swing_arm == "l")
			if state_t > 0.22:
				swings_left -= 1
				if swings_left > 0 and dist < 4.5:
					_start_swing()
				else:
					atk_cd = 1.2 if rage else 1.8
					_set_state("recover")
		"recover":
			_gravity(dt)
			_brake(dt)
			if state_t > 0.55:
				_set_state("chase")
		"leap_wind":
			_gravity(dt)
			_brake(dt)
			_face(dirp, dt, 10.0)
			_eyes(2.5 + state_t * 8.0)
			if state_t > 0.55:
				leap_from = global_position
				leap_to = p.global_position
				var flat := leap_to - leap_from
				flat.y = 0
				var tt := 0.65
				velocity = flat / tt
				velocity.y = 0.5 * 33.0 * tt
				_set_state("leap")
				G.fx.dust(global_position, 12)
		"leap":
			velocity.y -= 33.0 * dt
			_face(Vector3(velocity.x, 0, velocity.z), dt, 10.0)
			if state_t > 0.1 and is_on_floor():
				_land_shock()
				_set_state("recover")
		"spikes":
			_gravity(dt)
			_brake(dt)
			_face(dirp, dt, 10.0)
			_eyes(2.5 + state_t * 6.0)
			if state_t > 0.6 and state_t - dt <= 0.6:
				_throw_spears(p)
			if state_t > 1.0:
				_set_state("recover")
		"stagger":
			_gravity(dt)
			velocity.x = move_toward(velocity.x, 0, 20 * dt)
			velocity.z = move_toward(velocity.z, 0, 20 * dt)
			if state_t > stagger_time:
				_set_state("chase")
				atk_cd = 0.4
		"exposed":
			_gravity(dt)
			_brake(dt)
			neck_glow.visible = int(G.real_time * 8.0) % 2 == 0
			if state_t > exposed_time:
				_regenerate()
		"locked":
			velocity = Vector3.ZERO
	move_and_slide()
	_animate(dt)

func _fwd() -> Vector3:
	return Vector3(sin(facing), 0, cos(facing))

func _gravity(dt: float) -> void:
	if is_on_floor() and velocity.y <= 0:
		velocity.y = -1.0
	else:
		velocity.y -= 33.0 * dt

func _brake(dt: float) -> void:
	velocity.x = move_toward(velocity.x, 0, 25 * dt)
	velocity.z = move_toward(velocity.z, 0, 25 * dt)

func _face(d: Vector3, dt: float, rate: float) -> void:
	if d.length() > 0.05:
		facing = lerp_angle(facing, atan2(d.x, d.z), 1.0 - exp(-rate * dt))

func _eyes(e: float) -> void:
	for m in eye_mats:
		var mat: ShaderMaterial = m.material_override
		mat.set_shader_parameter("emission", e)

func _start_swing() -> void:
	if arms_alive.r and arms_alive.l:
		swing_arm = "l" if swing_arm == "r" else "r"
	else:
		swing_arm = "r" if arms_alive.r else "l"
	_set_state("windup")
	# предупреждение: вспышка в глазах
	G.fx.burst(J.head.global_position + _fwd() * 0.3 + Vector3.UP * 0.3, Color(1.0, 0.85, 0.3), 5, 3.0, 0.1, 0.25, 0.0)

func _roar() -> void:
	G.sfx.play("roar", 0.0)
	G.add_shake(0.35)
	G.fx.ring(global_position + Vector3.UP * 1.8, 0.8, Color(0.6, 0.05, 0.12), Color(1.0, 0.4, 0.3), 0.6, 6.0, 0.3, _fwd())
	if G.hud:
		G.hud.boss_intro(name_ru)

func _land_shock() -> void:
	G.add_shake(0.55)
	G.sfx.play("boom", 0.0)
	G.fx.ring(global_position + Vector3.UP * 0.1, 0.8, Color(0.55, 0.05, 0.1), Color(1.0, 0.5, 0.35), 0.5, 4.5, 0.5)
	G.fx.dust(global_position, 20)
	G.fx.debris_burst(global_position, Color(0.4, 0.33, 0.25), 6, 0.25, Vector3.UP * 4.0, 4.0)
	var p: Node3D = G.player
	var d: float = p.global_position.distance_to(global_position)
	if d < 4.2 and p.global_position.y - global_position.y < 1.2:
		p.receive_attack(20.0, global_position, false, self)

func _throw_spears(p: Node3D) -> void:
	G.sfx.play("whoosh_big", -2.0, 0.6)
	var origin: Vector3 = J.hand_r.global_position if arms_alive.r else J.head.global_position
	for i in 3:
		var target: Vector3 = p.global_position + Vector3.UP * 1.0 + Vector3(randf_range(-1.5, 1.5), 0, randf_range(-1.5, 1.5)) * (0.0 if i == 1 else 1.0)
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.12, 0.12, 1.3)
		mi.mesh = bm
		mi.material_override = Vox.cel_mat(Color(0.6, 0.02, 0.1), true, 1.2)
		G.fx.add_child(mi)
		mi.global_position = origin + Vector3(0, 0.3 * i, 0)
		var v := (target - mi.global_position).normalized() * 21.0
		mi.look_at(mi.global_position + v, Vector3.UP)
		spears.append({"n": mi, "v": v, "life": 2.0, "delay": i * 0.12})

func _update_spears(dt: float) -> void:
	var p: Node3D = G.player
	for i in range(spears.size() - 1, -1, -1):
		var s: Dictionary = spears[i]
		if s.delay > 0.0:
			s.delay -= dt
			continue
		s.life -= dt
		var n: MeshInstance3D = s.n
		n.global_position += s.v * dt
		if randf() < 0.5:
			G.fx.burst(n.global_position, Color(0.5, 0.02, 0.08), 1, 0.5, 0.08, 0.3, 4.0)
		var hit := false
		if p and n.global_position.distance_to(p.global_position + Vector3.UP * 1.0) < 0.85:
			var r: String = p.receive_attack(9.0, n.global_position - s.v.normalized(), true, self)
			if r != "dodge" and r != "none":
				hit = true
				if r == "parry" or r == "counter":
					G.fx.sparks(n.global_position, -s.v.normalized(), Color(1.0, 0.5, 0.4), 12)
		if n.global_position.y < 0.0 or s.life <= 0.0:
			hit = true
			G.fx.blood(n.global_position, Vector3.UP, 6)
		if hit:
			n.queue_free()
			spears.remove_at(i)

# =====================================================================
# Получение урона
func take_hit(dmg: float, dir: Vector3, atk: Dictionary) -> Dictionary:
	var res := {"dmg": dmg, "point": global_position + Vector3.UP * 1.7 - dir * 0.4, "cut_limb": false}
	if state == "dead" or state == "locked":
		res.dmg = 0
		return res
	if state == "idle":
		noticed = true
		_set_state("chase")
	since_hit = 0.0
	_flash()
	if state == "exposed":
		# по открытой шее обычные удары не убивают — нужно добивание
		res.dmg = 0
		G.fx.sparks(res.point, dir, Color(1, 0.4, 0.3), 6)
		return res
	hp -= dmg
	_add_wound(res.point, dir, atk)
	var knock: float = atk.get("knock", 2.5)
	velocity += dir * knock
	velocity.y = maxf(velocity.y, 1.0 if atk.power < 2 else 3.0)
	var armored: bool = state in ["swing", "leap", "spikes"] or (state == "windup" and atk.power < 2)
	if not armored and atk.stagger > 0.0:
		stagger(atk.stagger * (0.6 if rage else 1.0))
	# отрубить руку сильным ударом
	if atk.power >= 2 and randf() < 0.35:
		var side := "r" if arms_alive.r and (randf() < 0.5 or not arms_alive.l) else ("l" if arms_alive.l else "")
		if side != "":
			_cut_arm(side, dir)
			res.cut_limb = true
	if hp <= 0.0:
		hp = 0.0
		_expose()
	return res

# Порез на теле: тёмно-красная полоса на ближайшей части тела, по линии удара.
func _add_wound(p: Vector3, dir: Vector3, atk: Dictionary) -> void:
	var best: MeshInstance3D = null
	var bd := 99.0
	for m in meshes:
		if not is_instance_valid(m) or not m.is_visible_in_tree() or not (m.mesh is BoxMesh):
			continue
		if m.mesh.size.x < 0.1 and m.mesh.size.z < 0.1:
			continue   # когти, зубы
		var d: float = m.global_position.distance_to(p + Vector3(randf_range(-0.3, 0.3), randf_range(-0.6, 0.3), 0))
		if d < bd:
			bd = d
			best = m
	if best == null:
		return
	var sz: Vector3 = best.mesh.size
	var w := MeshInstance3D.new()
	var bm := BoxMesh.new()
	var length := clampf(maxf(sz.x, sz.z) * 1.15, 0.15, 0.6)
	bm.size = Vector3(length, 0.035 if atk.power < 2 else 0.06, maxf(sz.x, sz.z) * 1.08)
	w.mesh = bm
	w.material_override = Vox.cel_mat(Color(0.55, 0.0, 0.08), false, 0.6)
	w.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	best.add_child(w)
	w.position = Vector3(0, randf_range(-sz.y * 0.35, sz.y * 0.35), 0)
	w.rotation_degrees = Vector3(0, randf_range(-30, 30), float(atk.get("roll", 0.0)) + randf_range(-15, 15))
	wounds.append({"n": w, "s": 1.0})
	if wounds.size() > 14:
		var old: Dictionary = wounds.pop_front()
		if is_instance_valid(old.n):
			old.n.queue_free()

func _update_wounds(dt: float) -> void:
	# порезы затягиваются вместе с регенерацией
	if since_hit < 2.0:
		return
	for i in range(wounds.size() - 1, -1, -1):
		var w: Dictionary = wounds[i]
		w.s -= dt * 0.5
		if not is_instance_valid(w.n) or w.s <= 0.0:
			if is_instance_valid(w.n):
				w.n.queue_free()
			wounds.remove_at(i)
			continue
		w.n.scale = Vector3(1.0, w.s, w.s)

func stagger(t: float) -> void:
	if state in ["exposed", "dead", "locked"]:
		return
	stagger_time = t
	_set_state("stagger")
	_eyes(2.5)

func _flash() -> void:
	flash_t = 0.07
	for m in meshes:
		if is_instance_valid(m):
			m.material_overlay = overlay_mat

func _update_flash(dt: float) -> void:
	if flash_t > 0.0:
		flash_t -= dt
		if flash_t <= 0.0:
			for m in meshes:
				if is_instance_valid(m):
					m.material_overlay = null

func _cut_arm(side: String, dir: Vector3) -> void:
	arms_alive[side] = false
	arm_regrow[side] = 5.0
	var arm: Node3D = J["fore_" + side]
	var rb := RigidBody3D.new()
	rb.collision_layer = 8
	rb.collision_mask = 1 | 8
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = Vector3(0.2, 0.7, 0.2)
	cs.shape = sh
	cs.position = Vector3(0, -0.35, 0)
	rb.add_child(cs)
	G.fx.add_child(rb)
	rb.global_transform = arm.global_transform
	var copy := Node3D.new()
	rb.add_child(copy)
	copy.transform = Transform3D.IDENTITY
	copy.scale = Vector3.ONE * 1.35
	for c in arm.get_children():
		if c is MeshInstance3D:
			var mi := MeshInstance3D.new()
			mi.mesh = c.mesh
			mi.material_override = c.material_override
			mi.transform = c.transform
			copy.add_child(mi)
	var hand: Node3D = J["hand_" + side]
	for c in hand.get_children():
		if c is MeshInstance3D:
			var mi2 := MeshInstance3D.new()
			mi2.mesh = c.mesh
			mi2.material_override = c.material_override
			mi2.transform = hand.transform * c.transform
			copy.add_child(mi2)
	rb.linear_velocity = dir * 6.0 + Vector3.UP * 6.0
	rb.angular_velocity = Vector3(randf_range(-12, 12), randf_range(-12, 12), randf_range(-12, 12))
	G.fx.adopt(rb, 4.5)
	arm.visible = false
	G.fx.blood(arm.global_position, dir + Vector3.UP, 24)
	G.sfx.play("hit_heavy", 0.0, 0.8)

func _regrow_arm(side: String) -> void:
	arms_alive[side] = true
	var arm: Node3D = J["fore_" + side]
	arm.visible = true
	arm.scale = Vector3.ONE * 0.1
	G.fx.blood(arm.global_position, Vector3.UP, 10)
	G.sfx.play("crack", -6.0, 0.6)

func _expose() -> void:
	_set_state("exposed")
	velocity = Vector3.ZERO
	neck_glow.visible = true
	G.slowmo(0.35, 0.4)
	G.impact(0.06, 2)
	G.sfx.play("roar", -6.0, 0.7)
	if G.hud:
		G.hud.notify("ШЕЯ ОТКРЫТА — подойди и жми ЛКМ!", 3.0)

func _regenerate() -> void:
	regen_count += 1
	hp = max_hp * 0.45
	neck_glow.visible = false
	rage = true
	_roar()
	for s in ["r", "l"]:
		if not arms_alive[s]:
			_regrow_arm(s)
	var p: Node3D = G.player
	if p.global_position.distance_to(global_position) < 4.0:
		p.receive_attack(8.0, global_position, false, self)
	_set_state("chase")
	atk_cd = 0.8
	if G.hud:
		G.hud.notify("Демон регенерировал и впал в ярость")

func finisher_lock() -> void:
	_set_state("locked")
	velocity = Vector3.ZERO
	neck_glow.visible = true

func decapitate(dir: Vector3) -> void:
	_set_state("dead")
	neck_glow.visible = false
	_eyes(0.0)
	var head: Node3D = J.head
	head_body = RigidBody3D.new()
	head_body.collision_layer = 8
	head_body.collision_mask = 1 | 8
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = Vector3(0.45, 0.45, 0.45)
	cs.shape = sh
	cs.position = Vector3(0, 0.3, 0)
	head_body.add_child(cs)
	G.fx.add_child(head_body)
	var gt := head.global_transform
	head_body.global_transform = Transform3D(Basis.IDENTITY.rotated(Vector3.UP, facing), gt.origin)
	head.get_parent().remove_child(head)
	head_body.add_child(head)
	head.global_transform = gt
	head_body.linear_velocity = dir * 4.0 + Vector3.UP * 7.0
	head_body.angular_velocity = Vector3(randf_range(-8, 8), randf_range(-4, 4), randf_range(-8, 8))
	G.fx.blood(gt.origin, dir, 30)
	G.fx.blood(gt.origin, Vector3.UP, 20)
	ash_parts.clear()
	for m in meshes:
		if is_instance_valid(m):
			ash_parts.append(m)
	ash_parts.shuffle()
	ash_t = 0.0
	G.kills += 1

func _dead_tick(dt: float) -> void:
	# тело оседает на колени и рассыпается пеплом
	velocity = Vector3.ZERO
	ash_t += dt
	J.hips.position.y = lerpf(J.hips.position.y, 0.55, 1.0 - exp(-4.0 * dt))
	J.torso.rotation_degrees = J.torso.rotation_degrees.lerp(Vector3(35, 0, 0), 1.0 - exp(-4.0 * dt))
	J.leg_r.rotation_degrees = J.leg_r.rotation_degrees.lerp(Vector3(-80, 0, 0), 1.0 - exp(-5.0 * dt))
	J.leg_l.rotation_degrees = J.leg_l.rotation_degrees.lerp(Vector3(-80, 0, 0), 1.0 - exp(-5.0 * dt))
	J.shin_r.rotation_degrees = J.shin_r.rotation_degrees.lerp(Vector3(100, 0, 0), 1.0 - exp(-5.0 * dt))
	J.shin_l.rotation_degrees = J.shin_l.rotation_degrees.lerp(Vector3(100, 0, 0), 1.0 - exp(-5.0 * dt))
	if ash_t > 0.6 and ash_parts.size() > 0:
		var per := maxi(1, int(ash_parts.size() * dt / 1.6) + 1)
		for i in per:
			if ash_parts.is_empty():
				break
			var m: MeshInstance3D = ash_parts.pop_back()
			if is_instance_valid(m) and m.visible:
				G.fx.ash(m.global_position, 5)
				m.visible = false
	if ash_t > 3.4:
		if is_instance_valid(head_body):
			G.fx.ash(head_body.global_position, 20)
			head_body.queue_free()
		for sp in spears:
			sp.n.queue_free()
		spears.clear()
		queue_free()

# =====================================================================
func _animate(dt: float) -> void:
	var p := {}
	for k in J:
		p[k] = Vector3.ZERO
	var hips_y := 0.95
	var lean := 15.0
	var sp := Vector3(velocity.x, 0, velocity.z).length()
	# сутулая стойка, длинные руки висят
	p.torso = Vector3(20, 0, 0)
	p.head = Vector3(-15, 0, 0)
	p.arm_r = Vector3(-10, 0, -12)
	p.arm_l = Vector3(-10, 0, 12)
	p.fore_r = Vector3(-20, 0, 0)
	p.fore_l = Vector3(-20, 0, 0)
	if sp > 0.8 and is_on_floor():
		run_phase += dt * (5.0 + sp * 0.8)
		var s := sin(run_phase)
		var c := cos(run_phase)
		p.leg_r = Vector3(-s * 45, 0, 0)
		p.leg_l = Vector3(s * 45, 0, 0)
		p.shin_r = Vector3(maxf(0.0, c) * 70 + 10, 0, 0)
		p.shin_l = Vector3(maxf(0.0, -c) * 70 + 10, 0, 0)
		p.arm_r = Vector3(s * 40 + 20, 0, -15)
		p.arm_l = Vector3(-s * 40 + 20, 0, 15)
		lean = 30.0
		hips_y = 0.92 - absf(c) * 0.05
	match state:
		"windup":
			var arm := "arm_" + swing_arm
			var sx := -1.0 if swing_arm == "r" else 1.0
			p[arm] = Vector3(-160, 30 * sx, 40 * sx)
			p["fore_" + swing_arm] = Vector3(-40, 0, 0)
			p.torso = Vector3(0, 30 * sx, 0)
			lean = 0.0
		"swing":
			var arm2 := "arm_" + swing_arm
			var sx2 := -1.0 if swing_arm == "r" else 1.0
			p[arm2] = Vector3(-30, -50 * sx2, 10 * sx2)
			p["fore_" + swing_arm] = Vector3(-10, 0, 0)
			p.torso = Vector3(30, -30 * sx2, 0)
			lean = 25.0
		"leap_wind":
			hips_y = 0.6
			p.leg_r = Vector3(-70, 0, 0)
			p.leg_l = Vector3(-70, 0, 0)
			p.shin_r = Vector3(110, 0, 0)
			p.shin_l = Vector3(110, 0, 0)
			p.arm_r = Vector3(40, 0, -30)
			p.arm_l = Vector3(40, 0, 30)
		"leap":
			p.arm_r = Vector3(-170, 0, -20)
			p.arm_l = Vector3(-170, 0, 20)
			p.leg_r = Vector3(-30, 0, 0)
			p.shin_r = Vector3(60, 0, 0)
		"spikes":
			p.arm_r = Vector3(-150 if state_t < 0.6 else -60, -20, -10)
			p.fore_r = Vector3(-30, 0, 0)
			lean = 5.0
		"stagger":
			lean = -20.0
			p.head = Vector3(20, 0, 0)
			p.arm_r = Vector3(-40, 0, -50)
			p.arm_l = Vector3(-40, 0, 50)
		"exposed", "locked":
			hips_y = 0.55
			p.leg_r = Vector3(-80, 0, 0)
			p.leg_l = Vector3(-80, 0, 0)
			p.shin_r = Vector3(100, 0, 0)
			p.shin_l = Vector3(100, 0, 0)
			p.torso = Vector3(40, 0, 0)
			p.head = Vector3(-30, 0, 0)
			p.arm_r = Vector3(10, 0, -10)
			p.arm_l = Vector3(10, 0, 10)
			lean = 0.0
		"roar":
			p.torso = Vector3(-15, 0, 0)
			p.head = Vector3(-35, 0, 0)
			p.arm_r = Vector3(-30, 0, -70)
			p.arm_l = Vector3(-30, 0, 70)
			lean = -10.0
	var rate := 1.0 - exp(-14.0 * dt)
	for k in J:
		if k == "hips" or not p.has(k):
			continue
		rest[k] = rest[k].lerp(p[k], rate)
		J[k].rotation_degrees = rest[k]
	J.hips.position.y = lerpf(J.hips.position.y, hips_y, rate)
	for s in ["r", "l"]:
		var f: Node3D = J["fore_" + s]
		if f.scale.x < 1.0:
			f.scale = f.scale.lerp(Vector3.ONE, 1.0 - exp(-3.0 * dt))
	model.rotation = Vector3(deg_to_rad(lean), facing, 0)
