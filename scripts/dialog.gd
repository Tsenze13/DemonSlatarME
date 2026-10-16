extends Control
# Окно разговора внизу экрана (как в референсе): пиксельный портрет, имя,
# текст печатается по буквам, Пробел / ЛКМ / E — дальше, в конце — выбор (1–4 или мышью).

var lines: Array = []          # [[имя, текст, внешность(Dictionary)], ...]
var idx := 0
var shown := 0.0               # сколько букв видно
var choices: Array = []
var on_choice: Callable
var on_done: Callable
var open := false
var font: Font
var serif: Font
var buttons: Array = []
var box: VBoxContainer
var hover := -1

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_ALWAYS
	font = ThemeDB.fallback_font
	var sf := SystemFont.new()
	sf.font_names = PackedStringArray(["Georgia", "Cambria", "Times New Roman", "Noto Serif", "DejaVu Serif", "serif"])
	serif = sf
	box = VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	add_child(box)
	visible = false

# Начать разговор. lines — [имя, текст, внешность]; choices — подписи кнопок в конце.
func say(lines_: Array, choices_: Array = [], on_choice_ := Callable(), on_done_ := Callable()) -> void:
	lines = lines_
	idx = 0
	shown = 0.0
	choices = choices_
	on_choice = on_choice_
	on_done = on_done_
	open = true
	visible = true
	G.dialog = true
	_clear_buttons()
	if not G.autotest:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if G.sfx:
		G.sfx.play("tick", -14.0, 1.4)

func _clear_buttons() -> void:
	for b in buttons:
		b.queue_free()
	buttons.clear()

func _show_choices() -> void:
	_clear_buttons()
	var u := clampf(size.y / 900.0, 0.7, 2.0)
	box.position = Vector2(size.x * 0.5 + 120 * u, size.y - 250 * u - choices.size() * 50 * u)
	for i in choices.size():
		var b := Button.new()
		b.text = "%d   %s" % [i + 1, choices[i]]
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.custom_minimum_size = Vector2(460 * u, 42 * u)
		b.add_theme_font_size_override("font_size", int(19 * u))
		b.add_theme_stylebox_override("normal", _sb(Color(0.04, 0.05, 0.1, 0.88), Color(0.75, 0.62, 0.4)))
		b.add_theme_stylebox_override("hover", _sb(Color(0.16, 0.12, 0.08, 0.95), Color(1.0, 0.85, 0.5)))
		b.add_theme_stylebox_override("pressed", _sb(Color(0.25, 0.18, 0.1, 0.95), Color(1, 1, 1)))
		b.add_theme_stylebox_override("focus", _sb(Color(0.16, 0.12, 0.08, 0.95), Color(1.0, 0.85, 0.5)))
		var k := i
		b.pressed.connect(func(): _pick(k))
		box.add_child(b)
		buttons.append(b)
	# фокус на первом ответе: стрелки / крестовина геймпада и Enter / A выбирают
	if not buttons.is_empty():
		buttons[0].grab_focus()

func _sb(bg: Color, border: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.border_width_left = 3
	s.border_width_bottom = 1
	s.set_content_margin_all(8)
	s.content_margin_left = 16
	return s

func _pick(i: int) -> void:
	if G.sfx:
		G.sfx.play("tick", -10.0, 1.0)
	close()
	if on_choice.is_valid():
		on_choice.call(i)

func close() -> void:
	open = false
	visible = false
	G.dialog = false
	_clear_buttons()
	if not G.autotest and G.started and not G.paused:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _cur_text() -> String:
	return lines[idx][1] if idx < lines.size() else ""

# Дальше: допечатать строку, следующая строка, выбор или конец.
func advance() -> void:
	if not open:
		return
	var txt := _cur_text()
	if shown < txt.length():
		shown = txt.length()
		return
	if idx < lines.size() - 1:
		idx += 1
		shown = 0.0
		if G.sfx:
			G.sfx.play("tick", -16.0, 1.6)
		return
	if choices.size() > 0:
		if buttons.is_empty():
			_show_choices()
		return
	close()
	if on_done.is_valid():
		on_done.call()

func _input(e: InputEvent) -> void:
	if not open or G.paused:
		return
	if e is InputEventKey and e.pressed and not e.echo:
		if not buttons.is_empty():
			var n: int = e.physical_keycode - KEY_1
			if n >= 0 and n < choices.size():
				_pick(n)
				get_viewport().set_input_as_handled()
			return
		if e.physical_keycode in [KEY_SPACE, KEY_E, KEY_ENTER, KEY_KP_ENTER]:
			advance()
			get_viewport().set_input_as_handled()
	elif e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT and buttons.is_empty():
		advance()
		get_viewport().set_input_as_handled()
	elif e is InputEventJoypadButton and e.pressed and buttons.is_empty() and e.button_index in [JOY_BUTTON_A, JOY_BUTTON_B]:
		advance()
		get_viewport().set_input_as_handled()

func _process(dt: float) -> void:
	if not open:
		return
	var txt := _cur_text()
	if shown < txt.length():
		shown = minf(txt.length(), shown + G.rdt * 55.0)
		if int(shown) % 3 == 0 and G.sfx and randf() < 0.3:
			G.sfx.play("tick", -24.0, 2.2, 0.2)
	elif choices.size() > 0 and idx >= lines.size() - 1 and buttons.is_empty():
		_show_choices()
	queue_redraw()

# Пиксельный портрет 12×12 по внешности жителя.
func _portrait(r: Rect2, lk: Dictionary) -> void:
	draw_rect(r.grow(4), Color(0.75, 0.62, 0.4))
	draw_rect(r, Color(0.12, 0.1, 0.16))
	var c := r.size.x / 12.0
	var px := func(x: int, y: int, w: int, h: int, col: Color):
		draw_rect(Rect2(r.position + Vector2(x, y) * c, Vector2(w, h) * c), col)
	var st: String = lk.get("style", "short")
	if st == "crow":
		px.call(2, 3, 8, 7, Color(0.08, 0.08, 0.12))
		px.call(3, 2, 6, 2, Color(0.08, 0.08, 0.12))
		px.call(7, 5, 4, 2, Color(0.95, 0.75, 0.2))
		px.call(5, 4, 1, 1, Color(1.0, 0.85, 0.3))
		px.call(2, 10, 8, 2, Color(0.15, 0.15, 0.2))
		return
	if st == "demon":
		var sk: Color = lk.get("skin", Color(0.8, 0.8, 0.85))
		px.call(2, 3, 8, 8, sk)
		px.call(2, 1, 8, 3, lk.get("hair", Color(0.5, 0.05, 0.1)))
		px.call(3, 6, 2, 1, Color(1.0, 0.25, 0.2))
		px.call(7, 6, 2, 1, Color(1.0, 0.25, 0.2))
		px.call(4, 9, 4, 1, Color(0.25, 0.02, 0.05))
		px.call(5, 4, 2, 1, Color(1.0, 0.95, 0.7))
		return
	var skin: Color = lk.get("skin", Color(0.95, 0.78, 0.64))
	var hair: Color = lk.get("hair", Color(0.12, 0.1, 0.1))
	var robe: Color = lk.get("robe", Color(0.3, 0.35, 0.45))
	if st == "white":
		hair = Color(0.92, 0.92, 0.94)
	px.call(1, 10, 10, 2, robe)
	px.call(3, 10, 6, 1, robe.lightened(0.3))
	px.call(2, 3, 8, 7, skin)
	if st != "bald":
		px.call(2, 1, 8, 3, hair)
		px.call(1, 2, 1, 5, hair)
		px.call(10, 2, 1, 5, hair)
	else:
		px.call(1, 4, 1, 3, Color(0.85, 0.85, 0.85))
		px.call(10, 4, 1, 3, Color(0.85, 0.85, 0.85))
	if st == "bun":
		px.call(5, 0, 3, 2, hair)
	if st == "band":
		px.call(2, 3, 8, 1, Color(0.95, 0.95, 0.92))
	px.call(3, 5, 2, 2, Color(0.15, 0.1, 0.08))
	px.call(7, 5, 2, 2, Color(0.15, 0.1, 0.08))
	px.call(4, 5, 1, 1, Color(1, 1, 1))
	px.call(8, 5, 1, 1, Color(1, 1, 1))
	px.call(5, 8, 2, 1, Color(0.6, 0.3, 0.28))
	if st == "white" or st == "bald":
		px.call(3, 8, 6, 3, Color(0.93, 0.93, 0.92))
		px.call(5, 8, 2, 1, Color(0.6, 0.3, 0.28))
	if st == "white":
		px.call(8, 4, 1, 3, Color(0.6, 0.3, 0.3))

func _draw() -> void:
	if not open or idx >= lines.size():
		return
	var s := size
	var u := clampf(s.y / 900.0, 0.7, 2.0)
	var w := minf(s.x - 80 * u, 1100 * u)
	var h := 170 * u
	var r := Rect2(s.x * 0.5 - w * 0.5, s.y - h - 40 * u, w, h)
	draw_rect(r.grow(3 * u), Color(0.75, 0.62, 0.4, 0.9))
	draw_rect(r, Color(0.03, 0.03, 0.07, 0.9))
	draw_rect(Rect2(r.position + Vector2(0, 0), Vector2(w, 3 * u)), Color(1.0, 0.85, 0.55, 0.5))
	var ln: Array = lines[idx]
	var lk: Dictionary = ln[2] if ln.size() > 2 else {}
	var pr := Rect2(r.position + Vector2(18 * u, 18 * u), Vector2(134, 134) * u)
	_portrait(pr, lk)
	var tx := pr.end.x + 26 * u
	# имя — с засечками, как титры
	draw_string_outline(serif, Vector2(tx, r.position.y + 40 * u), ln[0], HORIZONTAL_ALIGNMENT_LEFT, -1, int(26 * u), 6, Color(0, 0, 0, 0.7))
	draw_string(serif, Vector2(tx, r.position.y + 40 * u), ln[0], HORIZONTAL_ALIGNMENT_LEFT, -1, int(26 * u), Color(1.0, 0.86, 0.55))
	var txt: String = ln[1].substr(0, int(shown))
	var tw := r.end.x - tx - 24 * u
	draw_multiline_string(font, Vector2(tx, r.position.y + 76 * u), txt, HORIZONTAL_ALIGNMENT_LEFT, tw, int(20 * u), -1, Color(0.95, 0.95, 1.0))
	# стрелка «дальше»
	if shown >= _cur_text().length() and (choices.is_empty() or idx < lines.size() - 1):
		var bob := sin(G.real_time * 6.0) * 3 * u
		var ax := r.end.x - 30 * u
		var ay := r.end.y - 22 * u + bob
		draw_colored_polygon(PackedVector2Array([Vector2(ax - 8 * u, ay - 6 * u), Vector2(ax + 8 * u, ay - 6 * u), Vector2(ax, ay + 4 * u)]), Color(1.0, 0.86, 0.55))
	draw_string(font, Vector2(r.position.x + 18 * u, r.end.y + 26 * u), "Пробел / ЛКМ — дальше", HORIZONTAL_ALIGNMENT_LEFT, -1, int(13 * u), Color(0.8, 0.8, 0.85, 0.7))
