extends Node
## Autoload: cambia de pantalla. Todas las rutas de escenas del juego (fuera del combate) están acá.
##
## NO guarda la partida ni toca GameState: solo navega.

const TITLE: String = "res://ui/title/title_screen.tscn"
const CREATE_FIGHTER: String = "res://ui/create_fighter/create_fighter_screen.tscn"
const HUB: String = "res://career/hub/hub_screen.tscn"
const ARENA: String = "res://career/arena/arena_screen.tscn"
const ARCADE: String = "res://modes/arcade/arcade_run.tscn"
const PRACTICE: String = "res://debug/combat_sandbox.tscn"


func go(scene_path: String) -> void:
	get_tree().change_scene_to_file(scene_path)


func go_title() -> void:
	go(TITLE)


func go_hub() -> void:
	go(HUB)
