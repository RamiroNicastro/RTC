class_name SfxSynth
extends RefCounted
## Sintetizador procedural de efectos de sonido (placeholder arcade): arma AudioStreamWAV
## de 16 bits mono mezclando ruido filtrado, senos con caída de pitch, envolventes cortas,
## saturación suave y una reverb chica. Cada sonido se genera UNA vez y queda en caché.
##
## NO reproduce nada (eso es CombatSfx), no conoce el combate ni usa autoloads, y no lee
## archivos de audio. Todo es determinista: la misma id siempre genera el mismo sonido.

const SAMPLE_RATE: int = 22050
## Los sonidos de público van a menor frecuencia de muestreo: no necesitan agudos y se generan más rápido.
const CROWD_SAMPLE_RATE: int = 16000
## Pico al que se normaliza cada sonido (≈ -1 dBFS): nunca hay clipping.
const PEAK_TARGET: float = 0.89
## Fracción final de cada sonido (no loop) que se apaga con un fundido suave.
const TAIL_FADE: float = 0.35
## Niveles de intensidad pregenerados para los sonidos que dependen de la fuerza.
const TIERS: int = 3

## Duración del loop del ambiente (en segundos) y del cruce que lo hace empalmar sin corte.
const AMBIENCE_LOOP_SECONDS: float = 6.0
const AMBIENCE_XFADE_SECONDS: float = 1.0

## Modos de filtro para SynthBuffer.add_noise().
enum Filter { LOW, BAND, HIGH }

## Todas las ids que sabe generar get_stream().
const ALL_IDS: PackedStringArray = [
	"hit_head_0", "hit_head_1", "hit_head_2",
	"hit_body_0", "hit_body_1", "hit_body_2",
	"block_0", "block_1", "block_2",
	"whoosh_0", "whoosh_1", "whoosh_2",
	"dodge", "guard_break", "knockdown", "bell",
	"cheer_0", "cheer_1", "cheer_2",
	"ambience",
]

static var _cache: Dictionary = {}


## Devuelve el stream de la id pedida (de ALL_IDS), generándolo la primera vez.
static func get_stream(id: String) -> AudioStreamWAV:
	if _cache.has(id):
		return _cache[id]
	var stream: AudioStreamWAV = build(id)
	if stream != null:
		_cache[id] = stream
	return stream


static func is_cached(id: String) -> bool:
	return _cache.has(id)


## Guarda en caché un stream generado aparte (por ejemplo en un hilo). Si ya había uno, gana el que estaba,
## así nunca cambia el stream de un sonido que ya está sonando. Llamar solo desde el hilo principal.
static func store(id: String, stream: AudioStreamWAV) -> void:
	if stream != null and not _cache.has(id):
		_cache[id] = stream


## Genera de antemano todos los sonidos (para hacerlo en una pantalla de carga y no a mitad de pelea).
static func warm_up() -> void:
	for id in ALL_IDS:
		get_stream(id)


static func clear_cache() -> void:
	_cache.clear()


## Nivel (0..TIERS-1) que corresponde a una fuerza 0..1+ (jab ≈ 0.3, fuerte ≈ 0.8, cargado ≈ 1.0+).
static func tier_for(strength: float) -> int:
	if strength < 0.5:
		return 0
	if strength < 0.95:
		return 1
	return 2


## Pico absoluto (0..1) de un stream de 16 bits. Lo usan las pruebas para verificar que no hay clipping.
static func measure_peak(stream: AudioStreamWAV) -> float:
	var data: PackedByteArray = stream.data
	var peak: int = 0
	for i in range(0, data.size() - 1, 2):
		peak = maxi(peak, absi(data.decode_s16(i)))
	return float(peak) / 32768.0


## Genera el stream SIN tocar la caché. No usa estado compartido, así que se puede llamar desde otro hilo.
static func build(id: String) -> AudioStreamWAV:
	var parts: PackedStringArray = id.rsplit("_", true, 1)
	var tier: int = 0
	var base: String = id
	if parts.size() == 2 and parts[1].is_valid_int():
		base = parts[0]
		tier = clampi(parts[1].to_int(), 0, TIERS - 1)
	var seed_value: int = absi(hash(id))
	match base:
		"hit_head":
			return _hit_head(tier, seed_value)
		"hit_body":
			return _hit_body(tier, seed_value)
		"block":
			return _block(tier, seed_value)
		"whoosh":
			return _whoosh(tier, seed_value)
		"dodge":
			return _dodge(seed_value)
		"guard_break":
			return _guard_break(seed_value)
		"knockdown":
			return _knockdown(seed_value)
		"bell":
			return _bell(seed_value)
		"cheer":
			return _cheer(tier, seed_value)
		"ambience":
			return _ambience(seed_value)
	push_error("SfxSynth: id de sonido desconocida: " + id)
	return null


# --- Recetas -------------------------------------------------------------------------------

## Golpe a la cabeza: chasquido agudo + "smack" de banda media + carne grave + cuerpo con caída de pitch.
static func _hit_head(t: int, seed_value: int) -> AudioStreamWAV:
	var b := SynthBuffer.new(0.28 + 0.14 * t, SAMPLE_RATE, seed_value)
	b.add_noise(0.0, Filter.HIGH, 2600.0, 2600.0, 0.0, 0.0, 0.0004, 0.005 + 0.002 * t, 0.75)
	b.add_noise(0.0, Filter.BAND, 1900.0 - 300.0 * t, 900.0 - 150.0 * t, 0.03, 0.8, 0.0008, 0.028 + 0.012 * t, 0.85)
	b.add_noise(0.0, Filter.LOW, 1000.0, 300.0, 0.04, 0.0, 0.001, 0.045 + 0.03 * t, 0.6 + 0.15 * t)
	b.add_tone(0.0, 220.0 - 30.0 * t, 72.0 - 12.0 * t, 0.035 + 0.01 * t, 0.0012, 0.065 + 0.05 * t, 0.8 + 0.2 * t)
	if t == 2:
		b.add_tone(0.0, 100.0, 42.0, 0.08, 0.002, 0.17, 0.65)
	b.drive(1.4 + 0.4 * t)
	return b.finish()


## Golpe al cuerpo: más grave y sordo, casi sin agudos, con un "thud" largo.
static func _hit_body(t: int, seed_value: int) -> AudioStreamWAV:
	var b := SynthBuffer.new(0.32 + 0.14 * t, SAMPLE_RATE, seed_value)
	b.add_noise(0.0, Filter.LOW, 2200.0, 800.0, 0.01, 0.0, 0.0006, 0.012, 0.5)
	b.add_noise(0.0, Filter.LOW, 550.0, 180.0, 0.05, 0.0, 0.001, 0.07 + 0.03 * t, 0.85)
	b.add_tone(0.0, 135.0 - 15.0 * t, 48.0 - 6.0 * t, 0.05, 0.0015, 0.11 + 0.06 * t, 1.0)
	if t >= 1:
		b.add_tone(0.0, 72.0, 36.0, 0.09, 0.003, 0.17 + 0.05 * t, 0.45 + 0.2 * t)
	b.drive(1.3 + 0.35 * t)
	return b.finish()


## Golpe en los guantes: "pop" de cuero resonante + golpe amortiguado del relleno.
static func _block(t: int, seed_value: int) -> AudioStreamWAV:
	var b := SynthBuffer.new(0.22 + 0.06 * t, SAMPLE_RATE, seed_value)
	b.add_noise(0.0, Filter.HIGH, 3200.0, 3200.0, 0.0, 0.0, 0.0003, 0.003, 0.25)
	b.add_noise(0.0, Filter.BAND, 1150.0 - 150.0 * t, 700.0, 0.02, 0.35, 0.0005, 0.018 + 0.006 * t, 0.75)
	b.add_tone(0.0, 430.0 - 60.0 * t, 190.0, 0.012, 0.0008, 0.03 + 0.01 * t, 0.6)
	b.add_tone(0.0, 150.0, 80.0, 0.03, 0.0015, 0.06 + 0.03 * t, 0.5 + 0.12 * t)
	b.add_noise(0.0, Filter.LOW, 1200.0, 400.0, 0.02, 0.0, 0.0008, 0.03, 0.45)
	b.drive(1.4)
	return b.finish()


## Golpe al aire: ruido de banda que barre hacia arriba y vuelve (efecto de paso).
static func _whoosh(t: int, seed_value: int) -> AudioStreamWAV:
	var dur: float = 0.22 + 0.07 * t
	var b := SynthBuffer.new(dur + 0.02, SAMPLE_RATE, seed_value)
	b.add_swept_noise(0.0, dur, 350.0 - 60.0 * t, 1500.0 - 250.0 * t, 0.45, 0.6, 1.0)
	b.add_swept_noise(0.0, dur, 1200.0, 2600.0 - 400.0 * t, 0.5, 0.9, 0.3)
	return b.finish()


## Esquive: whoosh corto y agudo con un roce de ropa al principio.
static func _dodge(seed_value: int) -> AudioStreamWAV:
	var b := SynthBuffer.new(0.18, SAMPLE_RATE, seed_value)
	b.add_swept_noise(0.0, 0.16, 900.0, 3200.0, 0.35, 0.5, 1.0)
	b.add_noise(0.0, Filter.HIGH, 4000.0, 4000.0, 0.0, 0.0, 0.002, 0.01, 0.2)
	return b.finish()


## Ruptura de guardia: crack seco con crepitado, "pop" de cuero, golpe grave y un brillo quebradizo.
static func _guard_break(seed_value: int) -> AudioStreamWAV:
	var b := SynthBuffer.new(0.7, SAMPLE_RATE, seed_value)
	b.add_noise(0.0, Filter.HIGH, 3000.0, 3000.0, 0.0, 0.0, 0.0003, 0.008, 1.0)
	b.add_noise(0.0, Filter.BAND, 2600.0, 1400.0, 0.03, 0.4, 0.0005, 0.035, 0.85)
	for i in 7:
		var at: float = b.rng.randf_range(0.004, 0.06)
		b.add_noise(at, Filter.HIGH, 2500.0, 2500.0, 0.0, 0.0, 0.0002, 0.003, b.rng.randf_range(0.3, 0.6))
	b.add_noise(0.0, Filter.BAND, 800.0, 500.0, 0.04, 0.5, 0.001, 0.05, 0.7)
	b.add_tone(0.0, 165.0, 45.0, 0.05, 0.0015, 0.16, 1.0)
	b.add_tone(0.0, 82.0, 35.0, 0.1, 0.003, 0.3, 0.6)
	b.add_tone(0.0, 1250.0, 1180.0, 0.05, 0.0008, 0.08, 0.15)
	b.add_tone(0.0, 1870.0, 1790.0, 0.05, 0.0008, 0.06, 0.1)
	b.drive(2.0)
	return b.finish()


## Knockdown: golpe grave contra la lona, rebote, vibración de la lona y reverb corta.
static func _knockdown(seed_value: int) -> AudioStreamWAV:
	var b := SynthBuffer.new(1.5, SAMPLE_RATE, seed_value)
	b.add_tone(0.0, 95.0, 34.0, 0.07, 0.002, 0.22, 1.0)
	b.add_noise(0.0, Filter.LOW, 1400.0, 300.0, 0.03, 0.0, 0.001, 0.06, 0.8)
	b.add_noise(0.0, Filter.LOW, 400.0, 150.0, 0.06, 0.0, 0.002, 0.12, 0.7)
	b.add_tone(0.11, 80.0, 40.0, 0.05, 0.002, 0.1, 0.4)
	b.add_noise(0.11, Filter.LOW, 900.0, 250.0, 0.03, 0.0, 0.001, 0.04, 0.3)
	b.add_noise(0.0, Filter.BAND, 220.0, 200.0, 0.1, 0.3, 0.005, 0.25, 0.15)
	b.drive(1.6)
	b.reverb(0.35, 0.74)
	return b.finish()


## Campana de ring: parciales inarmónicos (los agudos se apagan antes), batido entre dos parciales
## casi iguales y un golpe metálico de ruido al principio.
static func _bell(seed_value: int) -> AudioStreamWAV:
	var b := SynthBuffer.new(3.5, SAMPLE_RATE, seed_value)
	var fundamental: float = 1020.0
	# [relación de frecuencia, amplitud, tiempo de caída en segundos]
	var partials: Array[Vector3] = [
		Vector3(0.5, 0.25, 1.8), Vector3(1.0, 1.0, 1.6), Vector3(1.006, 0.6, 1.5),
		Vector3(1.52, 0.55, 1.1), Vector3(2.03, 0.45, 0.9), Vector3(2.74, 0.35, 0.7),
		Vector3(3.48, 0.25, 0.5), Vector3(4.27, 0.18, 0.35), Vector3(5.41, 0.12, 0.25),
	]
	for p in partials:
		var f: float = fundamental * p.x
		b.add_tone(0.0, f, f, 1.0, 0.0015, p.z, p.y)
	b.add_noise(0.0, Filter.HIGH, 3000.0, 3000.0, 0.0, 0.0, 0.0003, 0.004, 0.5)
	b.add_noise(0.0, Filter.BAND, 3000.0, 3000.0, 0.0, 0.5, 0.0005, 0.01, 0.3)
	return b.finish()


## Ovación: colchón de ruido modulado + muchas voces ("aaah") + aplausos y algún silbido.
static func _cheer(t: int, seed_value: int) -> AudioStreamWAV:
	var dur: float = [1.4, 2.1, 2.9][t]
	var b := SynthBuffer.new(dur, CROWD_SAMPLE_RATE, seed_value)
	b.add_crowd_bed(0.0, dur, 650.0, 0.9, 6.0, 0.5, 0.5 + 0.15 * t)
	b.add_crowd_bed(0.0, dur, 1500.0, 0.9, 8.0, 0.6, 0.25 + 0.1 * t)
	var voices: int = [18, 34, 55][t]
	for i in voices:
		var start: float = pow(b.rng.randf(), 1.4) * dur * 0.7
		var length: float = b.rng.randf_range(0.3, 0.9)
		b.add_voice(start, length, b.rng.randf_range(160.0, 360.0), b.rng.randf_range(600.0, 1300.0),
				b.rng.randf_range(0.3, 0.6), b.rng.randf_range(0.2, 0.45))
	var claps: int = [10, 40, 90][t]
	for i in claps:
		b.add_noise(b.rng.randf() * dur * 0.8, Filter.BAND, b.rng.randf_range(1100.0, 2200.0), 0.0, 0.0,
				0.8, 0.0003, 0.006, b.rng.randf_range(0.1, 0.25))
	for i in t * 2 - 1:
		b.add_whistle(b.rng.randf_range(0.1, dur * 0.5), b.rng.randf_range(0.35, 0.6),
				b.rng.randf_range(2100.0, 2900.0), 0.12)
	b.envelope(0.2, dur * 0.5, dur)
	return b.finish()


## Murmullo de fondo: colchón oscuro + voces sueltas, cerrado en loop con un cruce sin corte.
static func _ambience(seed_value: int) -> AudioStreamWAV:
	var dur: float = AMBIENCE_LOOP_SECONDS + AMBIENCE_XFADE_SECONDS
	var b := SynthBuffer.new(dur, CROWD_SAMPLE_RATE, seed_value)
	b.add_crowd_bed(0.0, dur, 450.0, 0.9, 3.0, 0.4, 0.6)
	b.add_crowd_bed(0.0, dur, 900.0, 0.9, 4.0, 0.5, 0.3)
	var voices: int = int(dur * 7.0)
	for i in voices:
		b.add_voice(b.rng.randf() * (dur - 0.2), b.rng.randf_range(0.2, 0.6), b.rng.randf_range(110.0, 260.0),
				b.rng.randf_range(350.0, 900.0), b.rng.randf_range(0.5, 0.7), b.rng.randf_range(0.25, 0.5))
	b.make_loop(AMBIENCE_XFADE_SECONDS)
	return b.finish(true)


# --- Buffer de síntesis --------------------------------------------------------------------

## Buffer de muestras en float con las operaciones de síntesis. Cada add_* SUMA una capa al buffer.
## Las capas de ruido se normalizan a su pico antes de sumarse, así `amp` es el pico real de la capa.
class SynthBuffer:
	var sr: int
	var data: PackedFloat32Array
	var rng: RandomNumberGenerator
	var _loop: bool = false

	func _init(seconds: float, rate: int, seed_value: int) -> void:
		sr = rate
		data = PackedFloat32Array()
		data.resize(maxi(1, int(seconds * rate)))
		data.fill(0.0)
		rng = RandomNumberGenerator.new()
		rng.seed = seed_value

	func idx(t: float) -> int:
		return clampi(int(t * sr), 0, data.size())

	## Seno con caída exponencial de pitch (f0 → f1, constante de tiempo glide_tau),
	## ataque lineal y caída exponencial (decay_tau). Se corta solo cuando ya no se oye.
	func add_tone(start: float, f0: float, f1: float, glide_tau: float, attack: float, decay_tau: float, amp: float) -> void:
		var n: int = data.size()
		var i0: int = idx(start)
		var att: int = maxi(1, int(attack * sr))
		var dk: float = exp(-1.0 / (decay_tau * sr))
		var gk: float = exp(-1.0 / (maxf(glide_tau, 0.0001) * sr))
		var g: float = 1.0
		var env: float = 1.0
		var phase: float = 0.0
		var w: float = TAU / sr
		for i in range(i0, n):
			var j: int = i - i0
			var a: float
			if j < att:
				a = float(j) / att
			else:
				env *= dk
				if env < 0.0001:
					break
				a = env
			phase += w * (f1 + (f0 - f1) * g)
			g *= gk
			data[i] += sin(phase) * a * amp

	## Ráfaga de ruido filtrado. LOW y HIGH usan dos polos simples (estables siempre);
	## BAND usa un filtro de estado variable con sobremuestreo x2 (`damping` bajo = más resonante).
	## El corte va de fc0 a fc1 con constante fc_tau (0 = fijo).
	func add_noise(start: float, mode: int, fc0: float, fc1: float, fc_tau: float, damping: float,
			attack: float, decay_tau: float, amp: float) -> void:
		var n: int = data.size()
		var i0: int = idx(start)
		var att: int = maxi(1, int(attack * sr))
		var dk: float = exp(-1.0 / (decay_tau * sr))
		var fixed: bool = fc_tau <= 0.0
		var gk: float = 0.0 if fixed else exp(-1.0 / (fc_tau * sr))
		var g: float = 1.0
		var env: float = 1.0
		var damp: float = clampf(damping, 0.2, 1.0)
		var s1: float = 0.0
		var s2: float = 0.0
		var layer := PackedFloat32Array()
		var coef: float = _coef(mode, fc0)
		for i in range(i0, n):
			var j: int = i - i0
			var a: float
			if j < att:
				a = float(j) / att
			else:
				env *= dk
				if env < 0.0001:
					break
				a = env
			if not fixed:
				coef = _coef(mode, fc1 + (fc0 - fc1) * g)
				g *= gk
			var x: float = rng.randf_range(-1.0, 1.0)
			var y: float
			if mode == Filter.BAND:
				for k in 2:
					s1 += coef * s2
					var high: float = x - s1 - damp * s2
					s2 += coef * high
				y = s2
			else:
				s1 += coef * (x - s1)
				s2 += coef * (s1 - s2)
				y = s2 if mode == Filter.LOW else x - s2
			layer.append(y * a)
		_mix_normalized(layer, i0, amp)

	## Ruido de banda con forma de "swish": volumen y brillo suben hasta peak_pos (0..1) y bajan.
	func add_swept_noise(start: float, dur: float, fc_lo: float, fc_hi: float, peak_pos: float, damping: float, amp: float) -> void:
		var i0: int = idx(start)
		var i1: int = idx(start + dur)
		var length: int = maxi(1, i1 - i0)
		var damp: float = clampf(damping, 0.2, 1.0)
		var low: float = 0.0
		var band: float = 0.0
		var layer := PackedFloat32Array()
		for i in range(i0, i1):
			var p: float = float(i - i0) / length
			var shape: float
			if p < peak_pos:
				shape = pow(p / peak_pos, 2.0)
			else:
				shape = pow((1.0 - p) / (1.0 - peak_pos), 1.5)
			var f: float = _coef(Filter.BAND, fc_lo + (fc_hi - fc_lo) * shape)
			var x: float = rng.randf_range(-1.0, 1.0)
			for k in 2:
				low += f * band
				var high: float = x - low - damp * band
				band += f * high
			layer.append(band * shape)
		_mix_normalized(layer, i0, amp)

	## Colchón de público: ruido de banda con modulación aleatoria suave (muchas voces que suben y bajan).
	func add_crowd_bed(start: float, dur: float, fc: float, damping: float, mod_rate: float, mod_depth: float, amp: float) -> void:
		var i0: int = idx(start)
		var i1: int = idx(start + dur)
		var f: float = _coef(Filter.BAND, fc)
		var damp: float = clampf(damping, 0.2, 1.0)
		var low: float = 0.0
		var band: float = 0.0
		var m: float = 1.0
		var target: float = 1.0
		var countdown: int = 0
		var smooth: float = 1.0 - exp(-TAU * mod_rate / sr)
		var layer := PackedFloat32Array()
		for i in range(i0, i1):
			countdown -= 1
			if countdown <= 0:
				target = 1.0 - mod_depth * rng.randf()
				countdown = int(sr / mod_rate * rng.randf_range(0.5, 1.5))
			m += (target - m) * smooth
			var x: float = rng.randf_range(-1.0, 1.0)
			for k in 2:
				low += f * band
				var high: float = x - low - damp * band
				band += f * high
			layer.append(band * m)
		_mix_normalized(layer, i0, amp)

	## Una voz de público: zumbido con 4 armónicos + aire, pasado por un formante, con ventana suave.
	func add_voice(start: float, dur: float, pitch: float, formant: float, breath: float, amp: float) -> void:
		var i0: int = idx(start)
		var i1: int = idx(start + dur)
		var length: int = maxi(1, i1 - i0)
		var f: float = _coef(Filter.BAND, formant)
		var low: float = 0.0
		var band: float = 0.0
		var phase: float = 0.0
		var w: float = TAU / sr
		var layer := PackedFloat32Array()
		for i in range(i0, i1):
			var p: float = float(i - i0) / length
			var win: float = sin(PI * p)
			win *= win
			phase += w * pitch * (1.0 + 0.08 * sin(PI * p))
			var buzz: float = sin(phase) + 0.5 * sin(2.0 * phase) + 0.33 * sin(3.0 * phase) + 0.25 * sin(4.0 * phase)
			var x: float = buzz * 0.5 * (1.0 - breath) + rng.randf_range(-1.0, 1.0) * breath
			for k in 2:
				low += f * band
				var high: float = x - low - 0.5 * band
				band += f * high
			layer.append(band * win)
		_mix_normalized(layer, i0, amp)

	## Silbido de público: seno agudo con vibrato y subida de pitch.
	func add_whistle(start: float, dur: float, freq: float, amp: float) -> void:
		var i0: int = idx(start)
		var i1: int = idx(start + dur)
		var length: int = maxi(1, i1 - i0)
		var phase: float = 0.0
		var w: float = TAU / sr
		for i in range(i0, i1):
			var p: float = float(i - i0) / length
			var win: float = sin(PI * p)
			var vib: float = 1.0 + 0.02 * sin(TAU * 6.0 * float(i - i0) / sr)
			phase += w * freq * (0.9 + 0.1 * minf(p * 3.0, 1.0)) * vib
			data[i] += sin(phase) * win * amp

	## Saturación suave (tanh) para dar golpe y redondear picos.
	func drive(amount: float) -> void:
		var norm: float = 1.0 / tanh(amount)
		for i in data.size():
			data[i] = tanh(data[i] * amount) * norm

	## Envolvente global: sube en `attack`, se mantiene hasta `release_start` y se apaga hasta `end`.
	func envelope(attack: float, release_start: float, end: float) -> void:
		for i in data.size():
			var t: float = float(i) / sr
			var a: float = 1.0
			if t < attack:
				a = t / attack
			elif t > release_start:
				a = clampf((end - t) / (end - release_start), 0.0, 1.0)
				a *= a
			data[i] *= a

	## Reverb corta tipo Schroeder: 4 peines en paralelo con amortiguación + 2 pasa-todo en serie.
	func reverb(wet: float, room: float) -> void:
		var n: int = data.size()
		var wet_buf := PackedFloat32Array()
		wet_buf.resize(n)
		wet_buf.fill(0.0)
		for d in [0.0297, 0.0371, 0.0411, 0.0437]:
			var length: int = int(d * sr)
			var line := PackedFloat32Array()
			line.resize(length)
			line.fill(0.0)
			var pos: int = 0
			var lp: float = 0.0
			for i in n:
				var out: float = line[pos]
				lp += 0.45 * (out - lp)
				line[pos] = data[i] + lp * room
				pos = (pos + 1) % length
				wet_buf[i] += out * 0.25
		for d in [0.005, 0.0017]:
			var length: int = int(d * sr)
			var line := PackedFloat32Array()
			line.resize(length)
			line.fill(0.0)
			var pos: int = 0
			for i in n:
				var buffered: float = line[pos]
				var x: float = wet_buf[i]
				var v: float = x + buffered * 0.7
				line[pos] = v
				wet_buf[i] = buffered - v * 0.7
				pos = (pos + 1) % length
		for i in n:
			data[i] += wet_buf[i] * wet

	## Recorta el buffer a (largo - xfade) y funde el sobrante con el principio para que el loop empalme.
	func make_loop(xfade: float) -> void:
		var x: int = int(xfade * sr)
		var loop_len: int = data.size() - x
		for i in x:
			var p: float = float(i) / x
			# Cruce de igual potencia (las dos partes son ruido sin correlación).
			data[i] = data[i] * sin(p * PI * 0.5) + data[loop_len + i] * cos(p * PI * 0.5)
		data.resize(loop_len)
		_loop = true

	## Normaliza al pico objetivo, apaga suave el último tramo (si no es loop) para que la cola
	## no termine cortada, y arma el AudioStreamWAV.
	func finish(loop: bool = false) -> AudioStreamWAV:
		var n: int = data.size()
		if not loop and not _loop:
			var fade: int = mini(n, int(n * SfxSynth.TAIL_FADE))
			for k in fade:
				var p: float = float(k) / fade  # 0 en la última muestra, 1 al principio del tramo
				data[n - 1 - k] *= 0.5 - 0.5 * cos(PI * p)
		var peak: float = 0.0
		for v in data:
			peak = maxf(peak, absf(v))
		var gain: float = SfxSynth.PEAK_TARGET / peak if peak > 0.000001 else 1.0
		var bytes := PackedByteArray()
		bytes.resize(n * 2)
		for i in n:
			bytes.encode_s16(i * 2, clampi(roundi(data[i] * gain * 32767.0), -32767, 32767))
		var stream := AudioStreamWAV.new()
		stream.format = AudioStreamWAV.FORMAT_16_BITS
		stream.mix_rate = sr
		stream.stereo = false
		stream.data = bytes
		if loop or _loop:
			stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
			stream.loop_begin = 0
			stream.loop_end = n
		return stream

	## Coeficiente del filtro para una frecuencia de corte (limitado para que sea estable).
	func _coef(mode: int, fc: float) -> float:
		if mode == SfxSynth.Filter.BAND:
			# Filtro de estado variable corriendo a 2× la frecuencia de muestreo.
			return 2.0 * sin(PI * clampf(fc, 20.0, sr * 0.24) / (2.0 * sr))
		return 1.0 - exp(-TAU * clampf(fc, 20.0, sr * 0.45) / sr)

	func _mix_normalized(layer: PackedFloat32Array, i0: int, amp: float) -> void:
		var peak: float = 0.0
		for v in layer:
			peak = maxf(peak, absf(v))
		if peak < 0.000001:
			return
		var gain: float = amp / peak
		for k in layer.size():
			data[i0 + k] += layer[k] * gain
