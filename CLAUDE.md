# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

# Fallen Legends 3D — guía para Claude Code

## Qué es
ARPG de **tercera persona 3D** en **Godot 4.7.2 / GDScript**, hermano de *Fallen Legends* (el 2D
isométrico, repo `arena-arpg`, en `~/Downloads/arena-arpg` o `$ARENA2D`). **Son dos juegos
independientes**: comparten mundo, leyendas y balance, pero ninguno depende del otro para compilar.
El 2D **no se publicará en Android**; el 3D sí, con `com.fallenlegends.proto3d` (decidido, no se
cambia). Sin red por ahora.

Modos (menú de inicio o `--mode=`): **Horda** (oleadas de cinco especies) y **1v1, 2v2, 3v3, 4v4**
contra bots **al mejor de 3 rondas por eliminación**, sin reaparecer dentro de la ronda, con vida
×3, definitiva por carga, básicas que pueden fallar, munición en la básica (menos la Ilusionista) y
área limpia al 65 % (reglas en el README). 7 leyendas
en rotación con 21 habilidades (más 3 retiradas), ciclo día/noche, gas que cierra el mapa,
regeneración tras 10 s sin daño, controles táctiles y pausa.

El README es la documentación del usuario y de las pruebas: reglas de los modos, mecánicas, flags,
cifras y las "Cosas que se aprendieron montándolo" (glTF, materiales, animaciones renombradas,
billboard, `--shot` en headless, anclas de UI, `--check-only`). **Léelo antes de tocar modelos,
materiales, animaciones o UI**, y actualízalo cuando cambien flags, cifras, reglas o controles.
Diseño y decisiones de los modos: `docs/superpowers/specs/2026-09-16-modos-por-equipos-design.md`.

## Comandos
```
godot --path .                                   # jugar: sale el menú (Esc suelta el ratón, P pausa, F10 sale)
godot --headless --path . --import               # primera vez, y tras crear una class_name nueva (refresca la caché de clases)
tools/check.sh                                   # PUERTA DE CALIDAD (~1 min): parseo + pruebas puras + humo + sondas
tools/check.sh parse main.gd                     # solo parseo de un script
tools/check.sh tests | smoke | probes            # solo pruebas puras | humo headless | sondas de partida
godot --headless --path . -s tests/test_team_match.gd                        # una prueba pura suelta (salida 1 si falla)
godot --headless --fixed-fps 60 --path . -- --probe=rocks_probe --secs=60     # ¿alguien se mete en las piedras?
godot --headless --fixed-fps 60 --path . -- --mode=4v4 --autoplay --log --probe=match_probe   # partida de bots entera
godot --headless --fixed-fps 60 --path . -- --mode=2v2 --legend=2 --autoplay --probe=decoy_probe  # marca al romper un señuelo
tools/sync_2d.sh [--copy]                        # deriva frente al 2D (copias literales y balance)
tools/build.sh android | android-release | web   # exportar (docs/DESPLIEGUE.md); nunca sin tools/check.sh antes
```
Capturas (todo lo que va tras `--` llega a `_args` como `--clave=valor`):
```
godot --path . --resolution 1280x720 -- --shot=/tmp/a.png --cam=1 --yaw=35 --pitch=-48 --dist=17   # Horda
godot --path . --resolution 1280x720 -- --mode=menu --shot=/tmp/menu.png --wait=90                  # menú
godot --path . --resolution 1600x720 -- --mode=2v2 --autoplay --touch --shot=/tmp/m.png --wait=600  # equipos en móvil
```
Flags de prueba (todos en README § "Opciones útiles para probar"): `--mode`, `--legend`,
`--autoplay`, `--rounds`, `--roundtime`, `--autocast`, `--probe`, `--near`, `--zombies`, `--wave`,
`--boss`, `--dianas`, `--cd`, `--nozone`, `--zonewait`, `--zonefast`, `--cycle`, `--night`,
`--nodecor`, `--noshadow`, `--touch`, `--roster`, `--fxtest`, `--bench`, `--log`, `--animlog`,
`--sporelog`, `--dashlog`, `--meleelog`, `--rocklog`, `--dbg`.

**Determinismo**: `rng` con semilla fija (`MAP_SEED` 1234) y `--fixed-fps 60` hacen que dos
ejecuciones iguales den la MISMA traza. Así se comprobó que partir `main.gd` no cambió la Horda:
se graba `--fixed-fps 60 --legend=N --autocast --near=4 --zombies=14 --log --meleelog --dashlog
--sporelog --shot=/tmp/x.png --wait=1200` antes y después y se compara con `diff` (quitando `fps=`).
Usa ese método en cualquier refactor. Un sorteo por pesos se comprueba aparte, con `randomize()`.

**Rendimiento** solo con la ventana en primer plano (macOS estrangula la de fondo a 3-4 FPS, y las
ventanas que abre una sesión de Claude Code están de fondo): referencia 40 esqueletos a 144 FPS.

## Arquitectura

| Fichero | Clase | Qué es |
|---|---|---|
| `main.gd` | `Main` | Escena raíz (`main.tscn`): elige modo, construye el mapa 3D, cámara, control del jugador (teclado/ratón/táctil), la Horda (oleadas, especies, jefe, campo de flujo, IA de criaturas), gas, día/noche, barras, insignias y HUD de depuración. ~2.900 líneas |
| `data/legend_data.gd` | `LegendData` | `ABILITIES`, `LEGENDS`, `PLAYABLE`, `SPECIES`, `PX`, `PVP_AMMO` y `PVP_BASIC_DMG` (munición y daño de la básica por equipos), rutas de modelos y listas de animaciones. `main.gd` tiene alias con los mismos nombres |
| `game/fighter.gd` | `Fighter` | Una leyenda en juego (tuya o de bot): cuerpo, modelo, equipo, `rec` (ficha de objetivo), estado de lanzador, `hp_mult`, definitiva por carga (`ult_*`), munición de la básica (`ammo_*`, 0 = sin límite), daño de la básica por equipos (`basic_dmg_mult`) y marca por romper un señuelo (`marked_t`, `mark_team`). Quien la maneja solo escribe `wish`, `run`, `crouch`, `holding_basic` |
| `game/combat.gd` | `Combat` | Las 13 mecánicas para cualquier Fighter, objetivos por equipo, daño con autor, empujón y tirón, esbirros, señuelos, esporas, regeneración, movimiento de leyendas, limpieza entre rondas |
| `fx/vfx.gd` | `Vfx` | Partículas, destellos, rayos, aros, discos, nubes, polvo, espinas, burbuja, cadena; vida de lo temporal |
| `fx/mark_fx.gd` | `MarkFx` | Contorno rojo a través de muros (stencil, `material_overlay`) de quien rompe un señuelo |
| `world/map_layout.gd` | `MapLayout` | Pura: transponer la rejilla, huella de una malla, encajar rocas en su celda, elegir celdas de peñascos |
| `game/game_modes.gd` | `GameModes` | Pura: tabla de modos, zonas de salida opuestas, reparto de leyendas, celda de reaparición |
| `game/team_match.gd` | `TeamMatch` | Pura: rondas al mejor de 3, eliminación, tiempo de ronda, bajas y caídas, eventos, final |
| `game/team_mode.gd` | `TeamMode` | Monta una partida por equipos, bots, eventos de ronda (limpiar, gas nuevo, todos a su sitio) y final |
| `game/bot_brain.gd` | `BotBrain` | Cerebro de bot (del 2D): objetivo visible, distancia por leyenda, huida, gas, habilidades por tipo, rutas; rodea las zonas rivales (`steer_around`) y administra la munición (`should_shoot`) |
| `game/nav_grid.gd` | `NavGrid` | `AStarGrid2D` de 8 direcciones sin cortar esquinas, para los bots |
| `ui/mode_menu.gd` | `ModeMenu` | Menú de inicio (modo y leyenda); guarda la elección en `Engine` meta y recarga la escena |
| `ui/match_hud.gd` | `MatchHud` | Rondas, leyendas en pie, reloj, bajas recientes, carteles de ronda, pantalla final |
| `ui/ammo_bar.gd` | `AmmoBar` | Tu munición: segmentos bajo tu vida que miran a la cámara, parpadeo y sonido al disparar sin munición |
| `ui/pause_menu.gd` | `PauseMenu` | ☰ / P: Seguir, Reiniciar, Menú (árbol en pausa, `PROCESS_MODE_ALWAYS`) |
| `touch_ui.gd` | — | Solo dibuja joystick y botones; lee de `main` (`_abil`, `_chg`, `cooldown_*`, `swap_ready`…) |
| `map_builder.gd`, `dungeon_gen.gd` | `MapBuilder`, `DungeonGen` | **Copias literales del 2D** (no se editan aquí: hook) |

### Flujo de una partida
- `_ready` → `_pick_mode()`: `--mode` manda; si no, `Engine.get_meta("fl_mode")` (lo pone el menú,
  la pausa o la revancha y sobrevive a `reload_current_scene`); si no, headless o cualquier flag →
  Horda; si no, **menú**. Después: mapa (transpuesto, ver abajo), tu leyenda (`combat.spawn_fighter`,
  siempre `combat.fighters[0]` = `pf`), gas, y `_setup_menu` / `TeamMode.setup` / `_setup_horde`.
- `_physics_process`: (Horda) tu muerte → `_tick_powers` [cada Fighter: `combat.tick_fighter`; luz;
  barras; mira; `--autocast`; cerebros de bots; `combat.tick_world`] → Horda o `team_mode.tick` →
  gas → tu movimiento (`combat.move_fighter`) → bots → cámara (si caíste por equipos, sigue a un
  compañero). **El orden importa** para las trazas deterministas.
- Por equipos, `TeamMatch` emite `round_end` / `round_start` / `over` y `TeamMode` los atiende; en
  `break` y `over` nadie recibe daño ni se mueve.

### Cómo están modeladas las cosas
- **Ficha de objetivo** (Dictionary) común a criaturas, leyendas, esbirros y señuelos: `node`, `kind`
  (`zombie`/`fighter`/`minion`/`decoy`), `team` (0 horda, 1 tuyo, 2 rival), `hp`, `hpmax`, `dead_t`,
  `stun_t`, `knock`, `knock_t`, `slow_t`, `blind_t`, `spore_t`, `spore_by`, `bar`, `bar_t`,
  `bscale`, `cap`. Todo lo que busca víctimas usa `combat.foes_in(team, punto, radio, n,
  solo_visibles)` y todo daño pasa por `combat.hurt(ficha, daño, aturdimiento, autor)`. Un campo
  nuevo se escribe en el `spawn`/`cast` y se lee en su `tick`: si nadie lo lee no hace nada (pasó
  con `knock`).
- **Todo lo que queda en el mundo** (`bolts`, `traps`, `storms`, `spikes`, `beacons`, `allies`)
  lleva `team`, `owner` (id de Fighter) y `slot` (ranura que lo lanzó): los topes son por dueño, las
  bajas se acreditan al dueño y el daño de la ranura 2 no carga la definitiva. `hurt(…, by, slot)`:
  pasa siempre la ranura. `combat.damage_by`, `soft_hits`/`soft_misses` y `ult_casts` son para medir.
- **Habilidades por datos** (`LegendData.ABILITIES`, cifras del 2D en píxeles, pasadas a metros con
  `PX` al usarlas): `k` = `proj`, `melee`, `dash`, `heal`, `buff`, `zone`, `gas`, `spores`, `trap`,
  `beacon`, `spikes`, `summon`, `decoy`, más modificadores (`homing`, `pull`, `catch`, `solid`,
  `stun`, `knock`, `shove`, `charge`, `dust`, `arc`, `back`, `sync`, `anim`, `adur`, `field`, `chg`,
  `swap`, `invis`). Mecánica nueva = `k` nuevo con su `cast_*` y su `tick_*` en Combat, y su caso en
  `BotBrain._use_abilities`.
- **Criaturas**: `SPECIES`; se mueven con un campo de flujo BFS compartido cada 0,4 s. **Bots**:
  cada uno su camino con `NavGrid`.
- **Mapa**: `MapBuilder` guarda `grid[y][x]`; `main.gd` lo **transpone una vez** (`MapLayout.transpose`)
  y lee `grid[x][y]`; las llamadas a MapBuilder usan `_mb_grid`/`_mb_zones`. Colisión de rejilla (caja
  de 3 m por celda bloqueada); los **peñascos** ocupan una celda (pasa a `MOUNTAIN`) y chocan con su
  envolvente convexa; las rocas de muro se encajan en su celda. `tests/rocks_probe.gd` vigila que
  nadie se meta en la piedra.
- **Modelos**: glTF **importados** (el importador quita `_Loop` de los nombres de animación). Cuerpo
  base cortado por el cuello + piezas de atuendo que se **sustituyen**, no se apilan. Solo se
  injertan las animaciones de `HERO_ANIMS*`/`ZOMBIE_ANIMS_*`. Armas construidas en código.

## Reglas (no negociables)
1. **Rendimiento con presupuesto móvil** (`gl_compatibility`, 40 criaturas u 8 leyendas con efectos
   a 60 FPS): nada nuevo por fotograma × N sin justificarlo; sin asignaciones en los `tick_*` de
   bucles grandes; geometría repetida por `MultiMesh`; shaders y materiales **compartidos**; medir en
   primer plano con `--bench`.
2. **`main.gd` no crece** (el hook avisa a partir de 3.000 líneas): un sistema nuevo va en su propio
   script con `class_name` y `main.gd` lo llama. Al cambiar algo grande de `main.gd`, extráelo
   primero sin cambiar comportamiento (trazas idénticas) y modifícalo después.
3. **Seguridad y licencias**: repo **privado** (Bestiary de Quaternius va con la QAL); sonidos de
   p0ss **CC-BY-SA 3.0** (atribución visible); ningún secreto en el repo (keystore de release fuera,
   variables `GODOT_ANDROID_KEYSTORE_RELEASE_*`); Android sin permisos de red; recursos con `load()`,
   nunca `Image.load_from_file`; `git push --force` denegado. Detalle: `docs/DESPLIEGUE.md`.
4. **Sincronía con el 2D**: `map_builder.gd` y `dungeon_gen.gd` no se editan aquí; se traen con
   `tools/sync_2d.sh --copy`. Toda cifra de balance sale de `data/*.tres` del 2D; una desviación
   lleva comentario junto al número y fila en el README. Desviaciones vivas: Enganche (recarga 20 s,
   alcance 1200 px), Sanación ×3, Muro de espinas ×3, regeneración a los 10 s (el 2D, 4 s).
5. **Determinismo**: nada de `randomize()` en el juego. Lógica pura nueva → prueba en
   `tests/test_*.gd` (`extends SceneTree`, `print("FALLO: …")`, `quit(1)`); comportamiento en partida
   → sonda en `tests/*_probe.gd` enganchada con `--probe` y añadida a `PROBES` de `tools/check.sh`.
6. **Nada está terminado sin evidencia**: `tools/check.sh` con su salida y, si es visual, una
   captura mirada de verdad. **`--check-only` no detecta llamadas a métodos inexistentes** sobre
   variables tipadas (`main.no_existe()` parsea): un script nuevo no está probado hasta que corre.

## Convenciones
- Comentarios y textos de UI en **español con tildes**; identificadores en **inglés**; tipado
  estático (`:=` solo cuando se infiere sin ambigüedad: Godot no infiere de un `Variant`).
- Los comentarios explican el **porqué** y la historia ("a petición del usuario", "antes…").
- UI en código: raíz con `set_anchors_and_offsets_preset(PRESET_FULL_RECT)` (con el nodo ya en el
  árbol, `set_anchors_preset` conserva su tamaño 0×0 y todo acaba arriba a la izquierda); botones de
  64 px o más para el dedo; probar a 1280×720 y 1600×720 con `--touch`.
- `match` es palabra reservada en GDScript. Clase nueva (`class_name`) → `godot --import` antes de
  usarla desde otro script (el hook y `tools/check.sh` ya lo hacen).
- Flags de prueba: `--clave=valor` tras `--`, documentadas en el README. Trazas de consola con
  prefijo entre corchetes (`[HORDA]`, `[PARTIDA]`, `[RONDA]`, `[BAJA]`, `[FIN]`, `[SONDA]`, `[ROCAS]`).
- `.uid` junto a cada script **se versiona**; `.import` no.
- Specs y planes en `docs/superpowers/specs/` y `docs/superpowers/plans/` (`AAAA-MM-DD-<tema>-design.md`).

## Git
- Identidad de commits **`JohanHdez <37870481+JohanHdez@users.noreply.github.com>`** (fijada en
  `.git/config`; el hook de sesión lo comprueba). Nunca la identidad global de este Mac (otro nombre
  y correo personal).
- Remoto `origin` = https://github.com/JohanHdez/fallen-legends-3d.git (privado, HTTPS). Rama `main`.
- Commit y push **solo cuando el usuario lo pida**. Sin `--force`.

## Trabajar con Claude Code en este repo
- **`/director <tarea>`** coordina (feature, bug, refactor, rendimiento, release, sincronía,
  auditoría) y **`/auditoria [alcance]`** lanza los cinco auditores de solo lectura de
  `.claude/agents/`. **`/verificar`**, **`/exportar`** (solo el usuario) y **`/sincronizar-2d`**.
  Las skills y agentes del repo se cargan al abrir la sesión: si se acaban de crear, hay que abrir
  una sesión nueva.
- Hooks (`.claude/hooks/`): estado del repo al abrir; bloqueo de las copias del 2D, `.godot/`,
  `export/` y `*.import`; parseo de cada `.gd` editado (refrescando la caché de clases si hace
  falta) y tope de líneas de `main.gd`. Ojo: ediciones hechas por Bash (sed, python) **no** pasan
  por los hooks; corre `tools/check.sh parse` a mano.
- Plugins, conectores, cadena de herramientas y licencias: `docs/DESPLIEGUE.md`.

## Deuda y trampas conocidas
- **`main.gd` sigue grande** (~2.900). Siguientes extracciones, una por vez con trazas idénticas:
  `game/horde.gd` (oleadas, especies, jefe, campo de flujo, IA de criaturas, `_kill_zombie`),
  `world/map3d.gd` (suelo, bloqueadores, peñascos, decoración, tumbas, colisión, gas),
  `chars/character_factory.gd` (glTF, injerto de animaciones, corte de cabeza, armas, ojos, tinte,
  barras), `ui/debug_hud.gd` e insignias.
- **Balance por equipos sin afinar** (28 partidas de bots con vida ×3, definitiva por carga,
  munición, bots que rodean zonas, marca del señuelo y pistola ×1,6): peleas de 22-34 s. Tormentero
  gana el 81 % y Caballero el 20 %; Rompemareas 28 %, Clérigo 36 %, Químico 40 %, Ilusionista y Rey
  liche 50 %. La
  **Trampa eléctrica no es una trampa**: su alcance (5 m) es su radio, así que salta al caer encima
  de alguien (340 de 344). La Ilusionista gana 16 de 36 duelos 1v1 (8 antes de la pistola ×1,6)
  pero ninguno contra Tormentero, Rey liche ni Rompemareas, dé lo que dé su pistola: falla la mitad,
  los esqueletos paran sus balas y su bot pelea a 5,6 m pudiendo disparar a 12,8. **Aturdir en el 3D solo impide moverse**; en el 2D tampoco deja atacar
  (`player.gd`: "no se mueve ni ataca"). Nadie muere en el gas. Los bots apenas esquivan.
- **Horda**: al reaparecer vuelves con `PLAYER_HP` (210) sea cual sea tu leyenda (se conserva para
  no descuadrar las trazas; arreglarlo es cambiar una línea en `_tick_player_death`). No hay forma
  de perder: las oleadas no acaban.
- **Solo hay 2 equipos por partida**: el combate ya admite cualquier número (`team` entero,
  `foes_in` = otro equipo), pero `TeamMatch`, `GameModes.spawn_areas`/`pick_legends`, `TeamMode`
  y `MatchHud` están escritos para Azul contra Rojo.
- **`project.godot` dice `config/features=("4.3", …)`** con motor 4.7.2 (el editor lo actualiza).
- **`--shot` en headless** imprime `ERROR: Parameter "t" is null`; `tools/check.sh` lo filtra.
- **Sin botón táctil para agacharse**; **sin icono de lanzador**; **sin keystore de release**;
  **sin atribución CC-BY-SA visible en el juego**; las insignias de 64 px pesan 19 MB.
