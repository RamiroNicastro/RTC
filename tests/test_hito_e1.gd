extends SceneTree
# Prueba automática del Hito E1: knockdown, cuenta, levantarse, KO y TKO.

class Scripted extends FighterController:
	var jab_next: bool = false
	## Si es > 0, cuando está en el piso toca cada tantos ticks para levantarse.
	var mash_every: int = 0
	var _t: int = 0

	func get_command(me: Fighter, _op: Fighter) -> FighterCommand:
		var c := FighterCommand.new()
		if me.state == Fighter.State.KNOCKDOWN and mash_every > 0:
			_t += 1
			c.jab = _t % mash_every == 0
		else:
			c.jab = jab_next
			jab_next = false
		return c


var failures: PackedStringArray = []
var done: bool = false


func _process(_delta: float) -> bool:
	if done:
		return true
	done = true
	test_knockdown_and_rise()
	test_ko()
	test_tko()
	test_no_get_up_without_tapping_fast()
	print("RESULTADO: ", "OK" if failures.is_empty() else "FALLÓ:\n  " + "\n  ".join(failures))
	quit()
	return true


func check(cond: bool, msg: String) -> void:
	if not cond:
		failures.append(msg)


func new_combat() -> Array:
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
	s.start_distance = 140.0
	combat.start(s)
	var sa := Scripted.new()
	var sb := Scripted.new()
	combat.controller_a = sa
	combat.controller_b = sb
	return [combat, sa, sb]


func step(combat: CombatScene, n: int = 1) -> void:
	for i in n:
		combat._physics_process(0.0)


func dispose(combat: CombatScene) -> void:
	root.remove_child(combat)
	combat.free()


## Deja al rival con poca vida y lo tira con un jab.
func knock_down_b(combat: CombatScene, sa: Scripted) -> void:
	combat.fighter_b.health = 3
	sa.jab_next = true
	step(combat, 8)


func test_knockdown_and_rise() -> void:
	var r := new_combat()
	var combat: CombatScene = r[0]
	var sa: Scripted = r[1]
	var sb: Scripted = r[2]
	var a := combat.fighter_a
	var b := combat.fighter_b
	sb.mash_every = 6   # 10 toques por segundo
	knock_down_b(combat, sa)
	check(b.state == Fighter.State.KNOCKDOWN, "con 0 de vida debería caer")
	check(combat.fight.phase == FightManager.Phase.COUNT, "debería empezar la cuenta")
	# Mientras cuenta, el que está parado termina el golpe que ya tiró, pero no puede empezar otro.
	while a.state == Fighter.State.ATTACKING:
		step(combat)
	sa.jab_next = true
	step(combat, 3)
	check(a.state == Fighter.State.IDLE, "durante la cuenta el que está parado no puede empezar un golpe")
	var rose_at := -1
	for t in 600:
		step(combat)
		if b.state == Fighter.State.IDLE:
			rose_at = t
			break
	print("Knockdown: se levantó a la cuenta de %d con %d de vida (caídas: %d)" % [combat.fight.count, b.health, b.knockdowns])
	check(rose_at >= 0, "tocando rápido debería levantarse")
	check(b.health == 40, "la primera vez se levanta con 40 de vida")
	check(combat.fight.count >= FightManager.MIN_COUNT_TO_RISE, "no se levanta antes de la cuenta mínima")
	check(combat.fight.phase == FightManager.Phase.RESUME, "después de levantarse viene el cartel de ¡boxeen!")
	step(combat, FightManager.RESUME_TICKS + 1)
	check(combat.fight.phase == FightManager.Phase.FIGHTING, "después del cartel se sigue peleando")
	check(b.state == Fighter.State.IDLE, "los toques para levantarse no deberían convertirse en un golpe")
	dispose(combat)


func test_ko() -> void:
	var r := new_combat()
	var combat: CombatScene = r[0]
	var ended := []
	combat.fight.fight_ended.connect(func(w: Fighter, m: FightManager.Method) -> void: ended.append([w, m]))
	knock_down_b(combat, r[1])     # el rival no toca nada
	step(combat, FightManager.COUNT_TICKS_PER_NUMBER * FightManager.COUNT_OUT + 5)
	print("Sin levantarse: fase %s, cuenta %d, estado del rival %s" % [
		FightManager.Phase.keys()[combat.fight.phase], combat.fight.count, Fighter.State.keys()[combat.fighter_b.state]])
	check(ended.size() == 1 and ended[0][1] == FightManager.Method.KO and ended[0][0] == combat.fighter_a, "a la cuenta de 10 es KO para el jugador")
	check(combat.fighter_b.state == Fighter.State.KO, "el rival queda KO en el piso")
	dispose(combat)


func test_tko() -> void:
	var r := new_combat()
	var combat: CombatScene = r[0]
	var sa: Scripted = r[1]
	var sb: Scripted = r[2]
	sb.mash_every = 3
	var ended := []
	combat.fight.fight_ended.connect(func(w: Fighter, m: FightManager.Method) -> void: ended.append(m))
	for i in 3:
		knock_down_b(combat, sa)
		if i < 2:
			for t in 900:
				step(combat)
				if combat.fight.phase == FightManager.Phase.FIGHTING:
					break
	print("Tres caídas: %s, caídas del rival %d" % [
		FightManager.Method.keys()[ended[0]] if ended.size() > 0 else "sin final", combat.fighter_b.knockdowns])
	check(ended == [FightManager.Method.TKO], "a la tercera caída es KO técnico")
	dispose(combat)


func test_no_get_up_without_tapping_fast() -> void:
	var r := new_combat()
	var combat: CombatScene = r[0]
	r[2].mash_every = 60   # 1 toque por segundo: la barra se vacía más rápido de lo que se llena
	knock_down_b(combat, r[1])
	step(combat, FightManager.COUNT_TICKS_PER_NUMBER * FightManager.COUNT_OUT + 5)
	print("Tocando lento (1 por segundo): estado del rival %s" % Fighter.State.keys()[combat.fighter_b.state])
	check(combat.fighter_b.state == Fighter.State.KO, "tocando muy lento no debería poder levantarse")
	dispose(combat)
