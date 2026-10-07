class_name ArcadeRecords
extends RefCounted
## Récords del Modo Arcade, guardados en JSON en user:// (como manda el plan para todo lo guardado).
##
## Escritura segura: primero a un archivo temporal y después se renombra.

## Ruta del archivo (las pruebas la cambian para no pisar los récords reales).
static var path: String = "user://arcade_records.json"
const SAVE_VERSION: int = 1

var best_score: int = 0
## Mejor etapa alcanzada (1 = primer rival, ladder.size() + 1 = campeón).
var best_stage: int = 0
var runs_played: int = 0
var championships: int = 0


static func load_records() -> ArcadeRecords:
	var r := ArcadeRecords.new()
	if not FileAccess.file_exists(path):
		return r
	var text: String = FileAccess.get_file_as_string(path)
	var data: Variant = JSON.parse_string(text)
	if data is Dictionary:
		r.best_score = int(data.get("best_score", 0))
		r.best_stage = int(data.get("best_stage", 0))
		r.runs_played = int(data.get("runs_played", 0))
		r.championships = int(data.get("championships", 0))
	return r


func save() -> void:
	var data := {
		"save_version": SAVE_VERSION,
		"best_score": best_score,
		"best_stage": best_stage,
		"runs_played": runs_played,
		"championships": championships,
	}
	var tmp: String = path + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		push_warning("No se pudieron guardar los récords del arcade.")
		return
	f.store_string(JSON.stringify(data, "\t"))
	f.close()
	DirAccess.rename_absolute(ProjectSettings.globalize_path(tmp), ProjectSettings.globalize_path(path))


## Registra el final de una partida. Devuelve true si es un récord nuevo de puntaje.
func register_run(score: int, stage_reached: int, champion: bool) -> bool:
	runs_played += 1
	if champion:
		championships += 1
	best_stage = maxi(best_stage, stage_reached)
	var is_record: bool = score > best_score
	if is_record:
		best_score = score
	save()
	return is_record
