# Eventos de la historia: cómo funcionan y cómo escribir uno nuevo

> Sistema pedido en el paso 24 de la Fase 2 del plan ("Ejecutor de eventos y Acto 1 inicial") y en la sección 7 ("eventos con condiciones y flags").
> Código: `narrative/`. Datos: `data/events/*.json`, `data/characters/*.tres`, `data/statuses/*.tres`. Textos: `i18n/textos.csv`.
> Prueba: `tests/test_eventos.gd` (también revisa que todos los eventos estén bien escritos).

## 1. Qué hay

| Pieza | Qué es |
|---|---|
| **Evento** | Una escena corta con un personaje, un texto y de 1 a 3 opciones. Cada opción tiene efectos. |
| **Moral** (0 a 100, arranca en 60) | Con 70 o más se entrena un 10 % mejor; con menos de 30, un 15 % peor. Cada semana se acerca sola 2 puntos a 50. Ganar sube (+8, KO +12) y perder baja (-10, KO -15). Se ve en el hub. |
| **Relaciones** (-100 a 100) | Con cada personaje que conociste. Cambian qué eventos salen. Se ven en **MI GENTE**. |
| **Marcas (flags)** | Recuerdan lo que decidiste ("leal_tito", "ani_ex"…). Sirven para las consecuencias tardías. |
| **Situaciones** | Algo que dura: de novio, un sponsor, un amuleto. Mueven la moral, la energía o la plata cada semana, y pueden cambiar un poco el gimnasio y la stamina de la pelea. Se ven en **MI GENTE** y en el resumen de la semana. |

## 2. Cuándo sale un evento

| Momento (`trigger`) | Cuándo se revisa |
|---|---|
| `hub` | Al abrir el hub. Solo para historia (no hay secundarios acá). |
| `week` | Al pasar la semana (después del resumen). |
| `fight` | Después de una pelea, al salir del resultado. Si no sale ninguno, se prueba con `week`, porque la pelea también pasa la semana. |
| `chain` | Nunca solo: aparece como continuación de otro (`next`) o agendado (`schedule`). |

En cada momento sale **como máximo uno**, en este orden:
1. lo **agendado** que ya venció (solo en `week`);
2. el primer evento de **historia** (`"story": true`) que cumpla sus condiciones, en el orden de los archivos. **La historia no depende del azar**;
3. con cierta probabilidad (35 % por semana, 60 % después de pelear), uno **secundario** al azar, según su `weight`.

## 3. Cómo se escribe un evento

En `data/events/` (un archivo por grupo: `acto1.json`, `vida.json`, `barrio.json`, `humor.json`). Si sumás un archivo nuevo, agregalo a `EVENT_FILES` en `narrative/event_runner.gd`.

```json
{
	"id": "v_ani_reclamo",
	"trigger": "week",
	"character": "ani",
	"once": false,
	"cooldown": 6,
	"weight": 2,
	"when": {"statuses": ["novia"]},
	"options": [
		{"requires": {"min_money": 60}, "effects": {"money": -60, "energy": -15, "relations": {"ani": 12}, "morale": 5}},
		{"effects": {"relations": {"ani": -15, "tito": 3}}}
	]
}
```

- `id`: único, en minúsculas. Los textos salen de él (ver abajo).
- `story`: `true` = sale sí o sí cuando se cumplen las condiciones (historia o momentos clave, como un corte de noviazgo).
- `once` (por defecto `true`): sale una sola vez. Con `false`, `cooldown` son las semanas de espera antes de repetirse.
- `weight`: qué tan seguido sale comparado con otros secundarios (por defecto 1).
- `character`: el retrato (id de `data/characters/`). Al ver su primer evento, el personaje se suma a MI GENTE.

### Condiciones (`when` del evento o `requires` de una opción)

| Clave | Ejemplo | Significa |
|---|---|---|
| `min_week` / `max_week` | `2` | semanas jugadas |
| `min_age` / `max_age` | `20` | edad |
| `min_money` / `max_money` | `200` | plata (en `requires`, el botón dice "no te alcanza") |
| `min_morale` / `max_morale` | `30` | moral |
| `min_energy` | `15` | energía |
| `best_rank` / `worst_rank` | `5` | puesto en el ranking (`best_rank: 5` = estar entre los 5 mejores) |
| `min_wins`, `min_kos`, `min_fights`, `max_fights` | `3` | récord |
| `min_stat` | `{"power": 40}` | estadísticas |
| `flags` / `not_flags` | `["leal_tito"]` | marcas que tenés o no tenés |
| `statuses` / `not_statuses` | `["novia"]` | situaciones activas o no |
| `relation_min` / `relation_max` | `{"tito": 25}` | relación (si no conocés al personaje, no se cumple) |
| `outcome` | `"win_ko"` o `["loss", "loss_ko"]` | cómo terminó la pelea: `win`, `win_ko`, `loss`, `loss_ko`, `draw` |
| `chance` | `0.5` | probabilidad extra |

### Efectos (`effects` de una opción)

| Clave | Ejemplo |
|---|---|
| `money`, `energy`, `morale` | `-200`, `-15`, `5` |
| `stats` | `{"technique": 1}` (de a poco: los eventos no reemplazan al gimnasio) |
| `relations` | `{"tito": 15, "bruno": -10}` (complacer a uno puede enojar a otro) |
| `flags` / `clear_flags` | `["leal_tito"]` |
| `add_status` | `{"novia": 0}` (0 = hasta que otro evento la saque) o `{"amuleto": 6}` (6 semanas) |
| `remove_status` | `["novia"]` |
| `next` | `"a1_bruno_intro"`: el evento que sigue **ya mismo** |
| `schedule` | `{"events": ["v_felipe_bien", "v_felipe_mal"], "weeks": 3}`: en 3 semanas sale uno de esos, al azar (consecuencias tardías) |

### Textos

En `i18n/textos.csv`, con claves que salen del id (en mayúsculas):

```
EV_V_ANI_RECLAMO_TITLE   título
EV_V_ANI_RECLAMO_TEXT    lo que pasa ({name} = tu nombre, {nick} = tu apodo)
EV_V_ANI_RECLAMO_1       texto del botón de la opción 1
EV_V_ANI_RECLAMO_1_RES   qué pasó al elegirla
EV_V_ANI_RECLAMO_2 …
```

Los saltos de línea se escriben `\n`. **La columna en (inglés) queda vacía por ahora**: usa el español hasta la traducción de la Fase 4 (sección 20 del plan).

### Personajes y situaciones

Son `.tres`: se crean desde el inspector (o copiando uno) en `data/characters/` y `data/statuses/`, y se agregan a `CHARACTERS` o `STATUSES` en `event_runner.gd`. Sus textos van en el CSV (`CHAR_X`, `CHAR_X_ROLE`, `STATUS_X`, `STATUS_X_DESC`).

## 4. Borrador del Acto 1 (versión 2, con los cambios de la persona del 09/10)

> Nombres provisorios salvo los que eligió la persona: **Felipe Quinteros** (mejor amigo), **Ani** (Anabella), **Ramiro Nicastro** y **Agus** (Agustina Roncati). La lectura cómoda, con todas las opciones, está en el documento "Eventos del Acto 1 (borrador)".
> El plan pedía 5 a 8 eventos para el Acto 1 en la 0.1; la persona lo amplió.

**Elenco (11):** el Nono (tu abuelo), Don Tito (entrenador), Bruno Castillo (compañero y futuro rival), Felipe Quinteros (mejor amigo, atiende el kiosco), Marta (tu vieja), Ani (la chica de la panadería), Ramiro Nicastro (iba a ser campeón y terminó en muletas), Agus (su novia), el Pampa (jefe de la banda del barrio), Don Cosme (el linyera que sabe técnicas prohibidas) y Don Aurelio (cutman místico).

**El motivo de la historia: el Nono.** Te regala sus guantes viejos y te manda al club. En la semana 5 se enferma: sus remedios cuestan $60 por semana (situación "El Nono internado"), que es la necesidad que empuja a pelear por plata. En la semana 16 muere ("El último mate"): le prometés pelear porque te gusta, o ser campeón por él. En el velorio aparece Bruno.

**Historia (en orden):** los guantes del Nono → el club y Tito → Bruno → Ramiro y Agus (semana 1) → guanteo con Bruno (semana 2) → el debut (ganado o perdido) → tu vieja y las vendas → el Nono en el hospital (semana 5) → el Pampa te ofrece peleas clandestinas (2 victorias): decís que no, lo pensás o aceptás; después te pide que te tires en una pelea (marca `tongo`, sin efecto en el combate todavía) y, si te negás, le rompen la vidriera a Felipe → Bruno se va con un promotor (3 victorias) → el último mate del Nono (semana 16) y el velorio → "Algún día" (top 5) cierra el acto.

**Vida y barrio:** Ani (conocerla, la plaza, novios, reclamos, el corte), los negocios de Felipe, Ramiro y Agus (ella lo reta; él te corrige después de perder), Tito (mate y la tercera pelea del Nono, o el enojo), Don Cosme (técnicas prohibidas por un sánguche y su pasado de campeón), los favores del Pampa si peleaste en su galpón, el asado por un KO y la noche larga después de un KO en contra.

**Opciones ocultas:** una opción cuyo `requires` pide algo de la historia (marcas, relaciones) no aparece hasta que se cumple; las que piden plata o energía se ven apagadas ("no te alcanza").

## 5. Propuesta para más adelante: el barrio como "mundito" (a decidir por la persona)

La persona pidió "un mundito como Punch Club", con personajes turbios en el barrio (ya están como eventos: el Pampa y Don Cosme). El plan dice **hub de menús con ilustraciones, sin mapa para caminar ni NPCs en el mapa** (secciones 0 y 20), así que esto **es un cambio de diseño y hay que aprobarlo**. Propuesta que respeta el espíritu del plan:

- El hub pasa a ser un **mapa del barrio dibujado** (placeholder primero): Club El Progreso, Casa, Laburo, Kiosco de Felipe, Plaza, Panadería, Tienda y, más lejos, la Arena del centro. **No se camina**: se toca un lugar.
- **Los personajes aparecen en un lugar** distinto cada semana (por ejemplo, Ani en la panadería o en la plaza, Felipe en el kiosco). Si tocás un lugar con alguien, puede salir su evento.
- Técnicamente es chico: un `trigger` nuevo `place` con la condición `place` en `EventRunner`, y que el hub dibuje el mapa en vez de la grilla.
- Lugares nuevos que pueden dar acciones: **Plaza** (correr gratis, ver a Ani, Don Cosme), **Kiosco** (negocios de Felipe), **Panadería**.
