class_name CharacterData
extends Resource
## Un personaje de la historia (entrenador, rival, familia, amigos): nombre, rol y color del
## retrato provisorio. Es contenido: se edita en el inspector (data/characters/).
##
## NO guarda la relación con el jugador: eso está en GameState.relations (de -100 a 100).

@export var id: StringName = &"character"
@export var name_key: String = "CHAR_X"
## Qué es para vos ("Tu entrenador", "Tu vieja"…).
@export var role_key: String = "CHAR_X_ROLE"
## Color del retrato provisorio (un cuadrado con la inicial hasta que haya arte).
@export var color: Color = Color(0.5, 0.5, 0.55)
