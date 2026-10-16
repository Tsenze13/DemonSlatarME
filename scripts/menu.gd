extends Control
# Главное меню и меню паузы с настройками (вкладки: Клинок, Графика, Звук,
# Управление). Все настройки — в user://settings.cfg, применяются сразу.

const SwordLib = preload("res://scripts/sword_lib.gd")
const SETTINGS_PATH := "user://settings.cfg"

var main: Node                     # main.gd — пересчёт пиксельного кадра и пр.
var settings := {
	"volume": 0.4, "sfx": 1.0, "music": 0.6, "sens": 1.0, "invert_y": false, "fov": 72.0, "cam_dist": 5.2,
	"shake": 1.0, "auto_cam": true, "pixel": false, "sword": 0, "saya": 0, "tint": 0, "haori": 0, "breath": 0,
	"window": 0, "vsync": true, "fps_limit": 0, "shadows": 2, "render_scale": 1.0, "grass": 1.0, "show_fps": false,
	"cine": true, "difficulty": 1, "preset": 2, "msaa": 2, "glow": true, "view_dist": 1.0,
	"keys": {},
}
# Готовые наборы графики: [тени, чёткость 3D, трава, сглаживание, свечение, дальность]
const PRESETS := [
	[1, 0.75, 0.3, 0, false, 0.45],   # Низкое — для слабых ноутбуков
	[1, 0.9, 0.6, 1, true, 0.7],      # Среднее
	[2, 1.0, 1.0, 2, true, 1.0],      # Высокое
]
const FPS_LIMITS := [0, 30, 60, 120, 144, 240]
const ACTIONS := [
	["move_f", "Вперёд"], ["move_b", "Назад"], ["move_l", "Влево"], ["move_r", "Вправо"],
	["jump", "Прыжок"], ["dash", "Рывок / бег (держать)"], ["flash", "Шаг-вспышка"],
	["light", "Удар"], ["heavy", "Тяжёлый удар"], ["parry", "Парирование"], ["draw", "Достать / убрать клинок"],
	["breathe", "Восстановить дыхание"], ["form1", "Форма 1"], ["form2", "Форма 2"], ["form3", "Форма 3"],
	["lock", "Захват цели"], ["mark", "Метка охотника"], ["map", "Карта"], ["daynight", "День / ночь"], ["help", "Подсказка"],
]

var title_screen: Control          # главное меню
var pause_panel: Control           # меню паузы (вкладки)
var tabs: TabContainer
var ctrl: Dictionary = {}          # элементы настроек по имени
var bind_buttons: Dictionary = {}
var capture_action := ""           # ждём клавишу для этого действия
var from_title := false            # настройки открыты из главного меню

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_title()
	_build_pause()
	pause_panel.visible = false

# ---------------------------------------------------------------------
# ГЛАВНОЕ МЕНЮ
func _build_title() -> void:
	title_screen = Control.new()
	title_screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(title_screen)
	var shade := ColorRect.new()
	shade.color = Color(0.0, 0.0, 0.04, 0.18)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_screen.add_child(shade)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	title_screen.add_child(box)
	box.anchor_left = 0.0
	box.anchor_right = 0.0
	box.anchor_top = 0.22
	box.anchor_bottom = 1.0
	box.offset_left = 90
	box.offset_right = 900
	var serif := SystemFont.new()
	serif.font_names = PackedStringArray(["Georgia", "Cambria", "Times New Roman", "Noto Serif", "DejaVu Serif", "serif"])
	var t := Label.new()
	t.text = "Клинок и Демон"
	t.add_theme_font_override("font", serif)
	t.add_theme_font_size_override("font_size", 80)
	t.add_theme_color_override("font_color", Color(1.0, 0.95, 0.9))
	t.add_theme_constant_override("outline_size", 14)
	t.add_theme_color_override("font_outline_color", Color(0.05, 0.02, 0.08))
	box.add_child(t)
	var sub := Label.new()
	sub.text = "деревня Ивакура ждёт ночи · версия " + str(ProjectSettings.get_setting("application/config/version", ""))
	sub.add_theme_font_override("font", serif)
	sub.add_theme_font_size_override("font_size", 24)
	sub.add_theme_color_override("font_color", Color(0.6, 0.8, 1.0))
	sub.add_theme_constant_override("outline_size", 8)
	sub.add_theme_color_override("font_outline_color", Color(0.02, 0.02, 0.06))
	box.add_child(sub)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 40)
	box.add_child(gap)
	cont_btn = _title_button(box, "Продолжить", func(): _start_game("continue"))
	_title_button(box, "Новая игра", func(): _start_game("new"))
	_title_button(box, "Свободная охота", func(): _start_game("free"))
	_title_button(box, "Настройки", func(): _open_settings(true))
	_title_button(box, "Выйти", func(): save(); get_tree().quit())

func _title_button(parent: Control, txt: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = txt
	b.custom_minimum_size = Vector2(320, 56)
	b.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	b.add_theme_font_size_override("font_size", 28)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.add_theme_stylebox_override("normal", _sb(Color(0.04, 0.06, 0.14, 0.75), Color(0.3, 0.5, 0.9)))
	b.add_theme_stylebox_override("hover", _sb(Color(0.1, 0.18, 0.38, 0.9), Color(0.6, 0.85, 1.0)))
	b.add_theme_stylebox_override("pressed", _sb(Color(0.15, 0.25, 0.5, 0.95), Color(1, 1, 1)))
	b.add_theme_stylebox_override("focus", _sb(Color(0.1, 0.18, 0.38, 0.9), Color(0.6, 0.85, 1.0)))
	b.pressed.connect(cb)
	parent.add_child(b)
	return b

func _sb(bg: Color, border: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.border_width_left = 4
	s.set_content_margin_all(12)
	s.content_margin_left = 22
	return s

var cont_btn: Button
func show_title() -> void:
	G.started = false
	title_screen.visible = true
	if cont_btn:
		cont_btn.visible = G.story != null and G.story.has_save()
	pause_panel.visible = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _start_game(how := "free") -> void:
	title_screen.visible = false
	G.started = true
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if G.story:
		match how:
			"new":
				G.story.new_game()
			"continue":
				G.story.continue_game()
			_:
				G.story.free_hunt()
	if G.hud:
		G.hud.help = how == "free"
		G.hud.help_t = 14.0 if how == "free" else 0.0

# ---------------------------------------------------------------------
# ПАУЗА И НАСТРОЙКИ
func _build_pause() -> void:
	pause_panel = Control.new()
	pause_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(pause_panel)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0.05, 0.55)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pause_panel.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pause_panel.add_child(center)
	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.07, 0.15, 0.96)
	sb.border_color = Color(0.4, 0.65, 1.0)
	sb.set_border_width_all(2)
	sb.set_content_margin_all(22)
	panel.add_theme_stylebox_override("panel", sb)
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	box.custom_minimum_size = Vector2(640, 0)
	panel.add_child(box)
	var t := Label.new()
	t.text = "ПАУЗА"
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.add_theme_font_size_override("font_size", 36)
	box.add_child(t)
	ctrl["title"] = t
	tabs = TabContainer.new()
	tabs.custom_minimum_size = Vector2(640, 470)
	tabs.add_theme_font_size_override("font_size", 18)
	box.add_child(tabs)
	_tab_journal()
	_tab_sword()
	_tab_graphics()
	_tab_sound()
	_tab_controls()
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(row)
	ctrl["continue"] = _btn(row, "Продолжить", func(): close_menu())
	ctrl["to_title"] = _btn(row, "Главное меню", func(): close_menu(); show_title())
	_btn(row, "Выйти из игры", func(): save(); get_tree().quit())

func _btn(parent: Control, txt: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = txt
	b.add_theme_font_size_override("font_size", 20)
	b.custom_minimum_size = Vector2(180, 42)
	b.pressed.connect(cb)
	parent.add_child(b)
	return b

func _page(name_: String) -> VBoxContainer:
	var sc := ScrollContainer.new()
	sc.name = name_
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	tabs.add_child(sc)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(v)
	return v

func _label(parent: Control, txt: String, fs := 18) -> Label:
	var l := Label.new()
	l.text = txt
	l.add_theme_font_size_override("font_size", fs)
	parent.add_child(l)
	return l

func _slider(parent: Control, key: String, title: String, lo: float, hi: float, step: float, cb: Callable) -> HSlider:
	var row := HBoxContainer.new()
	parent.add_child(row)
	var l := _label(row, title)
	l.custom_minimum_size = Vector2(250, 0)
	var s := HSlider.new()
	s.min_value = lo
	s.max_value = hi
	s.step = step
	s.custom_minimum_size = Vector2(300, 28)
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.value_changed.connect(cb)
	row.add_child(s)
	ctrl[key] = s
	return s

func _check(parent: Control, key: String, title: String, cb: Callable) -> CheckBox:
	var c := CheckBox.new()
	c.text = title
	c.add_theme_font_size_override("font_size", 18)
	c.toggled.connect(cb)
	parent.add_child(c)
	ctrl[key] = c
	return c

func _option(parent: Control, key: String, title: String, items: Array, cb: Callable) -> OptionButton:
	var row := HBoxContainer.new()
	parent.add_child(row)
	var l := _label(row, title)
	l.custom_minimum_size = Vector2(250, 0)
	var o := OptionButton.new()
	o.add_theme_font_size_override("font_size", 17)
	for it in items:
		o.add_item(it)
	o.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	o.item_selected.connect(cb)
	row.add_child(o)
	ctrl[key] = o
	return o

func _tab_sword() -> void:
	var v := _page("Снаряжение")
	var names := []
	for k in 6:
		names.append(SwordLib.NAMES[k])
	names += ["Парные клинки (на цепи)", "Гибкий клинок (хлыст)", "Кубический (свой)", "Нагината (древковое)", "Шар и топор на цепи"]
	_option(v, "sword", "Оружие", names, func(i): settings.sword = i; _apply_sword())
	var sayas := []
	for st in SwordLib.SAYA:
		sayas.append(st[0])
	_option(v, "saya", "Ножны", sayas, func(i): settings.saya = i; _apply_look())
	var tints := []
	for tn in SwordLib.TINTS:
		tints.append(tn[0])
	_option(v, "tint", "Цвет клинка", tints, func(i): settings.tint = i; _apply_look())
	var hs := []
	for h in SwordLib.HAORI:
		hs.append(h[0])
	_option(v, "haori", "Хаори", hs, _set_haori)
	var brs := []
	for k in G.BREATH_ORDER:
		brs.append(G.BREATHS[k].name + (" (скрытое — после финала)" if k == "dawn" else ""))
	_option(v, "breath", "Стиль дыхания", brs, _set_breath)
	_label(v, "Катаны держатся двумя руками и носятся за поясом.\nПарные клинки — на цепи, за спиной в бинтах; ПКМ — бросок на цепи.\nХлыст — дальние хлёсты; ПКМ — щелчок до 7 м.\nНагината — длинные махи и укол; шар на цепи — бьёт по кругу и в землю, ПКМ — бросок на 8 м.", 15).modulate = Color(0.75, 0.82, 1.0)

# Журнал: главы сюжета, прокачка, ранг и статистика.
var journal: RichTextLabel
func _tab_journal() -> void:
	var v := _page("Журнал")
	journal = RichTextLabel.new()
	journal.bbcode_enabled = true
	journal.fit_content = true
	journal.scroll_active = false
	journal.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	journal.add_theme_font_size_override("normal_font_size", 18)
	journal.add_theme_font_size_override("bold_font_size", 20)
	v.add_child(journal)

func refresh_journal() -> void:
	if journal == null:
		return
	var st = G.story
	var pr: Dictionary = G.prog
	var t := ""
	t += "[b][color=#ffd890]Ранг:[/color][/b] %s     [b][color=#ffd890]Рё:[/color][/b] %d     [b][color=#ffd890]Мастерство:[/color][/b] %d\n" % [st.rank_name() if st else "", int(pr.ryo), int(pr.mastery)]
	t += "Выносливость %d/5 · Лёгкие %d/5 · Концентрация %d/3 · Закалка клинка %d/5\n" % [int(pr.hp), int(pr.lungs), int(pr.focus), int(pr.blade)]
	t += "Демонов обезглавлено: %d · Охот на заказ: %d · В игре: %d мин\n\n" % [int(G.stats.kills_total), int(pr.get("hunts", 0)), int(float(G.stats.play_time) / 60.0)]
	t += "[b][color=#ffd890]СЮЖЕТ[/color][/b]\n"
	if st:
		var cur_ch := int(pr.chapter)
		for i in st.CH.size():
			var c: Dictionary = st.CH[i]
			var mark := "[color=#7fe08a]✓[/color]" if i < cur_ch or bool(pr.finished) else ("[color=#ffd36b]▶[/color]" if i == cur_ch else "[color=#666a77]·[/color]")
			var title := ("Пролог · " if i == 0 else "Глава %d · " % i) + String(c.name)
			if i > cur_ch and not bool(pr.finished):
				t += "%s  [color=#666a77]%s — ???[/color]\n" % [mark, "Глава %d" % i]
			else:
				t += "%s  %s — [i]%s[/i]\n" % [mark, title, String(c.sub)]
		if bool(pr.finished):
			t += "\n[color=#ffd890]Кагэцу повержен. Ворон даёт охоты на заказ — каждая злее.[/color]\n"
		elif st.objective != "":
			t += "\n[b]Сейчас:[/b] %s\n" % st.objective
	t += "\n[b][color=#ffd890]ДЕМОНЫ[/color][/b]\n"
	t += "Низший — стаей, слабый. Отшельник — копья крови, прыжок, отращивает руки.\n"
	t += "Громила — не вздрагивает от лёгких ударов, бей тяжёлыми и формами, руби ноги.\n"
	t += "Кровавая ткачиха — держит дистанцию, веер копий: сокращай рывком.\n"
	t += "Кагэцу — исчезает и выходит из-за спины, кровавый дождь, шея срастается дважды.\n"
	t += "\n[b][color=#ffd890]МЕТКА ОХОТНИКА[/color][/b] (с 4-й главы): копи ярость в бою, на полной шкале — V. 10 с силы и скорости, здоровье тает.\n"
	t += "[b][color=#ffd890]КАРТА[/color][/b] — клавиша M.\n"
	var got := 0
	for a in G.ACH:
		if G.has_ach(a[0]):
			got += 1
	t += "\n[b][color=#ffd890]ДОСТИЖЕНИЯ %d/%d[/color][/b]\n" % [got, G.ACH.size()]
	for a in G.ACH:
		if G.has_ach(a[0]):
			t += "[color=#7fe08a]✓ %s[/color] — %s\n" % [a[1], a[2]]
		else:
			t += "[color=#666a77]· %s — %s[/color]\n" % [a[1], a[2]]
	journal.text = t

func _tab_graphics() -> void:
	var v := _page("Графика")
	_option(v, "window", "Окно", ["В окне", "Полный экран", "Полный экран (без рамки)"], func(i): settings.window = i; _apply_window())
	_check(v, "vsync", "Вертикальная синхронизация", func(on): settings.vsync = on; _apply_window())
	var lim := []
	for f in FPS_LIMITS:
		lim.append("без ограничения" if f == 0 else "%d кадров/с" % f)
	_option(v, "fps_limit", "Ограничение кадров", lim, func(i): settings.fps_limit = i; _apply_window())
	_option(v, "preset", "Качество", ["Низкое (слабый ПК)", "Среднее", "Высокое", "Своё"], set_preset)
	_option(v, "shadows", "Тени", ["Выключены", "Простые", "Чёткие"], func(i): settings.shadows = i; _custom())
	_slider(v, "render_scale", "Чёткость 3D (меньше — быстрее)", 0.5, 1.0, 0.05, func(x): settings.render_scale = x; _custom())
	_slider(v, "grass", "Трава", 0.0, 1.0, 0.1, func(x): settings.grass = x; _custom())
	_option(v, "msaa", "Сглаживание", ["Выключено", "2×", "4×"], func(i): settings.msaa = i; _custom())
	_check(v, "glow", "Свечение (ореолы огня и фонарей)", func(on): settings.glow = on; _custom())
	_slider(v, "view_dist", "Дальность прорисовки", 0.3, 1.0, 0.05, func(x): settings.view_dist = x; _custom())
	_check(v, "pixel", "Пиксельный фильтр (крупные пиксели)", func(on): settings.pixel = on; _apply_graphics())
	_check(v, "show_fps", "Показывать кадры в секунду", func(on): settings.show_fps = on; G.show_fps = on)

func _tab_sound() -> void:
	var v := _page("Звук")
	_slider(v, "volume", "Общая громкость", 0.0, 1.0, 0.05, func(x): set_volume(x, false))
	_slider(v, "sfx", "Эффекты", 0.0, 1.0, 0.05, func(x): settings.sfx = x; _apply_sound())
	_slider(v, "music", "Музыка и окружение", 0.0, 1.0, 0.05, func(x): settings.music = x; _apply_sound())
	_label(v, "Во время игры: клавиши  −  и  +  — общая громкость", 15).modulate = Color(0.75, 0.82, 1.0)

func _tab_controls() -> void:
	var v := _page("Управление")
	_option(v, "difficulty", "Сложность", ["Лёгкая — демоны бьют слабее", "Обычная", "Тяжёлая — демоны злее, клинок слабее"], func(i): settings.difficulty = i; G.difficulty = i)
	_slider(v, "sens", "Чувствительность мыши", 0.2, 3.0, 0.05, func(x): settings.sens = x; _apply_camera())
	_check(v, "invert_y", "Инвертировать мышь по вертикали", func(on): settings.invert_y = on; _apply_camera())
	_slider(v, "fov", "Угол обзора", 60.0, 95.0, 1.0, func(x): settings.fov = x; _apply_camera())
	_slider(v, "cam_dist", "Дальность камеры", 3.5, 8.0, 0.1, func(x): settings.cam_dist = x; _apply_camera())
	_slider(v, "shake", "Тряска камеры", 0.0, 1.5, 0.1, func(x): settings.shake = x; _apply_camera())
	_check(v, "auto_cam", "Камера сама заходит за спину на бегу", func(on): settings.auto_cam = on; _apply_camera())
	_check(v, "cine", "Кинокадр на третьей форме", func(on): settings.cine = on; _apply_camera())
	_label(v, "Клавиши (нажми на кнопку, затем новую клавишу или кнопку мыши; Esc — отмена)", 15).modulate = Color(0.75, 0.82, 1.0)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 14)
	v.add_child(grid)
	for a in ACTIONS:
		var l := _label(grid, a[1], 17)
		l.custom_minimum_size = Vector2(300, 0)
		var b := Button.new()
		b.custom_minimum_size = Vector2(220, 34)
		b.add_theme_font_size_override("font_size", 17)
		var act: String = a[0]
		b.pressed.connect(func(): _start_capture(act))
		grid.add_child(b)
		bind_buttons[act] = b
	_btn(v, "Вернуть клавиши по умолчанию", func(): G.reset_keys(); settings.keys = {}; _refresh_binds(); save())
	_label(v, "Геймпад: A — прыжок, B — рывок, X — удар, Y — тяжёлый, LB — парирование,\nRB — шаг-вспышка, крестовина — формы, правый стик — захват, Back — клинок.", 15).modulate = Color(0.75, 0.82, 1.0)
	_refresh_binds()

# --- переназначение клавиш ---
func _start_capture(act: String) -> void:
	capture_action = act
	bind_buttons[act].text = "нажми клавишу…"

func _input(e: InputEvent) -> void:
	if capture_action == "":
		return
	var ev: InputEvent = null
	if e is InputEventKey and e.pressed and not e.echo:
		if e.physical_keycode == KEY_ESCAPE:
			capture_action = ""
			_refresh_binds()
			get_viewport().set_input_as_handled()
			return
		var k := InputEventKey.new()
		k.physical_keycode = e.physical_keycode
		ev = k
	elif e is InputEventMouseButton and e.pressed:
		var m := InputEventMouseButton.new()
		m.button_index = e.button_index
		ev = m
	if ev == null:
		return
	G.bind_key(capture_action, ev)
	settings.keys[capture_action] = G.event_code(ev)
	capture_action = ""
	_refresh_binds()
	save()
	get_viewport().set_input_as_handled()

func _refresh_binds() -> void:
	for act in bind_buttons:
		bind_buttons[act].text = G.key_text(act)

# ---------------------------------------------------------------------
func _open_settings(title_mode: bool) -> void:
	from_title = title_mode
	pause_panel.visible = true
	ctrl.title.text = "НАСТРОЙКИ" if title_mode else "ПАУЗА"
	ctrl.continue.text = "Назад" if title_mode else "Продолжить"
	ctrl.to_title.visible = not title_mode
	tabs.current_tab = 1 if title_mode else 0
	if title_mode:
		title_screen.visible = false

func open_pause() -> void:
	refresh_journal()
	G.paused = true
	get_tree().paused = true
	_open_settings(false)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func close_menu() -> void:
	capture_action = ""
	pause_panel.visible = false
	save()
	if from_title:
		from_title = false
		title_screen.visible = true
		return
	G.paused = false
	get_tree().paused = false
	if G.started:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func is_open() -> bool:
	return pause_panel.visible

# ---------------------------------------------------------------------
# ПРИМЕНЕНИЕ НАСТРОЕК
func set_volume(v: float, show: bool) -> void:
	settings.volume = clampf(v, 0.0, 1.0)
	_apply_sound()
	var s: HSlider = ctrl.get("volume")
	if s and absf(s.value - settings.volume) > 0.001:
		s.set_value_no_signal(settings.volume)
	if show and G.hud:
		G.hud.notify("Громкость: %d%%" % int(round(settings.volume * 100)), 1.2)
		save()

func _apply_sound() -> void:
	var m := AudioServer.get_bus_index("Master")
	AudioServer.set_bus_volume_db(m, linear_to_db(maxf(0.0001, settings.volume * settings.volume)))
	AudioServer.set_bus_mute(m, settings.volume <= 0.001)
	for pair in [["SFX", settings.sfx], ["Music", settings.music]]:
		var i := AudioServer.get_bus_index(pair[0])
		if i >= 0:
			var x: float = pair[1]
			AudioServer.set_bus_volume_db(i, linear_to_db(maxf(0.0001, x * x)))
			AudioServer.set_bus_mute(i, x <= 0.001)

func _apply_sword() -> void:
	if G.player:
		G.player.set_sword(settings.sword)

func _set_breath(i: int) -> void:
	settings.breath = i
	if G.player:
		G.player.set_breath(i)
		# закрытая Заря — вернуть выбор на действующий стиль
		var real: int = G.BREATH_ORDER.find(G.breath_style)
		if real != i:
			settings.breath = real
			(ctrl.breath as OptionButton).select(real)

func _set_haori(i: int) -> void:
	settings.haori = i
	if G.player:
		G.player.set_haori(i)

func _apply_look() -> void:
	if G.player:
		G.player.set_look(settings.saya, settings.tint)

func _apply_camera() -> void:
	var r: Node = G.cam_rig
	if r:
		r.sens_mult = settings.sens
		r.invert_y = settings.invert_y
		r.base_fov = settings.fov
		r.dist = settings.cam_dist
		r.auto_cam = settings.auto_cam and not G.autotest
		r.cine_forms = bool(settings.cine)
	G.shake_mult = settings.shake

func _apply_window() -> void:
	if G.autotest:
		return
	match int(settings.window):
		0:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MAXIMIZED)
		1:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		2:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if settings.vsync else DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = FPS_LIMITS[clampi(int(settings.fps_limit), 0, FPS_LIMITS.size() - 1)]

# Набор качества: ставит все настройки графики разом.
func set_preset(i: int) -> void:
	settings.preset = i
	if i < PRESETS.size():
		var pr: Array = PRESETS[i]
		settings.shadows = pr[0]
		settings.render_scale = pr[1]
		settings.grass = pr[2]
		settings.msaa = pr[3]
		settings.glow = pr[4]
		settings.view_dist = pr[5]
		_sync_graphics_ctrl()
	_apply_graphics()

# Любая ручная правка графики — набор «Своё».
func _custom() -> void:
	settings.preset = 3
	if ctrl.has("preset"):
		(ctrl.preset as OptionButton).select(3)
	_apply_graphics()

func _sync_graphics_ctrl() -> void:
	if not ctrl.has("preset"):
		return
	for k in ["render_scale", "grass", "view_dist"]:
		(ctrl[k] as HSlider).set_value_no_signal(float(settings[k]))
	(ctrl.glow as CheckBox).set_pressed_no_signal(bool(settings.glow))
	(ctrl.shadows as OptionButton).select(clampi(settings.shadows, 0, 2))
	(ctrl.msaa as OptionButton).select(clampi(settings.msaa, 0, 2))
	(ctrl.preset as OptionButton).select(clampi(settings.preset, 0, 3))

func _apply_graphics() -> void:
	if main:
		main.apply_view(settings)
	if G.world and G.world.has_method("set_quality"):
		G.world.set_quality(int(settings.shadows), float(settings.grass), bool(settings.glow), float(settings.view_dist))

func apply_all() -> void:
	_apply_sound()
	_apply_camera()
	_apply_window()
	_apply_graphics()
	G.show_fps = settings.show_fps
	if G.player:
		G.player.saya_style = settings.saya
		G.player.blade_tint = settings.tint
		G.player.set_sword(settings.sword)
		G.player.set_haori(settings.haori)
		G.player.set_breath(settings.breath)
	# элементы меню — по текущим значениям
	for k in ["volume", "sfx", "music", "sens", "fov", "cam_dist", "shake", "render_scale", "grass"]:
		(ctrl[k] as HSlider).set_value_no_signal(float(settings[k]))
	for k in ["invert_y", "auto_cam", "vsync", "pixel", "show_fps", "cine"]:
		(ctrl[k] as CheckBox).set_pressed_no_signal(bool(settings[k]))
	(ctrl.sword as OptionButton).select(clampi(settings.sword if settings.sword >= 0 else 8, 0, 10))
	(ctrl.saya as OptionButton).select(clampi(settings.saya, 0, SwordLib.SAYA.size() - 1))
	(ctrl.tint as OptionButton).select(clampi(settings.tint, 0, SwordLib.TINTS.size() - 1))
	(ctrl.haori as OptionButton).select(clampi(settings.haori, 0, SwordLib.HAORI.size() - 1))
	(ctrl.breath as OptionButton).select(clampi(settings.breath, 0, G.BREATH_ORDER.size() - 1))
	(ctrl.window as OptionButton).select(clampi(settings.window, 0, 2))
	(ctrl.difficulty as OptionButton).select(clampi(settings.difficulty, 0, 2))
	G.difficulty = 1 if G.autotest else int(settings.difficulty)
	(ctrl.fps_limit as OptionButton).select(clampi(settings.fps_limit, 0, FPS_LIMITS.size() - 1))
	_sync_graphics_ctrl()
	_refresh_binds()

func load_settings() -> void:
	var cf := ConfigFile.new()
	if cf.load(SETTINGS_PATH) == OK:
		for k in settings:
			if k == "keys":
				continue
			var def = settings[k]
			var v = cf.get_value("main", k, def)
			if typeof(def) == TYPE_FLOAT:
				settings[k] = float(v)
			elif typeof(def) == TYPE_INT:
				settings[k] = int(v)
			elif typeof(def) == TYPE_BOOL:
				settings[k] = bool(v)
		if cf.has_section("keys"):
			for act in cf.get_section_keys("keys"):
				var code: String = cf.get_value("keys", act, "")
				var ev: InputEvent = G.event_from_code(code)
				if ev != null and InputMap.has_action(act):
					G.bind_key(act, ev)
					settings.keys[act] = code
	apply_all()

func save() -> void:
	var cf := ConfigFile.new()
	for k in settings:
		if k != "keys":
			cf.set_value("main", k, settings[k])
	for act in settings.keys:
		cf.set_value("keys", act, settings.keys[act])
	cf.save(SETTINGS_PATH)
