# Registro de bajas, equipo a la vista y ajustes (controles y audio) — diseño

Fecha: 2026-09-20. Pedido por el usuario: "cuando un enemigo muera debemos mostrar quién mató a
quién y también sería bueno poder ver mis compañeros y la vida que tienen ellos"; "poder modificar
los controles en dirección y tamaño como normalmente se puede hacer en otros juegos, poder quitar la
música o cambiar el audio entre los que tenemos".

## Qué hay hoy (medido, no supuesto)

| Cosa | PvP (1VS1-4VS4) | Horda |
|---|---|---|
| Quién mató a quién | **Sí**: `MatchHud._feed`, arriba a la derecha bajo el minimapa, `Matador ✕ Víctima` con el color del equipo, las 4 últimas, 6 s | **No**: las bajas se cuentan (`main._kills`) pero no se anuncian |
| Compañeros y su vida | **No**: solo "leyendas en pie" en el marcador | **Sí**: `HordeHud`, una fila por compañero con barra de vida y cuenta atrás si cae |
| Controles ajustables | **No**: constantes fijas (`JOY_RADIUS`, `CROUCH_OFFSET`, `ABILITY_SIDE`…), hoy pasando a `game/player_input.gd` | igual |
| Audio | Dos pistas (`battleThemeA.mp3`, `bossbattle_22k.wav` para el jefe), volumen fijo −9 dB, sin ajustes | igual |

O sea: **cada modo tiene la mitad de lo que el usuario pide**. El trabajo no es inventar dos cosas
nuevas, sino sacar las dos que ya existen a piezas compartidas y ponerlas en los dos modos.

## Decisiones

1. **Una pieza por cosa, compartida por los dos modos.**
   - `ui/kill_feed.gd` (`KillFeed`): sale de `MatchHud`, lo usan `MatchHud` y `HordeHud`.
   - `ui/team_panel.gd` (`TeamPanel`): sale de `HordeHud`, lo usan `HordeHud` y `MatchHud`.
   Se sacan **sin cambiar comportamiento** (el PvP tiene que seguir viéndose igual antes y después),
   y solo entonces se enchufan en el otro modo.
2. **El registro dice de qué murió cada uno**, no solo quién. La ficha de baja ya lleva autor; se le
   añade la ranura (`slot`) que ya viaja en `hurt(..., by, slot)`: básica, táctica, definitiva,
   cuerpo a cuerpo o gas. Primero en texto (`Tormentero ✕ Zombi bruto · definitiva`); cuando el
   usuario traiga los iconos, el texto se sustituye por el icono correspondiente. **El diseño no
   depende de los iconos**: si no están, se ve el texto y no falla nada.
3. **En la Horda el registro solo enseña lo que te importa**: tus bajas y las de tus compañeros
   humanos o bots, no las 40 criaturas del enjambre; si no, tapa la pantalla. Tope de 4 líneas y
   6 s, como en PvP, y se agrupan las seguidas del mismo autor ("×3").
4. **Ajustes en un sitio solo**: pantalla nueva `ui/settings_menu.gd`, a la que se llega desde la
   **pausa** (botón "Ajustes") y desde el **menú de inicio**. No se duplica nada en los dos sitios.
5. **Los ajustes se guardan en disco** (`user://ajustes.json`) con una clase pura `Settings`
   (`net/`-style: lógica sin nodos, probada aparte). Hoy solo se guarda el nombre del jugador
   (`user://identity.json`); el contador de FPS de la pausa se pierde al cerrar, y pasa a guardarse
   aquí también.
6. **Controles: mover y redimensionar por grupos, no botón a botón.** Tres grupos —joystick,
   habilidades (las tres más la básica) y auxiliares (agacharse y órdenes)—, cada uno con su
   posición y su escala. Botón a botón sería más flexible pero se rompe más fácil y cuesta el doble
   de UI; si luego hace falta, se parte un grupo.
   - **Modo edición**: en Ajustes, "Colocar controles" enseña el HUD táctil de verdad sobre un fondo
     oscuro; arrastras cada grupo a donde quieras y un deslizador cambia su tamaño (×0,7 a ×1,5).
     Botón "Restaurar" vuelve a lo de fábrica.
   - **Límites**: nada puede salirse de la pantalla ni solaparse con el botón de pausa; la
     comprobación es pura (`Settings.clamp_layout`) y tiene prueba, como `test_touch_layout.gd`.
   - Se guarda en **fracciones de la pantalla**, no en píxeles: así vale igual en el S24 Ultra que
     en una tablet o en el navegador.
7. **Audio: cuatro perillas** — música sí/no, volumen de música, volumen de efectos y qué pista
   suena. Las pistas se listan **leyendo la carpeta** `assets/audio/music/`, no una lista escrita a
   mano: si el usuario mete otro mp3, aparece solo. La pista del jefe sigue teniendo prioridad
   mientras hay jefe (es información de juego, no gusto musical), y al acabar vuelve a la elegida.
8. **Nada de esto cambia el balance ni el determinismo**: son HUD y ajustes. Las trazas
   deterministas tienen que seguir idénticas, y eso se comprueba.

## Cómo se sabe que está

- **Puras**: `Settings` (valores por defecto, guardar y leer, límites de la colocación, elección de
  pista inexistente → la de por defecto), y el agrupado del registro de bajas.
- **Sondas**: una sonda de Horda comprueba que al morir una criatura aparece la línea con su autor;
  una de PvP, que el panel de compañeros enseña a los vivos con su vida y marca a los caídos.
- **Capturas miradas** a 1280×720 y 1600×720 con `--touch`: registro de bajas en Horda, panel de
  compañeros en PvP, pantalla de ajustes y modo de colocar controles.
- **Puerta completa en verde** y `main.gd` sin crecer.

## Fuera de alcance

Iconos (los trae el usuario; el diseño funciona sin ellos), voces, ecualizador, música propia del
menú, remapear teclas de PC (el teclado no se toca), y guardar ajustes en el servidor (son del
aparato).

## Orden de trabajo

1. `KillFeed` y `TeamPanel` extraídos, PvP idéntico. 2. Registro en Horda. 3. Panel en PvP.
4. `Settings` + pantalla de ajustes con audio. 5. Colocación de controles. 6. Iconos, cuando lleguen.

Va **después de las fases 0 y 2 del juego en línea** (decisión del usuario, 2026-09-20: "me gusta,
aprobado, pero primero termina la fase 2 del en línea para probarlo"). Dos razones y las dos son
buenas: la colocación de controles se apoya en `game/player_input.gd`, que sale de `main.gd` en la
fase 0, y el registro de bajas y el panel de compañeros tendrán que funcionar **también en línea**,
donde los datos llegan del servidor y no de la partida local: hacerlos antes obligaría a rehacerlos.
