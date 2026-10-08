class_name CombatSfx
extends Node
## Reproductor de efectos de sonido del combate (placeholder arcade). Usa los sonidos
## procedurales de SfxSynth con un pool de AudioStreamPlayer para que suenen varios a la vez,
## y les da una variación leve de pitch y volumen a cada uno para que no suenen repetidos.
##
## Solo SUENA: no decide cuándo (CombatScene o quien sea le avisa qué pasó), no cambia la lógica
## ni los timings y no usa autoloads. Toca solo el volumen de sus propios players, no el del bus.

const POOL_SIZE: int = 8
const BUS: StringName = &"Master"

## Volúmenes base (dB) de cada tipo de sonido, balanceados entre sí: los golpes adelante, el ambiente atrás.
const VOL_HIT_HEAD: float = -2.0
const VOL_HIT_BODY: float = -1.0
const VOL_BLOCK: float = -5.0
const VOL_WHOOSH: float = -13.0
const VOL_DODGE: float = -12.0
const VOL_GUARD_BREAK: float = -1.0
const VOL_KNOCKDOWN: float = 0.0
const VOL_BELL: float = -6.0
const VOL_CHEER: float = -13.0
const VOL_AMBIENCE: float = -24.0

## Tiempo entre campanadas cuando play_bell() pide varias.
const BELL_SPACING: float = 0.42
const AMBIENCE_FADE: float = 1.5

var _players: Array[AudioStreamPlayer] = []
## Orden de arranque de cada player (contador creciente) para robar el más viejo si están todos ocupados.
var _started_at: PackedInt64Array = []
var _play_count: int = 0
var _ambience: AudioStreamPlayer
var _ambience_tween: Tween
var _ambience_on: bool = false
var _master_db: float = 0.0
var _rng := RandomNumberGenerator.new()
var _warm_ids: PackedStringArray = []
var _warm_task: int = -1


func _ready() -> void:
	_rng.randomize()
	_ensure_players()
	# Genera en otro hilo los sonidos que falten (≈1,5 s en total), los golpes primero, para que la
	# ovación o el ambiente no traben la pelea la primera vez. Si algo se pide antes de que esté listo,
	# SfxSynth lo genera en el momento (los golpes tardan unos 10-30 ms).
	for id in SfxSynth.ALL_IDS:
		if not SfxSynth.is_cached(id):
			_warm_ids.append(id)
	if not _warm_ids.is_empty():
		_warm_task = WorkerThreadPool.add_task(_warm_up_in_background, false, "CombatSfx: generar sonidos")


func _exit_tree() -> void:
	for p in _players:
		p.stop()
	if _ambience != null:
		_ambience.stop()
	if _warm_task >= 0:
		WorkerThreadPool.wait_for_task_completion(_warm_task)
		_warm_task = -1


## Golpe que entra. strength 0..1+ (jab ≈ 0.3, fuerte ≈ 0.8, cargado/counter ≈ 1.0+).
## body = true: "thud" sordo al cuerpo; false: "smack" seco a la cabeza.
func play_hit(strength: float, body: bool) -> void:
	var s: float = maxf(strength, 0.0)
	var tier: int = SfxSynth.tier_for(s)
	var id: String = ("hit_body_" if body else "hit_head_") + str(tier)
	var base: float = VOL_HIT_BODY if body else VOL_HIT_HEAD
	var vol: float = base + lerpf(-6.0, 1.5, clampf(s / 1.1, 0.0, 1.0))
	_play(id, vol, _strength_pitch(s, tier), 0.06, 1.5)


## Golpe bloqueado en los guantes.
func play_block(strength: float) -> void:
	var s: float = maxf(strength, 0.0)
	var tier: int = SfxSynth.tier_for(s)
	var vol: float = VOL_BLOCK + lerpf(-4.0, 1.0, clampf(s / 1.1, 0.0, 1.0))
	_play("block_" + str(tier), vol, _strength_pitch(s, tier), 0.05, 1.5)


## Golpe al aire.
func play_whoosh(strength: float) -> void:
	var s: float = maxf(strength, 0.0)
	var tier: int = SfxSynth.tier_for(s)
	var vol: float = VOL_WHOOSH + lerpf(-3.0, 1.0, clampf(s / 1.1, 0.0, 1.0))
	_play("whoosh_" + str(tier), vol, _strength_pitch(s, tier), 0.08, 1.5)


func play_guard_break() -> void:
	_play("guard_break", VOL_GUARD_BREAK, 1.0, 0.04, 1.0)


func play_dodge() -> void:
	_play("dodge", VOL_DODGE, 1.0, 0.08, 1.5)


func play_knockdown() -> void:
	_play("knockdown", VOL_KNOCKDOWN, 1.0, 0.03, 0.5)


## Campana del ring; `times` campanadas separadas por BELL_SPACING.
func play_bell(times: int = 1) -> void:
	_ring_bell()
	if times <= 1 or not is_inside_tree():
		return
	for i in range(1, times):
		get_tree().create_timer(BELL_SPACING * i).timeout.connect(_ring_bell)


## Ovación del público, de 1,4 a 2,9 s según la intensidad (0..1).
func play_crowd_cheer(intensity: float) -> void:
	var i: float = clampf(intensity, 0.0, 1.0)
	var tier: int = 0 if i < 0.4 else (1 if i < 0.75 else 2)
	_play("cheer_" + str(tier), VOL_CHEER + 6.0 * i, 1.0, 0.04, 1.0)


## Murmullo de público en loop, con fundido de entrada.
func start_crowd_ambience() -> void:
	_ensure_players()
	if not is_inside_tree():
		return
	_ambience_on = true
	if _ambience_tween != null:
		_ambience_tween.kill()
	if not _ambience.playing:
		_ambience.stream = SfxSynth.get_stream("ambience")
		_ambience.volume_db = -60.0
		_ambience.play(_rng.randf() * SfxSynth.AMBIENCE_LOOP_SECONDS)
	_ambience_tween = create_tween()
	_ambience_tween.tween_property(_ambience, "volume_db", VOL_AMBIENCE + _master_db, AMBIENCE_FADE)


## Apaga el murmullo con un fundido de salida.
func stop_crowd_ambience() -> void:
	_ambience_on = false
	if _ambience == null or not _ambience.playing:
		return
	if _ambience_tween != null:
		_ambience_tween.kill()
	if not is_inside_tree():
		_ambience.stop()
		return
	_ambience_tween = create_tween()
	_ambience_tween.tween_property(_ambience, "volume_db", -60.0, AMBIENCE_FADE * 0.5)
	_ambience_tween.tween_callback(_ambience.stop)


## Volumen general de estos efectos (se suma al de cada sonido). No toca el bus.
func set_master_volume_db(db: float) -> void:
	_master_db = db
	if _ambience == null or not _ambience.playing or not _ambience_on:
		return
	if _ambience_tween != null:
		_ambience_tween.kill()  # corta el fundido de entrada y salta al volumen nuevo
	_ambience.volume_db = VOL_AMBIENCE + _master_db


# --- Interno -------------------------------------------------------------------------------

## Corre en un hilo del WorkerThreadPool: solo genera; la caché se toca en el hilo principal.
func _warm_up_in_background() -> void:
	for id in _warm_ids:
		_store_built.call_deferred(id, SfxSynth.build(id))


func _store_built(id: String, stream: AudioStreamWAV) -> void:
	SfxSynth.store(id, stream)


func _ring_bell() -> void:
	_play("bell", VOL_BELL, 1.0, 0.01, 0.5)


## Dentro de un nivel, más fuerza = un poco más grave.
func _strength_pitch(s: float, tier: int) -> float:
	var center: float = [0.3, 0.75, 1.1][tier]
	return clampf(1.0 - (s - center) * 0.15, 0.88, 1.08)


func _play(id: String, volume_db: float, pitch: float, pitch_jitter: float, volume_jitter_db: float) -> void:
	_ensure_players()
	if not is_inside_tree():
		return
	var stream: AudioStreamWAV = SfxSynth.get_stream(id)
	if stream == null:
		return
	var index: int = _free_player_index()
	var p: AudioStreamPlayer = _players[index]
	p.stream = stream
	p.pitch_scale = pitch * (1.0 + _rng.randf_range(-pitch_jitter, pitch_jitter))
	p.volume_db = volume_db + _master_db + _rng.randf_range(-volume_jitter_db, volume_jitter_db) * 0.5
	p.play()
	_play_count += 1
	_started_at[index] = _play_count


## Un player libre; si están todos sonando, el que arrancó hace más tiempo.
func _free_player_index() -> int:
	var oldest: int = 0
	for i in _players.size():
		if not _players[i].playing:
			return i
		if _started_at[i] < _started_at[oldest]:
			oldest = i
	return oldest


func _ensure_players() -> void:
	if not _players.is_empty():
		return
	_started_at.resize(POOL_SIZE)
	_started_at.fill(0)
	for i in POOL_SIZE:
		var p := AudioStreamPlayer.new()
		p.name = "Sfx%d" % i
		p.bus = BUS
		add_child(p)
		_players.append(p)
	_ambience = AudioStreamPlayer.new()
	_ambience.name = "Ambience"
	_ambience.bus = BUS
	add_child(_ambience)
