# Horda, etapa 1: extracción y arreglos rápidos — plan de implementación

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** sacar la Horda de `main.gd` a `game/horde.gd` sin cambiar nada y, encima, añadir el sonido y los
rayos de la Trampa y la Tormenta eléctricas, el botón táctil de agacharse y la zona de la Horda que se
para al 60 %.

**Architecture:** `Horde` (RefCounted, como `TeamMode`) recibe el estado y las funciones de oleadas,
especies, jefe, campo de flujo e IA de criaturas; `main.gd` la crea en la Horda y conserva alias para lo
que leen otros scripts. Los arreglos rápidos tocan `Combat` (rayos y sonido), `main.gd`/`touch_ui.gd`
(botón) y la zona (`_setup_zone`).

**Tech Stack:** Godot 4.7.2, GDScript con tipado estático, pruebas `extends SceneTree`, sondas `--probe`.

**Spec:** `docs/superpowers/specs/2026-09-17-horda-equipo-sigilo-design.md` (puntos 1, 3 y 4, y el paso 0).

## Global Constraints

- Commit y push solo cuando el usuario lo pida (CLAUDE.md § Git): este plan no hace commits.
- `main.gd` no crece; tope de aviso 3.000 líneas.
- Determinismo: nada de `randomize()`; el orden de las llamadas a `rng` no cambia en la extracción.
- Comentarios y textos en español con tildes; identificadores en inglés; tipado estático.
- Botones táctiles de 64 px o más; probar a 1280×720 y 1600×720 con `--touch`.
- Sonidos de Flare: CC-BY-SA 3.0, con fila de licencia en `docs/DESPLIEGUE.md`.
- Nada está terminado sin `tools/check.sh` en verde y, si es visual, una captura mirada.

---

### Task 1: Extraer la Horda a `game/horde.gd` (trazas idénticas)

**Files:**
- Create: `game/horde.gd`
- Modify: `main.gd` (bloque de oleadas y criaturas, líneas ~1713-1745 y ~1896-2502; `_ready`; `_physics_process`; `_tick_zone`; HUD de depuración)
- Modify: `game/combat.gd` (`main.zombies` sigue valiendo por alias), `tests/rocks_probe.gd`

**Interfaces:**
- Produces: `class_name Horde extends RefCounted` con
  `var zombies: Array`, `var wave: int`, `var left_to_spawn: int`, `var spawn_t: float`,
  `var spawn_cells: Array`, `var spawned: Dictionary`, `var boss_alive: bool`;
  `func _init(p_main: Main)`, `func setup() -> void`, `func tick(delta: float) -> void`,
  `func spawn_boss() -> void`, `func spawn_zombie(at := Vector3.INF) -> void`,
  `func spawn_targets(n: int) -> void`, `func kill_zombie(z: Dictionary) -> void`.
- `main.gd` añade `var horde: Horde = null` y el alias
  `var zombies: Array: get: return horde.zombies if horde != null else _no_zombies` (con
  `var _no_zombies: Array = []`), y `func _kill_zombie(z)` que llama a `horde.kill_zombie(z)`.

- [ ] **Step 1: Grabar las trazas de referencia de antes**

Run: `scratchpad/baseline/run_baseline2.sh scratchpad/baseline/e0` (las 13 trazas: 10 leyendas, jefe, táctil, recargas).
Expected: 13 ficheros; `diff` contra `baseline/c1` sin diferencias (el código actual es el mismo que las produjo).

- [ ] **Step 2: Crear `game/horde.gd` moviendo el código tal cual**

Mover de `main.gd` a `Horde`, sin cambiar el cuerpo salvo el prefijo `main.` en lo que sigue en `Main`:

| En `main.gd` | En `Horde` |
|---|---|
| `zombies`, `_flow`, `_flow_t`, `_wave`, `_left_to_spawn`, `_spawn_t`, `_break_t`, `_spawn_cells`, `_grave_cells`, `_spawned`, `_boss_proto`, `_boss_alive` | `zombies`, `_flow`, `_flow_t`, `wave`, `left_to_spawn`, `spawn_t`, `_break_t`, `spawn_cells`, `_grave_cells`, `spawned`, `_boss_proto`, `boss_alive` |
| `_setup_horde`, `_start_wave`, `_spawn_boss`, `_rebuild_flow`, `_spawn_zombie`, `_pick_species`, `_tick_horde`, `_tick_zombie`, `_separation`, `_kill_zombie`, `_spawn_targets`, `_enemy_prey`, `_enemy_target` | `setup`, `_start_wave`, `spawn_boss`, `_rebuild_flow`, `spawn_zombie`, `_pick_species`, `tick`, `_tick_zombie`, `_separation`, `kill_zombie`, `spawn_targets`, `_enemy_prey`, `_enemy_target` |

Se quedan en `Main` (los usan leyendas, esbirros o la cámara): constantes `ZOMBIE_*`, `SPECIES`, `MAX_ALIVE`, `SPAWN_EVERY`, `WAVE_BREAK`, `FLOW_EVERY`, `BOSS_*`; `_proto_of`, `_species_proto`, `_zombie_proto`, `_add_eyes`, `_make_character`, `_make_bar`, `_anims_of`, `_play_all`, `_cell_of`, `_cell_pos`, `_in_map`, `_cells_around`, `_kills`, `_badge_for`, `_show_badge`, `_play_music`, `_tick_player_death`, `player_hidden`.

Cabecera del fichero nuevo:

```gdscript
## La Horda: oleadas de criaturas, especies, jefe, campo de flujo hacia el jugador e IA de cada
## criatura. Sacada de main.gd el 2026-09-17 sin cambiar nada (13 trazas deterministas idénticas),
## para poder cambiarla después: sentidos de las criaturas, Horda en equipo y jefe-leyenda.
## main.gd la crea solo en la Horda y le da cuerda cada fotograma.
class_name Horde
extends RefCounted

var main: Main
var combat: Combat
var vfx: Vfx
var rng: RandomNumberGenerator

var zombies: Array = []        # {node, anim, hp, swing_t, dead_t}
# ... resto de variables de la tabla ...


func _init(p_main: Main) -> void:
	main = p_main
	combat = p_main.combat
	vfx = p_main.vfx
	rng = p_main.rng
```

Los nodos se añaden con `main.add_child(body)`; el jugador es `main.player`/`main.pf`.

- [ ] **Step 3: Enlazar en `main.gd`**

```gdscript
var horde: Horde = null
var _no_zombies: Array = []
var zombies: Array:
	get:
		return horde.zombies if horde != null else _no_zombies


func _kill_zombie(z: Dictionary) -> void:
	horde.kill_zombie(z)
```

En `_ready`: donde se llamaba `_setup_horde()`, `horde = Horde.new(self)` y `horde.setup()` (crear
`horde` ANTES de leer `--zombies`, `--near`, `--boss`, `--dianas`, que pasan a `horde.left_to_spawn`,
`horde.spawn_t`, `horde.spawn_cells`, `horde.spawn_boss()`, `horde.spawn_targets(n)`). En
`_physics_process`: `_tick_horde(delta)` → `horde.tick(delta)`. HUD de depuración y `--log`: `_wave`,
`_left_to_spawn`, `_spawned` → `horde.wave`, `horde.left_to_spawn`, `horde.spawned`.
`tests/rocks_probe.gd`: `main._left_to_spawn = 40` → `main.horde.left_to_spawn = 40`.

- [ ] **Step 4: Refrescar clases y parsear**

Run: `godot --headless --path . --import` y `tools/check.sh parse`
Expected: `RESULTADO: OK`

- [ ] **Step 5: Comparar trazas**

Run: `scratchpad/baseline/run_baseline2.sh scratchpad/baseline/e1` y comparar con `e0` fichero a fichero.
Expected: 13 iguales. Si alguna difiere, el orden de llamadas a `rng` o de los ticks cambió: revisar
antes de seguir.

- [ ] **Step 6: Puerta de calidad**

Run: `tools/check.sh`
Expected: `RESULTADO: OK`; `main.gd` baja de ~2.900 a ~2.300 líneas.

---

### Task 2: Rayos y sonido de la Trampa y la Tormenta eléctricas

**Files:**
- Create: `assets/audio/spells/shock.ogg`, `assets/audio/spells/thunder.ogg` (copiados de `~/Downloads/arena-arpg/assets/flare/soundfx/powers/`)
- Modify: `game/combat.gd` (`tick_traps`, `tick_storms`, contador `storm_strikes`), `tests/match_probe.gd`, `docs/DESPLIEGUE.md`, `README.md` (§ Licencias)
- Test: `tests/test_combat_rules.gd`

**Interfaces:**
- Produces: `Combat.STRIKE_SOUND := "shock"`, `Combat.THUNDER_SOUND := "thunder"`,
  `var storm_strikes := 0` (rayos de tormenta que cayeron sobre alguien).

- [ ] **Step 1: Prueba que falla**

```gdscript
	# Sonidos de los rayos: existen y se cargan por el nombre que usa Main._sfx.
	for s in [Combat.STRIKE_SOUND, Combat.THUNDER_SOUND]:
		_check(ResourceLoader.exists("res://assets/audio/spells/%s.ogg" % s), "falta el sonido %s" % s)
```

Run: `godot --headless --path . -s tests/test_combat_rules.gd` → FALLO (no existen las constantes).

- [ ] **Step 2: Copiar sonidos e importar**

Run: `cp ~/Downloads/arena-arpg/assets/flare/soundfx/powers/{shock,thunder}.ogg assets/audio/spells/ && godot --headless --path . --import`

- [ ] **Step 3: Sonido en cada rayo de trampa**

En `tick_traps`, donde cada víctima recibe `vfx.spark(...)`, sonar una vez por descarga (no por víctima):

```gdscript
			var struck := false
			for z in foes_in(team, node.position, float(t["rad"]), int(t["tgt"])):
				# ... daño como ahora ...
				if not t["beacon"]:
					vfx.spark(z["node"].global_position)
					struck = true
			if struck and owner != null:
				_sound(owner, STRIKE_SOUND, -4.0)
```

- [ ] **Step 4: Rayo por enemigo en la Tormenta**

En `tick_storms`, para las zonas con golpe (`not bool(st.get("gas", false))` y `String(st.get("fx", "spark")) == "spark"` y `float(st["fstun"]) > 0.0`): en el golpe inicial y en cada descarga del campo, `vfx.spark` sobre cada víctima, `storm_strikes += 1` por víctima y un `_sound(owner, THUNDER_SOUND, -3.0)` por descarga con víctimas.

- [ ] **Step 5: Sonda**

`tests/match_probe.gd` imprime `[SONDA] rayos de tormenta: %d` con `main.combat.storm_strikes`.

- [ ] **Step 6: Verificar**

Run: `tests/test_combat_rules.gd` → OK; `godot --headless --fixed-fps 60 --path . -- --mode=1v1 --legend=0 --autoplay --probe=match_probe` → `rayos de tormenta` > 0 y `match_probe: OK`.

- [ ] **Step 7: Licencia**

Fila en `docs/DESPLIEGUE.md` (tabla de recursos): `assets/audio/spells/shock.ogg`, `thunder.ogg` · Flare (flare-game) · CC-BY-SA 3.0 · atribuir; y la misma mención en README § Licencias.

---

### Task 3: Botón táctil de agacharse y Ctrl en la pausa

**Files:**
- Modify: `main.gd` (`button_rects`, `_input` táctil, `_touch_crouch`), `touch_ui.gd`, `ui/pause_menu.gd`

**Interfaces:**
- Produces: índice de botón `CROUCH_BTN := 3` en `button_rects()` (`{"idx": 3, "c": …, "r": 34.0, "name": "Agacharse"}`); `_touch_crouch` conmuta con un toque y se pone a `false` al morir.

- [ ] **Step 1: Botón**

En `button_rects()`, junto al joystick (arriba a la derecha del círculo base, sin pisarlo): `{"idx": CROUCH_BTN, "c": joy_center() + Vector2(JOY_RADIUS + 70.0, -JOY_RADIUS * 0.9), "r": 34.0, "name": "Agacharse"}`. En `_input`, un toque sobre `CROUCH_BTN` conmuta `_touch_crouch` y no arranca apuntado. `touch_ui._ability` dibuja el índice 3 con la base, el texto "▼" y un aro dorado si está activo, sin recarga.

- [ ] **Step 2: Al morir se suelta**

Donde tu leyenda cae (`Combat._hurt_fighter`, rama de `f.is_player`), `main._touch_crouch = false`.

- [ ] **Step 3: Pausa**

`ui/pause_menu.gd` añade una línea pequeña bajo los botones: "Ctrl: agacharse · Q/clic: básica · E: táctica · R: definitiva · C: cámara".

- [ ] **Step 4: Verificar con capturas**

Run: `godot --path . --resolution 1600x720 -- --mode=2v2 --autoplay --touch --shot=… --wait=300` y a 1280×720; mirar que el botón no pisa el joystick ni los de habilidad y mide ≥ 64 px.

---

### Task 4: La zona de la Horda se para al 60 %

**Files:**
- Modify: `main.gd` (`_setup_zone`, `_tick_zone`: `ZONE_MIN` → `_zone_min`)
- Test: `tests/test_combat_rules.gd` (o `test_zone.gd`)

**Interfaces:**
- Produces: `static func zone_floor(r0: float, pvp: bool) -> float` en `Main`: Horda `r0 * HORDE_ZONE_STOP` (`HORDE_ZONE_STOP := 0.6`); por equipos `ZONE_MIN`.

- [ ] **Step 1: Prueba que falla**

```gdscript
	_check(is_equal_approx(Main.zone_floor(63.0, false), 63.0 * 0.6), "en la Horda la zona se para al 60 %")
	_check(is_equal_approx(Main.zone_floor(40.0, true), Main.ZONE_MIN), "por equipos cierra hasta ZONE_MIN")
```

- [ ] **Step 2: Implementar y usar en `_tick_zone`** (`_zone_min := zone_floor(_zone_r0, is_pvp())` fijado en `_setup_zone` y en `reset_zone`).

- [ ] **Step 3: Verificar**: prueba OK; `--zonewait=1 --zonefast=40 --log` en la Horda imprime el radio parándose en ~38 m.

---

### Task 5: Referencias nuevas, documentación y puerta de calidad

- [ ] **Step 1:** grabar trazas nuevas de referencia (`baseline/e2`); la de la leyenda 0 (Tormentero) cambia por los rayos (consumen `rng` en `Vfx.spark`): comprobar que el resto sale igual que `e1`.
- [ ] **Step 2:** README (reglas de la zona en la Horda, botón de agacharse, sonidos de rayo), CLAUDE.md (tabla de arquitectura con `Horde`, deuda de `main.gd` actualizada), spec (marcar pasos 0, 1, 3 y 4 hechos).
- [ ] **Step 3:** `tools/check.sh` → `RESULTADO: OK`.
