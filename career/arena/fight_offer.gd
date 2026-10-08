class_name FightOffer
extends RefCounted
## Una oferta de pelea de la Arena: contra quién, qué tan difícil, por cuánta plata.
## Solo datos (se guarda en GameState.offers con to_dict). Las cuentas están en ArenaRules.

enum Level { EASY, EVEN, HARD }
enum Kind {
	## Una de varias cartas para elegir.
	CHOICE,
	## "Te toca": la única pelea de la semana; se acepta o se rechaza.
	ASSIGNED,
}

## Estilos de IA posibles (id → recurso).
const PROFILES: Dictionary = {
	"pressure": preload("res://data/ai_profiles/pressure.tres"),
	"outboxer": preload("res://data/ai_profiles/outboxer.tres"),
	"counter": preload("res://data/ai_profiles/counter.tres"),
}

var kind: Kind = Kind.CHOICE
var level: Level = Level.EVEN
var rival: FighterData = FighterData.new()
var profile_id: String = "pressure"
var ai_difficulty: AIInput.Difficulty = AIInput.Difficulty.EASY
## Puesto del rival en el ranking amateur.
var rank: int = 30
var wins: int = 0
var losses: int = 0
var draws: int = 0
var kos: int = 0
## Bolsa si ganás (antes de bonus).
var purse: int = 0
var rounds: int = 3


func profile() -> AIProfile:
	return PROFILES.get(profile_id, PROFILES["pressure"])


## "\"Apodo\" Apellido" para el HUD y las cartas.
func display_name() -> String:
	var last: String = rival.full_name.get_slice(" ", rival.full_name.get_slice_count(" ") - 1)
	return "\"%s\" %s" % [rival.nickname, last] if not rival.nickname.is_empty() else rival.full_name


func record_text() -> String:
	return "%d-%d-%d" % [wins, losses, draws]


func to_dict() -> Dictionary:
	return {
		"kind": kind,
		"level": level,
		"rival": rival.to_dict(),
		"profile_id": profile_id,
		"ai_difficulty": ai_difficulty,
		"rank": rank,
		"record": {"wins": wins, "losses": losses, "draws": draws, "kos": kos},
		"purse": purse,
		"rounds": rounds,
	}


static func from_dict(d: Dictionary) -> FightOffer:
	var o := FightOffer.new()
	o.kind = clampi(int(d.get("kind", Kind.CHOICE)), 0, Kind.size() - 1) as Kind
	o.level = clampi(int(d.get("level", Level.EVEN)), 0, Level.size() - 1) as Level
	o.rival = FighterData.from_dict(d.get("rival", {}), 30)
	o.profile_id = str(d.get("profile_id", "pressure"))
	if not PROFILES.has(o.profile_id):
		o.profile_id = "pressure"
	o.ai_difficulty = clampi(int(d.get("ai_difficulty", 0)), 0, AIInput.Difficulty.size() - 1) as AIInput.Difficulty
	o.rank = maxi(1, int(d.get("rank", 30)))
	var rec: Dictionary = d.get("record", {})
	o.wins = int(rec.get("wins", 0))
	o.losses = int(rec.get("losses", 0))
	o.draws = int(rec.get("draws", 0))
	o.kos = int(rec.get("kos", 0))
	o.purse = maxi(0, int(d.get("purse", 0)))
	o.rounds = clampi(int(d.get("rounds", 3)), 1, 12)
	return o
