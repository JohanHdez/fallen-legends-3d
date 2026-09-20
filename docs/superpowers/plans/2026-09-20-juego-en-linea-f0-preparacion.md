# Juego en línea, fase 0: preparar el combate para la red — plan de implementación

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Dejar el juego listo para que un servidor sin pantalla pueda simular la partida: la entrada
del jugador fuera de `main.gd`, `Vfx` sorteando con su propio generador y todos los efectos del
combate saliendo por un único punto.

**Architecture:** Tres refactores, uno por tarea, sin comportamiento nuevo. Dos de ellos tienen que
dar **trazas idénticas** (el método del CLAUDE.md); el del generador de `Vfx` las cambia **una vez**
y a propósito, así que se vuelven a grabar las referencias.

**Tech Stack:** Godot 4.7.2, GDScript tipado. Comprobación: `tools/check.sh` y comparación de trazas
deterministas con `diff`.

**Spec:** `docs/superpowers/specs/2026-09-18-juego-en-linea-design.md`, sección "Separar lógica y
efectos en el combate" y fase **F0**. La fase 1 (red y sala) ya está hecha y commiteada.

## Global Constraints

- Godot **4.7.2**, GDScript con tipado estático; comentarios y textos de UI en **español con
  tildes**, identificadores en inglés; los comentarios explican el porqué y la historia.
- **`main.gd` no crece**: va por **2.901** líneas de 3.000 (tope del hook). La tarea 1 tiene que
  **bajarlo** de 2.700.
- **Nada de `randomize()`** en el juego.
- **Determinismo**: dos ejecuciones iguales dan la MISMA traza. Las tareas 1 y 3 se dan por buenas
  **solo** si la traza no cambia ni un carácter (quitando `fps=`); la tarea 2 la cambia una vez.
- **Commit y push solo cuando el usuario lo pida.** Los pasos acaban en "punto de control".
- `map_builder.gd` y `dungeon_gen.gd` no se tocan (hook).
- Ediciones hechas por Bash (sed, python) no pasan por los hooks: después, `tools/check.sh parse <fichero>`.
- Nada terminado sin evidencia: la salida de `tools/check.sh` y, cuando sea visual, una captura mirada.

## Cómo se comparan las trazas (se usa en las tres tareas)

```bash
# ANTES de tocar nada, y otra vez DESPUÉS. `$N` es la leyenda (0..6).
traza() {   # traza <ruta> <legend>
  godot --headless --fixed-fps 60 --path . -- --legend="$2" --autocast --near=4 --zombies=14 \
    --log --meleelog --dashlog --sporelog --shot=/tmp/t.png --wait=1200 2>&1 \
    | grep -E "^\[" | sed -E 's/fps=[0-9]+//' > "$1"
}
for n in 0 1 2 3 4 5 6; do traza /tmp/antes_$n.log $n; done
# ... cambios ...
for n in 0 1 2 3 4 5 6; do traza /tmp/despues_$n.log $n; done
for n in 0 1 2 3 4 5 6; do diff -q /tmp/antes_$n.log /tmp/despues_$n.log || echo "CAMBIÓ la leyenda $n"; done
```
Siete leyendas, no una: cada una usa mecánicas distintas (esbirros, señuelos, esporas, guardia…).

---

## Mapa de ficheros

| Fichero | Acción | Responsabilidad |
|---|---|---|
| `game/player_input.gd` | Crear | `PlayerInput`: teclado, ratón y táctil del jugador; apuntado |
| `main.gd` | Modificar | Se queda con la cámara, el mundo y el HUD; delega la entrada |
| `touch_ui.gd` | Modificar | Lee el estado táctil de `main.input` en vez de `main` |
| `tests/test_touch_layout.gd` | Modificar | Las constantes del reparto pasan a `PlayerInput` |
| `fx/vfx.gd` | Modificar | Generador propio (`_rng`), sembrado con la semilla de la partida |
| `game/combat.gd` | Modificar | Los efectos salen por `emit_fx`; la lógica no llama a `Vfx` |
| `game/fx_sink.gd` | Crear | `FxSink`: quién recibe los efectos (pintarlos o convertirlos en avisos) |
| `tests/test_fx_sink.gd` | Crear | Prueba pura del catálogo de efectos y sus argumentos |

---

### Task 1: La entrada del jugador sale de `main.gd`

**Files:**
- Create: `game/player_input.gd`
- Modify: `main.gd`, `touch_ui.gd`, `tests/test_touch_layout.gd`

**Interfaces:**
- Produces: `class_name PlayerInput extends Node`, creado por `main.gd` en `_ready` y guardado en
  `main.input`. Mantiene **los mismos nombres** que tenían en `main.gd` para no cambiar lo que leen
  `touch_ui.gd` y las sondas:
  - Constantes del reparto táctil: `JOY_RADIUS`, `JOY_RUN`, `JOY_GRAB`, `KNOB_RADIUS`, `DEAD_ZONE`,
    `ABILITY_SIDE`, `MAIN_SIDE`, `CROUCH_BTN`, `CROUCH_RADIUS`, `CROUCH_OFFSET`, `ORDERS_BTN`,
    `ORDERS_RADIUS`, `ORDERS_OFFSET`, `ORDERS_TAP`, `AIM_DEAD`, `AIM_RADIUS`.
  - Estado: `_joy_idx`, `_joy_vec`, `_joy_origin`, `_aim_btn`, `_aim_idx`, `_aim_drag`, `_look_idx`,
    `_touch_crouch`, `_preview`.
  - Funciones: `joy_center()`, `button_center(i)`, `button_rects()`, `crouch_center(joy)` (estática),
    `_button_at(p)`, `_joy_from(p)`, `_release_aim()`, `_build_aim()`, `_aim_point(max_range)`,
    `_aim_point_touch(idx)`, `_auto_aim(i)`, `_ambush_aim()`, `_drag_point(...)`, `_try_cast(i, at)`,
    `_auto_cast()`, `_setup_touch()`, y los manejadores `_input(e)` / `_unhandled_input(e)`.
- Consumes: `main` (cámara, `pf`, `combat`, `_frozen()`, `_yaw`, `_pitch`, `touch`, `touch_ui`).

- [ ] **Step 1: Grabar las trazas de antes**

Run el bloque de "Cómo se comparan las trazas" (los siete `traza /tmp/antes_$n.log $n`).
Expected: siete ficheros con líneas `[HORDA]`, `[BAJA]`, etc. Guarda `wc -l /tmp/antes_*.log` en el
informe: si alguno está vacío, la grabación no vale y hay que parar.

- [ ] **Step 2: Crear `game/player_input.gd` con lo que hay hoy**

Mueve **tal cual** (sin reescribir la lógica) las constantes, el estado y las funciones de la lista
de "Interfaces". El fichero empieza con una cabecera que explique el porqué:

```gdscript
## La entrada del jugador: teclado, ratón, táctil y apuntado. Sale de main.gd el 2026-09-20 para la
## fase 0 del juego en línea (docs/superpowers/specs/2026-09-18-juego-en-linea-design.md): el
## servidor sin pantalla no tiene entrada, y main.gd estaba a 2.901 líneas de las 3.000 del tope.
## No cambia nada de lo que hacía: mismas constantes, mismos nombres y las mismas trazas.
class_name PlayerInput
extends Node

var main: Main
```

En `main.gd`:
- `var input: PlayerInput` y, en `_ready` (donde hoy se llama a `_setup_touch()`), crear el nodo,
  ponerle `input.main = self` y añadirlo como hijo.
- Borrar de `main.gd` todo lo movido, y donde `main.gd` llamaba a esas funciones, llamar a
  `input.…`.
- `main.gd` deja de tener `_input` y `_unhandled_input`: los tiene `PlayerInput`. **Ojo con el
  servidor**: hoy `_ready` hace `set_process_input(false)` sobre `main` cuando hay `--server`; ahora
  ese apagado no hace falta porque con `--server` no se crea `PlayerInput` (el `return` de `--server`
  está antes). Compruébalo y deja un comentario.

- [ ] **Step 3: `touch_ui.gd` y la prueba del reparto**

`touch_ui.gd` lee hoy de `main`: `AIM_DEAD`, `AIM_RADIUS`, `CROUCH_BTN`, `JOY_RADIUS`, `JOY_RUN`,
`KNOB_RADIUS`, `ORDERS_BTN`, `_aim_btn`, `_aim_drag`, `_joy_idx`, `_joy_vec`, `_touch_crouch`,
`button_rects`, `joy_center`. Todos pasan a `main.input.…`. Los que **no** se mueven (`_abil`,
`_chg`, `_ability_ready`, `can_revive_now`, `cooldown_fraction`, `cooldown_text`, `pf`, `swap_ready`)
siguen igual.

`tests/test_touch_layout.gd` usa `Main.CROUCH_RADIUS`, `Main.crouch_center`, `Main.JOY_RADIUS`,
`Main.JOY_GRAB`…: cámbialos a `PlayerInput.…`.

- [ ] **Step 4: Ver que compila y que la prueba pasa**

Run: `godot --headless --path . --import >/dev/null 2>&1 && tools/check.sh parse && godot --headless --path . -s tests/test_touch_layout.gd`
Expected: `RESULTADO: OK` y `test_touch_layout: OK (0 fallos)`.

- [ ] **Step 5: Las trazas tienen que ser IDÉNTICAS**

Run el bloque de después y el `diff` de las siete leyendas.
Expected: ningún "CAMBIÓ la leyenda N". Si alguna cambia, el refactor no es neutro: **no sigas**,
busca la diferencia (orden de llamadas, un `_auto_cast` que se llama antes o después) y arréglala.
Pega la salida del `diff` en el informe.

- [ ] **Step 6: Que el juego se sigue jugando con el dedo**

Run:
```bash
mkdir -p export/f0
for res in 1280x720 1600x720; do
  godot --path . --resolution $res -- --mode=2v2 --autoplay --touch --shot=export/f0/touch_$res.png --wait=260
done
```
Abre las dos capturas con Read: joystick, botón de agacharse, las tres habilidades con su aro y el
botón de órdenes si toca, todo en su sitio y sin solaparse. Descríbelas en el informe.

- [ ] **Step 7: Punto de control** — `wc -l main.gd` por debajo de 2.700 y `tools/check.sh` (entera)
en `RESULTADO: OK`. Sin commit.

---

### Task 2: `Vfx` sortea con su propio generador

**Files:**
- Modify: `fx/vfx.gd`, y los sitios que le pasan el `rng` del combate

**Interfaces:**
- Produces: `Vfx` deja de usar el `rng` del combate. Tiene `var _rng := RandomNumberGenerator.new()`,
  sembrado con la semilla de la partida (`Engine.get_meta("fl_seed", MAP_SEED)`) más un desplazamiento
  fijo, para que dos partidas con la misma semilla pinten igual pero **pintar no mueva el sorteo del
  combate**.

**Por qué:** hoy el zigzag de un rayo consume números del mismo generador que decide el combate, así
que un servidor que no pinta jugaría una partida distinta a la de un cliente que sí pinta. Es el
motivo por el que esta tarea existe.

- [ ] **Step 1: Encontrar todos los sorteos de Vfx**

Run: `grep -n "rng\." fx/vfx.gd` y `grep -rn "Vfx\." game/combat.gd | grep -c ""`
Anota en el informe cuántos sorteos hay y en qué efectos.

- [ ] **Step 2: Darle su generador**

En `fx/vfx.gd`, añadir el generador propio y sembrarlo donde se crea el `Vfx`:

```gdscript
## Generador propio (2026-09-20, fase 0 del juego en línea): antes compartía el `rng` del combate, así
## que pintar un rayo movía el sorteo de la partida y el servidor —que no pinta— habría jugado otra
## partida distinta a la del cliente. Se siembra con la semilla de la partida: dos partidas iguales
## siguen pintando igual.
var _rng := RandomNumberGenerator.new()
```

Sembrarlo al construirlo con `int(Engine.get_meta("fl_seed", 1234)) + 7919` (un primo cualquiera,
para no ir en fase con el del combate), y sustituir cada `rng.` por `_rng.` dentro de `fx/vfx.gd`.
Quitar el `rng` que le pasaban desde fuera si deja de usarse.

- [ ] **Step 3: Volver a grabar las referencias (las trazas CAMBIAN, a propósito)**

Run: las siete trazas de después y el `diff` contra las de antes.
Expected: cambian las leyendas que pintan efectos con sorteo (Tormentero y las que lanzan rayos) y
**no** cambian las demás. En el informe: qué leyendas cambiaron y en qué se nota (una línea de
ejemplo de cada lado). Si cambiara alguna que no pinta nada con sorteo, es un fallo de verdad.

- [ ] **Step 4: Las sondas siguen pasando**

Run: `tools/check.sh probes`
Expected: `RESULTADO: OK`. Las sondas no comparan trazas grabadas, así que tienen que seguir en verde
tal cual. Si alguna falla, dilo: significa que el cambio movió algo más que el dibujo.

- [ ] **Step 5: Punto de control** — `tools/check.sh` entera en verde. Sin commit.

---

### Task 3: Los efectos del combate salen por un único punto (`emit_fx`)

**Files:**
- Create: `game/fx_sink.gd`, `tests/test_fx_sink.gd`
- Modify: `game/combat.gd`

**Interfaces:**
- Produces:
  - `class_name FxSink extends RefCounted` con `func emit(kind: String, args: Dictionary) -> void`.
    Implementación por defecto, `LocalFx`, que pinta con `Vfx` lo mismo que hoy.
  - En `Combat`: `var fx_sink: FxSink` y `func emit_fx(kind: String, args: Dictionary) -> void`, que
    se lo pasa al sink. **Todas** las llamadas a `Vfx` que hoy hay en `combat.gd` pasan por aquí.
  - `FxSink.KINDS`: el catálogo de nombres de efecto con los argumentos que lleva cada uno
    (`{"bolt": ["from", "to", "color"], …}`), para que la prueba pura pueda comprobarlo y para que
    la fase 2 sepa qué mandar por la red.
- Consumes: `Vfx` (tarea 2).

- [ ] **Step 1: Inventario**

Run: `grep -n "Vfx\." game/combat.gd`
Anota **todas** las llamadas (el spec dice 57) con su efecto y sus argumentos. Ese inventario ES el
catálogo `KINDS`. Pégalo en el informe.

- [ ] **Step 2: Escribir la prueba primero**

`tests/test_fx_sink.gd` (pura, `extends SceneTree`): un sink de mentira que apunta lo que recibe, y
comprueba que:
- cada nombre de `FxSink.KINDS` tiene sus argumentos documentados y no hay dos iguales;
- `emit_fx` con un nombre que no está en el catálogo **falla** (`push_error` y no revienta);
- los argumentos que faltan se detectan (el sink de prueba compara contra `KINDS`).

- [ ] **Step 3: Ver que falla**

Run: `godot --headless --path . -s tests/test_fx_sink.gd`
Expected: `SCRIPT ERROR: ... Identifier "FxSink" not declared`.

- [ ] **Step 4: Implementar y sustituir las 57 llamadas**

Una por una, `Vfx.algo(...)` → `emit_fx("algo", {...})`, con `LocalFx` llamando exactamente a lo de
antes con los mismos argumentos y **en el mismo orden**. No aproveches para "mejorar" ningún efecto:
esta tarea no cambia ni un píxel.

- [ ] **Step 5: Ver que pasa**

Run: `godot --headless --path . -s tests/test_fx_sink.gd`
Expected: `test_fx_sink: OK (0 fallos)`.

- [ ] **Step 6: Las trazas tienen que ser IDÉNTICAS (otra vez)**

Run: las siete trazas y el `diff` contra las de la tarea 2 (las nuevas referencias).
Expected: ningún "CAMBIÓ la leyenda N". Pega la salida.

- [ ] **Step 7: Verlo con los ojos**

Run: `godot --path . --resolution 1280x720 -- --legend=0 --fxtest --shot=export/f0/fx_antes_despues.png --wait=260`
Abre la captura con Read: rayos, aros, trampas y esferas siguen ahí. Descríbela.

- [ ] **Step 8: Punto de control** — `tools/check.sh` entera en `RESULTADO: OK` y `wc -l main.gd`.
Sin commit. En el informe, la lista de efectos del catálogo: es lo que la fase 2 convertirá en avisos.
