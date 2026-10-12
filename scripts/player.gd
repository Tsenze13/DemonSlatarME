extends CharacterBody3D
# Охотник на демонов: быстрый мувмент (рывок, шаг-вспышка, бег по стенам,
# отталкивание от деревьев), комбо клинка, тяжёлый удар, парирование,
# три формы дыхания Прилива, восстановление дыхания и добивание.

const Vox = preload("res://scripts/vox.gd")
const Trail = preload("res://scripts/trail.gd")
const Cloth = preload("res://scripts/cloth.gd")
const Tex = preload("res://scripts/tex.gd")
const SwordLib = preload("res://scripts/sword_lib.gd")
const Whip = preload("res://scripts/whip.gd")

# --- движение ---
const RUN_SPEED := 13.5
const SPRINT_SPEED := 24.0        # бег на дыхании (держать Shift после рывка)
const SPRINT_COST := 6.0          # дыхания в секунду
const ACCEL := 70.0
const AIR_ACCEL := 30.0
const JUMP_V := 11.5
const GRAV := 33.0
const DASH_SPEED := 34.0
const DASH_TIME := 0.17
const WALLRUN_TIME := 1.2
const FLASH_DIST := 10.0
const HIP_Y := 0.92
const IDLE_ARM := Vector3(-18, -12, -8)
const IDLE_FORE := -50.0
const SWORD_TILT := Vector3(-28, 0, 0)   # клинок вперёд от кулака, а не продолжение руки

# --- атаки ---
# arm0/arm1 — поворот правой руки (градусы) в начале и конце взмаха,
# fore — сгиб локтя, tw — поворот корпуса, spin — оборот всего тела.
const ATK := {
	"l1": {"dur": 0.34, "hit0": 0.09, "hit1": 0.17, "dmg": 8, "range": 3.1, "arc": 140, "lunge": 9.0,
		"power": 1, "stagger": 0.3, "hitstop": 0.055, "shake": 0.12, "next": "l2",
		"arm0": Vector3(-85, -110, 0), "arm1": Vector3(-80, 95, 0), "fore0": -15, "fore1": -5, "tw0": -40, "tw1": 40,
		"fx": "slash", "roll": 8},
	"l2": {"dur": 0.34, "hit0": 0.08, "hit1": 0.16, "dmg": 8, "range": 3.1, "arc": 140, "lunge": 8.0,
		"power": 1, "stagger": 0.3, "hitstop": 0.055, "shake": 0.12, "next": "l3",
		"arm0": Vector3(-75, 100, 0), "arm1": Vector3(-85, -115, 0), "fore0": -20, "fore1": -5, "tw0": 40, "tw1": -45,
		"fx": "slash", "roll": -10, "rev": true},
	"l3": {"dur": 0.4, "hit0": 0.1, "hit1": 0.19, "dmg": 10, "range": 3.2, "arc": 120, "lunge": 9.0,
		"power": 1, "stagger": 0.35, "hitstop": 0.065, "shake": 0.16, "next": "l4",
		"arm0": Vector3(-175, -45, 0), "arm1": Vector3(-15, 35, 0), "fore0": -10, "fore1": 0, "tw0": -25, "tw1": 25,
		"fx": "slash", "roll": 65, "wr": 0.0},
	"l4": {"dur": 0.55, "hit0": 0.12, "hit1": 0.3, "dmg": 15, "range": 3.6, "arc": 360, "lunge": 11.0,
		"power": 2, "stagger": 0.6, "hitstop": 0.09, "shake": 0.3, "next": "",
		"arm0": Vector3(-90, -100, 0), "arm1": Vector3(-90, 100, 0), "fore0": 0, "fore1": 0, "tw0": -30, "tw1": 30,
		"spin": 1.0, "fx": "wave_ring", "knock": 9.0},
	"air": {"dur": 0.38, "hit0": 0.08, "hit1": 0.17, "dmg": 10, "range": 3.3, "arc": 130, "lunge": 4.0,
		"power": 1, "stagger": 0.35, "hitstop": 0.06, "shake": 0.15, "next": "air",
		"arm0": Vector3(-200, 0, 0), "arm1": Vector3(-15, 0, 0), "fore0": 0, "fore1": 0, "tw0": 0, "tw1": 0,
		"fx": "slash", "roll": 90, "air": true, "wr": 0.0},
	"dslash": {"dur": 0.42, "hit0": 0.05, "hit1": 0.16, "dmg": 16, "range": 3.6, "arc": 160, "lunge": 26.0,
		"power": 2, "stagger": 0.5, "hitstop": 0.08, "shake": 0.25, "next": "l3",
		"arm0": Vector3(-60, 120, 0), "arm1": Vector3(-90, -120, 0), "fore0": -10, "fore1": 0, "tw0": 50, "tw1": -50,
		"fx": "slash", "roll": -5, "rev": true},
	"heavy": {"dur": 0.78, "hit0": 0.4, "hit1": 0.5, "dmg": 24, "range": 3.7, "arc": 150, "lunge": 7.0,
		"power": 2, "stagger": 0.8, "hitstop": 0.11, "shake": 0.45, "next": "",
		"arm0": Vector3(-200, 0, 0), "arm1": Vector3(-10, 0, 0), "fore0": -20, "fore1": 0, "tw0": -10, "tw1": 5,
		"fx": "heavy", "roll": 90, "knock": 7.0, "guard": true, "wr": 0.0},
	# Прилив, первая форма — Веерный срез: рывок и широкая волна
	"f1": {"dur": 0.66, "hit0": 0.16, "hit1": 0.34, "dmg": 30, "range": 5.6, "arc": 220, "lunge": 24.0,
		"power": 2, "stagger": 1.0, "hitstop": 0.12, "shake": 0.5, "next": "",
		"arm0": Vector3(-90, -130, 0), "arm1": Vector3(-85, 125, 0), "fore0": -10, "fore1": 0, "tw0": -60, "tw1": 60,
		"fx": "wave_big", "breath": 25.0, "cd": 2.5, "form": true, "impact": true, "knock": 10.0},
	# вторая форма — Водоворот: прыжок с вращением, много ударов
	"f2": {"dur": 0.95, "hit0": 0.12, "hit1": 0.78, "dmg": 8, "range": 4.4, "arc": 360, "lunge": 6.0,
		"power": 2, "stagger": 0.4, "hitstop": 0.04, "shake": 0.14, "next": "",
		"arm0": Vector3(-95, -90, 0), "arm1": Vector3(-95, -90, 0), "fore0": 0, "fore1": 0, "tw0": 0, "tw1": 0,
		"spin": 2.5, "fx": "whirl", "breath": 30.0, "cd": 4.0, "form": true, "multi": 0.11, "jump": 10.0},
	# добивающий / контр-удар
	"counter": {"dur": 0.5, "hit0": 0.02, "hit1": 0.12, "dmg": 32, "range": 3.6, "arc": 200, "lunge": 0.0,
		"power": 2, "stagger": 1.2, "hitstop": 0.12, "shake": 0.5, "next": "",
		"arm0": Vector3(-80, 120, 0), "arm1": Vector3(-90, -120, 0), "fore0": 0, "fore1": 0, "tw0": 60, "tw1": -60,
		"fx": "wave_big", "impact": true, "knock": 8.0, "rev": true},
	# удар из ножен: выхват и срез одним движением
	"iai": {"dur": 0.46, "hit0": 0.07, "hit1": 0.17, "dmg": 24, "range": 3.6, "arc": 170, "lunge": 0.0,
		"power": 2, "stagger": 0.7, "hitstop": 0.1, "shake": 0.3, "next": "l3",
		"arm0": Vector3(-10, 75, 25), "arm1": Vector3(-88, -125, 0), "fore0": -30, "fore1": 0, "tw0": 55, "tw1": -55,
		"fx": "slash", "roll": -4, "rev": true, "impact_light": true},
	"ripple": {"dur": 0.45, "hit0": 0.08, "hit1": 0.18, "dmg": 10, "range": 4.8, "arc": 120, "lunge": 14.0,
		"power": 1, "stagger": 0.4, "hitstop": 0.06, "shake": 0.15, "next": "",
		"arm0": Vector3(-30, 60, 0), "arm1": Vector3(-90, -60, 0), "fore0": 0, "fore1": 0, "tw0": 30, "tw1": -30,
		"fx": "wave", "roll": -15, "rev": true},
}

var hp := 100.0
var max_hp := 100.0
var breath := 100.0
var max_breath := 100.0
var dash_charges := 2.0
var state := "move"
var state_t := 0.0
var facing := 0.0
var spawn_pos := Vector3(0, 1, 8)

var model: Node3D
var J := {}          # суставы
var rest := {}       # текущие повороты (сглаживание)
var blade_base: Node3D
var blade_tip: Node3D
var trail
var cloths: Array = []

var atk := {}
var atk_name := ""
var atk_dir := Vector3.FORWARD
var hit_set := {}
var multi_t := 0.0
var combo_queued := ""
var last_atk_end := -10.0
var air_jumps := 1
var wall_n := Vector3.ZERO
var wall_vertical := false
var invuln_t := 0.0
var lock_target: Node = null
var run_phase := 0.0
var flip_t := 0.0
var flip_axis := 1.0
var dust_t := 0.0
var ghost_t := 0.0
var flash_window := 0.0
var counter_window := 0.0
var cd := {"f1": 0.0, "f2": 0.0, "f3": 0.0}
var buf := {}
var hurt_dir := Vector3.ZERO
var fin_target: Node = null
var fin_stage := 0
var breathe_fx_t := 0.0
var msg_cb: Callable
var last_speed := 0.0
var hits_total := 0
var drawn := false              # клинок в руке или в ножнах
var sheathed_hilt: Node3D
var sheath_node: Node3D
var sword_vis: Node3D
var sword_index := 0              # пункт меню: 0..5 катаны, 6 парные, 7 хлыст, 8 / -1 — свой кубический
var saya_style := 0               # вид ножен (SwordLib.SAYA)
var blade_tint := 0               # цвет клинка (SwordLib.TINTS)
var sword_mode := "katana"         # katana | dual | whip | proc
var sword_l: Node3D
var sword_l_vis: Node3D
var back_sheath: Node3D
var scabbard_node: Node3D
var whip
var whip_anchor: Node3D
var trail_l
var grip_w := 0.0                  # вес двуручного хвата (IK обеих рук + положение меча)
var left_w := 0.0                  # вес левой руки на рукояти
var sprinting := false
var draw_swapped := false
var iai_dist := 8.0               # длина рывка при выхвате-ударе
const IAI_MAX := 8.0
const IAI_TIME := 0.1
var draw_from_drawn := false
var auto_sprint := false
var sprint_fx_t := 0.0
var landing_vel := 0.0

func _ready() -> void:
	collision_layer = 2
	collision_mask = 1
	floor_snap_length = 0.3
	floor_max_angle = deg_to_rad(50)
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.35
	cap.height = 1.7
	cs.shape = cap
	cs.position = Vector3(0, 0.85, 0)
	add_child(cs)
	_build_model()
	trail = MeshInstance3D.new()
	trail.set_script(Trail)
	add_child(trail)
	trail.set_colors(Color(0.95, 0.98, 1.0), Color(0.25, 0.6, 1.0))
	trail_l = MeshInstance3D.new()
	trail_l.set_script(Trail)
	add_child(trail_l)
	trail_l.set_colors(Color(0.95, 0.98, 1.0), Color(0.25, 0.6, 1.0))
	whip = Node3D.new()
	whip.set_script(Whip)
	whip.anchor = whip_anchor
	add_child(whip)
	whip.setup()
	set_sword(sword_index)
	global_position = spawn_pos
	facing = PI
	set_drawn(false)

# =====================================================================
# МОДЕЛЬ
# =====================================================================
func _build_model() -> void:
	model = Node3D.new()
	model.name = "Model"
	add_child(model)
	var skin := Color(0.96, 0.8, 0.68)
	var uni := Color(0.11, 0.12, 0.18)      # униформа охотника
	var belt := Color(0.92, 0.92, 0.88)
	var hair := Color(0.16, 0.08, 0.1)
	var hair_tip := Color(0.75, 0.2, 0.18)
	var steel := Color(0.82, 0.86, 0.92)
	var edge := Color(0.3, 0.62, 1.0)

	var hcol := Color(0.8, 0.8, 0.8)   # множитель для пиксельного узора хаори
	# коренастее, «блочные» пропорции: широкие плечи и толстые руки-ноги — видно издалека
	var hips := Vox.pivot(model, Vector3(0, HIP_Y, 0), "hips")
	Vox.box(hips, Vector3(0.42, 0.22, 0.25), Vector3(0, 0, 0), uni, true, 0.0, "cloth", true)
	var torso := Vox.pivot(hips, Vector3(0, 0.06, 0), "torso")
	Vox.box(torso, Vector3(0.44, 0.5, 0.25), Vector3(0, 0.26, 0), uni, true, 0.0, "cloth", true)
	Vox.box(torso, Vector3(0.45, 0.08, 0.26), Vector3(0, 0.03, 0), belt)
	Vox.box(torso, Vector3(0.1, 0.22, 0.02), Vector3(0, 0.37, 0.127), Color(0.85, 0.85, 0.82), false)  # ворот
	var head := Vox.pivot(torso, Vector3(0, 0.52, 0), "head")
	Vox.box(head, Vector3(0.12, 0.08, 0.12), Vector3(0, 0.02, 0), skin)
	Vox.box(head, Vector3(0.3, 0.3, 0.3), Vector3(0, 0.2, 0), skin)
	Vox.box(head, Vector3(0.06, 0.07, 0.02), Vector3(-0.07, 0.19, 0.151), Color(0.1, 0.05, 0.08), false)
	Vox.box(head, Vector3(0.06, 0.07, 0.02), Vector3(0.07, 0.19, 0.151), Color(0.1, 0.05, 0.08), false)
	Vox.box(head, Vector3(0.03, 0.035, 0.021), Vector3(-0.06, 0.205, 0.154), Color(0.5, 0.85, 1.0), false, 0.6)
	Vox.box(head, Vector3(0.03, 0.035, 0.021), Vector3(0.08, 0.205, 0.154), Color(0.5, 0.85, 1.0), false, 0.6)
	Vox.box(head, Vector3(0.08, 0.02, 0.02), Vector3(0, 0.1, 0.151), Color(0.6, 0.35, 0.32), false)   # рот
	# волосы: шапка, чёлка прядями, виски, затылок
	Vox.box(head, Vector3(0.34, 0.1, 0.34), Vector3(0, 0.39, -0.01), hair)
	Vox.box(head, Vector3(0.32, 0.07, 0.06), Vector3(0, 0.335, 0.15), hair)
	Vox.box(head, Vector3(0.06, 0.12, 0.05), Vector3(-0.11, 0.27, 0.155), hair)
	Vox.box(head, Vector3(0.06, 0.09, 0.05), Vector3(0.02, 0.285, 0.16), hair)
	Vox.box(head, Vector3(0.05, 0.08, 0.05), Vector3(0.12, 0.28, 0.155), hair_tip)
	Vox.box(head, Vector3(0.34, 0.28, 0.08), Vector3(0, 0.22, -0.16), hair)
	Vox.box(head, Vector3(0.04, 0.24, 0.28), Vector3(-0.165, 0.24, -0.01), hair)
	Vox.box(head, Vector3(0.04, 0.24, 0.28), Vector3(0.165, 0.24, -0.01), hair)
	var tail_anchor := Vox.pivot(head, Vector3(0, 0.3, -0.2), "tail")

	# хаори: жёсткая часть на плечах (кокетка)
	var hm: ShaderMaterial = Vox.cel_mat(hcol, true, 0.0, 0.022, "haori", true).duplicate()
	hm.set_shader_parameter("tex_scale", 2.0)
	var yoke := Vox.box(torso, Vector3(0.52, 0.12, 0.31), Vector3(0, 0.47, -0.005), hcol)
	yoke.material_override = hm

	var arms := {}
	for side in [-1.0, 1.0]:
		var nm := "r" if side < 0 else "l"
		var arm := Vox.pivot(torso, Vector3(0.3 * side, 0.45, 0), "arm_" + nm)
		Vox.box(arm, Vector3(0.15, 0.28, 0.15), Vector3(0, -0.13, 0), uni)
		var sl1 := Vox.box(arm, Vector3(0.25, 0.27, 0.25), Vector3(0.01 * side, -0.11, 0), hcol)
		sl1.material_override = hm
		var fore := Vox.pivot(arm, Vector3(0, -0.27, 0), "fore_" + nm)
		Vox.box(fore, Vector3(0.14, 0.25, 0.14), Vector3(0, -0.12, 0), uni)
		Vox.box(fore, Vector3(0.13, 0.1, 0.13), Vector3(0, -0.28, 0), skin)
		var sl2 := Vox.box(fore, Vector3(0.26, 0.2, 0.27), Vector3(0.01 * side, -0.05, -0.01), hcol)
		sl2.material_override = hm
		arms[nm] = [arm, fore]
	var fore_r: Node3D = arms.r[1]
	# клинок: модель из набора игрока (sword_lib) или свой кубический
	var sword := Vox.pivot(fore_r, Vector3(0, -0.29, 0.0), "sword")
	sword_vis = Vox.pivot(sword, Vector3.ZERO)
	blade_base = Vox.pivot(sword, Vector3(0, -0.13, 0))
	blade_tip = Vox.pivot(sword, Vector3(0, -0.95, 0))
	whip_anchor = Vox.pivot(sword, Vector3(0, -0.1, 0))
	sword_l = Vox.pivot(arms.l[1], Vector3(0, -0.29, 0), "sword_l")
	sword_l.rotation_degrees = SWORD_TILT
	sword_l_vis = Vox.pivot(sword_l, Vector3.ZERO)
	back_sheath = Vox.pivot(torso, Vector3(0, 0.3, -0.17))

	# ножны на левом бедре (размер подгоняется под клинок в set_sword)
	# катана за поясом-оби, как носили самураи: устье ножен перед левым боком,
	# рукоять вперёд и чуть к центру, ножны назад и немного вниз, лезвие вверх
	sheath_node = Vox.pivot(hips, Vector3(0.15, 0.08, 0.17))
	sheath_node.basis = _wear_basis(Vector3(0.18, -0.3, -1.0))
	sheathed_hilt = Vox.pivot(sheath_node, Vector3(0, 0.02, 0))
	scabbard_node = Vox.pivot(sheath_node, Vector3(0, 0.02, 0))

	for side in [-1.0, 1.0]:
		var nm := "r" if side < 0 else "l"
		var leg := Vox.pivot(hips, Vector3(0.11 * side, -0.06, 0), "leg_" + nm)
		Vox.box(leg, Vector3(0.19, 0.42, 0.2), Vector3(0, -0.2, 0), uni, true, 0.0, "cloth", true)
		var shin := Vox.pivot(leg, Vector3(0, -0.42, 0), "shin_" + nm)
		Vox.box(shin, Vector3(0.17, 0.24, 0.18), Vector3(0, -0.1, 0), uni, true, 0.0, "cloth", true)
		Vox.box(shin, Vector3(0.165, 0.16, 0.175), Vector3(0, -0.3, 0), belt)   # обмотки
		Vox.box(shin, Vector3(0.16, 0.07, 0.26), Vector3(0, -0.42, 0.04), Color(0.2, 0.15, 0.12))

	for n in ["hips", "torso", "head", "arm_r", "fore_r", "arm_l", "fore_l", "leg_r", "shin_r", "leg_l", "shin_l", "sword"]:
		J[n] = model.find_child(n, true, false)
		rest[n] = Vector3.ZERO

	# полы хаори: толстая блочная ткань вокруг корпуса, открыта спереди
	var ring := []
	for i in 9:
		var a := lerpf(-1.12, 1.12, float(i) / 8.0) * PI * 0.5 + PI * 0.5
		var x := cos(a) * 0.255
		var z := -sin(a) * 0.16
		if i == 0 or i == 8:
			z = 0.14
		ring.append(Vector3(x, 0.42, z))
	var body = _make_cloth(torso, ring, 4, 0.21)
	body.push_ellipse = Vector2(0.25, 0.16)
	body.stiff = 0.7
	body.wind = 0.3
	body.gravity = 18.0
	body.drag = 0.08
	body.thick = 0.05
	body.u_step = 0.25
	# рукава: висящий «мешок» под предплечьем
	for nm in ["r", "l"]:
		var fore: Node3D = arms[nm][1]
		var sl = _make_cloth(torso, [[fore, Vector3(-0.1, -0.12, -0.13)], [fore, Vector3(0.0, -0.12, -0.14)], [fore, Vector3(0.1, -0.12, -0.13)]], 3, 0.13)
		sl.stiff = 0.6
		sl.wind = 0.3
		sl.gravity = 16.0
		sl.thick = 0.06
		sl.u_step = 0.25
	# хвост волос и лента
	var tail = MeshInstance3D.new()
	tail.set_script(Cloth)
	tail.attach = tail_anchor
	tail.anchors = [Vector3.ZERO]
	tail.cols = 1
	tail.rows = 5
	tail.seg = 0.11
	tail.mode = "chain"
	tail.chain_size = Vector3(0.12, 0.1, 0.1)
	tail.chain_col = hair
	tail.gravity = 9.0
	model.add_child(tail)
	tail.setup()
	cloths.append(tail)
	var ribbon = MeshInstance3D.new()
	ribbon.set_script(Cloth)
	ribbon.attach = tail_anchor
	ribbon.anchors = [Vector3(0.06, 0.0, 0.02)]
	ribbon.cols = 1
	ribbon.rows = 4
	ribbon.seg = 0.11
	ribbon.mode = "chain"
	ribbon.chain_size = Vector3(0.09, 0.03, 0.1)
	ribbon.chain_col = Color(0.85, 0.15, 0.2)
	ribbon.chain_taper = 0.9
	ribbon.gravity = 6.0
	ribbon.wind = 2.0
	model.add_child(ribbon)
	ribbon.setup()
	cloths.append(ribbon)

func _make_cloth(attach: Node3D, anchors: Array, rows: int, seg: float):
	var c = MeshInstance3D.new()
	c.set_script(Cloth)
	c.attach = attach
	c.anchors = anchors
	c.cols = anchors.size()
	c.rows = rows
	c.seg = seg
	c.mode = "blocks"
	c.push_y_max = 0.6
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/cloth_block.gdshader")
	m.set_shader_parameter("pattern", Tex.get_tex("haori"))
	c.material_override = m
	model.add_child(c)
	cloths.append(c)
	c.call_deferred("setup")
	return c

# =====================================================================
# ВВОД
# =====================================================================
const BUF_ACTIONS := ["jump", "dash", "flash", "light", "heavy", "parry", "form1", "form2", "form3", "lock", "draw"]

# Вызывается из main.gd: события мыши не доходят до пиксельного SubViewport сами.
func handle_input(e: InputEvent) -> void:
	for a in BUF_ACTIONS:
		if e.is_action_pressed(a, false):
			buf[a] = G.real_time

func press(a: String) -> void:   # для автотеста
	buf[a] = G.real_time

func pressed(a: String, window := 0.22) -> bool:
	if buf.has(a) and G.real_time - buf[a] <= window:
		buf.erase(a)
		return true
	return false

func _input_dir() -> Vector3:
	var v := Vector2.ZERO
	v.x = Input.get_action_strength("move_r") - Input.get_action_strength("move_l")
	v.y = Input.get_action_strength("move_b") - Input.get_action_strength("move_f")
	var jx := Input.get_joy_axis(0, JOY_AXIS_LEFT_X)
	var jy := Input.get_joy_axis(0, JOY_AXIS_LEFT_Y)
	if Vector2(jx, jy).length() > 0.2:
		v += Vector2(jx, jy)
	if auto_move != Vector2.ZERO:
		v = auto_move
	if v.length() > 1.0:
		v = v.normalized()
	var yaw: float = G.cam_rig.yaw if G.cam_rig else 0.0
	var d := Vector3(v.x, 0, v.y).rotated(Vector3.UP, yaw)
	return d

var auto_move := Vector2.ZERO   # для автотеста
var auto_breathe := false

func _forward() -> Vector3:
	return Vector3(sin(facing), 0, cos(facing))

# =====================================================================
# ГЛАВНЫЙ ЦИКЛ
# =====================================================================
func _physics_process(dt: float) -> void:
	if dt <= 0.0:
		return
	state_t += dt
	invuln_t -= dt
	flash_window -= dt
	counter_window -= dt
	flip_t = maxf(0.0, flip_t - dt)
	dash_charges = minf(2.0, dash_charges + dt * 0.9)
	for k in cd:
		cd[k] = maxf(0.0, cd[k] - dt)
	if state != "breathe" and state != "dead" and not sprinting:
		breath = minf(max_breath, breath + dt * 5.0)
	if lock_target and (not is_instance_valid(lock_target) or lock_target.is_dead()):
		lock_target = null
	if pressed("lock", 0.3):
		if lock_target:
			lock_target = null
		else:
			lock_target = G.nearest_enemy(global_position, 30.0)

	var inp := _input_dir()
	var was_floor := is_on_floor()
	match state:
		"move": _st_move(dt, inp)
		"dash": _st_dash(dt, inp)
		"wallrun": _st_wallrun(dt, inp)
		"attack": _st_attack(dt, inp)
		"parry": _st_parry(dt)
		"stance": _st_stance(dt)
		"breathe": _st_breathe(dt, inp)
		"hurt": _st_hurt(dt)
		"finisher": _st_finisher(dt)
		"flash": _st_flash(dt)
		"draw": _st_draw(dt)
		"dead": _st_dead(dt)
	landing_vel = velocity.y
	move_and_slide()
	if not was_floor and is_on_floor() and landing_vel < -14.0:
		G.fx.dust(global_position, 10)
		G.add_shake(0.08)
	_separate_from_enemies()
	_effects(dt)
	_animate(dt)
	if sword_mode == "whip":
		var striking: bool = state == "attack" and state_t >= atk.hit0 - 0.06 and state_t <= atk.hit1 + 0.12
		whip.extend = move_toward(whip.extend, 1.0 if striking else 0.0, dt * (14.0 if striking else 3.0))
		trail.push(blade_base.global_position, whip.tip())
	else:
		trail.push(blade_base.global_position, blade_tip.global_position)
	if sword_mode == "dual":
		trail_l.emitting = trail.emitting
		trail_l.push(sword_l.global_transform * Vector3(0, -0.13, 0), sword_l.global_transform * Vector3(0, -0.95, 0))

func _separate_from_enemies() -> void:
	for e in G.enemies:
		if not is_instance_valid(e) or e.is_dead():
			continue
		var d: Vector3 = global_position - e.global_position
		d.y = 0
		var minr: float = 0.35 + e.radius
		if d.length() < minr and absf(global_position.y - e.global_position.y) < 2.0:
			var n := d.normalized() if d.length() > 0.01 else _forward() * -1.0
			global_position += n * (minr - d.length())

func _gravity(dt: float, mult := 1.0) -> void:
	if is_on_floor() and velocity.y <= 0.0:
		velocity.y = -1.0
	else:
		velocity.y -= GRAV * mult * dt

func _face(dir: Vector3, dt: float, rate := 16.0) -> void:
	if dir.length() > 0.05:
		facing = lerp_angle(facing, atan2(dir.x, dir.z), 1.0 - exp(-rate * dt))

func _hmove(target: Vector3, acc: float, dt: float) -> void:
	var hv := Vector3(velocity.x, 0, velocity.z)
	var sp := hv.length()
	var want := target.length()
	if sp > maxf(RUN_SPEED, want) + 0.5 and want > 0.1:
		# сохраняем разгон после рывков и прыжков: скорость падает плавно
		var keep := maxf(want, sp - (14.0 if is_on_floor() else 3.0) * dt)
		hv = hv.move_toward(target.normalized() * sp, acc * 1.5 * dt).limit_length(keep)
	else:
		hv = hv.move_toward(target, acc * dt)
	velocity.x = hv.x
	velocity.z = hv.z

# ---------------------------------------------------------------------
func _st_move(dt: float, inp: Vector3) -> void:
	var on_floor := is_on_floor()
	if on_floor:
		air_jumps = 1
	if sprinting:
		var held := Input.is_action_pressed("dash") or auto_sprint
		if not held or inp.length() < 0.2 or breath <= 0.0:
			sprinting = false
		else:
			breath = maxf(0.0, breath - SPRINT_COST * dt)
	var spd := SPRINT_SPEED if sprinting else RUN_SPEED
	_hmove(inp * spd, (ACCEL * 1.3 if sprinting else ACCEL) if on_floor else AIR_ACCEL, dt)
	_gravity(dt)
	if lock_target and inp.length() < 0.1:
		_face(lock_target.global_position - global_position, dt, 8.0)
	else:
		_face(inp, dt)
	if pressed("jump"):
		if on_floor:
			velocity.y = JUMP_V
			G.sfx.play("jump", -8.0)
			G.fx.dust(global_position, 5)
		elif _try_kickoff(inp):
			pass
		elif air_jumps > 0:
			air_jumps -= 1
			velocity.y = JUMP_V * 0.92
			flip_t = 0.35
			flip_axis = 1.0
			G.fx.ring(global_position, 0.6, Color(0.6, 0.85, 1.0), Color.WHITE, 0.3, 2.0, 0.15)
			G.sfx.play("jump", -6.0, 1.3)
	# бег по стене
	if not on_floor and is_on_wall() and inp.length() > 0.3 and velocity.y < 9.0 and state_t > 0.1:
		var n := get_wall_normal()
		n.y = 0
		if n.length() > 0.5:
			n = n.normalized()
			var hv := Vector3(velocity.x, 0, velocity.z)
			if inp.dot(-n) > 0.8:
				_start_wallrun(n, true)
				return
			elif hv.length() > 5.0:
				_start_wallrun(n, false)
				return
	if _common_actions(inp):
		return
	if (Input.is_action_pressed("breathe") or auto_breathe) and on_floor:
		_set_state("breathe")

func _common_actions(inp: Vector3) -> bool:
	if pressed("draw"):
		_set_state("draw")
		return true
	if pressed("dash"):
		if dash_charges >= 1.0:
			_start_dash(inp)
			return true
	if pressed("flash"):
		_start_flash()
		return true
	if pressed("light"):
		var f := _finisher_candidate()
		if f:
			_start_finisher(f)
		elif counter_window > 0.0:
			_start_attack("counter")
		elif flash_window > 0.0:
			_start_attack("dslash")
		elif not drawn:
			_start_attack("iai")
		elif not is_on_floor():
			_start_attack("air")
		elif combo_queued != "" and G.real_time - last_atk_end < 0.45:
			_start_attack(combo_queued)
		else:
			_start_attack("l1")
		return true
	if pressed("heavy"):
		_start_attack("heavy" if drawn else "iai")
		return true
	if pressed("parry"):
		if not drawn:
			set_drawn(true)
			G.sfx.play("draw", -4.0)
		_set_state("parry")
		G.sfx.play("whoosh", -10.0, 1.6)
		return true
	for i in 3:
		var fa := "form%d" % (i + 1)
		if pressed(fa):
			_try_form(i + 1)
			return true
	return false

# Поставить оружие (пункт меню): катана, парные клинки, хлыст или свой кубический.
func set_sword(m: int) -> void:
	sword_index = m
	if sword_vis == null:
		return
	for holder in [sword_vis, sword_l_vis, sheathed_hilt, scabbard_node, back_sheath]:
		for c in holder.get_children():
			c.queue_free()
	var n := SwordLib.count()
	var blade_len := 0.85
	if m >= 0 and m <= 5 and m < n:
		sword_mode = "katana"
		var vis := SwordLib.make(m, _tint())
		vis.position = Vector3(0, -0.1, 0)
		sword_vis.add_child(vis)
		sheathed_hilt.add_child(SwordLib.make_part(m, "handle"))
		scabbard_node.add_child(SwordLib.make_scabbard(m, saya_style))
	elif m == 6 and n >= 8:
		sword_mode = "dual"
		var r := SwordLib.make(6, _tint())
		r.position = Vector3(0, -0.1, 0)
		sword_vis.add_child(r)
		var l := SwordLib.make(7, _tint())
		l.position = Vector3(0, -0.1, 0)
		sword_l_vis.add_child(l)
		# в ножнах — крест-накрест за спиной, рукояти над плечами
		for k in 2:
			var bs := SwordLib.make(6 + k, _tint())
			var ang := 0.55 if k == 0 else -0.55
			bs.transform = Transform3D(Basis(Vector3(0, 0, 1), ang) * Basis(Vector3.UP, PI * 0.5), Vector3(0.0, 0.18, -0.02))
			back_sheath.add_child(bs)
	elif m == 7 and n >= 9:
		sword_mode = "whip"
		var h := SwordLib.make_part(8, "handle")
		h.position = Vector3(0, -0.1, 0)
		sword_vis.add_child(h)
		# в ножнах — свёрнутый клинок висит на бедре
		var coil := SwordLib.make(8)
		coil.basis = sheath_node.basis.inverse() * Basis.from_euler(Vector3(0.25, 0, 0))
		coil.position = sheath_node.basis.inverse() * Vector3(0.05, 0.15, -0.1)
		sheathed_hilt.add_child(coil)
		blade_len = 0.3
	else:
		sword_mode = "proc"
		_build_proc_sword(sword_vis)
		_build_proc_sword(sheathed_hilt)
		Vox.box(scabbard_node, Vector3(0.055, 0.84, 0.05), Vector3(0, -0.4, 0), Color(0.12, 0.1, 0.16))
		blade_len = 0.8
	blade_tip.position = Vector3(0, -0.1 - blade_len, 0)
	if whip and sword_mode == "whip":
		whip.set_tint(_tint())
		whip.reset()
	set_drawn(drawn)

func _tint() -> Color:
	return SwordLib.TINTS[clampi(blade_tint, 0, SwordLib.TINTS.size() - 1)][1]

# Внешний вид оружия из меню: вид ножен и цвет клинка.
func set_look(saya: int, tint: int) -> void:
	saya_style = saya
	blade_tint = tint
	set_sword(sword_index)

func _build_proc_sword(parent: Node3D) -> void:
	var steel := Color(0.82, 0.86, 0.92)
	var edge := Color(0.3, 0.62, 1.0)
	var sw := Vox.pivot(parent, Vector3(0, 0, 0))
	Vox.box(sw, Vector3(0.04, 0.25, 0.04), Vector3(0, 0.03, 0), Color(0.15, 0.12, 0.2))
	Vox.box(sw, Vector3(0.11, 0.025, 0.09), Vector3(0, -0.1, 0), Color(0.75, 0.62, 0.3))
	var b1 := Vox.pivot(sw, Vector3(0, -0.11, 0))
	Vox.box(b1, Vector3(0.014, 0.42, 0.03), Vector3(0, -0.21, 0), steel, true, 0.25)
	Vox.box(b1, Vector3(0.016, 0.42, 0.012), Vector3(0, -0.21, -0.013), edge, false, 1.4)
	var b2 := Vox.pivot(b1, Vector3(0, -0.42, 0))
	b2.rotation_degrees = Vector3(-6, 0, 0)
	Vox.box(b2, Vector3(0.014, 0.38, 0.028), Vector3(0, -0.19, 0), steel, true, 0.25)
	Vox.box(b2, Vector3(0.016, 0.38, 0.012), Vector3(0, -0.19, -0.013), edge, false, 1.4)

func set_drawn(on: bool) -> void:
	drawn = on
	if J.is_empty():
		return
	J.sword.visible = on
	sword_l.visible = on and sword_mode == "dual"
	sheathed_hilt.visible = not on
	back_sheath.visible = not on and sword_mode == "dual"
	scabbard_node.visible = sword_mode in ["katana", "proc"]
	if whip:
		whip.visible = on and sword_mode == "whip"
		if whip.visible:
			whip.reset()

func _st_draw(dt: float) -> void:
	# достать или убрать клинок: рука тянется к ножнам на левом бедре
	velocity.x = move_toward(velocity.x, 0, 40 * dt)
	velocity.z = move_toward(velocity.z, 0, 40 * dt)
	_gravity(dt)
	var slow := sword_mode in ["katana", "proc"]
	var swap_t := (0.16 if not drawn else 0.4) if slow else (0.12 if not drawn else 0.2)
	if not draw_swapped and state_t >= swap_t:
		draw_swapped = true
		if drawn:
			set_drawn(false)
			G.sfx.play("sheathe", -4.0)
		else:
			set_drawn(true)
			G.sfx.play("draw", -2.0)
			G.fx.burst(blade_tip.global_position, Color(0.9, 0.97, 1.0), 6, 3.0, 0.06, 0.25, 0.0)
	if state_t > (0.52 if slow else 0.3):
		_set_state("move")

func _set_state(s: String) -> void:
	state = s
	state_t = 0.0
	if s == "draw":
		draw_swapped = false
		draw_from_drawn = drawn

# ---------------------------------------------------------------------
func _try_kickoff(inp: Vector3) -> bool:
	if not G.world:
		return false
	var best := {}
	var bd := 99.0
	for k in G.world.kick_points():
		var d: Vector3 = global_position - k.pos
		d.y = 0
		var dist: float = d.length() - k.r
		if dist < 1.3 and global_position.y > 0.3 and global_position.y < k.h + 0.5 and dist < bd:
			bd = dist
			best = k
	var away := Vector3.ZERO
	if not best.is_empty():
		away = global_position - best.pos
		away.y = 0
		away = away.normalized()
	elif is_on_wall():
		away = get_wall_normal()
		away.y = 0
		away = away.normalized()
	else:
		var hit := _ray_around(1.0)
		if hit == Vector3.ZERO:
			return false
		away = hit
	var dir := away
	if inp.length() > 0.2:
		dir = (away * 0.55 + inp.normalized() * 0.9).normalized()
		if dir.dot(away) < -0.1:
			dir = (dir + away).normalized()
	velocity = dir * 17.0 + Vector3.UP * 11.5
	air_jumps = 1
	facing = atan2(dir.x, dir.z)
	flip_t = 0.42
	flip_axis = 1.0
	G.fx.burst(global_position + Vector3.UP * 0.9 - away * 0.4, Color(0.85, 0.75, 0.55), 8, 5.0, 0.12, 0.4, 6.0, -away, 0.6)
	G.fx.ring(global_position + Vector3.UP * 0.9 - away * 0.35, 0.4, Color(0.8, 0.9, 1.0), Color.WHITE, 0.25, 2.5, 0.12, away)
	G.sfx.play("jump", -4.0, 0.8)
	G.add_shake(0.08)
	G.speedlines = maxf(G.speedlines, 0.5)
	return true

func _ray_around(dist: float) -> Vector3:
	var space := get_world_3d().direct_space_state
	var from := global_position + Vector3.UP * 1.0
	for i in 8:
		var a := i * TAU / 8.0
		var d := Vector3(cos(a), 0, sin(a))
		var q := PhysicsRayQueryParameters3D.create(from, from + d * (0.35 + dist), 1)
		var r := space.intersect_ray(q)
		if r:
			var n: Vector3 = r.normal
			n.y = 0
			if n.length() > 0.5:
				return n.normalized()
	return Vector3.ZERO

func _ray(from: Vector3, to: Vector3) -> Dictionary:
	var q := PhysicsRayQueryParameters3D.create(from, to, 1)
	return get_world_3d().direct_space_state.intersect_ray(q)

# ---------------------------------------------------------------------
func _start_wallrun(n: Vector3, vertical: bool) -> void:
	wall_n = n
	wall_vertical = vertical
	_set_state("wallrun")
	air_jumps = 1
	G.fx.dust(global_position + Vector3.UP * 0.8 - n * 0.3, 5)

func _st_wallrun(dt: float, inp: Vector3) -> void:
	var probe := _ray(global_position + Vector3.UP * 0.9, global_position + Vector3.UP * 0.9 - wall_n * 1.0)
	if is_on_floor() or (probe.is_empty() and state_t > 0.08):
		_set_state("move")
		if wall_vertical and probe.is_empty() and velocity.y > 0:
			velocity += -wall_n * 4.0   # перемахнуть через край
		return
	if not probe.is_empty():
		wall_n = Vector3(probe.normal.x, 0, probe.normal.z).normalized()
	if wall_vertical:
		velocity = -wall_n * 1.5 + Vector3.UP * 10.5
		facing = atan2(-wall_n.x, -wall_n.z)
		if state_t > 0.55:
			# сорвался — сальто назад от стены
			velocity = wall_n * 9.0 + Vector3.UP * 9.0
			facing = atan2(wall_n.x, wall_n.z)
			flip_t = 0.4
			flip_axis = -1.0
			_set_state("move")
			return
	else:
		var hv := Vector3(velocity.x, 0, velocity.z)
		var tang := (hv - wall_n * hv.dot(wall_n))
		if tang.length() < 0.5:
			tang = wall_n.cross(Vector3.UP)
			if tang.dot(inp) < 0:
				tang = -tang
		tang = tang.normalized()
		var sp := maxf(hv.length(), RUN_SPEED * 1.05)
		var vy := velocity.y
		if state_t < 0.05:
			vy = maxf(vy, 3.5)
		vy -= GRAV * 0.28 * dt
		velocity = tang * sp - wall_n * 3.0
		velocity.y = vy
		facing = atan2(tang.x, tang.z)
		if state_t > WALLRUN_TIME:
			_set_state("move")
			return
	dust_t -= dt
	if dust_t <= 0.0:
		dust_t = 0.07
		G.fx.burst(global_position + Vector3.UP * 0.4 - wall_n * 0.35, Color(0.8, 0.75, 0.6), 2, 2.0, 0.1, 0.4, 2.0)
	if pressed("jump"):
		var hv2 := Vector3(velocity.x, 0, velocity.z)
		velocity = wall_n * 12.0 + hv2 * 0.75 + Vector3.UP * JUMP_V
		if wall_vertical:
			velocity = wall_n * 13.0 + Vector3.UP * 12.0
		facing = atan2(velocity.x, velocity.z)
		flip_t = 0.42
		flip_axis = 1.0
		G.sfx.play("jump", -4.0, 0.85)
		G.fx.ring(global_position + Vector3.UP * 0.9 - wall_n * 0.3, 0.4, Color(0.8, 0.9, 1.0), Color.WHITE, 0.25, 2.5, 0.12, wall_n)
		G.speedlines = maxf(G.speedlines, 0.5)
		_set_state("move")
		return
	if pressed("light"):
		_set_state("move")
		_start_attack("air")
		return
	if pressed("dash") and dash_charges >= 1.0:
		_start_dash(inp)

# ---------------------------------------------------------------------
var dash_dir := Vector3.FORWARD
var dash_from := Vector3.ZERO

func _start_dash(inp: Vector3) -> void:
	dash_charges -= 1.0
	dash_dir = inp.normalized() if inp.length() > 0.2 else _forward()
	facing = atan2(dash_dir.x, dash_dir.z)
	_set_state("dash")
	invuln_t = DASH_TIME + 0.03
	dash_from = global_position
	sonic_boom(dash_dir)
	G.fx.afterimage(model, Color(0.4, 0.7, 1.0))

# Звуковой барьер: хлопок, кольцо пара поперёк движения, пыль.
func sonic_boom(dir: Vector3) -> void:
	G.sfx.play("sonic", -2.0)
	G.sfx.play("dash", -6.0)
	G.speedlines = maxf(G.speedlines, 0.9)
	G.add_shake(0.12)
	var c := global_position + Vector3.UP * 0.9
	G.fx.ring(c, 0.35, Color(0.85, 0.92, 1.0), Color.WHITE, 0.35, 5.0, 0.18, dir)
	G.fx.ring(c - dir * 0.4, 0.25, Color(0.85, 0.92, 1.0), Color.WHITE, 0.25, 3.5, 0.12, dir)
	if is_on_floor():
		G.fx.dust(global_position, 10)

func _st_dash(dt: float, inp: Vector3) -> void:
	velocity = dash_dir * DASH_SPEED
	velocity.y = 0.0
	ghost_t -= dt
	if ghost_t <= 0.0:
		ghost_t = 0.035
		G.fx.afterimage(model, Color(0.4, 0.7, 1.0), 0.22)
	if state_t >= DASH_TIME:
		velocity = dash_dir * RUN_SPEED * 1.6
		_set_state("move")
		flash_window = 0.25
		# держишь Shift — переходишь в бег на дыхании
		if (Input.is_action_pressed("dash") or auto_sprint) and breath > 5.0:
			sprinting = true
	if state_t > 0.06 and pressed("light"):
		_set_state("move")
		_start_attack("dslash")

# Шаг-вспышка: мгновенный рывок на ~10 м к цели или вперёд.
var flash_from := Vector3.ZERO
var flash_to := Vector3.ZERO

func _start_flash() -> void:
	if breath < 12.0:
		_no_breath()
		return
	breath -= 12.0
	var dir := _forward()
	var dist := FLASH_DIST
	var tgt: Node = lock_target if lock_target else G.nearest_enemy(global_position, 14.0)
	var inp := _input_dir()
	if inp.length() > 0.3 and not lock_target:
		dir = inp.normalized()
		tgt = null
		for e in G.enemies:
			if is_instance_valid(e) and not e.is_dead():
				var to: Vector3 = e.global_position - global_position
				if to.length() < 14.0 and Vector3(to.x, 0, to.z).normalized().dot(dir) > 0.8:
					tgt = e
	if tgt:
		var to: Vector3 = tgt.global_position - global_position
		to.y = 0
		dir = to.normalized()
		dist = maxf(0.0, to.length() - (tgt.radius + 1.3))
	dist = minf(dist, 14.0)
	var from := global_position + Vector3.UP * 0.9
	var r := _ray(from, from + dir * (dist + 0.5))
	if r:
		dist = maxf(0.0, from.distance_to(r.position) - 0.6)
	flash_from = global_position
	flash_to = global_position + dir * dist
	facing = atan2(dir.x, dir.z)
	G.fx.afterimage(model, Color(0.85, 0.95, 1.0), 0.35)
	_set_state("flash")
	invuln_t = 0.2
	sonic_boom(dir)
	G.speedlines = 1.0

func _st_flash(_dt: float) -> void:
	var k := clampf(state_t / 0.07, 0.0, 1.0)
	var p := flash_from.lerp(flash_to, k)
	velocity = Vector3.ZERO
	global_position = Vector3(p.x, global_position.y, p.z)
	if k >= 1.0:
		G.fx.streak(flash_from + Vector3.UP * 0.9, flash_to + Vector3.UP * 0.9, Color(0.8, 0.92, 1.0), 0.3, 0.3)
		G.fx.burst(flash_to + Vector3.UP * 0.9, Color(0.75, 0.9, 1.0), 10, 6.0, 0.1, 0.3, 0.0)
		var d := (flash_to - flash_from).normalized()
		velocity = d * RUN_SPEED
		flash_window = 0.4
		_set_state("move")

# ---------------------------------------------------------------------
func _try_form(i: int) -> void:
	var key := "f%d" % i
	if cd[key] > 0.0:
		G.sfx.play("clang", -18.0, 2.0)
		return
	if i == 3:
		if breath < 15.0:
			_no_breath()
			return
		breath -= 15.0
		cd["f3"] = 3.0
		if not drawn:
			set_drawn(true)
			G.sfx.play("draw", -3.0)
		_set_state("stance")
		G.sfx.play("water", -6.0, 1.3)
		G.fx.ring(global_position + Vector3.UP * 0.05, 0.6, Color(0.3, 0.6, 1.0), Color(0.9, 0.97, 1.0), 0.6, 3.0, 0.2)
		return
	var a: Dictionary = ATK[key]
	if breath < a.breath:
		_no_breath()
		return
	breath -= a.breath
	cd[key] = a.cd
	_start_attack(key)

func _no_breath() -> void:
	G.sfx.play("hurt", -14.0, 1.6)
	if G.hud:
		G.hud.notify("Не хватает дыхания — держи R")

func _aim_target(max_d := 7.0) -> Node:
	if lock_target and global_position.distance_to(lock_target.global_position) < max_d + 3.0:
		return lock_target
	var inp := _input_dir()
	var best: Node = null
	var bs := -1.0
	for e in G.enemies:
		if not is_instance_valid(e) or e.is_dead():
			continue
		var to: Vector3 = e.global_position - global_position
		to.y = 0
		var d := to.length()
		if d > max_d:
			continue
		var dirv := inp if inp.length() > 0.2 else _forward()
		var score := (1.0 - d / max_d) + to.normalized().dot(dirv.normalized()) * 0.6
		if score > bs:
			bs = score
			best = e
	return best

func _start_attack(nm: String) -> void:
	if not drawn:
		set_drawn(true)
		G.sfx.play("draw", -3.0)
		if nm == "iai":
			G.impact(0.05, 1)
	sprinting = false
	atk = ATK[nm]
	atk_name = nm
	_set_state("attack")
	hit_set.clear()
	multi_t = 0.0
	combo_queued = ""
	var tgt := _aim_target(7.5)
	var inp := _input_dir()
	if tgt:
		var to: Vector3 = tgt.global_position - global_position
		to.y = 0
		facing = atan2(to.x, to.z)
	elif inp.length() > 0.2:
		facing = atan2(inp.x, inp.z)
	atk_dir = _forward()
	if nm == "iai":
		# резкий рывок-выхват: к демону (остановиться перед ним) или на 8 м вперёд
		iai_dist = IAI_MAX
		var tg := _aim_target(IAI_MAX + 3.0)
		if tg:
			var to2: Vector3 = tg.global_position - global_position
			to2.y = 0
			iai_dist = clampf(to2.length() - (tg.radius + 1.1), 0.0, IAI_MAX)
		invuln_t = 0.2
		sonic_boom(atk_dir)
		G.fx.afterimage(model, Color(0.85, 0.95, 1.0), 0.35)
	if atk.has("jump"):
		velocity.y = atk.jump
	elif atk.get("air", false):
		velocity.y = maxf(velocity.y, 2.0)
	if atk.has("form"):
		G.sfx.play("water", -2.0)
		G.do_flash(0.25, Color(0.6, 0.85, 1.0))
		if G.hud:
			G.hud.form_title(nm)
	G.sfx.play("whoosh_big" if atk.power >= 2 else "whoosh", -4.0, 1.0)

func _st_attack(dt: float, inp: Vector3) -> void:
	var t := state_t
	var a := atk
	# движение: выпад к цели
	var lunge: float = a.lunge
	var tgt := _aim_target(8.0)
	if tgt:
		var dist: float = Vector3(tgt.global_position.x - global_position.x, 0, tgt.global_position.z - global_position.z).length()
		if dist < tgt.radius + 1.4:
			lunge = 0.0
	var sp := 0.0
	if t < a.hit1:
		sp = lunge * (0.4 + 0.6 * Vox.ease_out(t / maxf(0.01, a.hit1)))
	else:
		sp = lunge * maxf(0.0, 1.0 - (t - a.hit1) * 6.0) * 0.3
	var hv := atk_dir * sp
	if atk_name == "iai":
		hv = atk_dir * (iai_dist / IAI_TIME) if (t >= 0.02 and t < 0.02 + IAI_TIME) else Vector3.ZERO
		if t < 0.02 + IAI_TIME:
			G.fx.afterimage(model, Color(0.7, 0.88, 1.0), 0.2)
			G.speedlines = 1.0
	if a.has("spin") and atk_name == "f2":
		hv = (inp * 6.0) if inp.length() > 0.1 else Vector3.ZERO
	velocity.x = hv.x
	velocity.z = hv.z
	if a.get("air", false) or atk_name == "f2":
		velocity.y -= GRAV * (0.55 if t < a.hit1 else 1.0) * dt
	else:
		_gravity(dt)
	# окно удара
	trail.emitting = t >= a.hit0 - 0.05 and t <= a.hit1 + 0.06
	if t >= a.hit0 and t <= a.hit1:
		if a.has("multi"):
			multi_t -= dt
			if multi_t <= 0.0:
				multi_t = a.multi
				hit_set.clear()
				_attack_fx_tick()
		if not hit_set.has("_fx"):
			hit_set["_fx"] = true
			_attack_fx()
		_check_hits()
	# открытая шея рядом — добивание сразу, из любой фазы удара
	if t > a.hit0 and atk_name != "f2":
		var fc := _finisher_candidate()
		if fc and pressed("light", 0.3):
			trail.emitting = false
			_start_finisher(fc)
			return
	# комбо: следующий удар можно нажать заранее
	if t > a.hit0 and a.next != "" and pressed("light", 0.3):
		combo_queued = a.next
	if t >= a.hit1 + 0.04 and combo_queued != "":
		var nx := combo_queued
		combo_queued = ""
		if _finisher_candidate():
			_start_finisher(_finisher_candidate())
		else:
			_start_attack(nx)
		return
	# отмена восстановления рывком или формой
	if t > a.hit1:
		if pressed("dash") and dash_charges >= 1.0:
			trail.emitting = false
			_start_dash(inp)
			return
		for i in 3:
			if pressed("form%d" % (i + 1), 0.1):
				trail.emitting = false
				_try_form(i + 1)
				return
	if t >= a.dur:
		trail.emitting = false
		last_atk_end = G.real_time
		combo_queued = a.next if a.next != "" else ""
		_set_state("move")

func _attack_fx() -> void:
	var a := atk
	var o := global_position + Vector3.UP * 1.1
	var blue := Color(0.15, 0.4, 0.95)
	var foam := Color(0.88, 0.96, 1.0)
	match a.fx:
		"slash":
			G.fx.slash_arc(o, atk_dir, a.get("roll", 0.0), 1.9, 150.0, 0.55, Color(0.55, 0.8, 1.0), Color.WHITE, 0, 0.22, a.get("rev", false))
		"wave":
			G.fx.slash_arc(o, atk_dir, a.get("roll", 0.0), 2.6, 170.0, 1.0, blue, foam, 1, 0.45, a.get("rev", false))
			G.fx.droplets(o + atk_dir * 1.5, atk_dir, 10)
		"wave_big":
			G.fx.slash_arc(o, atk_dir, 4.0, 3.3, 230.0, 1.9, blue, foam, 1, 0.6, a.get("rev", false))
			G.fx.slash_arc(o + Vector3.UP * 0.3, atk_dir, -6.0, 2.4, 200.0, 0.9, blue.lightened(0.2), foam, 1, 0.5, a.get("rev", false))
			G.fx.droplets(o + atk_dir * 2.0, atk_dir, 22)
			G.speedlines = 1.0
			G.add_shake(0.25)
			G.sfx.play("water", 0.0, 0.9)
		"wave_ring":
			G.fx.arc(o, Basis.IDENTITY, 2.4, 0.0, TAU, 1.0, blue, foam, 0.5, 1, 0.3, 0.2)
			G.fx.droplets(o, Vector3.UP, 16)
			G.sfx.play("water", -3.0, 1.1)
		"heavy":
			G.fx.slash_arc(o, atk_dir, 90.0, 2.0, 150.0, 0.7, Color(0.55, 0.8, 1.0), Color.WHITE, 0, 0.3)
			var gp := global_position + atk_dir * 2.2 + Vector3.UP * 0.1
			G.fx.ring(gp, 0.8, Color(0.85, 0.8, 0.65), Color.WHITE, 0.45, 4.0, 0.4)
			G.fx.dust(gp, 18)
			G.fx.burst(gp, Color(0.45, 0.4, 0.35), 10, 9.0, 0.18, 0.7, 20.0, Vector3.UP, 0.6)
			G.sfx.play("boom", -2.0)
			G.add_shake(0.4)
		"whirl":
			pass

func _attack_fx_tick() -> void:
	# Водоворот: волна вокруг тела на каждом обороте
	var o := global_position + Vector3.UP * (0.9 + state_t * 0.5)
	var b := Basis(Vector3.RIGHT, deg_to_rad(randf_range(-20, 20))) * Basis(Vector3.UP, randf() * TAU)
	G.fx.arc(o, b, 2.3, 0.0, PI * 1.5, 0.9, Color(0.15, 0.45, 0.95), Color(0.9, 0.97, 1.0), 0.32, 1, 0.0, 0.08)
	G.fx.droplets(o, Vector3.UP, 5)
	G.sfx.play("whoosh", -8.0, 1.2)

func _check_hits() -> void:
	var a := atk
	var range_: float = a.range * (1.9 if sword_mode == "whip" else 1.0)
	var half := deg_to_rad(a.arc) * 0.5
	for e in G.enemies:
		if not is_instance_valid(e) or e.is_dead() or hit_set.has(e.get_instance_id()):
			continue
		var to: Vector3 = e.global_position - global_position
		if absf(to.y) > 2.8:
			continue
		var flat := Vector3(to.x, 0, to.z)
		if flat.length() > range_ + e.radius:
			continue
		if a.arc < 360 and flat.length() > 0.5 and absf(atk_dir.signed_angle_to(flat.normalized(), Vector3.UP)) > half:
			continue
		hit_set[e.get_instance_id()] = true
		var res: Dictionary = e.take_hit(a.dmg, flat.normalized(), a)
		_on_hit(e, res, flat.normalized())
	for b in get_tree().get_nodes_in_group("breakable"):
		if hit_set.has(b.get_instance_id()) or not is_instance_valid(b):
			continue
		var c: Vector3 = b.center()
		var to2: Vector3 = c - global_position
		if absf(to2.y) > 3.0:
			continue
		var fl := Vector3(to2.x, 0, to2.z)
		if fl.length() > range_ + b.brad:
			continue
		if a.arc < 360 and fl.length() > 0.5 and absf(atk_dir.signed_angle_to(fl.normalized(), Vector3.UP)) > half:
			continue
		hit_set[b.get_instance_id()] = true
		if b.slash_hit(global_position, fl.normalized(), a.power):
			G.hitstop(0.03)
			G.add_shake(0.12)

func _on_hit(e: Node, res: Dictionary, dir: Vector3) -> void:
	var a := atk
	hits_total += 1
	var p: Vector3 = res.get("point", e.global_position + Vector3.UP * 1.4)
	G.hitstop(a.hitstop)
	G.add_shake(a.shake)
	G.fx.sparks(p, dir, Color(1.0, 0.95, 0.75), 10)
	G.fx.blood(p, dir, 8 if a.power < 2 else 14)
	if a.fx in ["wave", "wave_big", "wave_ring", "whirl"]:
		G.fx.droplets(p, dir, 10)
	G.fx.number(p + Vector3.UP * 0.4, str(int(res.get("dmg", a.dmg))), Color(1, 1, 1) if a.power < 2 else Color(0.6, 0.85, 1.0), a.power >= 2)
	G.sfx.play("hit_heavy" if a.power >= 2 else "hit", -2.0)
	if a.get("impact", false) and not hit_set.has("_imp"):
		hit_set["_imp"] = true
		G.impact(0.075, 0)
		G.do_flash(0.4)
	if G.hud:
		G.hud.add_combo(atk_name, int(res.get("dmg", a.dmg)))
	if res.get("cut_limb", false):
		G.impact(0.05, 1)
		if G.hud:
			G.hud.notify("Рука отрублена — отрастёт!")

# ---------------------------------------------------------------------
func _st_parry(dt: float) -> void:
	velocity.x = move_toward(velocity.x, 0, 60 * dt)
	velocity.z = move_toward(velocity.z, 0, 60 * dt)
	_gravity(dt)
	if lock_target:
		_face(lock_target.global_position - global_position, dt, 20.0)
	if state_t > 0.38:
		_set_state("move")

func _st_stance(dt: float) -> void:
	velocity.x = move_toward(velocity.x, 0, 60 * dt)
	velocity.z = move_toward(velocity.z, 0, 60 * dt)
	_gravity(dt)
	var t := _aim_target(10.0)
	if t:
		_face(t.global_position - global_position, dt, 10.0)
	breathe_fx_t -= dt
	if breathe_fx_t <= 0.0:
		breathe_fx_t = 0.3
		G.fx.ring(global_position + Vector3.UP * 0.04, 0.5, Color(0.25, 0.55, 1.0), Color(0.9, 0.97, 1.0), 0.7, 3.5, 0.12)
	if state_t > 1.0:
		_start_attack("ripple")

func _st_breathe(dt: float, inp: Vector3) -> void:
	velocity.x = move_toward(velocity.x, 0, 50 * dt)
	velocity.z = move_toward(velocity.z, 0, 50 * dt)
	_gravity(dt)
	breath = minf(max_breath, breath + 42.0 * dt)
	hp = minf(max_hp, hp + 2.5 * dt)
	breathe_fx_t -= dt
	if breathe_fx_t <= 0.0:
		breathe_fx_t = 0.12
		var p := global_position + Vector3(randf_range(-0.6, 0.6), 0.1, randf_range(-0.6, 0.6))
		G.fx.burst(p, Color(0.55, 0.8, 1.0), 2, 2.5, 0.08, 0.7, -3.0, Vector3.UP, 0.3, 0.5)
		var mouth: Vector3 = J.head.global_position + Vector3.UP * 0.2 + _forward() * 0.2
		G.fx.burst(mouth, Color(0.92, 0.95, 1.0), 1, 1.0, 0.1, 0.5, -0.5, _forward(), 0.3, 1.0)
	if not (Input.is_action_pressed("breathe") or auto_breathe) or inp.length() > 0.3:
		_set_state("move")
		return
	_common_actions(inp)

func _st_hurt(dt: float) -> void:
	velocity.x = move_toward(velocity.x, 0, 30 * dt)
	velocity.z = move_toward(velocity.z, 0, 30 * dt)
	_gravity(dt)
	if state_t > 0.38:
		_set_state("move")

func _st_dead(dt: float) -> void:
	velocity.x = 0
	velocity.z = 0
	_gravity(dt)
	if state_t > 3.0:
		hp = max_hp
		breath = max_breath
		global_position = spawn_pos
		velocity = Vector3.ZERO
		invuln_t = 1.5
		_set_state("move")
		if G.hud:
			G.hud.notify("Снова в бой")

# Удар демона по герою. Возвращает: "parry", "counter", "dodge", "hit", "none".
func receive_attack(dmg: float, src: Vector3, parryable: bool, attacker: Node = null) -> String:
	if state == "dead" or state == "finisher":
		return "none"
	if state == "stance":
		_counter_strike(attacker, src)
		return "counter"
	if state == "parry" and state_t < 0.26 and parryable:
		_parry_success(src)
		return "parry"
	if invuln_t > 0.0:
		if state == "dash" and state_t < 0.1:
			# идеальное уклонение — мир замедляется
			G.slowmo(0.3, 0.7)
			G.fx.afterimage(model, Color(1.0, 1.0, 1.0), 0.5)
			G.do_flash(0.25, Color(0.7, 0.85, 1.0))
			if G.hud:
				G.hud.notify("Идеальное уклонение")
				G.hud.add_combo("dodge", 15)
		return "dodge"
	hp -= dmg
	G.hurt_fx = 1.0
	G.add_shake(0.35)
	G.hitstop(0.06)
	G.sfx.play("hurt", -2.0)
	G.fx.blood(global_position + Vector3.UP * 1.2, (global_position - src).normalized(), 10)
	trail.emitting = false
	if G.hud:
		G.hud.reset_combo()
	var kb := (global_position - src)
	kb.y = 0
	kb = kb.normalized()
	if hp <= 0.0:
		hp = 0.0
		_set_state("dead")
		velocity = kb * 6.0 + Vector3.UP * 4.0
		G.slowmo(0.3, 1.0)
		G.impact(0.1, 2)
		if G.hud:
			G.hud.notify("Ты пал...")
		return "hit"
	velocity = kb * 9.0 + Vector3.UP * 3.0
	hurt_dir = kb
	_set_state("hurt")
	return "hit"

func _parry_success(src: Vector3) -> void:
	G.slowmo(0.25, 0.55)
	G.impact(0.07, 1)
	G.add_shake(0.3)
	G.sfx.play("clang", 0.0)
	var dir := (src - global_position).normalized()
	G.fx.sparks(global_position + Vector3.UP * 1.3 + dir * 0.8, -dir, Color(1.0, 0.9, 0.5), 26)
	G.fx.ring(global_position + Vector3.UP * 1.3 + dir * 0.8, 0.3, Color(1.0, 0.95, 0.7), Color.WHITE, 0.25, 4.0, 0.15, dir)
	counter_window = 0.9
	invuln_t = 0.3
	if G.hud:
		G.hud.notify("Парирование! Жми ЛКМ — контрудар")
		G.hud.add_combo("parry", 20)

func _counter_strike(attacker: Node, src: Vector3) -> void:
	# Тихая гладь: исчезнуть и появиться за спиной атакующего
	var target_pos := src
	if attacker and is_instance_valid(attacker):
		target_pos = attacker.global_position
	var to := target_pos - global_position
	to.y = 0
	var behind := target_pos + to.normalized() * 2.2
	G.fx.afterimage(model, Color(0.6, 0.85, 1.0), 0.5)
	G.fx.streak(global_position + Vector3.UP, behind + Vector3.UP, Color(0.75, 0.9, 1.0), 0.35, 0.3)
	global_position = Vector3(behind.x, global_position.y, behind.z)
	facing = atan2(-to.x, -to.z)
	G.slowmo(0.2, 0.6)
	G.sfx.play("water", 0.0, 1.2)
	G.sfx.play("shing", -4.0)
	invuln_t = 0.6
	_start_attack("counter")
	if G.hud:
		G.hud.form_title("f3")
		G.hud.add_combo("f3", 25)

# ---------------------------------------------------------------------
func _finisher_candidate() -> Node:
	for e in G.enemies:
		if is_instance_valid(e) and e.is_exposed() and global_position.distance_to(e.global_position) < 6.5:
			return e
	return null

func _start_finisher(e: Node) -> void:
	set_drawn(true)
	fin_target = e
	fin_stage = 0
	_set_state("finisher")
	trail.emitting = false
	invuln_t = 3.0
	e.finisher_lock()
	var to: Vector3 = e.global_position - global_position
	to.y = 0
	var dir := to.normalized()
	# встать перед демоном
	var start: Vector3 = e.global_position - dir * 2.6
	global_position = Vector3(start.x, e.global_position.y, start.z)
	facing = atan2(dir.x, dir.z)
	atk_dir = dir
	velocity = Vector3.ZERO
	if G.cam_rig:
		G.cam_rig.cinematic(e, 2.2)
	G.slowmo(0.5, 0.35)
	G.sfx.play("water", -2.0, 0.8)
	G.do_flash(0.3, Color(0.6, 0.85, 1.0))

func _st_finisher(dt: float) -> void:
	velocity = Vector3.ZERO
	var e := fin_target
	if fin_stage == 0 and state_t > 0.18:
		fin_stage = 1
		trail.emitting = true
		# пролёт сквозь демона — классический аниме-срез
		var from := global_position
		var to := global_position + atk_dir * 5.4
		G.fx.streak(from + Vector3.UP * 1.5, to + Vector3.UP * 1.5, Color(0.85, 0.95, 1.0), 0.6, 0.22)
		G.fx.afterimage(model, Color(0.5, 0.8, 1.0), 0.6)
		global_position = to
		G.impact(0.1, 0)
		G.hitstop(0.12)
		G.slowmo(0.15, 1.1)
		G.sfx.play("shing", 2.0)
		G.add_shake(0.6)
		if is_instance_valid(e):
			var neck: Vector3 = e.neck_pos()
			G.fx.slash_arc(neck - atk_dir * 2.5, atk_dir, 2.0, 3.0, 120.0, 0.9, Color(0.15, 0.4, 0.95), Color(0.9, 0.97, 1.0), 1, 0.9)
			G.fx.arc(neck, Basis.looking_at(atk_dir, Vector3.UP), 1.6, -0.2, PI + 0.2, 0.25, Color(1, 1, 1), Color(0.6, 0.85, 1.0), 0.8, 0)
			e.decapitate(atk_dir)
		if G.hud:
			G.hud.add_combo("finish", 60)
	elif fin_stage == 1 and state_t > 0.32:
		fin_stage = 2
		trail.emitting = false
		G.impact(0.08, 1)
		G.do_flash(0.5)
		if G.hud:
			G.hud.big_text("ОБЕЗГЛАВЛЕН")
	elif fin_stage == 2 and state_t > 0.75:
		_set_state("move")
		invuln_t = 0.5

# =====================================================================
# ЭФФЕКТЫ ДВИЖЕНИЯ
# =====================================================================
func _effects(dt: float) -> void:
	var hv := Vector3(velocity.x, 0, velocity.z)
	var sp := hv.length()
	last_speed = sp
	if sp > RUN_SPEED + 3.0:
		G.speedlines = maxf(G.speedlines, clampf((sp - RUN_SPEED) / 20.0, 0.0, 0.6))
	if sprinting and state == "move":
		G.speedlines = maxf(G.speedlines, 0.55)
		sprint_fx_t -= dt
		if sprint_fx_t <= 0.0:
			sprint_fx_t = 0.07
			G.fx.afterimage(model, Color(0.5, 0.75, 1.0), 0.16)
	dust_t -= dt
	if is_on_floor() and sp > 9.0 and dust_t <= 0.0 and state == "move":
		dust_t = 0.11
		G.fx.burst(global_position + Vector3.UP * 0.05 - hv.normalized() * 0.3, Color(0.75, 0.68, 0.55), 2, 2.0, 0.14, 0.35, -1.0, Vector3.UP, 0.8, 3.0)

# =====================================================================
# АНИМАЦИЯ (процедурная)
# =====================================================================
func _animate(dt: float) -> void:
	var p := {}
	for k in J:
		p[k] = Vector3.ZERO
	var hips_y := HIP_Y
	var lean := 0.0
	var roll := 0.0
	var hv := Vector3(velocity.x, 0, velocity.z)
	var sp := hv.length()
	var snap := false
	var model_spin := 0.0

	# базовая стойка с клинком: кулаки у живота, клинок вперёд и чуть вверх, лезвие вниз
	p.arm_r = IDLE_ARM
	p.fore_r = Vector3(IDLE_FORE, 0, 0)
	p.arm_l = Vector3(-30, 20, 15)
	p.fore_l = Vector3(-50, 0, 0)
	p.sword = Vector3(0, 0, 0)

	if not drawn:
		# клинок в ножнах: левая рука придерживает ножны, правая свободна
		p.arm_r = Vector3(-10, 0, -8)
		p.fore_r = Vector3(-25, 0, 0)
		p.arm_l = Vector3(15, -25, 18)
		p.fore_l = Vector3(-45, 0, 0)
	if state in ["move", "breathe", "parry", "stance", "hurt", "dead"] or (state == "attack" and false):
		if is_on_floor() and sp > 0.8:
			run_phase += dt * (6.0 + sp * 0.62)
			var s := sin(run_phase)
			var c := cos(run_phase)
			var k := clampf(sp / RUN_SPEED, 0.0, 1.3)
			p.leg_r = Vector3(-s * 55 * k, 0, 0)
			p.leg_l = Vector3(s * 55 * k, 0, 0)
			p.shin_r = Vector3(maxf(0.0, c) * 80 * k + 10, 0, 0)
			p.shin_l = Vector3(maxf(0.0, -c) * 80 * k + 10, 0, 0)
			hips_y = HIP_Y - absf(c) * 0.06 * k - 0.05 * k
			if sp > 9.0:
				# быстрый бег: корпус вперёд, руки и клинок назад
				lean = 30.0 * minf(1.0, (sp - 9.0) / 5.0)
				p.torso = Vector3(10, 0, 0)
				p.arm_r = Vector3(70, 0, -15)
				p.fore_r = Vector3(-20, 0, 0)
				p.sword = Vector3(-60, 0, 0)
				p.arm_l = Vector3(70, 0, 15)
				p.fore_l = Vector3(-20, 0, 0)
				p.head = Vector3(-25, 0, 0)
				if sprinting:
					lean = 42.0
					p.arm_r = Vector3(85, 0, -20)
					p.arm_l = Vector3(85, 0, 20)
			else:
				p.arm_l = Vector3(s * 40, 0, 10)
				p.torso = Vector3(8, s * 8, 0)
		elif not is_on_floor():
			p.leg_r = Vector3(-50, 0, 0)
			p.shin_r = Vector3(90, 0, 0)
			p.leg_l = Vector3(-10, 0, 0)
			p.shin_l = Vector3(40, 0, 0)
			lean = clampf(sp * 1.2, 0.0, 20.0)
			if velocity.y > 3.0:
				p.arm_r = Vector3(30, 0, -40)
				p.arm_l = Vector3(30, 0, 40)
		else:
			# стойка на месте: ноги шире, дыхание
			var br := sin(G.real_time * 2.0) * 3.0
			p.leg_r = Vector3(-15, 0, -8)
			p.leg_l = Vector3(12, 0, 8)
			p.shin_r = Vector3(20, 0, 0)
			p.shin_l = Vector3(12, 0, 0)
			p.torso = Vector3(br, -15, 0)
			hips_y = HIP_Y - 0.04
	if state == "wallrun":
		run_phase += dt * 16.0
		var s2 := sin(run_phase)
		p.leg_r = Vector3(-s2 * 60, 0, 0)
		p.leg_l = Vector3(s2 * 60, 0, 0)
		p.shin_r = Vector3(40 + s2 * 30, 0, 0)
		p.shin_l = Vector3(40 - s2 * 30, 0, 0)
		p.arm_r = Vector3(60, 0, -20)
		p.fore_r = Vector3(-20, 0, 0)
		p.arm_l = Vector3(60, 0, 20)
		p.sword = Vector3(-60, 0, 0)
		if wall_vertical:
			lean = -10.0
		else:
			var right := Vector3(cos(facing), 0, -sin(facing))  # сторона +X модели
			roll = -sign(wall_n.dot(right)) * 28.0
			lean = 15.0
	if state == "dash" or state == "flash":
		lean = 45.0
		p.arm_r = Vector3(75, 0, -20)
		p.arm_l = Vector3(75, 0, 20)
		p.fore_r = Vector3(-10, 0, 0)
		p.sword = Vector3(-70, 0, 0)
		p.leg_r = Vector3(-40, 0, 0)
		p.shin_r = Vector3(70, 0, 0)
		p.leg_l = Vector3(30, 0, 0)
		p.shin_l = Vector3(60, 0, 0)
		snap = true
	if state == "parry":
		var k2 := Vox.ease_out(state_t / 0.08)
		p.arm_r = Vector3(-100, 25, -10) * k2
		p.fore_r = Vector3(-60, 0, 0)
		p.sword = Vector3(0, 0, 90) * k2
		p.arm_l = Vector3(-90, -20, 20)
		p.torso = Vector3(-5, -20, 0)
		snap = true
	if state == "stance" or state == "breathe":
		p.arm_r = Vector3(-15, -10, -10)
		p.fore_r = Vector3(-20, 0, 0)
		p.sword = Vector3(30, 0, 0)
		p.arm_l = Vector3(-15, 10, 10)
		p.leg_r = Vector3(-20, 0, -10)
		p.leg_l = Vector3(25, 0, 10)
		p.shin_r = Vector3(30, 0, 0)
		p.shin_l = Vector3(20, 0, 0)
		hips_y = HIP_Y - 0.08
		if state == "breathe":
			p.torso = Vector3(sin(G.real_time * 5.0) * 4.0, 0, 0)
			p.head = Vector3(-10, 0, 0)
	if state == "draw":
		# рука к рукояти на левом бедре
		var kd := Vox.ease_out(state_t / 0.12)
		p.arm_r = Vector3(-25, 70, 30) * kd
		p.fore_r = Vector3(-60, 0, 0)
		p.torso = Vector3(5, 25 * kd, 0)
		p.arm_l = Vector3(15, -25, 18)
		snap = true
	if state == "hurt":
		lean = -25.0
		p.arm_r = Vector3(-20, 0, -40)
		p.arm_l = Vector3(-20, 0, 40)
	if state == "dead":
		lean = -80.0
		hips_y = 0.3
	if state == "attack" or state == "finisher":
		var a := atk if state == "attack" else ATK["dslash"]
		var t := state_t if state == "attack" else (0.08 if fin_stage == 0 else 0.3)
		var arm := Vector3.ZERO
		var fore := 0.0
		var tw := 0.0
		if t < a.hit0:
			var k3 := Vox.ease_out(t / maxf(0.01, a.hit0))
			arm = p.arm_r.lerp(a.arm0, k3)
			fore = lerpf(p.fore_r.x, a.fore0, k3)
			tw = lerpf(0.0, a.tw0, k3)
		elif t < a.hit1:
			var k4 := Vox.ease_in_out((t - a.hit0) / maxf(0.01, a.hit1 - a.hit0))
			arm = a.arm0.lerp(a.arm1, k4)
			fore = lerpf(a.fore0, a.fore1, k4)
			tw = lerpf(a.tw0, a.tw1, k4)
		else:
			var k5 := clampf((t - a.hit1) / maxf(0.01, a.dur - a.hit1), 0.0, 1.0)
			k5 = Vox.ease_in_out((k5 - 0.4) / 0.6) if k5 > 0.4 else 0.0
			arm = a.arm1.lerp(IDLE_ARM, k5)
			fore = lerpf(a.fore1, IDLE_FORE, k5)
			tw = lerpf(a.tw1, 0.0, k5)
		p.arm_r = arm
		p.fore_r = Vector3(fore, 0, 0)
		p.torso = Vector3(10, tw, 0)
		# кисть: лезвие смотрит по ходу удара (горизонтальные — вбок, вертикальные — вниз)
		var wr: float = a.get("wr", 90.0 if a.get("rev", false) else -90.0)
		p.sword = Vector3(0, wr * clampf(t / maxf(0.01, a.hit0), 0.0, 1.0), 0)
		p.arm_l = Vector3(-40, 40, 30)
		p.leg_r = Vector3(-35, 0, -10)
		p.leg_l = Vector3(30, 0, 10)
		p.shin_r = Vector3(35, 0, 0)
		p.shin_l = Vector3(25, 0, 0)
		hips_y = HIP_Y - 0.1
		lean = 12.0
		snap = true
		if a.has("spin"):
			var ks := clampf((t - a.hit0) / maxf(0.01, a.hit1 - a.hit0), 0.0, 1.0)
			model_spin = ks * TAU * a.spin
		if a.get("air", false) or atk_name == "f2":
			p.leg_r = Vector3(-60, 0, 0)
			p.shin_r = Vector3(90, 0, 0)
			p.leg_l = Vector3(-20, 0, 0)
			p.shin_l = Vector3(60, 0, 0)

	if sword_mode == "dual" and drawn and state not in ["dash", "flash", "wallrun", "draw", "dead"]:
		var ar: Vector3 = p.arm_r
		p.arm_l = Vector3(ar.x, -ar.y, -ar.z)
		p.fore_l = p.fore_r
		if state != "attack":
			# стойка с двумя клинками: руки в стороны, клинки вперёд
			if not (is_on_floor() and sp > 9.0):
				p.arm_r = Vector3(-35, -25, -30)
				p.arm_l = Vector3(-35, 25, 30)
				p.fore_r = Vector3(-35, 0, 0)
				p.fore_l = Vector3(-35, 0, 0)
	# применение
	var rate := 1.0 - exp(-(40.0 if snap else 16.0) * dt)
	for k in J:
		if k == "hips":
			continue
		var cur: Vector3 = rest[k]
		cur = cur.lerp(p[k], rate)
		rest[k] = cur
		J[k].rotation_degrees = cur + (SWORD_TILT if k == "sword" else Vector3.ZERO)
	J.hips.position.y = lerpf(J.hips.position.y, hips_y, rate)
	var flip := 0.0
	if flip_t > 0.0:
		flip = (1.0 - flip_t / 0.42) * TAU * flip_axis
	model.rotation = Vector3(deg_to_rad(lean) + flip, facing + model_spin, deg_to_rad(roll))
	if state == "dead":
		model.rotation.x = deg_to_rad(-80)
	if sword_mode == "dual":
		var sw: Vector3 = J.sword.rotation_degrees
		sword_l.rotation_degrees = Vector3(sw.x, -sw.y, -sw.z)
	_apply_ik(dt, sp)

# ---------------------------------------------------------------------
# Двуручный хват катаны: руки сами тянутся к рукояти (обратная кинематика).
const UPPER := 0.27
const LOWER := 0.29
const CHUDAN_H := Vector3(-0.04, 0.12, 0.3)      # правая рука перед животом (в системе торса)
const CHUDAN_D := Vector3(0, 0.42, 1.0)          # клинок вперёд и вверх — на горло противника
const LOW_H := Vector3(-0.02, 0.02, 0.29)
const LOW_D := Vector3(0, -0.25, 1.0)

func _apply_ik(dt: float, sp: float) -> void:
	var katana := sword_mode in ["katana", "proc"]
	var gw := 0.0
	var lw := 0.0
	var H := CHUDAN_H
	var D := CHUDAN_D.normalized()
	if katana and drawn:
		if state == "move" and is_on_floor() and sp < 9.0:
			gw = 1.0
		elif state in ["breathe", "stance"]:
			gw = 1.0
			H = LOW_H
			D = LOW_D.normalized()
		if gw > 0.0 or state in ["attack", "finisher", "parry"]:
			lw = 1.0
		if state == "attack" and atk_name == "f2":
			lw = 0.0
	grip_w = move_toward(grip_w, gw, dt * 7.0)
	left_w = move_toward(left_w, lw, dt * 9.0)
	var torso: Node3D = J.torso
	var inv := torso.global_transform.affine_inverse()
	if state == "draw" and katana:
		_draw_ik(inv)
		return
	if grip_w > 0.001:
		_ik_arm("r", H, grip_w)
		var want := _blade_basis(D)
		var ft: Basis = J.arm_r.basis * J.fore_r.basis
		var loc := (ft.inverse() * want).orthonormalized()
		J.sword.basis = Basis(J.sword.basis.get_rotation_quaternion().slerp(loc.get_rotation_quaternion(), grip_w))
	if left_w > 0.001:
		var tl: Vector3 = inv * (J.sword.global_transform * Vector3(0, 0.15, 0))
		_ik_arm("l", tl, left_w)

# Видимый выхват: рука к рукояти на бедре, клинок выезжает вдоль ножен, потом в стойку.
func _draw_ik(inv: Transform3D) -> void:
	var hilt: Vector3 = inv * sheathed_hilt.global_transform.origin
	var axis: Vector3 = (inv.basis * sheath_node.global_transform.basis.y).normalized()   # из устья наружу
	var mouth: Vector3 = inv * sheath_node.global_transform.origin
	var t := state_t
	var hand := hilt
	var bdir := -axis
	var w := 1.0
	var pull := 0.0
	if not draw_from_drawn:
		if t < 0.16:
			w = clampf(t / 0.12, 0.0, 1.0)
		elif t < 0.36:
			pull = Vox.ease_in_out((t - 0.16) / 0.2)
		else:
			pull = 1.0
		hand = hilt + axis * 0.9 * pull
		if t >= 0.36:
			var k := Vox.ease_in_out((t - 0.36) / 0.16)
			hand = hand.lerp(CHUDAN_H, k)
			bdir = bdir.lerp(CHUDAN_D.normalized(), k).normalized()
	else:
		if t < 0.18:
			var k2 := Vox.ease_in_out(t / 0.18)
			hand = CHUDAN_H.lerp(hilt + axis * 0.9, k2)
			bdir = CHUDAN_D.normalized().lerp(-axis, k2).normalized()
		elif t < 0.4:
			pull = 1.0 - Vox.ease_in_out((t - 0.18) / 0.22)
			hand = hilt + axis * 0.9 * pull
		else:
			hand = hilt
			w = 1.0 - clampf((t - 0.4) / 0.12, 0.0, 1.0)
	_ik_arm("r", hand, w)
	if drawn:
		var want := _blade_basis(bdir)
		var ft: Basis = J.arm_r.basis * J.fore_r.basis
		J.sword.basis = (ft.inverse() * want).orthonormalized()
	# левая рука держит ножны у устья
	_ik_arm("l", mouth + Vector3(0, 0.02, 0.02), 1.0)

# Базис ножен: клинок вдоль -Y = dir (назад-вниз), лезвие (-Z) смотрит вверх.
func _wear_basis(dir: Vector3) -> Basis:
	var d := dir.normalized()
	var y := -d
	var e := Vector3.UP - d * d.dot(Vector3.UP)
	var z := -e.normalized()
	var x := y.cross(z).normalized()
	return Basis(x, y, z)

# Базис клинка в системе торса: клинок вдоль -Y = dir, лезвие (-Z) смотрит вниз.
func _blade_basis(dir: Vector3) -> Basis:
	var y := -dir.normalized()
	var e := Vector3.DOWN - dir * dir.dot(Vector3.DOWN)
	if e.length() < 0.01:
		e = Vector3.FORWARD
	var z := -e.normalized()
	var x := y.cross(z).normalized()
	return Basis(x, y, z)

func _aim(v: Vector3, hint: Vector3) -> Basis:
	var y := -v.normalized()
	var x := hint - y * hint.dot(y)
	if x.length() < 0.001:
		x = Vector3.RIGHT
	x = x.normalized()
	var z := x.cross(y)
	return Basis(x, y, z)

# Двухзвенная IK руки к точке T (система торса), локоть наружу-вниз-назад.
func _ik_arm(side: String, T: Vector3, w: float) -> void:
	if w <= 0.001:
		return
	var arm: Node3D = J["arm_" + side]
	var fore: Node3D = J["fore_" + side]
	var S := arm.position
	var v := T - S
	var d := clampf(v.length(), 0.1, UPPER + LOWER - 0.004)
	var dir := v.normalized() if v.length() > 0.001 else Vector3.DOWN
	var sx := -1.0 if side == "r" else 1.0
	var pole := Vector3(0.7 * sx, -0.6, -0.4)
	var pn := pole - dir * pole.dot(dir)
	if pn.length() < 0.01:
		pn = Vector3(0, -1, 0)
	pn = pn.normalized()
	var a := (UPPER * UPPER + d * d - LOWER * LOWER) / (2.0 * d)
	var h := sqrt(maxf(0.0, UPPER * UPPER - a * a))
	var elbow := S + dir * a + pn * h
	var hand := S + dir * d
	var ud := (elbow - S).normalized()
	var ld := (hand - elbow).normalized()
	var hinge := ud.cross(ld)
	if hinge.length() < 0.001:
		hinge = Vector3(1, 0, 0)
	hinge = hinge.normalized()
	var ab := _aim(ud, hinge)
	var fb := _aim(ld, hinge)
	var fl := (ab.inverse() * fb).orthonormalized()
	arm.basis = Basis(arm.basis.get_rotation_quaternion().slerp(ab.get_rotation_quaternion(), w))
	fore.basis = Basis(fore.basis.get_rotation_quaternion().slerp(fl.get_rotation_quaternion(), w))

func is_dead() -> bool:
	return state == "dead"
