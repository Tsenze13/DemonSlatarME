extends Node
# Сюжет «Клинка и Демона»: пролог-обучение у наставника, Отбор, шесть ночных охот
# по округе деревни Ивакура и бой с Третьей Ущербной луной. Днём — деревня:
# жители, наставник (тренировки за мастерство), кузнец (закалка за рё), ворон с заданиями.
# Ночью — охота: идёшь к месту по метке, волны демонов, награда, ранг охотника.

const Npc = preload("res://scripts/npc.gd")
const Demon = preload("res://scripts/demon.gd")

var phase := "idle"          # idle | intro | tutorial | day | go | fight | done | ending | free
var chapter := 0
var wave := 0
var alive: Array = []        # демоны текущей волны
var wave_total := 0
var objective := ""
var target = null            # Vector3 метки на карте или null
var npcs := {}
var crow: Node3D = null
var near: Node3D = null      # житель рядом (E — поговорить)
var fade := 0.0              # затемнение экрана 0..1
var fade_to := 0.0
var card := ""               # титры главы
var card_sub := ""
var card_t := 0.0
var tut_step := 0
var tut_attacks := 0
var _last_state := ""
var wave_wait := -1.0
var done_t := -1.0
var kills_ch := 0

const RANKS := ["Десятая ступень", "Девятая ступень", "Восьмая ступень", "Седьмая ступень", "Шестая ступень",
	"Пятая ступень", "Четвёртая ступень", "Третья ступень", "Вторая ступень", "Первая ступень"]

# Внешность жителей (npc.gd)
const LOOK := {
	"gensai": {"style": "white", "skin": Color(0.9, 0.74, 0.6), "robe": Color(0.18, 0.3, 0.26), "robe2": Color(0.14, 0.14, 0.18),
		"obi": Color(0.62, 0.52, 0.32), "prop": "sword", "stern": true},
	"tetsu": {"style": "band", "skin": Color(0.84, 0.6, 0.44), "robe": Color(0.42, 0.26, 0.16), "robe2": Color(0.2, 0.18, 0.18),
		"hair": Color(0.1, 0.08, 0.08), "prop": "hammer", "stern": true},
	"elder": {"style": "bald", "skin": Color(0.9, 0.75, 0.62), "robe": Color(0.42, 0.34, 0.5), "robe2": Color(0.28, 0.24, 0.32),
		"obi": Color(0.2, 0.18, 0.25), "prop": "cane"},
	"okiku": {"style": "bun", "skin": Color(0.96, 0.82, 0.72), "robe": Color(0.78, 0.46, 0.52), "robe2": Color(0.5, 0.28, 0.35),
		"obi": Color(0.95, 0.85, 0.5), "hair": Color(0.1, 0.07, 0.08), "prop": "basket"},
	"taro": {"style": "kid", "skin": Color(0.95, 0.78, 0.64), "robe": Color(0.3, 0.52, 0.72), "robe2": Color(0.22, 0.3, 0.45),
		"hair": Color(0.15, 0.1, 0.08), "scale": 0.72},
	"crow": {"style": "crow"},
}
const NAMES := {"gensai": "Наставник Гэнсай", "tetsu": "Кузнец Тэцу", "elder": "Староста Мотоки",
	"okiku": "Окику", "taro": "Таро", "crow": "Ворон Кагари"}
const HERO := {"style": "short", "skin": Color(0.95, 0.78, 0.64), "robe": Color(0.11, 0.12, 0.18), "hair": Color(0.15, 0.1, 0.1)}

# Главы. place — куда идти, start — где очнуться после гибели, waves — [[вид, x, z], ...].
var CH := [
	{"name": "Ученик", "sub": "пролог", "time": "sunset"},
	{"name": "Отбор", "sub": "продержись до рассвета у святилища Кумо", "time": "night",
		"place": Vector3(0, 0, -56), "start": Vector3(0, 0, -44), "where": "Святилище Кумо",
		"waves": [[["low", -5, -62], ["low", 5, -62]], [["low", -8, -50], ["low", 8, -50], ["low", 0, -66]],
			[["low", -6, -60], ["low", 6, -60], ["low", -9, -52], ["low", 9, -52]]],
		"brief": ["Кааа! Слушай, ученик! Наставник Гэнсай велел передать: сегодня ночью — Отбор.",
			"На холме у святилища Кумо собираются низшие демоны. Продержись до рассвета.",
			"Пройдёшь — станешь охотником. Не пройдёшь — Кааа… не будем об этом."],
		"outro": ["Рассвет! Ты выстоял, кааа! Гэнсай сказал «неплохо» — от него это почти похвала.",
			"Теперь ты охотник десятой ступени. Я — твой ворон. Задания — через меня!"],
		"reward": [60, 2]},
	{"name": "Улица фонарей", "sub": "в деревне пропадают люди", "time": "night",
		"place": Vector3(32, 0, -30), "start": Vector3(32, 0, -2), "where": "Деревня Ивакура",
		"waves": [[["low", 31, -38], ["low", 34, -46]], [["low", 30, -22], ["low", 34, -50], ["low", 32, -58]]],
		"brief": ["Кааа! Беда в Ивакуре! Ночью с улицы фонарей пропадают люди.",
			"Староста говорит — то ли тени, то ли звери. Я говорю — демоны! Кааа!",
			"Иди на улицу фонарей, когда стемнеет. Не дай им уйти в лес."],
		"outro": ["Улица чиста! Жители выходят из домов, кааа!",
			"Но это мелочь. Низших кто-то гонит из старого леса. Там живёт кто-то постарше…"],
		"reward": [90, 2]},
	{"name": "Отшельник старого леса", "sub": "демон, что живёт в кедрах", "time": "night",
		"place": Vector3(-58, 0, -38), "start": Vector3(-44, 0, -26), "where": "Старый кедровый лес",
		"waves": [[["low", -62, -34], ["low", -56, -46]], [["hermit", -60, -42]]],
		"brief": ["Кааа! Следы ведут в старый кедровый лес. Там охотился демон-отшельник.",
			"Он отращивает руки и метает копья из крови. Руби ему шею, пока открыта!",
			"И не стой на месте, когда он прыгает. Кааа!"],
		"outro": ["Отшельник обратился в пепел! Лес вздохнул, кааа.",
			"Но он кричал перед смертью: «Тень придёт за мной». Тень? Мне не нравится это слово."],
		"reward": [140, 3]},
	{"name": "Болотный громила", "sub": "у пруда Цукими кто-то ломает мосты", "time": "night",
		"place": Vector3(-34, 0, 8), "start": Vector3(-14, 0, 6), "where": "Пруд Цукими",
		"waves": [[["low", -38, 10], ["low", -28, 12], ["low", -42, 6]], [["brute", -34, 10]]],
		"brief": ["Кааа! У пруда Цукими рыбаки видели великана с бычьими рогами.",
			"Лёгкие удары его не остановят — только тяжёлые и формы. Отрубишь ногу — он падает на колено.",
			"Береги голову, ученик. Он бьёт как падающее дерево."],
		"outro": ["Громила пал! Кааа! Мост ещё стоит — почти весь.",
			"Ночью я видел над святилищем красные нити. Кто-то плетёт паутину вокруг деревни."],
		"reward": [180, 3]},
	{"name": "Красные нити", "sub": "в бамбуковой роще поют", "time": "night",
		"place": Vector3(-32, 0, 26), "start": Vector3(-14, 0, 18), "where": "Бамбуковая роща",
		"waves": [[["weaver", -34, 30], ["low", -28, 22], ["low", -38, 22]], [["weaver", -26, 32], ["weaver", -40, 30]]],
		"brief": ["Кааа! В бамбуковой роще женский голос поёт по ночам. Люди идут на песню и не возвращаются.",
			"Это кровавая ткачиха. Держит дистанцию и сыплет копьями — сокращай расстояние рывком!",
			"Их там больше одной. Кааа… будь быстрым."],
		"outro": ["Нити порваны! Последняя ткачиха шептала имя: Кагэцу.",
			"Кагэцу — Третья Ущербная луна. Он ждёт тебя у святилища. Готовься, кааа."],
		"reward": [220, 4]},
	{"name": "Третья Ущербная луна", "sub": "Кагэцу ждёт у святилища", "time": "night",
		"place": Vector3(0, 0, -58), "start": Vector3(0, 0, -42), "where": "Святилище Кумо",
		"waves": [[["low", -6, -58], ["low", 6, -58], ["low", 0, -50]], [["boss", 0, -62]]],
		"brief": ["Кааа… это он. Кагэцу, Третья Ущербная луна. Вся эта нечисть служила ему.",
			"Его шея срастается после удара. Руби снова и снова, пока не рассыплется.",
			"Он исчезает и выходит из тени за спиной. Когда небо краснеет — беги из круга копий.",
			"Гэнсай сказал: «Дыши. Не думай о страхе — думай о следующем шаге». Кааа. Удачи."],
		"outro": [],
		"reward": [400, 5]},
]

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	G.story = self

# ---------------------------------------------------------------------
# Запуск
func _reset_view() -> void:
	fade = 0.0
	fade_to = 0.0
	card_t = 0.0
	G.cutscene = false
	if G.dialog_ui and G.dialog_ui.open:
		G.dialog_ui.close()
	_clear_demons()

func new_game() -> void:
	_reset_view()
	for k in ["ryo", "mastery", "hp", "lungs", "focus", "blade", "chapter"]:
		G.prog[k] = 0
	G.prog.trial = -1
	G.prog.finished = false
	G.prog.started = true
	G.save_prog()
	G.mode = "story"
	apply_progress()
	_spawn_npcs()
	_clear_demons()
	chapter = 0
	_intro()

func continue_game() -> void:
	_reset_view()
	G.mode = "story"
	apply_progress()
	_spawn_npcs()
	_clear_demons()
	chapter = int(G.prog.chapter)
	if bool(G.prog.finished):
		_free_roam()
	elif chapter == 0:
		_intro()
	else:
		_day()

func free_hunt() -> void:
	_reset_view()
	G.mode = "free"
	apply_progress()
	_spawn_npcs()
	phase = "free"
	objective = "Свободная охота: демоны приходят один за другим. Заказы — у ворона в деревне"
	target = null
	crow.has_news = true

func has_save() -> bool:
	return bool(G.prog.started)

# Ранг: до Отбора — ученик, после — ступени с десятой вверх (глава → ступень).
func rank_name() -> String:
	var ch := int(G.prog.chapter)
	if ch < 2:
		return "ученик"
	return RANKS[clampi(ch - 2, 0, RANKS.size() - 1)]

# Прокачка → герой.
func apply_progress() -> void:
	var p = G.player
	if p == null:
		return
	p.max_hp = 100.0 + 20.0 * float(G.prog.hp)
	p.max_breath = 100.0 + 20.0 * float(G.prog.lungs)
	p.hp = p.max_hp
	p.breath = p.max_breath

# ---------------------------------------------------------------------
# Жители
func _spawn_npcs() -> void:
	if not npcs.is_empty():
		return
	var spots := {
		"gensai": [Vector3(5, 0, 9), atan2(-5.0, -9.0)],
		"tetsu": [Vector3(37.2, 0, -32.5), -PI * 0.5],
		"elder": [Vector3(29.5, 0, -17), PI * 0.5],
		"okiku": [Vector3(28.8, 0, -32.5), PI * 0.5],
		"taro": [Vector3(33.5, 0, -45), PI],
		"crow": [Vector3(30.6, 0, -1.5), PI * 0.8],
	}
	for id in spots:
		var n = StaticBody3D.new()
		n.set_script(Npc)
		var pos: Vector3 = spots[id][0]
		pos.y = G.world.height_at(pos.x, pos.z) if G.world.has_method("height_at") else 0.0
		n.setup(id, NAMES[id], LOOK[id], pos, spots[id][1])
		G.world.add_child(n)
		npcs[id] = n
	crow = npcs.crow

func _process(_dt: float) -> void:
	var dt: float = G.rdt
	fade = move_toward(fade, fade_to, dt * 1.6)
	card_t = maxf(0.0, card_t - dt)
	if G.player == null or not G.started:
		return
	var p: Node3D = G.player
	# ближайший житель — подсказка «E — поговорить»
	near = null
	if not G.dialog and phase in ["day", "tutorial", "free", "go", "trial"] and not _enemies_near():
		var bd := 2.8
		for id in npcs:
			var n: Node3D = npcs[id]
			if not n.visible:
				continue
			var d: float = n.global_position.distance_to(p.global_position)
			if d < bd:
				bd = d
				near = n
	match phase:
		"tutorial":
			_tutorial_tick()
		"go":
			if target != null and Vector2(p.global_position.x - target.x, p.global_position.z - target.z).length() < 9.0:
				_start_fight()
		"fight":
			_fight_tick(dt)
		"trial":
			_trial_tick(dt)
		"done":
			done_t -= dt
			if done_t <= 0.0:
				done_t = 99.0
				_chapter_outro()
	if crow and phase in ["go", "fight"] and not crow.flying:
		# ворон кружит над героем во время охоты
		var a := G.real_time * 0.8
		crow.fly(p.global_position + Vector3(cos(a) * 5.0, 7.0, sin(a) * 5.0))

func _enemies_near() -> bool:
	for e in G.enemies:
		if is_instance_valid(e) and not e.is_dead() and e.global_position.distance_to(G.player.global_position) < 20.0:
			return true
	return false

# E рядом с жителем.
func try_talk() -> bool:
	if near == null or G.dialog:
		return false
	talk(near.id)
	return true

func _line(id: String, txt: String) -> Array:
	return [NAMES.get(id, id), txt, LOOK.get(id, HERO)]

func _say(id: String, texts: Array, choices: Array = [], cb := Callable(), done := Callable()) -> void:
	var ls: Array = []
	for t in texts:
		if t is Array:
			ls.append(_line(t[0], t[1]))
		else:
			ls.append(_line(id, t))
	if npcs.has(id):
		npcs[id].talking = true
	var stop := func():
		if npcs.has(id):
			npcs[id].talking = false
	var on_pick := func(i: int) -> void:
		stop.call()
		if cb.is_valid():
			cb.call(i)
	var on_end := func() -> void:
		stop.call()
		if done.is_valid():
			done.call()
	G.dialog_ui.say(ls, choices, on_pick, on_end)

func talk(id: String) -> void:
	if G.sfx and id == "crow":
		G.sfx.play("caw", -6.0)
	match id:
		"crow":
			_talk_crow()
		"gensai":
			_talk_gensai()
		"tetsu":
			_talk_tetsu()
		"elder":
			_say("elder", [_elder_line()])
		"okiku":
			_say("okiku", [_okiku_line()])
		"taro":
			_say("taro", [_taro_line()])

# Текущее задание: глава сюжета или охота на заказ.
var cur: Dictionary = {}
func _cur() -> Dictionary:
	if not cur.is_empty():
		return cur
	return CH[chapter] if chapter < CH.size() else {}

# Охота на заказ (после сюжета и в свободной охоте): случайное место и стая,
# с каждой охотой — сильнее и богаче.
var pending: Dictionary = {}
func _make_contract() -> Dictionary:
	var src: Dictionary = CH[1 + randi() % (CH.size() - 2)]
	var n := int(G.prog.get("hunts", 0))
	var pts: Array = []
	for w in src.waves:
		for sp in w:
			pts.append(Vector2(sp[1], sp[2]))
	var pick := func() -> Vector2:
		var v: Vector2 = pts[randi() % pts.size()]
		return v + Vector2(randf_range(-3, 3), randf_range(-3, 3))
	var waves: Array = []
	var nw := 2 if n < 3 else 3
	for wi in nw:
		var w2: Array = []
		var last := wi == nw - 1
		var lows := mini(2 + n / 2, 5) - (2 if last else 0)
		for k in maxi(lows, 0):
			var q: Vector2 = pick.call()
			w2.append(["low", q.x, q.y])
		if last:
			var strong := ["hermit", "weaver", "brute"]
			for k in (1 if n < 4 else 2):
				var q2: Vector2 = pick.call()
				w2.append([strong[randi() % strong.size()], q2.x, q2.y])
			if n >= 6 and randf() < 0.35:
				var q3: Vector2 = pick.call()
				w2.append(["boss", q3.x, q3.y])
		waves.append(w2)
	return {"name": "Охота на заказ", "where": src.where, "place": src.place, "start": src.start, "time": "night",
		"waves": waves, "reward": [80 + n * 20, 2 + n / 3], "contract": true}

func _talk_crow() -> void:
	if phase == "free":
		pending = _make_contract()
		var hn := int(G.prog.get("hunts", 0))
		_say("crow", ["Кааа! Есть заказ: %s. Стая низших и кто-то покрупнее. Награда — %d рё." % [pending.where, pending.reward[0]],
			"Охот на заказ выполнено: %d. Каждая следующая — злее. Кааа!" % hn],
			["Беру заказ — пусть наступит ночь", "Не сейчас"], _contract_pick)
		return
	if phase == "day" and chapter < CH.size():
		var c: Dictionary = CH[chapter]
		_say("crow", c.brief, ["В путь — пусть наступит ночь", "Позже, ещё не готов"], _crow_pick)
	elif phase == "go" or phase == "fight":
		_say("crow", ["Кааа! Место отмечено на карте — ромб и стрелка. Беги туда!"])
	else:
		_say("crow", ["Кааа?"])

func _crow_pick(i: int) -> void:
	if i == 0:
		_go()

func _contract_pick(i: int) -> void:
	if i == 0:
		cur = pending
		_clear_demons(true)
		_go()

func _upgrade_text() -> Array:
	var pr: Dictionary = G.prog
	return [
		"Выносливость: +20 здоровья (ур. %d/5) — %s" % [pr.hp, _cost_txt(pr.hp, 5)],
		"Лёгкие: +20 дыхания (ур. %d/5) — %s" % [pr.lungs, _cost_txt(pr.lungs, 5)],
		"Концентрация: дыхание восстанавливается быстрее (ур. %d/3) — %s" % [pr.focus, _cost_txt(pr.focus, 3)],
		"Хватит на сегодня",
	]

func _cost_txt(lv: int, mx: int) -> String:
	return "предел" if lv >= mx else "%d мастерства" % (lv + 1)

func _talk_gensai() -> void:
	if phase == "tutorial":
		_say("gensai", [_tut_hint()])
		return
	var lines := ["Ты пришёл учиться или языком чесать? Мастерство у тебя: %d." % int(G.prog.mastery)]
	var trial_ok := int(G.prog.get("trial", -1)) != chapter and phase in ["day", "free"]
	_say("gensai", lines, ["Тренироваться", "Испытание: 6 чучел за 25 секунд (+2 мастерства)" if trial_ok else "Испытание уже пройдено — приходи после охоты",
		"Расскажи о демонах", "Ничего, наставник"], _gensai_pick)

func _gensai_pick(i: int) -> void:
	if i == 0:
		_train_menu()
	elif i == 1:
		if int(G.prog.get("trial", -1)) != chapter and phase in ["day", "free"]:
			_say("gensai", ["Чучела вокруг поляны. Шесть штук. Двадцать пять ударов сердца. Пошёл!"], [], Callable(), _start_trial)
		else:
			_say("gensai", ["Сегодня хватит. Тело должно запомнить, а не сломаться."])
	elif i == 2:
		_say("gensai", _gensai_lore())

func _train_menu() -> void:
	_say("gensai", ["Выбирай. Каждая ступень тяжелее прошлой. (мастерство: %d)" % int(G.prog.mastery)], _upgrade_text(), _train_pick)

func _train_pick(i: int) -> void:
	var keys := ["hp", "lungs", "focus"]
	if i >= 3:
		return
	var k: String = keys[i]
	var mx := 3 if k == "focus" else 5
	var lv := int(G.prog[k])
	if lv >= mx:
		_say("gensai", ["Тут ты уже упёрся в предел. Остальное — только в бою."])
		return
	if int(G.prog.mastery) < lv + 1:
		_say("gensai", ["Мастерства мало. Руби демонов, потом приходи."])
		return
	G.prog.mastery = int(G.prog.mastery) - (lv + 1)
	G.prog[k] = lv + 1
	G.save_prog()
	apply_progress()
	if G.sfx:
		G.sfx.play("chime", -6.0)
	_say("gensai", [["gensai", ["Ещё. Дыши глубже. Глубже! …Вот. Теперь ты чуть меньше бесполезен.",
		"Сто взмахов до заката. Без жалоб.", "Хорошо. Тело запомнит раньше головы."][randi() % 3]]], [], Callable(), _train_menu)

func _gensai_lore() -> Array:
	var all := [
		"Демона не убить обычной раной. Руки отрастут, кишки зарастут. Только голова — когда шея открыта.",
		"Слабые демоны ходят стаей. Сильные — в одиночку и с кровавым искусством.",
		"Ущербные луны — шесть демонов, что служат самому древнему из них. Каждый стоит сотни низших.",
		"Дыхание — не воздух, а ритм. Поймаешь ритм — клинок станет водой, огнём или громом.",
		"Клинок в ножнах быстрее, чем кажется. Первый удар из ножен — самый честный.",
	]
	return [all[randi() % all.size()], all[(randi() + 2) % all.size()]]

func _talk_tetsu() -> void:
	var lv := int(G.prog.blade)
	var cost := 80 * (lv + 1)
	var ch := ["Закалить клинок: +10%% урона (ур. %d/5) — %s" % [lv, "предел" if lv >= 5 else "%d рё" % cost], "Как выбрать клинок?", "Ничего"]
	_say("tetsu", ["Хм. Клинок принёс? Покажи. …Зазубрина на зазубрине. У тебя %d рё." % int(G.prog.ryo)], ch, _tetsu_pick)

func _tetsu_pick(i: int) -> void:
	var lv := int(G.prog.blade)
	var cost := 80 * (lv + 1)
	if i == 0:
		if lv >= 5:
			_say("tetsu", ["Лучше уже не будет. Это лучший клинок, что я ковал."])
		elif int(G.prog.ryo) < cost:
			_say("tetsu", ["Сталь стоит денег, парень. Приходи с %d рё." % cost])
		else:
			G.prog.ryo = int(G.prog.ryo) - cost
			G.prog.blade = lv + 1
			G.save_prog()
			if G.sfx:
				G.sfx.play("clang", -4.0, 1.2)
			_say("tetsu", ["*звон молота* …Держи. Режет как надо. Не урони."])
	elif i == 1:
		_say("tetsu", ["Клинок, ножны, цвет стали — всё в паузе, раздел «Клинок». Катаны, парные на цепи, хлыст, нагината, шар на цепи.",
			"А дыхание — в «Снаряжении». Вода течёт, пламя давит, гром бьёт издалека. Пробуй."])

func _elder_line() -> String:
	var ls := [
		"Ивакура стоит у гор триста лет. Демоны приходили и раньше… но не столько.",
		"С улицы фонарей пропадали люди. Если бы не охотники — некому было бы зажигать фонари.",
		"Кедры у святилища старше деревни. Говорят, на верхних ветках видно море.",
		"Пруд Цукими назван в честь луны. Теперь там ловят рыбу только днём.",
		"Бамбуковая роща поёт на ветру. Но то, что пело там ночью, — не ветер.",
		"Кагэцу… это имя шептали ещё мои деды. Если ты его одолеешь — Ивакура будет помнить тебя.",
		"Ты спас нас, охотник. Пей чай, отдыхай. Фонари горят снова.",
	]
	return ls[clampi(chapter, 0, ls.size() - 1)]

func _okiku_line() -> String:
	var ls := ["Ой! Вы ученик Гэнсая-сама? Возьмите рисовый колобок — на дорогу.",
		"Муж говорит, по ночам за ставнями кто-то скребётся. Вы ведь разберётесь?",
		"Спасибо вам! Сегодня я снова пеку для всей улицы.",
		"Рыбаки не ходят на пруд. Цены на рыбу — ужас!",
		"Песню из рощи слышала моя сестра. Она с тех пор не спит… Пожалуйста, поторопитесь.",
		"Говорят, вы идёте к святилищу. Возьмите оберег. Сама шила."]
	return ls[clampi(chapter, 0, ls.size() - 1)]

func _taro_line() -> String:
	var ls := ["Когда вырасту — тоже буду охотником! Покажи рывок! Ну покажи!",
		"А правда, что у демонов отрастают руки? Фууу!",
		"Я видел, как ты прыгал по крышам! Научи!",
		"Мама не пускает меня к пруду. Это из-за громилы, да?",
		"Я сплёл себе хаори из маминого платка. Похоже?",
		"Ворон Кагари сказал, что ты победишь. Вороны не врут!"]
	return ls[clampi(chapter, 0, ls.size() - 1)]

# ---------------------------------------------------------------------
# Испытание наставника: разрубить чучела на время
var trial_left := 0.0
var trial_dummies: Array = []
var trial_prev := ""
var trial_obj_prev := ""

func _start_trial() -> void:
	trial_prev = phase
	trial_obj_prev = objective
	phase = "trial"
	trial_left = 25.0
	trial_dummies.clear()
	var c := Vector3(0, 0, 2)
	for i in 6:
		var a := TAU * i / 6.0 + randf_range(-0.3, 0.3)
		var r := randf_range(6.0, 11.0)
		var pos := _ground(c + Vector3(cos(a) * r, 0, sin(a) * r))
		trial_dummies.append(_dummy(pos))
	G.sfx.play("gong", -10.0, 1.4)
	target = null

func _dummy(pos: Vector3) -> Node3D:
	var b = StaticBody3D.new()
	b.set_script(load("res://scripts/breakable.gd"))
	b.position = pos
	G.world.add_child(b)
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = Vector3(0.5, 1.7, 0.5)
	cs.shape = sh
	cs.position = Vector3(0, 0.85, 0)
	b.add_child(cs)
	var straw := Color(0.86, 0.72, 0.4)
	var V = load("res://scripts/vox.gd")
	V.box(b, Vector3(0.12, 1.7, 0.12), Vector3(0, 0.85, 0), Color(0.45, 0.32, 0.2), true, 0.0, "wood")
	V.box(b, Vector3(0.46, 0.7, 0.36), Vector3(0, 1.05, 0), straw, true, 0.0, "cloth")
	V.box(b, Vector3(0.9, 0.1, 0.1), Vector3(0, 1.3, 0), Color(0.45, 0.32, 0.2), true, 0.0, "wood")
	V.box(b, Vector3(0.3, 0.3, 0.3), Vector3(0, 1.62, 0), Color(0.92, 0.88, 0.75), true, 0.0, "cloth")
	V.box(b, Vector3(0.5, 0.06, 0.38), Vector3(0, 0.95, 0), Color(0.6, 0.2, 0.15))
	b.brad = 0.8
	b.col = straw
	b.pieces = 8
	b.piece_size = 0.22
	b.height = 1.7
	return b

func _trial_tick(dt: float) -> void:
	trial_left -= dt
	var left := 0
	for d in trial_dummies:
		if is_instance_valid(d) and d.is_inside_tree():
			left += 1
	objective = "Испытание: чучела %d/6 · %d с" % [6 - left, int(ceil(maxf(0.0, trial_left)))]
	if left == 0:
		phase = trial_prev
		objective = trial_obj_prev
		G.prog.trial = chapter
		G.prog.mastery = int(G.prog.mastery) + 2
		G.save_prog()
		G.sfx.play("chime", -4.0)
		G.hud.big_text("ИСПЫТАНИЕ ПРОЙДЕНО")
		G.hud.notify("+2 мастерства", 3.0)
		_say("gensai", ["…%d секунд в запасе. Я в твои годы был медленнее. Не зазнавайся." % int(trial_left)])
	elif trial_left <= 0.0:
		for d in trial_dummies:
			if is_instance_valid(d):
				d.queue_free()
		trial_dummies.clear()
		phase = trial_prev
		objective = trial_obj_prev
		G.hud.notify("Время вышло", 2.5)
		_say("gensai", ["Медленно. Демон бы уже съел тебя и закусил мной. Ещё раз — когда отдышишься."])

# ---------------------------------------------------------------------
# Пролог: титры и обучение у наставника
func _intro() -> void:
	phase = "intro"
	G.cutscene = true
	fade = 1.0
	fade_to = 1.0
	_set_time("sunset")
	# герой лицом к наставнику — камера за спиной, Гэнсай в кадре
	_place(Vector3(2.5, 0, 3.0), atan2(2.5, 6.0))
	var cards := [
		["Горная провинция Кумо", "начало эпохи Тайсё"],
		["Ночами из лесов приходят демоны", "их не берёт обычная сталь"],
		["Старый охотник Гэнсай взял ученика", "сегодня — последний урок"],
	]
	for c in cards:
		_card(c[0], c[1], 3.2)
		await _w(3.4)
	fade_to = 0.0
	G.cutscene = false
	_card("Пролог", "Ученик", 3.0, true)
	await _w(1.2)
	_say("gensai", [
		"Опоздал. Солнце уже садится, а ты только глаза продрал.",
		"Сегодня последний урок. Потом — Отбор, и я тебе больше не нянька.",
		"Слушай и делай. Говорю один раз."], [], Callable(), _begin_tutorial)

func _begin_tutorial() -> void:
	phase = "tutorial"
	tut_step = 0
	tut_attacks = 0
	_tut_objective()

const TUT := [
	["Достань клинок — F (или ЛКМ: удар из ножен)", "Клинок — из ножен. Медленно, как я учил. Или сразу ударом — так быстрее."],
	["Рывок — Shift", "Ноги — твоя жизнь. Рывок: Shift. Пока летишь — тебя не задеть."],
	["Серия ударов — ЛКМ три раза", "Теперь руби. Три удара подряд, не останавливайся."],
	["Форма дыхания — 1", "Вдох — и форма. Клавиша 1. Почувствуй, как воздух становится клинком."],
	["Парирование — Q", "Демон замахнулся — Q. Поймаешь миг, когда сверкнут когти, — мир замрёт."],
]

func _tut_objective() -> void:
	if tut_step < TUT.size():
		objective = TUT[tut_step][0]
		target = null
		npcs.gensai.has_news = false

func _tut_hint() -> String:
	return TUT[tut_step][1] if tut_step < TUT.size() else "Хватит болтать. Смотри в лес."

func _tutorial_tick() -> void:
	var p = G.player
	var st: String = p.state
	var ok := false
	match tut_step:
		0:
			ok = p.drawn
		1:
			ok = st == "dash"
		2:
			# каждый новый удар серии — смена атаки (или вход в атаку)
			if st == "attack" and (_last_state != "attack" or p.atk_name != _last_atk):
				tut_attacks += 1
			_last_atk = p.atk_name
			ok = tut_attacks >= 3
		3:
			ok = st == "attack" and bool(p.atk.get("form", false))
		4:
			ok = st == "parry"
	_last_state = st
	if ok:
		tut_step += 1
		if G.sfx:
			G.sfx.play("chime", -10.0, 1.3)
		if tut_step < TUT.size():
			_tut_objective()
			G.hud.notify("Хорошо. Дальше.", 1.6)
			_say("gensai", [TUT[tut_step][1]])
		else:
			phase = "intro"
			objective = ""
			_prologue_night()
var _last_atk := ""

func _prologue_night() -> void:
	_say("gensai", ["…Сносно. Для ученика.", "Тише. Солнце село. Чуешь? Гнилая кровь.", "Это твой первый. Я смотрю. Голову — с плеч, когда шея откроется."], [], Callable(), _first_demon)

func _first_demon() -> void:
	_set_time("night")
	G.sfx.play("gong", -6.0)
	_start_waves([[["low", -2, -10]]], Vector3(2, 0, 4))

# ---------------------------------------------------------------------
# День в деревне
func _day() -> void:
	phase = "day"
	_villagers(true)
	G.cutscene = false
	_set_time("day")
	_clear_demons()
	_place(Vector3(32, 0, 2), PI)
	for id in npcs:
		npcs[id].has_news = false
	crow.flying = false
	crow.model.position = Vector3(0, 1.25, 0)
	crow.model.rotation = Vector3.ZERO
	crow.has_news = true
	if chapter < CH.size():
		objective = "Ворон Кагари ждёт у входа в деревню — поговори (E)"
	target = crow.home
	var c: Dictionary = CH[chapter]
	_card("Глава %d" % chapter, c.name, 3.2, true)

# Ночью жители прячутся по домам (остаётся только ворон), днём — выходят.
func _villagers(on: bool) -> void:
	for id in npcs:
		if id == "crow":
			continue
		var n: Node3D = npcs[id]
		n.visible = on
		n.process_mode = Node.PROCESS_MODE_INHERIT if on else Node.PROCESS_MODE_DISABLED
		n.collision_layer = 1 if on else 0

func _go() -> void:
	var c: Dictionary = _cur()
	target = c.place
	phase = "go"
	crow.has_news = false
	fade_to = 1.0
	G.cutscene = true
	await _w(0.8)
	_set_time(c.time)
	_villagers(false)
	fade_to = 0.0
	G.cutscene = false
	G.sfx.play("caw", -8.0, 0.9)
	objective = "Иди к месту: %s (метка на карте)" % c.where
	target = c.place
	G.player.spawn_pos = _ground(c.start)

func _start_fight() -> void:
	var c: Dictionary = _cur()
	_start_waves(c.waves, c.start)
	G.sfx.play("gong", -8.0, 0.8)

func _start_waves(waves: Array, start: Vector3) -> void:
	phase = "fight"
	wave = 0
	kills_ch = 0
	G.player.spawn_pos = _ground(start)
	_cur_waves = waves
	_spawn_wave()
var _cur_waves: Array = []

func _spawn_wave() -> void:
	alive.clear()
	var w: Array = _cur_waves[wave]
	for sp in w:
		var d = CharacterBody3D.new()
		d.set_script(Demon)
		d.kind = sp[0]
		G.world.add_child(d)
		d.global_position = _ground(Vector3(sp[1], 0, sp[2])) + Vector3.UP * 0.5
		d.facing = randf() * TAU
		alive.append(d)
		G.fx.burst(d.global_position + Vector3.UP, Color(0.35, 0.02, 0.08), 16, 4.0, 0.18, 0.5, -1.0)
	wave_total = alive.size()
	target = null
	for d in alive:
		if d.kind == "boss":
			# выход Тени: титр, замедление, гонг
			_card("Кагэцу", "Третья Ущербная луна", 3.4, true)
			G.slowmo(0.4, 1.2)
			G.add_shake(0.5)
		elif d.kind in ["brute", "weaver", "hermit"] and G.hud:
			G.hud.intro_seen.erase(d.name_ru)
	_fight_objective()
	if _cur_waves.size() > 1:
		G.hud.notify("Волна %d из %d" % [wave + 1, _cur_waves.size()], 2.0)

func _fight_objective() -> void:
	var left := 0
	for d in alive:
		if is_instance_valid(d) and not d.is_dead():
			left += 1
	var c: Dictionary = _cur()
	if chapter == 0 and cur.is_empty():
		objective = "Убей демона. Когда шея откроется — ЛКМ"
	else:
		objective = "%s: демоны %d/%d%s" % [c.get("where", ""), wave_total - left, wave_total,
			"  · волна %d/%d" % [wave + 1, _cur_waves.size()] if _cur_waves.size() > 1 else ""]

func _fight_tick(dt: float) -> void:
	for i in range(alive.size() - 1, -1, -1):
		if not is_instance_valid(alive[i]) or alive[i].is_dead():
			alive.remove_at(i)
	_fight_objective()
	if alive.is_empty():
		if wave_wait < 0.0:
			wave_wait = 0.2 if fast else 2.5
		wave_wait -= dt
		if wave_wait <= 0.0:
			wave_wait = -1.0
			wave += 1
			if wave < _cur_waves.size():
				_spawn_wave()
				G.sfx.play("roar", -10.0, 0.9)
			else:
				_complete()

func on_demon_killed(d) -> void:
	kills_ch += 1
	var rw: int = int(d.T.get("reward", 10))
	G.prog.ryo = int(G.prog.ryo) + rw
	if d.kind != "low":
		G.prog.mastery = int(G.prog.mastery) + 1
	if G.hud:
		G.hud.notify("+%d рё%s" % [rw, "  +1 мастерство" if d.kind != "low" else ""], 1.8)

func _complete() -> void:
	phase = "done"
	_clear_demons(true)
	objective = ""
	var c: Dictionary = _cur()
	if chapter == 0 and cur.is_empty():
		G.hud.big_text("ПЕРВЫЙ ДЕМОН")
		G.prog.mastery = int(G.prog.mastery) + 1
	else:
		var rw: Array = c.reward
		G.prog.ryo = int(G.prog.ryo) + rw[0]
		G.prog.mastery = int(G.prog.mastery) + rw[1]
		G.hud.big_text("ОХОТА ЗАВЕРШЕНА")
		G.hud.notify("Награда: %d рё, %d мастерства" % [rw[0], rw[1]], 4.0)
	G.sfx.play("chime", -4.0)
	G.save_prog()
	done_t = 0.2 if fast else 3.5

func _chapter_outro() -> void:
	if not cur.is_empty():
		G.prog.hunts = int(G.prog.get("hunts", 0)) + 1
		G.save_prog()
		crow.fly(G.player.global_position + Vector3(1.2, 1.6, 1.2))
		_say("crow", ["Кааа! Заказ выполнен! Деревня спит спокойно.", "Возвращайся к столбу — будут ещё."], [], Callable(), _end_contract)
		return
	if chapter == 0:
		_say("gensai", ["Неплохо. Голова отдельно, ты цел. Для первого раза — сойдёт.",
			"Отдохни. Завтра ночью — Отбор. Мой ворон Кагари найдёт тебя в деревне.",
			"И… молодец, ученик."], [], Callable(), _next_chapter)
	elif chapter == CH.size() - 1:
		_ending()
	else:
		var c: Dictionary = CH[chapter]
		crow.fly(G.player.global_position + Vector3(1.2, 1.6, 1.2))
		_say("crow", c.outro, [], Callable(), _next_chapter)

func _next_chapter() -> void:
	fade_to = 1.0
	G.cutscene = true
	await _w(1.0)
	chapter += 1
	G.prog.chapter = chapter
	G.save_prog()
	G.player.hp = G.player.max_hp
	G.player.breath = G.player.max_breath
	fade_to = 0.0
	_day()
	if chapter == 2:
		G.hud.notify("Ранг: %s" % rank_name(), 3.0)

# Гибель в бою: волна заново, герой — у начала места.
func on_player_respawn() -> void:
	if phase != "fight":
		return
	for d in alive:
		if is_instance_valid(d):
			d.queue_free()
	alive.clear()
	for e in G.enemies.duplicate():
		if is_instance_valid(e) and not e.is_dead():
			e.queue_free()
	await _w(0.3)
	if phase == "fight":
		_spawn_wave()
		G.hud.notify("Волна начинается заново", 2.0)

# ---------------------------------------------------------------------
# Финал
func _ending() -> void:
	phase = "ending"
	G.prog.finished = true
	G.prog.chapter = CH.size()
	G.save_prog()
	await _w(1.0)
	_say("gensai", [
		["crow", "КААА! Он рассыпался! Кагэцу рассыпался в пепел!"],
		"…Слышу. Не ори, птица.",
		"Ты сделал то, что я не смог двадцать лет назад, ученик. Нет — охотник.",
		"Но Кагэцу был лишь третьим. Над ним — ещё двое Ущербных, и шесть Полных лун.",
		"Отдохни до рассвета. Потом — дорога. Горы в тумане ждут."], [], Callable(), _credits)

func _credits() -> void:
	fade_to = 1.0
	G.cutscene = true
	await _w(1.2)
	_set_time("day")
	_place(Vector3(32, 0, 2), PI)
	var cards := [
		["Рассвет над Ивакурой", "фонари гаснут — впервые не от страха"],
		["Клинок и Демон", "глава первая окончена"],
		["Игра сделана для Tsenze", "код, модели, звук и музыка — собраны кодом"],
		["Продолжение следует", "Горы в тумане · Полные луны · Путь демона"],
	]
	for c in cards:
		_card(c[0], c[1], 3.6)
		await _w(3.8)
	fade_to = 0.0
	G.cutscene = false
	_free_roam()

func _end_contract() -> void:
	fade_to = 1.0
	G.cutscene = true
	await _w(1.0)
	cur = {}
	_set_time("day")
	_villagers(true)
	_place(Vector3(32, 0, 2), PI)
	crow.flying = false
	crow.model.position = Vector3(0, 1.25, 0)
	crow.model.rotation = Vector3.ZERO
	fade_to = 0.0
	G.cutscene = false
	G.player.hp = G.player.max_hp
	phase = "free"
	objective = "Свободная охота. Ворон Кагари даёт заказы. Ранг: %s" % rank_name()
	target = null
	if crow:
		crow.has_news = true

func _free_roam() -> void:
	phase = "free"
	G.mode = "free"
	objective = "Свободная охота. Ворон Кагари в деревне. Ранг: %s" % rank_name()
	target = null
	if crow:
		crow.has_news = true
	_set_time("night")

# ---------------------------------------------------------------------
# Вспомогательное
func _clear_demons(ash := false) -> void:
	if G.hud:
		G.hud.intro_t = 0.0
	for e in G.enemies.duplicate():
		if is_instance_valid(e) and not e.is_dead():
			if ash:
				G.fx.ash(e.global_position + Vector3.UP, 20)
			e.queue_free()
	alive.clear()

func _ground(v: Vector3) -> Vector3:
	var h: float = G.world.height_at(v.x, v.z) if G.world and G.world.has_method("height_at") else 0.0
	return Vector3(v.x, h + 0.1, v.z)

func _place(pos: Vector3, face: float) -> void:
	var p = G.player
	p.global_position = _ground(pos) + Vector3.UP * 0.4
	p.velocity = Vector3.ZERO
	p.facing = face
	p.spawn_pos = p.global_position
	if G.cam_rig:
		G.cam_rig.yaw = atan2(-sin(face), -cos(face))

func _set_time(t: String) -> void:
	if G.world and G.world.has_method("set_time"):
		G.world.set_time(t)

func _card(title: String, sub: String, t: float, gong := false) -> void:
	card = title
	card_sub = sub
	card_t = t
	if gong and G.sfx:
		G.sfx.play("gong", -8.0)

var fast := false            # автотест: паузы сценок в 20 раз короче
func _w(t: float) -> void:
	await get_tree().create_timer(t * (0.05 if fast else 1.0), true, false, true).timeout
