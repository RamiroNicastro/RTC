# PLAN FINAL (V2.1): RPG de boxeo 2D (Godot 4 · GDScript · Android)

## Contexto

Este es un RPG deportivo de boxeo en el que **las peleas las juega directamente el jugador**, rodeado por una capa de carrera, vida, compras e historia. El desarrollador es principiante y trabaja con IA. El Plan V1 quedó aprobado conceptualmente; esta V2 incorpora las 11 correcciones técnicas y de diseño que pediste, más las respuestas sobre tono, mundo, compras y fracaso.

**Objetivo de esta versión del plan**: dejar todo definido para empezar el **Hito A** del prototipo de combate.

### Cambios respecto de la V1
1. "Divisiones" pasa a llamarse **etapas de carrera (tiers)**. "Categoría de peso" queda reservado para el futuro.
2. Hay un nuevo **modelo temporal** con saltos de tiempo automáticos. Las cuentas cierran para llegar de los 18 a los 35 años.
3. Los timings del combate se miden en **ticks de física fijos**, independientes de los FPS de pantalla.
4. La detección de impactos queda detrás de un **`HitResolver` intercambiable**: primero por distancia y después con hitboxes.
5. **Técnica ya no toca a los jueces.** Los jueces puntúan solo eventos reales.
6. **Sin EventBus** al inicio. Hay 3 autoloads y señales locales.
7. Se corrigió la explicación sobre `.tres` y se aclaró su uso.
8. La configuración de pantalla para Android quedó definida (16:9, 19,5:9 y 20:9) y el espacio de juego es fijo.
9. El prototipo se divide en **9 hitos (A–I)** con un criterio de prueba cada uno.
10. El pipeline de arte queda **sin decidir**: todo el prototipo usa placeholders.
11. Las dos reglas de arquitectura quedan escritas como **reglas inviolables**.
12. Se suman: diseño para que sea adictivo y satisfactorio, compras visibles, mundo ficticio con varios países, drama con humor de cultura de pelea y carreras que pueden terminar mal.

### Cambios de la versión final (V2.1)
1. **Carrera**: el objetivo normal es de 36 a 40 peleas. Puede terminar antes, y excepcionalmente llegar a unas 45.
2. **Golpe al cuerpo**: la reducción de stamina máxima tiene un tope y se recupera en parte entre rounds. Antes de la 1.0 se suman cross, hook, uppercut y combos desbloqueables.
3. **Hitboxes futuras**: las activa el timing del `MoveData`, **nunca la animación**.
4. **Técnica**: se quita el aumento de rango. El alcance depende del golpe y de la envergadura del peleador.
5. **Montaña**: pasa a ser un campamento de boxeo en altura de 3 a 6 meses.
6. **Corte de peso**: sale de la 1.0 y queda para la expansión de categorías.
7. **Vehículos**: solo dan fama, moral y estatus, y tienen mantenimiento. No dan acciones extra ni ahorran tiempo de viaje.
8. **Guardado**: un slot en el MVP y 3 slots en la 1.0. El Salón de la fama es global.
9. **Android**: se agrega el **Hito T** (prueba táctil temprana) después del Hito C.
10. **El Hito E se divide** en E1, E2 y E3.
11. **Rivales**: 15 a 20 diseñados a mano, más rivales secundarios generados, sin simular el mundo.
12. **Idiomas**: la 1.0 sale en español e inglés.

---

## 0. Alcance (se mantienen los recortes de la V1)

| Idea | Decisión para la 1.0 |
|---|---|
| Lugares | Un hub de menús con **ilustraciones que evolucionan** (casa, gimnasio, garage), sin mapa para caminar |
| Historia ramificada | 3 actos con un rival central, más **eventos con condiciones y flags** |
| Contratos, sponsors y representante | **Cartas de oferta** |
| Minijuegos | 2 (bolsa y soga); el resto se entrena en automático |
| Categorías de peso | Después de la 1.0 |
| Ranking mundial | Ranking abstracto por puntos. Rivales: 15 a 20 importantes **hechos a mano**, más **secundarios generados** combinando datos. **No se simula un mundo del boxeo** |
| Cortes, daño localizado, clinch, estilos de guardia complejos | Después de la 1.0 (la arquitectura los permite). Cross, hook, uppercut y combos entran en la 0.5 |
| MMA y modo entrenador | Expansiones futuras |

---

## 1. Visión del juego

> **Un RPG de carrera de boxeo donde cada pelea la jugás vos.** Empezás sin nada en un barrio humilde de un país ficticio, entrenás, laburás, comprás tus primeros guantes buenos y vas subiendo hasta pelear por el mundo. Lo que construís afuera solo sirve si sabés usarlo arriba del ring. Cada carrera es distinta porque **no podés ser todo**, y puede terminar en gloria o en ruina.

**Pilares de diseño, en orden:**
1. **Un combate que se siente bien**: golpes con peso, lectura del rival, decisiones tácticas.
2. **Progreso que se ve y se siente**: la casa, el auto, los guantes y el gimnasio cambian en pantalla, y el tiempo pasa con momentos memorables.
3. **Lo de afuera se nota adentro**: cada estadística, compra y habilidad cambia algo concreto en el ring.
4. **Una carrera con identidad y riesgo**: especialización exclusiva, envejecimiento, un rival con historia y la posibilidad de fracasar.
5. **Sesiones cortas**: una pelea dura de 5 a 8 minutos y un turno de gestión menos de un minuto.

**Tono**: drama realista al estilo Rocky o Creed (barrio, sacrificio, familia, traiciones), con **humor de cultura de pelea** en los eventos secundarios.

---

## 2. Gameplay loop principal

### Ciclo de pelea
```
OFERTA → NEGOCIACIÓN → CAMPAMENTO (jugable) → PELEA (jugable) → RECOMPENSAS → SALTO DE TIEMPO (montaje) → OFERTA…
```

| Fase | ¿Quién la juega? | Duración real |
|---|---|---|
| Oferta y negociación | El jugador elige entre 2 o 3 cartas (rival, bolsa, riesgo, fama) | ~30 segundos |
| Campamento | El jugador, **4 a 6 turnos** de 3 acciones cada uno | ~3 a 5 minutos |
| Pelea | El jugador | ~5 a 8 minutos |
| Recompensas | Pantalla de resultado (dinero, fama, bonus, puntos de habilidad) | ~20 segundos |
| Salto de tiempo | **Automático**, en forma de montaje (sección 3) | ~10 a 20 segundos |

### Diseño para que sea adictivo (sin prácticas tóxicas)
Siempre tiene que haber **una meta corta, una media y una larga** a la vista:

- **Corta (esta pelea)**: la bolsa a cobrar y los bonus posibles: "KO de la noche", "Pelea de la noche", "Sin recibir knockdowns".
- **Media (las próximas 2 o 3 peleas)**: **la próxima compra está siempre visible con su precio y una barra de "te faltan $X"**. Lo mismo para el próximo nodo de habilidad y el próximo puesto del ranking.
- **Larga**: el título de la etapa, la revancha con el rival, la casa de tus sueños.

Mecanismos concretos:
- **"Una pelea más"**: al terminar una pelea aparece enseguida la próxima oferta jugosa, con la recompensa destacada.
- **Recompensas variables**: sponsors sorpresa, eventos aleatorios y bonus de la noche.
- **Progreso acumulado y visible**: el récord en pantalla, la vitrina de cinturones y trofeos en la casa y la colección de autos en el garage.
- **Momentos de pico emocional**: el KO en cámara lenta, levantar el cinturón, la primera casa propia.
- **Sin** monetización, sin timers de espera y sin castigos por no conectarse. La adicción tiene que salir del juego en sí.

---

## 3. Estructura de la carrera y modelo temporal

### Etapas de carrera (tiers)

| Tier | Nombre | Edad típica | Peleas aprox. | Rounds |
|---|---|---|---|---|
| T1 | Barrio / Amateur | 18–20 | 8–9 | 3 |
| T2 | Profesional regional | 20–23 | 6–7 | 4–6 |
| T3 | Campeón nacional | 23–26 | 6–7 | 6–8 |
| T4 | Ranking internacional | 26–29 | 6–7 | 8 |
| T5 | Contendiente mundial | 28–31 | 4–5 | 8–10 |
| T6 | Campeón mundial / defensas | 30–36+ | 5–8 | 10 |

**Objetivo de una carrera normal: 36 a 40 peleas.** Puede terminar antes por retiro, lesión o fracaso, y excepcionalmente extenderse hasta unas **45** (por ejemplo, un campeón longevo con muchas defensas).

El término **"categoría de peso"** (weight class) queda reservado para el futuro.

### Modelo temporal: corrección central de la V2

**Problema de la V1**: 40 peleas con 8 a 10 semanas cada una daban unos 7 a 8 años, y el personaje llegaba a los 26 al final de la carrera.

**Solución**: cada ciclo de pelea dura entre **3 y 8 meses de tiempo de juego**, pero el jugador gestiona **solo el campamento**. El resto pasa como **saltos automáticos con resumen**.

Composición de un ciclo:

| Tramo | Duración en el juego | ¿Se juega? |
|---|---|---|
| Negociación y espera de fecha | 2–6 semanas | No (salto) |
| Campamento | **4–6 turnos = 4–6 semanas** | **Sí** |
| Pelea | 1 noche | **Sí** |
| Recuperación | 2–12 semanas según el daño recibido | No (salto) |
| Inactividad, lesión o decisiones | 0–12 meses o más | No (salto, con eventos) |

Duración media del ciclo según el tier:
- T1 amateur: unos **2,5 meses**, porque se pelea seguido y con poco daño. Son unas 9 peleas en unos 2 años, y el personaje llega a los ~20.
- T2 a T6 profesional: unos **4,5 a 6 meses**, es decir, 2 o 3 peleas por año como en el boxeo real.
- Total: 18 → ~35 años, con **36 a 40 peleas** (como máximo ~45) y unos **200 turnos jugables** en toda la carrera.

**Ajustes que alargan o acortan el tiempo** (todos en una tabla de datos para balancear):
- Lesiones: de 1 a 12 meses fuera.
- "Tomarse un descanso": de 1 a 6 meses, recupera desgaste y moral.
- **Campamento de boxeo en altura**: de 3 a 6 meses. Mejora Cardio y Técnica, y tiene consecuencias en fama, dinero y moral (ver sección 7).
- Problemas contractuales o con el promotor: de 2 a 6 meses de inactividad.
- Que el peleador pida peleas más seguido acorta la recuperación pero aumenta el riesgo de lesión.

### Que el paso del tiempo sea satisfactorio
El salto de tiempo **no es una pantalla negra**. Es un **montaje**:
- un calendario que pasa hojas, y la edad que sube con una animación;
- un titular de diario ficticio sobre tu última pelea;
- barras de estadísticas que suben o bajan (con la edad, el descanso o el desgaste);
- el dinero que entra y sale: alquiler, sueldo del entrenador, mantenimiento del auto;
- eventos cortos que ocurrieron en el salto ("Tu rival ganó por KO en el extranjero").

**Momentos fijos del calendario**:
- **Cumpleaños**: resumen del año con récord, dinero y un evento especial. A los 30 llega "Ya no sos un pibe".
- **Fin de temporada**: premios ficticios como "Peleador del año" o "KO del año", y cambios en el ranking.
- **El prime y el declive se anuncian** con eventos narrativos (la primera vez que notás que estás más lento) y no solo con números.

### Edad
- La curva de potencial es: crecimiento rápido de los 18 a los 26, **prime de los 27 a los 31**, y declive desde los 32 (primero la velocidad y el cardio, y la recuperación se vuelve más lenta).
- **Desgaste acumulado**: una variable de salud a largo plazo que sube con cada pelea dura y cada knockdown, y que no se recupera del todo.

### Fin de carrera (puede terminar mal)
- **Retiro voluntario**, en cualquier momento a partir del T2.
- **Retiro forzado** por:
  - una **lesión grave** (evento con decisión: arriesgarse a volver o retirarse);
  - **desgaste acumulado** al máximo (la comisión médica no te habilita);
  - una **seguidilla de derrotas** que te deja sin ofertas;
  - **ruina económica**, que no termina la carrera pero te obliga a aceptar peleas malas, y es un gran motor de drama.
- **Resumen de carrera**: récord, KOs, derrotas, títulos, defensas, dinero ganado y **dinero final**, mayor rival, reputación, edad de retiro y un **epílogo narrativo** según cómo terminó. Todo se guarda en el **Salón de la fama** local.

---

## 4. Diseño del sistema de combate

### Reglas inviolables de arquitectura
> **R1.** `PlayerInput` y `AIInput` controlan **exactamente el mismo** `Fighter`. El Fighter no sabe quién lo maneja.
>
> **R2.** El combate recibe un `FightSetup` y devuelve un `FightResult`. **No depende** de la carrera, la economía, la narrativa ni de ningún autoload.

### Tiempo del combate (corrección 3)
- **La lógica corre en `_physics_process` con un tick fijo de 60 Hz** (`physics_ticks_per_second = 60`). Todos los timings se guardan como **ticks** (números enteros).
- **1 tick equivale a 1 frame a 60 FPS.** El frame data de diseño es directamente legible: "el jab tiene 6 de arranque, 2 activos y 10 de recuperación".
- **El render es independiente.** En una pantalla de 30, 90 o 120 Hz la lógica sigue igual. Se activa la **interpolación de física 2D** (disponible desde Godot 4.3) para que el movimiento se vea suave.
- Hay un **reloj propio del combate**: un contador de ticks que puede pausarse o ralentizarse para el hitstop y la cámara lenta del KO. **Nunca se usa `Engine.time_scale`**, porque afecta a todo el juego.
- **La lógica manda y la animación obedece.** El estado del Fighter decide qué animación se ve, pero la lógica nunca espera a que termine una animación. Así el combate no depende del arte, que todavía no está decidido.
- Si algún día cambia el tick rate, hay una sola función de conversión de ticks a segundos.

### Detección de impactos desacoplada (corrección 4)
```
Fighter (fase ACTIVE de un golpe)
   └─► HitResolver.resolve(atacante, defensor, move) ─► HitInfo
                                                          { resultado: HIT / BLOCKED / DODGED / WHIFF,
                                                            zona: HEAD / BODY, counter: bool, daño }
```
- **`HitResolver`** es una interfaz con un solo método.
  - **Implementación 1 (prototipo)**: `DistanceHitResolver`. Compara la distancia entre los peleadores con el rango del golpe, y usa la zona declarada en el `MoveData` y el estado del defensor.
  - **Implementación 2 (futura)**: `HitboxHitResolver`, con Area2D de hitbox por golpe y hurtboxes de cabeza y cuerpo.
- **Regla de las hitboxes**: **nunca las activa la animación.** La lógica, según los ticks del `MoveData` (fase ACTIVE), decide cuándo una hitbox está encendida. Su forma y posición vienen de datos (el `MoveData` y el estado del Fighter). La animación solo **representa visualmente** ese timing. Así se mantiene la regla de que la lógica manda.
- **Desde el día 1, cada golpe declara su zona (cabeza o cuerpo)** y cada estado defensivo declara qué zonas protege. Por eso el cambio a hitboxes no rompe nada.
- Lo que el resolver devuelve (`HitInfo`) es lo que consumen el daño, la stamina, las estadísticas de la pelea y el game feel. Ninguno de esos sistemas sabe cómo se detectó el impacto.

### Espacio
Un solo eje horizontal. El **ring tiene un ancho fijo en unidades de mundo** (sección 15) y las cuerdas limitan el movimiento, no los bordes de la pantalla.

### Acciones
| Acción | Rol | Zona | Notas |
|---|---|---|---|
| Jab | Medir, interrumpir, sumar golpes | Cabeza | Rápido, barato |
| Golpe fuerte | Castigar, romper la guardia, buscar el KO | Cabeza | Lento, castigable si falla |
| Golpe al cuerpo (▼ + golpe) | Reduce **temporalmente** la stamina máxima del rival (con tope) | Cuerpo | Medio |
| Guardia (mantener) | Protege cabeza y cuerpo y reduce el daño | — | Cada golpe bloqueado cuesta stamina; el golpe fuerte puede romperla |
| Esquive (toque) | Ventana de invulnerabilidad **solo de la cabeza** | — | Si sale bien, el siguiente golpe es un **counter** |
| Mover | Controlar la distancia | — | Retroceder regenera stamina |

**Triángulo de profundidad**:
- el golpe fuerte rompe la guardia;
- la guardia frena el jab;
- el esquive castiga el golpe fuerte;
- **el golpe al cuerpo castiga al que abusa del esquive**, porque el esquive no protege el cuerpo.

### Recursos del peleador
- **Salud en dos capas**: el daño actual se recupera parcialmente entre rounds, y el daño acumulado baja la salud máxima de la pelea.
- **Stamina**: con poca stamina los golpes salen más lentos, pegan menos y la guardia es más débil.
- **Knockdown** cuando la salud llega a 0. Hay una cuenta con un minijuego corto para levantarse. Tres knockdowns en un round son TKO.
- **Desgaste por golpes al cuerpo**, con dos límites para que no sea una estrategia dominante:
  - **Tope**: la stamina máxima puede bajar como mucho un X % (valor inicial a balancear: 30 %).
  - **Recuperación parcial entre rounds**: se recupera parte de la reducción (valor inicial a balancear: 50 %). Solo una parte queda para el resto de la pelea.
  - Los dos valores viven en una tabla de balance, no en el código.

### Repertorio
- **MVP**: Jab, Fuerte, Cuerpo, Guardia y Esquive.
- **Antes de la 1.0** (en la 0.5): golpes diferenciados, cada uno con su `MoveData`, rango, zona y timing:
  - **cross**: recto potente;
  - **hook**: corto, rompe la guardia lateral;
  - **uppercut**: muy corto, castiga al que se agacha o se cubre;
  - **combos desbloqueables**: cadenas con ventanas de timing, que se desbloquean con el árbol de habilidades y los entrenadores.
- El "Fuerte" del MVP pasa a ser el cross, y "Cuerpo" se convierte en un modificador que vale para varios golpes.

### Jueces (corrección 5)
- Durante la pelea, un objeto `FightStats` **registra eventos reales**: golpes conectados por tipo y zona, golpes bloqueados y esquivados, knockdowns, daño infligido y tiempo avanzando contra el rival.
- **Tres jueces** puntúan cada round 10-9 a partir de esos eventos. Cada uno da un **peso ligeramente distinto** a los criterios (uno valora más la agresividad, otro la precisión), lo que permite decisiones divididas creíbles.
- **Ninguna estadística del peleador entra en la fórmula de los jueces.**

### IA
- Cada rival tiene un `AIProfile` (Resource) con: agresividad, distancia preferida, probabilidad de bloquear o esquivar, tiempo de reacción en ticks, golpes favoritos y conducta con poca stamina.
- La IA "ve" lo mismo que vería un jugador (distancia, estado visible del rival, stamina propia) y **emite los mismos comandos** que `PlayerInput`.
- Arquetipos iniciales: **presionador**, **técnico de distancia** y **contragolpeador**.

### Game feel
Hitstop por impacto (en el reloj del combate), sacudida de cámara leve, destello en el golpeado, sonido en capas, cámara lenta con zoom en el KO y vibración háptica opcional.

### Futuro (la arquitectura lo permite)
Hitboxes y hurtboxes, cortes, daño localizado, clinch, estilos de guardia y MMA (otro set de `MoveData`). Cross, hook, uppercut y combos **no** son futuro lejano: entran en la 0.5.

---

## 5. Estadísticas

Cada estadística modifica **parámetros reales del peleador**. Todo pasa por un único archivo de fórmulas (`stat_formulas`), y los efectos están **acotados**: un 100 contra un 1 es una diferencia de alrededor de ±30 a 40 %, nunca ×3. Así la habilidad del jugador siempre pesa.

| Estadística | Parámetros que modifica |
|---|---|
| **Potencia** | Daño por golpe; daño a la guardia (capacidad de romperla) |
| **Velocidad** | Ticks de arranque de los golpes; velocidad de movimiento |
| **Cardio** | Stamina máxima; velocidad de regeneración |
| **Mentón** | Salud máxima; umbral de knockdown; recuperación entre rounds; velocidad para levantarse |
| **Técnica** | **Menos ticks de recuperación**; **menos stamina por golpe**; **menor penalización al fallar un golpe**; **más tolerancia de timing** (ventana de counter después de un esquive y, cuando existan, ventanas para encadenar combos). **No modifica el rango.** |
| **Defensa** | Daño que absorbe la guardia; stamina por golpe bloqueado; **ticks de la ventana de esquive**; salida más rápida del aturdimiento por golpe recibido |

Así, una buena técnica **indirectamente** hace que conectes más y gastes menos, y eso los jueces lo registran como eventos reales.

**El alcance** depende del **rango base del golpe** (en su `MoveData`) y de una **característica física del peleador**: la **envergadura**. Se fija al crear el personaje o el rival y **no se entrena** (un rival alto y de brazos largos se siente distinto a uno bajo). El modificador por envergadura es chico y acotado.

- La escala va de 1 a 100, con rendimientos decrecientes y un tope por potencial y edad.
- **Fuera del ring**: energía (acciones del turno), salud o lesiones, **desgaste acumulado** y moral.

---

## 6. Progresión: especializaciones

- Hay **3 árboles** (Pegador, Técnico y Contragolpeador) de unos 8 nodos cada uno, y se juntan **unos 15 o 16 puntos por carrera**.
- La **habilidad final de cada árbol es exclusiva**: elegir una bloquea las otras dos.
- Los nodos dan **efectos concretos de combate**, como "el hook rompe la guardia", "el counter hace ×1,5" o "el jab al cuerpo drena el doble".
- Desde la 0.5, parte de los nodos **desbloquean combos** propios de cada estilo.
- Los **entrenadores** desbloquean el acceso a ciertos nodos o abaratan su costo, con lo que integran las "técnicas" sin un sistema aparte.

---

## 7. Narrativa, mundo, tono y humor

### Mundo ficticio con varios países
Todos los nombres son provisorios y se definen en la fase narrativa.
- **País de origen**: ficticio, **inspirado en Argentina y el Río de la Plata**: clubes de barrio, kioscos, colectivos, asados, mate. Es una **identidad fuerte y poco vista**, que funciona como diferencial y no como barrera. Juegos con identidad local fuerte suelen viajar bien.
- **Países de las etapas internacionales (T4–T6)**, cada uno con su estética y su arena:
  - una meca del boxeo latino, de inspiración mexicana;
  - una capital del espectáculo, estilo Las Vegas;
  - una tradición inglesa de boxeo;
  - un país asiático;
  - una **región de montaña** con campamentos de boxeo en altura.
- **Idiomas**:
  - durante el desarrollo, los textos quedan **externalizados desde el día 1**, sin texto escrito directamente en el código;
  - la **1.0 sale como mínimo en español e inglés**;
  - el portugués y otros idiomas quedan para después.
- Los personajes del país de origen hablan en rioplatense y los extranjeros tienen sus propias voces. En inglés se adapta el tono, no se traduce literal.

### Estructura narrativa
- **Eventos con condiciones y flags**: cada evento es un dato con condiciones (tier, edad, flags, relación, dinero), un texto, un retrato y 2 o 3 opciones con efectos.
- Las **consecuencias tardías** se resuelven con flags que activa una decisión temprana y que exigen eventos de actos posteriores.
- **3 actos**:
  - **Acto 1 (T1–T2)**: el barrio, el entrenador inicial y el rival como compañero o igual.
  - **Acto 2 (T3–T4)**: la plata, la traición o separación y la rivalidad que explota.
  - **Acto 3 (T5–T6)**: el título, el precio del éxito y el final de la rivalidad.
- **Elenco de la 1.0**: entrenador inicial, rival, amigo o amiga, familiar, representante, promotor y periodista. Son 7 personajes con retrato.
- **Los finales dependen de la carrera**: gloria, ruina, redención o retiro temprano.

### Humor de cultura de pelea
Va en eventos secundarios y nunca rompe el drama del arco principal. Son **parodias originales, sin nombres reales**. Algunos ejemplos:
- **"Me voy a la montaña"**: un **campamento de boxeo en altura de 3 a 6 meses** con un entrenador viejo y excéntrico. Mejora Cardio y Técnica. Cuesta dinero, la fama puede bajar (nadie te ve) o subir (el documental del viaje), y la moral depende de cómo te fue. Volvés con barba, corriendo cuestas por costumbre y diciendo frases raras del entrenador.
- **Pelea contra un influencer**: una exhibición con una bolsa enorme que te cuesta respeto entre los puristas, y que puede salir muy mal.
- **Conferencia de prensa**: elegís entre respetuoso, provocador o meme. Lo que digas puede volverse viral.
- **El cutman místico** que cura todo con vaselina y fe.
- El **trash talk en redes** del rival y tus respuestas.
- Un **sponsor dudoso**: bebidas energéticas de dudosa procedencia.

---

## 8. Entrenamiento

- Cada entrenamiento consume 1 acción del turno y energía, y da experiencia en sus estadísticas.
- Multiplicadores: calidad del **gimnasio**, del **entrenador**, del **programa de entrenamiento**, de la nutrición y del **equipo propio**.
- **Dos minijuegos** en la 1.0: bolsa (timing) y soga (ritmo). Siempre existe el **modo automático**, que rinde un 80 %.
- El **sparring** es un round real con daño reducido. Reutiliza el combate entero gracias a R2.
- El **sobreentrenamiento** aumenta el riesgo de lesión.

---

## 9. Economía y compras visibles

### Ingresos y gastos
| Ingresos | Gastos fijos (en cada salto de tiempo) | Gastos puntuales |
|---|---|---|
| Trabajo (sobre todo en T1) | Alquiler o mantenimiento de la casa | Compras |
| Bolsas de pelea | Cuota del gimnasio y sueldo del entrenador | Hospital y lesiones |
| Bonus de la noche | **Mantenimiento de autos** (el lujo cuesta) | Viajes |
| Sponsors (cartas) | Porcentaje del representante | |
| | Nutrición | |

El **estilo de vida tiene costo recurrente**. Un campeón que se compra tres autos de lujo puede terminar en la ruina cuando llega el declive, y eso es drama realista, rejugabilidad y una gran meta de largo plazo.

### Compras: todas se ven y todas hacen algo
| Categoría | Ejemplos de progresión | Se ve en | Efecto mecánico (acotado) |
|---|---|---|---|
| **Equipo de pelea** | Guantes usados → buenos → profesionales → a medida; vendas, shorts y bata | **El peleador en el ring** | Guantes: pequeño + a potencia o velocidad. Bata y shorts: + fama o entrada épica |
| **Equipo de entrenamiento** | Soga, bolsa en casa, pesas, cinta | La pantalla de casa | Permite entrenar en casa (ahorra energía y la cuota del gimnasio en ciertos entrenamientos) |
| **Programas de entrenamiento** | Plan genérico → plan de un entrenador → plan de élite | La pantalla del gimnasio | Más experiencia por acción, es decir, **entrenás más rápido** |
| **Gimnasio** | Club de barrio → gimnasio regional → centro de alto rendimiento | **La ilustración del gimnasio** | Multiplicador de experiencia, mejores sparrings, acceso a entrenadores |
| **Vivienda** | Pieza alquilada → departamento → casa → mansión | **La ilustración de la casa**, con vitrina de trofeos y cinturones | Calidad del descanso (energía), moral |
| **Vehículos** | Bici → moto → auto usado → auto bueno → **auto de lujo** | **Garage o colección** | **Fama, moral y estatus o lujo.** Mantenimiento recurrente alto en los caros. **No dan acciones extra ni reducen tiempos de viaje** |
| **Recuperación** | Fisioterapeuta, crioterapia, médico personal | Menú | Lesiones más cortas y menos desgaste |

**Regla de diseño**: ninguna compra debe poder reemplazar la habilidad del jugador. Por ejemplo, los guantes dan como mucho alrededor de +5 %.

**Regla de arte, para controlar el costo**: cada lugar tiene **4 o 5 niveles visuales fijos** (no se colocan muebles libres) y el equipo del peleador son **capas de sprite intercambiables**. Esto se diseña cuando se decida el pipeline de arte.

---

## 10. Arquitectura técnica en Godot

### Autoloads: solo 3 (corrección 6)
1. **`GameState`**: guarda los datos de la partida en curso.
2. **`SaveManager`**: convierte `GameState` a JSON y viceversa.
3. **`SceneRouter`**: cambia de pantalla.

**No hay EventBus.** Se usan **señales locales de Godot**: cada nodo emite sus señales y quien lo crea se conecta. Un EventBus solo se agrega si aparece una necesidad concreta y repetida, como varios sistemas sin relación que necesitan enterarse del mismo evento, y esa decisión se documenta.

**El combate no usa ningún autoload** (R2). Así se puede ejecutar solo desde una escena de debug.

### Combate
```
CombatScene
├── FightManager        rounds, reloj, cuenta, jueces, arma el FightResult; reloj de combate (ticks)
├── Ring                ancho fijo en unidades de mundo, cuerdas
├── Fighter (x2)        máquina de estados (enum + match), lee MoveData, stats ya calculados
│     └── controller    PlayerInput | AIInput | DummyInput  → emiten los mismos comandos
├── HitResolver         DistanceHitResolver (después HitboxHitResolver)
├── FightStats          registro de eventos (lo consumen los jueces y el FightResult)
├── CombatCamera        centrada entre los peleadores, limitada al ring
├── CombatFX            hitstop, sacudida, destellos (escuchan señales del Fighter)
└── CombatHUD           barras, reloj, controles táctiles
```
- `FightSetup` (entrada): datos de ambos peleadores, perfil de IA, número de rounds, tipo (oficial o sparring) y equipamiento visual.
- `FightResult` (salida): ganador, método, round, `FightStats` resumido, daño recibido y lesiones.

### Fuera del combate
Hay módulos independientes: Campamento y tiempo, Entrenamiento, Economía y compras, Ofertas y ranking (incluye un `RivalGenerator`), Narrativa y eventos, y Progresión. Cada uno lee y escribe `GameState` y expone señales propias; ninguno llama a los métodos internos de otro.

- **Rivales**:
  - los **importantes** son `FighterData` hechos a mano: nombre, historia, apariencia, envergadura, estadísticas y `AIProfile` propio;
  - los **secundarios** salen de un `RivalGenerator`, que combina pools de nombres, piezas de apariencia, estadísticas escaladas al tier, un récord plausible y uno de los `AIProfile` base;
  - un rival generado que se vuelve relevante para el jugador (por ejemplo, porque te ganó) se **guarda** en `GameState` para que pueda volver a aparecer;
  - **no hay simulación del mundo**: el ranking solo se mueve por tus resultados y por pequeños cambios aleatorios en cada salto de tiempo.
- **Idiomas**: todo texto visible pasa por `tr("CLAVE")`, con archivos de traducción CSV de Godot (`TranslationServer`). Los eventos JSON guardan claves de texto, no frases.

### Para trabajar con IA
- **Git desde el día 1** y un commit por cada hito que funcione.
- `docs/` con el GDD, la arquitectura y las convenciones, y un `CLAUDE.md` con las reglas R1 y R2.
- **Un hito o sistema por sesión.** Siempre se prueba en Godot antes de seguir.
- GDScript con **tipado estático**.

---

## 11. Estructura de carpetas

```
res://
├── autoload/          game_state.gd, save_manager.gd, scene_router.gd
├── combat/
│   ├── combat_scene.tscn, fight_manager.gd, fight_setup.gd, fight_result.gd, fight_stats.gd
│   ├── fighter/       fighter.tscn, fighter.gd
│   ├── input/         player_input.gd, ai_input.gd, dummy_input.gd
│   ├── hit/           hit_resolver.gd, distance_hit_resolver.gd, hit_info.gd
│   ├── ai/            ai_profile.gd
│   ├── moves/         move_data.gd
│   ├── judges/        judge.gd
│   ├── camera/, fx/, hud/
├── fighter_model/     fighter_data.gd, stat_formulas.gd   (lo comparten el combate y la carrera)
├── career/            hub/, camp/, time/, training/, economy/, shop/, offers/, ranking/, progression/
├── narrative/         event_runner.gd, dialogue_box.tscn
├── ui/                theme, componentes, safe_area_container
├── data/              moves/, ai_profiles/, fighters/, skills/, items/, trainings/, balance/, events/ (JSON)
├── assets/            placeholders/ (y más adelante sprites, retratos, audio, fuentes)
├── debug/             combat_sandbox.tscn (sliders de stats, modos del dummy, visualización de rangos)
└── docs/
```

---

## 12. Sistemas independientes

1. **Combate** (R1 y R2). 2. **Modelo del peleador y fórmulas de estadísticas**. 3. **Tiempo y campamento**. 4. **Entrenamiento** (los minijuegos son escenas sueltas que devuelven un puntaje). 5. **Economía y tienda**. 6. **Ofertas y ranking**. 7. **Narrativa y eventos**. 8. **Guardado**. 9. **UI táctil** (los botones emiten comandos y no saben qué hacen).

---

## 13. Formato de cada dato (corrección 7)

| Dato | Formato |
|---|---|
| Golpes, perfiles de IA, rivales fijos, habilidades, objetos, entrenamientos, tablas de balance | **Resources `.tres`** en `res://`: se editan en el inspector, tienen tipos y son ideales para contenido estático |
| Eventos narrativos | **JSON** con claves de texto |
| Textos e idiomas (es, en) | **CSV de traducción** de Godot |
| Pools para rivales generados (nombres, apodos, piezas de apariencia) | **JSON o CSV** |
| Partida guardada | **JSON** en `user://` |

**Matiz sobre `.tres`**: los Resources son perfectos para los **datos del juego** que vienen con la build y que el jugador no modifica. Para las **partidas guardadas** se elige JSON por razones prácticas:
1. **Se puede leer y depurar**: el archivo se abre y se entiende.
2. **Las migraciones son simples**: se agrega un campo con un valor por defecto, sin depender de la estructura interna de las clases.
3. **Seguridad**: un `.tres` cargado desde una carpeta del usuario (como `user://`) puede contener scripts incrustados que se ejecutan al cargarlo. No es un problema para el contenido propio de `res://`, pero es una buena razón para no cargar Resources desde archivos que alguien pudo editar o compartir.

---

## 14. Sistema de guardado

- **Slots**:
  - el **MVP y la 0.1** usan **un solo slot**;
  - la **1.0 tiene 3 slots de carrera independientes** (`user://slot_1.json`, `slot_2.json`, `slot_3.json`);
  - para que el cambio no cueste nada, la API del `SaveManager` **recibe un id de slot desde el principio** (`save(slot)`, `load(slot)`), aunque al inicio siempre sea 1.
- Cada slot tiene un campo `save_version` y una función de migración por versión.
- El **Salón de la fama es global**: está en `user://hall_of_fame.json`, fuera de los slots, y lo alimentan todas las carreras terminadas de cualquier slot.
- **Autoguardado** al terminar cada turno, cada pelea, cada evento y cada salto de tiempo, y también con `NOTIFICATION_APPLICATION_PAUSED` en Android.
- Escritura segura: primero a un archivo temporal, después se renombra, y se conserva `career.bak`.
- **No se guarda en medio de una pelea**: si la app se cierra, la pelea se reinicia.
- `GameState` tiene `to_dict()` y `from_dict()`.
- Cada slot guarda continuamente (no hay "cargar el guardado anterior" para deshacer una derrota), lo que va de la mano con "la carrera puede terminar mal".

---

## 15. Android: pantalla, aspecto y safe areas (corrección 8)

### Configuración del proyecto
- Viewport base de **1280×720**, `stretch/mode = canvas_items` y `stretch/aspect = expand`.
- Orientación **sensor_landscape**, modo inmersivo (oculta las barras del sistema) y la pantalla se mantiene encendida durante la pelea.
- Renderer Compatibility, tick de física de 60 Hz e interpolación de física 2D activada.

### Qué pasa en cada aspecto
Con `expand`, **la altura lógica se mantiene en 720** en pantallas más anchas que 16:9, y el ancho crece:

| Aspecto | Viewport lógico |
|---|---|
| 16:9 | 1280×720 |
| 19,5:9 | ~1560×720 |
| 20:9 | 1600×720 |
| 4:3 (tablet) | 1280×960 (crece la altura) |

### Regla del combate: mismo espacio útil en todos los aspectos
- El **ring mide un ancho fijo en unidades de mundo**: las cuerdas limitan el movimiento, no la pantalla.
- **El zoom de la cámara depende solo de la altura**, nunca del ancho. En una 20:9 se ve **más público y escenario a los costados**, pero la distancia entre los peleadores, el alcance de los golpes y el espacio para moverse son idénticos.
- La cámara sigue el punto medio entre los peleadores y queda limitada a los bordes del escenario.
- **Los escenarios se diseñan para 1600 de ancho** (20:9), con una zona central crítica de 1280 y un margen vertical extra para tablets.

### Safe areas (notch y cámara perforada)
- La UI cuelga de un `SafeAreaContainer` raíz que lee `DisplayServer.get_display_safe_area()`, lo convierte a coordenadas del viewport y aplica márgenes.
- **Solo la UI respeta la safe area.** El mundo del combate se dibuja de borde a borde.
- Los controles táctiles se anclan a las esquinas inferiores **dentro** de la safe area.

### Controles táctiles
- **Izquierda**: ◀ ▶ y ▼ (modificador de cuerpo).
- **Derecha**: Jab, Fuerte, Guardia (mantener) y Esquive.
- Botones de al menos 9 a 10 mm físicos, opacidad configurable, modo zurdo y vibración opcional.

**Cómo probarlo**: en el editor con tamaños de ventana de 1280×720, 1560×720 y 1600×720, y en al menos un celular real.

---

## 16. MVP: prototipo de combate en hitos (corrección 9)

**Todo con placeholders**: rectángulos de colores, formas simples y sonidos genéricos (corrección 10). **Cada hito se termina, se prueba y se commitea antes de empezar el siguiente.**

| Hito | Incluye | NO incluye | Criterio de prueba |
|---|---|---|---|
| **A**: movimiento | `CombatScene`, `Ring` con cuerdas, `Fighter` (rectángulo), `PlayerInput` (teclado), rival con `DummyInput` quieto, cámara, reloj por ticks, overlay de debug (estado y posición), un `FightSetup` con valores por defecto | Golpes, UI | Me muevo con fluidez, no atravieso al rival ni las cuerdas, y la lógica funciona igual con la pantalla limitada a 30 y a 144 fps |
| **B**: jab | `MoveData` (startup, active y recovery en ticks), estados de ataque, `HitResolver` por distancia, `HitInfo`, salud y barra, aturdimiento por golpe recibido, destello simple | Stamina, otros golpes | El jab conecta solo dentro del rango (visible en el debug), tiene recuperación castigable y el daño se aplica una sola vez por golpe |
| **C**: stamina, golpe fuerte y guardia | Stamina con costos y regeneración, efectos de stamina baja, golpe fuerte, guardia (mantener), ruptura de guardia, modos del dummy (siempre bloquea, pega cada X segundos) | Esquive, cuerpo | Se puede verificar el triángulo: la guardia frena el jab y el golpe fuerte rompe la guardia; spamear te deja sin stamina |
| **T**: prueba táctil temprana | Botones táctiles **provisorios** para mover, jab, fuerte y guardia; build de Android; prueba en el celular | Esquive, cuerpo, UI final, safe area | En el celular, moverse, pegar el jab, el fuerte y cubrirse se siente cómodo y responde rápido. Si no, se ajusta el diseño de controles **antes** de seguir |
| **D**: esquive y golpe al cuerpo | Esquive con invulnerabilidad de cabeza, counter, zonas cabeza y cuerpo, reducción de stamina máxima por golpes al cuerpo **con tope** | Knockdown | El esquive evita el golpe fuerte, pero el golpe al cuerpo lo castiga; el counter hace más daño; la stamina máxima nunca baja más que el tope |
| **E1**: knockdown y KO | Knockdown al llegar la salud a 0, cuenta, minijuego para levantarse, KO y TKO (3 knockdowns), salud simple de una capa | Rounds, jueces | Tirar al rival, verlo levantarse o no, y terminar por KO o TKO, sin estados trabados |
| **E2**: rounds | Reloj de round, campana, descanso entre rounds, **salud en dos capas**, recuperación entre rounds (incluida la recuperación parcial del desgaste del cuerpo) | Jueces | Una pelea de 3 rounds avanza bien; entre rounds se recupera lo que corresponde y el daño acumulado persiste |
| **E3**: jueces y resultado | `FightStats` (registro de eventos), 3 jueces 10-9, decisión unánime, dividida o empate, `FightResult`, pantalla final | IA | La tarjeta de los jueces coincide con lo que pasó en la pelea, y el `FightResult` contiene todos los datos |
| **F**: primera IA | `AIInput`: reacción con retardo, manejo de la distancia, ataque, guardia, conducta con poca stamina | Perfiles múltiples | La IA pelea una pelea completa, gana a veces, no repite un patrón obvio y no hace trampa (usa los mismos comandos) |
| **G**: 3 perfiles | `AIProfile` Resource: presionador, técnico de distancia y contragolpeador; dificultad por tiempo de reacción | — | Se reconoce cada estilo sin que nadie lo diga, y cada uno requiere una estrategia distinta |
| **H**: game feel y balance | Hitstop (reloj del combate), sacudida, destellos, sonidos en capas, cámara lenta en el KO, `stat_formulas`, sliders de stats en el sandbox, pasada de balance | Arte final | Pegar "se siente"; 1 contra 100 en una estadística se nota pero no es imposible; probado por 2 o 3 personas en PC |
| **I**: integración táctil definitiva | Controles táctiles finales (los 5 botones y el modificador de cuerpo, opacidad, modo zurdo), `SafeAreaContainer`, build de Android, prueba en 16:9 y 20:9, vibración, rendimiento | — | Una pelea completa jugable y cómoda en un celular real a 60 fps, con el mismo espacio de ring en todos los aspectos |

**Orden de los hitos**: A → B → C → **T** → D → E1 → E2 → E3 → F → G → H → I. Cada uno se prueba y se commitea por separado.

**🚪 Puerta del MVP**: 3 o 4 personas juegan en el celular y **quieren repetir**. Si no pasa, se vuelve a iterar sobre los hitos C a H. No se empieza la carrera hasta pasar esta puerta.

> Nota: la exportación a Android se configura en la **Fase 0** con una escena vacía, para que el Hito T no se trabe por problemas del SDK.

---

## 17. Versión 0.1: primer recorte vertical

- **Decisión del pipeline de arte** (pixel art, cutout o híbrido) y arte de **un** peleador base.
- Hub: Casa, Gimnasio, Trabajo, Tienda y Arena, con ilustraciones en el **nivel 1**.
- Loop de campamento, **saltos de tiempo con montaje**, edad y cumpleaños.
- 6 estadísticas aplicadas al combate, entrenamiento automático y minijuego de bolsa.
- Una tienda mínima: 2 niveles de guantes (que **se ven en el ring**) y un programa de entrenamiento.
- **T1 completo** (unas 8 peleas amateur), con cartas de oferta.
- De 5 a 8 eventos del Acto 1 y **1 evento de humor**.
- Guardado y carga JSON, y build de Android.

## 18. Versión 0.5

- Tiers T1 a T3.
- **Repertorio ampliado**: cross, hook, uppercut (con el modificador de cuerpo) y **combos desbloqueables**. Incluye el rediseño de los controles táctiles para el nuevo repertorio.
- Los 3 árboles de habilidades con exclusividad, incluidos los nodos que desbloquean combos.
- `RivalGenerator` para rivales secundarios.
- Tienda completa: vivienda (casa que evoluciona), gimnasio, **vehículos** y equipo de pelea por capas. Gastos fijos y estilo de vida.
- Lesiones, desgaste acumulado y prime.
- Representante y sponsors como cartas, y ranking.
- Sparring, soga y "simular pelea".
- Acto 1 y Acto 2 (parcial), 7 retratos y unos 10 eventos de humor.
- Fin de temporada y premios.

## 19. Versión 1.0

- Tiers T1 a T6 y los **países internacionales**, cada uno con su arena.
- Declive, todos los **finales de carrera (incluidos los malos)**, epílogos y Salón de la fama.
- Acto 3, 2 o 3 finales de la rivalidad, y unos 20 eventos de humor.
- **Entre 15 y 20 rivales importantes hechos a mano** (identidad, apariencia, envergadura, `AIProfile` propio), más rivales secundarios generados.
- Carreras de **36 a 40 peleas** de objetivo (como máximo ~45).
- **3 slots de carrera** y Salón de la fama global.
- **Español e inglés** completos.
- Tutorial, opciones (idioma incluido), balance, rendimiento y publicación en Google Play.

## 20. Lo que NO se desarrolla todavía

- MMA, modo entrenador, categorías de peso y **corte de peso**, que queda para la expansión de categorías.
- Simulación de un mundo completo del boxeo.
- Hitboxes y hurtboxes (ya están previstas, pero no se implementan en el MVP).
- Cortes, daño localizado, clinch, estilos de guardia más complejos.
- Multijugador, online, nube.
- Mundo para caminar, NPCs en el mapa.
- Romance profundo, decoración libre de la casa.
- Monetización.
- El portugués y otros idiomas más allá del español y el inglés.
- Traducir mientras el contenido cambia: el inglés se hace en la Fase 4, con los textos ya estables.
- EventBus, frameworks genéricos de máquinas de estado, plugins de diálogo.
- **Cualquier arte final antes de pasar la puerta del MVP.**

## 21. Riesgos

### Diseño
1. **El combate no es divertido en pantalla táctil.** Se mitiga con los hitos, la puerta del MVP y pruebas en el dispositivo.
2. **Las estadísticas o las compras rompen el balance.** Por eso hay fórmulas acotadas en un único archivo y las compras dan como mucho alrededor de +5 %.
3. **Repetitividad en 40 peleas.** Se compensa con perfiles de IA, el rival, peleas con condiciones especiales, cambios de país y eventos.
4. **Que los saltos de tiempo se sientan vacíos o los campamentos repetitivos.** De ahí el montaje, los eventos dentro del salto y los cumpleaños y fines de temporada.
5. **Explosión de contenido narrativo.** El alcance de eventos queda cerrado por versión.
6. **Que el humor rompa el drama.** El humor va solo en eventos secundarios y nunca en momentos clave del arco.

### Técnicos
7. **Costo del arte**: peleadores, casas en 5 niveles, autos y países. Es el mayor cuello de botella. Se controla con niveles fijos, capas de sprites, un cuerpo base reutilizable y la decisión del pipeline recién después del MVP.
8. **Que la lógica quede acoplada a la animación.** La regla es que la lógica manda, que todo se mide en ticks y que el `HitResolver` es intercambiable.
9. **Que el código generado por IA se desordene.** Se mitiga con git, R1 y R2, los docs y un hito por sesión.
10. **Exportación a Android.** Se configura en la Fase 0.
11. **Partidas incompatibles entre versiones.** Para eso están `save_version`, las migraciones y el backup.

## 22. Orden exacto de desarrollo

**Fase 0: Preparación**
1. Instalar Godot 4 (versión estable más reciente, 4.3 o superior por la interpolación de física 2D).
2. Crear el proyecto con: renderer Compatibility, 1280×720, `canvas_items` + `expand`, `sensor_landscape` y tick de 60 Hz.
3. Iniciar git y crear `docs/` (este plan, convenciones) y `CLAUDE.md` con R1 y R2.
4. Configurar la exportación a Android y lograr que una escena vacía corra en el celular.

**Fase 1: Prototipo de combate**
5. Hito A → 6. Hito B → 7. Hito C → 8. **Hito T (prueba táctil temprana)** → 9. Hito D → 10. Hito E1 → 11. Hito E2 → 12. Hito E3 → 13. Hito F → 14. Hito G → 15. Hito H → 16. Hito I → 17. **🚪 Puerta del MVP**.

**Fase 2: Base de la carrera (0.1)**
15. `FighterData` y la conexión con `stat_formulas` → 16. Los autoloads `GameState` y `SceneRouter` → 17. Hub → 18. Campamento y acciones → 19. **Saltos de tiempo y montaje**, edad → 20. Economía básica y trabajo → 21. Tienda mínima y equipo visible → 22. Cartas de oferta y flujo completo del ciclo → 23. `SaveManager` → 24. Ejecutor de eventos y Acto 1 inicial → 25. Minijuego de bolsa → 26. **Decisión del pipeline de arte** y peleador base → 27. Build 0.1.

**Fase 3: Profundidad (0.5)**
**Repertorio ampliado: cross, hook, uppercut y combos desbloqueables** → **adaptación de los controles táctiles a ese repertorio** → árboles de habilidades (con los nodos de combos) → **`RivalGenerator` para rivales secundarios** → lesiones y desgaste → tienda completa (casa, gimnasio, vehículos) → gastos fijos → representante y sponsors → ranking y T2 y T3 → sparring, soga y simular → Actos 1 y 2 → humor → fin de temporada.

**Fase 4: Contenido y cierre (1.0)**
T4 a T6 y países → declive y finales → Acto 3 → rivales hechos a mano → 3 slots → **traducción al inglés** → tutorial y opciones → balance → publicación.

---

## Verificación del plan
- **Cada hito** tiene su propio criterio de prueba (sección 16) y se commitea solo si lo cumple.
- **Fase 1**: la puerta del MVP en un celular real con otras personas.
- **Fase 2**: se completa T1 en Android cerrando y reabriendo la app sin perder progreso, el personaje termina T1 con unos 20 años, y los guantes comprados se ven en el ring.
- **Fase 3**: dos carreras con especializaciones distintas se sienten distintas, y una carrera derrochadora puede terminar en la ruina.
- **Fase 4**: una carrera completa de los 18 a los ~35 años sin bloqueos, con un resumen y un epílogo coherentes.
