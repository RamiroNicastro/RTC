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
| **Marcas (flags)** | Recuerdan lo que decidiste ("leal_tito", "sofi_ex"…). Sirven para las consecuencias tardías. |
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

En `data/events/` (un archivo por grupo: `acto1.json`, `vida.json`, `humor.json`). Si sumás un archivo nuevo, agregalo a `EVENT_FILES` en `narrative/event_runner.gd`.

```json
{
	"id": "v_sofi_reclamo",
	"trigger": "week",
	"character": "sofi",
	"once": false,
	"cooldown": 6,
	"weight": 2,
	"when": {"statuses": ["novia"]},
	"options": [
		{"requires": {"min_money": 60}, "effects": {"money": -60, "energy": -15, "relations": {"sofi": 12}, "morale": 5}},
		{"effects": {"relations": {"sofi": -15, "tito": 3}}}
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
| `schedule` | `{"events": ["v_chino_bien", "v_chino_mal"], "weeks": 3}`: en 3 semanas sale uno de esos, al azar (consecuencias tardías) |

### Textos

En `i18n/textos.csv`, con claves que salen del id (en mayúsculas):

```
EV_V_SOFI_RECLAMO_TITLE   título
EV_V_SOFI_RECLAMO_TEXT    lo que pasa ({name} = tu nombre, {nick} = tu apodo)
EV_V_SOFI_RECLAMO_1       texto del botón de la opción 1
EV_V_SOFI_RECLAMO_1_RES   qué pasó al elegirla
EV_V_SOFI_RECLAMO_2 …
```

Los saltos de línea se escriben `\n`. **La columna en (inglés) queda vacía por ahora**: usa el español hasta la traducción de la Fase 4 (sección 20 del plan).

### Personajes y situaciones

Son `.tres`: se crean desde el inspector (o copiando uno) en `data/characters/` y `data/statuses/`, y se agregan a `CHARACTERS` o `STATUSES` en `event_runner.gd`. Sus textos van en el CSV (`CHAR_X`, `CHAR_X_ROLE`, `STATUS_X`, `STATUS_X_DESC`).

## 4. Borrador del Acto 1 (para que la persona lo corrija)

> **Todos los nombres son provisorios** (sección 7 del plan). El tono busca drama de barrio con humor de cultura de pelea en los secundarios.

**Elenco:**
- **Don Tito**: entrenador del club El Progreso. Viejo, cascarrabias y de pocas palabras. Lo quiere todo a las siete de la mañana.
- **Bruno Castillo**: el mejor del club y tu compañero. Talentoso y canchero. Es la semilla del **rival central**.
- **El Chino**: tu amigo del barrio. Siempre tiene un negocio "imposible de perder". Fuente de humor y de líos. A Tito no le gusta.
- **Marta, tu vieja**: no quiere que te rompan la cara, pero te banca.
- **Sofi**: la chica de la panadería. Si pasa a ser tu novia, te da moral pero "te afloja las piernas" (menos energía y un poco menos de stamina en la pelea).
- **Don Aurelio**: cutman místico (evento de humor).

**Historia (en orden):**
1. **El club El Progreso** (al empezar). Le decís a Tito a qué venís: campeón, aprender, o "el Chino me dijo que no se paga". → Sigue **Bruno** ("soy el mejor de acá").
2. **Guanteo con Bruno** (semana 2). A full, técnico o "hoy no".
3. **Tu primera victoria** o **El debut que no fue** (después de la primera pelea).
4. **Las vendas en el lavarropas** (tu vieja, después de la primera pelea). Si la invitás al club, 3 semanas después va a verte.
5. **Bruno se va** (al llegar a 3 victorias). Un promotor se lo lleva al centro. Te quedás con Tito, te tienta irte con Bruno o le avisás a Tito ("buchón"). **Esta decisión arma la rivalidad del Acto 2.**
6. **Algún día** (al entrar al top 5 amateur). Bruno y vos en la misma cartelera: "nos vamos a terminar cruzando". Cierra el Acto 1 (marca `acto1_fin`).

**Vida (secundarios, con ramas):**
- **Sofi**: la conocés → salidas en la plaza (la relación sube) → "¿qué somos?" (novios o no) → reclamos de tiempo → si la relación cae a 0, **corta** (moral -15).
- **El Chino**: el negocio de las remeras (en 3 semanas sale bien, +$450, o mal y perdés los $200). Te saca al fulbito si tu moral está por el piso.
- **Tito**: con buena relación, mate y secretos de guardia. Con mala relación, te deja de hablar hasta que pidas disculpas.
- **Después de pelear**: asado del barrio por un KO, o noche larga con tu vieja después de un KO en contra.

**Humor:** el cutman místico (vaselina, fe y un diente de ajo) y Turbo Toro Max, la bebida energética "sin registro pero con onda".

**Enemistades armadas:** Tito contra el Chino (las joditas te alejan del gimnasio), Tito contra Sofi ("las mujeres aflojan las piernas") y Tito contra Bruno (después de que se va).

## 5. Propuesta para más adelante: el barrio como "mundito" (a decidir por la persona)

La persona pidió "un mundito como Punch Club". El plan dice **hub de menús con ilustraciones, sin mapa para caminar ni NPCs en el mapa** (secciones 0 y 20), así que esto **es un cambio de diseño y hay que aprobarlo**. Propuesta que respeta el espíritu del plan:

- El hub pasa a ser un **mapa del barrio dibujado** (placeholder primero): Club El Progreso, Casa, Laburo, Kiosco del Chino, Plaza, Panadería, Tienda y, más lejos, la Arena del centro. **No se camina**: se toca un lugar.
- **Los personajes aparecen en un lugar** distinto cada semana (por ejemplo, Sofi en la panadería o en la plaza, el Chino en el kiosco). Si tocás un lugar con alguien, puede salir su evento.
- Técnicamente es chico: un `trigger` nuevo `place` con la condición `place` en `EventRunner`, y que el hub dibuje el mapa en vez de la grilla.
- Lugares nuevos que pueden dar acciones: **Plaza** (correr gratis, ver a Sofi), **Kiosco** (negocios del Chino), **Panadería**.
