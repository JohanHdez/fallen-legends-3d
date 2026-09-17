# Horda en equipo, sigilo, reanimaciones y órdenes del Rey liche — diseño

Fecha: 2026-09-17. Pedido por el usuario tras jugar la Horda ("fue muy fácil", "los zombis están
quietos", "no vi la opción de agacharme"…) y cerrado con él en cuatro preguntas: selector de equipo
1 a 4, reanimaciones también en PvP, derrota si cae todo el equipo y un solo botón de órdenes.

## Qué se construye

1. **Rayos con sonido.** Cada rayo de la Trampa eléctrica suena. La Tormenta eléctrica tira un rayo
   del cielo, con trueno, sobre cada enemigo que siga dentro en cada descarga.
2. **Jefe Rompemareas con sus poderes.** Deja de ser un zombi grande: es una leyenda Rompemareas
   manejada por un bot, del lado de la horda, como el jefe-leyenda del 2D.
3. **Agacharse en el móvil.** Botón que se activa y desactiva con un toque; Ctrl sale en la pausa.
4. **La zona de la Horda se para al 60 %** del radio inicial (hoy cierra hasta 10 m).
5. **Más difícil.** Criaturas con más daño de base, que crecen con cada oleada, con cada tramo que
   cierra el gas y con el tamaño del equipo.
6. **Criaturas que buscan.** Deambulan; te ven o no según la luz, los obstáculos y si estás escondido;
   la que te descubre grita y avisa a las que estén a 30 m; si te pierden, rebuscan y vuelven a deambular.
7. **Horda en equipo.** Tú solo o con 1, 2 o 3 compañeros bot.
8. **Reanimaciones** en la Horda y en PvP; **derrota** en la Horda si cae todo el equipo.
9. **Órdenes del Rey liche**: Atacar, Reagrupar y Emboscada con un solo botón.

## Reglas

| Regla | Valor | Origen |
|---|---|---|
| Sonido del rayo de trampa | `shock.ogg` de Flare (CC-BY-SA 3.0), a volumen según distancia | usuario; sonido del 2D |
| Tormenta eléctrica | en el golpe y en cada descarga del campo (cada 2 s, 10 s): un rayo sobre cada enemigo dentro y un trueno (`thunder.ogg`) | usuario |
| Jefe | leyenda Rompemareas con bot, equipo de la horda; vida ×4 × (1 + 0,2 por compañero), daño ×1,5; no reaparece ni se reanima | 2D (`spawn_boss_legend`, `BOSS_HP_PER_PLAYER`, `BOSS_DMG_MULT`); ×4 a medir |
| Agacharse en táctil | botón conmutador junto al joystick; se suelta solo al morir | usuario |
| Zona en la Horda | espera 120 s y cierra como hoy, pero se para al 60 % del radio inicial | usuario |
| Daño de base de las criaturas | ×1,3 (9 → 11,7 cada 1,5 s) | usuario ("muy dóciles"); a medir |
| Por oleada | +10 % de vida | 2D (`HP_PER_WAVE`) |
| Por tramo del gas | el cierre va en 4 tramos; cada uno: +15 % vida, +10 % daño, +5 % velocidad | usuario ("mientras avancen las zonas") |
| Por compañero | +3 criaturas por oleada y +8 de tope a la vez | 2D (`_wave_plan`, `MAX_ALIVE + 8·extra`) |
| Estados de una criatura | deambular → perseguir → buscar → deambular | diseño |
| Vista | 12 m de día, 8 m de noche, con línea de visión en la rejilla (una celda bloqueada corta) | diseño |
| Escondido (agachado en hierba alta o invisible) | solo te descubren a ≤ 1,5 m; la que ya te persigue, a ≤ 4 m | usuario ("si pasan cerca o sobre mí sí me ven"; "así me agache 2 m más adelante") |
| Atacar | te delata 3 s, como hoy | existente |
| Grito | al descubrirte, "!" y sonido; avisa a las criaturas a ≤ 30 m (saben quién y dónde) | usuario (30 m) |
| Perder el rastro | 3 s sin verte → van a la última posición, rebuscan 8 s → deambulan | diseño |
| Deambular | celda transitable al azar a ≤ 10 celdas, preferentemente hacia el área limpia; al llegar esperan 0,5-1,5 s | usuario ("caminando en todas direcciones buscando") |
| Horda en equipo | selector 1 a 4 en el menú; compañeros bot con leyendas distintas | usuario |
| Caer (DERRIBO) | a 0 de vida la leyenda queda derribada: se arrastra al 25 % de su velocidad, no ataca y lleva el letrero "¡DERRIBADO! N s". Tiene 45 s | usuario (2026-09-17, sustituye a la vuelta sola) |
| Reanimar (el "gesto") | un compañero vivo **agachado** a ≤ 1,5 m durante 3 s (si se levanta o se va, el progreso baja al mismo ritmo); se levanta donde cayó con 50 % de vida y 3 s de inmunidad | usuario (gesto); 2D (`REVIVE_TIME`, `REVIVE_HP`, `SPAWN_INVULN`) |
| Rematar | los golpes a un derribado le quitan tiempo: el daño de 1,5 veces su vida máxima se lleva los 45 s (un golpe normal, ~1 s). Los proyectiles que van a otro le pasan por encima | usuario ("los golpes le quitan tiempo") |
| Morir | se acaban los 45 s, o no queda nadie de su equipo en pie → muere y la baja es de quien lo derribó; ya no se puede reanimar | usuario |
| Volver | Horda: al empezar la oleada siguiente. PvP: en la ronda siguiente | usuario |
| Señuelos de una derribada | copian su letrero, su animación de arrastrarse, su paso y su falta de barra: si no, se sabría cuál es la de verdad | usuario (2026-09-17) |
| Cuenta de caídas | Horda: toda la partida. PvP: por ronda | diseño |
| Cae todo el equipo | Horda: fin de la partida (oleada alcanzada, bajas, Revancha y Menú). PvP: ronda para el rival, como hoy | usuario |
| Bots | van a reanimar a un compañero caído si no tienen un rival a menos de 8 m, y se agachan a su lado | 2D (`bot_brain` cooperativo) |
| Botón de órdenes del Rey liche | aparece con esqueletos vivos. Toque: alterna Atacar / Reagrupar. Arrastrar y soltar: Emboscada donde sueltes (hasta 12 m). Teclado: F toca; F mantenida apunta con el ratón y al soltar embosca | usuario |
| Atacar | cada esqueleto va al enemigo visible más cercano a él, esté donde esté, rodeando obstáculos; si no hay, vuelve con el Rey | usuario |
| Reagrupar | le siguen en dos anillos (4 a 2 m, 6 a 3,5 m), a 1,5 m unos de otros; golpean a quien tengan a 2 m, sin perseguir | usuario |
| Emboscada | van al punto, se reparten en 3 m y se entierran: medio hundidos, translúcidos para su equipo e invisibles para el rival (ni bots, ni teledirigidos, ni criaturas). Si un enemigo entra a 4 m de cualquiera, salen todos y pasan a Atacar | usuario |
| Esqueletos | los nuevos obedecen la orden puesta (empieza en Atacar); vida ×3 por equipos (180); 3,1 m/s | usuario; 2D (velocidad) |

## Arquitectura

`main.gd` está en 2.902 líneas (tope 3.000). **Paso 0**: sacar la Horda sin cambiar nada, con las
13 trazas deterministas idénticas; después se cambia.

| Script | Clase | Qué hace |
|---|---|---|
| `game/horde.gd` | `Horde` | oleadas, especies, jefe, campo de flujo, IA de criaturas, `_kill_zombie` (paso 0: movido tal cual) |
| `game/creature_senses.gd` | `CreatureSenses` | pura: ¿ve a esta leyenda? (vista, noche, línea de visión, escondido, persecución), estados y tiempos |
| `game/revive.gd` | `Revive` | pura: 45 s de derribo, progreso de reanimación, remate por daño, arrastre |
| `ui/minimap.gd` | `Minimap` | minimapa de arriba a la derecha: gira con la cámara y marca en rojo a los enemigos que ve tu equipo (petición del usuario, 2026-09-17) |
| `game/horde_mode.gd` | `HordeMode` | monta la Horda en equipo: compañeros bot, caídas y reanimaciones, derrota, HUD |
| `game/minions.gd` | `Minions` | esbirros del Rey liche sacados de Combat: órdenes, formación, emboscada, rutas |
| `ui/horde_hud.gd` | `HordeHud` | vida del equipo, caídos y cuenta atrás, progreso de reanimación, oleada, pantalla final |

- Las leyendas de la Horda pasan a ser todas `Fighter` del equipo 1 (hoy la tuya usa `_php` y
  `PLAYER_HP`); las criaturas eligen presa entre todas ellas y sus esbirros y señuelos.
- Campo de flujo: uno por leyenda conocida (hasta 4 BFS de 42×42 cada 0,4 s). Deambular y buscar
  usan `NavGrid` (una ruta al cambiar de meta).
- El jefe es un `Fighter` del equipo 0 con `BotBrain`; `BotBrain` necesita `main.nav`, que hoy
  solo se crea por equipos: se crea también en la Horda.
- Las reanimaciones viven en `Revive` y las usan `HordeMode` y `TeamMode`. `TeamMatch` sigue
  contando la eliminación con las leyendas en pie.

## Orden de trabajo

0. ✅ Extraer `Horde` (trazas idénticas; `main.gd` de 2.903 a ~2.500 líneas).
1. ✅ Rayos y sonido, botón de agacharse, zona al 60 % (plan `docs/superpowers/plans/2026-09-17-horda-etapa1-extraccion-y-arreglos.md`).
2. ✅ Leyendas de la Horda como `Fighter`, Horda en equipo, reanimaciones (Horda y PvP), derrota, HUD
   (plan `docs/superpowers/plans/2026-09-17-horda-etapa2-equipo-y-reanimaciones.md`). De paso: la
   Horda ignoraba la leyenda elegida en el menú, y las descripciones del menú hablaban aún de "15 bajas".
3. ✅ Jefe-leyenda (`boss_probe`): usa Enganche, Ancla clavada y mandoble; sin regeneración (con
   ~1.700 de vida el 8 %/s era imbatible). Cuatro bots lo tumban en 33 s; dos caen en 15 s.
4. ✅ Sentidos de las criaturas (`senses_probe`, plan `docs/superpowers/plans/2026-09-17-horda-etapa4-sentidos.md`).
   Añadido al medir: la mitad de las metas al deambular van cerca del centro del área limpia (con metas
   solo al azar tardaban casi un minuto en dar con alguien y una oleada se atascaba).
5. ✅ Dificultad (`test_horde_scaling`; medido con bots, 10 partidas por versión): solo caían todas en la
   oleada 5 (el jefe) y en equipo de 4 llegaban a la 10 sin perder; ahora solo caen en las oleadas 3-5 y
   en equipo de 4 dos de tres caen en la 5. Aviso "¡La horda se endurece!" en cada tramo del gas.
6. ✅ Órdenes del Rey liche (`test_minions`, `minion_probe`; plan `docs/superpowers/plans/2026-09-17-horda-etapa6-ordenes-liche.md`).
   `game/minions.gd` no saca todo el código de esbirros de `Combat` (el alzado sigue allí): solo su IA y las órdenes.
7. ✅ Documentación, `tools/check.sh` (14 pruebas puras y 10 sondas) y trazas nuevas de referencia.
   Efecto medido en PvP (28 partidas): rondas de 1v1 66 s, 2v2 71 s, 3v3 90 s y 4v4 62 s (antes
   63/40/48/47); victorias del 27 % (Clérigo) al 70 % (Químico).

## Pruebas

- Puras: `test_creature_senses.gd`, `test_revive.gd`, `test_minions.gd` (huecos de la formación,
  disparo de la emboscada) y escalado de dificultad.
- Sondas: `horde_probe` (Horda en equipo con bots: pasan oleadas, hay caídas y reanimaciones, la
  derrota acaba la partida, ninguna criatura quieta mucho rato, el grito no pasa de 30 m),
  `match_probe` (reanimaciones en PvP y la eliminación sigue cerrando rondas), `minion_probe`
  (Atacar llega a un enemigo a 20 m, Reagrupar sigue a menos de 4 m, la emboscada salta),
  `decoy_probe --down-decoys` (los señuelos copian a la Ilusionista derribada) y `minimap_probe`
  (sitio del mapa en pantalla y quién sale en rojo, en PvP y en la Horda).
- Las trazas de la Horda cambian a propósito desde el paso 1: se graban unas nuevas de referencia.

## Fuera de alcance

Emboscadas de los bots; reanimaciones con objeto o habilidad; que el jefe tenga guardia de
criaturas (el 2D la tiene); red.
