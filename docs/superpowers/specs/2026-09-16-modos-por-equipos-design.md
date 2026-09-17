# Modos por equipos 1v1, 2v2, 3v3 y 4v4 — diseño

Fecha: 2026-09-16. Pedido por el usuario: "crea los modos de juego 4 vs 4, 1 vs 1, 2 vs 2 y 3 vs 3".
Sesión autónoma: las decisiones de abajo se tomaron sin poder consultar; cada una dice por qué.

## Qué se construye

- Cinco modos: **Horda** (el de siempre) y **1v1, 2v2, 3v3, 4v4** por equipos.
- Los modos por equipos son **sin red, contra bots**: tú más N−1 compañeros bot contra N rivales bot.
  El juego 3D no tiene red; montarla es una fase entera. El diseño separa "leyenda en juego"
  (`Fighter`) de quién la controla (teclado, táctil o `BotBrain`), así que el multijugador en línea
  podrá asignar un jugador remoto a un `Fighter` sin rehacer el combate.
- Menú de inicio (táctil y ratón) para elegir modo y leyenda. Con `--mode=` se salta el menú; en
  headless, `--shot` o `--probe` sin `--mode` se juega Horda, como hasta ahora.

## Reglas

Revisadas el mismo día con peticiones del usuario: **al mejor de 3 rondas por eliminación**,
**regeneración tras 10 s sin daño** y, tras medir peleas de ~7 s, **vida ×3, definitiva por carga,
básicas que pueden fallar y mapa más corto**. Lo demás sale del juego 2D.

Medido con 28 partidas de bots (7 leyendas × 4 modos): la pelea pasó de 6-8 s a 18-24 s y la
ronda de ~17 s a 23-28 s; las definitivas hacen ~14 % del daño; los bots aciertan el 83 % de los
teledirigidos (apenas esquivan). Siguen sin morir en el gas.

Después, **munición en la básica** (idea del usuario) y **bots que rodean lo que el rival dejó
puesto** (antes lo pisaban a ciegas). Medido otra vez con 28 partidas contra las 28 de referencia:

| | antes | con munición y bots que rodean zonas |
|---|---|---|
| Pelea 1v1 / 2v2 / 3v3 / 4v4 | 18 / 20 / 24 / 23 s | 22 / 27 / 32 / 46 s |
| Definitivas / su parte del daño | 201 / 15 % | 310 / 12 % |
| Parte del daño de Trampa eléctrica y Baliza Nox | 23 % y 10 % | 16 % y 0,2 % |
| Victorias: Tormentero, Químico, Clérigo, Ilusionista, Caballero | 68, 80, 9, 33, 50 % | 81, 40, 36, 50, 20 % |

Rebajar la carga de la definitiva al ritmo sostenido con munición se probó y se descartó: casi
duplicaba las definitivas (375, 20 % del daño). La Trampa eléctrica no funciona como trampa: 340 de
344 saltan al caer encima de alguien, porque su alcance (5 m) es igual a su radio.

Duelos de la Ilusionista (6 semillas contra cada rival, con la marca) según el daño de su pistola:

| Rival | ×1,0 | ×1,3 | ×1,6 | ×2,0 |
|---|---|---|---|---|
| Tormentero | 0 de 6 | 0 | 0 | 0 |
| Clérigo | 0 | 2 | 4 | 6 |
| Caballero esqueleto | 6 | 6 | 6 | 6 |
| Rompemareas | 0 | 0 | 0 | 1 |
| Rey liche | 0 | 0 | 0 | 0 |
| Químico | 2 | 5 | 6 | 6 |
| Total / victorias por equipos | 8 de 36 / 50 % | 13 / 56 % | **16 / 50 %** | 19 / 67 % |

Se elige ×1,6. El daño no arregla el Tormentero ni el Rey liche: la trampa la deja aturdida dentro
(en el 3D aturdir solo impide moverse) y los esqueletos paran las balas.

Activación de trampa y baliza (28 partidas y 36 duelos de la Ilusionista por valor):

| | al momento | 2 s | **3 s** |
|---|---|---|---|
| Pelea 1v1 / 2v2 / 3v3 / 4v4 | 22 / 27 / 30 / 34 s | 55 / 43 / 42 / 44 s | 57 / 35 / 43 / 43 s |
| Daño de la Trampa eléctrica | 15 % | 2 % | 2 % |
| Victorias Tormentero / Químico / Rompemareas / Clérigo | 81 / 40 / 28 / 36 % | 45 / 80 / 72 / 18 % | 52 / 50 / 56 / 45 % |
| Victorias Ilusionista / Rey liche / Caballero | 50 / 50 / 20 % | 39 / 52 / 40 % | 50 / 52 / 30 % |
| Duelos de la Ilusionista | 16 de 36 | 17 de 36 | — |

Se eligen 3 s: el reparto más igualado. Las peleas 1v1 entre bots pasan a durar casi un minuto.

| Regla | Valor | Origen |
|---|---|---|
| Partida | al mejor de 3: gana quien se lleva 2 rondas | usuario |
| Ronda | la gana el equipo que deja al rival sin nadie en pie; sin reaparecer dentro de la ronda; eliminación mutua = nadie suma | usuario |
| Descanso entre rondas | 4 s; se limpia el mundo, todos a su zona de salida con vida y recargas llenas, gas nuevo | diseño |
| Tope de ronda | 150 s; decide quien tenga más en pie y luego más vida | diseño |
| Gas por rondas | arranca al 65 % del mapa, espera 25 s, cierra ×1,5 y quema ×3 (en la Horda: todo el mapa, 120 s, ×1) | usuario: mapa más corto |
| Vida | ×3 en todas las leyendas; curación ×3 | usuario |
| Definitiva | por carga: vacía al empezar cada ronda; se llena con el daño de básica y táctica (6 s de la básica sin fallar × multiplicador de vida) y un goteo de 45 s; su propio daño no la recarga | usuario |
| Básicas teledirigidas | pueden fallar: vuelan recto, corrigen solo en los últimos 2 m a 40°/s, impactan por contacto y se apagan en su alcance | usuario |
| Munición de la básica | 3 disparos que vuelven de uno en uno (1,0 s; Rey liche 1,15; Rompemareas 1,4): −40 % de daño sostenido a distancia, −20 % cuerpo a cuerpo; la Ilusionista sin límite; barra bajo tu vida y arcos en el botón; la carga de la definitiva no cambia | usuario |
| Pistola de la Ilusionista | ×1,6 (9 → 14,4); solo por equipos | usuario |
| Trampa eléctrica y Baliza Nox | tardan 3 s en activarse (se ven, pero no saltan); al activarse, aro y chispazo | usuario (2026-09-17) |
| Marca del señuelo | quien rompe un señuelo queda marcado 5 s para el equipo de la Ilusionista: contorno rojo a través de todo, no puede esconderse, los bots van a por él | usuario |
| Bots | rodean trampas, balizas, nubes, tormentas y espinas rivales, y salen si les pillan dentro; con munición guardan el último disparo para cuando el rival está a menos del 70 % del alcance | diseño |
| Regeneración | tras 10 s sin daño, 8 % de la vida máxima por segundo, también en la Horda | usuario (espera) y `player.REGEN_RATE` del 2D (ritmo) |
| Leyendas | las 7 en rotación; únicas dentro de cada equipo; en el duelo, distinta de la tuya | lobby del 2D |
| Mapa | el de la Horda (42×42, semilla 1234) sin criaturas | el 3D solo dibuja ese |
| Pruebas | `--rounds=N`, `--roundtime=S`, `--autoplay` | — |

Bajas: cuenta la del equipo contrario, con crédito al dueño (el esbirro del Liche, la trampa del
Tormentero o la plaga del Clérigo acreditan a quien la lanzó). Caer en el gas no suma a nadie.
Las bajas y caídas por leyenda se muestran al final; las insignias de racha funcionan para tu leyenda.

Si caes, la cámara sigue a un compañero en pie hasta el final de la ronda.

Zonas de salida: dos grupos de celdas despejadas de campo, opuestos respecto al centro, dentro del
círculo inicial del gas. Se elige la dirección (de 8) que da más celdas libres a los dos lados.

## Arquitectura

`main.gd` supera su tope (4.600 líneas): primero se extrae, sin cambiar el comportamiento, y
luego se añaden los modos en scripts propios.

| Script | Clase | Qué hace |
|---|---|---|
| `data/legend_data.gd` | `LegendData` | `ABILITIES`, `LEGENDS`, `PLAYABLE`, `SPECIES`, rutas y animaciones (movido tal cual) |
| `fx/vfx.gd` | `Vfx` | partículas, destellos, rayos, aros, discos, nubes, polvo, burbuja; vida de los efectos |
| `game/fighter.gd` | `Fighter` | una leyenda en juego: cuerpo, modelo, equipo, vida, recargas, preaviso, mejora, carga, guardia, ocultación, marcador |
| `game/combat.gd` | `Combat` | las 13 mecánicas generalizadas a cualquier `Fighter`, objetivos por equipo, daño, empujón, tirón, esbirros, señuelos, esporas, movimiento de leyendas |
| `game/team_match.gd` | `TeamMatch` | rondas, marcador, bajas y caídas, tiempo de ronda, final (lógica pura) |
| `game/game_modes.gd` | `GameModes` | tabla de modos, zonas de salida, reparto de leyendas, celda de reaparición (lógica pura) |
| `game/team_mode.gd` | `TeamMode` | monta la partida, bots, eventos de ronda, limpieza entre rondas y final |
| `game/nav_grid.gd` | `NavGrid` | `AStarGrid2D` sobre la rejilla, sin cortar esquinas |
| `game/bot_brain.gd` | `BotBrain` | objetivo, distancia por leyenda, huida, gas, uso de habilidades por tipo |
| `ui/mode_menu.gd` | `ModeMenu` | menú de inicio |
| `ui/match_hud.gd` | `MatchHud` | rondas, leyendas en pie, reloj, bajas recientes, carteles de ronda, pantalla final |
| `ui/pause_menu.gd` | `PauseMenu` | pausa (☰ o P) con Seguir, Reiniciar y Menú, también en la Horda |

### Protocolo de objetivo

Todo lo que recibe daño es un `Dictionary` con `node`, `team`, `kind` (`zombie`, `fighter`,
`minion`, `decoy`), `hp`, `hpmax`, `dead_t`, `stun_t`, `knock`, `knock_t`, `slow_t`, `blind_t`,
`spore_t` y barra. Las criaturas ya lo eran; las leyendas y los aliados se suman.
`Combat.foes_in(team, punto, radio, n, solo_visibles)` sustituye a `_nearest_in` y
`Combat.hurt(objetivo, daño, aturdimiento, autor)` a `_damage_zombie`/`_damage_player`.
Equipos: 0 = horda, 1 = el tuyo, 2 = el rival.

### Qué no cambia

Horda: mismas oleadas, jefe, especies, esporas, balizas, gas, día/noche y controles. Se verifica
con trazas deterministas (`--fixed-fps 60 --autocast --log`) de las 10 leyendas, jefe, táctil y
recargas cortas, grabadas antes de extraer: deben salir idénticas.

## Pruebas

- `tests/test_team_match.gd`: bajas y crédito, ronda por eliminación, eliminación mutua, ronda por
  tiempo, descanso, tope de rondas y final al mejor de 3.
- `tests/test_game_modes.gd`: zonas de salida opuestas, dentro del gas inicial y con sitio para 4;
  leyendas únicas por equipo; celda de reaparición dentro del área limpia y lejos de rivales.
- `tests/test_game_modes.gd` también prueba `NavGrid`: camino entre las zonas de salida, sin celdas
  bloqueadas ni esquinas cortadas.
- `tests/test_fighter.gd`: munición (gastar, volver de uno en uno, sin munición no está lista, se
  rellena por ronda, la Ilusionista sin límite); `tests/test_bot_brain.gd`: cuándo dispara con
  munición y cómo rodea o abandona una zona; `tests/test_ammo_bar.gd`: relleno de cada segmento.
- `tests/match_probe.gd` comprueba también la munición (máximo por leyenda, nunca fuera de rango,
  alguien la gasta) e imprime trampas puestas, las que saltan al caer y las pisadas después.
- `tests/match_probe.gd` (`--probe`): partida entera de bots en headless para cada modo, con
  `--autoplay`; debe acabar en 2 o 3 rondas, sin errores de script, con daño en los dos equipos y
  sin leyendas clavadas.
- `tools/check.sh` corre todo; las trazas de Horda se comparan a mano tras la extracción.

## Fuera de alcance (anotado como siguiente paso)

Multijugador en línea; mapa arena propio con río (el 2D lo tiene, el 3D no dibuja agua); que los
bots se agachen en la hierba; botón táctil de agacharse; elegir la victoria desde el menú.
