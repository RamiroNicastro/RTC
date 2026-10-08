# Boxeo RPG: guía para trabajar con IA en este proyecto

RPG de carrera de boxeo 2D para Android, hecho en Godot 4.7 con GDScript.
El plan aprobado y congelado está en [docs/PLAN_FINAL_V2.1.md](docs/PLAN_FINAL_V2.1.md). **No se rediseña:** cualquier cambio de diseño se consulta antes.
Las convenciones de código están en [docs/CONVENCIONES.md](docs/CONVENCIONES.md).
**Para continuar el trabajo** (mapa del código, balance, pruebas, trampas y próximos pasos), leé [docs/HANDOFF.md](docs/HANDOFF.md).

## Reglas inviolables

- **R1.** `PlayerInput`, `AIInput` y `DummyInput` controlan **exactamente el mismo** `Fighter`. El Fighter no sabe quién lo maneja: solo recibe un `FighterCommand` por tick.
- **R2.** El combate recibe un `FightSetup` y, al terminar, emite `fight_finished(FightResult)`. **Nada dentro de `combat/` usa autoloads** ni conoce la carrera, la economía o la narrativa.

## Reglas de arquitectura

- **Tiempo:** la lógica del combate cuenta en **ticks** (números enteros) dentro de `_physics_process`, a 60 Hz fijos. 1 tick equivale a 1 frame a 60 FPS. Nunca se usa `delta` ni `Engine.time_scale` en la lógica del combate. Las conversiones van en `CombatTime`.
- **El orden de los ticks lo maneja `CombatScene`:** primero se leen los comandos de los dos peleadores y después se los avanza a ambos. Los Fighters no tienen `_physics_process` propio.
- **La lógica manda y la animación obedece.** Las hitboxes futuras se activan según los ticks del `MoveData`, nunca desde la animación.
- **La detección de impactos** pasa por `HitResolver` (desde el Hito B). Al principio mide distancia; más adelante usará hitboxes.
- **Autoloads:** solo `GameState`, `SaveManager` y `SceneRouter`, y recién en la Fase 2. **No hay EventBus**: se usan señales locales.
- **Datos estáticos** en Resources `.tres`. **Partidas guardadas** en JSON dentro de `user://`.
- **Textos visibles** con `tr("CLAVE")`. Se exceptúan el overlay de debug y la sandbox.
- **Si el editor no arranca el juego** (queda gris), hay que cerrar Godot del todo y reabrirlo, o usar `jugar.bat`, que abre el juego sin el editor.
- **Después de agregar archivos nuevos**, la persona tiene que usar *Proyecto → Recargar proyecto actual* antes de F5. Si no, el editor no ve las clases nuevas y el juego queda en gris (pausado por error). Hay que recordárselo.
- **Placeholders** solamente: no se hace arte final antes de pasar la puerta del MVP.

## Decisiones tomadas durante el desarrollo (amplían el plan)

- **Hito C, tono:** el combate es realista pero **arcade**. El spam se castiga claramente, y frenar recupera rápido.
- **Hito C, fatiga ligera:** el 15 % de la stamina gastada se vuelve fatiga y baja el máximo (con tope del 25 %). Se ve como un tramo gris en la barra. En el Hito E2, el descanso entre rounds recupera una parte con `recover_fatigue()`. Se suma a la reducción del máximo por golpes al cuerpo (Hito D).

- **Hito D, guardia más suave:** un jab bloqueado saca solo 1 de stamina. El fuerte bloqueado saca 15 y rompe la guardia. Bloquear **no genera fatiga**: la fatiga sale solo del esfuerzo propio (pegar, fallar, esquivar).

- **Hito F, balance arcade:** objetivo con IA contra IA: alrededor del 30 % de las peleas termina por KO o TKO, el resto por decisión, y casi ninguna se define en el round 1. Los valores actuales:
  - jab 4, fuerte 14, cuerpo 3 y 10;
  - el jab que conecta no da ventaja para encadenar;
  - al levantarse se recupera el 40 %;
  - levantarse cuesta más cuanto más salud máxima se perdió;
  - la barra para levantarse se vacía a 3 toques por segundo.

  Se mide con `godot --headless --path . -s res://tests/balance_report.gd` (20 peleas IA contra IA).

- **Ampliación estratégica** (pedido de la persona: "que no sea solo spamear", al estilo de Gladihoppers):
  - **Distancia justa:** cada `MoveData` tiene su zona ideal (`sweet_gap_min/max`). El jab rinde en la punta y el fuerte de cerca.
  - **Impulso:** pegar avanzando da hasta +30 % y retrocediendo hasta −40 %. El fuerte avanzando además adelanta un paso (`lunge`).
  - **Empuje:** el golpe que entra empuja al rival (`knockback`); bloqueado, la mitad. Las cuerdas lo frenan.
  - **Fuerte cargado:** mantener el botón congela el arranque hasta 45 ticks: +60 % de daño y el doble de empuje. Cargar cerca del rival es arriesgado, porque te pueden cortar.
  - **La IA lee patrones:** recuerda los últimos 6 golpes del rival. Al golpe que más se repite lo reconoce antes (percepción más rápida según `read_skill`) y se defiende mejor. Contra el spam de jab llega a defender más del 90 %.
  - **Normal más fácil:** +3 ticks de reacción y −15 % de defensa sobre el perfil.

- **Pedido de la persona: "que sea un vicio".** Se agregó un **Modo Arcade de prueba** (escalera de rivales con puntaje y récords) como capa sobre el combate, para la puerta del MVP. **No es la carrera**: la carrera sigue siendo la Fase 2 y va a reemplazar o convivir con este modo.
- **Ronda 2 (revisión crítica):**
  - los toques del jugador se guardan durante el hitstop (`PlayerInput.poll()`);
  - el fuerte avisa con un destello (amarillo a la cabeza, violeta al cuerpo) y un soplido;
  - aparece una marca de distancia justa bajo el rival;
  - carteles "ATORADO" y "CON IMPULSO";
  - la carga tiene zona muerta (`CHARGE_HOLD_TICK = 8`);
  - la guardia solo se rompe en la zona justa del fuerte, y el fuerte llega a 100;
  - la IA castiga la carga y el presionador carga;
  - pausa con Esc, P, ⏸ o Atrás, y al perder el foco;
  - en el arcade: golpe propio por rival (arranque de 20 a 24), frase, desafíos, rounds 1-1-2-2-3-3 de 45 s y botón CONTINUAR.
- **Ronda 3 (decisiones de la persona, amplían el plan):**
  - **golpe estrella:** un medidor que llenan los counters, los fuertes limpios y los esquives. Lleno, el próximo fuerte pega ×1,6, rompe la guardia desde cualquier distancia y empuja ×1,8;
  - **combo 1-2 adelantado:** un jab que conecta hace que el fuerte siguiente arranque 6 ticks antes, durante 24 ticks;
  - **cuerpo en el táctil:** se desliza hacia abajo sobre JAB o FUERTE, con una ventana de 50 ms. Se sacó el botón CUERPO.
- **Ajuste tras la prueba de la persona ("la stamina se termina muy rápido", "está difícil"):**
  - stamina más fluida: jab 4,5 (+2,5 si falla), fuerte 13 (+5), esquive 6, recuperación de 18 por segundo con 0,5 s de espera y fatiga del 10 %;
  - para compensar, la **salud base pasó a 160**. Con eso la mitad de las peleas termina por KO o TKO y todas llegan al round 3. Las pruebas fijan la salud en 100 para que sus cuentas sigan valiendo;
  - Fácil y Normal son más accesibles: más reacción, menos defensa y castigo, menos lectura. El contragolpeador conserva reflejos rápidos (reacción 6) para que su esquive siga siendo su sello.
- **Sangre visual** (la persona busca realismo): salpicaduras en los golpes fuertes a la cabeza, manchas en la lona y la cara marcada según el daño profundo. Se apaga con `CombatFX.blood_enabled`.
- **Cortes (hecho, pasada de realismo parte 1):**
  - un fuerte, counter o estrella a la cabeza puede abrir un corte en la ceja o el pómulo, como máximo 2;
  - cada golpe a la cabeza lo agranda, y pegar sobre un corte suma un 18 % de daño;
  - con un corte grave la IA ve peor (+6 ticks de reacción) y el jugador ve un borde rojo;
  - el cutman reduce los cortes un 45 % en el descanso;
  - el médico para la pelea con gravedad 1,0 en el descanso o 1,4 en el momento (`DOCTOR_STOPPAGE`), y los cortes quedan en `FightResult.injuries`;
  - balance: cerca del 15 % de las peleas termina por el médico, siempre en el round 2 o 3.
- **Antes, la idea de los cortes con efecto** (sangrado, el médico que para la pelea) iba en la **pasada de realismo**, inmediatamente después de cerrar el prototipo de combate. Es la próxima gran tarea de diseño; la persona tomó como referencia el juego "Bruisers 2D Boxing".
- **Game feel:** se apaga con `FightSetup.game_feel = false` (todas las pruebas lo hacen, para contar ticks exactos).

## Trabajo en equipo: varias sesiones de Claude sobre el mismo repo

El repo está en GitHub (`origin`). Lo usan dos sesiones de Claude: una local, en la PC de la persona, con Godot y Windows, y otra desde Claude Code, que puede correr en la nube con Linux. Para no pisarse:

1. **Al empezar:** `git pull --rebase`. Leer este archivo, sobre todo "Estado actual" y "En curso".
2. **Anotar qué se va a hacer** en "En curso" (más abajo), con el nombre de la sesión y los archivos. Commitear y pushear esa nota antes de empezar, si el trabajo es largo.
3. **Trabajar en partes chicas:** un hito o una mejora por vez. **No dejar cambios sin commitear** al terminar.
4. **Antes de pushear:** correr `bash tests/run_all.sh`; todo tiene que dar OK. Si no hay Godot, ver `tools/install_godot_linux.sh` y la variable `GODOT`.
5. **Pushear al terminar** (`git push`) y borrar la nota de "En curso".
6. **Si `git pull --rebase` da conflicto:** resolverlo con cuidado (nunca `--force`) y volver a correr las pruebas.
7. **Si las dos sesiones necesitan los mismos archivos al mismo tiempo**, usar una rama (`git checkout -b <tema>`) y unirla a `main` cuando las pruebas den OK.

### En curso
- (nada)

## Forma de trabajo

- **Un hito por sesión.** Un hito se commitea solo después de que la persona lo probó en Godot y cumple el criterio de la sección 16 del plan.
- Al terminar un hito, se actualiza "Estado actual" en este archivo.
- **Respaldo en GitHub:** el repo privado es https://github.com/RamiroNicastro/RTC (remoto `origin`, rama `main`). Después de cada commit se hace `git push` para no perder trabajo.

## Cómo validar sin abrir el editor (desde Git Bash)

```bash
GODOT="$HOME/Downloads/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe"
"$GODOT" --headless --path . --import                 # importar y regenerar el caché de clases
"$GODOT" --headless --path . --quit-after 300         # correr la sandbox unos segundos y ver errores
bash tests/run_all.sh                                 # pruebas automáticas (todas tienen que dar OK)
```

Las pruebas de `tests/` reemplazan los controladores por controladores guionados (algo que R1 permite) y avanzan los ticks a mano con `_physics_process(0.0)`. Cada hito nuevo suma su propio `tests/test_hito_X.gd`.

## Estado actual

- [x] Fase 0: proyecto configurado (1280×720, canvas_items + expand, sensor_landscape, 60 Hz, interpolación de física), git, docs.
- [ ] Fase 0: exportación a Android (la configura la persona; los pasos están en docs/ANDROID.md).
- [x] Hito A: movimiento, Fighter, rival quieto y cámara con zoom suave
- [x] Hito B: jab (MoveData en ticks), HitResolver por distancia, salud, hitstun, HUD, rangos en debug
- [x] Hito C: stamina arcade + fatiga ligera, golpe fuerte, guardia y ruptura de guardia, modos del dummy
- [~] Hito T: botones táctiles provisorios hechos y probados con mouse. **Pendiente: prueba en un celular real** (falta instalar JDK 17, Android SDK y plantillas; ver docs/ANDROID.md)
- [x] Hito D: esquive (solo cabeza) con counter, golpes al cuerpo con desgaste del máximo (tope 30 %), guardia más suave
- [x] Hito E1: knockdown, cuenta (mínimo 3 para levantarse), barra para levantarse, KO/TKO, textos en i18n/
- [x] Hito E2: rounds (3×60 s), reloj que se frena en la cuenta, descanso con recuperación parcial, salud en dos capas, TKO por round
- [x] Hito E3: FightStats (solo eventos reales), 3 jueces con pesos distintos, decisiones, FightResult (solo datos), pantalla final
- [x] Hito F: IA que ve con 0,2 s de retraso, mide distancia, ataca, castiga, se cubre o esquiva, cuida la stamina; primer ajuste de balance
- [x] Hito G: AIProfile con 3 estilos (presionador, técnico, contragolpeador) y dificultad fácil/normal/difícil
- [x] Ampliación estratégica: distancia justa, impulso, empuje, la IA lee patrones, fuerte cargado, Normal más fácil
- [~] Hito H (game feel): hitstop y cámara lenta en `CombatClock`, sacudida y zoom en `CombatCamera`, `CombatFX` (chispas, carteles, combos, destello), `CombatSfx` (sonidos sintetizados), público que reacciona, HUD con carteles animados
- [~] Hito I: controles táctiles con 7 botones (esquive y cuerpo incluidos), safe area y modo zurdo. Falta la prueba en un celular real.
- [x] Modo Arcade de prueba: título → escalera de 6 rivales → puntaje → récords en JSON (`modes/arcade/`, `ui/`)
- [x] Fase 2, etapa 1 (adelantada antes de la puerta del MVP, con OK de la persona): `FighterData` (6 estadísticas 1-100 + envergadura) y `StatFormulas` (50 = valores de hoy; 100 contra 1 ≈ 35-40 %). Los 6 rivales del arcade tienen ficha en `data/rivals/arcade/`. Mentón todavía solo cambia la salud (falta knockdown, levantarse y recuperación entre rounds). **Decisión de la persona (08/10/2026): se arranca la carrera sin esperar la puerta del MVP**; el combate se ajusta cuando se pueda probar en Android.
- [x] Crear peleador: nombre, apodo y 5 estilos (Equilibrado, Pegador, Estilista, Fajador, Contragolpeador; todos suman 300 puntos). `PlayerFighter` lo guarda en `user://player_fighter.json` (provisorio hasta `GameState`). El Arcade lo pide la primera vez; el título tiene "MI PELEADOR".
- [~] Carrera, parte 1: autoloads `GameState`, `SaveManager` y `SceneRouter`; título con CONTINUAR / NUEVA CARRERA; "Crear peleador" en modo carrera (exige nombre; arranca con el 60 % de las estadísticas del estilo, $500, 18 años); hub con encabezado, estadísticas y 5 lugares (todavía "Próximamente"). Se guarda al salir y al pausar o cerrar la app.
- [~] Carrera, parte 2: semana de 3 acciones con energía (100). Gimnasio con 6 ejercicios (`data/trainings/`, principal ++ y secundaria +; sparring sube todo; Mentón solo como secundaria, a propósito), Trabajo (+$150), Casa (+45 energía). Al pasar la semana: -$100 de gastos, +25 energía, cumpleaños cada 52. Cansado (<50) o con deuda se entrena peor. Balance en `career/week/week_actions.gd` (de 30 a 50 en ~10 sesiones). Falta: Arena (peleas) y Tienda.
