extends Node
## Autoload: los datos de la carrera en curso (tu peleador, plata, tiempo, récord).
##
## Solo guarda datos y reglas simples sobre ellos. NO guarda en disco (eso es SaveManager)
## y NO cambia de pantalla (eso es SceneRouter). El combate nunca lo lee (R2): la carrera
## arma un FightSetup con StatFormulas y después anota el FightResult acá.

signal changed

## Edad al empezar la carrera.
const START_AGE: int = 18
const WEEKS_PER_YEAR: int = 52
## Plata inicial (pesos del juego).
const START_MONEY: int = 500
## Un amateur arranca con este porcentaje de las estadísticas de su estilo
## (Equilibrado 50 → 30). Así hay lugar para crecer entrenando.
const START_STAT_RATIO: float = 0.6
## Las 6 estadísticas, en el orden en que se guardan y se muestran.
const STAT_NAMES: Array[StringName] = [&"power", &"speed", &"cardio", &"chin", &"technique", &"defense"]
const MAX_ENERGY: int = 100
const ACTIONS_PER_WEEK: int = 3
## Puesto inicial en el ranking amateur (1 = el mejor) y el peor posible.
const START_RANK: int = 30
const WORST_RANK: int = 40
## Moral (0 a MAX_MORALE). Con 50 no cambia nada; alta entrena mejor, baja entrena peor.
const START_MORALE: int = 60
const MAX_MORALE: int = 100

## true si hay una carrera cargada (nueva o continuada).
var active: bool = false
## Tu peleador: nombre, apodo, color y estadísticas actuales.
var fighter: FighterData = FighterData.new()
var style_id: StringName = &"balanced"
var money: int = 0
## Semanas jugadas desde el comienzo (0 = primera semana).
var week: int = 0
var tier: int = 1
var wins: int = 0
var losses: int = 0
var draws: int = 0
var kos: int = 0
## Energía (0 a MAX_ENERGY). Entrenar y trabajar la gastan; descansar la recupera.
var energy: int = MAX_ENERGY
## Acciones que quedan esta semana. Al llegar a 0 pasa la semana.
var actions_left: int = ACTIONS_PER_WEEK
## Lo que ya se entrenó pero todavía no llegó a un punto entero, por estadística (0 a 1).
var stat_progress: Dictionary = {}
## Puesto en el ranking amateur (1 = el mejor).
var rank: int = START_RANK
## Ofertas de pelea de esta semana (FightOffer.to_dict). Se generan una vez por semana.
var offers: Array = []
## Semana a la que corresponden las ofertas (-1 = ninguna todavía).
var offers_week: int = -1

## --- Historia (la maneja EventRunner) ---
var morale: int = START_MORALE
## Marcas de lo que decidiste en los eventos ("leal_tito", "sofi_conocida"…).
var flags: Array = []
## Relación con cada personaje que conociste: id → de -100 a 100.
var relations: Dictionary = {}
## Situaciones activas: id → semanas que quedan (-1 = hasta que un evento la saque).
var statuses: Dictionary = {}
## Eventos que ya salieron: id → semana en que salieron (para "una sola vez" y las esperas).
var events_seen: Dictionary = {}
## Eventos agendados para más adelante: [{"id", "week"}].
var scheduled: Array = []


## Arranca una carrera desde cero con el peleador que creó el jugador.
func new_career(player: PlayerFighter) -> void:
	fighter = player.to_fighter_data()
	for stat in STAT_NAMES:
		fighter.set(stat, maxi(1, roundi(int(fighter.get(stat)) * START_STAT_RATIO)))
	style_id = player.style_id
	money = START_MONEY
	week = 0
	tier = 1
	wins = 0
	losses = 0
	draws = 0
	kos = 0
	energy = MAX_ENERGY
	actions_left = ACTIONS_PER_WEEK
	stat_progress = {}
	rank = START_RANK
	offers = []
	offers_week = -1
	_reset_story()
	active = true
	changed.emit()


func _reset_story() -> void:
	morale = START_MORALE
	flags = []
	relations = {}
	statuses = {}
	events_seen = {}
	scheduled = []


func age() -> int:
	return START_AGE + week / WEEKS_PER_YEAR


## Semana dentro del año actual de la carrera (1 a 52).
func week_of_year() -> int:
	return week % WEEKS_PER_YEAR + 1


func display_name() -> String:
	if fighter.nickname.is_empty():
		return fighter.full_name
	return "\"%s\" %s" % [fighter.nickname, fighter.full_name]


func to_dict() -> Dictionary:
	return {
		"fighter": fighter.to_dict(),
		"style_id": String(style_id),
		"money": money,
		"week": week,
		"tier": tier,
		"record": {"wins": wins, "losses": losses, "draws": draws, "kos": kos},
		"energy": energy,
		"actions_left": actions_left,
		"stat_progress": stat_progress,
		"rank": rank,
		"offers": offers,
		"offers_week": offers_week,
		"morale": morale,
		"flags": flags,
		"relations": relations,
		"statuses": statuses,
		"events_seen": events_seen,
		"scheduled": scheduled,
	}


func from_dict(d: Dictionary) -> void:
	fighter = FighterData.from_dict(d.get("fighter", {}), 30)
	style_id = StringName(str(d.get("style_id", "balanced")))
	money = int(d.get("money", START_MONEY))
	week = maxi(0, int(d.get("week", 0)))
	tier = clampi(int(d.get("tier", 1)), 1, 6)
	var rec: Dictionary = d.get("record", {})
	wins = int(rec.get("wins", 0))
	losses = int(rec.get("losses", 0))
	draws = int(rec.get("draws", 0))
	kos = int(rec.get("kos", 0))
	energy = clampi(int(d.get("energy", MAX_ENERGY)), 0, MAX_ENERGY)
	actions_left = clampi(int(d.get("actions_left", ACTIONS_PER_WEEK)), 1, ACTIONS_PER_WEEK)
	stat_progress = {}
	var progress: Dictionary = d.get("stat_progress", {})
	for stat in STAT_NAMES:
		stat_progress[String(stat)] = clampf(float(progress.get(String(stat), 0.0)), 0.0, 0.999)
	rank = clampi(int(d.get("rank", START_RANK)), 1, WORST_RANK)
	offers = d.get("offers", [])
	offers_week = int(d.get("offers_week", -1))
	morale = clampi(int(d.get("morale", START_MORALE)), 0, MAX_MORALE)
	flags = d.get("flags", [])
	relations = {}
	var rel: Dictionary = d.get("relations", {})
	for who in rel:
		relations[who] = int(rel[who])
	statuses = {}
	var st: Dictionary = d.get("statuses", {})
	for id in st:
		statuses[id] = int(st[id])
	events_seen = {}
	var seen: Dictionary = d.get("events_seen", {})
	for id in seen:
		events_seen[id] = int(seen[id])
	scheduled = []
	for item in d.get("scheduled", []):
		scheduled.append({"id": str(item.get("id", "")), "week": int(item.get("week", 0))})
	active = true
	changed.emit()


## Deja el estado vacío (por ejemplo, al volver al título).
func clear() -> void:
	active = false
	fighter = FighterData.new()
	_reset_story()
	changed.emit()
