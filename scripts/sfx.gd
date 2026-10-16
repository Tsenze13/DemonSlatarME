extends Node
# Звуки, синтезированные кодом при запуске: свист клинка, удар, звон
# парирования, грохот, рык демона, «шинг» добивания.

const RATE := 22050
var sounds := {}
var players: Array = []
var _next := 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in 14:
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		players.append(p)
	sounds["whoosh"] = _make(0.22, _whoosh)
	sounds["whoosh_big"] = _make(0.42, _whoosh_big)
	sounds["hit"] = _make(0.2, _hit)
	sounds["hit_heavy"] = _make(0.35, _hit_heavy)
	sounds["clang"] = _make(0.7, _clang)
	sounds["boom"] = _make(0.8, _boom)
	sounds["roar"] = _make(1.1, _roar)
	sounds["shing"] = _make(0.9, _shing)
	sounds["dash"] = _make(0.16, _dash)
	sounds["jump"] = _make(0.12, _jump)
	sounds["water"] = _make(0.6, _water)
	sounds["crack"] = _make(0.4, _crack)
	sounds["hurt"] = _make(0.25, _hurt)
	sounds["sonic"] = _make(0.9, _sonic)
	sounds["draw"] = _make(0.5, _draw)
	sounds["sheathe"] = _make(0.35, _sheathe)
	sounds["step_dirt"] = _make(0.12, _step_dirt)
	sounds["step_grass"] = _make(0.16, _step_grass)
	sounds["land"] = _make(0.3, _land)
	sounds["fire"] = _make(0.7, _fire)
	sounds["thunder"] = _make(0.9, _thunder)
	# попадания по материалам
	sounds["flesh"] = _make(0.28, _flesh)
	sounds["wood"] = _make(0.35, _wood)
	sounds["stone"] = _make(0.45, _stone)
	sounds["snap"] = _make(0.18, _snap)
	sounds["tick"] = _make(0.05, _tick)
	sounds["chime"] = _make(1.4, _chime)
	sounds["gong"] = _make(2.2, _gong)
	sounds["caw"] = _make(0.45, _caw)

func play(nm: String, vol_db := 0.0, pitch := 1.0, rnd := 0.08) -> void:
	if not sounds.has(nm):
		return
	var p: AudioStreamPlayer = players[_next]
	_next = (_next + 1) % players.size()
	p.stream = sounds[nm]
	p.volume_db = vol_db
	p.pitch_scale = pitch * (1.0 + randf_range(-rnd, rnd))
	p.play()

func _make(dur: float, gen: Callable) -> AudioStreamWAV:
	var n := int(dur * RATE)
	var data := PackedByteArray()
	data.resize(n * 2)
	var state := {"lp": 0.0, "lp2": 0.0, "ph": 0.0, "ph2": 0.0}
	for i in n:
		var t := float(i) / RATE
		var v: float = gen.call(t, dur, state)
		var s := int(clampf(v, -1.0, 1.0) * 32000.0)
		data.encode_s16(i * 2, s)
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = data
	return w

func _lp(st: Dictionary, key: String, x: float, a: float) -> float:
	st[key] = st[key] + (x - st[key]) * a
	return st[key]

func _whoosh(t: float, d: float, st: Dictionary) -> float:
	var env := minf(t / 0.04, 1.0) * pow(1.0 - t / d, 2.0)
	var cut := 0.05 + 0.35 * sin(PI * t / d)
	return _lp(st, "lp", randf_range(-1, 1), cut) * env * 1.6

func _whoosh_big(t: float, d: float, st: Dictionary) -> float:
	var env := minf(t / 0.06, 1.0) * pow(1.0 - t / d, 1.5)
	var cut := 0.03 + 0.25 * sin(PI * t / d)
	var n := _lp(st, "lp", randf_range(-1, 1), cut)
	st["ph"] += TAU * (180.0 - 90.0 * t / d) / RATE
	return (n * 1.5 + sin(st["ph"]) * 0.25) * env

func _hit(t: float, d: float, st: Dictionary) -> float:
	var env := exp(-t * 22.0)
	st["ph"] += TAU * (140.0 * exp(-t * 8.0) + 40.0) / RATE
	var n := randf_range(-1, 1) * exp(-t * 60.0)
	return (sin(st["ph"]) * 0.9 * env + n * 0.6)

func _hit_heavy(t: float, d: float, st: Dictionary) -> float:
	var env := exp(-t * 11.0)
	st["ph"] += TAU * (110.0 * exp(-t * 6.0) + 32.0) / RATE
	var n := _lp(st, "lp", randf_range(-1, 1), 0.3) * exp(-t * 25.0)
	return (sin(st["ph"]) * env + n) * 1.1

func _clang(t: float, d: float, st: Dictionary) -> float:
	var v := 0.0
	var fr := [1230.0, 1870.0, 2650.0, 3410.0, 920.0]
	for i in fr.size():
		v += sin(TAU * fr[i] * t) * exp(-t * (5.0 + i * 2.0)) / (1.0 + i * 0.4)
	v += randf_range(-1, 1) * exp(-t * 90.0)
	return v * 0.45

func _boom(t: float, d: float, st: Dictionary) -> float:
	st["ph"] += TAU * (70.0 * exp(-t * 3.0) + 25.0) / RATE
	var n := _lp(st, "lp", randf_range(-1, 1), 0.06) * 2.5
	return (sin(st["ph"]) * 0.8 + n) * exp(-t * 4.5)

func _roar(t: float, d: float, st: Dictionary) -> float:
	var f := 75.0 + sin(t * 30.0) * 8.0 - t * 20.0
	st["ph"] += TAU * f / RATE
	var saw := fmod(st["ph"] / TAU, 1.0) * 2.0 - 1.0
	var n := _lp(st, "lp", randf_range(-1, 1), 0.15)
	var env := minf(t / 0.12, 1.0) * pow(1.0 - t / d, 1.2)
	return _lp(st, "lp2", saw * 0.7 + n * 0.9, 0.25) * env * 1.4

func _shing(t: float, d: float, st: Dictionary) -> float:
	var f := 2400.0 + 1800.0 * exp(-t * 6.0)
	st["ph"] += TAU * f / RATE
	var env := minf(t / 0.01, 1.0) * exp(-t * 4.0)
	var n := randf_range(-1, 1) * exp(-t * 30.0)
	return (sin(st["ph"]) * 0.4 + sin(st["ph"] * 1.51) * 0.2) * env + n * 0.5

func _dash(t: float, d: float, st: Dictionary) -> float:
	var env := sin(PI * t / d)
	var x := randf_range(-1, 1)
	var hp := x - _lp(st, "lp", x, 0.2)
	return hp * env * 0.8

func _jump(t: float, d: float, st: Dictionary) -> float:
	var env := exp(-t * 25.0)
	return _lp(st, "lp", randf_range(-1, 1), 0.12) * env * 1.5

func _water(t: float, d: float, st: Dictionary) -> float:
	var env := minf(t / 0.05, 1.0) * pow(1.0 - t / d, 1.3)
	var n := _lp(st, "lp", randf_range(-1, 1), 0.08 + 0.1 * sin(t * 40.0))
	var bub := sin(TAU * (500.0 + 300.0 * sin(t * 23.0)) * t) * 0.1
	return (n * 1.8 + bub) * env

func _crack(t: float, d: float, st: Dictionary) -> float:
	var n := randf_range(-1, 1)
	var env := exp(-t * 14.0)
	var crackle := 1.0 if randf() < 0.05 else 0.3
	return _lp(st, "lp", n * crackle, 0.4) * env * 1.6

func _hurt(t: float, d: float, st: Dictionary) -> float:
	st["ph"] += TAU * (220.0 - t * 400.0) / RATE
	return (sin(st["ph"]) * 0.5 + randf_range(-1, 1) * 0.3) * exp(-t * 12.0)

# Звуковой барьер: резкий хлопок + низкий гул + свист воздуха.
func _sonic(t: float, d: float, st: Dictionary) -> float:
	var crack := randf_range(-1, 1) * exp(-t * 90.0) * 1.6
	st["ph"] += TAU * (55.0 * exp(-t * 2.0) + 30.0) / RATE
	var boom := sin(st["ph"]) * exp(-t * 4.0) * 0.9
	var air := _lp(st, "lp", randf_range(-1, 1), 0.05 + 0.2 * exp(-t * 6.0)) * minf(t / 0.03, 1.0) * exp(-t * 3.5) * 1.6
	return crack + boom + air

# Выхват меча: металлический «шинг» по ножнам.
func _draw(t: float, d: float, st: Dictionary) -> float:
	var scrape := _lp(st, "lp", randf_range(-1, 1), 0.5) * minf(t / 0.02, 1.0) * exp(-t * 9.0) * 0.6
	st["ph"] += TAU * (3200.0 + 900.0 * exp(-t * 8.0)) / RATE
	var ring := (sin(st["ph"]) * 0.35 + sin(st["ph"] * 1.37) * 0.2) * exp(-t * 5.0) * smoothstep(0.03, 0.08, t)
	return scrape + ring

func _sheathe(t: float, d: float, st: Dictionary) -> float:
	var scrape := _lp(st, "lp", randf_range(-1, 1), 0.35) * exp(-t * 10.0) * 0.7
	var click := randf_range(-1, 1) * exp(-maxf(0.0, t - 0.22) * 80.0) * (1.0 if t > 0.22 else 0.0)
	return scrape + click

# Шаги: по земле — глухой стук с хрустом, по траве — мягкий шорох.
func _step_dirt(t: float, d: float, st: Dictionary) -> float:
	st["ph"] += TAU * (90.0 * exp(-t * 30.0) + 50.0) / RATE
	var thump := sin(st["ph"]) * exp(-t * 45.0) * 0.8
	var crunch := _lp(st, "lp", randf_range(-1, 1) * (1.0 if randf() < 0.3 else 0.2), 0.5) * exp(-t * 28.0) * 0.9
	return thump + crunch

func _step_grass(t: float, d: float, st: Dictionary) -> float:
	var x := randf_range(-1, 1)
	var hp := x - _lp(st, "lp", x, 0.15)
	return hp * sin(PI * t / d) * 0.55 + sin(TAU * 70.0 * t) * exp(-t * 50.0) * 0.4

func _land(t: float, d: float, st: Dictionary) -> float:
	st["ph"] += TAU * (75.0 * exp(-t * 12.0) + 35.0) / RATE
	var n := _lp(st, "lp", randf_range(-1, 1), 0.2) * exp(-t * 20.0)
	return (sin(st["ph"]) * exp(-t * 14.0) + n) * 0.9

# Пламя: гул с треском.
func _fire(t: float, d: float, st: Dictionary) -> float:
	var env := minf(t / 0.05, 1.0) * pow(1.0 - t / d, 1.4)
	var roar := _lp(st, "lp", randf_range(-1, 1), 0.06) * 2.2
	var crackle := randf_range(-1, 1) * (1.0 if randf() < 0.02 else 0.0)
	st["ph"] += TAU * (60.0 + 20.0 * sin(t * 13.0)) / RATE
	return (roar + crackle * 0.8 + sin(st["ph"]) * 0.25) * env

# Гром: резкий треск разряда и раскат.
func _thunder(t: float, d: float, st: Dictionary) -> float:
	var crack := randf_range(-1, 1) * exp(-t * 35.0) * 1.3
	var buzz := (1.0 if fmod(t * 120.0, 1.0) < 0.5 else -1.0) * exp(-t * 18.0) * 0.25
	var rumble := _lp(st, "lp", randf_range(-1, 1), 0.03) * 3.0 * minf(t / 0.08, 1.0) * exp(-t * 3.0)
	return crack + buzz + rumble

# Разрез плоти: короткий высокий «шк» лезвия + влажный глухой шлепок.
func _flesh(t: float, d: float, st: Dictionary) -> float:
	var hiss := (randf_range(-1, 1) - _lp(st, "lp", randf_range(-1, 1), 0.5)) * exp(-t * 45.0) * 0.9
	st["ph"] += TAU * (90.0 * exp(-t * 10.0) + 45.0) / RATE
	var thump := sin(st["ph"]) * exp(-t * 18.0)
	var wet := _lp(st, "lp2", randf_range(-1, 1), 0.08) * exp(-pow((t - 0.05) * 30.0, 2.0)) * 2.0
	return hiss + thump * 0.8 + wet

# Удар по дереву: полый стук (две резонансные частоты) и щелчок.
func _wood(t: float, d: float, st: Dictionary) -> float:
	var v := sin(TAU * 210.0 * t) * exp(-t * 18.0) + sin(TAU * 470.0 * t) * exp(-t * 26.0) * 0.6 + sin(TAU * 820.0 * t) * exp(-t * 40.0) * 0.3
	v += randf_range(-1, 1) * exp(-t * 120.0) * 0.7
	return v * 0.7

# Удар по камню: звонкий щелчок и осыпающаяся крошка.
func _stone(t: float, d: float, st: Dictionary) -> float:
	var click := (sin(TAU * 1650.0 * t) + sin(TAU * 2900.0 * t) * 0.5) * exp(-t * 70.0)
	var grit: float = randf_range(-1, 1) * (1.0 if randf() > 0.6 else 0.35) * exp(-t * 9.0) * 0.5
	return (click * 0.6 + _lp(st, "lp", grit, 0.6)) * 0.9

# Щелчок хлыста.
func _snap(t: float, d: float, st: Dictionary) -> float:
	var n := randf_range(-1, 1) * exp(-t * 80.0)
	st["ph"] += TAU * 2400.0 * exp(-t * 30.0) / RATE
	return (n + sin(st["ph"]) * exp(-t * 50.0) * 0.5) * 0.9

# Щелчок интерфейса (буквы в диалоге, выбор).
func _tick(t: float, d: float, st: Dictionary) -> float:
	st["ph"] += TAU * 1800.0 / RATE
	return sin(st["ph"]) * exp(-t * 120.0) * 0.4

# Колокольчик: глава пройдена, награда.
func _chime(t: float, d: float, st: Dictionary) -> float:
	var v := 0.0
	for k in [1.0, 2.0, 3.01, 4.2]:
		v += sin(TAU * 880.0 * k * t) * exp(-t * (2.5 + k)) / k
	return v * 0.35 * minf(1.0, t * 200.0)

# Храмовый гонг: титры главы.
func _gong(t: float, d: float, st: Dictionary) -> float:
	var f := 110.0 * (1.0 + 0.02 * exp(-t * 3.0))
	var v := sin(TAU * f * t) + 0.6 * sin(TAU * f * 2.76 * t) * exp(-t * 2.0) + 0.3 * sin(TAU * f * 5.4 * t) * exp(-t * 4.0)
	return v * exp(-t * 1.4) * 0.45 * minf(1.0, t * 100.0)

# Карканье ворона.
func _caw(t: float, d: float, st: Dictionary) -> float:
	var f := 520.0 - t * 500.0
	st["ph"] += TAU * f / RATE
	var saw := fmod(st["ph"] / TAU, 1.0) * 2.0 - 1.0
	var env := sin(PI * clampf(t / 0.4, 0.0, 1.0))
	return (saw * 0.6 + randf_range(-1, 1) * 0.35) * env * 0.5
