# Pantalla de inicio estilo 2D — diseño

**Fecha:** 2026-11-09 · **Pedido:** "¿hay forma de que la pantalla de inicio también la hagamos en el
juego 3D?" (la del 2D: leyenda grande en el centro, botones a los lados, modo y JUGAR abajo).

## Alcance acordado con el usuario
- **Solo la pantalla.** Nada de tienda, oro, nivel ni progreso: el 3D no tiene esos sistemas y
  quedan fuera (serían una feature aparte con servidor de perfiles).
- **En el centro, la leyenda en 3D**: tu leyenda de verdad, animada en reposo, en el mapa, con la
  cámara cerca dando una vuelta lenta a su alrededor. ◀ ▶ la cambian en caliente
  (`Main.set_legend`, el mismo cambio de las teclas 1-7).

## Distribución (1280×720 de referencia, `canvas_items` + `expand`)
- Arriba: tu nombre (campo, izquierda) y el título "FALLEN LEGENDS 3D" (centro).
- Centro: la leyenda (el mundo, sin velo encima); ◀ y ▶ a sus lados; debajo su nombre, vida,
  velocidad y habilidades.
- Derecha: EN LÍNEA y, debajo, el estado de la conexión.
- Abajo: en el centro el selector de modo (‹ nombre + descripción ›) y, con la Horda, el equipo
  (Solo 2 3 4); a la derecha JUGAR, grande y dorado. Abajo a la izquierda, las teclas (solo sin
  pantalla táctil).
- Franjas oscuras arriba y abajo para que se lea el texto; el centro queda limpio.

## Arquitectura
- `ui/mode_menu.gd` (ModeMenu): mismas variables y API que antes (`mode`, `legend`, `team`,
  `touch`, `play_online()`, `_play()`): las sondas de red (`lobby_probe`, `match_net_probe`) lo
  siguen encontrando y pulsando "EN LÍNEA" igual. El modo pasa de una fila de botones a un
  carrusel ‹ ›; la leyenda la aplica a la escena (`Main.set_legend`) si la escena es el menú.
- `ui/menu_stage.gd` (MenuStage, nuevo): la cámara del menú (encuadre de retrato y vuelta lenta).
  `main.gd` no crece: `_setup_menu` y la rama de menú de `_physics_process` llaman a MenuStage en
  vez de llevar la cámara ellos.
- El Lobby, al salir, crea un `ModeMenu.new()` por su cuenta: por eso la conexión con la leyenda
  vive en ModeMenu (busca la escena actual), no en `main.gd`.

## Cómo se comprueba
- `tools/check.sh` (puerta de calidad completa).
- Capturas `--mode=menu --shot=… --wait=90` en 1280×720 y en formato de celular.
