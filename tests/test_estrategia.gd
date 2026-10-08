extends SceneTree
# Prueba automática de la ampliación estratégica: distancia justa, impulso, empuje, fuerte cargado
# y la IA que lee los patrones del jugador.

class Scripted extends FighterController:
	var move: int = 0
	var guard: bool = false
	var jab_next: bool = false
	var power_next: bool = false
	var power_held: bool = false

	func get_command(_me: Fighter, _op: Fighter) -> FighterCommand:
		var c := FighterCommand.new()
		c.move = move
		c.guard = guard
		c.jab = jab_next
		c.power = power_next
		c.power_held = power_held
		jab_next = false
		power_next = false
		return c


## Atacante que se acerca y tira golpes a intervalos irregulares: solo jabs, o variando.
class Prodder extends FighterController:
	var vary: bool = false
	var rng := RandomNumberGenerator.new()
	var _next: int = 30
	var _t: int = 0
	var _i: int = 0

	func get_command(me: Fighter, op: Fighter) -> FighterCommand:
		_t += 1
		var c := FighterCommand.new()
		var gap: float = absf(op.position.x - me.position.x) - me.half_width() - op.half_width()
		if gap > 70.0:
			c.move = 1
		if _t >= _next and gap <= 100.0:
			_next = _t + rng.randi_range(40, 70)
			_i += 1
			if not vary or _i % 3 == 0:
				c.jab = true
			elif _i % 3 == 1:
				c.power = true
			else:
				c.jab = true
				c.body = true
		return c


var failures: PackedStringArray = []
var done: bool = false


func _process(_delta: float) -> bool:
	if done:
		return true
	done = true
	test_sweet_spot()
	test_momentum_and_lunge()
	test_knockback()
	test_charged_power()
	test_ai_reads_patterns()
	print("RESULTADO: ", "OK" if failures.is_empty() else "FALLÓ:\n  " + "\n  ".join(failures))
	quit()
	return true


func check(cond: bool, msg: String) -> void:
	if not cond:
		failures.append(msg)


func new_combat(gap: float) -> Array:
	var combat: CombatScene = load("res://combat/combat_scene.tscn").instantiate()
	root.add_child(combat)
	combat.set_physics_process(false)
	var s := FightSetup.new()
	s.start_with_intro = false
	s.game_feel = false
	s.fighter_a = FighterSetup.new()
	s.fighter_a.max_health = 100  # las cuentas de esta prueba están hechas sobre 100
	s.fighter_a.cut_susceptibility = 0.0  # sin cortes al azar: esta prueba mide otra cosa
	s.fighter_b = FighterSetup.new()
	s.fighter_b.max_health = 100  # las cuentas de esta prueba están hechas sobre 100
	s.fighter_b.cut_susceptibility = 0.0  # sin cortes al azar: esta prueba mide otra cosa
	s.start_distance = gap + 90.0
	combat.start(s)
	var sa := Scripted.new()
	var sb := Scripted.new()
	combat.controller_a = sa
	combat.controller_b = sb
	var infos: Array[HitInfo] = []
	combat.hit_resolved.connect(func(i: HitInfo) -> void: infos.append(i))
	return [combat, sa, sb, infos]


func step(combat: CombatScene, n: int = 1) -> void:
	for i in n:
		combat._physics_process(0.0)


func dispose(combat: CombatScene) -> void:
	root.remove_child(combat)
	combat.free()


## Daño de un golpe tirado quieto a una distancia dada.
func damage_at(gap: float, power: bool) -> int:
	var r := new_combat(gap)
	var combat: CombatScene = r[0]
	if power:
		r[1].power_next = true
	else:
		r[1].jab_next = true
	step(combat, 30)
	var infos: Array[HitInfo] = r[3]
	var dmg: int = infos[0].damage if infos.size() > 0 else -1
	dispose(combat)
	return dmg


func test_sweet_spot() -> void:
	var jab_close: int = damage_at(0.0, false)
	var jab_tip: int = damage_at(95.0, false)
	var power_close: int = damage_at(10.0, true)
	var power_tip: int = damage_at(120.0, true)
	print("Distancia justa: jab pegado %d / jab en la punta %d   ·   fuerte de cerca %d / fuerte en la punta %d" % [
		jab_close, jab_tip, power_close, power_tip])
	check(jab_tip == 4 and jab_close <= 2, "el jab pega completo en la punta y poco pegado")
	check(power_close == 14 and power_tip <= 8, "el fuerte pega completo de cerca y poco en la punta")


func test_momentum_and_lunge() -> void:
	# Quieto.
	var still: int = damage_at(40.0, true)
	# Avanzando: camina 25 ticks hacia el rival y tira el fuerte.
	var r := new_combat(140.0)
	var combat: CombatScene = r[0]
	var sa: Scripted = r[1]
	sa.move = 1
	step(combat, 25)
	sa.move = 0
	var x_before: float = combat.fighter_a.position.x
	sa.power_next = true
	step(combat, 30)
	var infos: Array[HitInfo] = r[3]
	var forward: int = infos[0].damage if infos.size() > 0 else -1
	var lunge: float = combat.fighter_a.position.x - x_before
	dispose(combat)
	# Retrocediendo: camina hacia atrás y tira un jab.
	r = new_combat(60.0)
	combat = r[0]
	sa = r[1]
	sa.move = -1
	step(combat, 20)
	sa.move = 0
	combat.fighter_b.position.x = combat.fighter_a.position.x + 90.0 + 80.0
	sa.jab_next = true
	step(combat, 20)
	infos = r[3]
	var backward: HitInfo = infos[0] if infos.size() > 0 else null
	dispose(combat)
	print("Impulso: fuerte quieto %d, avanzando %d (paso adelante %.0f)   ·   jab retrocediendo: impulso %+d%%" % [
		still, forward, lunge, roundi((backward.momentum_mult - 1.0) * 100.0) if backward else 0])
	check(forward > still, "pegar avanzando debería hacer más daño")
	check(lunge > 15.0, "el fuerte avanzando debería adelantar un paso")
	check(backward != null and backward.momentum_mult < 0.8, "pegar retrocediendo debería restar daño")


func test_knockback() -> void:
	var r := new_combat(50.0)
	var combat: CombatScene = r[0]
	var b := combat.fighter_b
	var x0: float = b.position.x
	r[1].jab_next = true
	step(combat, 30)
	var jab_push: float = b.position.x - x0
	x0 = b.position.x
	combat.fighter_a.position.x = b.position.x - 140.0
	r[1].power_next = true
	step(combat, 40)
	var power_push: float = b.position.x - x0
	dispose(combat)
	# Contra la guardia empuja la mitad.
	r = new_combat(50.0)
	combat = r[0]
	r[2].guard = true
	step(combat, 2)
	x0 = combat.fighter_b.position.x
	r[1].power_next = true
	step(combat, 40)
	var blocked_push: float = combat.fighter_b.position.x - x0
	dispose(combat)
	# Contra las cuerdas no pasa de las cuerdas.
	r = new_combat(50.0)
	combat = r[0]
	var limit: float = combat.ring.half_width() - combat.fighter_b.half_width()
	combat.fighter_b.position.x = limit - 5.0
	combat.fighter_a.position.x = combat.fighter_b.position.x - 140.0
	r[1].power_next = true
	step(combat, 40)
	var at_rope: float = combat.fighter_b.position.x
	dispose(combat)
	print("Empuje: jab %.0f, fuerte %.0f, fuerte contra la guardia %.0f, contra las cuerdas queda en %.0f (límite %.0f)" % [
		jab_push, power_push, blocked_push, at_rope, limit])
	check(jab_push > 10.0 and power_push > jab_push * 2.0, "el fuerte empuja bastante más que el jab")
	check(absf(blocked_push - power_push * 0.5) < 6.0, "contra la guardia empuja la mitad")
	check(at_rope <= limit + 0.01, "las cuerdas frenan el empuje")


func test_charged_power() -> void:
	var r := new_combat(40.0)
	var combat: CombatScene = r[0]
	var sa: Scripted = r[1]
	# IA que no ataca (para medir solo la carga; en una pelea real, cargar cerca del rival es arriesgado).
	var passive: AIProfile = load("res://data/ai_profiles/counter.tres").duplicate()
	passive.aggression = 0.0
	passive.punish_chance = 0.0
	var ai := AIInput.new()
	ai.configure(passive, 1)
	combat.controller_b = ai
	sa.power_next = true
	sa.power_held = true
	var ai_reacted_while_charging := false
	# La carga arranca en el tick CHARGE_HOLD_TICK (zona muerta) y dura hasta 45 ticks.
	for i in Fighter.CHARGE_HOLD_TICK + 50:
		step(combat)
		# Desde que la IA "ve" la carga (su retraso + margen), no debería tener ninguna defensa pendiente.
		if i >= Fighter.CHARGE_HOLD_TICK + ai.reaction_ticks + 8 and combat.fighter_a.charging and (ai._guard_left > 0 or ai._dodge_in >= 0):
			ai_reacted_while_charging = true
	var ratio: float = combat.fighter_a.charge_ratio()
	sa.power_held = false
	step(combat, 30)
	var infos: Array[HitInfo] = r[3]
	print("Fuerte cargado: carga %d%%, resultado %s, daño %d (normal 14), empuje %.0f" % [
		roundi(ratio * 100.0), HitInfo.Result.keys()[infos[0].result] if infos.size() > 0 else "-",
		infos[0].damage if infos.size() > 0 else 0, infos[0].knockback if infos.size() > 0 else 0.0])
	check(is_equal_approx(ratio, 1.0), "manteniendo K se carga completo")
	check(not ai_reacted_while_charging, "la IA espera a que suelte la carga para reaccionar")
	if infos.size() > 0 and infos[0].result == HitInfo.Result.HIT:
		check(infos[0].damage >= 21, "el fuerte cargado completo debería hacer ~22")
	dispose(combat)


## Spamear el mismo golpe se vuelve cada vez más fácil de defender para la IA; variar no.
func test_ai_reads_patterns() -> void:
	var rates := {}
	for vary in [false, true]:
		var early := [0, 0]
		var late := [0, 0]
		for i in 3:
			var r := new_combat(150.0)
			var combat: CombatScene = r[0]
			var p := Prodder.new()
			p.vary = vary
			p.rng.seed = 600 + i
			combat.controller_a = p
			var ai := AIInput.new()
			ai.configure(load("res://data/ai_profiles/counter.tres"), 700 + i)
			combat.controller_b = ai
			var count := [0]
			combat.hit_resolved.connect(func(info: HitInfo) -> void:
				if info.attacker != combat.fighter_a:
					return
				count[0] += 1
				var bucket: Array = early if count[0] <= 6 else late
				bucket[1] += 1
				if info.result != HitInfo.Result.HIT:
					bucket[0] += 1)
			for t in 60 * 50:
				if combat.result != null:
					break
				combat._physics_process(0.0)
			dispose(combat)
		rates[vary] = [float(early[0]) / maxf(1, early[1]), float(late[0]) / maxf(1, late[1])]
	print("Lectura de patrones: spameando jab la IA defiende %d%% al principio → %d%% después   ·   variando: %d%% → %d%%" % [
		roundi(rates[false][0] * 100), roundi(rates[false][1] * 100), roundi(rates[true][0] * 100), roundi(rates[true][1] * 100)])
	check(rates[false][1] > rates[false][0] + 0.15, "spameando jab, la IA debería defenderlo cada vez mejor")
	check(rates[false][1] > rates[true][1] + 0.1, "variando, la IA debería defender menos que contra el spam")
