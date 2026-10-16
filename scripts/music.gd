extends Node
# Музыка и звуки окружения, синтезируются кодом в фоновом потоке:
#  спокойная тема (бурдон, кото, флейта-сякухати), боевая (тайко, сямисэн),
#  окружение ночью (сверчки, ветер) и днём (птицы, ветер).
# Боевая тема плавно вступает, когда демон заметил героя и рядом.

const RATE := 22050
const LEN := 16.0                 # длина петли, с
# лад «ин» (японская пентатоника) от ре: D Eb G A Bb
const SCALE := [0, 1, 5, 7, 8]
const BASE_HZ := 146.83           # ре малой октавы

var calm: AudioStreamPlayer
var battle: AudioStreamPlayer
var amb_night: AudioStreamPlayer
var amb_day: AudioStreamPlayer
var boss: AudioStreamPlayer
var boss_k := 0.0
var combat := 0.0
var ready_ := false
var _thread: Thread
var _streams := {}
var buf := PackedFloat32Array()     # текущая дорожка (пишем прямо в неё — без копий)

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for nm in ["calm", "battle", "amb_night", "amb_day", "boss"]:
		var p := AudioStreamPlayer.new()
		p.bus = "Music"
		p.volume_db = -80.0
		add_child(p)
		set(nm, p)
	_thread = Thread.new()
	_thread.start(_generate)

func _exit_tree() -> void:
	if _thread and _thread.is_started():
		_thread.wait_to_finish()

func _note_hz(deg: int) -> float:
	var oct := floori(float(deg) / SCALE.size())
	var k: int = SCALE[posmod(deg, SCALE.size())]
	return BASE_HZ * pow(2.0, oct + k / 12.0)

var gen_ms := 0

func _generate() -> void:
	var t0 := Time.get_ticks_msec()
	var r := RandomNumberGenerator.new()
	r.seed = 1234
	# в потоке — только данные (байты), ресурсы звука создаются в главном потоке
	_streams["calm"] = _to_bytes(_calm(r))
	_streams["battle"] = _to_bytes(_battle(r))
	_streams["amb_night"] = _to_bytes(_amb(r, true))
	_streams["amb_day"] = _to_bytes(_amb(r, false))
	_streams["boss"] = _to_bytes(_boss(r))
	gen_ms = Time.get_ticks_msec() - t0
	call_deferred("_on_ready")

func _on_ready() -> void:
	for nm in _streams:
		var p: AudioStreamPlayer = get(nm)
		p.stream = _to_stream(_streams[nm])
		p.play()
	ready_ = true

func _to_bytes(b: PackedFloat32Array) -> PackedByteArray:
	var data := PackedByteArray()
	data.resize(b.size() * 2)
	for i in b.size():
		data.encode_s16(i * 2, int(clampf(b[i], -1.0, 1.0) * 30000.0))
	return data

func _to_stream(data: PackedByteArray) -> AudioStreamWAV:
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = data
	w.loop_mode = AudioStreamWAV.LOOP_FORWARD
	w.loop_begin = 0
	w.loop_end = data.size() / 2
	return w

func _new_buf() -> void:
	buf = PackedFloat32Array()
	buf.resize(int(LEN * RATE))

func _take(peak: float) -> PackedFloat32Array:
	var m := 0.001
	for v in buf:
		m = maxf(m, absf(v))
	var k := peak / m
	for i in buf.size():
		buf[i] *= k
	var out := buf
	buf = PackedFloat32Array()
	return out

# щипок струны: несколько гармоник с быстрым спадом (кото, сямисэн)
func _pluck(t0: float, hz: float, amp: float, decay: float, bright: float) -> void:
	var n := int(minf(2.5, 5.0 / decay) * RATE)
	var s0 := int(t0 * RATE)
	for i in n:
		var t := float(i) / RATE
		var e := exp(-t * decay) * minf(1.0, t * 400.0)
		var ph := TAU * hz * t
		var v := sin(ph) + sin(ph * 2.0) * 0.5 * bright + sin(ph * 3.0) * 0.3 * bright * bright + sin(ph * 4.0) * 0.15 * bright
		var k := (s0 + i) % buf.size()
		buf[k] += v * e * amp

# барабан тайко: низкий удар с опусканием тона + шлепок
func _taiko(r: RandomNumberGenerator, t0: float, amp: float, hz := 70.0) -> void:
	var n := int(0.6 * RATE)
	var s0 := int(t0 * RATE)
	var ph := 0.0
	var lp := 0.0
	for i in n:
		var t := float(i) / RATE
		ph += TAU * (hz * (1.0 + 1.2 * exp(-t * 18.0))) / RATE
		lp += (r.randf_range(-1, 1) - lp) * 0.2
		var v := sin(ph) * exp(-t * 6.0) + lp * exp(-t * 40.0) * 0.8
		var k := (s0 + i) % buf.size()
		buf[k] += v * amp

# флейта: синус с вибрато и дыханием
func _flute(r: RandomNumberGenerator, t0: float, dur: float, hz: float, amp: float) -> void:
	var n := int(dur * RATE)
	var s0 := int(t0 * RATE)
	var ph := 0.0
	var lp := 0.0
	for i in n:
		var t := float(i) / RATE
		var env := minf(1.0, t / 0.25) * minf(1.0, (dur - t) / 0.4)
		var vib := 1.0 + 0.006 * sin(TAU * 5.0 * t) * minf(1.0, t / 0.6)
		ph += TAU * hz * vib / RATE
		lp += (r.randf_range(-1, 1) - lp) * 0.3
		var v := sin(ph) + sin(ph * 2.0) * 0.12 + lp * 0.25
		var k := (s0 + i) % buf.size()
		buf[k] += v * env * amp

func _calm(r: RandomNumberGenerator) -> PackedFloat32Array:
	_new_buf()
	var n := buf.size()
	# бурдон ре + ля, медленно дышит
	for i in n:
		var t := float(i) / RATE
		var sw := 0.6 + 0.4 * sin(TAU * t / LEN)
		buf[i] = (sin(TAU * BASE_HZ * 0.5 * t) * 0.5 + sin(TAU * BASE_HZ * 0.75 * t) * 0.25 + sin(TAU * BASE_HZ * t) * 0.1) * 0.09 * sw
	# кото: неторопливая фраза
	var phrase := [[0.0, 5], [0.75, 7], [1.5, 6], [2.5, 4], [3.5, 5], [4.5, 2], [6.0, 3], [7.0, 4],
		[8.0, 5], [8.75, 7], [9.5, 8], [10.5, 7], [11.5, 6], [12.5, 5], [13.5, 3], [14.5, 4]]
	for ph in phrase:
		_pluck(ph[0], _note_hz(ph[1]), 0.16, 3.0, 0.6)
		if r.randf() < 0.4:
			_pluck(ph[0] + 0.375, _note_hz(ph[1] - 2), 0.08, 3.5, 0.5)
	# флейта: две длинные ноты
	_flute(r, 2.0, 3.2, _note_hz(10), 0.07)
	_flute(r, 10.0, 3.6, _note_hz(9), 0.07)
	return _take(0.55)

func _battle(r: RandomNumberGenerator) -> PackedFloat32Array:
	_new_buf()
	var beat := 0.5                     # 120 ударов в минуту
	var bars := int(LEN / (beat * 4))
	for bar in bars:
		var t0 := bar * beat * 4
		# тайко: БУМ . бум БУМ | . бум . БУМ
		for hit in [[0.0, 0.5, 62.0], [1.0, 0.3, 70.0], [1.5, 0.45, 62.0], [2.5, 0.3, 70.0], [3.0, 0.5, 58.0]]:
			_taiko(r, t0 + hit[0] * beat, hit[1], hit[2])
		# малый барабан шиме: дробь шестнадцатыми в конце такта
		if bar % 2 == 1:
			for s in 4:
				_taiko(r, t0 + (3.0 + s * 0.25) * beat, 0.12, 190.0)
		# сямисэн: восьмые по ладу, каждые два такта — новая фигура
		var fig := [5, 7, 5, 8, 7, 5, 4, 5] if bar % 4 < 2 else [7, 8, 10, 8, 7, 5, 7, 4]
		for e in 8:
			_pluck(t0 + e * beat * 0.5, _note_hz(fig[e]), 0.13 if e % 2 == 0 else 0.09, 7.0, 1.0)
	# низкий бурдон
	for i in buf.size():
		var t := float(i) / RATE
		buf[i] += sin(TAU * BASE_HZ * 0.5 * t) * 0.06
	return _take(0.7)

# Тема Ущербной луны: быстрые тайко, сямисэн с режущими секундами,
# низкий «хор» на дрожащих синусах и удары гонга на каждые 4 такта.
func _boss(r: RandomNumberGenerator) -> PackedFloat32Array:
	_new_buf()
	var beat := 0.4                     # 150 ударов в минуту
	var bars := int(LEN / (beat * 4))
	for bar in bars:
		var t0 := bar * beat * 4
		for hit in [[0.0, 0.6, 52.0], [0.5, 0.3, 64.0], [1.0, 0.45, 52.0], [2.0, 0.6, 50.0], [2.75, 0.3, 64.0], [3.0, 0.4, 58.0], [3.5, 0.35, 64.0]]:
			_taiko(r, t0 + hit[0] * beat, hit[1], hit[2])
		for s2 in 8:
			_taiko(r, t0 + s2 * beat * 0.5, 0.06, 210.0)
		var fig := [0, 1, 0, 3, 1, 0, -1, 0] if bar % 2 == 0 else [3, 4, 3, 1, 0, 1, 3, 4]
		for e in 8:
			_pluck(t0 + e * beat * 0.5, _note_hz(fig[e] + 5), 0.14 if e % 2 == 0 else 0.1, 8.0, 1.0)
			if e % 4 == 0:
				_pluck(t0 + e * beat * 0.5, _note_hz(fig[e] + 6), 0.07, 6.0, 0.9)   # режущая секунда
	var n := buf.size()
	for i in n:
		var t := float(i) / RATE
		var vib := sin(TAU * 5.0 * t) * 0.004
		var ch := sin(TAU * BASE_HZ * 0.5 * t * (1.0 + vib)) + 0.6 * sin(TAU * BASE_HZ * 0.5 * 1.0595 * t * (1.0 - vib)) + 0.4 * sin(TAU * BASE_HZ * 0.75 * t)
		buf[i] += ch * 0.05 * (0.7 + 0.3 * sin(TAU * t / LEN * 2.0))
		# гонг раз в 4 такта
		var gt := fmod(t, beat * 16.0)
		buf[i] += sin(TAU * 90.0 * gt + sin(TAU * 247.0 * gt) * 2.0) * exp(-gt * 1.2) * 0.12
	return _take(0.75)

func _amb(r: RandomNumberGenerator, night: bool) -> PackedFloat32Array:
	_new_buf()
	var n := buf.size()
	# ветер: шум через фильтр, медленно гуляет
	var lp := 0.0
	var lp2 := 0.0
	for i in n:
		var t := float(i) / RATE
		var g := 0.5 + 0.5 * sin(TAU * t / LEN * 2.0 + sin(TAU * t / LEN) * 2.0)
		lp += (r.randf_range(-1, 1) - lp) * (0.02 + 0.03 * g)
		lp2 += (lp - lp2) * 0.1
		buf[i] = lp2 * (0.6 + 0.8 * g) * 0.9
	if night:
		# сверчки: пачки коротких высоких трелей
		var t := 0.0
		while t < LEN - 0.5:
			var hz := r.randf_range(4200.0, 5200.0)
			var reps := r.randi_range(3, 6)
			var amp := r.randf_range(0.03, 0.07)
			for k in reps:
				var s0 := int((t + k * 0.06) * RATE)
				for i in int(0.035 * RATE):
					var tt := float(i) / RATE
					buf[(s0 + i) % n] += sin(TAU * hz * tt) * sin(PI * tt / 0.035) * amp * (0.5 + 0.5 * sin(TAU * 60.0 * tt))
			t += r.randf_range(0.25, 0.9)
	else:
		# птицы: короткие свисты с изгибом тона
		var t2 := 0.5
		while t2 < LEN - 1.0:
			var f0 := r.randf_range(2200.0, 3600.0)
			for k in r.randi_range(2, 4):
				var s1 := int((t2 + k * 0.14) * RATE)
				var ph := 0.0
				var d := r.randf_range(0.06, 0.11)
				for i in int(d * RATE):
					var tt := float(i) / RATE
					ph += TAU * (f0 + 900.0 * sin(PI * tt / d)) / RATE
					buf[(s1 + i) % n] += sin(ph) * sin(PI * tt / d) * 0.05
			t2 += r.randf_range(1.2, 3.0)
	return _take(0.5)

# Смешивание: в меню и без демона — спокойная тема, в бою — боевая.
func _process(_dt: float) -> void:
	if not ready_:
		return
	var dt: float = G.rdt
	var want := 0.0
	var want_boss := 0.0
	if G.started and G.player:
		for e in G.enemies:
			if is_instance_valid(e) and not e.is_dead() and e.noticed and e.global_position.distance_to(G.player.global_position) < 35.0:
				want = 1.0
				if e.get("kind") in ["boss", "boss2"]:
					want_boss = 1.0
	combat = move_toward(combat, want, dt * (0.6 if want > combat else 0.25))
	boss_k = move_toward(boss_k, want_boss, dt * 0.5)
	calm.volume_db = linear_to_db(maxf(0.0001, (1.0 - combat) * 0.7))
	battle.volume_db = linear_to_db(maxf(0.0001, combat * 0.8 * (1.0 - boss_k)))
	boss.volume_db = linear_to_db(maxf(0.0001, combat * 0.85 * boss_k))
	var night: bool = G.world.night if G.world else true
	amb_night.volume_db = linear_to_db(0.5 if night else 0.0001)
	amb_day.volume_db = linear_to_db(0.0001 if night else 0.5)
