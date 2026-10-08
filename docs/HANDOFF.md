# Traspaso: cómo seguir este proyecto (para cualquier sesión de Claude)

> Leé esto **después** de [CLAUDE.md](../CLAUDE.md), donde están las reglas, el estado y las decisiones. El plan aprobado y congelado es [PLAN_FINAL_V2.1.md](PLAN_FINAL_V2.1.md).
> Este documento explica **dónde quedó todo, cómo está armado, qué trampas hay y qué sigue**, paso a paso.
> Última actualización: 08/10/2026.

---

## 1. La persona y cómo trabajar con ella

- Es principiante en programación y trabaja con IA. Escribe en español rioplatense. **Respondé en español claro, sin jerga**, y explicá qué hiciste y cómo probarlo.
- Quiere un juego **arcade, adictivo, fluido y estratégico** ("que no sea solo spamear"), con **realismo alcanzable**. Su referencia es *Bruisers 2D Boxing*. Le gustan la sangre y que los golpes tengan consecuencias.
- Juega en **Windows con el editor de Godot 4.7.2**. Todavía no puede instalar el SDK de Android (la PC es de trabajo).
- Cuando el editor no ve archivos nuevos, el juego "queda en gris". Recordale cerrar Godot y reabrirlo, o usar `jugar.bat`.
- **Los cambios de diseño se consultan con la persona.** Ella decide; vos proponés con una opción recomendada.
- Usa la herramienta de preguntas (AskUserQuestion) cuando hay que elegir.

## 2. Estado actual (resumen)

**Ya hecho y probado (en `main`):**
- Combate completo:
  - golpes: jab, fuerte (cargable), cuerpo, guardia, esquive, counter;
  - mecánicas: distancia justa, impulso, empuje, stamina y fatiga, golpe estrella, combo 1-2;
  - reglas: knockdowns, rounds, jueces, `FightResult`.
- IA con 3 estilos (presionador, técnico, contragolpeador) y 3 dificultades. Ve al rival con retraso y lee patrones.
- Sensación de impacto: hitstop, cámara lenta, sacudida, chispas, carteles, sangre visual, público, sonidos sintetizados.
- Peleadores articulados y animados (placeholder dibujado por código).
- Modo Arcade: título → 6 rivales con golpe propio y desafíos → puntaje → récords en JSON.
- Controles táctiles: 6 botones, deslizar hacia abajo para el cuerpo, safe area y modo zurdo.
- 17 archivos de pruebas automáticas, todos en OK.

**Pendiente del plan para cerrar la Fase 1 (MVP):**
- Exportar a Android y probar en un celular real (Hitos T e I). Lo bloquea la PC de la persona: ver [ANDROID.md](ANDROID.md).
- Puerta del MVP: 3 o 4 personas juegan en el celular y quieren repetir.

**Lo próximo que se acordó:** la **pasada de realismo** (cortes con efecto, cutman y médico). Ver la sección 7.

## 3. Mapa del código (qué hace cada cosa)

```
combat/                        TODO el combate (no usa autoloads; R2)
  combat_scene.gd/.tscn        raíz. Orden de cada tick: comandos → fighters → ring → golpes → árbitro → cámara.
                               Aplica game feel (_impact_feel), estadísticas, jueces y arma el FightResult.
  combat_clock.gd              reloj en ticks: pausa, hitstop (freeze) y cámara lenta (slow_motion)
  combat_time.gd               conversión ticks ↔ segundos (60 ticks = 1 s)
  fight_setup.gd               ENTRADA del combate (peleadores, rounds, round_seconds, game_feel…)
  fight_result.gd              SALIDA del combate (solo datos) + decide() para decisiones
  fight_manager.gd             árbitro: rounds, reloj, cuenta, KO/TKO, descanso
  fight_stats.gd               registro de eventos reales por round (lo usan jueces y resultado)
  fighter_setup.gd             datos de UN peleador para UNA pelea (salud 160, stamina, golpes, IA)
  fighter/fighter.gd           máquina de estados del peleador (TODA la lógica de pelea)
  fighter/fighter_visual.gd    dibujo articulado (solo lee; se dibuja en un solo lote)
  input/                       FighterCommand + controladores: PlayerInput, AIInput, DummyInput
  ai/ai_profile.gd             parámetros de un estilo de IA (los .tres están en data/ai_profiles)
  hit/                         HitResolver (por distancia) y HitInfo (resultado de un golpe)
  moves/move_data.gd           un golpe como dato (ticks, alcance, distancia justa, empuje, carga)
  judges/judge.gd              un juez (10-9 / 10-10 / 10-8) con pesos propios
  camera/combat_camera.gd      cámara: sigue, zoom suave, sacudida, foco en el KO
  fx/combat_fx.gd              chispas, carteles, sangre, avisos de golpe, marca de distancia justa
  fx/combat_sfx.gd             sonidos (pool de reproductores); fx/sfx_synth.gd los sintetiza
  hud/                         CombatHUD (barras, reloj, carteles), TouchControls, ResultScreen, PauseMenu
  ring.gd                      cuerdas y choque (la lógica de espacio) + escenario y público
data/moves/                    golpes .tres (jab, power, jab_body, power_body) y rivals/ (golpes del arcade)
data/ai_profiles/              pressure.tres, outboxer.tres, counter.tres
data/rivals/arcade/            fichas FighterData de los 6 rivales del arcade (estadísticas, estilo, golpe propio)
fighter_model/                 FighterData (ficha: 6 estadísticas 1-100 + envergadura) y StatFormulas (ficha → FighterSetup; 50 = valores de hoy)
                               FighterStyle (estilos del jugador, en data/fighter_styles/) y PlayerFighter (tu peleador, JSON en user://)
ui/create_fighter/             pantalla "Crear peleador" (nombre, apodo, estilo con barras de estadísticas)
ui/stat_bars.gd                barras de las 6 estadísticas (las usan "Crear peleador" y el hub)
autoload/                      GameState (datos de la carrera), SaveManager (JSON en user://slot_1.json + .bak), SceneRouter (rutas y cambio de pantalla)
career/hub/                    hub de la carrera: encabezado (nombre, semana, edad, plata, récord), estadísticas y 5 lugares
modes/arcade/                  Modo Arcade: arcade_run (flujo), arcade_rivals, arcade_score, arcade_records
ui/                            ui_style.gd (fuente y botones) y title/ (pantalla de título, escena principal)
debug/                         sandbox de práctica con overlay de debug (teclas en la cabecera del script)
i18n/textos.csv                TODOS los textos visibles (columnas keys, es, en). Se usan con tr("CLAVE").
tests/                         pruebas automáticas (ver sección 5) y balance_report.gd
tools/install_godot_linux.sh   Godot para Linux (sesiones en la nube)
jugar.bat                      abre el juego en Windows sin el editor
```

### Cómo fluye un golpe (para no perderse)
1. El controlador emite un `FighterCommand` (por ejemplo, `jab = true`).
2. `Fighter.tick()` lo guarda unos ticks (buffer) y arranca el golpe: STARTUP → ACTIVE → RECOVERY.
3. En ACTIVE, `CombatScene._check_hit()` llama a `HitResolver.resolve()`, que devuelve un `HitInfo` (HIT, BLOCKED, DODGED o WHIFF, más daño y empuje). El daño se calcula como base × cansancio × distancia × impulso × carga × counter × estrella.
4. `CombatScene._apply_hit()`:
   - `defender.receive_hit()` (daño, estados, knockdown);
   - `attacker.notify_attack_result()` (medidor de estrella, ventana del 1-2);
   - empuje, estadísticas, la señal `hit_resolved`, y `_impact_feel()` (hitstop, cámara, efectos, sonido).
5. Si hay knockdown, `FightManager.on_knockdown()` arranca la cuenta, y al final del round puntúan los jueces.

## 4. Números de balance actuales (y cómo medirlos)

| Concepto | Valor |
|---|---|
| Salud base | 160 (las pruebas fijan 100) |
| Daño profundo | 35 % de cada golpe baja la salud máxima |
| Jab | 4 de daño, arranque 6, activo 2, recuperación 10; zona justa 55–110; costo 4,5 (+2,5 si falla) |
| Fuerte | 14 de daño, arranque 16, alcance 100; zona justa 0–75; costo 13 (+5); rompe la guardia solo en la zona justa |
| Fuertes de los rivales del arcade | arranque de 20 a 24 (se ven venir) |
| Stamina | regeneración 18 por segundo tras 0,5 s; fatiga 10 % del gasto; cansado por debajo del 30 % |
| Estrella | ×1,6 de daño, rompe la guardia desde cualquier distancia, ×1,8 de empuje |
| Combo 1-2 | el fuerte arranca 6 ticks antes, durante 24 ticks después de un jab que conectó |
| IA en Normal | +2 ticks de reacción, bloqueo y castigo ×0,7, esquive ×0,9, lectura ×0,6 |
| IA en Fácil | +10 ticks de reacción, defensa ×0,5, lectura ×0,3, agresividad ×0,75 |
| Objetivo de balance (IA contra IA) | alrededor del 50 % por KO o TKO y todas llegan al round 3 |

Medir el balance (unos 2 minutos):

```
godot --headless --path . -s res://tests/balance_report.gd
```

## 5. Pruebas y cómo validar

- Todas: `bash tests/run_all.sh` (unos 10 a 12 minutos). Todas tienen que dar `RESULTADO: OK`.
  - Una sola: `"$GODOT" --headless --path . -s res://tests/test_X.gd`.
  - Ruta de Godot en Windows: `$HOME/Downloads/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe`.
  - En Linux: `GODOT=$(bash tools/install_godot_linux.sh) bash tests/run_all.sh`.
- **Cada prueba nueva** sigue el mismo formato:
  - `extends SceneTree`;
  - todo se hace en el primer `_process`;
  - el combate se instancia con `set_physics_process(false)` y los ticks se avanzan a mano con `combat._physics_process(0.0)`;
  - se usan controladores guionados (clases internas que extienden `FighterController`);
  - `FightSetup` va con `start_with_intro = false`, `game_feel = false` y `max_health = 100` (las cuentas de las pruebas asumen 100);
  - al final imprime `RESULTADO: OK` o `RESULTADO: FALLÓ: …`.
- **Capturas** para ver cómo se ve: un script `extends SceneTree` en una carpeta temporal, **sin `--headless`**, que cambia a la escena, simula input y guarda `root.get_texture().get_image().save_png(ruta)`.
- El aviso "ObjectDB instances were leaked at exit" que aparece al cerrar las pruebas es conocido y no afecta el resultado. Lo está revisando la auditoría.

## 6. Trampas conocidas (te van a ahorrar horas)

1. **Godot recién importado:** si hay archivos o clases nuevas, correr `"$GODOT" --headless --path . --import` antes de las pruebas.
2. **No usar `_initialize()` en los scripts de prueba para instanciar escenas:** los `@onready` todavía no existen. Usar el primer `_process`.
3. **Lambdas de GDScript:** capturan las variables enteras **por copia**. Para contadores usá un `Array` (por ejemplo, `var c := [0]`).
4. **En headless, `Input.parse_input_event` no procesa la cola.** Para toques usá `root.push_input(ev, true)`, con coordenadas locales.
5. **Editar archivos desde Bash:** en Windows, pasar un script de Python por la entrada estándar rompe los caracteres especiales (◀, á) y las comillas. Escribí el script a un archivo con la herramienta Write y corrélo con `python archivo.py`.
6. **El nombre `Popup` está reservado por Godot:** no lo uses para clases internas. Revisá también otros nombres nativos.
7. **`is_touchscreen_available()` da true en la PC** (por la emulación con mouse). Para detectar un celular usá `OS.has_feature("mobile")`.
8. **Las pruebas IA contra IA (F y G) dependen del balance.** Si cambiás números de daño, stamina o IA, volvé a correrlas y al reporte de balance. Ajustá criterios **solo** si lo que miden sigue siendo cierto.
9. **El editor de la persona puede pisar archivos** si los tenía abiertos. Si algo "volvió atrás", revisá `git diff`.
10. **Autoloads en las pruebas:** un script de prueba (`-s`) se compila ANTES de que existan `GameState`, `SaveManager` y `SceneRouter`. Si nombra por `class_name` a una clase que usa un autoload (por ejemplo `CreateFighterScreen`), falla al compilar. En la prueba, buscá los autoloads con `root.get_node("GameState")` y cargá esas pantallas por ruta (`load("res://...gd")`). Las escenas que se instancian en tiempo de ejecución no tienen problema.
11. **Las pruebas no pisan los guardados reales:** `SaveManager.folder`, `PlayerFighter.path` y `ArcadeRecords.path` se cambian al principio de cada prueba que guarda.

## 7. Próximos pasos (en orden)

### Hecho: auditoría de código (08/10)
Errores reales ya arreglados (prueba: `tests/test_auditoria.gd`):
- el botón Atrás de Android pausa (`quit_on_go_back=false`);
- intercambio justo: si los dos golpes tumbarían, los dos quedan con 1 de salud;
- la cámara lenta más larga no se pisa;
- la pausa no deja toques guardados;
- no salen golpes del buffer durante la cuenta;
- `await` seguros en `ResultScreen` y el arcade;
- `CombatSfx` frena el audio al salir (se acabó la "fuga" de las pruebas);
- el médico y el knockdown se procesan en orden.

### Auditoría pendiente (hacer cuando convenga, de mayor a menor impacto)
1. **Rendimiento en celular:**
   - `Ring._draw` redibuja unas 230 siluetas de público por frame: pasar el escenario fijo a un nodo que se dibuje una vez, y el público a un único arreglo de triángulos (como `FighterVisual`) o a unos 20 Hz;
   - `CombatFX` crea arreglos nuevos con `filter()` en cada frame: pasar a un pool;
   - la IA crea un `Snapshot.new()` por tick: pasar a un buffer circular.
2. **Sonido:** el precalentado de `CombatSfx` debería ser estático en `SfxSynth` y lanzarse desde el título (hoy puede trabar el arranque de la pelea).
3. **R2:** `combat/` depende de `ui/ui_style.gd`. Mover `UIStyle` a una carpeta neutral (por ejemplo `shared/`).
4. **Textos sin traducir que ve el jugador:**
   - `"VS"`, los nombres y apodos de los rivales del arcade;
   - los botones de la Práctica ("Rival", "Debug", "Reiniciar", "Jugador");
   - `"Peleador"` por defecto.
5. **La IA ve demasiado:** recibe el `move_id` y la zona exactos desde el tick 1, incluso en el jab al cuerpo, que no tiene aviso. Propuesta: que la zona se vea recién después de unos ticks.
6. **Lag táctil:** la ventana de 50 ms del deslizar demora todo jab o fuerte que no se desliza. Evaluarlo en el celular real.
7. **Toques para levantarse:** durante la congelada se juntan en un solo `bool`. Contarlos en vez de perderlos.
8. **Deuda menor:**
   - señales sin uso;
   - comentarios del tipo "llega en el Hito X";
   - `get_slice(" ", 1)` en `arcade_run`;
   - el enum de dificultad conviene moverlo a `AIProfile`;
   - validar `decision_interval_ticks > 0`.
9. **Pruebas que faltan:** que todas las claves de `tr()` existan en el CSV, y `quit_requested`.

### Hecho: pasada de realismo, parte 1: cortes, cutman y médico (ver CLAUDE.md)

### (Diseño original del paso A, como referencia)
Lo pidió la persona ("me gusta la sangre y que afecte"). Diseño propuesto, a validar con ella si cambia algo:
- **Abrir un corte:** un golpe fuerte, counter o estrella **a la cabeza** que conecta puede abrir un corte en la ceja o el pómulo. La probabilidad crece con el daño y con el daño profundo acumulado. Hay como máximo 2 cortes por peleador.
- **Efectos del corte:**
  - sangra (visual, ya existe una base en `CombatFX` y `FighterVisual._draw_face_damage`);
  - **cada golpe que vuelve a pegar sobre el corte lo agranda y suma un 15 a 20 % de daño**;
  - un corte grave tapa la visión: en la IA suma retraso de reacción; para el jugador, una viñeta roja sutil de un lado.
- **Cutman, entre rounds:** reduce la gravedad de cada corte (por ejemplo, −35 %). Cuando exista la carrera, un cutman mejor va a reducir más.
- **Médico:** si un corte supera la gravedad máxima, en el descanso **revisa** y puede **parar la pelea**, que termina por TKO con un método nuevo: `DOCTOR_STOPPAGE`.
- **Datos:**
  - `FightResult.injuries` guarda los cortes (zona, gravedad), para que la carrera los use (lesiones y tiempo de recuperación);
  - los textos van en `i18n/textos.csv`;
  - los números van en constantes con comentario, o en un Resource de balance.
- **Pruebas:** `tests/test_cortes.gd`, para que el corte se abra, crezca, sume daño, el cutman lo reduzca y el médico pare la pelea.

### Paso B: pasada de realismo, parte 2 (consultar con la persona)
Daño localizado, que ya está previsto en el plan:
- cabeza contra cuerpo con consecuencias distintas; el cuerpo ya baja la stamina máxima;
- piernas flojas después de un golpe fuerte (moverse más lento unos segundos);
- más adelante, el clinch.

### Paso C: cerrar la Fase 1
- Cuando la persona tenga Android: exportar, probar los controles táctiles (Hito I) y hacer la puerta del MVP con 3 o 4 personas.
- Antes, es útil sumar una **pantalla de "cómo se juega"** la primera vez, y **opciones**: volumen, sangre sí/no (`CombatFX.blood_enabled`), opacidad de los botones, modo zurdo.

### Paso D: Fase 2 del plan (la carrera)
Ver la sección 22 del plan. Arrancar por:
1. ~~`FighterData` y `stat_formulas`~~ **hecho**. Pendiente de esa parte: que Mentón también mueva el umbral de knockdown, levantarse y la recuperación entre rounds (hoy son constantes en `fighter.gd`), y sliders de estadísticas en la sandbox;
2. ~~autoloads `GameState`, `SaveManager` y `SceneRouter`~~ **hecho** (carrera nueva desde "Crear peleador", guardado en `user://slot_1.json` con `.bak`);
3. ~~el hub~~ **hecho como esqueleto**: muestra todo, los 5 lugares todavía avisan "Próximamente". Sigue: Gimnasio (entrenar), Trabajo (plata), Casa (descansar) y que la semana avance;
4. el campamento;
5. los saltos de tiempo.

**El combate no se toca:** la carrera arma un `FightSetup` y lee el `FightResult` (R2).

## 8. Cómo trabajar si sos la "otra" sesión
1. Seguir las reglas de "Trabajo en equipo" de CLAUDE.md: `git pull --rebase`, anotar en "En curso", pruebas en OK y `git push`.
2. Una tarea por vez y commits chicos, con la línea `Co-Authored-By` que te indique tu sesión.
3. Al terminar algo visible, contarle a la persona **en español simple** qué cambió, cómo probarlo y qué decisiones quedan para ella.
