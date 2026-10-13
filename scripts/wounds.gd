extends RefCounted
# Порезы внутри текстуры (по вокселям) на блоках персонажей.
# store — словарь {MeshInstance3D: [порезы]} у каждого персонажа.
# Порез: плоскость разреза в локальных координатах блока, длина вдоль линии и ширина;
# заживая, ширина уменьшается — разрез затягивается пиксель за пикселем.

const MAX_CUTS := 8

# Есть ли у блока материал, умеющий показывать порезы.
static func can_cut(mi: MeshInstance3D) -> bool:
	var m := mi.material_override
	return m is ShaderMaterial and (m as ShaderMaterial).shader != null and (m as ShaderMaterial).shader.resource_path.ends_with("cel.gdshader")

# wp — точка попадания, line — направление линии разреза, fwd — куда шёл удар (мир).
static func add(store: Dictionary, mi: MeshInstance3D, wp: Vector3, line: Vector3, fwd: Vector3, width: float, length: float, life: float) -> void:
	if not can_cut(mi):
		return
	if not store.has(mi):
		mi.material_override = mi.material_override.duplicate()
		store[mi] = []
	var inv := mi.global_transform.affine_inverse()
	var lc: Vector3 = inv * wp
	# плоскость разреза — та, по которой прошёл клинок: содержит линию и направление удара
	var nw := line.cross(fwd)
	if nw.length() < 0.01:
		nw = line.cross(Vector3.UP)
	var ln: Vector3 = (inv.basis * nw.normalized()).normalized()
	var list: Array = store[mi]
	list.append({"n": ln, "d": ln.dot(lc), "c": lc, "len": length, "w0": width, "w": width, "life": life, "max": life})
	if list.size() > MAX_CUTS:
		list.pop_front()
	_upload(mi, list)

# Заживление: heal_rate — доля ширины в секунду (0 — не заживает), life тикает всегда.
static func update(store: Dictionary, dt: float, heal_rate: float) -> void:
	for mi in store.keys():
		if not is_instance_valid(mi):
			store.erase(mi)
			continue
		var list: Array = store[mi]
		var changed := false
		for i in range(list.size() - 1, -1, -1):
			var c: Dictionary = list[i]
			c.life -= dt
			if heal_rate > 0.0:
				c.w -= c.w0 * heal_rate * dt
				changed = true
			elif c.life < 3.0:
				c.w = c.w0 * maxf(0.0, c.life / 3.0)
				changed = true
			if c.w <= 0.0 or c.life <= 0.0:
				list.remove_at(i)
				changed = true
		if changed:
			_upload(mi, list)

static func count(store: Dictionary) -> int:
	var n := 0
	for mi in store:
		n += (store[mi] as Array).size()
	return n

static func clear(store: Dictionary) -> void:
	for mi in store.keys():
		if is_instance_valid(mi):
			_upload(mi, [])
	store.clear()

static func _upload(mi: MeshInstance3D, list: Array) -> void:
	var m := mi.material_override as ShaderMaterial
	if m == null:
		return
	var pl := PackedVector4Array()
	var cc := PackedVector4Array()
	var ww := PackedFloat32Array()
	for i in MAX_CUTS:
		if i < list.size():
			var c: Dictionary = list[i]
			pl.append(Vector4(c.n.x, c.n.y, c.n.z, c.d))
			cc.append(Vector4(c.c.x, c.c.y, c.c.z, c.len))
			ww.append(c.w)
		else:
			pl.append(Vector4.ZERO)
			cc.append(Vector4.ZERO)
			ww.append(0.0)
	m.set_shader_parameter("cut_n", list.size())
	m.set_shader_parameter("cut_pl", pl)
	m.set_shader_parameter("cut_c", cc)
	m.set_shader_parameter("cut_w", ww)
