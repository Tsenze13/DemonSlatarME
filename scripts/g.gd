extends Node
# Глобальное состояние: время игры (стоп-кадр, замедление), тряска камеры,
# импакт-кадры, ссылки на главные объекты, раскладка управления.

var player: Node = null
var cam_rig: Node = null
var fx: Node = null
var hud: Node = null
var world: Node = null
var sfx: Node = null
var music: Node = null
var post_mat: ShaderMaterial = null
var enemies: Array = []
var story = null            # story.gd: сюжет, задания, жители, прокачка
var dialog_ui = null        # dialog.gd: окно разговора
var dialog := false         # идёт разговор — герой не слушается управления
var cutscene := false       # титры главы / затемнение
var mode := "free"          # "story" — сюжет, "free" — свободная охота

# Прокачка (сохраняется в save.cfg, раздел [story]).
var prog := {"ryo": 0, "mastery": 0, "hp": 0, "lungs": 0, "focus": 0, "blade": 0, "chapter": 0, "finished": false, "started": false, "trial": -1, "hunts": 0, "onigiri": 2, "gift": -1, "finished2": false,
	"formlv": {}, "final": {}, "loadout": {}}

var difficulty := 1          # 0 — лёгкая, 1 — обычная, 2 — тяжёлая (настройки)
func dmg_out_mult() -> float:
	var mt = player.get("mark_t") if player else null
	var mk := 1.4 if mt != null and float(mt) > 0.0 else 1.0
	# базовый множитель 1.5: игрок — «урона не хватает»
	return 1.5 * (1.0 + 0.1 * float(prog.blade)) * [1.3, 1.0, 0.85][clampi(difficulty, 0, 2)] * mk

func dmg_in_mult() -> float:
	# демоны бьют мягче (игрок: «просто запинывают»)
	return [0.4, 0.7, 1.0][clampi(difficulty, 0, 2)]

func load_prog() -> void:
	var cf := ConfigFile.new()
	if cf.load("user://save.cfg") == OK:
		for k in prog:
			prog[k] = cf.get_value("story", k, prog[k])

func save_prog() -> void:
	if autotest:
		return
	var cf := ConfigFile.new()
	cf.load("user://save.cfg")
	for k in prog:
		cf.set_value("story", k, prog[k])
	cf.save("user://save.cfg")

var real_time := 0.0      # реальные секунды (не замедляются)
var rdt := 0.016          # реальная длительность кадра
var hitstop_until := 0.0
var slow_until := 0.0
var slow_scale := 1.0
var impact_until := 0.0
var impact_mode := 0
var flash := 0.0
var flash_col := Color.WHITE
var shake := 0.0
var speedlines := 0.0
var hurt_fx := 0.0
var paused := false
var kills := 0
var autotest := false
var started := false        # игра началась (нажато «Играть» в главном меню)
var show_fps := false
var shake_mult := 1.0
# Стиль дыхания: вид эффектов форм, цвет мазка, звук и названия форм.
var breath_style := "water"
# Стили дыхания и названия форм — из breaths.gd (14 стилей, формы как в аниме и манге).
const Breaths = preload("res://scripts/breaths.gd")
var BREATH_ORDER: Array = []
var BREATHS := {}

func _init() -> void:
	BREATH_ORDER = Breaths.ORDER.duplicate()
	for id in Breaths.ORDER:
		var st: Dictionary = Breaths.STYLES[id]
		var names: Array = []
		for f in st.forms:
			names.append(f[0])
		BREATHS[id] = {"name": st.name, "kind": st.kind, "a": st.a, "b": st.b, "flash": st.flash, "core": st.core,
			"edge": st.edge, "fx": st.fx, "forms": names}

# Открыт ли стиль (сюжет — по главам, свободная охота — все).
func style_open(id: String) -> bool:
	return Breaths.unlocked(id, prog, mode == "free" or autotest)

func br() -> Dictionary:
	return BREATHS.get(breath_style, BREATHS.water)

# Семейство эффектов стиля (у Зари — пламя).
func fx_style() -> String:
	return String(br().get("fx", breath_style))

func dawn_unlocked() -> bool:
	return style_open("dawn")
var stats := {"kills_total": 0, "best_combo": 0, "play_time": 0.0, "perfect": 0, "arms": 0, "legs": 0, "marks": 0, "bosses": 0, "ach": ""}

# Достижения: [ключ, название, условие словами]. Проверяются раз в секунду (`_check_ach`).
const ACH := [
	["first", "Первая голова", "обезглавь демона"],
	["ten", "Десять голов", "обезглавь 10 демонов"],
	["hundred", "Сотня", "обезглавь 100 демонов"],
	["parry", "Звон стали", "10 идеальных парирований"],
	["arms", "Без рук", "отруби 10 рук"],
	["legs", "Подсечка", "отруби 5 ног"],
	["mark", "Алая метка", "пробуди Метку охотника"],
	["combo", "Буря клинка", "серия из 25 ударов"],
	["boss", "Закат Третьей луны", "победи Кагэцу"],
	["boss2", "Иней тает", "победи Сэйрэн, Вторую луну"],
	["hunt5", "Охотник на заказ", "5 охот на заказ"],
	["rich", "Тугой кошель", "накопи 1000 рё"],
	["full", "Предел тела", "все тренировки наставника до предела"],
]

func stat_add(k: String, v := 1) -> void:
	stats[k] = int(stats.get(k, 0)) + v

func has_ach(k: String) -> bool:
	return (String(stats.ach) + ",").find(k + ",") >= 0

func _ach_ok(k: String) -> bool:
	match k:
		"first": return int(stats.kills_total) >= 1
		"ten": return int(stats.kills_total) >= 10
		"hundred": return int(stats.kills_total) >= 100
		"parry": return int(stats.perfect) >= 10
		"arms": return int(stats.arms) >= 10
		"legs": return int(stats.legs) >= 5
		"mark": return int(stats.marks) >= 1
		"combo": return int(stats.best_combo) >= 25
		"boss": return int(stats.bosses) >= 1
		"boss2": return bool(prog.get("finished2", false))
		"hunt5": return int(prog.get("hunts", 0)) >= 5
		"rich": return int(prog.ryo) >= 1000
		"full": return int(prog.hp) >= 5 and int(prog.lungs) >= 5 and int(prog.focus) >= 3
	return false

var ach_t := 0.0
func _check_ach() -> void:
	for a in ACH:
		if not has_ach(a[0]) and _ach_ok(a[0]):
			stats.ach = String(stats.ach) + a[0] + ","
			if hud:
				hud.notify("ДОСТИЖЕНИЕ: %s" % a[1], 3.5)
			if sfx:
				sfx.play("chime", -6.0, 1.2)
			save_stats()
const SAVE_PATH := "user://save.cfg"

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	real_time = Time.get_ticks_usec() / 1e6
	autotest = OS.get_cmdline_user_args().has("--autotest") or OS.get_environment("KLINOK_AUTOTEST") != ""
	_setup_input()
	load_stats()
	if not autotest:
		load_prog()

# --- сохранение прогресса (пока — статистика) ---
func load_stats() -> void:
	var cf := ConfigFile.new()
	if cf.load(SAVE_PATH) == OK:
		for k in stats:
			stats[k] = cf.get_value("stats", k, stats[k])

func save_stats() -> void:
	if autotest:
		return
	var cf := ConfigFile.new()
	cf.load(SAVE_PATH)            # не затирать раздел [story]
	for k in stats:
		cf.set_value("stats", k, stats[k])
	cf.save(SAVE_PATH)

func add_kill() -> void:
	kills += 1
	stats.kills_total = int(stats.kills_total) + 1
	save_stats()

# --- клавиши: по умолчанию, переназначение, подписи ---
var default_keys := {}

func reset_keys() -> void:
	for a in default_keys:
		_clear_kbm(a)
		for ev in default_keys[a]:
			InputMap.action_add_event(a, ev)

func _clear_kbm(a: String) -> void:
	for ev in InputMap.action_get_events(a):
		if ev is InputEventKey or ev is InputEventMouseButton:
			InputMap.action_erase_event(a, ev)

# Новая клавиша для действия (клавиатура/мышь заменяются, геймпад остаётся).
func bind_key(a: String, ev: InputEvent) -> void:
	_clear_kbm(a)
	InputMap.action_add_event(a, ev)

func event_code(ev: InputEvent) -> String:
	if ev is InputEventKey:
		return "k:%d" % ev.physical_keycode
	if ev is InputEventMouseButton:
		return "m:%d" % ev.button_index
	return ""

func event_from_code(c: String) -> InputEvent:
	if c.begins_with("k:"):
		var k := InputEventKey.new()
		k.physical_keycode = int(c.substr(2)) as Key
		return k
	if c.begins_with("m:"):
		var m := InputEventMouseButton.new()
		m.button_index = int(c.substr(2)) as MouseButton
		return m
	return null

const MOUSE_NAMES := {1: "ЛКМ", 2: "ПКМ", 3: "Колёсико", 4: "Колесо вверх", 5: "Колесо вниз", 8: "Мышь 4", 9: "Мышь 5"}

func key_text(a: String) -> String:
	var parts := []
	for ev in InputMap.action_get_events(a):
		if ev is InputEventKey:
			parts.append(OS.get_keycode_string(ev.physical_keycode))
		elif ev is InputEventMouseButton:
			parts.append(MOUSE_NAMES.get(int(ev.button_index), "Мышь %d" % ev.button_index))
	return " / ".join(parts) if not parts.is_empty() else "—"

func _setup_input() -> void:
	var keys := {
		"move_f": [KEY_W, KEY_UP], "move_b": [KEY_S, KEY_DOWN],
		"move_l": [KEY_A, KEY_LEFT], "move_r": [KEY_D, KEY_RIGHT],
		"jump": [KEY_SPACE], "dash": [KEY_SHIFT], "flash": [KEY_E],
		"parry": [KEY_Q], "breathe": [KEY_R], "form1": [KEY_1],
		"form2": [KEY_2], "form3": [KEY_3], "lock": [KEY_TAB],
		"daynight": [KEY_N], "pause": [KEY_ESCAPE], "help": [KEY_F1],
		"light": [KEY_J], "heavy": [KEY_K], "draw": [KEY_F], "mark": [KEY_V], "map": [KEY_M], "eat": [KEY_H], "form4": [KEY_4], "form5": [KEY_5],
		"form6": [KEY_6], "form7": [KEY_7], "form8": [KEY_8], "form9": [KEY_9], "form10": [KEY_0], "form_page": [KEY_QUOTELEFT],
	}
	var mouse := {"light": MOUSE_BUTTON_LEFT, "heavy": MOUSE_BUTTON_RIGHT, "lock": MOUSE_BUTTON_MIDDLE}
	var pad := {
		"jump": JOY_BUTTON_A, "dash": JOY_BUTTON_B, "light": JOY_BUTTON_X,
		"heavy": JOY_BUTTON_Y, "parry": JOY_BUTTON_LEFT_SHOULDER,
		"flash": JOY_BUTTON_RIGHT_SHOULDER, "lock": JOY_BUTTON_RIGHT_STICK,
		"breathe": JOY_BUTTON_LEFT_STICK, "form1": JOY_BUTTON_DPAD_LEFT,
		"form2": JOY_BUTTON_DPAD_UP, "form3": JOY_BUTTON_DPAD_RIGHT,
		"pause": JOY_BUTTON_START, "draw": JOY_BUTTON_BACK, "mark": JOY_BUTTON_DPAD_DOWN,
	}
	for a in keys:
		if not InputMap.has_action(a):
			InputMap.add_action(a)
		default_keys[a] = []
		for k in keys[a]:
			var ev := InputEventKey.new()
			ev.physical_keycode = k
			InputMap.action_add_event(a, ev)
			default_keys[a].append(ev)
	for a in mouse:
		var ev := InputEventMouseButton.new()
		ev.button_index = mouse[a]
		InputMap.action_add_event(a, ev)
		default_keys[a].append(ev)
	for a in pad:
		var ev := InputEventJoypadButton.new()
		ev.button_index = pad[a]
		InputMap.action_add_event(a, ev)

# --- «Сок» удара -------------------------------------------------------
func hitstop(dur: float) -> void:
	hitstop_until = maxf(hitstop_until, real_time + dur)

func slowmo(scale: float, dur: float) -> void:
	slow_scale = scale
	slow_until = maxf(slow_until, real_time + dur)

func impact(dur: float = 0.07, mode: int = 0) -> void:
	impact_until = real_time + dur
	impact_mode = mode

func add_shake(a: float) -> void:
	shake = maxf(shake, a * shake_mult)

func do_flash(a: float, c: Color = Color.WHITE) -> void:
	flash = maxf(flash, a)
	flash_col = c

func _process(_delta: float) -> void:
	var now := Time.get_ticks_usec() / 1e6
	rdt = clampf(now - real_time, 0.0, 0.1)
	real_time = now
	var ts := 1.0
	if now < slow_until:
		ts = slow_scale
	if now < hitstop_until:
		ts = 0.02
	if paused:
		ts = 1.0
	Engine.time_scale = ts
	shake = maxf(0.0, shake - rdt * 2.2)
	if started and not paused:
		stats.play_time = float(stats.play_time) + rdt
		ach_t -= rdt
		if ach_t <= 0.0:
			ach_t = 1.0
			_check_ach()
	speedlines = maxf(0.0, speedlines - rdt * 2.5)
	flash = maxf(0.0, flash - rdt * 5.0)
	hurt_fx = maxf(0.0, hurt_fx - rdt * 1.5)
	if post_mat:
		post_mat.set_shader_parameter("impact", 1.0 if now < impact_until else 0.0)
		post_mat.set_shader_parameter("impact_mode", impact_mode)
		post_mat.set_shader_parameter("speed", speedlines)
		post_mat.set_shader_parameter("rtime", now)
		post_mat.set_shader_parameter("flash", flash)
		post_mat.set_shader_parameter("flash_col", Vector3(flash_col.r, flash_col.g, flash_col.b))
		post_mat.set_shader_parameter("hurt", hurt_fx)

func nearest_enemy(from: Vector3, max_d: float, alive_only := true) -> Node:
	var best: Node = null
	var bd := max_d
	for e in enemies:
		if not is_instance_valid(e):
			continue
		if alive_only and e.is_dead():
			continue
		var d: float = from.distance_to(e.global_position)
		if d < bd:
			bd = d
			best = e
	return best
