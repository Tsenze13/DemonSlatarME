extends Node3D
# Регенерация конечности по вокселям: сначала из обрубка растёт кость
# (с костяными пальцами-когтями), на неё нарастают мышцы, сверху — кожа.
# Каждый слой — свой MultiMesh, воксели «выскакивают» по очереди сверху вниз.

const Vox = preload("res://scripts/vox.gd")

const V := 0.034                  # размер вокселя
var dur := 2.4
var t := 0.0
var layers: Array = []            # [{mm, items: [{xf, at}], from, to}]
var done := false

# len — длина предплечья вниз (−Y), w — толщина, hand_y — где кисть, skin — цвет кожи.
func build(len_: float, w: float, hand_y: float, skin: Color, bone: Color) -> void:
	var muscle := Color(0.7, 0.1, 0.14)
	var bone_items := []
	var mus_items := []
	var skin_items := []
	var n := int(round(w / V))          # вокселей поперёк
	var rows := int(ceil((len_ + 0.12) / V))
	for r in rows:
		var y := -V * (r + 0.5)
		var in_hand := -y > hand_y - 0.02
		var nw := n + (1 if in_hand else 0)
		var half := (nw - 1) * 0.5
		var order := float(r) / rows
		# кость — тонкий стержень по центру (до кисти)
		if not in_hand:
			bone_items.append({"xf": Transform3D(Basis.IDENTITY.scaled(Vector3(0.45, 1.0, 0.45)), Vector3(0, y, 0)), "at": order})
		for ix in nw:
			for iz in nw:
				var x := (ix - half) * V
				var z := (iz - half) * V
				var edge := ix == 0 or iz == 0 or ix == nw - 1 or iz == nw - 1
				var item := {"xf": Transform3D(Basis.IDENTITY, Vector3(x, y, z)), "at": clampf(order + randf_range(-0.06, 0.06), 0.0, 1.0)}
				if edge:
					skin_items.append(item)
				else:
					mus_items.append(item)
	# костяные пальцы-когти: тянутся из кисти вниз
	for k in 4:
		var fx := (k - 1.5) * 0.04
		for s in 4:
			var y2 := -hand_y - 0.06 - s * V
			bone_items.append({"xf": Transform3D(Basis.IDENTITY.scaled(Vector3(0.55, 1.0, 0.55)), Vector3(fx, y2, 0.03 + s * 0.012)), "at": 0.75 + s * 0.06})
	_layer(bone_items, bone, 0.0, 0.42)
	_layer(mus_items, muscle, 0.32, 0.7)
	_layer(skin_items, skin, 0.6, 0.94)

func _layer(items: Array, col: Color, from: float, to: float) -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	var bm := BoxMesh.new()
	bm.size = Vector3.ONE * V
	mm.mesh = bm
	mm.instance_count = items.size()
	for i in items.size():
		mm.set_instance_transform(i, Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * 0.001), (items[i].xf as Transform3D).origin))
	var mi := MultiMeshInstance3D.new()
	mi.multimesh = mm
	mi.material_override = Vox.cel_mat(col, true, 0.15, 0.01)
	add_child(mi)
	layers.append({"mm": mm, "items": items, "from": from, "to": to})

func _process(delta: float) -> void:
	if done:
		return
	t += delta
	var k := t / dur
	for L in layers:
		var mm: MultiMesh = L.mm
		var items: Array = L.items
		for i in items.size():
			var it: Dictionary = items[i]
			var appear: float = lerpf(L.from, L.to, it.at)
			var s := clampf((k - appear) / 0.04, 0.0, 1.0)
			var xf: Transform3D = it.xf
			var b := xf.basis.scaled(Vector3.ONE * maxf(0.001, s * (1.0 + 0.25 * sin(s * PI))))
			mm.set_instance_transform(i, Transform3D(b, xf.origin))
	if k >= 1.0:
		done = true

func finished() -> bool:
	return done
