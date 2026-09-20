# Juego en línea (PvP y Horda) con sala y servidor en Railway — diseño

Fecha: 2026-09-18. Pedido por el usuario: "crea el juego en línea por favor, ya tenemos un despliegue
en railway con el 2d, ahora lo voy a reemplazar con este proyecto"; "tráete la sala que manejamos en
el proyecto 2D donde puedes ver a tu equipo en un lobby"; "la idea es que lo mínimo sea 30 fps,
máximo 60 fps".

## Decisiones del usuario

| Pregunta | Decisión |
|---|---|
| ¿Qué va en línea en la primera versión? | **PvP (1v1 a 4v4) y Horda cooperativa, juntos** |
| ¿Desde dónde se juega? | **APK de Android y navegador** (el ejecutable de escritorio vale para probar) |
| ¿Dónde va la web? | Tiene Railway; abierto a Vercel si es mejor. Recomendado: **Vercel** si acepta archivos de 38 y 42 MB; si no, un segundo servicio en Railway |
| ¿Otro motor u otro servidor? | Investigado (Photon Quantum solo existe para Unity; Edgegap, Gameye, Nakama, W4 Cloud; Hathora y Unity Multiplay cerraron en 2026). **Godot, servidor con autoridad y predicción, en Railway por WebSocket, preparado para pasar a Edgegap** |
| Rendimiento | **Mínimo 30 FPS, máximo 60**, también en línea |

## Qué se construye

- **Servidor dedicado**: el mismo proyecto arrancado con `--server`, sin pantalla, en Railway.
- **Sala** (portada de `scripts/lobby.gd` del 2D): jugadores con leyenda y equipo, líder que elige
  modo y bots, "¡Listo!" e "Iniciar partida". Al acabar la partida se vuelve a la sala.
- **Menú**: nombre del jugador y botón **"Jugar en línea"** junto a los modos sin conexión, que se
  quedan como están.
- **Partida en línea**: Horda cooperativa (1-4 humanos) y 1v1-4v4; los huecos los rellenan bots. Si
  un jugador se desconecta, un bot sigue con su leyenda.
- **Clientes**: APK (con permiso de Internet) y web, los dos por `wss://`.

Fuera de alcance (siguiente paso si hace falta): perfiles, oro y tienda del 2D; cuentas;
emparejamiento con desconocidos; clasificaciones; **más de una sala a la vez** (como el 2D: una sala
por servidor); volver a la misma partida tras desconectarse; chat.

## Requisitos

- **Rendimiento del cliente**: nunca por debajo de **30 FPS** y tope de **60** (`Engine.max_fps`,
  ya puesto el 2026-09-17), en el S24 Ultra con un 4v4 y con la Horda llena, y en el navegador. Lo
  que añade la red en cada fotograma (leer una foto, interpolar, mover nodos) va sin asignaciones
  grandes y sin crear nodos salvo cuando aparece algo nuevo. Se mide con `--bench` conectado.
- **Servidor**: simula a 60 Hz con el código de siempre; manda **20 fotos/s** del estado; recibe
  los controles de cada jugador a 30 Hz.
- **Ancho de banda**: objetivo ≤ 30 KB/s por jugador (el 2D gastaba unos 80). Búfer de salida del
  WebSocket de 1 MB, como el 2D, para aguantar atascos del móvil.
- **Latencia**: jugable hasta ~150 ms de ida y vuelta (Railway está en una sola región y va por TCP).
- **Seguridad**: el servidor decide todo (recargas, munición, daño, alcances): el cliente solo manda
  controles. El identificador del dispositivo no se difunde nunca. Ningún secreto en el repo.

## Arquitectura

### Tres formas de arrancar

- **Sin conexión**: como hoy.
- **Servidor** (`--server`): sin jugador local. Cada leyenda humana la mueve un `RemoteControl`
  con los controles que llegan de su jugador; el resto, `BotBrain`. `combat.fighters[0]` (`pf`) es la
  del líder: el código que hoy mira a "tu leyenda" (cámara, HUD) corre sin pantalla sin estorbar,
  igual que con `--autoplay` en las sondas.
- **Cliente**: monta el mismo mapa con la semilla que manda el servidor y **no simula el combate**:
  pinta lo que llega. Su `pf` es su propia leyenda.

### Quién mueve cada leyenda

`Fighter` ya separa la leyenda de quién la maneja: solo se escriben `wish`, `run`, `crouch` y
`holding_basic`, y se pide lanzar con `combat.start_cast`. `RemoteControl` hace exactamente eso con
los controles recibidos, como hoy lo hacen el teclado, el táctil y los bots.

### Protocolo

- Transporte: `WebSocketMultiplayerPeer` en el puerto de `PORT` (Railway) o 7777; ENet para pruebas
  locales. `PROTOCOL` sube con cada cambio de mensajes y el servidor echa con un aviso a quien no
  coincida (como el 2D). Los clientes del 2D que lleguen al servidor nuevo no se registran y su
  menú les dice que no entiende al servidor.
- **Sala** (fiable): registrarse (protocolo, nombre, id de dispositivo) → estado de la sala
  (jugadores, modo, bots, líder, listos); peticiones de modo, equipo, leyenda, bots, listo,
  iniciar y salir.
- **Inicio** (fiable): modo, semilla, reparto (id de leyenda, leyenda, equipo, jugador o bot).
- **Controles** (cliente → servidor, 30 Hz): número de secuencia, joystick, correr, agacharse,
  básica mantenida. **Lanzar** va aparte y fiable (no se puede perder un botón), con ranura y punto.
- **Fotos** (servidor → cliente, 20 Hz): instante, último control confirmado de ese cliente, y
  compactado en bytes (`StreamPeerBuffer`, posiciones en 16 bits): leyendas (posición, orientación,
  animación, vida, derribo, marca; munición y cargas solo las propias), proyectiles, trampas,
  zonas, muros de espinas, balizas, esbirros, señuelos, criaturas, gas y reloj de ronda u oleada.
  Estimado: unos 600 bytes por foto con 70 criaturas, ~15 KB/s.
- **Avisos** (fiables): lanzó, golpeó, derribó, murió, levantó, marcó, ronda, oleada, jefe, fin de
  partida y sonidos. De ellos salen los efectos visuales y el HUD en el cliente.
- La codificación va en un módulo puro, `NetCodec`, probado aparte.

### Cliente: pintar lo que manda el servidor

- `NetView` guarda un nodo por id: lo crea cuando aparece en una foto (con los mismos constructores
  de modelos y `Vfx` del juego), lo mueve y lo quita cuando deja de venir. Los demás se pintan
  **100 ms en diferido**, interpolando entre dos fotos, para que se muevan suaves.
- **Tu leyenda se predice**: tus controles se aplican al momento con `combat.move_fighter` sobre el
  mismo mapa y colisiones; cuando una foto confirma un control, se vuelven a aplicar los que aún
  no ha confirmado (reconciliación). Si el error pasa de 1,5 m, salta; si es menor, se suaviza.
- No se predicen habilidades, daño ni muertes: llegan del servidor.

### Separar lógica y efectos en el combate

`combat.gd` mezcla la lógica con 57 llamadas a `Vfx`. Antes de la red:

1. `Vfx` pasa a tener **su propio generador aleatorio**. Hoy comparte el `rng` del combate (el zigzag
   de los rayos), así que pintar o no pintar cambiaría la partida. Cambia las trazas **una vez**, a
   propósito.
2. Cada efecto del combate sale por un único punto (`emit_fx`): sin conexión se pinta al momento; en
   el servidor se convierte en aviso; en el cliente se pinta al recibirlo. Hecho sin cambiar el
   comportamiento: trazas idénticas antes y después, con el método del CLAUDE.md.

### `main.gd` no crece

Va por 2.888 líneas de 3.000. La red va en `net/`; en `main.gd` solo quedan los enganches. Antes, se
saca la entrada del jugador (teclado, táctil, apuntar) a `game/player_input.gd` con trazas
idénticas, para dejar sitio.

### Ficheros nuevos (previstos)

| Fichero | Qué es |
|---|---|
| `net/net.gd` (autoload `Net`) | Conexión, sala y ciclo de partida |
| `net/net_address.gd`, `net/identity.gd` | Traídos del 2D: dirección del servidor e id de dispositivo |
| `net/net_codec.gd` | Puro: codificar y leer fotos y controles |
| `net/remote_control.gd` | Servidor: controles recibidos → `Fighter` |
| `net/net_server.gd` | Servidor: fotos y avisos |
| `net/net_client.gd`, `net/net_view.gd` | Cliente: interpolación, predicción y pintar |
| `ui/lobby.gd` | La sala, construida por código como el resto de la UI del 3D |
| `Dockerfile`, `.dockerignore`, `railway.json` | Servidor en Railway, como el 2D |

## Despliegue

- **Railway**: el servicio del 2D pasa a construir este repo (se cambia la fuente en el panel de
  Railway). Arranque: `godot --headless --path /app -- --server`. El dominio se mantiene
  (`wss://fallen-legends-production.up.railway.app`) y es el que traen el APK y la web.
- **Android**: `permissions/internet=true` (hoy `false`). Cambia la regla "Android sin permisos de
  red" del CLAUDE.md, por decisión del usuario.
- **Web**: la exportación que ya hay (77 MB, sin hilos, así que no pide cabeceras especiales),
  conectando por `wss://`. Se sube desde el Mac a Vercel con `vercel deploy`; si Vercel no acepta
  los tamaños, segundo servicio en Railway.

## Pruebas

- **Puras**: `NetCodec` (ida y vuelta, cuantización, tamaño), interpolación, reconciliación y
  reglas de la sala (líder, listos, equipos, huecos → bots).
- **Sondas con varios procesos** (`tools/net_check.sh`, dentro de `tools/check.sh`): un servidor
  sin pantalla y dos clientes sin pantalla con controles automáticos. Recorren sala → partida →
  fin de partida → sala y comprueban que la posición y la vida que ve cada cliente coinciden con
  las del servidor (con margen), que llegan los avisos, que las rondas y oleadas van a la par, los
  KB/s por jugador y lo que tarda la red por fotograma.
- **Rendimiento**: `--bench` conectado, con la ventana en primer plano: 4v4 y Horda llena a 30 FPS o
  más. En el S24 Ultra y en Chrome del móvil lo mide el usuario, con el contador de FPS de la pausa.

## Fases

Cada fase acaba con la puerta de calidad en verde y algo que se puede probar.

| Fase | Qué | Cómo se sabe que está |
|---|---|---|
| **F0** Preparación | `player_input.gd` fuera de `main.gd`; `Vfx` con su generador; efectos por `emit_fx` | Trazas idénticas (salvo el cambio del generador, una vez); puerta en verde |
| **F1** Red y sala | `Net`, servidor `--server`, sala, menú "Jugar en línea" | Servidor local y dos clientes entran, eligen, se ponen listos y el líder inicia |
| **F2** PvP en línea | Controles, fotos, avisos, predicción, rondas y final | Sonda de 2v2 con dos clientes: sincronía, rondas y vuelta a la sala; ≥30 FPS |
| **F3** Horda en línea | Criaturas, oleadas, jefe, reanimaciones | Sonda de Horda con dos clientes; KB/s dentro del objetivo |
| **F4** Despliegue | Docker, Railway, APK con Internet, web en Vercel | Partida real desde el APK y el navegador contra el servidor de Railway |

## Riesgos

- **El navegador del móvil puede no llegar a 30 FPS** con el 3D. Se mide en F4; si no llega, la web
  sale con menos decoración y sin sombras.
- **Latencia de Railway** (una región y TCP): EE. UU. este para Latinoamérica; si en el sur se nota,
  se pasa el servidor a Edgegap (UDP, cerca de cada jugador) sin tocar el juego.
- **Una sola sala por servidor**, como el 2D.
- **Los APK del 2D pierden el juego en línea** cuando el servicio de Railway pase a ser el del 3D.
- **Licencia QAL** del Bestiary: publicar la web es distribuir el juego compilado, igual que el APK
  (permitido); el repositorio sigue privado.
- **`main.gd` al límite**: por eso la F0 empieza sacando código.

## Preguntas resueltas (2026-09-18)

- **Los jugadores están en Latinoamérica** → Railway en **EE. UU. este (Virginia)**, la región más
  cercana para casi toda la zona: ~60-100 ms desde Colombia o México y ~130-160 ms desde Argentina
  o Chile, en el límite de lo jugable. Si en el sur se nota, Edgegap tiene servidores en São Paulo
  y Santiago.
- **Se reutiliza el dominio del 2D** (`fallen-legends-production.up.railway.app`): los APK del 2D
  se quedan sin servidor en cuanto el servicio pase a ser el del 3D.
