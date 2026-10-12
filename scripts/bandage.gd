extends Node3D
# Бинты на парных клинках за спиной.
# Выхват: бинты разматываются от острия к гарде, лентами спадают и тут же исчезают.
# Обратно на спину: бинты по спирали наматываются от гарды к острию.

const Vox = preload("res://scripts/vox.gd")

const PER := 13                  # витков на клинок
const STEP := 0.063
const UNWRAP_TIME := 0.15
const WRAP_TIME := 0.42

var bands: Array = []            # {mi, base: Transform3D, i}
var amount := 1.0                # сколько витков на месте (0..1)
var target := 1.0
var rate := 1.0
var strips: Array = []           # спадающие ленты {n, v, w, life, max}

func _ready() -> void:
	top_level = true

# holders — узлы клинков за спиной (гарда в начале, клинок вдоль -Y), dims — [ширина, толщина].
func build(holders: Array, dims: Array) -> void:
	for b in bands:
		if is_instance_valid(b.mi):
			b.mi.queue_free()
	bands.clear()
	var mats := [Vox.cel_mat(Color(0.94, 0.92, 0.86), true, 0.0, 0.012),
		Vox.cel_mat(Color(0.84, 0.81, 0.74), true, 0.0, 0.012)]
	for k in holders.size():
		var h: Node3D = holders[k]
		var w: float = dims[k][0]
		var t: float = dims[k][1]
		for i in PER:
			var mi := MeshInstance3D.new()
			var bm := BoxMesh.new()
			bm.size = Vector3(t + 0.04, 0.074, w + 0.04)
			mi.mesh = bm
			mi.material_override = mats[(i + k) % 2]
			# виток наклонён — получается спираль вокруг клинка
			var tilt := deg_to_rad(13.0 if i % 2 == 0 else 9.0)
			var base := Transform3D(Basis(Vector3.RIGHT, tilt), Vector3(0, -0.06 - i * STEP, 0))
			mi.transform = base
			h.add_child(mi)
			bands.append({"mi": mi, "base": base, "i": i})
	_apply()

func set_full(on: bool) -> void:
	amount = 1.0 if on else 0.0
	target = amount
	_apply()

# Размотать (при выхвате). Остатки — сразу лентами вниз.
func unwrap(time := UNWRAP_TIME) -> void:
	target = 0.0
	rate = 1.0 / maxf(0.01, time)

func unwrap_now() -> void:
	target = 0.0
	_set_amount(0.0)

# Намотать (клинки вернулись на спину).
func wrap(time := WRAP_TIME) -> void:
	amount = 0.0
	target = 1.0
	rate = 1.0 / maxf(0.01, time)
	_apply()

func is_wrapped() -> bool:
	return amount >= 0.999

func visible_bands() -> int:
	var c := 0
	for b in bands:
		if b.mi.visible:
			c += 1
	return c

func _local_k(i: int, a: float) -> float:
	# от гарды (i=0) к острию: виток i на месте, когда a*PER > i+1
	return clampf(a * PER - i, 0.0, 1.0)

func _set_amount(a: float) -> void:
	if a < amount:
		# снятые витки — лентами вниз
		for b in bands:
			if _local_k(b.i, amount) > 0.0 and _local_k(b.i, a) <= 0.0 and b.mi.is_visible_in_tree():
				_spawn_strip(b.mi.global_transform)
	amount = a
	_apply()

func _apply() -> void:
	for b in bands:
		var k := _local_k(b.i, amount)
		var mi: MeshInstance3D = b.mi
		mi.visible = k > 0.0
		if k > 0.0 and k < 1.0:
			# виток подлетает, закручиваясь вокруг клинка
			var e := Vox.ease_out(k)
			var s := 1.0 + (1.0 - e) * 1.4
			mi.transform = b.base * Transform3D(Basis(Vector3.UP, (1.0 - e) * 4.0).scaled(Vector3(s, 1.0, s)), Vector3.ZERO)
		else:
			mi.transform = b.base

func _spawn_strip(xf: Transform3D) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.008, 0.034, 0.22)
	mi.mesh = bm
	mi.material_override = Vox.cel_mat(Color(0.94, 0.92, 0.86), true, 0.0, 0.01)
	mi.top_level = true
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	mi.global_transform = Transform3D(xf.basis.orthonormalized() * Basis(Vector3.UP, randf_range(-1.2, 1.2)), xf.origin)
	var out := Vector3(randf_range(-1, 1), randf_range(0.2, 1.2), randf_range(-1, 1)).normalized()
	var l := randf_range(0.28, 0.4)
	strips.append({"n": mi, "v": out * randf_range(1.5, 3.2), "w": Vector3(randf_range(-9, 9), randf_range(-14, 14), randf_range(-9, 9)),
		"life": l, "max": l})

func _process(dt: float) -> void:
	if amount != target:
		_set_amount(move_toward(amount, target, rate * dt))
	for i in range(strips.size() - 1, -1, -1):
		var s: Dictionary = strips[i]
		s.life -= dt
		var n: MeshInstance3D = s.n
		if s.life <= 0.0:
			n.queue_free()
			strips.remove_at(i)
			continue
		s.v.y -= 7.0 * dt
		s.v *= maxf(0.0, 1.0 - 2.5 * dt)
		n.global_position += s.v * dt
		n.rotate(s.w.normalized(), s.w.length() * dt)
		# лента «распускается» вдоль и тает к концу жизни
		var f: float = s.life / s.max
		var stretch := 1.0 + (1.0 - f) * 1.2
		var thin := clampf(f * 2.2, 0.0, 1.0)
		n.scale = Vector3(thin, thin, stretch * thin)
