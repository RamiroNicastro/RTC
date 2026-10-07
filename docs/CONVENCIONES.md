# Convenciones de código

## Nombres
- Archivos y carpetas en `snake_case`: `fighter_command.gd`, `combat_scene.tscn`.
- `class_name` en `PascalCase`: `FighterCommand`, `CombatScene`.
- Variables y funciones en `snake_case`. Lo privado empieza con `_`: `_tick_neutral()`.
- Constantes en `MAYUSCULAS`: `TICKS_PER_SECOND`.
- Señales en pasado: `state_changed`, `hit_landed`.
- Los nombres en el código van en inglés. Los comentarios y la documentación, en español.

## GDScript
- **Tipado estático siempre:** `var hp: int = 100` y `func tick(cmd: FighterCommand) -> void`.
- Cada script empieza con un comentario `##` que dice **qué es** y **qué NO hace**.
- Los valores que se van a balancear se marcan con `@export` en un Resource, para no tener números mágicos sueltos en la lógica.
- Las máquinas de estado se escriben con un `enum` y un `match`, sin frameworks.
- Indentación con tabs (la de Godot por defecto).

## Unidades
- **Distancias:** unidades de mundo (1 unidad equivale a 1 píxel a zoom 1 con la ventana de 720 de alto).
- **Velocidades** en el inspector: unidades por segundo. Se convierten a unidades por tick con `CombatTime.SECONDS_PER_TICK`.
- **Timings de golpes:** en ticks (1 tick equivale a 1 frame a 60 FPS).
- **Dirección relativa:** en un `FighterCommand`, `move = +1` significa **avanzar hacia el rival** y `-1` **retroceder**, sin importar el lado de la pantalla.

## Carpetas
- `combat/`: todo el combate. No importa nada de `career/`, `narrative/` ni de los autoloads.
- `debug/`: escenas y herramientas de prueba. Pueden usar cualquier cosa, pero nada del juego depende de ellas.
- `data/`: Resources `.tres` de contenido (golpes, perfiles de IA, etc.).
- `docs/`: el plan y las guías.
