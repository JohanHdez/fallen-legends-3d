# Horda, etapa 2: Horda en equipo, reanimaciones y derrota — plan de implementación

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** que la Horda se juegue sola o con 1-3 compañeros bot, que en la Horda y en PvP se pueda
levantar a un compañero caído agachándose a su lado (o vuelva solo a los 15/30/60 s si queda alguien en
pie), y que la Horda se pierda cuando cae todo el equipo.

**Architecture:** las reglas puras de reanimación en `Revive` (estáticas, probadas). Un
`ReviveSystem` (RefCounted) aplica esas reglas a las leyendas de un modo cada fotograma y le pide al modo
dónde reaparecer; lo usan `TeamMode` (por ronda) y el nuevo `HordeMode` (toda la partida). `HordeMode`
monta los compañeros bot, el HUD de equipo y la derrota; `Horde` pasa a perseguir a cualquier leyenda del
equipo (campo de flujo con varias fuentes) y escala oleadas con el tamaño del equipo, como el 2D.

**Tech Stack:** Godot 4.7.2, GDScript tipado, pruebas `extends SceneTree`, sondas `--probe`.

**Spec:** `docs/superpowers/specs/2026-09-17-horda-equipo-sigilo-design.md` (puntos 7 y 8).

## Global Constraints

- Commit y push solo si el usuario lo pide.
- Cifras del 2D (`player.gd`, `horde.gd`): `REVIVE_RANGE` 90 px, `REVIVE_TIME` 3 s, `REVIVE_HP` 0,5,
  `SPAWN_INVULN` 3 s, `RESPAWN_STEPS` [15, 30, 60], oleada `6 + 4·w + 3·(n−1)`, tope `+8·(n−1)`.
- Gesto de reanimar: compañero vivo **agachado** a ≤ 90 px (1,4 m). Decisión del usuario: también en PvP.
- Cuenta de caídas: Horda, toda la partida; PvP, por ronda.
- Horda: cae todo el equipo (o tú, si vas solo) → fin de partida.
- Textos en español con tildes; botones ≥ 64 px; UI con `set_anchors_and_offsets_preset`.
- `main.gd` no crece: la lógica nueva va en sus scripts.

---

### Task 1: Reglas puras de reanimación (`game/revive.gd`)

**Files:** Create `game/revive.gd`; Test `tests/test_revive.gd`.

**Interfaces — Produces:**
```gdscript
class_name Revive
extends RefCounted
const RANGE := 90.0 * LegendData.PX        # 1,4 m (player.REVIVE_RANGE del 2D)
const TIME := 3.0                          # REVIVE_TIME
const HP := 0.5                            # REVIVE_HP: vuelve con media vida
const INVULN := 3.0                        # SPAWN_INVULN
const STEPS := [15.0, 30.0, 60.0]          # horde.RESPAWN_STEPS
static func respawn_time(downs: int) -> float          # downs = caídas contando esta (1, 2, 3…)
static func progress(p: float, helped: bool, delta: float) -> float   # sube o baja a 1/TIME por s, en [0, 1]
static func can_help(helper_alive: bool, helper_crouch: bool, dist: float) -> bool
```

- [ ] Prueba: `respawn_time(1)=15`, `(2)=30`, `(3)=60`, `(7)=60`, `(0)=15`; `progress(0, true, 1.5)=0.5`, `progress(0.5, false, 0.75)=0.25`, nunca < 0 ni > 1; `can_help(true, true, 1.3)`, no si no está agachado, no si está muerto, no a 1,5 m.
- [ ] Ver fallar, implementar, ver pasar.

### Task 2: `ReviveSystem` y reanimaciones en PvP

**Files:** Create `game/revive_system.gd`; Modify `game/fighter.gd` (`downs`, `revive_progress`), `game/team_mode.gd`, `game/bot_brain.gd`, `ui/match_hud.gd`, `game/combat.gd` (`_hurt_fighter`: caída también fuera de PvP pasa por `dead_t`/colisión); Test `tests/match_probe.gd`.

**Interfaces — Produces:**
```gdscript
class_name ReviveSystem
extends RefCounted
var respawn_at: Callable        # func(f: Fighter) -> Vector3: dónde vuelve solo
var revives := 0                # levantados por un compañero (sondas)
var respawns := 0               # vueltos solos (sondas)
func _init(p_main: Main, p_respawn_at: Callable)
func on_down(f: Fighter) -> void        # downs += 1; respawn_t = Revive.respawn_time(downs); revive_progress = 0
func tick(delta: float) -> void         # para cada leyenda caída de un equipo con alguien en pie
func stand_up(f: Fighter, at: Vector3, hp_frac: float) -> void   # vida, colisión, Idle, inmunidad, cerebro
func reset_counts() -> void             # downs = 0 de todas (PvP, cada ronda)
func helper_of(f: Fighter) -> Fighter   # compañero que la está levantando, o null
```
`Fighter`: `var downs := 0`, `var revive_progress := 0.0`.

Reglas en `tick`: si ningún compañero de su equipo está vivo, no corre nada. Si `helper_of(f)` ≠ null,
`revive_progress = Revive.progress(…, true, delta)`; a 1 → `stand_up(f, f.pos(), Revive.HP)`,
`revives += 1`. Si no, el progreso baja y `respawn_t -= delta`; a 0 → `stand_up(f, respawn_at.call(f), 1.0)`,
`respawns += 1`. `stand_up` pone `invuln_t = Revive.INVULN`, `dead_t = -1`, colisión activa, `Idle`, borra
estados (`stun_t`, `knock_t`, `slow_t`, `blind_t`) y el `target` del cerebro.

`TeamMode`: crea el sistema con `respawn_at` = celda de su zona de salida; `on_fighter_down` llama a
`revive.on_down(f)`; `tick` llama a `revive.tick(delta)` solo con `rules.state == "playing"`;
`_reset_round` llama a `revive.reset_counts()`. La eliminación de ronda no cambia (cuenta leyendas en pie).

`BotBrain._think`: tras el gas y antes de huir, si hay un compañero caído y ningún rival a menos de 8 m,
ir a él; a ≤ `Revive.RANGE * 0.8`, parar y `f.crouch = true`. En cualquier otro caso `f.crouch = false`.

`MatchHud`: si has caído, "Has caído · vuelves en N s, o si un compañero se agacha a tu lado";
si levantas a alguien, "Reanimando a X… 45 %"; sobre cada caído de tu equipo, `Label3D` "¡CAÍDO! N s".

- [ ] Sonda: `match_probe` imprime `[SONDA] reanimaciones: %d levantados, %d vueltos solos` y falla si en
  4v4 no hubo ninguna de las dos, o si una ronda dura más de su tope (la eliminación sigue funcionando).
- [ ] `tools/check.sh probes` en verde.

### Task 3: Horda en equipo (`game/horde_mode.gd`, menú y `--team`)

**Files:** Create `game/horde_mode.gd`, `ui/horde_hud.gd`; Modify `main.gd` (crear `HordeMode`, `--team=N`, `Engine` meta `fl_horde_team`, cámara de espectador también en la Horda, `on_fighter_down`), `ui/mode_menu.gd` (selector 1-4 bajo los modos, visible con Horda), `game/horde.gd` (presas y campo de flujo con varias leyendas; tamaño de oleada y tope por equipo; crédito de bajas por autor), `game/combat.gd` (`main._kill_zombie(z, by)`).

**Interfaces — Produces:**
```gdscript
class_name HordeMode
extends RefCounted
var size := 1
var revive: ReviveSystem
var hud: HordeHud
var over := false
func _init(p_main: Main)
func setup(p_size: int) -> void      # nav, compañeros bot junto a ti, leyendas sin repetir, HUD
func tick(delta: float) -> void      # cerebros, reanimaciones, derrota
func move_bots(delta: float) -> void
func on_fighter_down(f: Fighter, by: Fighter) -> void
func team_alive() -> int
```
`Horde`: `func party_size() -> int` (leyendas del equipo 1); oleada `6 + 4·w + 3·(party−1)`; tope
`Main.MAX_ALIVE + 8·(party−1)`; `_rebuild_flow(goals: Array[Vector2i])` BFS con todas las leyendas vivas
como fuente; `_enemy_prey` elige la leyenda viva y visible (o esbirro/señuelo) más cercana;
`kill_zombie(z, by)`: insignias solo si `by == null or by.is_player`, si no `by.kills += 1`.

- [ ] Sonda nueva `tests/horde_probe.gd` (`--team=4 --autoplay`): los 4 del equipo son `Fighter` del
  equipo 1 con leyendas distintas; las criaturas golpean a más de una leyenda distinta; pasan al menos 2
  oleadas; sin errores.
- [ ] Capturas del menú con el selector (1280×720) y de la Horda con equipo (`--team=3 --touch`).

### Task 4: Derrota y reanimaciones en la Horda

**Files:** Modify `game/horde_mode.gd`, `ui/horde_hud.gd`, `main.gd` (quitar `_tick_player_death` y el uso de `PLAYER_HP`), `game/horde.gd` (parar oleadas al acabar).

- `HordeMode` crea `ReviveSystem` con `respawn_at` = celda transitable más cercana al centro del área
  limpia. Cuenta de caídas de toda la partida (no se reinicia).
- Si `team_alive() == 0`: `over = true` a los 2 s de la última caída, se paran oleadas y cerebros,
  `[FIN] horda oleada=%d bajas=%d` y pantalla final (oleada alcanzada, bajas y caídas por leyenda,
  Revancha y Menú).
- [ ] `horde_probe --team=4`: hubo al menos una reanimación o vuelta sola; con `--team=1` y criaturas
  forzadas (`--zombies=60 --near=3`) la partida acaba en derrota antes de `--secs`.
- [ ] Trazas deterministas nuevas de referencia (las de leyendas que morían en 20 s cambian: ahora
  pierden).

### Task 5: Documentación y puerta de calidad

- [ ] README (Horda en equipo, reanimación, derrota, `--team`), CLAUDE.md (arquitectura, deuda: se va la
  de `PLAYER_HP` y "no hay forma de perder"), spec (pasos 2 hechos), `tools/check.sh` con
  `horde_probe` en `PROBES`, y `RESULTADO: OK`.
