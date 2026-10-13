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
const Chain = preload("res://scripts/chain.gd")
const Bandage = preload("res://scripts/bandage.gd")

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
	"l1": {"sweep": true, "dur": 0.34, "hit0": 0.09, "hit1": 0.17, "dmg": 8, "range": 3.1, "arc": 140, "lunge": 9.0,
		"power": 1, "stagger": 0.3, "hitstop": 0.055, "shake": 0.12, "next": "l2",
		"arm0": Vector3(-85, -110, 0), "arm1": Vector3(-80, 95, 0), "fore0": -15, "fore1": -5, "tw0": -40, "tw1": 40,
		"fx": "slash", "roll": 8},
	"l2": {"sweep": true, "dur": 0.34, "hit0": 0.08, "hit1": 0.16, "dmg": 8, "range": 3.1, "arc": 140, "lunge": 8.0,
		"power": 1, "stagger": 0.3, "hitstop": 0.055, "shake": 0.12, "next": "l3",
		"arm0": Vector3(-75, 100, 0), "arm1": Vector3(-85, -115, 0), "fore0": -20, "fore1": -5, "tw0": 40, "tw1": -45,
		"fx": "slash", "roll": -10, "rev": true},
	# третий — восходящий срез: подбрасывает демона
	"l3": {"sweep": true, "launch": true, "dur": 0.42, "hit0": 0.1, "hit1": 0.2, "dmg": 10, "range": 3.2, "arc": 120, "lunge": 9.0,
		"power": 1, "stagger": 0.35, "hitstop": 0.07, "shake": 0.18, "next": "l4",
		"arm0": Vector3(-5, -50, 0), "arm1": Vector3(-185, 25, 0), "fore0": -20, "fore1": 0, "tw0": -20, "tw1": 20,
		"fx": "slash", "roll": -70, "wr": 180.0},
	"l4": {"dur": 0.55, "hit0": 0.12, "hit1": 0.3, "dmg": 15, "range": 3.6, "arc": 360, "lunge": 11.0,
		"power": 2, "stagger": 0.6, "hitstop": 0.09, "shake": 0.3, "next": "",
		"arm0": Vector3(-90, -100, 0), "arm1": Vector3(-90, 100, 0), "fore0": 0, "fore1": 0, "tw0": -30, "tw1": 30,
		"spin": 1.0, "fx": "wave_ring", "knock": 9.0},
	"air": {"sweep": true, "dur": 0.38, "hit0": 0.08, "hit1": 0.17, "dmg": 10, "range": 3.3, "arc": 130, "lunge": 4.0,
		"power": 1, "stagger": 0.35, "hitstop": 0.06, "shake": 0.15, "next": "air",
		"arm0": Vector3(-200, 0, 0), "arm1": Vector3(-15, 0, 0), "fore0": 0, "fore1": 0, "tw0": 0, "tw1": 0,
		"fx": "slash", "roll": 90, "air": true, "wr": 0.0},
	"dslash": {"dur": 0.42, "hit0": 0.05, "hit1": 0.16, "dmg": 16, "range": 3.6, "arc": 160, "lunge": 26.0,
		"power": 2, "stagger": 0.5, "hitstop": 0.08, "shake": 0.25, "next": "l3",
		"arm0": Vector3(-60, 120, 0), "arm1": Vector3(-90, -120, 0), "fore0": -10, "fore1": 0, "tw0": 50, "tw1": -50,
		"fx": "slash", "roll": -5, "rev": true},
	"heavy": {"sweep": true, "dur": 0.78, "hit0": 0.4, "hit1": 0.5, "dmg": 24, "range": 3.7, "arc": 150, "lunge": 7.0,
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
	# --- парные клинки: быстрые удары то правой, то левой, крест, вихрь на цепи ---
	"d1": {"sweep": true, "dur": 0.26, "hit0": 0.06, "hit1": 0.13, "dmg": 6, "range": 2.9, "arc": 140, "lunge": 8.0,
		"power": 1, "stagger": 0.25, "hitstop": 0.045, "shake": 0.1, "next": "d2",
		"arm0": Vector3(-80, -100, 0), "arm1": Vector3(-75, 90, 0), "fore0": -10, "fore1": -5, "tw0": -35, "tw1": 35,
		"fx": "slash", "roll": 6},
	"d2": {"sweep": true, "dur": 0.26, "hit0": 0.06, "hit1": 0.13, "dmg": 6, "range": 2.9, "arc": 140, "lunge": 8.0,
		"power": 1, "stagger": 0.25, "hitstop": 0.045, "shake": 0.1, "next": "d3",
		"arm0": Vector3(-80, -100, 0), "arm1": Vector3(-75, 90, 0), "fore0": -10, "fore1": -5, "tw0": 35, "tw1": -35,
		"fx": "slash", "roll": -6, "rev": true},
	"d3": {"sweep": true, "launch": true, "dur": 0.42, "hit0": 0.1, "hit1": 0.2, "dmg": 12, "range": 3.2, "arc": 120, "lunge": 10.0,
		"power": 2, "stagger": 0.5, "hitstop": 0.08, "shake": 0.22, "next": "d4",
		"arm0": Vector3(-20, -60, 0), "arm1": Vector3(-170, 40, 0), "fore0": -20, "fore1": 0, "tw0": 0, "tw1": 0,
		"fx": "cross", "wr": 180.0},
	"d4": {"dur": 0.72, "hit0": 0.12, "hit1": 0.58, "dmg": 7, "range": 4.4, "arc": 360, "lunge": 4.0,
		"power": 1, "stagger": 0.3, "hitstop": 0.035, "shake": 0.1, "next": "",
		"arm0": Vector3(-90, -80, 0), "arm1": Vector3(-90, -80, 0), "fore0": 0, "fore1": 0, "tw0": 0, "tw1": 0,
		"spin": 2.0, "fx": "chain_whirl", "multi": 0.12, "knock": 6.0},
	"dair": {"sweep": true, "dur": 0.36, "hit0": 0.08, "hit1": 0.17, "dmg": 9, "range": 3.2, "arc": 130, "lunge": 4.0,
		"power": 1, "stagger": 0.35, "hitstop": 0.06, "shake": 0.15, "next": "dair",
		"arm0": Vector3(-200, -20, 0), "arm1": Vector3(-20, 20, 0), "fore0": 0, "fore1": 0, "tw0": 0, "tw1": 0,
		"fx": "cross", "air": true, "wr": 0.0},
	# --- гибкий клинок: дальние хлёсты, щелчок сверху, круг, дальний удар ---
	"w1": {"sweep": true, "dur": 0.42, "hit0": 0.12, "hit1": 0.22, "dmg": 8, "range": 2.6, "arc": 130, "lunge": 3.0,
		"power": 1, "stagger": 0.3, "hitstop": 0.05, "shake": 0.12, "next": "w2",
		"arm0": Vector3(-100, -120, 0), "arm1": Vector3(-70, 80, 0), "fore0": -30, "fore1": 0, "tw0": -45, "tw1": 40,
		"fx": "lash", "roll": 4},
	"w2": {"sweep": true, "dur": 0.42, "hit0": 0.12, "hit1": 0.22, "dmg": 8, "range": 2.6, "arc": 130, "lunge": 3.0,
		"power": 1, "stagger": 0.3, "hitstop": 0.05, "shake": 0.12, "next": "w3",
		"arm0": Vector3(-70, 90, 0), "arm1": Vector3(-100, -110, 0), "fore0": -30, "fore1": 0, "tw0": 40, "tw1": -45,
		"fx": "lash", "roll": -4, "rev": true},
	"w3": {"sweep": true, "dur": 0.55, "hit0": 0.16, "hit1": 0.27, "dmg": 13, "range": 3.0, "arc": 40, "lunge": 2.0,
		"power": 2, "stagger": 0.6, "hitstop": 0.08, "shake": 0.25, "next": "w4",
		"arm0": Vector3(-200, 0, 0), "arm1": Vector3(-40, 0, 0), "fore0": -40, "fore1": 0, "tw0": -10, "tw1": 10,
		"fx": "crack", "roll": 90, "wr": 0.0, "knock": 5.0},
	"w4": {"dur": 0.6, "hit0": 0.12, "hit1": 0.4, "dmg": 12, "range": 2.8, "arc": 360, "lunge": 2.0,
		"power": 2, "stagger": 0.6, "hitstop": 0.07, "shake": 0.25, "next": "",
		"arm0": Vector3(-90, -110, 0), "arm1": Vector3(-90, 100, 0), "fore0": 0, "fore1": 0, "tw0": -30, "tw1": 30,
		"spin": 1.0, "fx": "lash_ring", "knock": 9.0},
	"wheavy": {"sweep": true, "dur": 0.7, "hit0": 0.32, "hit1": 0.42, "dmg": 20, "range": 3.8, "arc": 30, "lunge": 0.0,
		"power": 2, "stagger": 0.8, "hitstop": 0.1, "shake": 0.4, "next": "",
		"arm0": Vector3(-185, -20, 0), "arm1": Vector3(-75, 0, 0), "fore0": -50, "fore1": 0, "tw0": -20, "tw1": 15,
		"fx": "crack", "roll": 90, "wr": 0.0, "knock": 9.0},
	"wair": {"sweep": true, "dur": 0.4, "hit0": 0.1, "hit1": 0.2, "dmg": 9, "range": 2.8, "arc": 130, "lunge": 3.0,
		"power": 1, "stagger": 0.35, "hitstop": 0.06, "shake": 0.15, "next": "wair",
		"arm0": Vector3(-200, 0, 0), "arm1": Vector3(-30, 0, 0), "fore0": 0, "fore1": 0, "tw0": 0, "tw1": 0,
		"fx": "lash", "roll": 90, "air": true, "wr": 0.0},
	# парные клинки: бросок правого клинка на цепи — летит, вращаясь, и возвращается
	"chain": {"dur": 0.74, "hit0": 0.13, "hit1": 0.52, "dmg": 11, "range": 7.0, "arc": 50, "lunge": 0.0,
		"power": 2, "stagger": 0.45, "hitstop": 0.04, "shake": 0.18, "next": "",
		"arm0": Vector3(-165, -35, 0), "arm1": Vector3(-80, 15, 0), "fore0": -70, "fore1": 0, "tw0": -40, "tw1": 25,
		"fx": "chain", "multi": 0.1, "throw": 6.5, "knock": 4.0, "wr": 0.0},
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
var grip_r_w := 0.0
var grip_l_w := 0.0
var sprinting := false
var draw_swapped := false
var iai_dist := 8.0               # длина рывка при выхвате-ударе
const IAI_MAX := 8.0
const IAI_TIME := 0.1
var draw_from_drawn := false
var auto_sprint := false
var sprint_fx_t := 0.0
var landing_vel := 0.0
# парные клинки: цепь между навершиями, бинты за спиной, бросок на цепи
var chain
var bandage
var back_swords: Array = []
var pommel_r := 0.25
var pommel_l := 0.25
var thrown: Node3D
var throw_from := Vector3.ZERO
var throw_to := Vector3.ZERO
var throw_init := false
var ik_pole_up := false
var sweep_prev: Array = []        # отрезки клинков в прошлом кадре (попадание по движению клинка)
const SWEEP_EXT := 0.75           # «ветер клинка» — добавка к длине лезвия
const SWEEP_PAD := 0.3

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
	chain = Node3D.new()
	chain.set_script(Chain)
	add_child(chain)
	chain.setup()
	bandage = Node3D.new()
	bandage.set_script(Bandage)
	add_child(bandage)
	thrown = Node3D.new()
	thrown.top_level = true
	thrown.visible = false
	add_child(thrown)
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
	# пуговицы формы
	for k in 3:
		Vox.box(torso, Vector3(0.035, 0.035, 0.02), Vector3(0, 0.15 + k * 0.08, 0.128), Color(0.85, 0.7, 0.3), false, 0.2)
	var head := Vox.pivot(torso, Vector3(0, 0.52, 0), "head")
	Vox.box(head, Vector3(0.12, 0.08, 0.12), Vector3(0, 0.02, 0), skin)
	Vox.box(head, Vector3(0.3, 0.3, 0.3), Vector3(0, 0.2, 0), skin)
	for sx in [-1.0, 1.0]:
		Vox.box(head, Vector3(0.03, 0.07, 0.05), Vector3(0.163 * sx, 0.19, 0.0), skin.darkened(0.08))   # уши
	_build_face(head, skin, hair)
	# волосы: шапка с торчащими прядями, чёлка, виски, затылок
	Vox.box(head, Vector3(0.34, 0.1, 0.34), Vector3(0, 0.39, -0.01), hair)
	Vox.box(head, Vector3(0.32, 0.07, 0.06), Vector3(0, 0.335, 0.15), hair)
	var bangs := [[-0.12, 0.27, 0.12, 8.0], [-0.055, 0.28, 0.1, -4.0], [0.01, 0.275, 0.11, 6.0], [0.075, 0.285, 0.09, -8.0], [0.13, 0.275, 0.1, 10.0]]
	for i in bangs.size():
		var bg: Array = bangs[i]
		var strand := Vox.box(head, Vector3(0.06, bg[2], 0.05), Vector3(bg[0], bg[1], 0.157), hair_tip if i == 4 else hair)
		strand.rotation_degrees = Vector3(0, 0, bg[3])
	var spikes := [[Vector3(0, 0.45, -0.06), Vector3(-25, 0, 0)], [Vector3(-0.1, 0.44, 0.02), Vector3(-10, 0, 25)],
		[Vector3(0.1, 0.44, 0.02), Vector3(-10, 0, -25)], [Vector3(-0.09, 0.42, -0.14), Vector3(-45, 0, 20)],
		[Vector3(0.09, 0.42, -0.14), Vector3(-45, 0, -20)], [Vector3(0, 0.36, -0.21), Vector3(-70, 0, 0)]]
	for sp in spikes:
		var spk := Vox.box(head, Vector3(0.09, 0.11, 0.09), sp[0], hair)
		spk.rotation_degrees = sp[1]
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
		# кулак: ладонь, ряд костяшек спереди, большой палец к телу
		Vox.box(fore, Vector3(0.12, 0.1, 0.12), Vector3(0, -0.28, 0), skin)
		Vox.box(fore, Vector3(0.125, 0.065, 0.04), Vector3(0, -0.3, 0.058), skin.darkened(0.06))
		Vox.box(fore, Vector3(0.035, 0.055, 0.05), Vector3(-0.06 * side, -0.265, 0.04), skin)
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
		Vox.box(shin, Vector3(0.165, 0.15, 0.175), Vector3(0, -0.27, 0), belt)   # обмотки
		Vox.box(shin, Vector3(0.17, 0.025, 0.18), Vector3(0, -0.22, 0), belt.darkened(0.15), false)
		# стопа: таби и сандалии-варадзи на ремешках, гнётся в голеностопе
		var foot := Vox.pivot(shin, Vector3(0, -0.36, 0.0), "foot_" + nm)
		Vox.box(foot, Vector3(0.15, 0.08, 0.22), Vector3(0, -0.04, 0.04), Color(0.9, 0.89, 0.84))
		Vox.box(foot, Vector3(0.165, 0.03, 0.255), Vector3(0, -0.09, 0.045), Color(0.62, 0.48, 0.3))
		Vox.box(foot, Vector3(0.155, 0.02, 0.03), Vector3(0, -0.035, 0.11), Color(0.25, 0.18, 0.14), false)
		Vox.box(foot, Vector3(0.155, 0.02, 0.03), Vector3(0, -0.035, -0.02), Color(0.25, 0.18, 0.14), false)

	for n in ["hips", "torso", "head", "arm_r", "fore_r", "arm_l", "fore_l", "leg_r", "shin_r", "leg_l", "shin_l", "sword", "foot_r", "foot_l"]:
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
	# пряди у висков — на физике
	for sx in [-1.0, 1.0]:
		var lock = MeshInstance3D.new()
		lock.set_script(Cloth)
		lock.attach = head
		lock.anchors = [Vector3(0.155 * sx, 0.3, 0.1)]
		lock.cols = 1
		lock.rows = 3
		lock.seg = 0.065
		lock.mode = "chain"
		lock.chain_size = Vector3(0.05, 0.05, 0.065)
		lock.chain_col = hair
		lock.chain_taper = 0.75
		lock.gravity = 8.0
		model.add_child(lock)
		lock.setup()
		cloths.append(lock)

# Лицо: глаза (белок, радужка, зрачок, блик, веко), брови, нос, рот. Мимика — _face_anim.
var eyes: Array = []
var brows: Array = []
var mouth: Node3D
var mouth_open: Node3D
var blink_t := 3.0
var face_brow := 0.0
var face_open := 0.0
var face_squint := 0.0

func _build_face(head: Node3D, skin: Color, hair: Color) -> void:
	var face := Vox.pivot(head, Vector3(0, 0.2, 0.151), "face")
	var white := Color(0.97, 0.96, 0.94)
	var iris := Color(0.3, 0.55, 0.95)
	var dark := Color(0.08, 0.05, 0.08)
	for sx in [-1.0, 1.0]:
		var eye := Vox.pivot(face, Vector3(0.068 * sx, -0.012, 0))
		Vox.box(eye, Vector3(0.075, 0.068, 0.006), Vector3.ZERO, white, false)
		Vox.box(eye, Vector3(0.044, 0.066, 0.008), Vector3(-0.01 * sx, -0.002, 0.001), iris, false, 0.35)
		Vox.box(eye, Vector3(0.024, 0.034, 0.01), Vector3(-0.01 * sx, -0.012, 0.002), dark, false)
		Vox.box(eye, Vector3(0.014, 0.016, 0.012), Vector3(-0.002 * sx, 0.014, 0.003), Color.WHITE, false, 1.0)
		Vox.box(eye, Vector3(0.084, 0.016, 0.012), Vector3(0, 0.036, 0.002), dark, false)    # верхнее веко с ресницами
		eyes.append(eye)
		var brow := Vox.pivot(face, Vector3(0.07 * sx, 0.058, 0.004))
		Vox.box(brow, Vector3(0.082, 0.02, 0.012), Vector3.ZERO, hair, false)
		brows.append(brow)
	Vox.box(face, Vector3(0.022, 0.03, 0.008), Vector3(0, -0.05, 0.0), skin.darkened(0.12), false)   # нос
	mouth = Vox.pivot(face, Vector3(0, -0.098, 0.001))
	Vox.box(mouth, Vector3(0.07, 0.016, 0.006), Vector3.ZERO, Color(0.55, 0.3, 0.3), false)
	mouth_open = Vox.pivot(face, Vector3(0, -0.1, 0.002))
	Vox.box(mouth_open, Vector3(0.06, 0.045, 0.006), Vector3.ZERO, Color(0.3, 0.06, 0.1), false)
	Vox.box(mouth_open, Vector3(0.05, 0.01, 0.008), Vector3(0, 0.014, 0.001), Color(0.95, 0.95, 0.92), false)  # зубы
	mouth_open.scale = Vector3(1, 0.05, 1)

# Мимика: в бою — сдвинутые брови и крик на ударе, от боли — зажмуривается,
# на дыхании — прикрытые глаза, без сознания — закрыты. Моргает сам.
func _face_anim(dt: float) -> void:
	if eyes.is_empty():
		return
	var brow := 0.0          # >0 — злые (внутренние концы вниз), <0 — испуг
	var open := 0.0          # рот открыт
	var squint := 0.0        # прищур / закрытые глаза
	match state:
		"attack", "finisher":
			brow = 1.0
			var a := atk if state == "attack" else ATK["dslash"]
			if state_t >= a.hit0 - 0.04 and state_t <= a.hit1 + 0.1:
				open = 1.0
			squint = 0.25
		"dash", "flash", "wallrun", "draw", "parry", "stance":
			brow = 0.8
			squint = 0.2
		"hurt", "down":
			brow = -1.0
			open = 0.7
			squint = 0.85
		"breathe":
			squint = 0.6
			open = 0.25
		"dead":
			squint = 1.0
			brow = -0.5
		_:
			if sprinting:
				brow = 0.7
				open = 0.3
			elif drawn:
				brow = 0.35
	blink_t -= dt
	if blink_t < 0.0:
		if blink_t > -0.12:
			squint = maxf(squint, 1.0)
		else:
			blink_t = randf_range(2.5, 5.0)
	var r := 1.0 - exp(-18.0 * dt)
	face_brow = lerpf(face_brow, brow, r)
	face_open = lerpf(face_open, open, r)
	face_squint = lerpf(face_squint, squint, 1.0 - exp(-30.0 * dt))
	for i in 2:
		var sx := -1.0 if i == 0 else 1.0
		(eyes[i] as Node3D).scale = Vector3(1, maxf(0.08, 1.0 - face_squint * 0.92), 1)
		var b: Node3D = brows[i]
		b.rotation_degrees = Vector3(0, 0, 18.0 * sx * face_brow)
		b.position.y = 0.058 - 0.012 * maxf(0.0, face_brow) + 0.01 * maxf(0.0, -face_brow)
	mouth_open.scale = Vector3(1, maxf(0.05, face_open), 1)
	mouth.visible = face_open < 0.3

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

# Смена захваченной цели: следующий демон левее (dir < 0) или правее (dir > 0) на экране.
func switch_lock(dir: float) -> void:
	if lock_target == null or G.cam_rig == null:
		return
	var cam: Camera3D = G.cam_rig.cam
	var right := cam.global_transform.basis.x
	var best: Node = null
	var bd := 1e9
	var cur: Vector3 = lock_target.global_position
	for e in G.enemies:
		if not is_instance_valid(e) or e == lock_target or e.is_dead():
			continue
		if e.global_position.distance_to(global_position) > 30.0:
			continue
		var side: float = (e.global_position - cur).dot(right)
		if side * dir <= 0.0:
			continue
		var d: float = absf(side) + (e.global_position - cur).length() * 0.3
		if d < bd:
			bd = d
			best = e
	if best:
		lock_target = best
		G.sfx.play("dash", -14.0, 1.6)

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
		"down": _st_down(dt)
	landing_vel = velocity.y
	move_and_slide()
	if not was_floor and is_on_floor():
		# приземление: присед по силе удара, с разбега и высоко — кувырок
		land_t = 0.0
		land_k = clampf((-landing_vel - 4.0) / 22.0, 0.0, 1.0)
		var hsp := Vector3(velocity.x, 0, velocity.z).length()
		if landing_vel < -22.0 and hsp > 7.0 and state == "move":
			roll_t = 0.0
			flip_t = 0.42
			flip_axis = 1.0
			land_k *= 0.4
			G.sfx.play("dash", -10.0, 0.8)
		if landing_vel < -6.0:
			G.sfx.play("land", lerpf(-16.0, -4.0, land_k), 1.0)
		if landing_vel < -14.0:
			G.fx.dust(global_position, 10)
			G.add_shake(0.08)
	_separate_from_enemies()
	_update_cuts(dt)
	_effects(dt)
	_animate(dt)
	if sword_mode == "whip":
		var striking: bool = state == "attack" and state_t >= atk.hit0 - 0.06 and state_t <= atk.hit1 + 0.12
		whip.extend = move_toward(whip.extend, 1.0 if striking else 0.0, dt * (14.0 if striking else 3.0))
		trail.push(blade_base.global_position, whip.tip())
	else:
		trail.push(blade_base.global_position, blade_tip.global_position)
	if sword_mode == "dual":
		var ds := _dual_side()
		trail_l.emitting = trail.emitting and ds != "r"
		trail.emitting = trail.emitting and ds != "l"
		trail_l.push(sword_l.global_transform * Vector3(0, -0.13, 0), sword_l.global_transform * Vector3(0, -0.95, 0))
		if thrown.visible:
			if state != "attack" or atk_name != "chain":
				thrown.visible = false
				sword_vis.visible = true
		_update_chain()

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
		if not drawn:
			_start_attack("iai")
		else:
			_start_attack("heavy")
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
	back_swords.clear()
	if bandage:
		bandage.build([], [])
	for holder in [sword_vis, sword_l_vis, sheathed_hilt, scabbard_node, back_sheath, thrown]:
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
		thrown.add_child(SwordLib.make(6, _tint()))
		pommel_r = SwordLib.info(6).handle
		pommel_l = SwordLib.info(7).handle
		# за спиной — крест-накрест в бинтах, рукояти над плечами
		var dims := []
		for k in 2:
			var bs := SwordLib.make(6 + k, _tint())
			bs.transform = Transform3D(_back_basis(k), _back_pos(k))
			back_sheath.add_child(bs)
			back_swords.append(bs)
			var inf := SwordLib.info(6 + k)
			dims.append([inf.blade_w, inf.blade_t])
		bandage.build(back_swords, dims)
		bandage.set_full(not drawn)
	elif m == 7 and n >= 9:
		sword_mode = "whip"
		var h := SwordLib.make_part(8, "handle")
		h.position = Vector3(0, -0.1, 0)
		sword_vis.add_child(h)
		# в ножнах — свёрнутый клинок висит на бедре
		var coil := SwordLib.make(8, _tint())
		# в системе бёдер: клинок вниз, свёрнутая лента вдоль бедра
		var hip_xf := Transform3D(Basis.from_euler(Vector3(0.12, 0, -0.08)), Vector3(0.27, 0.12, 0.0))
		coil.transform = (sheath_node.transform * Transform3D(Basis.IDENTITY, sheathed_hilt.position)).affine_inverse() * hip_xf
		sheathed_hilt.add_child(coil)
		blade_len = 0.3
	else:
		sword_mode = "proc"
		_build_proc_sword(sword_vis)
		_build_proc_sword(sheathed_hilt)
		scabbard_node.add_child(SwordLib.make_scabbard(-1, saya_style))
		blade_len = 0.8
	blade_tip.position = Vector3(0, -0.1 - blade_len, 0)
	if whip and sword_mode == "whip":
		whip.set_tint(_tint())
		whip.reset()
	set_drawn(drawn)

# Клинки за спиной (система back_sheath): k=0 — правый (рукоять над правым плечом).
func _back_basis(k: int) -> Basis:
	var ang := 0.55 if k == 0 else -0.55
	return Basis(Vector3(0, 0, 1), ang) * Basis(Vector3.UP, PI * 0.5)

func _back_pos(k: int) -> Vector3:
	return Vector3(-0.13 if k == 0 else 0.13, 0.03, -0.03 if k == 0 else -0.08)

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
	var was := drawn
	drawn = on
	if J.is_empty():
		return
	if sword_mode == "dual" and bandage:
		if on:
			bandage.unwrap_now()           # остатки бинтов — лентами вниз
		elif was:
			bandage.wrap()                 # клинки на спине — бинты наматываются
		else:
			bandage.set_full(true)
	if thrown:
		thrown.visible = false
		sword_vis.visible = true
	J.sword.visible = on
	sword_l.visible = on and sword_mode == "dual"
	sheathed_hilt.visible = not on
	back_sheath.visible = not on and sword_mode == "dual"
	scabbard_node.visible = sword_mode in ["katana", "proc"]
	if chain:
		var cv: bool = sword_mode == "dual"
		if cv and not chain.visible:
			chain.visible = true
			_update_chain()
			chain.reset()
		chain.visible = cv
		chain.length = 1.3 if on else 0.75
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
	if sword_mode == "dual":
		swap_t = 0.17 if not drawn else 0.2
	if not draw_swapped and state_t >= swap_t:
		draw_swapped = true
		if drawn:
			set_drawn(false)
			G.sfx.play("sheathe", -4.0)
		else:
			set_drawn(true)
			G.sfx.play("draw", -2.0)
			G.fx.burst(blade_tip.global_position, Color(0.9, 0.97, 1.0), 6, 3.0, 0.06, 0.25, 0.0)
	var end_t := 0.52 if slow else (0.4 if sword_mode == "dual" else 0.3)
	if state_t > end_t:
		_set_state("move")

func _set_state(s: String) -> void:
	state = s
	state_t = 0.0
	if s == "draw":
		draw_swapped = false
		draw_from_drawn = drawn
		if sword_mode == "dual" and not drawn:
			bandage.unwrap()               # руки к рукоятям — бинты разматываются
			G.sfx.play("whoosh", -9.0, 1.5)

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

# У каждого оружия свой набор: базовое имя удара → удар этого оружия.
const WEAPON_ATK := {
	"dual": {"l1": "d1", "l2": "d2", "l3": "d3", "l4": "d4", "heavy": "chain", "air": "dair"},
	"whip": {"l1": "w1", "l2": "w2", "l3": "w3", "l4": "w4", "heavy": "wheavy", "air": "wair"},
}

func _start_attack(nm: String) -> void:
	nm = WEAPON_ATK.get(sword_mode, {}).get(nm, nm)
	if not drawn:
		set_drawn(true)
		G.sfx.play("draw", -3.0)
		if nm == "iai":
			G.impact(0.05, 1)
	sprinting = false
	atk = ATK[nm]
	# ноги в комбо чередуются: шаг то левой, то правой
	step_lead = -1.0 if nm in ["l2", "dslash", "counter", "iai", "d2", "w2"] else 1.0
	sweep_prev = []
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
	if nm == "chain":
		# бросок на цепи: до демона (сквозь него) или на полную длину
		var dist: float = atk.throw
		var tg2 := _aim_target(atk.throw + 2.0)
		if tg2:
			var to3: Vector3 = tg2.global_position - global_position
			to3.y = 0
			dist = clampf(to3.length() + 0.6, 2.5, atk.throw)
		throw_to = global_position + atk_dir * dist + Vector3.UP * 1.15
		throw_init = false
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
	if atk_name == "chain":
		_throw_update(t)
	# для попадания по клинку: запомнить его положение до окна удара,
	# окно чуть длиннее — суставы на пружинах догоняют позу с запаздыванием
	var sweep_on: bool = a.get("sweep", false)
	if sweep_on and t < a.hit0:
		sweep_prev = _blade_segments()
	if t >= a.hit0 and t <= a.hit1 + (0.07 if sweep_on else 0.0):
		if a.has("multi"):
			multi_t -= dt
			if multi_t <= 0.0:
				multi_t = a.multi
				hit_set.clear()
				if atk_name == "chain":
					G.sfx.play("whoosh", -9.0, 1.4)
				elif atk_name == "d4":
					# вихрь на цепи: стальное кольцо вокруг
					var oo := global_position + Vector3.UP * 1.0
					G.fx.arc(oo, Basis(Vector3.RIGHT, deg_to_rad(randf_range(-12, 12))), 2.6, 0.0, PI * 1.6, 0.3,
						Color(0.6, 0.65, 0.75), Color.WHITE, 0.25, 0, 0.0, 0.06)
					G.sfx.play("whoosh", -8.0, 1.5)
				else:
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
		"chain":
			G.sfx.play("clang", -12.0, 1.6)
		"cross":
			# крест двумя клинками
			G.fx.slash_arc(o, atk_dir, 50.0, 1.9, 140.0, 0.5, Color(0.75, 0.85, 1.0), Color.WHITE, 0, 0.22, false)
			G.fx.slash_arc(o, atk_dir, -50.0, 1.9, 140.0, 0.5, Color(0.75, 0.85, 1.0), Color.WHITE, 0, 0.22, true)
			G.sfx.play("clang", -10.0, 1.3)
		"chain_whirl":
			G.sfx.play("whoosh_big", -6.0, 1.2)
		"lash":
			# хлыст: длинная тонкая дуга
			G.fx.slash_arc(o, atk_dir, a.get("roll", 0.0), 4.2, 150.0, 0.25, Color(0.95, 0.45, 0.7), Color.WHITE, 0, 0.2, a.get("rev", false))
			G.sfx.play("crack", -10.0, 1.6)
		"crack":
			# щелчок хлыста: удар в землю далеко впереди
			var reach: float = a.range * 1.9
			var gp2 := global_position + atk_dir * reach * 0.85 + Vector3.UP * 0.1
			G.fx.slash_arc(o, atk_dir, 90.0, reach * 0.6, 120.0, 0.3, Color(0.95, 0.45, 0.7), Color.WHITE, 0, 0.25)
			G.fx.streak(o + atk_dir * 0.5, gp2, Color(1.0, 0.75, 0.9), 0.25, 0.12)
			G.fx.ring(gp2, 0.5, Color(0.85, 0.8, 0.65), Color.WHITE, 0.35, 3.0, 0.3)
			G.fx.dust(gp2, 10)
			G.sfx.play("crack", -3.0, 1.3)
			G.add_shake(0.2)
		"lash_ring":
			G.fx.arc(o, Basis.IDENTITY, 2.8 * 1.9 * 0.7, 0.0, TAU, 0.35, Color(0.95, 0.45, 0.7), Color.WHITE, 0.4, 0, 0.2, 0.2)
			G.sfx.play("whoosh_big", -4.0, 1.3)

func _attack_fx_tick() -> void:
	# Водоворот: волна вокруг тела на каждом обороте
	var o := global_position + Vector3.UP * (0.9 + state_t * 0.5)
	var b := Basis(Vector3.RIGHT, deg_to_rad(randf_range(-20, 20))) * Basis(Vector3.UP, randf() * TAU)
	G.fx.arc(o, b, 2.3, 0.0, PI * 1.5, 0.9, Color(0.15, 0.45, 0.95), Color(0.9, 0.97, 1.0), 0.32, 1, 0.0, 0.08)
	G.fx.droplets(o, Vector3.UP, 5)
	G.sfx.play("whoosh", -8.0, 1.2)

# ---------------------------------------------------------------------
# Попадание по движению клинка: отрезок лезвия (с «ветром» SWEEP_EXT) в этом
# и прошлом кадре заметает полосу; кто в неё попал — по тому и удар.
func _blade_segments() -> Array:
	var segs := []
	if sword_mode == "whip":
		var pts: Array = [blade_base.global_position]
		for i in range(0, whip.n, 2):
			pts.append(whip.pos[i])
		pts.append(whip.tip())
		for i in pts.size() - 1:
			segs.append([pts[i], pts[i + 1]])
		return segs
	var side := _dual_side() if sword_mode == "dual" else "r"
	if side != "l":
		var a := blade_base.global_position
		var b := blade_tip.global_position
		segs.append([a, b + (b - a).normalized() * SWEEP_EXT])
	if sword_mode == "dual" and side != "r":
		var a2 := sword_l.global_transform * Vector3(0, -0.13, 0)
		var b2 := sword_l.global_transform * Vector3(0, -0.95, 0)
		segs.append([a2, b2 + (b2 - a2).normalized() * SWEEP_EXT])
	return segs

# Ближайшие точки двух отрезков: [расстояние, точка на втором].
static func seg_seg(p1: Vector3, q1: Vector3, p2: Vector3, q2: Vector3) -> Array:
	var d1 := q1 - p1
	var d2 := q2 - p2
	var r := p1 - p2
	var a := d1.dot(d1)
	var e := d2.dot(d2)
	var f := d2.dot(r)
	var sc := 0.0
	var tc := 0.0
	if a < 1e-8 and e < 1e-8:
		return [r.length(), p2]
	if a < 1e-8:
		tc = clampf(f / e, 0.0, 1.0)
	else:
		var c := d1.dot(r)
		if e < 1e-8:
			sc = clampf(-c / a, 0.0, 1.0)
		else:
			var b := d1.dot(d2)
			var den := a * e - b * b
			sc = clampf((b * f - c * e) / den, 0.0, 1.0) if den > 1e-8 else 0.0
			tc = (b * sc + f) / e
			if tc < 0.0:
				tc = 0.0
				sc = clampf(-c / a, 0.0, 1.0)
			elif tc > 1.0:
				tc = 1.0
				sc = clampf((b - c) / a, 0.0, 1.0)
	var c1 := p1 + d1 * sc
	var c2 := p2 + d2 * tc
	return [c1.distance_to(c2), c2]

# Полоса клинка: подотрезки между прошлым и текущим кадром.
func _swept() -> Array:
	var cur := _blade_segments()
	var out := []
	for i in cur.size():
		if i < sweep_prev.size():
			for k in 4:
				var f := float(k) / 3.0
				out.append([(sweep_prev[i][0] as Vector3).lerp(cur[i][0], f), (sweep_prev[i][1] as Vector3).lerp(cur[i][1], f)])
		else:
			out.append(cur[i])
	sweep_prev = cur
	return out

func _sweep_hits() -> void:
	var a := atk
	var band := _swept()
	for e in G.enemies:
		if not is_instance_valid(e) or e.is_dead() or hit_set.has(e.get_instance_id()):
			continue
		var e0: Vector3 = e.global_position + Vector3.UP * 0.3
		var e1: Vector3 = e.global_position + Vector3.UP * 2.3
		var best := 99.0
		var pt := Vector3.ZERO
		for sg in band:
			var r: Array = seg_seg(e0, e1, sg[0], sg[1])
			if r[0] < best:
				best = r[0]
				pt = r[1]
		if best > e.radius + SWEEP_PAD:
			continue
		hit_set[e.get_instance_id()] = true
		var flat: Vector3 = e.global_position - global_position
		flat.y = 0
		var dir := flat.normalized() if flat.length() > 0.1 else atk_dir
		var res: Dictionary = e.take_hit(a.dmg, dir, a)
		res["point"] = pt
		_on_hit(e, res, dir)
	for b in get_tree().get_nodes_in_group("breakable"):
		if not is_instance_valid(b) or hit_set.has(b.get_instance_id()):
			continue
		var c: Vector3 = b.center()
		var bd := 99.0
		for sg in band:
			var r2: Array = seg_seg(c, c, sg[0], sg[1])
			bd = minf(bd, r2[0])
		if bd > b.brad + SWEEP_PAD:
			continue
		hit_set[b.get_instance_id()] = true
		var fl: Vector3 = c - global_position
		fl.y = 0
		if b.slash_hit(global_position, fl.normalized() if fl.length() > 0.1 else atk_dir, a.power):
			G.hitstop(0.03)
			G.add_shake(0.12)

# ---------------------------------------------------------------------
# Бросок на цепи: правый клинок летит к цели, крутясь, и возвращается в руку.
func _throw_k(t: float) -> float:
	var a := atk
	var mid: float = (a.hit0 + a.hit1) * 0.5
	if t < a.hit0 or t > a.hit1:
		return 0.0
	if t < mid:
		return Vox.ease_out((t - a.hit0) / (mid - a.hit0))
	return 1.0 - Vox.ease_in_out((t - mid) / (a.hit1 - mid))

func _throw_update(t: float) -> void:
	var a := atk
	var flying: bool = t >= a.hit0 and t <= a.hit1
	thrown.visible = flying and sword_mode == "dual"
	sword_vis.visible = not thrown.visible
	if not thrown.visible:
		return
	var hand: Vector3 = J.sword.global_transform * Vector3(0, -0.1, 0)
	if not throw_init:
		throw_init = true
		throw_from = hand
	var k := _throw_k(t)
	# туда — по прямой с небольшой дугой, обратно — в текущее положение руки
	var mid: float = (a.hit0 + a.hit1) * 0.5
	var from := throw_from if t < mid else hand
	var p := from.lerp(throw_to, k) + Vector3.UP * sin(k * PI) * 0.35
	var axis := atk_dir.cross(Vector3.UP).normalized()
	var spin: float = (t - a.hit0) * 26.0
	thrown.global_transform = Transform3D(Basis(axis, spin) * Basis(Vector3.UP, facing), p)
	# мазок клинка в полёте не рисуем: при вращении он растягивается на полэкрана
	trail.emitting = false
	trail_l.emitting = false

func _throw_hits() -> void:
	var a := atk
	if not thrown.visible:
		return
	var c := thrown.global_transform * Vector3(0, -0.45, 0)
	for e in G.enemies:
		if not is_instance_valid(e) or e.is_dead() or hit_set.has(e.get_instance_id()):
			continue
		var to: Vector3 = e.global_position + Vector3.UP * 1.1 - c
		if Vector3(to.x, 0, to.z).length() > e.radius + 1.0 or absf(to.y) > 1.8:
			continue
		hit_set[e.get_instance_id()] = true
		var dir := Vector3(to.x, 0, to.z).normalized() if Vector3(to.x, 0, to.z).length() > 0.1 else atk_dir
		var res: Dictionary = e.take_hit(a.dmg, dir, a)
		_on_hit(e, res, dir)
	for b in get_tree().get_nodes_in_group("breakable"):
		if not is_instance_valid(b) or hit_set.has(b.get_instance_id()):
			continue
		var to2: Vector3 = b.center() - c
		if Vector3(to2.x, 0, to2.z).length() > b.brad + 0.7:
			continue
		hit_set[b.get_instance_id()] = true
		if b.slash_hit(global_position, atk_dir, a.power):
			G.hitstop(0.03)

func _update_chain() -> void:
	if chain == null or sword_mode != "dual":
		return
	if drawn:
		chain.pa = sword_l.global_transform * Vector3(0, -0.1 + pommel_l, 0)
		if thrown.visible:
			chain.pb = thrown.global_transform * Vector3(0, pommel_r, 0)
		else:
			chain.pb = J.sword.global_transform * Vector3(0, -0.1 + pommel_r, 0)
	elif back_swords.size() == 2:
		chain.pb = back_swords[0].global_transform * Vector3(0, pommel_r, 0)
		chain.pa = back_swords[1].global_transform * Vector3(0, pommel_l, 0)

func _check_hits() -> void:
	var a := atk
	if atk_name == "chain":
		_throw_hits()
		return
	if a.get("sweep", false):
		_sweep_hits()
		return
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

# Сбит с ног: лежит, потом встаёт. Рывок или прыжок — вскочить раньше.
# Шаг: звук по поверхности (утоптанная поляна и деревня — земля, остальное — трава).
func _footstep(sp: float) -> void:
	var p := global_position
	var dirt := (absf(p.x) < 10.0 and absf(p.z) < 10.0) or state == "wallrun"
	var vol := lerpf(-22.0, -10.0, clampf(sp / SPRINT_SPEED, 0.0, 1.0))
	G.sfx.play("step_dirt" if dirt else "step_grass", vol, 1.0 + randf_range(-0.1, 0.1))

func _st_down(dt: float) -> void:
	var on_floor := is_on_floor()
	if on_floor:
		velocity.x = move_toward(velocity.x, 0, 22 * dt)
		velocity.z = move_toward(velocity.z, 0, 22 * dt)
	_gravity(dt)
	if state_t > 0.4 and state_t < DOWN_GETUP and on_floor and (pressed("jump") or pressed("dash")):
		# подъём прыжком
		_set_state("move")
		velocity.y = 7.0
		flip_t = 0.42
		flip_axis = -1.0
		invuln_t = 0.3
		G.sfx.play("jump", -6.0, 1.2)
		return
	if state_t > DOWN_END:
		_set_state("move")

func _st_dead(dt: float) -> void:
	velocity.x = 0
	velocity.z = 0
	_gravity(dt)
	# возрождение: само через 4 с или сразу по Пробелу / удару
	if state_t > 4.0 or (state_t > 1.5 and (pressed("jump") or pressed("light"))):
		hp = max_hp
		breath = max_breath
		clear_cuts()
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
	_add_cut(src)
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
		return "hit"
	hurt_dir = kb
	if dmg >= 18.0:
		# сильный удар сбивает с ног
		velocity = kb * 11.0 + Vector3.UP * 6.0
		invuln_t = DOWN_END
		sprinting = false
		_set_state("down")
		return "hit"
	velocity = kb * 9.0 + Vector3.UP * 3.0
	_set_state("hurt")
	return "hit"

# Порез на одежде героя: тёмно-красная полоса поперёк ближайшей части тела.
# Со временем затягивается (cut_life), при возрождении исчезает.
var cuts: Array = []

func _add_cut(src: Vector3) -> void:
	var hit_p := global_position + Vector3(randf_range(-0.2, 0.2), randf_range(0.6, 1.5), 0) + (src - global_position).normalized() * 0.2
	var best: MeshInstance3D = null
	var bd := 99.0
	for jn in ["torso", "arm_r", "arm_l", "fore_r", "fore_l", "leg_r", "leg_l", "shin_r", "shin_l", "hips"]:
		for c in J[jn].get_children():
			if c is MeshInstance3D and c.mesh is BoxMesh and c.mesh.size.y > 0.15:
				var dd: float = c.global_position.distance_to(hit_p)
				if dd < bd:
					bd = dd
					best = c
	if best == null:
		return
	var sz: Vector3 = best.mesh.size
	var w := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(sz.x * 1.06, randf_range(0.025, 0.04), sz.z * 1.06)
	w.mesh = bm
	w.material_override = Vox.cel_mat(Color(0.5, 0.04, 0.08), false, 0.35)
	w.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	best.add_child(w)
	w.position = Vector3(0, randf_range(-sz.y * 0.3, sz.y * 0.3), 0)
	w.rotation_degrees = Vector3(randf_range(-10, 10), 0, randf_range(-35, 35))
	cuts.append({"n": w, "life": 25.0})
	if cuts.size() > 10:
		var old: Dictionary = cuts.pop_front()
		if is_instance_valid(old.n):
			old.n.queue_free()

func _update_cuts(dt: float) -> void:
	for i in range(cuts.size() - 1, -1, -1):
		var c: Dictionary = cuts[i]
		c.life -= dt
		if not is_instance_valid(c.n) or c.life <= 0.0:
			if is_instance_valid(c.n):
				c.n.queue_free()
			cuts.remove_at(i)
		elif c.life < 2.0:
			c.n.scale = Vector3(1, c.life / 2.0, 1)

func clear_cuts() -> void:
	for c in cuts:
		if is_instance_valid(c.n):
			c.n.queue_free()
	cuts.clear()

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
# Слои: базовая поза состояния → движение тела (наклон от ускорения, крен
# в поворотах, фазы прыжка, приземление) → пружины суставов (инерция,
# лёгкий перехлёст, плавные переходы между любыми позами).
var jvel := {}
var bsp := {"lean": 0.0, "lean_v": 0.0, "roll": 0.0, "roll_v": 0.0, "hy": HIP_Y, "hy_v": 0.0, "my": 0.0, "my_v": 0.0}
var prev_hv := Vector3.ZERO
var acc_s := Vector3.ZERO
var turn_s := 0.0
var prev_facing := 0.0
var land_t := 9.0
var land_k := 0.0
var roll_t := 9.0
var idle_t := 0.0
var step_lead := 1.0          # какая нога впереди в ударе (1 — левая, -1 — правая)
const DOWN_GETUP := 0.85      # сбит с ног: когда начинает вставать
const DOWN_END := 1.25

func _spring_f(key: String, target: float, w: float, z: float, dt: float) -> float:
	var x: float = bsp[key]
	var v: float = bsp[key + "_v"]
	v += (w * w * (target - x) - 2.0 * z * w * v) * dt
	x += v * dt
	bsp[key] = x
	bsp[key + "_v"] = v
	return x

func _animate(dt: float) -> void:
	var p := {}
	for k in J:
		p[k] = Vector3.ZERO
	var hips_y := HIP_Y
	var model_y := 0.0
	var lean := 0.0
	var roll := 0.0
	var hv := Vector3(velocity.x, 0, velocity.z)
	var sp := hv.length()
	var snap := false
	var model_spin := 0.0
	var on_floor := is_on_floor()
	var fwd := Vector3(sin(facing), 0, cos(facing))
	var side_x := Vector3(cos(facing), 0, -sin(facing))     # +X модели (левый бок героя)

	# --- движение тела: ускорение и поворот ---
	var acc := (hv - prev_hv) / maxf(dt, 0.001)
	prev_hv = hv
	acc_s = acc_s.lerp(acc, 1.0 - exp(-12.0 * dt))
	var dfa := wrapf(facing - prev_facing, -PI, PI)
	prev_facing = facing
	turn_s = lerpf(turn_s, dfa / maxf(dt, 0.001), 1.0 - exp(-10.0 * dt))
	land_t += dt
	roll_t += dt
	var t_real := G.real_time

	# базовая стойка с клинком: кулаки у живота, клинок вперёд и чуть вверх, лезвие вниз
	p.arm_r = IDLE_ARM
	p.fore_r = Vector3(IDLE_FORE, 0, 0)
	p.arm_l = Vector3(-30, 20, 15)
	p.fore_l = Vector3(-50, 0, 0)
	p.sword = Vector3(0, 0, 0)
	if not drawn:
		# клинок в ножнах: левая рука придерживает ножны у устья, правая свободна
		p.arm_r = Vector3(-10, 0, -8)
		p.fore_r = Vector3(-25, 0, 0)
		p.arm_l = Vector3(15, -25, 18)
		p.fore_l = Vector3(-45, 0, 0)

	var free_body: bool = state in ["move", "breathe", "parry", "stance"]
	if free_body:
		if on_floor and sp > 0.8:
			idle_t = 0.0
			# --- бег ---
			var k := clampf(sp / RUN_SPEED, 0.0, 1.3)
			var prev_s := sin(run_phase)
			run_phase += dt * (5.5 + sp * 0.6)
			var s := sin(run_phase)
			if signf(s) != signf(prev_s):
				_footstep(sp)
			var c := cos(run_phase)
			p.leg_r = Vector3(-s * 58 * k, 0, -3)
			p.leg_l = Vector3(s * 58 * k, 0, 3)
			# колено сгибается, когда нога уходит назад и проносится вперёд
			p.shin_r = Vector3(maxf(0.0, c) * 85 * k + maxf(0.0, s) * 25 * k + 8, 0, 0)
			p.shin_l = Vector3(maxf(0.0, -c) * 85 * k + maxf(0.0, -s) * 25 * k + 8, 0, 0)
			hips_y = HIP_Y - absf(c) * 0.06 * k - 0.04 * k
			# таз крутится за ногами, корпус — против, голова смотрит вперёд
			p.hips = Vector3(0, -s * 10 * k, -c * 3 * k)
			p.torso = Vector3(6 + 4 * k, s * 14 * k, c * 2 * k)
			p.head = Vector3(-4, -s * 4 * k, 0)
			lean = 6.0 * k
			if sp > 9.0:
				# быстрый бег: корпус вперёд, руки и клинок назад
				var kf := minf(1.0, (sp - 9.0) / 5.0)
				lean = lerpf(lean, 30.0, kf)
				p.torso = Vector3(10, s * 8, 0)
				p.arm_r = Vector3(70 + s * 6, 0, -15)
				p.fore_r = Vector3(-20, 0, 0)
				p.sword = Vector3(-60, 0, 0)
				p.arm_l = Vector3(70 - s * 6, 0, 15)
				p.fore_l = Vector3(-20, 0, 0)
				p.head = Vector3(-25, 0, 0)
				if sprinting:
					lean = 42.0
					p.arm_r = Vector3(85, 0, -20)
					p.arm_l = Vector3(85, 0, 20)
			elif not drawn:
				# в ножнах: правая рука машет против ноги, левая держит ножны
				p.arm_r = Vector3(s * 42 * k, 0, -10)
				p.fore_r = Vector3(-30 - maxf(0.0, -s) * 30 * k, 0, 0)
			else:
				p.arm_l = Vector3(-s * 30, 0, 10)
		elif on_floor:
			# --- стойка на месте: ноги шире, дыхание, перенос веса, взгляд по сторонам ---
			idle_t += dt
			var br := sin(t_real * 2.0)
			var sway := sin(t_real * 0.7)
			p.leg_r = Vector3(-15, 0, -8 - sway * 2)
			p.leg_l = Vector3(12, 0, 8 - sway * 2)
			p.shin_r = Vector3(20, 0, 0)
			p.shin_l = Vector3(12, 0, 0)
			p.hips = Vector3(0, -8, sway * 2.5)
			p.torso = Vector3(br * 3.0, -8, -sway * 2.0)
			hips_y = HIP_Y - 0.05 + br * 0.008
			if idle_t > 3.0:
				p.head = Vector3(0, sin(idle_t * 0.45) * 22.0 * clampf((idle_t - 3.0) / 1.5, 0.0, 1.0), 0)
		else:
			# --- в воздухе: фазы прыжка ---
			idle_t = 0.0
			var up := clampf(velocity.y / 8.0, 0.0, 1.0)
			var down := clampf(-velocity.y / 12.0, 0.0, 1.0)
			var apex := 1.0 - maxf(up, down)
			# взлёт: толчковая нога вытянута, маховая поджата; вершина — группировка;
			# падение — ноги вниз навстречу земле, руки в стороны для равновесия
			p.leg_r = Vector3(-55 * up - 70 * apex - 25 * down, 0, 0)
			p.shin_r = Vector3(85 * up + 110 * apex + 30 * down, 0, 0)
			p.leg_l = Vector3(15 * up - 55 * apex + 8 * down, 0, 0)
			p.shin_l = Vector3(15 * up + 100 * apex + 22 * down, 0, 0)
			p.torso = Vector3(10 * apex - 4 * down, 0, 0)
			p.head = Vector3(-6 * up + 10 * down, 0, 0)
			lean = clampf(sp * 1.2, 0.0, 18.0) + 10.0 * apex - 6.0 * down
			if not drawn or sp > 9.0:
				p.arm_r = Vector3(30 * up - 25 * down - 30 * apex, 0, -40 * up - 65 * down - 20 * apex)
				p.arm_l = Vector3(30 * up - 25 * down - 30 * apex, 0, 40 * up + 65 * down + 20 * apex)
				p.fore_r = Vector3(-30, 0, 0)
		if on_floor:
			# наклон от ускорения (разгон — вперёд, торможение — назад) и крен в поворотах
			var acc_f := acc_s.dot(fwd)
			lean += clampf(acc_f * 0.35, -24.0, 14.0)
			roll += clampf(-turn_s * sp * 0.3, -18.0, 18.0)
			if acc_f < -25.0 and sp > 4.0:
				# торможение юзом: ноги вперёд, присед
				var kb := clampf((-acc_f - 25.0) / 40.0, 0.0, 1.0)
				p.leg_r = p.leg_r.lerp(Vector3(-45, 0, -6), kb)
				p.leg_l = p.leg_l.lerp(Vector3(10, 0, 6), kb)
				p.shin_r = p.shin_r.lerp(Vector3(30, 0, 0), kb)
				p.shin_l = p.shin_l.lerp(Vector3(70, 0, 0), kb)
				hips_y -= 0.1 * kb

	if state == "wallrun":
		var prev_s2 := sin(run_phase)
		run_phase += dt * 16.0
		var s2 := sin(run_phase)
		if signf(s2) != signf(prev_s2):
			_footstep(20.0)
		p.leg_r = Vector3(-s2 * 60, 0, 0)
		p.leg_l = Vector3(s2 * 60, 0, 0)
		p.shin_r = Vector3(40 + s2 * 30, 0, 0)
		p.shin_l = Vector3(40 - s2 * 30, 0, 0)
		p.arm_r = Vector3(60, 0, -20)
		p.fore_r = Vector3(-20, 0, 0)
		p.arm_l = Vector3(60, 0, 20)
		p.sword = Vector3(-60, 0, 0)
		p.torso = Vector3(10, s2 * 10, 0)
		if wall_vertical:
			lean = -10.0
		else:
			roll = -sign(wall_n.dot(side_x)) * 28.0
			lean = 15.0
	if state == "dash" or state == "flash":
		# рывок: низкий выпад, толчковая нога вытянута назад, руки и клинок назад
		lean = 45.0
		p.arm_r = Vector3(75, 0, -20)
		p.arm_l = Vector3(75, 0, 20)
		p.fore_r = Vector3(-10, 0, 0)
		p.sword = Vector3(-70, 0, 0)
		p.leg_r = Vector3(-55, 0, 0)
		p.shin_r = Vector3(80, 0, 0)
		p.leg_l = Vector3(40, 0, 0)
		p.shin_l = Vector3(35, 0, 0)
		p.head = Vector3(-30, 0, 0)
		hips_y = HIP_Y - 0.12
		snap = true
	if state == "parry":
		# блок: шаг назад, клинок поперёк, корпус развёрнут
		var k2 := Vox.ease_out(state_t / 0.08)
		p.arm_r = Vector3(-100, 25, -10) * k2
		p.fore_r = Vector3(-60, 0, 0)
		p.sword = Vector3(0, 0, 90) * k2
		p.arm_l = Vector3(-90, -20, 20)
		p.torso = Vector3(-5, -20, 0)
		p.leg_r = Vector3(25, 0, -10)
		p.shin_r = Vector3(35, 0, 0)
		p.leg_l = Vector3(-20, 0, 10)
		p.shin_l = Vector3(25, 0, 0)
		hips_y = HIP_Y - 0.1
		lean = -8.0
		snap = true
	if state == "stance" or state == "breathe":
		p.arm_r = Vector3(-15, -10, -10)
		p.fore_r = Vector3(-20, 0, 0)
		p.sword = Vector3(30, 0, 0)
		p.arm_l = Vector3(-15, 10, 10)
		p.leg_r = Vector3(-25, 0, -12)
		p.leg_l = Vector3(28, 0, 12)
		p.shin_r = Vector3(35, 0, 0)
		p.shin_l = Vector3(30, 0, 0)
		p.hips = Vector3(0, -15, 0)
		p.torso = Vector3(4, 0, 0)
		hips_y = HIP_Y - 0.12
		if state == "breathe":
			p.torso = Vector3(sin(t_real * 5.0) * 4.0, 0, 0)
			p.head = Vector3(-10, 0, 0)
	if state == "draw":
		# рука к рукояти на левом бедре
		var kd := Vox.ease_out(state_t / 0.12)
		p.arm_r = Vector3(-25, 70, 30) * kd
		p.fore_r = Vector3(-60, 0, 0)
		p.torso = Vector3(5, 25 * kd, 0)
		p.hips = Vector3(0, -10 * kd, 0)
		p.arm_l = Vector3(15, -25, 18)
		p.leg_r = Vector3(-15, 0, -8)
		p.leg_l = Vector3(15, 0, 8)
		p.shin_r = Vector3(25, 0, 0)
		p.shin_l = Vector3(20, 0, 0)
		hips_y = HIP_Y - 0.06
		if sword_mode == "dual":
			# руки за спину: корпус чуть вперёд, плечи раскрыты
			p.torso = Vector3(10 * kd, 0, 0)
			p.hips = Vector3.ZERO
			p.head = Vector3(8 * kd, 0, 0)
			p.arm_l = Vector3(-25, -70, -30) * kd
		snap = true
	if state == "hurt":
		# удар отбрасывает: корпус откидывается от удара, голова дёргается, руки врозь
		var f := hurt_dir.dot(fwd)
		var sd := hurt_dir.dot(side_x)
		var kh := 1.0 - clampf((state_t - 0.12) / 0.26, 0.0, 1.0)
		lean = 32.0 * f * kh
		roll = -26.0 * sd * kh
		p.head = Vector3(-30 * f * kh, 0, 0)
		p.torso = Vector3(-15 * kh, 0, 0)
		p.arm_r = Vector3(-30, 0, -55) * kh
		p.arm_l = Vector3(-30, 0, 55) * kh
		p.leg_r = Vector3(25, 0, -10) * kh
		p.shin_r = Vector3(40, 0, 0) * kh
		p.leg_l = Vector3(-25, 0, 10) * kh
		p.shin_l = Vector3(20, 0, 0) * kh
		hips_y = HIP_Y - 0.08 * kh
		snap = true
	if state == "down":
		# сбит с ног: падает на спину, лежит, поднимается через присед
		var t := state_t
		if t < DOWN_GETUP:
			var kf2 := Vox.ease_out(t / 0.28)
			lean = -88.0 * kf2
			model_y = 0.14 * kf2
			p.leg_r = Vector3(-30, 0, -10) * kf2
			p.leg_l = Vector3(-50, 0, 12) * kf2
			p.shin_r = Vector3(40, 0, 0) * kf2
			p.shin_l = Vector3(70, 0, 0) * kf2
			p.arm_r = Vector3(-60, 0, -70) * kf2
			p.arm_l = Vector3(-60, 0, 70) * kf2
			p.head = Vector3(20, 0, 0) * kf2
		else:
			var kg := Vox.ease_in_out((t - DOWN_GETUP) / (DOWN_END - DOWN_GETUP))
			# сначала сесть (колени к груди), потом встать
			var sit := sin(kg * PI)
			lean = lerpf(-88.0, 0.0, kg) + 35.0 * sit
			model_y = 0.14 * (1.0 - kg)
			p.leg_r = Vector3(-110 * sit, 0, -8)
			p.leg_l = Vector3(-100 * sit, 0, 8)
			p.shin_r = Vector3(130 * sit, 0, 0)
			p.shin_l = Vector3(120 * sit, 0, 0)
			p.arm_r = Vector3(-50 * sit, 0, -30 * sit)
			p.arm_l = Vector3(-50 * sit, 0, 30 * sit)
			hips_y = HIP_Y - 0.45 * sit
		snap = true
	if state == "dead":
		# на колени, потом вперёд лицом в землю
		var t2 := state_t
		var kn := Vox.ease_out(t2 / 0.35)
		var fall := Vox.ease_in_out((t2 - 0.55) / 0.35)
		p.leg_r = Vector3(-20, 0, -6) * kn
		p.leg_l = Vector3(-20, 0, 6) * kn
		p.shin_r = Vector3(110, 0, 0) * kn
		p.shin_l = Vector3(110, 0, 0) * kn
		p.torso = Vector3(25, 0, 0) * kn
		p.head = Vector3(30, 0, 0) * kn
		p.arm_r = Vector3(10, 0, -10)
		p.arm_l = Vector3(10, 0, 10)
		hips_y = lerpf(HIP_Y, 0.45, kn)
		lean = 80.0 * fall
		model_y = 0.12 * fall
		snap = true
	if state == "attack" or state == "finisher":
		var a := atk if state == "attack" else ATK["dslash"]
		var t := state_t if state == "attack" else (0.08 if fin_stage == 0 else 0.3)
		var arm := Vector3.ZERO
		var fore := 0.0
		var tw := 0.0
		var st := 0.0           # шаг в удар: 0 — вес на задней ноге, 1 — выпад
		var wind := 0.0         # замах
		var swing_k := 0.0
		if t < a.hit0:
			var k3 := Vox.ease_out(t / maxf(0.01, a.hit0))
			arm = p.arm_r.lerp(a.arm0, k3)
			fore = lerpf(p.fore_r.x, a.fore0, k3)
			# корпус закручивается чуть дальше руки — замах всем телом
			tw = lerpf(0.0, a.tw0 * 1.2, k3)
			wind = k3
			st = -0.25 * k3
		elif t < a.hit1:
			var raw: float = (t - a.hit0) / maxf(0.01, a.hit1 - a.hit0)
			var k4 := Vox.ease_in_out(raw)
			swing_k = k4
			arm = a.arm0.lerp(a.arm1, k4)
			fore = lerpf(a.fore0, a.fore1, k4)
			# корпус ведёт: доворачивается раньше руки
			tw = lerpf(a.tw0 * 1.2, a.tw1, Vox.ease_out(minf(1.0, raw * 1.4)))
			st = Vox.ease_out(minf(1.0, raw * 1.6))
		else:
			var k5 := clampf((t - a.hit1) / maxf(0.01, a.dur - a.hit1), 0.0, 1.0)
			k5 = Vox.ease_in_out((k5 - 0.35) / 0.65) if k5 > 0.35 else 0.0
			arm = a.arm1.lerp(IDLE_ARM, k5)
			fore = lerpf(a.fore1, IDLE_FORE, k5)
			tw = lerpf(a.tw1, 0.0, k5)
			st = 1.0 - k5
			swing_k = 1.0
		p.arm_r = arm
		p.fore_r = Vector3(fore, 0, 0)
		# поворот делят таз и корпус, голова держит цель
		p.hips = Vector3(0, tw * 0.35, 0)
		p.torso = Vector3(6 + 10 * maxf(0.0, st) - 6 * wind, tw * 0.7, 0)
		p.head = Vector3(-8 * maxf(0.0, st), -tw * 0.6, 0)
		# кисть: лезвие смотрит по ходу удара (горизонтальные — вбок, вертикальные — вниз)
		var wr: float = a.get("wr", 90.0 if a.get("rev", false) else -90.0)
		p.sword = Vector3(0, wr * clampf(t / maxf(0.01, a.hit0), 0.0, 1.0), 0)
		p.arm_l = Vector3(-40, 40, 30)
		# ноги: ведущая вперёд, задняя вытянута; при выпаде таз ниже
		var lead := step_lead
		var front := Vector3(-30 - 22 * st, 0, 8 * lead)
		var back := Vector3(25 + 18 * st, 0, -8 * lead)
		if lead > 0.0:
			p.leg_l = front
			p.leg_r = back
			p.shin_l = Vector3(20 + 25 * maxf(0.0, st), 0, 0)
			p.shin_r = Vector3(30 + 20 * maxf(0.0, st), 0, 0)
		else:
			p.leg_r = Vector3(front.x, 0, -front.z)
			p.leg_l = Vector3(back.x, 0, -back.z)
			p.shin_r = Vector3(20 + 25 * maxf(0.0, st), 0, 0)
			p.shin_l = Vector3(30 + 20 * maxf(0.0, st), 0, 0)
		hips_y = HIP_Y - 0.06 - 0.1 * maxf(0.0, st)
		lean = 6.0 + 14.0 * maxf(0.0, st) - 6.0 * wind
		snap = true
		if a.has("spin"):
			var ks := clampf((t - a.hit0) / maxf(0.01, a.hit1 - a.hit0), 0.0, 1.0)
			model_spin = ks * TAU * a.spin
		if a.get("air", false) or atk_name == "f2":
			p.leg_r = Vector3(-60, 0, 0)
			p.shin_r = Vector3(90, 0, 0)
			p.leg_l = Vector3(-20, 0, 0)
			p.shin_l = Vector3(60, 0, 0)
			p.hips = Vector3.ZERO
			hips_y = HIP_Y

	if sword_mode == "dual" and drawn and state == "attack":
		# удар левой — зеркало правой позы; правая в это время держит стойку (IK)
		var side := _dual_side()
		if side == "l" or side == "both":
			var ar: Vector3 = p.arm_r
			p.arm_l = Vector3(ar.x, -ar.y, -ar.z)
			p.fore_l = p.fore_r

	# --- приземление: присед тем глубже, чем сильнее удар о землю; кувырок с разбега ---
	if land_t < 0.32 and state in ["move", "attack"]:
		var kk := (1.0 - land_t / 0.32) * land_k
		hips_y -= 0.24 * kk
		p.leg_r += Vector3(-40, 0, 0) * kk
		p.leg_l += Vector3(-30, 0, 0) * kk
		p.shin_r += Vector3(75, 0, 0) * kk
		p.shin_l += Vector3(65, 0, 0) * kk
		p.torso += Vector3(18, 0, 0) * kk
		if state == "move" and (not drawn or sp > 9.0):
			p.arm_r += Vector3(-20, 0, -25) * kk
			p.arm_l += Vector3(-20, 0, 25) * kk
	if roll_t < 0.42:
		# кувырок: сгруппироваться
		p.leg_r = Vector3(-110, 0, 0)
		p.leg_l = Vector3(-100, 0, 0)
		p.shin_r = Vector3(130, 0, 0)
		p.shin_l = Vector3(125, 0, 0)
		p.torso = Vector3(35, 0, 0)
		p.head = Vector3(30, 0, 0)
		hips_y = HIP_Y - 0.3
		snap = true

	# стопы: на земле держатся ровно (против наклона ноги и тела), в воздухе — носок вниз
	for sd in ["r", "l"]:
		var flat := -((p["leg_" + sd] as Vector3).x + (p["shin_" + sd] as Vector3).x)
		if on_floor and state not in ["down", "dead"]:
			flat -= lean
			p["foot_" + sd] = Vector3(clampf(flat * 0.85, -55.0, 45.0), 0, 0)
		else:
			p["foot_" + sd] = Vector3(clampf(flat * 0.3 + 20.0, -30.0, 50.0), 0, 0)

	# --- пружины суставов: плавно, с инерцией и лёгким перехлёстом ---
	var w := 40.0 if snap else 20.0
	var zeta := 0.82 if snap else 0.72
	var dtc := minf(dt, 1.0 / 30.0)
	for k in J:
		var cur: Vector3 = rest[k]
		var v: Vector3 = jvel.get(k, Vector3.ZERO)
		v += (w * w * (p[k] - cur) - 2.0 * zeta * w * v) * dtc
		cur += v * dtc
		rest[k] = cur
		jvel[k] = v
		J[k].rotation_degrees = cur + (SWORD_TILT if k == "sword" else Vector3.ZERO)
	J.hips.position.y = _spring_f("hy", hips_y, 26.0 if snap else 18.0, 0.8, dtc)
	model.position.y = _spring_f("my", model_y, 16.0, 0.9, dtc)
	var lean_s := _spring_f("lean", lean, 24.0 if snap else 14.0, 0.75, dtc)
	var roll_s := _spring_f("roll", roll, 16.0, 0.8, dtc)
	var flip := 0.0
	if flip_t > 0.0:
		flip = (1.0 - flip_t / 0.42) * TAU * flip_axis
	model.rotation = Vector3(deg_to_rad(lean_s) + flip, facing + model_spin, deg_to_rad(roll_s))
	if sword_mode == "dual":
		var sw: Vector3 = J.sword.rotation_degrees
		sword_l.rotation_degrees = Vector3(sw.x, -sw.y, -sw.z)
	_apply_ik(dt, sp)
	_face_anim(dt)

# ---------------------------------------------------------------------
# Двуручный хват катаны: руки сами тянутся к рукояти (обратная кинематика).
# Парные клинки: какой рукой идёт удар (r — правой, l — левой, both — обеими).
const DUAL_SIDE := {"l1": "r", "l2": "l", "l3": "r", "l4": "both", "air": "r", "dslash": "l",
	"heavy": "both", "f1": "both", "f2": "both", "counter": "both", "ripple": "l", "iai": "both", "chain": "r",
	"d1": "r", "d2": "l", "d3": "both", "d4": "both", "dair": "both"}
# Стойки (система торса): рука, направление клинка.
# парные: кулак у пояса, клинок вверх и вперёд, как меч в руке; лезвие смотрит вперёд
const DUAL_R_H := Vector3(-0.29, 0.0, 0.3)
const DUAL_R_D := Vector3(-0.12, 0.8, 0.6)
const WHIP_H := Vector3(-0.31, 0.04, 0.24)
const WHIP_D := Vector3(-0.15, -0.8, 0.55)

func _dual_side() -> String:
	if state == "attack":
		return DUAL_SIDE.get(atk_name, "both")
	return ""

const UPPER := 0.27
const LOWER := 0.29
const CHUDAN_H := Vector3(-0.04, 0.12, 0.3)      # правая рука перед животом (в системе торса)
const CHUDAN_D := Vector3(0, 0.42, 1.0)          # клинок вперёд и вверх — на горло противника
const LOW_H := Vector3(-0.02, 0.02, 0.29)
const LOW_D := Vector3(0, -0.25, 1.0)

func _apply_ik(dt: float, sp: float) -> void:
	var katana := sword_mode in ["katana", "proc"]
	var idle_ok: bool = drawn and ((state == "move" and is_on_floor() and sp < 9.0) or state in ["breathe", "stance"])
	var gw := 0.0
	var lw := 0.0
	var H := CHUDAN_H
	var D := CHUDAN_D.normalized()
	var rw := 0.0     # правая рука в стойке (парные / хлыст)
	var lgw := 0.0    # левая рука в стойке (парные)
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
	elif sword_mode == "dual" and drawn:
		var side := _dual_side()
		if idle_ok or state == "parry":
			rw = 1.0
			lgw = 1.0
		elif side == "r":
			lgw = 1.0
		elif side == "l":
			rw = 1.0
	elif sword_mode == "whip" and drawn and idle_ok:
		rw = 1.0
	grip_w = move_toward(grip_w, gw, dt * 7.0)
	left_w = move_toward(left_w, lw, dt * 9.0)
	grip_r_w = move_toward(grip_r_w, rw, dt * 9.0)
	grip_l_w = move_toward(grip_l_w, lgw, dt * 9.0)
	var torso: Node3D = J.torso
	var inv := torso.global_transform.affine_inverse()
	if state == "draw" and katana:
		_draw_ik(inv)
		return
	if state == "draw" and sword_mode == "dual":
		_dual_draw_ik()
		return
	if grip_w > 0.001:
		_hold("r", H, D, grip_w, J.sword)
	if left_w > 0.001:
		var tl: Vector3 = inv * (J.sword.global_transform * Vector3(0, 0.15, 0))
		_ik_arm("l", tl, left_w)
	if sword_mode == "dual":
		if grip_r_w > 0.001:
			_hold("r", DUAL_R_H, DUAL_R_D.normalized(), grip_r_w, J.sword)
		if grip_l_w > 0.001:
			var lh := Vector3(-DUAL_R_H.x, DUAL_R_H.y, DUAL_R_H.z)
			var ld := Vector3(-DUAL_R_D.x, DUAL_R_D.y, DUAL_R_D.z).normalized()
			_hold("l", lh, ld, grip_l_w, sword_l)
	elif sword_mode == "whip" and grip_r_w > 0.001:
		_hold("r", WHIP_H, WHIP_D.normalized(), grip_r_w, J.sword)

# Рука в точке H (система торса), клинок в её кулаке смотрит по D, лезвие вниз.
func _hold(side: String, H: Vector3, D: Vector3, w: float, blade: Node3D) -> void:
	_ik_arm(side, H, w)
	var want := _blade_basis(D)
	var ft: Basis = J["arm_" + side].basis * J["fore_" + side].basis
	var loc := (ft.inverse() * want).orthonormalized()
	blade.basis = Basis(blade.basis.get_rotation_quaternion().slerp(loc.get_rotation_quaternion(), w))

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

# Парные: руки за плечи к рукоятям на спине (бинты в это время спадают),
# клинки из-за спины — в стойку. Обратно — наоборот.
func _dual_draw_ik() -> void:
	var t := state_t
	for k in 2:
		var side := "r" if k == 0 else "l"
		var blade: Node3D = J.sword if k == 0 else sword_l
		var bb: Basis = back_sheath.basis * _back_basis(k)
		var grip: Vector3 = back_sheath.position + _back_pos(k) + bb * Vector3(0, 0.1, 0)
		var H := DUAL_R_H if k == 0 else Vector3(-DUAL_R_H.x, DUAL_R_H.y, DUAL_R_H.z)
		var D := DUAL_R_D if k == 0 else Vector3(-DUAL_R_D.x, DUAL_R_D.y, DUAL_R_D.z)
		var sb := _blade_basis(D.normalized())
		var hand := grip
		var b := bb
		var w := 1.0
		if not draw_from_drawn:
			if t < 0.17:
				w = Vox.ease_out(t / 0.13)
			else:
				var kk := Vox.ease_in_out((t - 0.17) / 0.2)
				# клинки идут по дуге над плечами
				hand = grip.lerp(H, kk) + Vector3(0, sin(kk * PI) * 0.12, 0)
				b = Basis(bb.get_rotation_quaternion().slerp(sb.get_rotation_quaternion(), kk))
		else:
			if t < 0.2:
				var kk2 := Vox.ease_in_out(t / 0.18)
				hand = H.lerp(grip, kk2) + Vector3(0, sin(kk2 * PI) * 0.12, 0)
				b = Basis(sb.get_rotation_quaternion().slerp(bb.get_rotation_quaternion(), kk2))
			else:
				w = 1.0 - Vox.ease_in_out((t - 0.22) / 0.16)
		ik_pole_up = hand.y > 0.35
		_ik_arm(side, hand, w)
		ik_pole_up = false
		if drawn:
			var ft: Basis = J["arm_" + side].basis * J["fore_" + side].basis
			blade.basis = (ft.inverse() * b).orthonormalized()

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
	if ik_pole_up:
		pole = Vector3(0.8 * sx, 0.5, 0.3)    # рука за плечо: локоть вверх и в сторону
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
