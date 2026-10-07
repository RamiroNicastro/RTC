# Boxeo RPG: guía para trabajar con IA en este proyecto

RPG de carrera de boxeo 2D para Android, hecho en Godot 4.7 con GDScript.
El plan aprobado y congelado está en [docs/PLAN_FINAL_V2.1.md](docs/PLAN_FINAL_V2.1.md). **No se rediseña:** cualquier cambio de diseño se consulta antes.
Las convenciones de código están en [docs/CONVENCIONES.md](docs/CONVENCIONES.md).

## Reglas inviolables

- **R1.** `PlayerInput`, `AIInput` y `DummyInput` controlan **exactamente el mismo** `Fighter`. El Fighter no sabe quién lo maneja: solo recibe un `FighterCommand` por tick.
- **R2.** El combate recibe un `FightSetup` y (a partir del Hito E3) devuelve un `FightResult`. **Nada dentro de `combat/` usa autoloads** ni conoce la carrera, la economía o la narrativa.

## Reglas de arquitectura

- **Tiempo:** la lógica del combate cuenta en **ticks** (números enteros) dentro de `_physics_process`, a 60 Hz fijos. 1 tick equivale a 1 frame a 60 FPS. Nunca se usa `delta` ni `Engine.time_scale` en la lógica del combate. Las conversiones van en `CombatTime`.
- **El orden de los ticks lo maneja `CombatScene`:** primero se leen los comandos de los dos peleadores y después se los avanza a ambos. Los Fighters no tienen `_physics_process` propio.
- **La lógica manda y la animación obedece.** Las hitboxes futuras se activan según los ticks del `MoveData`, nunca desde la animación.
- **La detección de impactos** pasa por `HitResolver` (desde el Hito B). Al principio mide distancia; más adelante usará hitboxes.
- **Autoloads:** solo `GameState`, `SaveManager` y `SceneRouter`, y recién en la Fase 2. **No hay EventBus**: se usan señales locales.
- **Datos estáticos** en Resources `.tres`. **Partidas guardadas** en JSON dentro de `user://`.
- **Textos visibles** con `tr("CLAVE")`. Se exceptúan el overlay de debug y la sandbox.
- **Placeholders** solamente: no se hace arte final antes de pasar la puerta del MVP.

## Forma de trabajo

- **Un hito por sesión.** Un hito se commitea solo después de que la persona lo probó en Godot y cumple el criterio de la sección 16 del plan.
- Al terminar un hito, se actualiza "Estado actual" en este archivo.

## Cómo validar sin abrir el editor (desde Git Bash)

```bash
GODOT="$HOME/Downloads/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe"
"$GODOT" --headless --path . --import                 # importar y regenerar el caché de clases
"$GODOT" --headless --path . --quit-after 300         # correr la sandbox unos segundos y ver errores
```

## Estado actual

- [x] Fase 0: proyecto configurado (1280×720, canvas_items + expand, sensor_landscape, 60 Hz, interpolación de física), git, docs.
- [ ] Fase 0: exportación a Android (la configura la persona; los pasos están en docs/ANDROID.md).
- [ ] **Hito A: movimiento, Fighter y rival quieto** ← en curso
- [ ] Hitos B, C, T, D, E1, E2, E3, F, G, H, I
