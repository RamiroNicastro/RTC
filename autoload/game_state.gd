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
	active = true
	changed.emit()


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
	var stats := {}
	for stat in STAT_NAMES:
		stats[String(stat)] = int(fighter.get(stat))
	return {
		"fighter": {
			"full_name": fighter.full_name,
			"nickname": fighter.nickname,
			"color": fighter.color.to_html(false),
			"wingspan": fighter.wingspan,
			"stats": stats,
		},
		"style_id": String(style_id),
		"money": money,
		"week": week,
		"tier": tier,
		"record": {"wins": wins, "losses": losses, "draws": draws, "kos": kos},
	}


func from_dict(d: Dictionary) -> void:
	var f: Dictionary = d.get("fighter", {})
	fighter = FighterData.new()
	fighter.full_name = str(f.get("full_name", ""))
	fighter.nickname = str(f.get("nickname", ""))
	fighter.color = Color.html(str(f.get("color", PlayerFighter.COLOR.to_html(false))))
	fighter.wingspan = clampf(float(f.get("wingspan", 0.0)), -1.0, 1.0)
	var stats: Dictionary = f.get("stats", {})
	for stat in STAT_NAMES:
		fighter.set(stat, clampi(int(stats.get(String(stat), 30)), 1, 100))
	style_id = StringName(str(d.get("style_id", "balanced")))
	money = int(d.get("money", START_MONEY))
	week = maxi(0, int(d.get("week", 0)))
	tier = clampi(int(d.get("tier", 1)), 1, 6)
	var rec: Dictionary = d.get("record", {})
	wins = int(rec.get("wins", 0))
	losses = int(rec.get("losses", 0))
	draws = int(rec.get("draws", 0))
	kos = int(rec.get("kos", 0))
	active = true
	changed.emit()


## Deja el estado vacío (por ejemplo, al volver al título).
func clear() -> void:
	active = false
	fighter = FighterData.new()
	changed.emit()
