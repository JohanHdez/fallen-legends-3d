# Juego en línea, fase 2: la partida PvP en red — plan de implementación

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Que dos personas jueguen de verdad un 1VS1-4VS4 contra el servidor: el servidor simula con
el código de siempre, los clientes mandan controles y pintan lo que llega, tu leyenda se predice, las
rondas van a la par y al acabar todos vuelven a la sala.

**Architecture:** El servidor (peer 1) corre la partida entera con `TeamMode` y `Combat` tal cual,
con `RemoteControl` moviendo las leyendas humanas y `BotBrain` las demás. Manda **20 fotos/s** del
estado (binario, `NetCodec`) y **avisos fiables** para lo que no se puede perder (lanzamientos,
bajas, rondas). El cliente monta el mismo mapa con la semilla del servidor, **no simula el combate**:
interpola a 100 ms lo de los demás y **predice** lo suyo, reconciliando con la última foto.

**Tech Stack:** Godot 4.7.2, GDScript tipado, `@rpc` sobre WebSocket, `StreamPeerBuffer` para el
binario. Pruebas: `tests/test_*.gd` puras, sondas multiproceso (`tools/net_check.sh`).

**Spec:** `docs/superpowers/specs/2026-09-18-juego-en-linea-design.md` (fase **F2**).
**Depende de:** la fase 0 (`docs/superpowers/plans/2026-09-20-juego-en-linea-f0-preparacion.md`):
`game/player_input.gd`, `Vfx` con generador propio y los efectos por `emit_fx`/`FxSink`. **No
empieces la tarea 4 sin la F0 terminada**: sin `FxSink` el servidor pintaría y la partida se le iría
de la del cliente.

## Global Constraints

- Godot **4.7.2**, GDScript tipado; comentarios y textos de UI en **español con tildes**,
  identificadores en inglés; los comentarios explican el porqué y la historia.
- **`main.gd` no crece**: la red vive en `net/`; en `main.gd` solo enganches de una o dos líneas.
- **Nada de `randomize()`**. La semilla de la partida la manda el servidor (`Main.new_seed()`).
- **El servidor es la única autoridad**: el cliente manda intención (controles y "quiero lanzar"),
  nunca resultados. Ningún daño, recarga, munición ni muerte se decide en el cliente.
- **Rendimiento**: mínimo **30 FPS** en el cliente (S24 Ultra, 4v4), tope 60. Lo que la red hace por
  fotograma va **sin asignaciones** en el camino caliente y sin crear nodos salvo cuando aparece algo.
- **Ancho de banda**: objetivo **≤ 30 KB/s** por jugador; se mide y se apunta en el informe.
- `PROTOCOL` sube a **101** en la tarea 3 (cambian los mensajes) y **no vuelve a bajar**.
- **Commit y push solo cuando el usuario lo pida.** Pasos que acaban en "punto de control".
- Nada terminado sin evidencia: `tools/check.sh` y capturas miradas de verdad.

## Mapa de ficheros

| Fichero | Acción | Responsabilidad |
|---|---|---|
| `net/net_codec.gd` | Crear | Puro: controles y fotos a bytes y de vuelta |
| `net/remote_control.gd` | Crear | Servidor: controles recibidos → `Fighter` |
| `net/net_server.gd` | Crear | Servidor: monta la partida, manda fotos y avisos |
| `net/net_client.gd` | Crear | Cliente: recibe, interpola, predice y reconcilia |
| `net/net_view.gd` | Crear | Cliente: un nodo por id; crea, mueve y quita |
| `net/net_fx.gd` | Crear | Servidor: `FxSink` que convierte efectos en avisos |
| `net/net.gd` | Modificar | Ciclo de partida: iniciar, terminar, volver a la sala |
| `game/team_mode.gd` | Modificar | `setup_from_roster(mode, roster)` |
| `main.gd` | Modificar (≤ 10 líneas) | Enganche: con partida en red, `NetClient` manda |
| `tests/test_net_codec.gd` | Crear | Prueba pura del códec |
| `tests/match_net_probe.gd` | Crear | Sonda de cliente en partida |
| `tools/net_check.sh` | Modificar | Paso nuevo: 2v2 con dos clientes |

---

### Task 1: `NetCodec`, puro y probado

**Files:** Create `net/net_codec.gd`, `tests/test_net_codec.gd`

**Interfaces:**
- `NetCodec.MAP_MAX := 200.0` (metros de media anchura del mundo; las posiciones se cuantizan a
  16 bits en ese rango: ~6 mm de error, invisible).
- `encode_input(d: Dictionary) -> PackedByteArray` y `decode_input(b) -> Dictionary` con
  `{"seq": int, "wish": Vector2, "run": bool, "crouch": bool, "basic": bool, "yaw": float}`.
- `encode_snapshot(d: Dictionary) -> PackedByteArray` y `decode_snapshot(b) -> Dictionary` con
  `{"t": float, "ack": int, "fighters": Array, "zone": float, "clock": float, "round": int}`;
  cada leyenda `{"id", "pos": Vector3, "yaw", "anim": int, "hp", "downed", "marked"}`.
- `fits(bytes: int) -> bool` no existe: el tamaño se comprueba en la prueba, no en el juego.

- [ ] **Step 1: Escribir la prueba** (`tests/test_net_codec.gd`, `extends SceneTree`): ida y vuelta
  de un control y de una foto de 8 leyendas; el error de posición por debajo de 1 cm; el `yaw` por
  debajo de 1,5°; una foto de 8 leyendas por debajo de **200 bytes**; una de 8 leyendas + 40
  criaturas por debajo de **700 bytes**; y que leer bytes corruptos (medio mensaje) devuelve `{}` en
  vez de reventar.
- [ ] **Step 2: Ver que falla** — `godot --headless --path . -s tests/test_net_codec.gd` →
  `Identifier "NetCodec" not declared`.
- [ ] **Step 3: Implementar** con `StreamPeerBuffer`: `put_u16` para posiciones cuantizadas,
  `put_u8` para yaw (256 pasos), vida en `u8` (fracción ×255), animación por índice en una tabla
  fija (`NetCodec.ANIMS`), banderas en un byte de bits.
- [ ] **Step 4: Ver que pasa** y anotar en el informe los tamaños reales medidos.
- [ ] **Step 5: Punto de control** — `tools/check.sh tests` en verde.

---

### Task 2: El servidor monta la partida del reparto

**Files:** Modify `game/team_mode.gd`, `net/net.gd`; Create `net/net_server.gd`

**Interfaces:**
- `TeamMode.setup_from_roster(mode: String, roster: Array) -> void`: como `setup`, pero las plazas
  (equipo, leyenda, peer) vienen dadas y **no se sortean**. `roster` es el de `LobbyRules.roster`.
  El `Fighter` de cada plaza guarda `peer` (0 = bot) en un campo nuevo `Fighter.peer`.
- `NetServer` (nodo hijo de `Net` en el servidor): `start(mode, seed, roster)`, `stop()`,
  `_physics_process` a 60 Hz.

- [ ] **Step 1** — En el servidor, `Net._request_start` deja de solo avisar: guarda la semilla en
  `Engine.set_meta("fl_seed", seed)`, carga `main.tscn` en modo partida y llama a
  `NetServer.start(...)`. El servidor **sigue sin pintar**: `--server` ya apaga entrada y proceso de
  `main`, así que `NetServer` conduce el `tick` de `TeamMode` él mismo.
- [ ] **Step 2** — `setup_from_roster`: saca el reparto aleatorio y coloca cada plaza. Prueba pura
  nueva en `tests/test_game_modes.gd` o en una prueba propia: con un reparto dado, los equipos, las
  leyendas y los `peer` quedan donde toca.
- [ ] **Step 3** — Sonda: `tools/net_check.sh` arranca el servidor, un cliente entra, inicia un 1v1
  y el servidor imprime `[PARTIDA] ronda 1` y sigue simulando 10 s sin que nadie se conecte a ver.
  Expected: ninguna `SCRIPT ERROR`, el servidor vivo al final.
- [ ] **Step 4: Punto de control** — `tools/check.sh net` en verde.

---

### Task 3: Controles del cliente (30 Hz) y `RemoteControl`

**Files:** Create `net/remote_control.gd`; Modify `net/net.gd`, `net/net_server.gd`

**Interfaces:**
- `RemoteControl.apply(f: Fighter, input: Dictionary) -> void`: escribe `wish`, `run`, `crouch`,
  `holding_basic` y guarda el `yaw` para orientar. **No** lanza habilidades: eso va aparte y fiable.
- RPC nuevos: `_input_frame(bytes)` (cliente → servidor, `unreliable_ordered`, 30 Hz) y
  `_cast(slot: int, at: Vector3)` (cliente → servidor, `reliable`).
- `PROTOCOL` sube a **101**.

- [ ] **Step 1** — Sonda `tests/match_net_probe.gd`: entra por la sala, inicia, manda "avanzar" 2 s
  y comprueba que **el servidor** movió su leyenda más de 3 m (lo dice una foto de la tarea 4; de
  momento, el servidor lo imprime con `--log`).
- [ ] **Step 2: Verla fallar** (aún no hay controles).
- [ ] **Step 3: Implementar**: el cliente junta su control cada 1/30 s y lo manda; el servidor lo
  guarda por peer y lo aplica en su `tick`. Controles que llegan tarde o desordenados **se
  descartan** por número de secuencia.
- [ ] **Step 4** — Lanzar: el botón del cliente manda `_cast(slot, punto)`; el servidor comprueba
  recarga, munición y alcance **con las reglas de siempre** (`combat.start_cast`) y descarta lo
  imposible. Un cliente trucado no puede lanzar más rápido.
- [ ] **Step 5: Verla pasar** y **Punto de control** — `tools/check.sh net`.

---

### Task 4: Fotos y pintado en el cliente (sin predicción todavía)

**Files:** Create `net/net_client.gd`, `net/net_view.gd`; Modify `main.gd` (≤ 10 líneas), `net/net.gd`

**Interfaces:**
- `NetServer` manda `_snapshot(bytes)` (`unreliable`) 20 veces por segundo a todos.
- `NetClient.on_snapshot(bytes)`: guarda las dos últimas fotos; `_process` interpola al instante
  `ahora - 100 ms`. `NetView.apply(state)`: crea el nodo que falte con los mismos constructores del
  juego, mueve los que hay y borra los que dejaron de venir.
- En `main.gd`: si hay partida en red, **no** se crean bots ni se simula; se monta el mapa con la
  semilla y manda `NetClient`.

- [ ] **Step 1** — La sonda de la tarea 3 crece: la posición que ve el cliente y la que tiene el
  servidor no se separan más de **1,5 m** durante 10 s de movimiento.
- [ ] **Step 2: Verla fallar.**
- [ ] **Step 3: Implementar** la foto, el búfer de dos y la interpolación. Sin asignaciones por
  fotograma en el camino caliente (reutilizar arrays y diccionarios).
- [ ] **Step 4: Verla pasar**; anotar KB/s medidos por jugador.
- [ ] **Step 5: Mirarlo** — captura a 1280×720 de un cliente en partida: las dos leyendas se ven,
  con su barra y su nombre. Abrir con Read y describirla.
- [ ] **Step 6: Punto de control.**

---

### Task 5: Predicción y reconciliación de tu leyenda

**Files:** Modify `net/net_client.gd`

- Tu leyenda se mueve **al momento** con `combat.move_fighter` sobre el mismo mapa; cada control se
  guarda con su número. Al llegar una foto con `ack`, se coloca tu leyenda donde dice el servidor y
  se vuelven a aplicar los controles posteriores. Error > **1,5 m** → salto; menor → se suaviza en
  0,2 s. No se predicen daño, muerte ni habilidades.

- [ ] **Step 1** — Prueba pura `tests/test_net_predict.gd`: dada una posición confirmada y tres
  controles pendientes, la reconciliación devuelve la misma posición que aplicarlos en orden.
- [ ] **Step 2: Verla fallar. Step 3: Implementar. Step 4: Verla pasar.**
- [ ] **Step 5** — Con 150 ms de retardo simulado (`--lag=150` nuevo en la sonda), tu leyenda no da
  tirones: la sonda mide que no retrocede más de 0,3 m en ningún fotograma.
- [ ] **Step 6: Punto de control.**

---

### Task 6: Avisos: efectos, golpes y bajas

**Files:** Create `net/net_fx.gd`; Modify `net/net_server.gd`, `net/net_client.gd`

- `NetFx` es un `FxSink` (F0): en el servidor, cada `emit_fx` se convierte en aviso `_fx(kind, args)`
  (`reliable`) y **no se pinta**. El cliente lo recibe y llama al `LocalFx` de siempre.
- Avisos de juego: `lanzó`, `golpeó`, `derribó`, `murió` (con autor y ranura), `levantó`, `marcó`,
  `ronda`, `fin`. De ellos salen el HUD y los sonidos del cliente.

- [ ] **Step 1** — La sonda comprueba que al morir alguien llega el aviso con autor y que el HUD del
  cliente lo enseña (el registro de bajas que ya tiene `MatchHud`).
- [ ] **Step 2: Verla fallar. Step 3: Implementar. Step 4: Verla pasar.**
- [ ] **Step 5: Punto de control.**

---

### Task 7: Rondas, final y vuelta a la sala

**Files:** Modify `net/net_server.gd`, `net/net_client.gd`, `net/net.gd`, `ui/lobby.gd`

- El servidor manda `ronda` y `fin` por aviso; el cliente pinta los carteles con `MatchHud`. Al
  acabar, todos vuelven a la **sala** (no al menú) con el marcador final, como dice el spec.
- Si alguien se desconecta a mitad, **un bot sigue con su leyenda** y el resto sigue jugando.

- [ ] **Step 1** — La sonda juega un 1v1 entero (`--rounds=1 --roundtime=30`) y comprueba: cartel de
  ronda, final, y que los dos clientes acaban otra vez en la sala.
- [ ] **Step 2: Verla fallar. Step 3: Implementar. Step 4: Verla pasar.**
- [ ] **Step 5** — Desconexión: se mata un cliente a mitad y la partida sigue; su leyenda la lleva un
  bot. La sonda lo comprueba.
- [ ] **Step 6: Punto de control.**

---

### Task 8: Sonda de 2v2 con dos clientes, KB/s y rendimiento

**Files:** Modify `tools/net_check.sh`, `tests/match_net_probe.gd`

- [ ] **Step 1** — Paso nuevo en `tools/net_check.sh`: servidor + **dos** clientes sin pantalla que
  juegan un 2v2 hasta el final. Comprueban sincronía (≤ 1,5 m), rondas a la par, avisos y vuelta a
  la sala. Tope de tiempo y limpieza como el resto del script (guarda de puerto, `kill_server`).
- [ ] **Step 2** — Medir y **apuntar en el informe**: KB/s por jugador (objetivo ≤ 30), bytes por
  foto, y milisegundos por fotograma que consume la red en el cliente.
- [ ] **Step 3** — Rendimiento con ventana: `--bench` conectado a un servidor local, 4v4.
  Expected: **≥ 30 FPS**. Si no llega, decir por qué y qué se recorta (decoración, sombras).
- [ ] **Step 4: Punto de control** — `tools/check.sh` entera.

---

### Task 9: Documentación y puerta completa

**Files:** Modify `README.md`, `CLAUDE.md`

- [ ] **Step 1** — README: la sección "Juego en línea" pasa de "fase 1, la sala" a contar la partida
  en red: qué manda el servidor, qué predice el cliente, las flags nuevas (`--lag`, las de la sonda)
  y los números medidos (KB/s, bytes por foto, FPS).
- [ ] **Step 2** — CLAUDE.md: filas nuevas en la tabla de arquitectura (`net_codec`, `net_server`,
  `net_client`, `net_view`, `net_fx`, `remote_control`), `PROTOCOL` 101 y la regla de que **el
  cliente nunca decide** (daño, recargas, munición y muertes son del servidor).
- [ ] **Step 3** — `tools/check.sh` entera en `RESULTADO: OK`, con su salida pegada.
- [ ] **Step 4: Cierre** — contarle al usuario qué se puede probar ya (dos móviles, o móvil y Mac,
  contra Railway) y preguntarle si quiere commit.
