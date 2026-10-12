extends Control
# Интерфейс: здоровье, дыхание, формы, полоса демона, комбо и ранг стиля,
# титры форм как в аниме, подсказки, пауза.

var font: Font
var notes: Array = []          # [текст, время жизни]
var big := ""
var big_t := 0.0
var title := ""
var title_sub := ""
var title_t := 0.0
var intro := ""
var intro_t := 0.0
var combo := 0
var combo_t := 0.0
var style := 0.0
var style_idle := 0.0
var last_kind := ""
var help := true
var help_t := 14.0
var px_scale := 3.0

const RANKS := [
	[0.0, "D", "НЕРЯШЛИВО", Color(0.7, 0.7, 0.75)],
	[40.0, "C", "ЧИСТО", Color(0.55, 0.85, 1.0)],
	[90.0, "B", "ОСТРО", Color(0.45, 1.0, 0.6)],
	[160.0, "A", "БЛЕСТЯЩЕ", Color(1.0, 0.85, 0.3)],
	[250.0, "S", "ИСТИННЫЙ КЛИНОК", Color(1.0, 0.35, 0.3)],
]
const FORM_NAMES := {
	"f1": ["ПРИЛИВ · ПЕРВАЯ ФОРМА", "Веерный срез"],
	"f2": ["ПРИЛИВ · ВТОРАЯ ФОРМА", "Водоворот"],
	"f3": ["ПРИЛИВ · ТРЕТЬЯ ФОРМА", "Тихая гладь"],
}

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	font = ThemeDB.fallback_font
	process_mode = Node.PROCESS_MODE_ALWAYS

func notify(t: String, life := 2.2) -> void:
	for n in notes:
		if n[0] == t:
			n[1] = life
			return
	notes.append([t, life])
	if notes.size() > 3:
		notes.pop_front()

func big_text(t: String) -> void:
	notes.clear()
	big = t
	big_t = 2.6

func form_title(nm: String) -> void:
	if FORM_NAMES.has(nm):
		title = FORM_NAMES[nm][1]
		title_sub = FORM_NAMES[nm][0]
		title_t = 2.0

func boss_intro(nm: String) -> void:
	intro = nm
	intro_t = 3.0

func add_combo(kind: String, dmg: int) -> void:
	combo += 1
	combo_t = 3.0
	var mult := 1.4 if kind != last_kind else 0.6
	if kind in ["f1", "f2", "f3", "parry", "dodge", "finish", "counter"]:
		mult = 2.0
	style = minf(320.0, style + dmg * mult)
	style_idle = 0.0
	last_kind = kind

func reset_combo() -> void:
	combo = 0
	style *= 0.35

func _rank() -> Array:
	var r: Array = RANKS[0]
	for x in RANKS:
		if style >= x[0]:
			r = x
	return r

func _process(_d: float) -> void:
	var dt: float = G.rdt
	for i in range(notes.size() - 1, -1, -1):
		notes[i][1] -= dt
		if notes[i][1] <= 0.0:
			notes.remove_at(i)
	big_t = maxf(0.0, big_t - dt)
	title_t = maxf(0.0, title_t - dt)
	intro_t = maxf(0.0, intro_t - dt)
	combo_t -= dt
	if combo_t <= 0.0:
		combo = 0
	style_idle += dt
	if style_idle > 1.6:
		style = maxf(0.0, style - dt * 18.0)
	if help_t > 0.0:
		help_t -= dt
		if help_t <= 0.0:
			help = false
	queue_redraw()

func _txt(pos: Vector2, t: String, fsize: int, col: Color, align := HORIZONTAL_ALIGNMENT_LEFT, _w := -1.0, outline := 8) -> void:
	if align != HORIZONTAL_ALIGNMENT_LEFT:
		var tw := font.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize).x
		pos.x -= tw * (0.5 if align == HORIZONTAL_ALIGNMENT_CENTER else 1.0)
	draw_string_outline(font, pos, t, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize, outline, Color(0.02, 0.02, 0.05, col.a))
	draw_string(font, pos, t, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize, col)

func _bar(r: Rect2, k: float, col: Color, back := Color(0.05, 0.05, 0.08, 0.85)) -> void:
	draw_rect(r.grow(3), Color(0.02, 0.02, 0.04, 0.9))
	draw_rect(r, back)
	draw_rect(Rect2(r.position, Vector2(r.size.x * clampf(k, 0.0, 1.0), r.size.y)), col)
	draw_rect(Rect2(r.position, Vector2(r.size.x * clampf(k, 0.0, 1.0), r.size.y * 0.3)), col.lightened(0.35))

func _draw() -> void:
	var s := size
	var u := clampf(s.y / 900.0, 0.7, 2.0)
	var p: Node = G.player
	if p == null:
		return
	# --- здоровье и дыхание ---
	var x0 := 28.0 * u
	var y0 := 30.0 * u
	_txt(Vector2(x0, y0), "ЗДОРОВЬЕ", int(15 * u), Color(1, 0.85, 0.85))
	_bar(Rect2(x0, y0 + 8 * u, 300 * u, 16 * u), p.hp / p.max_hp, Color(0.85, 0.15, 0.2))
	_txt(Vector2(x0, y0 + 46 * u), "ДЫХАНИЕ", int(15 * u), Color(0.8, 0.92, 1))
	_bar(Rect2(x0, y0 + 54 * u, 260 * u, 12 * u), p.breath / p.max_breath, Color(0.35, 0.7, 1.0))
	for i in 2:
		var c := Color(0.85, 0.95, 1.0) if p.dash_charges >= i + 1 else Color(0.25, 0.3, 0.4)
		draw_rect(Rect2(x0 + i * 22 * u, y0 + 76 * u, 16 * u, 8 * u), c)
	_txt(Vector2(x0 + 52 * u, y0 + 85 * u), "рывок", int(12 * u), Color(0.8, 0.85, 0.95))
	if p.state == "breathe":
		_txt(Vector2(x0, y0 + 112 * u), "Полная концентрация...", int(16 * u), Color(0.6, 0.85, 1.0))

	# --- формы дыхания ---
	var fw := 190.0 * u
	var fx0 := s.x * 0.5 - fw * 1.5 - 12 * u
	var fy := s.y - 92 * u
	var keys := ["f1", "f2", "f3"]
	var cost := [25, 30, 15]
	for i in 3:
		var r := Rect2(fx0 + i * (fw + 12 * u), fy, fw, 58 * u)
		draw_rect(r.grow(2), Color(0.02, 0.02, 0.05, 0.85))
		draw_rect(r, Color(0.08, 0.14, 0.3, 0.85))
		var cdv: float = p.cd[keys[i]]
		var maxcd: float = 2.5 if i == 0 else (4.0 if i == 1 else 3.0)
		if cdv > 0.0:
			draw_rect(Rect2(r.position, Vector2(r.size.x * cdv / maxcd, r.size.y)), Color(0, 0, 0, 0.55))
		var ok: bool = p.breath >= cost[i] and cdv <= 0.0
		_txt(r.position + Vector2(10 * u, 22 * u), "%d  %s" % [i + 1, FORM_NAMES[keys[i]][1]], int(16 * u), Color(0.9, 0.96, 1.0) if ok else Color(0.5, 0.55, 0.65))
		_txt(r.position + Vector2(10 * u, 46 * u), "дыхание %d" % cost[i], int(12 * u), Color(0.55, 0.75, 1.0) if ok else Color(0.4, 0.45, 0.55))

	# --- демон ---
	var e: Node = null
	for en in G.enemies:
		if is_instance_valid(en) and not en.is_dead():
			e = en
	if e and e.noticed:
		var bw := 520.0 * u
		var bx := s.x * 0.5 - bw * 0.5
		_txt(Vector2(bx, 38 * u), e.name_ru, int(20 * u), Color(1.0, 0.75, 0.7))
		if e.rage:
			_txt(Vector2(bx + bw, 38 * u), "ЯРОСТЬ", int(16 * u), Color(1, 0.3, 0.25), HORIZONTAL_ALIGNMENT_RIGHT, 0)
		_bar(Rect2(bx, 48 * u, bw, 14 * u), e.hp / e.max_hp, Color(0.6, 0.05, 0.15))
		if e.is_exposed():
			var blink := int(G.real_time * 6.0) % 2 == 0
			_txt(Vector2(s.x * 0.5, 90 * u), "ШЕЯ ОТКРЫТА — ЛКМ, ДОБЕЙ!", int(24 * u), Color(1, 0.3, 0.25) if blink else Color(1, 0.9, 0.85), HORIZONTAL_ALIGNMENT_CENTER, 0)
			var left: float = maxf(0.0, e.exposed_time - e.state_t)
			_bar(Rect2(s.x * 0.5 - 120 * u, 100 * u, 240 * u, 6 * u), left / e.exposed_time, Color(1, 0.4, 0.3))
		elif not e.arms_alive.r or not e.arms_alive.l:
			_txt(Vector2(bx, 82 * u), "конечность отрастает...", int(13 * u), Color(0.9, 0.6, 0.6))
	_txt(Vector2(s.x - 28 * u, 34 * u), "Обезглавлено: %d" % G.kills, int(15 * u), Color(0.9, 0.9, 0.95), HORIZONTAL_ALIGNMENT_RIGHT, 0)

	# --- захват цели ---
	if p.lock_target and is_instance_valid(p.lock_target) and G.cam_rig:
		var cam: Camera3D = G.cam_rig.cam
		var wp: Vector3 = p.lock_target.global_position + Vector3.UP * 1.6
		if not cam.is_position_behind(wp):
			var sp := cam.unproject_position(wp) * px_scale
			var k := 10 * u
			var col := Color(1, 0.35, 0.3)
			draw_line(sp + Vector2(-k, 0), sp + Vector2(-k * 0.4, 0), col, 3)
			draw_line(sp + Vector2(k, 0), sp + Vector2(k * 0.4, 0), col, 3)
			draw_line(sp + Vector2(0, -k), sp + Vector2(0, -k * 0.4), col, 3)
			draw_line(sp + Vector2(0, k), sp + Vector2(0, k * 0.4), col, 3)

	# --- счётчик ударов ---
	if combo > 1:
		var pulse := 1.0 + clampf(1.0 - style_idle * 4.0, 0.0, 1.0) * 0.15
		_txt(Vector2(s.x - 40 * u, s.y * 0.38), "%d" % combo, int(48 * u * pulse), Color(1, 1, 1), HORIZONTAL_ALIGNMENT_RIGHT, 0, 12)
		_txt(Vector2(s.x - 40 * u, s.y * 0.38 + 26 * u), "ударов подряд", int(15 * u), Color(0.85, 0.9, 1.0), HORIZONTAL_ALIGNMENT_RIGHT, 0)

	# --- титр формы (как в аниме) ---
	if title_t > 0.0:
		var a := clampf(title_t * 2.0, 0.0, 1.0)
		var slide := (1.0 - clampf((2.0 - title_t) * 6.0, 0.0, 1.0)) * 60 * u
		var tx := 60 * u + slide
		var ty := s.y * 0.62
		draw_rect(Rect2(0, ty - 50 * u, 560 * u, 82 * u), Color(0.02, 0.05, 0.15, 0.55 * a))
		draw_rect(Rect2(0, ty + 30 * u, 560 * u, 3 * u), Color(0.5, 0.8, 1.0, a))
		_txt(Vector2(tx, ty - 22 * u), title_sub, int(16 * u), Color(0.6, 0.85, 1.0, a))
		_txt(Vector2(tx, ty + 18 * u), title, int(40 * u), Color(1, 1, 1, a), HORIZONTAL_ALIGNMENT_LEFT, -1, 12)

	# --- имя демона при появлении ---
	if intro_t > 0.0:
		var a2 := clampf(intro_t, 0.0, 1.0) * clampf((3.0 - intro_t) * 3.0, 0.0, 1.0)
		draw_rect(Rect2(0, s.y * 0.2 - 36 * u, s.x, 64 * u), Color(0.1, 0.0, 0.02, 0.5 * a2))
		_txt(Vector2(s.x * 0.5, s.y * 0.2 + 10 * u), intro, int(38 * u), Color(1, 0.4, 0.35, a2), HORIZONTAL_ALIGNMENT_CENTER, 0, 12)

	# --- большой текст ---
	if big_t > 0.0:
		var a3 := clampf(big_t, 0.0, 1.0)
		var sc := 1.0 + maxf(0.0, big_t - 2.3) * 2.0
		_txt(Vector2(s.x * 0.5, s.y * 0.45), big, int(76 * u * sc), Color(1, 0.95, 0.9, a3), HORIZONTAL_ALIGNMENT_CENTER, 0, 18)

	# --- уведомления ---
	var ny := s.y * 0.66
	for n in notes:
		var a4 := clampf(n[1] * 2.0, 0.0, 1.0)
		_txt(Vector2(s.x * 0.5, ny), n[0], int(20 * u), Color(1, 1, 1, a4), HORIZONTAL_ALIGNMENT_CENTER, 0)
		ny += 28 * u

	# --- управление ---
	if help or G.paused:
		var lines := [
			"WASD — бег   Мышь — камера   Пробел — прыжок / от дерева и стены",
			"Shift — рывок   E — шаг-вспышка к цели   Tab / колесо — захват цели",
			"ЛКМ — комбо   ПКМ — тяжёлый удар   Q — парирование",
			"1 / 2 / 3 — формы Прилива   R (держать) — восстановить дыхание",
			"Бег в стену в прыжке — бег по стене   N — день/ночь   − / + — громкость",
			"Esc — пауза и настройки (громкость, мышь)   F1 — подсказка",
		]
		var hy := s.y - 270 * u
		var hx := 28 * u
		draw_rect(Rect2(hx - 12 * u, hy - 26 * u, 640 * u, lines.size() * 24 * u + 20 * u), Color(0.02, 0.03, 0.08, 0.7))
		for l in lines:
			_txt(Vector2(hx, hy), l, int(15 * u), Color(0.88, 0.92, 1.0))
			hy += 24 * u
	_txt(Vector2(s.x - 16 * u, s.y - 14 * u), "Клинок и Демон · прототип 0.4", int(12 * u), Color(0.7, 0.75, 0.85, 0.6), HORIZONTAL_ALIGNMENT_RIGHT, 0)
