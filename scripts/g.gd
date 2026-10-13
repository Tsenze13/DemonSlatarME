extends Node
# Глобальное состояние: время игры (стоп-кадр, замедление), тряска камеры,
# импакт-кадры, ссылки на главные объекты, раскладка управления.

var player: Node = null
var cam_rig: Node = null
var fx: Node = null
var hud: Node = null
var world: Node = null
var sfx: Node = null
var post_mat: ShaderMaterial = null
var enemies: Array = []

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
var stats := {"kills_total": 0, "best_combo": 0, "play_time": 0.0}
const SAVE_PATH := "user://save.cfg"

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	real_time = Time.get_ticks_usec() / 1e6
	autotest = OS.get_cmdline_user_args().has("--autotest") or OS.get_environment("KLINOK_AUTOTEST") != ""
	_setup_input()
	load_stats()

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
		"light": [KEY_J], "heavy": [KEY_K], "draw": [KEY_F],
	}
	var mouse := {"light": MOUSE_BUTTON_LEFT, "heavy": MOUSE_BUTTON_RIGHT, "lock": MOUSE_BUTTON_MIDDLE}
	var pad := {
		"jump": JOY_BUTTON_A, "dash": JOY_BUTTON_B, "light": JOY_BUTTON_X,
		"heavy": JOY_BUTTON_Y, "parry": JOY_BUTTON_LEFT_SHOULDER,
		"flash": JOY_BUTTON_RIGHT_SHOULDER, "lock": JOY_BUTTON_RIGHT_STICK,
		"breathe": JOY_BUTTON_LEFT_STICK, "form1": JOY_BUTTON_DPAD_LEFT,
		"form2": JOY_BUTTON_DPAD_UP, "form3": JOY_BUTTON_DPAD_RIGHT,
		"pause": JOY_BUTTON_START, "draw": JOY_BUTTON_BACK,
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
