# Horda, etapa 4: sentidos de las criaturas — plan de implementación

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** que las criaturas no sepan siempre dónde está el equipo: deambulan buscando, te ven según
luz, obstáculos y si estás escondido, la que te descubre grita y avisa a las que estén a 30 m, y si te
pierden rebuscan donde te vieron y vuelven a deambular.

**Architecture:** reglas puras en `CreatureSenses` (¿ve a esta leyenda?, línea de visión en la
rejilla, alcance de vista según la noche, quién oye un grito). `Horde._tick_zombie` pasa a una máquina
de estados por criatura (`wander` → `chase` → `search` → `wander`) guardada en su ficha, con una
comprobación de sentidos escalonada cada 0,25 s, un campo de flujo por leyenda viva para perseguir y
rutas `NavGrid` para deambular y rebuscar. `Horde` guarda cada detección y cada grito para las sondas.

**Tech Stack:** Godot 4.7.2, GDScript tipado; pruebas `extends SceneTree`; sondas `--probe`.

**Spec:** `docs/superpowers/specs/2026-09-17-horda-equipo-sigilo-design.md` (punto 6).

## Global Constraints

- Vista 12 m de día, 8 m de noche (interpolada con `Main._night_amount`), con línea de visión (una
  celda no transitable entre medias la corta).
- Escondido (agachado en hierba alta o invisible): solo a ≤ 1,5 m; quien ya lo persigue, a ≤ 4 m.
- Grito al descubrir: avisa a las criaturas a ≤ 30 m (decisión del usuario), "!" 1 s y sonido.
- Perder el rastro: 3 s sin detectarlo → `search` en la última posición durante 8 s → `wander`.
- Deambular: celda transitable al azar a ≤ 10 celdas, preferentemente dentro del área limpia; esperar
  0,5-1,5 s al llegar.
- Sin asignaciones por fotograma en el bucle de 40 criaturas; comprobaciones escalonadas.
- Esbirros y señuelos siguen siendo presa a ≤ 14 m como hasta ahora (los señuelos existen para engañar).
- Las trazas de la Horda cambian a propósito: se graban unas nuevas al final.

---

### Task 1: `CreatureSenses` (pura)

**Files:** Create `game/creature_senses.gd`; Test `tests/test_creature_senses.gd`.

**Interfaces — Produces:**
```gdscript
class_name CreatureSenses
extends RefCounted
const SIGHT_DAY := 12.0
const SIGHT_NIGHT := 8.0
const HIDDEN_NEAR := 1.5
const HIDDEN_CHASE := 4.0
const ALERT_RADIUS := 30.0
const LOSE_AFTER := 3.0
const SEARCH_TIME := 8.0
const WANDER_CELLS := 10
const CHECK_EVERY := 0.25
static func sight_range(night: float) -> float                 # lerp de 12 a 8 con night en [0, 1]
static func can_see(dist: float, hidden: bool, chasing: bool, night: float, los: bool) -> bool
static func los_clear(grid: Array, a: Vector2i, b: Vector2i) -> bool   # celdas intermedias transitables
static func hears(shouter: Vector3, listener: Vector3) -> bool          # a ≤ ALERT_RADIUS en el plano
```
- [ ] Prueba: `sight_range(0)=12`, `(1)=8`; `can_see(11, false, false, 0, true)`, no a 13 de día, no a 9 de noche, no sin línea de visión; escondido: sí a 1,4, no a 2, persiguiéndolo sí a 3,9, no a 4,5 (la línea de visión no cuenta pegado); `los_clear` en una rejilla de 5×5 con un muro en medio (bloquea en recto, libre por el lado); `hears` a 29 sí y a 31 no, ignorando la altura.

### Task 2: Máquina de estados en `Horde`

**Files:** Modify `game/horde.gd`; Modify `main.gd` solo si hace falta exponer `_night_amount`.

Ficha de criatura (en `spawn_zombie`): `"state": "wander"`, `"know": -1`, `"last": Vector3.ZERO`,
`"seen_t": 99.0`, `"search_t": 0.0`, `"sense_t": CHECK_EVERY * (índice % 5) / 5`, `"goal": Vector3`,
`"path": []`, `"wait_t": 0.0`, `"alert": null` (Label3D "!", perezoso).

Cada fotograma: `seen_t += delta`; `sense_t -= delta`; al llegar a 0 → `_sense(z)`:
leyendas vivas del equipo, la más cercana visible según `can_see` (línea de visión solo si no está
escondida y está a tiro de vista) → si hay: si no la perseguía, `_shout(z, f)`; `state = chase`,
`know = f.id`, `last = f.pos()`, `seen_t = 0`. Guarda `{dist, hidden, chasing, night}` en
`detections` (tope 400) para las sondas.
`_shout(z, f)`: `shouts += 1`; "!" 1 s; sonido a volumen por distancia; a cada criatura viva que
`hears` y no esté persiguiendo: `chase`, `know`, `last`, `seen_t = 0`; `alerted.append(dist)`.
Transiciones: `chase` y `seen_t ≥ LOSE_AFTER` → `search` (`search_t = SEARCH_TIME`, meta `last`);
`search` y `search_t ≤ 0` → `wander`.

Movimiento: `chase` con `seen_t < 0,5` → campo de flujo de su leyenda (`_flows[f.id]`, BFS por
leyenda viva cada 0,4 s); si no → ruta `NavGrid` a `last`. `search` → ruta a `last`; al llegar,
metas al azar a ≤ 3 celdas de `last`. `wander` → ruta a una celda al azar a ≤ `WANDER_CELLS`; si la
criatura está fuera del área limpia o el azar cae fuera, la meta se acerca al centro. Espera 0,5-1,5 s.
Ataque: la leyenda que persigue si está a su alcance y la ve, o un esbirro/señuelo a su alcance.

- [ ] Parsea; una Horda de 60 s con `--team=2 --autoplay --log` sin errores.

### Task 3: Sonda de sentidos

**Files:** Create `tests/senses_probe.gd`; Modify `tools/check.sh` (`PROBES`).

- [ ] Cada detección de `detections` cumple la regla con 0,5 m de tolerancia (lo que se mueven en
  0,25 s); cada distancia de `alerted` ≤ 30 m; hay al menos un grito en una partida de 90 s con
  `--team=2 --autoplay --near=8 --zombies=20`; en ventanas de 10 s, al menos el 70 % de las criaturas
  que deambulan se han movido más de 3 m; con `--hide` (la sonda deja tu leyenda agachada en la hierba
  alta más cercana y sin moverse, `--team=1`, sin `--autoplay`), ninguna criatura te detecta a más de
  1,5 m mientras sigues escondida.

### Task 4: Trazas, documentación y puerta de calidad

- [ ] Trazas nuevas de referencia; README (sección "Cubrirse y esconderse" y criaturas), CLAUDE.md,
  spec (paso 4 hecho); `tools/check.sh` → `RESULTADO: OK`.
