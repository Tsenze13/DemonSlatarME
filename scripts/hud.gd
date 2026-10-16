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
var serif: Font                # шрифт с засечками для титров мест (как в референсе)
var loc_name := ""
var loc_sub := ""
var loc_t := 0.0
var loc_check := 0.0
var loc_cand := ""             # место, где герой сейчас (ещё без титра)
var loc_cand_sub := ""
var loc_stay := 0.0
var loc_seen := {}             # место → когда последний раз показан титр
var show_map := true
var big_map := false
const MAP_LABELS := [["Поляна у старой стены", Vector2(0, 2)], ["Деревня Ивакура", Vector2(32, -32)], ["Святилище Кумо", Vector2(0, -62)],
	["Пруд Цукими", Vector2(-34, -5)], ["Бамбуковая роща", Vector2(-32, 26)], ["Старый кедровый лес", Vector2(-62, -42)],
	["Каменная стена", Vector2(0, 50)]]

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
	var sf := SystemFont.new()
	sf.font_names = PackedStringArray(["Georgia", "Cambria", "Times New Roman", "Noto Serif", "DejaVu Serif", "Liberation Serif", "serif"])
	sf.antialiasing = TextServer.FONT_ANTIALIASING_GRAY
	serif = sf
	process_mode = Node.PROCESS_MODE_ALWAYS

var note_last := {}             # текст → когда показан (одна и та же надпись не мигает)

func notify(t: String, life := 2.2) -> void:
	for n in notes:
		if n[0] == t:
			n[1] = life
			return
	if G.real_time - float(note_last.get(t, -99.0)) < 4.0:
		return
	note_last[t] = G.real_time
	notes.append([t, life])
	if notes.size() > 3:
		notes.pop_front()

func big_text(t: String) -> void:
	notes.clear()
	big = t
	big_t = 2.6

# Название формы по текущему стилю дыхания: [подпись, имя].
func _form(nm: String) -> Array:
	var b: Dictionary = G.br()
	var idx := ["f1", "f2", "f3"].find(nm)
	if idx < 0:
		return ["", ""]
	var ord: String = ["ПЕРВАЯ", "ВТОРАЯ", "ТРЕТЬЯ"][idx]
	return ["%s · %s ФОРМА" % [String(b.name).to_upper(), ord], b.forms[idx]]

func form_title(nm: String) -> void:
	var f := _form(nm)
	if f[1] != "":
		title = f[1]
		title_sub = f[0]
		title_t = 2.0

var intro_seen := {}
func boss_intro(nm: String) -> void:
	# имя демона — крупно только при первой встрече (и не чаще раза в 3 мин), рык повторяется часто
	var now := Time.get_ticks_msec() / 1000.0
	if intro_seen.has(nm) and now - float(intro_seen[nm]) < 180.0:
		return
	intro_seen[nm] = now
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
	# титр места: когда герой входит в новую область
	loc_t = maxf(0.0, loc_t - dt)
	loc_check -= dt
	if loc_check <= 0.0 and G.world and G.player and G.world.has_method("region_at"):
		loc_check = 0.25
		var r: Array = G.world.region_at(G.player.global_position)
		# титр — только когда герой задержался в новом месте (не мелькает на бегу),
		# одно и то же место — не чаще раза в 2 минуты, «луга» без титра
		if r[0] != loc_cand:
			loc_cand = r[0]
			loc_cand_sub = r[1]
			loc_stay = 0.0
		else:
			loc_stay += 0.25
		var since: float = G.real_time - float(loc_seen.get(loc_cand, -999.0))
		if loc_stay >= 1.5 and loc_cand != loc_name and r[1] != "" and since > 120.0 and loc_t <= 0.0:
			loc_name = loc_cand
			loc_sub = loc_cand_sub
			loc_seen[loc_name] = G.real_time
			loc_t = 4.5
	queue_redraw()

func _stxt(pos: Vector2, t: String, fsize: int, col: Color) -> void:
	var tw := serif.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize).x
	pos.x -= tw * 0.5
	draw_string_outline(serif, pos, t, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize, 6, Color(0.02, 0.02, 0.04, col.a * 0.6))
	draw_string(serif, pos, t, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize, col)

# Мини-карта (круг, север сверху) и компас.
func _draw_map(s: Vector2, u: float) -> void:
	var w = G.world
	if w == null or w.get("minimap") == null or w.minimap == null:
		return
	var p: Node3D = G.player
	var r := 78.0 * u
	var c := Vector2(s.x - r - 26 * u, r + 96 * u)
	var view := 55.0                       # радиус обзора карты, м
	var n: float = w.minimap.get_width()
	var pts := PackedVector2Array()
	var uvs := PackedVector2Array()
	for i in 40:
		var a := TAU * i / 40.0
		var d := Vector2(cos(a), sin(a))
		pts.append(c + d * r)
		var wp := Vector2(p.global_position.x, p.global_position.z) + d * view
		uvs.append((wp + Vector2(w.HALF, w.HALF)) / w.MAP_SCALE / n)
	draw_circle(c, r + 4 * u, Color(0.04, 0.03, 0.06, 0.85))
	draw_colored_polygon(pts, Color(1, 1, 1, 0.92), uvs, w.minimap)
	draw_arc(c, r + 2 * u, 0, TAU, 48, Color(0.95, 0.88, 0.7, 0.9), 2.0 * u)
	# демоны
	for e in G.enemies:
		if is_instance_valid(e) and not e.is_dead():
			var dv := Vector2(e.global_position.x - p.global_position.x, e.global_position.z - p.global_position.z) / view
			if dv.length() < 1.0:
				draw_circle(c + dv * r, 4 * u, Color(1, 0.25, 0.2))
	# цель задания
	if G.story and G.story.target != null:
		var tv := Vector2(G.story.target.x - p.global_position.x, G.story.target.z - p.global_position.z) / view
		if tv.length() > 0.95:
			tv = tv.normalized() * 0.95
		var tc := c + tv * r
		draw_colored_polygon(PackedVector2Array([tc + Vector2(0, -7 * u), tc + Vector2(5 * u, 0), tc + Vector2(0, 7 * u), tc + Vector2(-5 * u, 0)]), Color(1.0, 0.82, 0.4))
	# жители с новостями
	if G.story:
		for id in G.story.npcs:
			var npc_n = G.story.npcs[id]
			if npc_n.has_news:
				var nv := Vector2(npc_n.global_position.x - p.global_position.x, npc_n.global_position.z - p.global_position.z) / view
				if nv.length() < 1.0:
					draw_circle(c + nv * r, 4 * u, Color(1.0, 0.9, 0.3))
	# герой — стрелка по направлению взгляда
	var f: float = p.facing
	var fd := Vector2(sin(f), cos(f))
	var sd := Vector2(-fd.y, fd.x)
	draw_colored_polygon(PackedVector2Array([c + fd * 9 * u, c - fd * 6 * u + sd * 6 * u, c - fd * 3 * u, c - fd * 6 * u - sd * 6 * u]), Color(1, 1, 1))
	_txt(c + Vector2(0, -r - 8 * u), "С", int(14 * u), Color(1, 0.9, 0.7), HORIZONTAL_ALIGNMENT_CENTER, 0, 6)
	# компас: полоса под картой — куда смотрит камера
	if G.cam_rig:
		var yaw: float = G.cam_rig.yaw
		var cw := r * 2.2
		var cx := c.x
		var cy := c.y + r + 18.0 * u
		draw_rect(Rect2(cx - cw * 0.5, cy - 2 * u, cw, 2 * u), Color(1, 1, 1, 0.35))
		# курс по часовой от севера (−z); камера смотрит по курсу −yaw
		var marks := [["С", 0.0], ["В", PI * 0.5], ["Ю", PI], ["З", -PI * 0.5]]
		for m in marks:
			var da := wrapf(float(m[1]) + yaw, -PI, PI)
			if absf(da) < PI * 0.5:
				var x := cx + da / (PI * 0.5) * cw * 0.5
				_txt(Vector2(x, cy + 18 * u), m[0], int(15 * u), Color(1, 0.92, 0.75, 1.0 - absf(da) / (PI * 0.5)), HORIZONTAL_ALIGNMENT_CENTER, 0, 6)

# Сюжет: задание, метка цели, «E — поговорить», рё, затемнение и титры глав.
func _draw_story(s: Vector2, u: float) -> void:
	var st = G.story
	if st == null:
		return
	var p: Node3D = G.player
	# задание — под шкалами, с засечками
	if st.objective != "" and not G.dialog and G.started:
		var oy := 150.0 * u
		var head: String = "ЗАДАНИЕ"
		if not st.cur.is_empty():
			head = "ОХОТА НА ЗАКАЗ · %d" % (int(G.prog.get("hunts", 0)) + 1)
		elif G.mode == "story" and st.chapter < st.CH.size():
			head = "ГЛАВА %d · %s" % [st.chapter, String(st.CH[st.chapter].name).to_upper()] if st.chapter > 0 else "ПРОЛОГ · УЧЕНИК"
		var ow := maxf(font.get_string_size(st.objective, HORIZONTAL_ALIGNMENT_LEFT, -1, int(17 * u)).x, 200 * u) + 40 * u
		draw_rect(Rect2(14 * u, oy - 22 * u, ow, 58 * u), Color(0.02, 0.03, 0.08, 0.55))
		draw_rect(Rect2(14 * u, oy - 22 * u, 3 * u, 58 * u), Color(1.0, 0.82, 0.45, 0.9))
		_txt(Vector2(28 * u, oy - 4 * u), head, int(12 * u), Color(1.0, 0.82, 0.5))
		_txt(Vector2(28 * u, oy + 22 * u), st.objective, int(17 * u), Color(1, 1, 1))
	if G.mode == "story" or int(G.prog.ryo) > 0:
		_txt(Vector2(28 * u, s.y - 118 * u), "%d рё   ·   мастерство %d   ·   %s" % [int(G.prog.ryo), int(G.prog.mastery), st.rank_name()], int(14 * u), Color(1.0, 0.9, 0.65))
	# метка цели: ромб над местом, у края экрана — стрелка
	if st.target != null and G.cam_rig and not G.dialog:
		var cam: Camera3D = G.cam_rig.cam
		var tp: Vector3 = st.target + Vector3.UP * 2.5
		var dist: float = Vector2(p.global_position.x - tp.x, p.global_position.z - tp.z).length()
		var sp: Vector2
		var behind := cam.is_position_behind(tp)
		sp = cam.unproject_position(tp) * px_scale
		var m := 60.0 * u
		var onscreen := not behind and sp.x > m and sp.x < s.x - m and sp.y > m and sp.y < s.y - m
		var col := Color(1.0, 0.82, 0.4)
		if onscreen:
			var k := 12 * u * (1.0 + sin(G.real_time * 4.0) * 0.1)
			draw_colored_polygon(PackedVector2Array([sp + Vector2(0, -k), sp + Vector2(k * 0.7, 0), sp + Vector2(0, k), sp + Vector2(-k * 0.7, 0)]), col)
			draw_polyline(PackedVector2Array([sp + Vector2(0, -k - 3), sp + Vector2(k * 0.7 + 3, 0), sp + Vector2(0, k + 3), sp + Vector2(-k * 0.7 - 3, 0), sp + Vector2(0, -k - 3)]), Color(0.1, 0.05, 0.0, 0.8), 2.0)
			_txt(sp + Vector2(0, 30 * u), "%d м" % int(dist), int(15 * u), col, HORIZONTAL_ALIGNMENT_CENTER, 0)
		else:
			var c := s * 0.5
			var d := sp - c
			if behind:
				d = -d
			if d.length() < 1.0:
				d = Vector2(0, -1)
			d = d.normalized()
			var ep := c + d * minf(s.x, s.y) * 0.42
			var nrm := Vector2(-d.y, d.x)
			draw_colored_polygon(PackedVector2Array([ep + d * 16 * u, ep - d * 8 * u + nrm * 11 * u, ep - d * 8 * u - nrm * 11 * u]), col)
			_txt(ep - d * 26 * u + Vector2(0, 6 * u), "%d м" % int(dist), int(14 * u), col, HORIZONTAL_ALIGNMENT_CENTER, 0)
	# E — поговорить
	if st.near and not G.dialog and G.cam_rig:
		var cam2: Camera3D = G.cam_rig.cam
		var np: Vector3 = st.near.talk_pos() + Vector3.UP * 0.6
		if not cam2.is_position_behind(np):
			var sp2 := cam2.unproject_position(np) * px_scale
			var label := "E — поговорить: %s" % st.near.title
			var tw := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, int(16 * u)).x
			draw_rect(Rect2(sp2.x - tw * 0.5 - 12 * u, sp2.y - 22 * u, tw + 24 * u, 30 * u), Color(0.02, 0.03, 0.08, 0.75))
			draw_rect(Rect2(sp2.x - tw * 0.5 - 12 * u, sp2.y + 6 * u, tw + 24 * u, 2 * u), Color(1.0, 0.82, 0.45))
			_txt(Vector2(sp2.x, sp2.y), label, int(16 * u), Color(1, 0.95, 0.85), HORIZONTAL_ALIGNMENT_CENTER, 0, 6)
	# затемнение и титры
	if st.fade > 0.0:
		draw_rect(Rect2(Vector2.ZERO, s), Color(0, 0, 0, st.fade))
	if st.card_t > 0.0:
		var a := clampf(st.card_t, 0.0, 1.0) * clampf((3.6 - st.card_t) * 1.5, 0.0, 1.0)
		var cy := s.y * 0.42
		if st.fade < 0.5:
			draw_rect(Rect2(0, cy - 70 * u, s.x, 120 * u), Color(0, 0, 0, 0.45 * a))
		_stxt(Vector2(s.x * 0.5, cy), st.card, int(54 * u), Color(1, 0.96, 0.88, a))
		var lw := serif.get_string_size(st.card, HORIZONTAL_ALIGNMENT_LEFT, -1, int(54 * u)).x
		draw_line(Vector2(s.x * 0.5 - lw * 0.5 - 90 * u, cy - 18 * u), Vector2(s.x * 0.5 - lw * 0.5 - 20 * u, cy - 18 * u), Color(1, 0.9, 0.7, a * 0.8), 1.5 * u)
		draw_line(Vector2(s.x * 0.5 + lw * 0.5 + 20 * u, cy - 18 * u), Vector2(s.x * 0.5 + lw * 0.5 + 90 * u, cy - 18 * u), Color(1, 0.9, 0.7, a * 0.8), 1.5 * u)
		_stxt(Vector2(s.x * 0.5, cy + 38 * u), st.card_sub, int(22 * u), Color(0.95, 0.85, 0.7, a * 0.9))

# Большая карта (M): вся округа, места, цель задания, жители, демоны, герой.
func _draw_big_map(s: Vector2, u: float) -> void:
	var w = G.world
	if w == null or w.get("minimap") == null or w.minimap == null:
		return
	draw_rect(Rect2(Vector2.ZERO, s), Color(0.02, 0.02, 0.04, 0.72))
	var side := minf(s.x, s.y) * 0.82
	var r := Rect2(s * 0.5 - Vector2(side, side) * 0.5, Vector2(side, side))
	var half: float = w.HALF
	var to_px := func(x: float, z: float) -> Vector2:
		return r.position + Vector2((x + half) / (half * 2.0), (z + half) / (half * 2.0)) * side
	draw_rect(r.grow(6 * u), Color(0.75, 0.62, 0.4))
	draw_texture_rect(w.minimap, r, false)
	for lb in MAP_LABELS:
		var lp: Vector2 = to_px.call(lb[1].x, lb[1].y)
		_stxt(lp, lb[0], int(17 * u), Color(1, 0.97, 0.88))
	if G.story:
		for id in G.story.npcs:
			var n = G.story.npcs[id]
			if n.visible:
				var np: Vector2 = to_px.call(n.global_position.x, n.global_position.z)
				draw_circle(np, 4 * u, Color(1.0, 0.9, 0.3) if n.has_news else Color(0.9, 0.85, 0.75))
		if G.story.target != null:
			var tp: Vector2 = to_px.call(G.story.target.x, G.story.target.z)
			var k := 10 * u * (1.0 + sin(G.real_time * 4.0) * 0.15)
			draw_colored_polygon(PackedVector2Array([tp + Vector2(0, -k), tp + Vector2(k * 0.7, 0), tp + Vector2(0, k), tp + Vector2(-k * 0.7, 0)]), Color(1.0, 0.82, 0.4))
	for e in G.enemies:
		if is_instance_valid(e) and not e.is_dead():
			draw_circle(to_px.call(e.global_position.x, e.global_position.z), 4 * u, Color(1, 0.25, 0.2))
	var p: Node3D = G.player
	var pp: Vector2 = to_px.call(p.global_position.x, p.global_position.z)
	var fd := Vector2(sin(p.facing), cos(p.facing))
	var sd := Vector2(-fd.y, fd.x)
	draw_colored_polygon(PackedVector2Array([pp + fd * 12 * u, pp - fd * 7 * u + sd * 8 * u, pp - fd * 3 * u, pp - fd * 7 * u - sd * 8 * u]), Color(1, 1, 1))
	_stxt(Vector2(s.x * 0.5, r.position.y - 16 * u), "Округа деревни Ивакура", int(30 * u), Color(1, 0.95, 0.85))
	_txt(Vector2(s.x * 0.5, r.end.y + 30 * u), "M — закрыть   ·   ромб — цель задания   ·   жёлтые точки — жители с новостями", int(15 * u), Color(0.85, 0.85, 0.9), HORIZONTAL_ALIGNMENT_CENTER, 0)

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
	# шкала Метки охотника
	if p.has_method("mark_unlocked") and p.mark_unlocked():
		var mk: float = p.mark_t / p.MARK_DUR if p.mark_t > 0.0 else p.fury / 100.0
		var mcol := Color(1.0, 0.25, 0.15) if p.mark_t > 0.0 or p.fury >= 100.0 else Color(0.65, 0.2, 0.18)
		_bar(Rect2(x0 + 110 * u, y0 + 78 * u, 150 * u, 6 * u), mk, mcol)
		var mt := "МЕТКА — V" if p.fury >= 100.0 and p.mark_t <= 0.0 else ("МЕТКА %d с" % int(ceil(p.mark_t)) if p.mark_t > 0.0 else "метка")
		_txt(Vector2(x0 + 268 * u, y0 + 86 * u), mt, int(12 * u), mcol.lightened(0.3) if int(G.real_time * 3.0) % 2 == 0 or p.fury < 100.0 else mcol)
	if p.state == "breathe":
		_txt(Vector2(x0, y0 + 112 * u), "Полная концентрация...", int(16 * u), Color(0.6, 0.85, 1.0))

	# --- формы дыхания ---
	var fw := 190.0 * u
	var fx0 := s.x * 0.5 - fw * 1.5 - 12 * u
	var fy := s.y - 92 * u
	var keys := ["f1", "f2", "f3"]
	var cost := [int(p.form_cost(1)), int(p.form_cost(2)), int(p.form_cost(3))]
	for i in 3:
		var r := Rect2(fx0 + i * (fw + 12 * u), fy, fw, 58 * u)
		draw_rect(r.grow(2), Color(0.02, 0.02, 0.05, 0.85))
		draw_rect(r, Color(0.08, 0.14, 0.3, 0.85))
		var cdv: float = p.cd[keys[i]]
		var maxcd: float = p.form_cd(i + 1)
		if cdv > 0.0:
			draw_rect(Rect2(r.position, Vector2(r.size.x * cdv / maxcd, r.size.y)), Color(0, 0, 0, 0.55))
		var ok: bool = p.breath >= cost[i] and cdv <= 0.0
		_txt(r.position + Vector2(10 * u, 22 * u), "%d  %s" % [i + 1, _form(keys[i])[1]], int(16 * u), Color(0.9, 0.96, 1.0) if ok else Color(0.5, 0.55, 0.65))
		_txt(r.position + Vector2(10 * u, 46 * u), "дыхание %d" % cost[i], int(12 * u), Color(0.55, 0.75, 1.0) if ok else Color(0.4, 0.45, 0.55))

	if show_map and G.started:
		_draw_map(s, u)
	# --- титр места (шрифт с засечками, тонкие линии) ---
	if loc_t > 0.0 and loc_name != "":
		var la := clampf(loc_t, 0.0, 1.0) * clampf((4.5 - loc_t) * 2.0, 0.0, 1.0)
		var ly := s.y * 0.34
		var lw := serif.get_string_size(loc_name, HORIZONTAL_ALIGNMENT_LEFT, -1, int(44 * u)).x
		_stxt(Vector2(s.x * 0.5, ly), loc_name, int(44 * u), Color(1, 0.97, 0.9, la))
		draw_line(Vector2(s.x * 0.5 - lw * 0.5 - 80 * u, ly - 14 * u), Vector2(s.x * 0.5 - lw * 0.5 - 16 * u, ly - 14 * u), Color(1, 0.95, 0.85, la * 0.8), 1.5 * u)
		draw_line(Vector2(s.x * 0.5 + lw * 0.5 + 16 * u, ly - 14 * u), Vector2(s.x * 0.5 + lw * 0.5 + 80 * u, ly - 14 * u), Color(1, 0.95, 0.85, la * 0.8), 1.5 * u)
		if loc_sub != "":
			_stxt(Vector2(s.x * 0.5, ly + 30 * u), loc_sub, int(18 * u), Color(0.95, 0.9, 0.82, la * 0.9))

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
	if G.mode == "free":
		_txt(Vector2(s.x - 28 * u, 34 * u), "Обезглавлено: %d" % G.kills, int(15 * u), Color(0.9, 0.9, 0.95), HORIZONTAL_ALIGNMENT_RIGHT, 0)
		_txt(Vector2(s.x - 28 * u, 54 * u), "всего за все игры: %d" % int(G.stats.kills_total), int(12 * u), Color(0.7, 0.75, 0.85), HORIZONTAL_ALIGNMENT_RIGHT, 0)
	if G.show_fps:
		_txt(Vector2(s.x - 28 * u, 76 * u), "%d кадров/с" % Engine.get_frames_per_second(), int(14 * u), Color(0.6, 1.0, 0.6), HORIZONTAL_ALIGNMENT_RIGHT, 0)

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

	_draw_story(s, u)
	if big_map:
		_draw_big_map(s, u)
	# --- управление ---
	if (help or G.paused) and not G.dialog:
		var lines := [
			"WASD — бег   Мышь — камера   Пробел — прыжок / от дерева и стены",
			"F — достать / убрать клинок   ЛКМ из ножен — рывок-выхват   Shift держать — быстрый бег",
			"Shift — рывок   E — шаг-вспышка к цели   Tab / колесо — захват цели",
			"ЛКМ — комбо   ПКМ — тяжёлый удар   Q — парирование",
			"1 / 2 / 3 — формы дыхания (стиль — Esc → Снаряжение)   R (держать) — восстановить дыхание",
			"Бег в стену в прыжке — бег по стене   Пробел в воздухе — прыжок к ветке кедра (метка)",
			"N — время суток (день / закат / ночь)   − / + — громкость",
			"Esc — пауза и настройки (клинок, графика, звук, клавиши)   F1 — подсказка",
		]
		var hy := s.y - 270 * u
		var hx := 28 * u
		draw_rect(Rect2(hx - 12 * u, hy - 26 * u, 640 * u, lines.size() * 24 * u + 20 * u), Color(0.02, 0.03, 0.08, 0.7))
		for l in lines:
			_txt(Vector2(hx, hy), l, int(15 * u), Color(0.88, 0.92, 1.0))
			hy += 24 * u
	# --- экран гибели ---
	if p.state == "dead" and p.state_t > 0.8:
		var a5 := clampf((p.state_t - 0.8) * 2.0, 0.0, 1.0)
		draw_rect(Rect2(Vector2.ZERO, s), Color(0.12, 0.0, 0.02, 0.45 * a5))
		_txt(Vector2(s.x * 0.5, s.y * 0.42), "ТЫ ПАЛ", int(80 * u), Color(1.0, 0.85, 0.82, a5), HORIZONTAL_ALIGNMENT_CENTER, 0, 18)
		var left := maxf(0.0, 4.0 - p.state_t)
		var hint := "Снова в бой через %d…" % int(ceil(left))
		if p.state_t > 1.5:
			hint += "   Пробел или ЛКМ — сразу"
		_txt(Vector2(s.x * 0.5, s.y * 0.42 + 54 * u), hint, int(20 * u), Color(0.95, 0.9, 0.9, a5), HORIZONTAL_ALIGNMENT_CENTER, 0)
	_txt(Vector2(s.x - 16 * u, s.y - 14 * u), "Клинок и Демон · версия " + str(ProjectSettings.get_setting("application/config/version", "")), int(12 * u), Color(0.7, 0.75, 0.85, 0.6), HORIZONTAL_ALIGNMENT_RIGHT, 0)
