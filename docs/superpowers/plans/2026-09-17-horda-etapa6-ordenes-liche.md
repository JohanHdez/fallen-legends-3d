# Etapa 6: órdenes de los esqueletos del Rey liche — plan de implementación

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** que el Rey liche mande a sus esqueletos con un solo botón: tocar alterna Atacar/Reagrupar y
arrastrar coloca una Emboscada donde se esconden y saltan todos cuando pasa un enemigo.

**Architecture:** reglas puras (huecos de la formación, reparto de la emboscada, siguiente orden,
punto de emboscada con tope) en `Minions` como estáticas; el mismo `Minions` (RefCounted) lleva la IA
de cada esqueleto según la orden de su dueño (`Fighter.minion_order`, `Fighter.ambush_at`) y la llama
`Combat.tick_allies` en lugar del bloque de esbirros de hoy. Los enterrados llevan `"hidden": true` en
su ficha y `Combat.foes_in` y las criaturas los saltan. Entrada: tecla F y botón táctil de órdenes.

**Tech Stack:** Godot 4.7.2, GDScript tipado; pruebas `extends SceneTree`; sondas `--probe`.

**Spec:** `docs/superpowers/specs/2026-09-17-horda-equipo-sigilo-design.md` (punto 9).

## Global Constraints

- Un solo botón (decisión del usuario): toque alterna Atacar/Reagrupar; arrastrar y soltar = Emboscada
  donde se suelte, hasta 12 m. Teclado: F toca; F mantenida apunta con el ratón y al soltar embosca.
- Atacar: al enemigo visible más cercano a cada esqueleto, esté donde esté, rodeando obstáculos; sin
  nadie, vuelven con el Rey. Reagrupar: dos anillos (4 a 2 m, 6 a 3,5 m), 1,5 m entre ellos; golpean a
  quien tengan a 2 m sin perseguir. Emboscada: se reparten en 3 m, se entierran (medio hundidos,
  invisibles para el rival) y saltan todos si un enemigo entra a 4 m de cualquiera → Atacar.
- Los esqueletos nuevos obedecen la orden puesta (empieza en Atacar); vida ×3 por equipos; 3,1 m/s.
- Bots: Atacar peleando, Reagrupar huyendo; no emboscan.
- Botones táctiles ≥ 64 px; `main.gd` no crece más de lo imprescindible.
- Las trazas del Rey liche en la Horda cambian a propósito.

---

### Task 1: Reglas puras (`game/minions.gd`, estáticas)

**Files:** Create `game/minions.gd`; Test `tests/test_minions.gd`.

**Interfaces — Produces:**
```gdscript
class_name Minions
extends RefCounted
const ORDERS := ["attack", "regroup", "ambush"]
const RING_IN := 2.0
const RING_OUT := 3.5
const AMBUSH_RADIUS := 3.0
const AMBUSH_RANGE := 12.0
const AMBUSH_TRIGGER := 4.0
const HIT_REACH := 2.0
const SPEED := 200.0 * LegendData.PX       # 3,1 m/s (enemy_type del 2D)
static func formation_slot(i: int) -> Vector2          # 0-3 anillo interior, 4-9 exterior (y más, se repite)
static func ambush_slot(i: int, n: int) -> Vector2     # dentro de AMBUSH_RADIUS
static func toggle(order: String) -> String            # attack <-> regroup; desde ambush, attack
static func ambush_point(from: Vector3, at: Vector3) -> Vector3   # a AMBUSH_RANGE como mucho
```
- [ ] Prueba: 10 huecos de formación: los 4 primeros a 2 m, los 6 siguientes a 3,5 m, ninguno a menos de 1,4 m de otro; 10 huecos de emboscada dentro de 3 m y a ≥ 0,9 m entre sí; `toggle`; `ambush_point` recorta a 12 m.

### Task 2: IA de los esqueletos por orden

**Files:** Modify `game/minions.gd` (instancia), `game/combat.gd` (`tick_allies`, `spawn_ally`, `foes_in`, `cast_summon`), `game/fighter.gd` (`minion_order`, `ambush_at`), `game/horde.gd` (`_prey_for` salta enterrados), `game/bot_brain.gd` (órdenes).

- [ ] Parsea y una Horda con `--legend=5 --autocast` corre sin errores.

### Task 3: Entrada (F y botón táctil) y dibujo

**Files:** Modify `main.gd` (F, `button_rects`, `_input`/`_release_aim`), `touch_ui.gd`.

- [ ] Capturas a 1280×720 y 1600×720 con `--touch` y el Rey liche con esqueletos.

### Task 4: Sonda `minion_probe` y documentación

- [ ] `tests/minion_probe.gd`: Atacar llega a una diana a 20 m; Reagrupar sigue a menos de 4,5 m de
  media tras andar 25 m; Emboscada: se entierran, `foes_in` no los ve, y una diana a 2 m los hace
  saltar a Atacar. En `PROBES`. README, CLAUDE.md, spec; `tools/check.sh` → OK.
