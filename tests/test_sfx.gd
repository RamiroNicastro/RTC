extends SceneTree
## Prueba automática de los sonidos procedurales: cada stream de SfxSynth se genera, dura algo
## razonable, no está vacío ni hace clipping, queda en caché; y todos los métodos de CombatSfx
## se pueden llamar (incluidas las campanadas diferidas, el fundido del ambiente y la generación
## en segundo plano).
##
## NO escucha los sonidos: solo mide. Para oírlos hay que correr el juego.

const MAX_SECONDS: float = 4.0
const MAX_AMBIENCE_SECONDS: float = 10.0
## Cuánto tiempo real dejamos correr el árbol para que disparen los timers de la campana.
const WAIT_MSEC: int = 1300
## Tope extra para que termine la generación en segundo plano de CombatSfx.
const WARM_TIMEOUT_MSEC: int = 20000

var failures: PackedStringArray = []
var phase: int = 0
var sfx: CombatSfx
var wait_until: int = 0


func _process(_delta: float) -> bool:
	match phase:
		0:
			phase = 1
			test_streams()
			test_tiers()
			test_combat_sfx_calls()
			wait_until = Time.get_ticks_msec() + WAIT_MSEC
		1:
			var all_cached: bool = true
			for id in SfxSynth.ALL_IDS:
				all_cached = all_cached and SfxSynth.is_cached(id)
			var now: int = Time.get_ticks_msec()
			if now < wait_until or (not all_cached and now < wait_until + WARM_TIMEOUT_MSEC):
				return false
			check(all_cached, "la generación en segundo plano no terminó")
			phase = 2
			test_after_wait()
			print("RESULTADO: ", "OK" if failures.is_empty() else "FALLÓ:\n  " + "\n  ".join(failures))
			quit()
	return phase == 2


func check(cond: bool, msg: String) -> void:
	if not cond:
		failures.append(msg)


func test_streams() -> void:
	SfxSynth.clear_cache()
	var t0: int = Time.get_ticks_msec()
	for id in SfxSynth.ALL_IDS:
		var t: int = Time.get_ticks_msec()
		var s: AudioStreamWAV = SfxSynth.get_stream(id)
		check(s != null, id + ": no se generó")
		if s == null:
			continue
		var length: float = s.get_length()
		var peak: float = SfxSynth.measure_peak(s)
		print("  %-12s %5.2f s  pico %.3f  %d Hz  (%d ms)" % [id, length, peak, s.mix_rate, Time.get_ticks_msec() - t])
		check(s.format == AudioStreamWAV.FORMAT_16_BITS and not s.stereo, id + ": no es 16 bits mono")
		check(s.data.size() > 0 and length > 0.1, id + ": vacío o demasiado corto (%.3f s)" % length)
		var max_len: float = MAX_AMBIENCE_SECONDS if id == "ambience" else MAX_SECONDS
		check(length < max_len, id + ": demasiado largo (%.2f s)" % length)
		check(peak <= 1.0 and peak < 0.99, id + ": clipping (pico %.3f)" % peak)
		check(peak > 0.1, id + ": casi en silencio (pico %.3f)" % peak)
		check(SfxSynth.get_stream(id) == s, id + ": no quedó en caché")
		if id == "ambience":
			check(s.loop_mode == AudioStreamWAV.LOOP_FORWARD and s.loop_end == s.data.size() / 2,
					"ambience: el loop no cubre todo el stream")
			check(absf(_sample(s, 0) - _sample(s, s.data.size() / 2 - 1)) < 0.15,
					"ambience: el loop tiene un salto entre el final y el principio")
		else:
			check(s.loop_mode == AudioStreamWAV.LOOP_DISABLED, id + ": no debería estar en loop")
			# Arranque y final en silencio: sin clicks.
			check(absf(_sample(s, 0)) < 0.02, id + ": arranca con un click")
			check(absf(_sample(s, s.data.size() / 2 - 1)) < 0.02, id + ": termina cortado")
	print("Generación total: %d ms" % (Time.get_ticks_msec() - t0))


func test_tiers() -> void:
	check(SfxSynth.tier_for(0.3) == 0 and SfxSynth.tier_for(0.8) == 1 and SfxSynth.tier_for(1.0) == 2,
			"niveles de fuerza mal mapeados")
	# Más fuerza = más largo.
	for base in ["hit_head", "hit_body", "block", "whoosh", "cheer"]:
		var a: float = SfxSynth.get_stream(base + "_0").get_length()
		var c: float = SfxSynth.get_stream(base + "_2").get_length()
		check(c > a, base + ": el nivel fuerte debería durar más que el suave")


func test_combat_sfx_calls() -> void:
	SfxSynth.clear_cache()  # para que CombatSfx tenga que generar en segundo plano
	sfx = CombatSfx.new()
	root.add_child(sfx)
	check(sfx._players.size() == CombatSfx.POOL_SIZE, "el pool no tiene %d players" % CombatSfx.POOL_SIZE)
	for p in sfx._players:
		check(p.bus == &"Master", "un player no usa el bus Master")
	sfx.set_master_volume_db(-3.0)
	for s in [0.0, 0.3, 0.8, 1.0, 1.4, -1.0]:
		sfx.play_hit(s, false)
		sfx.play_hit(s, true)
		sfx.play_block(s)
		sfx.play_whoosh(s)
	sfx.play_guard_break()
	sfx.play_dodge()
	sfx.play_knockdown()
	sfx.play_bell()
	sfx.play_bell(3)
	sfx.play_crowd_cheer(0.2)
	sfx.play_crowd_cheer(0.6)
	sfx.play_crowd_cheer(1.0)
	sfx.start_crowd_ambience()
	sfx.start_crowd_ambience()  # dos veces seguidas no debería romper nada
	sfx.set_master_volume_db(0.0)
	# Pool: con streams ya generados, 8 golpes seguidos ocupan los 8 players y el 9.º roba el más viejo.
	# (Se mide recién acá porque mientras se generaba lo anterior el audio siguió corriendo.)
	for i in CombatSfx.POOL_SIZE:
		sfx.play_hit(0.8, i % 2 == 0)
	var playing: int = 0
	for p in sfx._players:
		if p.playing:
			playing += 1
	check(playing == CombatSfx.POOL_SIZE, "con muchos sonidos a la vez deberían sonar todos los players (%d)" % playing)
	var oldest: int = 0
	for i in sfx._players.size():
		if sfx._started_at[i] < sfx._started_at[oldest]:
			oldest = i
	sfx.play_dodge()
	check(sfx._players[oldest].stream == SfxSynth.get_stream("dodge"), "con el pool lleno no se reusó el player más viejo")
	check(sfx._ambience.playing, "el ambiente no arrancó")
	check(sfx._ambience.stream.loop_mode == AudioStreamWAV.LOOP_FORWARD, "el ambiente no está en loop")
	# Un CombatSfx fuera del árbol no debe tirar errores: simplemente no suena.
	var loose := CombatSfx.new()
	loose.play_hit(0.5, false)
	loose.play_bell(2)
	loose.start_crowd_ambience()
	loose.stop_crowd_ambience()
	loose.free()


func test_after_wait() -> void:
	check(sfx._ambience.playing, "el ambiente se cortó solo")
	check(sfx._ambience.volume_db > -30.0, "el fundido de entrada del ambiente no subió (%.1f dB)" % sfx._ambience.volume_db)
	var bells: int = 0
	for p in sfx._players:
		if p.playing and p.stream == SfxSynth.get_stream("bell"):
			bells += 1
	check(bells >= 2, "las campanadas diferidas no sonaron (%d)" % bells)
	sfx.stop_crowd_ambience()
	sfx.free()


func _sample(s: AudioStreamWAV, i: int) -> float:
	return s.data.decode_s16(i * 2) / 32768.0
