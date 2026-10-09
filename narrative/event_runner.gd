class_name EventRunner
extends RefCounted
## Motor de eventos de la historia: elige qué evento sale, revisa sus condiciones, aplica la
## opción que eligió el jugador y maneja la moral, las relaciones y las situaciones que duran.
##
## Los eventos son datos JSON en data/events/ (formato explicado en docs/EVENTOS.md).
## Sus textos van en i18n/textos.csv con claves que salen del id:
##   EV_<ID>_TITLE, EV_<ID>_TEXT, EV_<ID>_1 (opción 1), EV_<ID>_1_RES (qué pasó)…
## Recibe el GameState como parámetro (`gs`) para poder probarlo sin depender del autoload.
## NO guarda en disco ni muestra nada: eso lo hacen EventBox y la pantalla que lo llama.

const EVENT_FILES: Array[String] = [
	"res://data/events/acto1.json",
	"res://data/events/vida.json",
	"res://data/events/barrio.json",
	"res://data/events/humor.json",
]
const CHARACTERS: Array[CharacterData] = [
	preload("res://data/characters/nono.tres"),
	preload("res://data/characters/tito.tres"),
	preload("res://data/characters/bruno.tres"),
	preload("res://data/characters/felipe.tres"),
	preload("res://data/characters/mama.tres"),
	preload("res://data/characters/ani.tres"),
	preload("res://data/characters/ramiro.tres"),
	preload("res://data/characters/agus.tres"),
	preload("res://data/characters/pampa.tres"),
	preload("res://data/characters/cosme.tres"),
	preload("res://data/characters/aurelio.tres"),
]
const STATUSES: Array[StatusData] = [
	preload("res://data/statuses/novia.tres"),
	preload("res://data/statuses/nono_enfermo.tres"),
	preload("res://data/statuses/amuleto.tres"),
	preload("res://data/statuses/turbo_toro.tres"),
]

## Momentos en que se buscan eventos:
## hub = al abrir el hub; week = al pasar la semana; fight = después de una pelea;
## chain = solo como continuación de otro evento ("next") o agendado ("schedule").
const TRIGGERS: Array[String] = ["hub", "week", "fight", "chain"]
## Probabilidad de que salga un evento secundario (los de historia no dependen del azar).
const SIDE_CHANCE: Dictionary = {"hub": 0.0, "week": 0.35, "fight": 0.6, "chain": 0.0}
## Resultados posibles de una pelea (condición "outcome").
const OUTCOMES: Array[String] = ["win", "win_ko", "loss", "loss_ko", "draw"]

const RELATION_MIN: int = -100
const RELATION_MAX: int = 100
## Cada semana la moral se acerca a 50 de a este paso (el ánimo se acomoda solo).
const MORALE_DRIFT: int = 2
const MORALE_NEUTRAL: int = 50

## Condiciones que entiende "when" (y "requires" en las opciones). Ver docs/EVENTOS.md.
const CONDITION_KEYS: Array[String] = [
	"min_week", "max_week", "min_age", "max_age", "min_money", "max_money",
	"min_morale", "max_morale", "min_energy", "best_rank", "worst_rank",
	"min_wins", "min_fights", "max_fights", "min_kos", "min_stat",
	"flags", "not_flags", "statuses", "not_statuses", "relation_min", "relation_max",
	"outcome", "chance",
]
const EFFECT_KEYS: Array[String] = [
	"money", "energy", "morale", "stats", "relations", "flags", "clear_flags",
	"add_status", "remove_status", "schedule", "next",
]
const EVENT_KEYS: Array[String] = ["id", "trigger", "story", "once", "cooldown", "weight", "character", "when", "options"]
const OPTION_KEYS: Array[String] = ["effects", "requires"]

## Eventos cargados (se leen una sola vez).
static var _events: Array = []


# --- Datos ---

static func events() -> Array:
	if _events.is_empty():
		for path in EVENT_FILES:
			var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
			if data is Array:
				_events.append_array(data)
			else:
				push_error("EventRunner: %s no es una lista de eventos válida." % path)
	return _events


static func find_event(id: String) -> Dictionary:
	for ev in events():
		if ev["id"] == id:
			return ev
	return {}


static func character(id: StringName) -> CharacterData:
	for c in CHARACTERS:
		if c.id == id:
			return c
	return null


static func status(id: StringName) -> StatusData:
	for s in STATUSES:
		if s.id == id:
			return s
	return null


## Claves de texto de un evento.
static func key(ev: Dictionary, part: String) -> String:
	return "EV_%s_%s" % [String(ev["id"]).to_upper(), part]


static func option_key(ev: Dictionary, index: int) -> String:
	return key(ev, str(index + 1))


static func result_key(ev: Dictionary, index: int) -> String:
	return key(ev, "%d_RES" % (index + 1))


# --- Elegir un evento ---

## Busca el evento que corresponde a este momento. Devuelve {} si no sale ninguno.
## Orden: primero lo agendado que ya venció (solo en "week"), después la historia (en el orden
## de los archivos) y, con la probabilidad de SIDE_CHANCE, uno secundario al azar según su peso.
## `context` lleva datos del momento (por ejemplo {"outcome": "win_ko"} después de una pelea).
static func pick(gs: Object, trigger: String, context: Dictionary = {}, rng: RandomNumberGenerator = null) -> Dictionary:
	if rng == null:
		rng = RandomNumberGenerator.new()
		rng.randomize()
	if trigger == "week":
		var due: Dictionary = _pop_due_scheduled(gs, context)
		if not due.is_empty():
			return due
	for ev in events():
		if ev.get("story", false) and ev.get("trigger", "") == trigger and is_available(gs, ev, context, rng):
			return ev
	if rng.randf() >= float(SIDE_CHANCE.get(trigger, 0.0)):
		return {}
	var pool: Array = []
	var total: float = 0.0
	for ev in events():
		if not ev.get("story", false) and ev.get("trigger", "") == trigger and is_available(gs, ev, context, rng):
			pool.append(ev)
			total += float(ev.get("weight", 1.0))
	var roll: float = rng.randf() * total
	for ev in pool:
		roll -= float(ev.get("weight", 1.0))
		if roll < 0.0:
			return ev
	return {} if pool.is_empty() else pool[-1]


## true si el evento puede salir ahora (no lo viste si es de una sola vez, pasó su espera y
## se cumplen sus condiciones). Con `rng`, también tira la probabilidad "chance".
static func is_available(gs: Object, ev: Dictionary, context: Dictionary = {}, rng: RandomNumberGenerator = null) -> bool:
	var id: String = ev["id"]
	if gs.events_seen.has(id):
		if ev.get("once", true):
			return false
		if gs.week - int(gs.events_seen[id]) < int(ev.get("cooldown", 0)):
			return false
	return conditions_met(gs, ev.get("when", {}), context, rng)


## Revisa un bloque de condiciones ("when" de un evento o "requires" de una opción).
static func conditions_met(gs: Object, when: Dictionary, context: Dictionary = {}, rng: RandomNumberGenerator = null) -> bool:
	var fights: int = gs.wins + gs.losses + gs.draws
	for k in when:
		var v: Variant = when[k]
		var ok: bool = true
		match k:
			"min_week": ok = gs.week >= int(v)
			"max_week": ok = gs.week <= int(v)
			"min_age": ok = gs.age() >= int(v)
			"max_age": ok = gs.age() <= int(v)
			"min_money": ok = gs.money >= int(v)
			"max_money": ok = gs.money <= int(v)
			"min_morale": ok = gs.morale >= int(v)
			"max_morale": ok = gs.morale <= int(v)
			"min_energy": ok = gs.energy >= int(v)
			"best_rank": ok = gs.rank <= int(v)
			"worst_rank": ok = gs.rank >= int(v)
			"min_wins": ok = gs.wins >= int(v)
			"min_fights": ok = fights >= int(v)
			"max_fights": ok = fights <= int(v)
			"min_kos": ok = gs.kos >= int(v)
			"min_stat":
				for stat in v:
					ok = ok and int(gs.fighter.get(stat)) >= int(v[stat])
			"flags":
				for f in v:
					ok = ok and gs.flags.has(f)
			"not_flags":
				for f in v:
					ok = ok and not gs.flags.has(f)
			"statuses":
				for s in v:
					ok = ok and gs.statuses.has(s)
			"not_statuses":
				for s in v:
					ok = ok and not gs.statuses.has(s)
			"relation_min":
				for c in v:
					ok = ok and gs.relations.has(c) and int(gs.relations[c]) >= int(v[c])
			"relation_max":
				for c in v:
					ok = ok and gs.relations.has(c) and int(gs.relations[c]) <= int(v[c])
			"outcome":
				var outcome: String = context.get("outcome", "")
				ok = outcome in (v as Array) if v is Array else outcome == v
			"chance":
				ok = rng == null or rng.randf() < float(v)
		if not ok:
			return false
	return true


## true si el jugador puede elegir esa opción (por ejemplo, si le alcanza la plata).
static func option_available(gs: Object, option: Dictionary) -> bool:
	return conditions_met(gs, option.get("requires", {}))


## true si la opción se muestra. Las que piden plata o energía se ven apagadas ("no te alcanza");
## las que dependen de la historia (marcas, relaciones…) directamente no aparecen hasta que se cumplan.
static func option_visible(gs: Object, option: Dictionary) -> bool:
	var story_req: Dictionary = option.get("requires", {}).duplicate()
	story_req.erase("min_money")
	story_req.erase("min_energy")
	return conditions_met(gs, story_req)


## Lo agendado que ya venció. Sale el primero cuyas condiciones se cumplan; los que ya no
## se cumplen se descartan (la historia siguió por otro lado).
static func _pop_due_scheduled(gs: Object, context: Dictionary) -> Dictionary:
	var keep: Array = []
	var found: Dictionary = {}
	for item in gs.scheduled:
		if not found.is_empty() or int(item["week"]) > gs.week:
			keep.append(item)
			continue
		var ev: Dictionary = find_event(item["id"])
		if not ev.is_empty() and conditions_met(gs, _without_chance(ev.get("when", {})), context):
			found = ev
	gs.scheduled = keep
	return found


static func _without_chance(when: Dictionary) -> Dictionary:
	var w: Dictionary = when.duplicate()
	w.erase("chance")
	return w


# --- Elegir una opción ---

## Aplica la opción `index` del evento y lo marca como visto. Devuelve un resumen para mostrar:
## {"money", "energy", "morale", "stats": {stat: n}, "relations": {id: n},
##  "added": [status], "removed": [status], "next": id del evento que sigue ya mismo ("" = ninguno)}.
static func choose(gs: Object, ev: Dictionary, index: int, rng: RandomNumberGenerator = null) -> Dictionary:
	var option: Dictionary = ev["options"][index]
	var fx: Dictionary = option.get("effects", {})
	var summary := {"money": 0, "energy": 0, "morale": 0, "stats": {}, "relations": {},
			"added": [], "removed": [], "next": ""}
	gs.events_seen[ev["id"]] = gs.week
	var who: String = ev.get("character", "")
	if who != "" and not gs.relations.has(who):
		gs.relations[who] = 0

	if fx.has("money"):
		gs.money += int(fx["money"])
		summary["money"] = int(fx["money"])
	if fx.has("energy"):
		var before: int = gs.energy
		gs.energy = clampi(gs.energy + int(fx["energy"]), 0, gs.MAX_ENERGY)
		summary["energy"] = gs.energy - before
	if fx.has("morale"):
		summary["morale"] = add_morale(gs, int(fx["morale"]))
	for stat in fx.get("stats", {}):
		var cur: int = gs.fighter.get(stat)
		var after: int = clampi(cur + int(fx["stats"][stat]), 1, 100)
		gs.fighter.set(stat, after)
		if after != cur:
			summary["stats"][stat] = after - cur
	for c in fx.get("relations", {}):
		summary["relations"][c] = add_relation(gs, c, int(fx["relations"][c]))
	for f in fx.get("flags", []):
		if not gs.flags.has(f):
			gs.flags.append(f)
	for f in fx.get("clear_flags", []):
		gs.flags.erase(f)
	for s in fx.get("add_status", {}):
		var weeks: int = int(fx["add_status"][s])
		gs.statuses[s] = weeks if weeks > 0 else -1
		summary["added"].append(s)
	for s in fx.get("remove_status", []):
		if gs.statuses.has(s):
			gs.statuses.erase(s)
			summary["removed"].append(s)
	if fx.has("schedule"):
		_schedule(gs, fx["schedule"], rng)
	summary["next"] = fx.get("next", "")
	gs.changed.emit()
	return summary


## Agenda un evento para dentro de N semanas. Con varios ids, sale uno al azar.
static func _schedule(gs: Object, sch: Dictionary, rng: RandomNumberGenerator) -> void:
	var ids: Array = sch["events"]
	if rng == null:
		rng = RandomNumberGenerator.new()
		rng.randomize()
	var id: String = ids[rng.randi_range(0, ids.size() - 1)]
	gs.scheduled.append({"id": id, "week": gs.week + int(sch.get("weeks", 1))})


# --- Moral, relaciones y situaciones ---

## Suma (o resta) moral entre 0 y el máximo. Devuelve lo que cambió de verdad.
static func add_morale(gs: Object, amount: int) -> int:
	var before: int = gs.morale
	gs.morale = clampi(gs.morale + amount, 0, gs.MAX_MORALE)
	return gs.morale - before


static func add_relation(gs: Object, who: String, amount: int) -> int:
	var before: int = int(gs.relations.get(who, 0))
	var after: int = clampi(before + amount, RELATION_MIN, RELATION_MAX)
	gs.relations[who] = after
	return after - before


## Al pasar la semana: la moral se acomoda hacia 50 y cada situación aplica lo suyo y descuenta
## una semana. Devuelve {"lines": [{"id", "morale", "energy", "money"}], "expired": [ids]}.
static func apply_week(gs: Object) -> Dictionary:
	if gs.morale > MORALE_NEUTRAL:
		gs.morale = maxi(MORALE_NEUTRAL, gs.morale - MORALE_DRIFT)
	elif gs.morale < MORALE_NEUTRAL:
		gs.morale = mini(MORALE_NEUTRAL, gs.morale + MORALE_DRIFT)
	var lines: Array = []
	var expired: Array = []
	for id in gs.statuses.keys():
		var s: StatusData = status(StringName(id))
		if s != null:
			add_morale(gs, s.weekly_morale)
			gs.energy = clampi(gs.energy + s.weekly_energy, 0, gs.MAX_ENERGY)
			gs.money += s.weekly_money
			if s.weekly_morale != 0 or s.weekly_energy != 0 or s.weekly_money != 0:
				lines.append({"id": id, "morale": s.weekly_morale, "energy": s.weekly_energy, "money": s.weekly_money})
		var left: int = int(gs.statuses[id])
		if left > 0:
			left -= 1
			if left == 0:
				gs.statuses.erase(id)
				expired.append(id)
			else:
				gs.statuses[id] = left
	return {"lines": lines, "expired": expired}


## Multiplicador de todas las situaciones activas para el gimnasio.
static func training_mult(gs: Object) -> float:
	var m: float = 1.0
	for id in gs.statuses:
		var s: StatusData = status(StringName(id))
		if s != null:
			m *= s.training_mult
	return m


## Multiplicador de todas las situaciones activas para la stamina en la pelea.
static func fight_stamina_mult(gs: Object) -> float:
	var m: float = 1.0
	for id in gs.statuses:
		var s: StatusData = status(StringName(id))
		if s != null:
			m *= s.fight_stamina_mult
	return m


# --- Revisión de los datos (la usan las pruebas) ---

## Revisa que los eventos estén bien escritos: claves conocidas, personajes y situaciones que
## existen, eventos encadenados o agendados que existen y textos en el CSV.
## Devuelve la lista de errores (vacía = todo bien). `has_text` dice si existe una clave de texto.
static func validate(has_text: Callable) -> PackedStringArray:
	var errors: PackedStringArray = []
	var ids := {}
	for ev in events():
		var id: String = ev.get("id", "")
		if id == "" or ids.has(id):
			errors.append("evento sin id o repetido: '%s'" % id)
		ids[id] = true
	for ev in events():
		var id: String = ev.get("id", "")
		for k in ev:
			if not k in EVENT_KEYS:
				errors.append("%s: clave desconocida '%s'" % [id, k])
		if not ev.get("trigger", "") in TRIGGERS:
			errors.append("%s: trigger desconocido '%s'" % [id, ev.get("trigger", "")])
		var who: String = ev.get("character", "")
		if who != "" and character(StringName(who)) == null:
			errors.append("%s: personaje desconocido '%s'" % [id, who])
		_validate_conditions(id, ev.get("when", {}), errors)
		for part in ["TITLE", "TEXT"]:
			if not has_text.call(key(ev, part)):
				errors.append("%s: falta el texto %s" % [id, key(ev, part)])
		var options: Array = ev.get("options", [])
		if options.is_empty():
			errors.append("%s: no tiene opciones" % id)
		for i in options.size():
			var o: Dictionary = options[i]
			for k in o:
				if not k in OPTION_KEYS:
					errors.append("%s opción %d: clave desconocida '%s'" % [id, i + 1, k])
			_validate_conditions(id, o.get("requires", {}), errors)
			for k in [option_key(ev, i), result_key(ev, i)]:
				if not has_text.call(k):
					errors.append("%s: falta el texto %s" % [id, k])
			var fx: Dictionary = o.get("effects", {})
			for k in fx:
				if not k in EFFECT_KEYS:
					errors.append("%s opción %d: efecto desconocido '%s'" % [id, i + 1, k])
			for stat in fx.get("stats", {}):
				if not StringName(stat) in FighterData.STAT_NAMES:
					errors.append("%s: estadística desconocida '%s'" % [id, stat])
			for c in fx.get("relations", {}):
				if character(StringName(c)) == null:
					errors.append("%s: personaje desconocido '%s'" % [id, c])
			for s in fx.get("add_status", {}).keys() + fx.get("remove_status", []):
				if status(StringName(s)) == null:
					errors.append("%s: situación desconocida '%s'" % [id, s])
			var linked: Array = fx.get("schedule", {}).get("events", []).duplicate()
			if fx.get("next", "") != "":
				linked.append(fx["next"])
			for l in linked:
				if not ids.has(l):
					errors.append("%s: lleva a un evento que no existe '%s'" % [id, l])
	for c in CHARACTERS:
		for k in [c.name_key, c.role_key]:
			if not has_text.call(k):
				errors.append("personaje %s: falta el texto %s" % [c.id, k])
	for s in STATUSES:
		for k in [s.name_key, s.desc_key]:
			if not has_text.call(k):
				errors.append("situación %s: falta el texto %s" % [s.id, k])
	return errors


static func _validate_conditions(id: String, when: Dictionary, errors: PackedStringArray) -> void:
	for k in when:
		if not k in CONDITION_KEYS:
			errors.append("%s: condición desconocida '%s'" % [id, k])
	for c in when.get("relation_min", {}).keys() + when.get("relation_max", {}).keys():
		if character(StringName(c)) == null:
			errors.append("%s: personaje desconocido '%s'" % [id, c])
	for s in when.get("statuses", []) + when.get("not_statuses", []):
		if status(StringName(s)) == null:
			errors.append("%s: situación desconocida '%s'" % [id, s])
	var outcome: Variant = when.get("outcome", null)
	if outcome != null:
		for o in (outcome as Array if outcome is Array else [outcome]):
			if not o in OUTCOMES:
				errors.append("%s: resultado de pelea desconocido '%s'" % [id, o])
