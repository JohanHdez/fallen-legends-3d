# Juego en línea, fase 1: red y sala — plan de implementación

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Un servidor dedicado (`--server`, WebSocket) y la sala del 2D en el 3D: desde el menú, "Jugar
en línea" lleva a una sala donde cada jugador ve a su equipo, elige leyenda y equipo, se pone listo y
el líder inicia; el servidor sortea la semilla y reparte las plazas (humanos y bots).

**Architecture:** Un autoload `Net` (portado de `scripts/net.gd` del 2D) hace de conexión y de
autoridad de la sala; las reglas de la sala viven en una clase pura, `LobbyRules`, que usan el
servidor (de verdad) y los clientes (copia para pintar). La UI de la sala (`Lobby`) se construye por
código como el resto de la UI del 3D y sustituye al menú en su misma capa. En esta fase "Iniciar"
solo reparte y avisa: la partida en red es la fase 2.

**Tech Stack:** Godot 4.7.2, GDScript tipado, `WebSocketMultiplayerPeer` / `ENetMultiplayerPeer`,
RPC de alto nivel (`@rpc`). Pruebas: `tests/test_*.gd` (`godot -s`) y un script con varios procesos
(`tools/net_check.sh`).

**Spec:** `docs/superpowers/specs/2026-09-18-juego-en-linea-design.md` (fase F1). La F0 del spec
(sacar la entrada de `main.gd`, generador propio de `Vfx`, efectos por `emit_fx`) solo la necesita
la F2, así que va en el plan de la F2; esta fase no toca el combate.

## Global Constraints

- Godot **4.7.2**, GDScript con tipado estático; comentarios y textos de UI en **español con
  tildes**, identificadores en inglés; los comentarios explican el porqué y la historia.
- **`main.gd` no crece**: va por 2.888 líneas de 3.000 (tope del hook). Esta fase solo le añade el
  enganche de `--server` (7 líneas). La red va en `net/`.
- **Nada de `randomize()`**. La semilla de la partida sale de `Main.new_seed()`.
- **Commit y push solo cuando el usuario lo pida.** Identidad `JohanHdez
  <37870481+JohanHdez@users.noreply.github.com>`; nunca `--force`. Por eso los pasos de este plan
  acaban en "punto de control", no en commit.
- **Ningún secreto en el repo**; el id de dispositivo **no se difunde nunca** a otros jugadores.
- Transporte: **WebSocket** en el puerto de la variable `PORT` o **7777**; ENet para pruebas locales.
  **`PROTOCOL` = 100** (el 2D va por 3). Servidor por defecto:
  **`wss://fallen-legends-production.up.railway.app`** (decisión del usuario: se reutiliza el dominio).
- Rendimiento del cliente: **mínimo 30 FPS, máximo 60**.
- UI construida en código: raíz con `set_anchors_and_offsets_preset(PRESET_FULL_RECT)`, **botones de
  64 px o más**, probada a **1280×720 y 1600×720 con `--touch`**.
- **Android sigue sin permiso de red** hasta la F4 (en el móvil, "En línea" aún no podrá conectar).
- Nada está terminado sin evidencia: `tools/check.sh` con su salida y capturas miradas de verdad.
- Ediciones hechas por Bash no pasan por los hooks: después, `tools/check.sh parse <fichero>`.

---

## Mapa de ficheros

| Fichero | Acción | Responsabilidad |
|---|---|---|
| `net/net_address.gd` | Crear (copia del 2D) | Dirección → transporte (`NetAddress.parse`) |
| `net/identity.gd` | Crear (copia del 2D) | Id de dispositivo y apodo (`Identity`) |
| `net/lobby_rules.gd` | Crear | Reglas puras de la sala (`LobbyRules`) |
| `net/net.gd` | Crear | Autoload `Net`: conexión, registro, sala, arranque |
| `ui/ui_kit.gd` | Crear | `UiKit.label` y `UiKit.button`, compartidos por menú y sala |
| `ui/lobby.gd` | Crear | La sala (`Lobby`) |
| `ui/mode_menu.gd` | Modificar | Nombre + botón "EN LÍNEA"; usa `UiKit` |
| `main.gd` | Modificar (`_ready`, 7 líneas) | `--server`: no monta nada |
| `project.godot` | Modificar | Registrar el autoload `Net` |
| `tests/test_net_address.gd`, `tests/test_identity.gd`, `tests/test_lobby_rules.gd` | Crear | Pruebas puras |
| `tests/lobby_probe.gd` | Crear | Sonda de cliente (la carga `Net` con `--netprobe`) |
| `tools/net_check.sh` | Crear | Servidor + clientes sin pantalla |
| `tools/check.sh` | Modificar | Paso `net` dentro de `all` |
| `README.md`, `CLAUDE.md` | Modificar | Flags, comandos, arquitectura |

---

### Task 1: Dirección e identidad, traídas del 2D

**Files:**
- Create: `net/net_address.gd`, `net/identity.gd`
- Test: `tests/test_net_address.gd`, `tests/test_identity.gd`

**Interfaces:**
- Produces: `NetAddress.parse(text: String, default_port: int) -> Dictionary`
  (`{"transport": "enet"|"ws", "host", "port", "url"}`), `NetAddress.WS`, `NetAddress.ENET`;
  `Identity.PATH` (static var), `Identity.load_or_create() -> Dictionary` (`{"id", "name"}`),
  `Identity.save(id, name)`, `Identity.is_valid_id(s) -> bool`, `Identity.new_id() -> String`,
  `Identity.sanitize_name(raw) -> String`, `Identity.unique_name(name, taken: Array) -> String`,
  `Identity.NAME_MAX` (16), `Identity.DEFAULT_NAME` ("Jugador").

- [ ] **Step 1: Traer las pruebas del 2D**

```bash
mkdir -p net
cp ~/Downloads/arena-arpg/tests/test_net_address.gd tests/test_net_address.gd
```

Crear `tests/test_identity.gd` (la del 2D sin la parte de `Profiles`, que no se trae):

```gdscript
## Prueba de lógica pura de la identidad del jugador: `godot --headless --path . -s tests/test_identity.gd`
## `Identity` (traída del 2D el 2026-09-18 para el juego en línea) genera y guarda un identificador
## secreto por dispositivo, sanea el apodo y resuelve apodos repetidos en una sala.
extends SceneTree

func _init() -> void:
	var failures := 0
	Identity.PATH = "user://identity_test.json"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Identity.PATH))

	# Primera ejecución: crea un id de 32 hexadecimales y lo persiste; la segunda devuelve el mismo.
	var first := Identity.load_or_create()
	failures += _check("id válido al crearlo", Identity.is_valid_id(str(first.id)), first)
	failures += _check("apodo por defecto", first.name == "Jugador", first)
	var again := Identity.load_or_create()
	failures += _check("el id se conserva entre arranques", again.id == first.id, [first.id, again.id])
	# Dos dispositivos distintos no comparten id.
	Identity.PATH = "user://identity_test2.json"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Identity.PATH))
	var other := Identity.load_or_create()
	failures += _check("ids distintos por dispositivo", other.id != first.id, [first.id, other.id])
	Identity.save(str(other.id), "Kael")
	failures += _check("apodo guardado", Identity.load_or_create().name == "Kael", Identity.load_or_create())

	# Validación del id (lo que manda el cliente al servidor: nunca se confía en él).
	failures += _check("id corto inválido", not Identity.is_valid_id("abc"), "")
	failures += _check("id no hexadecimal inválido", not Identity.is_valid_id("zz" + "0".repeat(30)), "")
	failures += _check("id en mayúsculas se acepta", Identity.is_valid_id("ABCDEF0123456789ABCDEF0123456789"), "")

	# Apodo: recorte, tope de 16, sin caracteres de control, vacío -> Jugador.
	failures += _check("apodo recortado", Identity.sanitize_name("   Kael  ") == "Kael", Identity.sanitize_name("   Kael  "))
	failures += _check("apodo a 16", Identity.sanitize_name("abcdefghijklmnopqrstuvwxyz").length() == 16, "")
	failures += _check("apodo vacío", Identity.sanitize_name("   ") == "Jugador", "")
	failures += _check("apodo sin caracteres de control", Identity.sanitize_name("Ka\nel\tX") == "KaelX", Identity.sanitize_name("Ka\nel\tX"))
	failures += _check("espacios internos colapsados", Identity.sanitize_name("Ka    el") == "Ka el", "")

	# Apodos repetidos en la sala: se numeran; sin conflicto se devuelve tal cual.
	failures += _check("apodo libre", Identity.unique_name("Kael", ["Ana", "Bo"]) == "Kael", "")
	failures += _check("apodo repetido", Identity.unique_name("Kael", ["Kael"]) == "Kael 2", Identity.unique_name("Kael", ["Kael"]))
	failures += _check("apodo repetido dos veces", Identity.unique_name("Kael", ["Kael", "Kael 2"]) == "Kael 3", "")
	failures += _check("numerar respeta el tope de 16", Identity.unique_name("abcdefghijklmnop", ["abcdefghijklmnop"]).length() <= 16, "")
	failures += _check("comparación sin mayúsculas", Identity.unique_name("kael", ["Kael"]) == "kael 2", "")

	for p in ["user://identity_test.json", "user://identity_test2.json"]:
		var rm := DirAccess.remove_absolute(ProjectSettings.globalize_path(p))
		failures += _check("limpieza de %s" % p, rm == OK and not FileAccess.file_exists(p), rm)
	# Los autoloads se instancian DESPUÉS de este _init (Net._ready llama a Identity.load_or_create):
	# si no se restaura la ruta, Net volvería a crear el fichero de prueba al salir.
	Identity.PATH = "user://identity.json"
	print("test_identity: %d fallos" % failures)
	quit(1 if failures > 0 else 0)

func _check(name: String, ok: bool, got: Variant) -> int:
	if not ok:
		print("FALLO: %s -> %s" % [name, got])
	return 0 if ok else 1
```

- [ ] **Step 2: Ver que fallan**

Run: `godot --headless --path . -s tests/test_net_address.gd; godot --headless --path . -s tests/test_identity.gd`
Expected: `SCRIPT ERROR: ... Identifier "NetAddress" not declared` (y lo mismo con `Identity`).

- [ ] **Step 3: Traer las dos clases**

```bash
cp ~/Downloads/arena-arpg/scripts/net_address.gd net/net_address.gd
cp ~/Downloads/arena-arpg/scripts/identity.gd net/identity.gd
godot --headless --path . --import >/dev/null 2>&1
```

Añadir como segunda línea de cada fichero (después de la primera línea `##`):

```gdscript
## Copiado de arena-arpg (scripts/<mismo nombre>) el 2026-09-18 para el juego en línea del 3D.
```

- [ ] **Step 4: Ver que pasan**

Run: `tools/check.sh tests 2>&1 | grep -E "test_net_address|test_identity"`
Expected: `✓ tests/test_net_address.gd` y `✓ tests/test_identity.gd`.

- [ ] **Step 5: Punto de control** — `tools/check.sh parse net/net_address.gd net/identity.gd` → `RESULTADO: OK`.

---

### Task 2: Reglas de la sala (`LobbyRules`, pura)

**Files:**
- Create: `net/lobby_rules.gd`
- Test: `tests/test_lobby_rules.gd`

**Interfaces:**
- Consumes: `GameModes.ORDER`, `GameModes.MODES`, `GameModes.team_size(mode) -> int`,
  `HordeMode.MAX_TEAM` (4), `LegendData.PLAYABLE` (7), `LegendData.LEGENDS[i]["name"]`.
- Produces (clase `LobbyRules`, `extends RefCounted`):
  - `const MAX_PLAYERS := 8`
  - `var players: Dictionary` (peer `int` → `{"name": String, "team": int, "legend": int, "ready": bool}`),
    `var order: Array` (ids por llegada), `var mode: String` (por defecto `"2v2"`),
    `var horde_team: int`, `var leader: int` (0 = nadie)
  - `is_horde() -> bool`, `team_size() -> int`, `capacity() -> int`,
    `count_team(team: int, except_id := 0) -> int`, `legends_in(team: int, except_id := 0) -> Array`,
    `free_legend(team: int, except_id := 0) -> int`
  - `add(id: int, name: String) -> Dictionary` (`{}` si no cabe), `remove(id: int) -> void`
  - `set_mode(by: int, m: String) -> String`, `set_team(id: int, t: int) -> String`,
    `set_legend(id: int, legend: int) -> String`, `set_ready(id: int, r: bool) -> void`,
    `set_horde_team(by: int, n: int) -> String` — devuelven `""` si se pudo, o el motivo
  - `unready_all()`, `ready_needed() -> int`, `ready_count() -> int`, `all_ready() -> bool`,
    `can_start(by: int) -> String`
  - `roster(seed: int) -> Array` (plazas `{"team": int, "legend": int, "peer": int (0 = bot), "name": String}`)
  - `to_dict() -> Dictionary`, `from_dict(d: Dictionary) -> void`

- [ ] **Step 1: Escribir la prueba**

`tests/test_lobby_rules.gd`:

```gdscript
## Prueba de las reglas de la sala en línea (net/lobby_rules.gd), sin red:
##   godot --headless --path . -s tests/test_lobby_rules.gd
## Petición del usuario (2026-09-18): "tráete la sala que manejamos en el proyecto 2D donde puedes ver
## a tu equipo en un lobby". Líder, equipos, leyendas sin repetir dentro de un equipo, listos, y el
## reparto de plazas con bots al empezar.
extends SceneTree

var failures := 0


func _check(ok: bool, msg: String) -> void:
	if not ok:
		print("FALLO: " + msg)
		failures += 1


func _init() -> void:
	_test_join_and_leader()
	_test_mode_and_teams()
	_test_ready_and_start()
	_test_roster()
	_test_sync()
	print("test_lobby_rules: %s (%d fallos)" % ["OK" if failures == 0 else "FALLO", failures])
	quit(1 if failures > 0 else 0)


func _test_join_and_leader() -> void:
	var s := LobbyRules.new()   # 2v2 por defecto
	var a := s.add(10, "Ana")
	var b := s.add(11, "Beto")
	_check(s.leader == 10, "el primero en llegar es el líder (líder %d)" % s.leader)
	_check(int(a["team"]) == 1 and int(b["team"]) == 2, "en 2v2 se reparten: Ana %d, Beto %d" % [a["team"], b["team"]])
	s.add(12, "Caro")
	s.add(13, "Dani")
	_check(s.add(14, "Eva").is_empty(), "un 2v2 no admite a un quinto")
	_check(s.count_team(1) == 2 and s.count_team(2) == 2, "dos y dos (%d/%d)" % [s.count_team(1), s.count_team(2)])
	_check(int(s.players[12]["legend"]) != int(s.players[10]["legend"]), "Caro no repite la leyenda de su compañera Ana")
	s.remove(10)
	_check(s.leader == 11, "si se va el líder, lo es el siguiente en llegar (líder %d)" % s.leader)
	s.remove(11)
	s.remove(12)
	s.remove(13)
	_check(s.leader == 0 and s.players.is_empty(), "sala vacía, sin líder")


func _test_mode_and_teams() -> void:
	var s := LobbyRules.new()
	s.add(1, "Ana")
	s.add(2, "Beto")
	s.add(3, "Caro")
	_check(s.set_mode(2, "4v4") != "", "solo el líder cambia el modo")
	_check(s.mode == "2v2", "el modo no cambió (%s)" % s.mode)
	_check(s.set_mode(1, "1v1") != "", "tres no caben en un 1v1")
	s.set_ready(2, true)
	_check(s.set_mode(1, "4v4") == "", "el líder pasa a 4v4")
	_check(not bool(s.players[2]["ready"]), "cambiar de modo quita el listo a todos")
	_check(s.set_team(2, 1) == "", "Beto se pasa al equipo 1")
	_check(int(s.players[2]["team"]) == 1, "Beto está en el 1")
	var ana_legend := int(s.players[1]["legend"])
	_check(s.set_legend(2, ana_legend) != "", "Beto no puede llevar la leyenda de su compañera Ana")
	s.set_team(3, 2)
	_check(s.set_legend(3, ana_legend) == "", "Caro, del otro equipo, sí puede llevarla")
	_check(s.set_team(1, 3) != "", "no existe el equipo 3")
	_check(s.set_mode(1, "horda") == "", "a la Horda")
	var legends := []
	for id in s.players:
		_check(int(s.players[id]["team"]) == 1, "en la Horda todos al equipo 1 (%s)" % s.players[id]["name"])
		legends.append(int(s.players[id]["legend"]))
	_check(_unique(legends), "al juntarse en un equipo no repiten leyenda: %s" % str(legends))
	_check(s.set_team(2, 2) != "", "en la Horda no se cambia de equipo")
	_check(s.horde_team >= 3, "la Horda tiene al menos una plaza por humano (%d)" % s.horde_team)
	_check(s.set_horde_team(1, 2) == "" and s.horde_team == 3, "el equipo de la Horda no baja de los humanos que hay (%d)" % s.horde_team)
	_check(s.set_horde_team(2, 4) != "", "solo el líder elige el tamaño del equipo")


func _test_ready_and_start() -> void:
	var s := LobbyRules.new()
	s.add(1, "Ana")
	s.add(2, "Beto")
	s.add(3, "Caro")
	_check(s.ready_needed() == 2, "listos hacen falta los que no son líder (%d)" % s.ready_needed())
	_check(s.can_start(1) != "", "sin listos no se empieza")
	s.set_ready(2, true)
	_check(s.can_start(1) != "", "con uno de dos listos, tampoco")
	s.set_ready(3, true)
	_check(s.can_start(1) == "", "todos listos: el líder puede empezar")
	_check(s.can_start(2) != "", "otro que no es el líder no puede")


func _test_roster() -> void:
	var s := LobbyRules.new()          # 2v2: Ana (1), Beto (2); los otros dos huecos, bots
	s.add(1, "Ana")
	s.add(2, "Beto")
	var r := s.roster(1234)
	_check(r.size() == 4, "un 2v2 son cuatro plazas (%d)" % r.size())
	if r.size() == 4:
		_check(int(r[0]["team"]) == 1 and int(r[0]["peer"]) == 1, "la primera plaza es Ana, del equipo 1")
		_check(int(r[1]["team"]) == 1 and int(r[1]["peer"]) == 0, "la segunda, un bot del equipo 1")
		_check(int(r[2]["team"]) == 2 and int(r[2]["peer"]) == 2, "la tercera, Beto, del equipo 2")
		_check(int(r[3]["team"]) == 2 and int(r[3]["peer"]) == 0, "la cuarta, un bot del equipo 2")
	for t in [1, 2]:
		var legends := []
		for slot in r:
			if int(slot["team"]) == t:
				legends.append(int(slot["legend"]))
		_check(_unique(legends), "equipo %d sin leyendas repetidas: %s" % [t, str(legends)])
	_check(str(s.roster(1234)) == str(r), "la misma semilla da el mismo reparto")
	var h := LobbyRules.new()
	h.add(5, "Ana")
	h.set_mode(5, "horda")
	h.add(6, "Beto")
	h.set_horde_team(5, 3)
	var hr := h.roster(7)
	_check(hr.size() == 3, "Horda de 3: tres plazas (%d)" % hr.size())
	var bots := 0
	for slot in hr:
		_check(int(slot["team"]) == 1, "en la Horda todas las plazas son del equipo 1")
		if int(slot["peer"]) == 0:
			bots += 1
	_check(bots == 1, "dos humanos y un bot (%d bots)" % bots)


func _test_sync() -> void:
	var s := LobbyRules.new()
	s.add(1, "Ana")
	s.add(2, "Beto")
	s.set_mode(1, "3v3")
	s.set_ready(2, true)
	var c := LobbyRules.new()
	c.from_dict(s.to_dict())
	_check(c.mode == "3v3" and c.leader == 1 and c.players.size() == 2, "la copia del cliente tiene modo, líder y jugadores")
	_check(bool(c.players[2]["ready"]) and String(c.players[2]["name"]) == "Beto", "y quién está listo")
	_check(c.order == s.order, "y el orden de llegada")
	s.players[2]["name"] = "Otro"
	_check(String(c.players[2]["name"]) == "Beto", "la copia no comparte datos con el original")


func _unique(a: Array) -> bool:
	var seen := {}
	for v in a:
		if seen.has(v):
			return false
		seen[v] = true
	return true
```

- [ ] **Step 2: Ver que falla**

Run: `godot --headless --path . -s tests/test_lobby_rules.gd`
Expected: `SCRIPT ERROR: ... Identifier "LobbyRules" not declared`.

- [ ] **Step 3: Implementar**

`net/lobby_rules.gd`:

```gdscript
## Reglas de la sala del juego en línea, sin red: quién es el líder, en qué equipo y con qué leyenda
## está cada uno, quién está listo, si se puede empezar y el reparto de plazas (humanos y bots) al
## empezar. La usan el servidor (la de verdad) y los clientes (una copia, para pintar la sala). Pura
## para probarla con `godot -s` (tests/test_lobby_rules.gd). Portada de las reglas de sala de
## scripts/net.gd del 2D con los modos del 3D; diseño en
## docs/superpowers/specs/2026-09-18-juego-en-linea-design.md.
class_name LobbyRules
extends RefCounted

const MAX_PLAYERS := 8        # un 4v4 lleno

var players := {}             # id de peer -> {"name": String, "team": int, "legend": int, "ready": bool}
var order: Array = []         # ids por orden de llegada: si se va el líder, lo es el siguiente
var mode := "2v2"
var horde_team := HordeMode.MAX_TEAM   # Horda: plazas del equipo (humanos + bots)
var leader := 0               # 0 = nadie


func is_horde() -> bool:
	return mode == "horda"


## Plazas por equipo: las del modo por equipos o, en la Horda, las que eligió el líder.
func team_size() -> int:
	return horde_team if is_horde() else GameModes.team_size(mode)


## Humanos que caben: en la Horda, HordeMode.MAX_TEAM; por equipos, los dos equipos llenos.
func capacity() -> int:
	return HordeMode.MAX_TEAM if is_horde() else GameModes.team_size(mode) * 2


func count_team(team: int, except_id := 0) -> int:
	var n := 0
	for id in players:
		if int(id) != except_id and int(players[id]["team"]) == team:
			n += 1
	return n


## Leyendas ya cogidas en un equipo: dentro de un equipo no se repiten; entre equipos, sí (como
## GameModes.pick_legends sin conexión).
func legends_in(team: int, except_id := 0) -> Array:
	var out: Array = []
	for id in players:
		if int(id) != except_id and int(players[id]["team"]) == team:
			out.append(int(players[id]["legend"]))
	return out


func free_legend(team: int, except_id := 0) -> int:
	var used := legends_in(team, except_id)
	for l in LegendData.PLAYABLE:
		if l not in used:
			return l
	return 0


## Entra alguien: al equipo con más sitio (en la Horda, al 1) y con una leyenda que su equipo no
## lleve. Devuelve su ficha, o {} si la sala está llena para este modo.
func add(id: int, name: String) -> Dictionary:
	if players.size() >= mini(capacity(), MAX_PLAYERS):
		return {}
	var team := 1 if is_horde() else (2 if count_team(2) < count_team(1) else 1)
	var p := {"name": name, "team": team, "legend": free_legend(team), "ready": false}
	players[id] = p
	order.append(id)
	if leader == 0:
		leader = id
	horde_team = maxi(horde_team, players.size())
	return p


func remove(id: int) -> void:
	players.erase(id)
	order.erase(id)
	if leader == id:
		leader = int(order[0]) if not order.is_empty() else 0


## Cambia el modo (solo el líder). Quita el listo a todos: nadie queda comprometido con un modo que
## no ha visto (como el 2D). "" si se pudo; si no, el motivo.
func set_mode(by: int, m: String) -> String:
	if by != leader:
		return "Solo el líder cambia el modo."
	if not GameModes.MODES.has(m):
		return "Ese modo no existe."
	if m == mode:
		return ""
	var old := mode
	mode = m
	if players.size() > capacity():
		mode = old
		return "Sois %d: no cabéis en %s." % [players.size(), String(GameModes.MODES[m]["name"])]
	if is_horde():
		horde_team = maxi(horde_team, players.size())
	_reseat()
	unready_all()
	return ""


## Tras cambiar de modo: en la Horda todos al equipo 1; por equipos, cada uno se queda en el suyo si
## cabe. Si dos del mismo equipo llevan la misma leyenda, la conserva el que llegó antes.
func _reseat() -> void:
	var size := team_size()
	var counts := {1: 0, 2: 0}
	for id in order:
		var p: Dictionary = players[id]
		var t := 1 if is_horde() else int(p["team"])
		if t != 1 and t != 2:
			t = 1
		if not is_horde() and int(counts[t]) >= size:
			t = 3 - t
		counts[t] = int(counts[t]) + 1
		p["team"] = t
	var seen := {1: [], 2: []}
	for id in order:
		var p: Dictionary = players[id]
		var t := int(p["team"])
		if int(p["legend"]) in (seen[t] as Array):
			for l in LegendData.PLAYABLE:
				if l not in (seen[t] as Array):
					p["legend"] = l
					break
		(seen[t] as Array).append(int(p["legend"]))


## Cambia de equipo (por equipos; en la Horda vais todos juntos). Si su leyenda ya la lleva alguien
## del equipo nuevo, se le da una libre.
func set_team(id: int, t: int) -> String:
	if not players.has(id) or (t != 1 and t != 2):
		return "Equipo no válido."
	if is_horde():
		return "En la Horda vais todos juntos."
	var p: Dictionary = players[id]
	if int(p["team"]) == t:
		return ""
	if count_team(t) >= team_size():
		return "Ese equipo ya está lleno."
	p["team"] = t
	if int(p["legend"]) in legends_in(t, id):
		p["legend"] = free_legend(t, id)
	return ""


func set_legend(id: int, legend: int) -> String:
	if not players.has(id) or legend < 0 or legend >= LegendData.PLAYABLE:
		return "Leyenda no válida."
	var p: Dictionary = players[id]
	if legend in legends_in(int(p["team"]), id):
		return "Esa leyenda ya la lleva tu compañero."
	p["legend"] = legend
	return ""


func set_ready(id: int, r: bool) -> void:
	if players.has(id):
		players[id]["ready"] = r


## Horda: plazas del equipo (solo el líder; nunca menos que los humanos que hay).
func set_horde_team(by: int, n: int) -> String:
	if by != leader:
		return "Solo el líder elige el tamaño del equipo."
	horde_team = clampi(n, maxi(players.size(), 1), HordeMode.MAX_TEAM)
	return ""


func unready_all() -> void:
	for id in players:
		players[id]["ready"] = false


## "¡Listo!": lo marcan todos menos el líder (pulsar Iniciar ya es su listo), como en el 2D.
func ready_needed() -> int:
	return players.size() - (1 if players.has(leader) else 0)


func ready_count() -> int:
	var n := 0
	for id in players:
		if int(id) != leader and bool(players[id]["ready"]):
			n += 1
	return n


func all_ready() -> bool:
	return ready_count() >= ready_needed()


## ¿Puede empezar `by`? "" si sí; si no, el motivo para enseñárselo.
func can_start(by: int) -> String:
	if by != leader:
		return "Solo el líder puede iniciar."
	if players.is_empty():
		return "No hay nadie en la sala."
	if not all_ready():
		return "Faltan jugadores por marcar ¡Listo! (%d/%d)." % [ready_count(), ready_needed()]
	return ""


## Reparto al empezar, en el orden en que se crearán las leyendas: equipo 1 y luego equipo 2; en
## cada uno, los humanos por orden de llegada y después los bots. Los bots cogen leyendas que su
## equipo no lleve, barajadas con la semilla de la partida: todos los aparatos sacan el mismo reparto.
func roster(seed: int) -> Array:
	var r := RandomNumberGenerator.new()
	r.seed = seed
	var out: Array = []
	var teams := [1] if is_horde() else [1, 2]
	for t: int in teams:
		var used: Array = []
		for id in order:
			var p: Dictionary = players[id]
			if int(p["team"]) == t:
				out.append({"team": t, "legend": int(p["legend"]), "peer": int(id), "name": String(p["name"])})
				used.append(int(p["legend"]))
		var free: Array = []
		for l in LegendData.PLAYABLE:
			if l not in used:
				free.append(l)
		for i in range(free.size() - 1, 0, -1):
			var j := r.randi_range(0, i)
			var tmp: int = free[i]
			free[i] = free[j]
			free[j] = tmp
		for k in team_size() - count_team(t):
			var leg: int = int(free[k % free.size()]) if not free.is_empty() else 0
			out.append({"team": t, "legend": leg, "peer": 0, "name": String(LegendData.LEGENDS[leg]["name"])})
	return out


## Para mandarla por la red y pintarla en los clientes (copias, no referencias).
func to_dict() -> Dictionary:
	return {"players": players.duplicate(true), "order": order.duplicate(), "mode": mode,
		"horde_team": horde_team, "leader": leader}


func from_dict(d: Dictionary) -> void:
	players = (d.get("players", {}) as Dictionary).duplicate(true)
	order = (d.get("order", []) as Array).duplicate()
	mode = String(d.get("mode", "2v2"))
	horde_team = int(d.get("horde_team", HordeMode.MAX_TEAM))
	leader = int(d.get("leader", 0))
```

- [ ] **Step 4: Ver que pasa**

Run: `godot --headless --path . --import >/dev/null 2>&1; godot --headless --path . -s tests/test_lobby_rules.gd 2>&1 | grep -E "FALLO|SCRIPT ERROR|^test_"`
Expected: `test_lobby_rules: OK (0 fallos)`.

- [ ] **Step 5: Punto de control** — `tools/check.sh tests` → todas las `test_*` en ✓.

---

### Task 3: `UiKit` (etiqueta y botón compartidos), sin cambiar el menú

**Files:**
- Create: `ui/ui_kit.gd`
- Modify: `ui/mode_menu.gd` (cuerpos de `_label` y `_button`)

**Interfaces:**
- Produces: `UiKit.label(sz: int, c: Color) -> Label`,
  `UiKit.button(text: String, min_size: Vector2, sz: int, base := Color(0.16, 0.18, 0.26)) -> Button`,
  `UiKit.GOLD`.

- [ ] **Step 1: Captura de referencia del menú (antes)**

Run: `godot --path . --resolution 1280x720 --fixed-fps 60 -- --mode=menu --shot=/tmp/menu_antes.png --wait=60`
Expected: `captura: /tmp/menu_antes.png`.

- [ ] **Step 2: Crear `ui/ui_kit.gd`**

```gdscript
## Piezas de UI de los menús construidos en código (menú de inicio y sala en línea): etiqueta con
## contorno y botón redondeado, de 64 px o más para el dedo. Son las de ModeMenu, sacadas aquí al
## añadir la sala (2026-09-18) para no copiarlas.
class_name UiKit
extends RefCounted

const GOLD := Color(1.0, 0.82, 0.38)


static func label(sz: int, c: Color) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", sz)
	l.add_theme_color_override("font_color", c)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 5)
	return l


static func button(text: String, min_size: Vector2, sz: int, base := Color(0.16, 0.18, 0.26)) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = min_size
	b.add_theme_font_size_override("font_size", sz)
	for st in [["normal", base], ["hover", base.lightened(0.18)], ["pressed", GOLD.darkened(0.45)],
			["focus", base.lightened(0.1)]]:
		var s := StyleBoxFlat.new()
		s.bg_color = st[1]
		s.set_corner_radius_all(12)
		s.border_color = GOLD if st[0] == "pressed" else Color(1, 1, 1, 0.08)
		s.set_border_width_all(2)
		b.add_theme_stylebox_override(st[0], s)
	b.add_theme_color_override("font_pressed_color", Color.WHITE)
	return b
```

- [ ] **Step 3: El menú los usa**

En `ui/mode_menu.gd`, sustituir los cuerpos de `_label` y `_button` (las firmas no cambian):

```gdscript
func _label(sz: int, c: Color) -> Label:
	return UiKit.label(sz, c)


func _button(text: String, min_size: Vector2, sz: int, base := Color(0.16, 0.18, 0.26)) -> Button:
	return UiKit.button(text, min_size, sz, base)
```

- [ ] **Step 4: El menú sale idéntico**

Run:
```bash
godot --headless --path . --import >/dev/null 2>&1
godot --path . --resolution 1280x720 --fixed-fps 60 -- --mode=menu --shot=/tmp/menu_despues.png --wait=60
python3 -c "from PIL import Image, ImageChops; a=Image.open('/tmp/menu_antes.png').convert('RGB'); b=Image.open('/tmp/menu_despues.png').convert('RGB'); print('distintos:', ImageChops.difference(a,b).getbbox())"
```
Expected: `distintos: None` (ningún píxel distinto). Si sale una caja pequeña, mirar las dos
capturas: si solo cambia alguna partícula del fondo (no siempre son deterministas) y el panel se ve
igual, vale; si cambia el panel, el cambio no es neutro y hay que revisarlo.

- [ ] **Step 5: Punto de control** — `tools/check.sh parse ui/ui_kit.gd ui/mode_menu.gd` → `RESULTADO: OK`.

---

### Task 4: Autoload `Net` y servidor `--server`

**Files:**
- Create: `net/net.gd`
- Modify: `project.godot` (sección `[autoload]`), `main.gd` (`_ready`, tras `_collect_args()`)

**Interfaces:**
- Consumes: `NetAddress`, `Identity`, `LobbyRules` (Tasks 1-2), `Main.new_seed() -> int`.
- Produces (autoload `Net`, sin `class_name`):
  - Señales: `lobby_ready`, `lobby_changed`, `lobby_message(text: String)`,
    `match_started(mode: String, seed: int, roster: Array)`, `left(reason: String)`
  - `var cmdline: Dictionary`, `var lobby: LobbyRules`, `var player_name: String`,
    `var last_error: String`, `var dedicated: bool`
  - `server_address() -> String`, `join(address: String) -> Error`, `leave(reason := "") -> void`,
    `in_lobby() -> bool`, `my_id() -> int`, `is_leader() -> bool`, `remember_name(n: String) -> void`
  - `request_mode(m: String)`, `request_team(t: int)`, `request_legend(l: int)`,
    `request_horde_team(n: int)`, `request_lobby_ready(r: bool)`, `request_start()`
  - Traza en consola: `[RED] servidor escuchando en el puerto N (ws)`, `[RED] entra <nombre>`,
    `[RED] en la sala: …` (cliente), `[RED] empieza <modo> · semilla N · M plazas` (servidor)

- [ ] **Step 1: Prueba de humo del servidor (falla)**

Run:
```bash
perl -e 'alarm 20; exec @ARGV' godot --headless --path . -- --server --transport=ws --port=17799 > /tmp/srv.log 2>&1; grep -E "servidor escuchando|SCRIPT ERROR" /tmp/srv.log
```
Expected: nada (aún no hay servidor; `main.gd` monta una Horda).

- [ ] **Step 2: Crear `net/net.gd`**

```gdscript
## Autoload "Net": conexión con el servidor, la sala y el arranque de partida del juego en línea
## (fase 1: docs/superpowers/specs/2026-09-18-juego-en-linea-design.md). El servidor (peer 1) es la
## única autoridad: aplica LobbyRules y manda el estado de la sala a todos; los clientes solo piden.
## Portado de scripts/net.gd del 2D (conexión, registro con versión del protocolo, búferes del
## WebSocket), sin perfiles, tienda ni reconexión.
##   Servidor:  godot --headless --path . -- --server [--transport=ws] [--port=N]
##   Cliente:   el menú ("EN LÍNEA"); --client=ws://ip:puerto para un servidor local.
## Sin conexión no hace nada: las partidas de siempre no pasan por aquí.
extends Node

const DEFAULT_PORT := 7777
## Servidor de "EN LÍNEA": el mismo dominio que tenía el 2D en Railway (decisión del usuario,
## 2026-09-18). Los APK del 2D se quedan sin servidor al cambiar el servicio.
const DEFAULT_SERVER := "wss://fallen-legends-production.up.railway.app"
## Versión del protocolo: sube con cada cambio de mensajes. Empieza en 100 para no coincidir con el
## 2D (va por 3): un cliente del 2D que llegue aquí es rechazado o no se registra, y su menú lo dice.
const PROTOCOL := 100
## Búferes y saludo del WebSocket, como el 2D (2026-09-14): con los 64 KB de serie, un atasco de un
## segundo en el móvil desbordaba la salida y se caía la conexión.
const WS_OUTBOUND_BUFFER := 1048576
const WS_INBOUND_BUFFER := 262144
const WS_HANDSHAKE_TIMEOUT := 10.0
## Si el servidor no nos registra en este tiempo, no nos entiende (otra versión o servidor viejo).
const REGISTER_TIMEOUT := 12.0

signal lobby_ready                     # registrado: ya se puede enseñar la sala
signal lobby_changed                   # llegó un estado nuevo de la sala
signal lobby_message(text: String)     # aviso del servidor para este jugador
signal match_started(mode: String, seed: int, roster: Array)
signal left(reason: String)            # fuera de la sala (salir, rechazo o conexión perdida)

var cmdline := {}
var port := DEFAULT_PORT
var transport := NetAddress.ENET
var dedicated := false
var player_name := Identity.DEFAULT_NAME
var player_id := ""
var protocol := PROTOCOL               # --protocol=N (solo pruebas): fingir otra versión
var lobby := LobbyRules.new()          # en el servidor, la de verdad; en el cliente, la copia recibida
var last_error := ""                   # por qué se salió: el menú lo enseña
var _pids := {}                        # servidor: peer -> id de dispositivo (no se difunde nunca)
var _register_t := 0.0
var _registered := false


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		var kv := String(a).split("=", true, 1)
		cmdline[kv[0].lstrip("-")] = kv[1] if kv.size() > 1 else "1"
	# --identity=ruta: identidad propia (varias instancias en la misma máquina, pruebas).
	if cmdline.has("identity"):
		Identity.PATH = String(cmdline["identity"])
	var ident := Identity.load_or_create()
	player_id = String(ident["id"])
	player_name = String(ident["name"])
	if cmdline.has("name"):
		player_name = Identity.sanitize_name(String(cmdline["name"]))
	if String(cmdline.get("protocol", "")).is_valid_int():
		protocol = int(cmdline["protocol"])
	if String(cmdline.get("port", "")).is_valid_int():
		port = int(cmdline["port"])
	# Railway da el puerto en PORT y solo enruta TCP: ahí el WebSocket es obligatorio.
	var paas := OS.get_environment("PORT").is_valid_int()
	if paas and not cmdline.has("port"):
		port = int(OS.get_environment("PORT"))
	if String(cmdline.get("transport", NetAddress.WS if paas else NetAddress.ENET)) == NetAddress.WS:
		transport = NetAddress.WS
	multiplayer.connected_to_server.connect(_on_connected)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	if cmdline.has("server"):
		# Sin tope, un servidor sin pantalla da vueltas al bucle al 100 % de CPU (y Railway lo cobra).
		Engine.max_fps = 60
		var err := host()
		print("[RED] servidor escuchando en el puerto %d (%s)%s" % [port, transport,
			"" if err == OK else " · ERROR %d" % err])
		if err != OK:
			get_tree().quit(1)
	# --netprobe=nombre: sonda de red; vive aquí para sobrevivir a los cambios de escena.
	if cmdline.has("netprobe"):
		var probe := load("res://tests/%s.gd" % String(cmdline["netprobe"])) as Script
		if probe != null:
			add_child(probe.new())


func host() -> Error:
	var peer: MultiplayerPeer
	var err := OK
	if transport == NetAddress.WS:
		var ws := WebSocketMultiplayerPeer.new()
		_tune_ws(ws)
		err = ws.create_server(port)
		peer = ws
	else:
		var enet := ENetMultiplayerPeer.new()
		err = enet.create_server(port, LobbyRules.MAX_PLAYERS)
		peer = enet
	if err != OK:
		return err
	multiplayer.multiplayer_peer = peer
	dedicated = true
	lobby = LobbyRules.new()
	_pids.clear()
	return OK


## Dirección del servidor: --client=... (pruebas y servidores locales) o el de Railway.
func server_address() -> String:
	return String(cmdline.get("client", DEFAULT_SERVER))


## Conecta ("wss://dominio", "ws://ip:puerto", "ip" o "ip:puerto"; ver NetAddress).
func join(address: String) -> Error:
	last_error = ""
	var addr := NetAddress.parse(address, port)
	var err := OK
	if String(addr["transport"]) == NetAddress.WS:
		var ws := WebSocketMultiplayerPeer.new()
		_tune_ws(ws)
		err = ws.create_client(String(addr["url"]))
		if err == OK:
			multiplayer.multiplayer_peer = ws
	else:
		var enet := ENetMultiplayerPeer.new()
		var host_name := String(addr["host"])
		if not host_name.is_valid_ip_address():
			var resolved := IP.resolve_hostname(host_name)
			if resolved != "":
				host_name = resolved
		err = enet.create_client(host_name, int(addr["port"]))
		if err == OK:
			multiplayer.multiplayer_peer = enet
	print("[RED] conectando con %s%s" % [address, "" if err == OK else " · ERROR %d" % err])
	return err


## Sale de la sala: botón Salir (sin motivo), rechazo del servidor o conexión perdida.
func leave(reason := "") -> void:
	last_error = reason
	multiplayer.multiplayer_peer = null
	lobby = LobbyRules.new()
	_registered = false
	_register_t = 0.0
	left.emit(reason)


func in_lobby() -> bool:
	return _registered


func my_id() -> int:
	return multiplayer.get_unique_id()


func is_leader() -> bool:
	return _registered and lobby.leader == my_id()


func remember_name(n: String) -> void:
	player_name = Identity.sanitize_name(n)
	Identity.save(player_id, player_name)


func _tune_ws(ws: WebSocketMultiplayerPeer) -> void:
	ws.outbound_buffer_size = WS_OUTBOUND_BUFFER
	ws.inbound_buffer_size = WS_INBOUND_BUFFER
	ws.handshake_timeout = WS_HANDSHAKE_TIMEOUT


func _on_connected() -> void:
	_register_t = REGISTER_TIMEOUT
	print("[RED] conectado; me registro como %s" % player_name)
	_register.rpc_id(1, player_name, player_id, protocol)


func _on_connection_failed() -> void:
	leave("No se pudo conectar con el servidor.")


func _on_server_disconnected() -> void:
	leave("Se perdió la conexión con el servidor.")


func _on_peer_disconnected(id: int) -> void:
	if not multiplayer.is_server():
		return
	var who: Dictionary = lobby.players.get(id, {})
	print("[RED] se va %s" % String(who.get("name", "un peer sin registrar")))
	lobby.remove(id)
	_pids.erase(id)
	_broadcast_lobby.call_deferred()


func _process(delta: float) -> void:
	if _register_t > 0.0:
		_register_t -= delta
		if _register_t <= 0.0 and not _registered:
			leave("Ese servidor no respondió al registro: seguramente tiene otra versión del juego.")


# ---------------------------------------------------------------- servidor: registro y sala

@rpc("any_peer", "reliable")
func _register(pname: String, pid: String, version: int) -> void:
	if not multiplayer.is_server():
		return
	var id := multiplayer.get_remote_sender_id()
	if version != PROTOCOL:
		print("[RED] rechazo a %s: protocolo %d (el mío %d)" % [pname, version, PROTOCOL])
		_kick.rpc_id(id, "El servidor tiene otra versión del juego (protocolo %d; el tuyo %d). Actualiza la app." % [PROTOCOL, version])
		return
	var taken: Array = []
	for other in lobby.players:
		taken.append(String(lobby.players[other]["name"]))
	var nick := Identity.unique_name(Identity.sanitize_name(pname), taken)
	if lobby.add(id, nick).is_empty():
		_kick.rpc_id(id, "La sala está llena para este modo.")
		return
	_pids[id] = pid.to_lower() if Identity.is_valid_id(pid) else Identity.new_id()
	print("[RED] entra %s (peer %d)%s" % [nick, id, " · líder" if lobby.leader == id else ""])
	_broadcast_lobby()


func _broadcast_lobby() -> void:
	_lobby_state.rpc(lobby.to_dict())


## Estado de la sala (servidor -> todos). La primera vez que me incluye, estoy dentro.
@rpc("authority", "reliable", "call_local")
func _lobby_state(d: Dictionary) -> void:
	lobby.from_dict(d)
	if not _registered and not multiplayer.is_server() and lobby.players.has(my_id()):
		_registered = true
		_register_t = 0.0
		print("[RED] en la sala: %d jugador(es), modo %s" % [lobby.players.size(), lobby.mode])
		lobby_ready.emit()
	lobby_changed.emit()


@rpc("authority", "reliable", "call_local")
func _notify(text: String) -> void:
	lobby_message.emit(text)


@rpc("authority", "reliable")
func _kick(reason: String) -> void:
	print("[RED] el servidor nos rechaza: %s" % reason)
	leave(reason)


# ---------------------------------------------------------------- peticiones (cliente -> servidor)

func request_mode(m: String) -> void:
	_request_mode.rpc_id(1, m)


func request_team(t: int) -> void:
	_request_team.rpc_id(1, t)


func request_legend(l: int) -> void:
	_request_legend.rpc_id(1, l)


func request_horde_team(n: int) -> void:
	_request_horde_team.rpc_id(1, n)


## "¡Listo!". No se llama request_ready: Node ya tiene uno.
func request_lobby_ready(r: bool) -> void:
	_request_ready.rpc_id(1, r)


func request_start() -> void:
	_request_start.rpc_id(1)


@rpc("any_peer", "reliable")
func _request_mode(m: String) -> void:
	if multiplayer.is_server():
		_apply(lobby.set_mode(multiplayer.get_remote_sender_id(), m))


@rpc("any_peer", "reliable")
func _request_team(t: int) -> void:
	if multiplayer.is_server():
		_apply(lobby.set_team(multiplayer.get_remote_sender_id(), t))


@rpc("any_peer", "reliable")
func _request_legend(l: int) -> void:
	if multiplayer.is_server():
		_apply(lobby.set_legend(multiplayer.get_remote_sender_id(), l))


@rpc("any_peer", "reliable")
func _request_horde_team(n: int) -> void:
	if multiplayer.is_server():
		_apply(lobby.set_horde_team(multiplayer.get_remote_sender_id(), n))


@rpc("any_peer", "reliable")
func _request_ready(r: bool) -> void:
	if multiplayer.is_server():
		lobby.set_ready(multiplayer.get_remote_sender_id(), r)
		_broadcast_lobby()


## El líder inicia: semilla nueva, reparto de plazas (humanos y bots) y aviso a todos. En la fase 1
## la partida en red aún no existe: todos siguen en la sala, sin el listo.
@rpc("any_peer", "reliable")
func _request_start() -> void:
	if not multiplayer.is_server():
		return
	var by := multiplayer.get_remote_sender_id()
	var err := lobby.can_start(by)
	if err != "":
		_notify.rpc_id(by, err)
		return
	var match_seed := Main.new_seed()
	var roster := lobby.roster(match_seed)
	lobby.unready_all()
	print("[RED] empieza %s · semilla %d · %d plazas" % [lobby.mode, match_seed, roster.size()])
	_broadcast_lobby()
	_start_match.rpc(lobby.mode, match_seed, roster)


@rpc("authority", "reliable", "call_local")
func _start_match(m: String, match_seed: int, roster: Array) -> void:
	match_started.emit(m, match_seed, roster)


## Resultado de una regla: si falló, se lo dice solo a quien pidió; y siempre manda el estado (así
## también vuelve a su sitio quien pidió algo imposible).
func _apply(err: String) -> void:
	if err != "":
		_notify.rpc_id(multiplayer.get_remote_sender_id(), err)
	_broadcast_lobby()
```

- [ ] **Step 3: Registrar el autoload**

En `project.godot`, antes de la línea `[display]`, añadir:

```ini
[autoload]

Net="*res://net/net.gd"

```

- [ ] **Step 4: `main.gd` no monta nada en el servidor**

En `main.gd`, en `_ready()`, justo después de `_collect_args()`:

```gdscript
	# Servidor dedicado del juego en línea (fase 1): no monta mapa, cámara ni HUD; la sala la lleva
	# el autoload Net. En la fase 2 montará aquí la partida en línea.
	if _args.has("server"):
		set_process(false)
		set_physics_process(false)
		set_process_input(false)
		set_process_unhandled_input(false)
		return
```

- [ ] **Step 5: El servidor arranca**

Run:
```bash
godot --headless --path . --import >/dev/null 2>&1
perl -e 'alarm 15; exec @ARGV' godot --headless --path . -- --server --transport=ws --port=17799 > /tmp/srv.log 2>&1; grep -E "servidor escuchando|SCRIPT ERROR|ERROR" /tmp/srv.log | grep -v "leaked\|resources still"
wc -l main.gd
```
Expected: `[RED] servidor escuchando en el puerto 17799 (ws)`, ningún `SCRIPT ERROR`; `main.gd` en 2.895 líneas.

- [ ] **Step 6: Sin conexión no cambia nada**

Run: `tools/check.sh smoke` y `tools/check.sh tests`
Expected: `✓ humo` y todas las pruebas en ✓ (el autoload no hace nada sin `--server` ni `--netprobe`).

- [ ] **Step 7: Punto de control** — `tools/check.sh parse net/net.gd main.gd` → `RESULTADO: OK`.

---

### Task 5: Prueba con varios procesos (falla hasta que exista la sala)

**Files:**
- Create: `tests/lobby_probe.gd`, `tools/net_check.sh`
- Modify: `tools/check.sh` (paso `net`)

**Interfaces:**
- Consumes: autoload `Net` (Task 4); `ModeMenu.play_online()` y la clase `Lobby` (Task 6: aquí
  todavía no existen, por eso falla).
- Produces: `tools/net_check.sh` (sale con 0 si todo va bien); `tools/check.sh net`.
- Flags de la sonda: `--want-mode=M`, `--want-legend=N`, `--want-team=T`, `--expect=N`
  (jugadores que espera el líder antes de iniciar), `--expect-kick`, `--hold` (no inicia ni sale:
  para capturas), `--secs=N` (60 por defecto).

- [ ] **Step 1: Crear `tests/lobby_probe.gd`**

```gdscript
## Sonda de la sala en línea (fase 1 del juego en línea). Un cliente sin pantalla que entra por el
## menú (pulsa "EN LÍNEA", como un jugador), elige leyenda y equipo y se pone listo; si es el líder,
## cambia al modo pedido y, cuando están todos (--expect) y listos, inicia. Comprueba que la sala
## (Lobby) enseña a cada jugador y que llega el arranque con el reparto completo, sin leyendas
## repetidas dentro de un equipo. Con --expect-kick comprueba lo contrario: que el servidor lo echa
## (otra versión del protocolo). La lanza tools/net_check.sh con un servidor y varios clientes:
##   godot --headless --path . -- --mode=menu --client=ws://127.0.0.1:17777 --name=Ana \
##     --netprobe=lobby_probe --want-mode=3v3 --want-legend=0 --want-team=1 --expect=2
## La carga el autoload Net (--netprobe), así que su padre es Net.
extends Node

var net: Node
var _t := 0.0
var _secs := 60.0
var _pressed := false
var _asked := false
var _done := false
var _requests := 0


func _ready() -> void:
	net = get_parent()
	_secs = float(net.cmdline.get("secs", "60"))
	net.lobby_changed.connect(_on_lobby_changed)
	net.match_started.connect(_on_match_started)
	net.left.connect(_on_left)


func _process(delta: float) -> void:
	_t += delta
	if _t > _secs and not _done:
		if net.cmdline.has("hold"):
			get_tree().quit(0)
		else:
			_finish(["no terminó en %.0f s (en la sala: %s)" % [_secs, str(net.in_lobby())]])
		return
	# Entra por el menú, como un jugador: busca el ModeMenu y pulsa "EN LÍNEA".
	if not _pressed:
		for n in get_tree().root.find_children("*", "Control", true, false):
			if n is ModeMenu:
				_pressed = true
				(n as ModeMenu).play_online()
				break


func _on_lobby_changed() -> void:
	if not net.in_lobby() or net.cmdline.has("expect-kick") or _done:
		return
	var s: LobbyRules = net.lobby
	var mine: Dictionary = s.players.get(net.my_id(), {})
	if mine.is_empty():
		return
	_requests += 1
	if _requests > 40:
		_finish(["la sala no llega al estado pedido tras 40 cambios"])
		return
	var want_mode := String(net.cmdline.get("want-mode", s.mode))
	var want_team := int(net.cmdline.get("want-team", mine["team"]))
	var want_legend := int(net.cmdline.get("want-legend", mine["legend"]))
	if net.is_leader() and s.mode != want_mode:
		net.request_mode(want_mode)
		return
	if s.mode != want_mode:
		return                          # espera a que el líder ponga el modo
	if not s.is_horde() and int(mine["team"]) != want_team:
		net.request_team(want_team)
		return
	if int(mine["legend"]) != want_legend:
		net.request_legend(want_legend)
		return
	if net.cmdline.has("hold"):
		if not net.is_leader() and not bool(mine["ready"]):
			net.request_lobby_ready(true)
		return
	if net.is_leader():
		if s.players.size() >= int(net.cmdline.get("expect", "1")) and s.all_ready() and not _asked:
			_asked = true
			net.request_start()
	elif not bool(mine["ready"]):
		net.request_lobby_ready(true)


func _on_match_started(mode: String, seed_value: int, roster: Array) -> void:
	if _done:
		return
	var s: LobbyRules = net.lobby
	var problems: Array = []
	var want_mode := String(net.cmdline.get("want-mode", mode))
	if mode != want_mode:
		problems.append("empezó %s y se pidió %s" % [mode, want_mode])
	var cap := s.team_size() * (1 if s.is_horde() else 2)
	if roster.size() != cap:
		problems.append("reparto de %d plazas para %s (deberían ser %d)" % [roster.size(), mode, cap])
	var me_seen := false
	for t in [1, 2]:
		var seen := {}
		for slot: Dictionary in roster:
			if int(slot["team"]) != t:
				continue
			if seen.has(int(slot["legend"])):
				problems.append("el equipo %d repite %s" % [t, String(LegendData.LEGENDS[int(slot["legend"])]["name"])])
			seen[int(slot["legend"])] = true
			if int(slot["peer"]) == net.my_id():
				me_seen = true
				if net.cmdline.has("want-legend") and int(slot["legend"]) != int(net.cmdline["want-legend"]):
					problems.append("salgo con otra leyenda (%d)" % int(slot["legend"]))
	if not me_seen:
		problems.append("no estoy en el reparto")
	# La sala enseña a todos los jugadores (petición del usuario: "donde puedes ver a tu equipo").
	var texts := _lobby_texts()
	if texts.is_empty():
		problems.append("no hay sala (Lobby) en pantalla")
	for id in s.players:
		var nm := String(s.players[id]["name"])
		if nm not in texts:
			problems.append("la sala no enseña a %s" % nm)
	print("[RED] partida iniciada: %s · semilla %d · reparto %s" % [mode, seed_value, _describe(roster)])
	_finish(problems)


func _on_left(reason: String) -> void:
	if _done:
		return
	if net.cmdline.has("expect-kick"):
		if reason.contains("versión"):
			print("[RED] rechazado como se esperaba: %s" % reason)
			_finish([])
		else:
			_finish(["me echaron por otra cosa: %s" % reason])
		return
	_finish(["salí de la sala: %s" % reason])


## Todos los textos de las etiquetas de la sala en pantalla.
func _lobby_texts() -> Array:
	var out: Array = []
	for n in get_tree().root.find_children("*", "Control", true, false):
		if n is Lobby:
			for l in (n as Node).find_children("*", "Label", true, false):
				out.append((l as Label).text)
	return out


func _describe(roster: Array) -> String:
	var parts: Array = []
	for slot: Dictionary in roster:
		parts.append("%s(%d, %s)" % ["bot" if int(slot["peer"]) == 0 else String(slot["name"]), int(slot["team"]),
			String(LegendData.LEGENDS[int(slot["legend"])]["name"])])
	return ", ".join(parts)


func _finish(problems: Array) -> void:
	_done = true
	for p in problems:
		print("[RED] problema: %s" % p)
	print("lobby_probe: %s" % ("OK" if problems.is_empty() else "FALLO"))
	get_tree().quit(0 if problems.is_empty() else 1)
```

- [ ] **Step 2: Crear `tools/net_check.sh`** (y `chmod +x tools/net_check.sh`)

```bash
#!/usr/bin/env bash
# Prueba de la sala en línea con varios procesos (fase 1 del juego en línea,
# docs/superpowers/specs/2026-09-18-juego-en-linea-design.md): un servidor sin pantalla por
# WebSocket y dos clientes sin pantalla que entran por el menú, eligen, se ponen listos y el líder
# inicia un 3v3; y un tercer cliente con otra versión del protocolo, que el servidor tiene que echar.
#   tools/net_check.sh            # sale con 0 si todo va bien (lo llama tools/check.sh)
set -uo pipefail
cd "$(dirname "$0")/.."
GODOT="${GODOT:-godot}"
PORT="${NET_PORT:-17777}"
with_timeout() { perl -e 'alarm shift; exec @ARGV' "$@"; }
tmp="$(mktemp -d)"
fail=0

with_timeout 240 "$GODOT" --headless --path . -- --server --transport=ws --port="$PORT" \
  --identity="$tmp/servidor.json" >"$tmp/servidor.log" 2>&1 &
server=$!
for _ in $(seq 1 60); do grep -q "servidor escuchando" "$tmp/servidor.log" 2>/dev/null && break; sleep 0.5; done
if ! grep -q "servidor escuchando en el puerto $PORT" "$tmp/servidor.log"; then
  echo "✗ el servidor no arrancó"; tail -20 "$tmp/servidor.log" | sed 's/^/    /'
  kill "$server" 2>/dev/null; rm -rf "$tmp"; exit 1
fi

client() {  # nombre y flags de la sonda
  local name="$1"; shift
  with_timeout 150 "$GODOT" --headless --path . -- --mode=menu --nodecor --client="ws://127.0.0.1:$PORT" \
    --name="$name" --identity="$tmp/$name.json" --netprobe=lobby_probe "$@" >"$tmp/$name.log" 2>&1
}

client Ana --want-mode=3v3 --want-legend=0 --want-team=1 --expect=2 &
ana=$!
# Ana llega primero, así que es la líder: Beto entra cuando ella ya está en la sala.
for _ in $(seq 1 120); do grep -q "\[RED\] en la sala" "$tmp/Ana.log" 2>/dev/null && break; sleep 0.5; done
client Beto --want-mode=3v3 --want-legend=3 --want-team=2 &
beto=$!
wait "$ana"; ca=$?
wait "$beto"; cb=$?
client Viejo --protocol=99 --expect-kick
cv=$?
kill "$server" 2>/dev/null; wait "$server" 2>/dev/null

for who in "Ana:$ca" "Beto:$cb" "Viejo:$cv"; do
  n="${who%%:*}"; code="${who##*:}"
  grep -E "^\[RED\]|^lobby_probe" "$tmp/$n.log" | tail -4 | sed "s/^/    $n: /"
  if [ "$code" -ne 0 ] || ! grep -q "^lobby_probe: OK" "$tmp/$n.log" || grep -q "SCRIPT ERROR" "$tmp/$n.log"; then
    echo "✗ cliente $n (salida $code)"
    grep -A3 "SCRIPT ERROR" "$tmp/$n.log" | head -20 | sed 's/^/    /'
    fail=1
  else
    echo "✓ cliente $n"
  fi
done
grep -E "^\[RED\]" "$tmp/servidor.log" | tail -8 | sed 's/^/    servidor: /'
if grep -q "SCRIPT ERROR" "$tmp/servidor.log"; then
  echo "✗ servidor con errores"; grep -A3 "SCRIPT ERROR" "$tmp/servidor.log" | head -20 | sed 's/^/    /'; fail=1
fi
rm -rf "$tmp"
exit $fail
```

- [ ] **Step 3: Engancharla a `tools/check.sh`**

Añadir antes de la línea `case "${1:-all}" in`:

```bash
do_net() {
  echo "== Red: la sala en línea (servidor y clientes sin pantalla, tools/net_check.sh)"
  tools/net_check.sh || fail=1
}

```

y en el `case`: añadir `  net) do_net ;;`, cambiar `all)   do_parse; do_tests; do_smoke; do_probes ;;` por
`all)   do_parse; do_tests; do_smoke; do_probes; do_net ;;` y el mensaje de uso a
`Uso: $0 [all|parse [script...]|tests|smoke|probes|net]`. En la cabecera del fichero, añadir la línea
`#   tools/check.sh net             # solo la sala en línea (servidor y clientes, tools/net_check.sh)`.

- [ ] **Step 4: Ver que falla**

Run: `tools/check.sh net`
Expected: `✗ cliente Ana` (`SCRIPT ERROR` por `ModeMenu.play_online` / `Lobby` inexistentes, o
`no terminó en 60 s`) y `RESULTADO: FALLO`.

---

### Task 6: La sala (`Lobby`) y "EN LÍNEA" en el menú

**Files:**
- Create: `ui/lobby.gd`
- Modify: `ui/mode_menu.gd` (variables, fila de JUGAR, `play_online` y sus respuestas)

**Interfaces:**
- Consumes: `Net` (Task 4), `LobbyRules` (Task 2), `UiKit` (Task 3), `GameModes.short_name` (añadida
  durante la ejecución: "1VS1"…"4VS4"), `GameModes.ORDER/MODES`,
  `HordeMode.MAX_TEAM`, `LegendData.LEGENDS/PLAYABLE`.
- Produces: clase `Lobby` (`extends Control`); `ModeMenu.play_online() -> void`.

- [ ] **Step 1: Crear `ui/lobby.gd`**

```gdscript
## La sala del juego en línea (fase 1: docs/superpowers/specs/2026-09-18-juego-en-linea-design.md),
## portada de scripts/lobby.gd del 2D a petición del usuario (2026-09-18: "tráete la sala que
## manejamos en el proyecto 2D donde puedes ver a tu equipo en un lobby"). Los equipos en columnas
## con cada jugador, su leyenda y si está listo, más los huecos que llenarán los bots; tu leyenda y
## tu equipo; el líder elige el modo (y en la Horda cuántos sois) e inicia cuando todos están
## listos. Todo lo decide el servidor: aquí solo se pide (Net.request_*) y se pinta Net.lobby.
class_name Lobby
extends Control

const GOLD := UiKit.GOLD
const TEAM_COL := {1: Color(0.45, 0.7, 1.0), 2: Color(1.0, 0.45, 0.4)}
const READY_COL := Color(0.45, 1.0, 0.55)
const WAIT_COL := Color(0.62, 0.6, 0.55)
const BOT_COL := Color(0.55, 0.57, 0.62)

var _mode_buttons := {}
var _horde_row: HBoxContainer
var _horde_buttons := {}
var _team_row: HBoxContainer
var _legend_label: Label
var _columns: HBoxContainer
var _ready_button: Button
var _start_button: Button
var _status: Label


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var veil := ColorRect.new()
	veil.color = Color(0.02, 0.03, 0.06, 0.5)
	veil.set_anchors_preset(Control.PRESET_FULL_RECT)
	veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(veil)
	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.04, 0.05, 0.09, 0.9)
	sb.set_corner_radius_all(20)
	sb.content_margin_left = 30
	sb.content_margin_right = 30
	sb.content_margin_top = 20
	sb.content_margin_bottom = 22
	panel.add_theme_stylebox_override("panel", sb)
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	panel.custom_minimum_size = Vector2(900, 0)
	add_child(panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	panel.add_child(col)

	var title := UiKit.label(40, GOLD)
	title.text = "SALA EN LÍNEA"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(title)

	# Modo (solo el líder).
	var modes := HBoxContainer.new()
	modes.alignment = BoxContainer.ALIGNMENT_CENTER
	modes.add_theme_constant_override("separation", 8)
	var group := ButtonGroup.new()
	for id: String in GameModes.ORDER:
		var b := UiKit.button(GameModes.short_name(id), Vector2(120, 64), 24)
		b.toggle_mode = true
		b.button_group = group
		b.pressed.connect(_pick_mode.bind(id))
		modes.add_child(b)
		_mode_buttons[id] = b
	col.add_child(modes)

	# Horda: cuántos sois (humanos + bots; solo el líder).
	_horde_row = HBoxContainer.new()
	_horde_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_horde_row.add_theme_constant_override("separation", 8)
	var hl := UiKit.label(22, Color(0.85, 0.87, 0.95))
	hl.text = "Equipo de"
	_horde_row.add_child(hl)
	var hgroup := ButtonGroup.new()
	for n in range(1, HordeMode.MAX_TEAM + 1):
		var hb := UiKit.button(str(n), Vector2(64, 64), 26)
		hb.toggle_mode = true
		hb.button_group = hgroup
		hb.pressed.connect(_pick_horde_team.bind(n))
		_horde_row.add_child(hb)
		_horde_buttons[n] = hb
	col.add_child(_horde_row)

	# Tu leyenda y tu equipo.
	var mine := HBoxContainer.new()
	mine.alignment = BoxContainer.ALIGNMENT_CENTER
	mine.add_theme_constant_override("separation", 10)
	var prev := UiKit.button("◀", Vector2(64, 64), 28)
	prev.pressed.connect(_step_legend.bind(-1))
	mine.add_child(prev)
	_legend_label = UiKit.label(28, GOLD)
	_legend_label.custom_minimum_size = Vector2(260, 0)
	_legend_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mine.add_child(_legend_label)
	var next := UiKit.button("▶", Vector2(64, 64), 28)
	next.pressed.connect(_step_legend.bind(1))
	mine.add_child(next)
	_team_row = HBoxContainer.new()
	_team_row.add_theme_constant_override("separation", 8)
	for t: int in [1, 2]:
		var tb := UiKit.button("Azul" if t == 1 else "Rojo", Vector2(110, 64), 24, (TEAM_COL[t] as Color).darkened(0.55))
		tb.pressed.connect(_pick_team.bind(t))
		_team_row.add_child(tb)
	mine.add_child(_team_row)
	col.add_child(mine)

	# Los equipos, en columnas.
	_columns = HBoxContainer.new()
	_columns.alignment = BoxContainer.ALIGNMENT_CENTER
	_columns.add_theme_constant_override("separation", 24)
	col.add_child(_columns)

	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 14)
	var leave := UiKit.button("Salir", Vector2(160, 72), 26)
	leave.pressed.connect(_leave)
	buttons.add_child(leave)
	_ready_button = UiKit.button("¡Listo!", Vector2(240, 72), 28, Color(0.12, 0.4, 0.2))
	_ready_button.pressed.connect(_toggle_ready)
	buttons.add_child(_ready_button)
	_start_button = UiKit.button("Iniciar partida", Vector2(280, 72), 28, Color(0.55, 0.36, 0.08))
	_start_button.pressed.connect(_start)
	buttons.add_child(_start_button)
	col.add_child(buttons)

	_status = UiKit.label(18, Color(1.0, 0.8, 0.6))
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(_status)

	Net.lobby_changed.connect(_refresh)
	Net.lobby_message.connect(_on_message)
	Net.match_started.connect(_on_match_started)
	Net.left.connect(_on_left)
	_refresh()


func _refresh() -> void:
	var s: LobbyRules = Net.lobby
	var me: int = Net.my_id()
	var leader: bool = Net.is_leader()
	for id: String in _mode_buttons:
		var b: Button = _mode_buttons[id]
		b.set_pressed_no_signal(id == s.mode)
		b.disabled = not leader
	_horde_row.visible = s.is_horde()
	for n: int in _horde_buttons:
		var hb: Button = _horde_buttons[n]
		hb.set_pressed_no_signal(n == s.horde_team)
		hb.disabled = not leader or n < s.players.size()
	_team_row.visible = not s.is_horde()
	var mine: Dictionary = s.players.get(me, {})
	if not mine.is_empty():
		_legend_label.text = String(LegendData.LEGENDS[int(mine["legend"])]["name"])
	_fill_columns(s, me)
	_ready_button.visible = not leader
	_ready_button.text = "Cancelar listo" if bool(mine.get("ready", false)) else "¡Listo!"
	_start_button.visible = leader
	_start_button.disabled = not s.all_ready()


## Una columna por equipo (en la Horda, una): cada jugador con su leyenda y LÍDER, LISTO o
## esperando; después, un "Bot" por cada hueco que llenará un bot al empezar.
func _fill_columns(s: LobbyRules, me: int) -> void:
	for c in _columns.get_children():
		c.queue_free()
	var teams := [1] if s.is_horde() else [1, 2]
	for t: int in teams:
		var box := VBoxContainer.new()
		box.custom_minimum_size = Vector2(420, 0)
		box.add_theme_constant_override("separation", 6)
		var head := UiKit.label(24, TEAM_COL[t])
		head.text = "TU EQUIPO" if s.is_horde() else ("EQUIPO AZUL" if t == 1 else "EQUIPO ROJO")
		box.add_child(head)
		for id in s.order:
			var p: Dictionary = s.players[id]
			if int(p["team"]) != t:
				continue
			var state := "LÍDER" if int(id) == s.leader else ("LISTO" if bool(p["ready"]) else "esperando")
			var state_col := GOLD if int(id) == s.leader else (READY_COL if bool(p["ready"]) else WAIT_COL)
			box.add_child(_row(String(p["name"]), String(LegendData.LEGENDS[int(p["legend"])]["name"]),
				state, state_col, int(id) == me))
		for k in s.team_size() - s.count_team(t):
			box.add_child(_row("Bot", "leyenda al azar", "bot", BOT_COL, false))
		_columns.add_child(box)


func _row(who: String, legend: String, state: String, state_col: Color, me: bool) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var a := UiKit.label(22, GOLD if me else Color(0.95, 0.95, 1.0))
	a.text = who
	a.custom_minimum_size = Vector2(150, 0)
	row.add_child(a)
	var b := UiKit.label(20, Color(0.82, 0.84, 0.92))
	b.text = legend
	b.custom_minimum_size = Vector2(170, 0)
	row.add_child(b)
	var c := UiKit.label(18, state_col)
	c.text = state
	row.add_child(c)
	return row


func _pick_mode(id: String) -> void:
	Net.request_mode(id)


func _pick_horde_team(n: int) -> void:
	Net.request_horde_team(n)


func _pick_team(t: int) -> void:
	Net.request_team(t)


## La siguiente leyenda que no lleve ya un compañero.
func _step_legend(d: int) -> void:
	var s: LobbyRules = Net.lobby
	var mine: Dictionary = s.players.get(Net.my_id(), {})
	if mine.is_empty():
		return
	var taken := s.legends_in(int(mine["team"]), Net.my_id())
	var l := int(mine["legend"])
	for k in LegendData.PLAYABLE:
		l = wrapi(l + d, 0, LegendData.PLAYABLE)
		if l not in taken:
			break
	Net.request_legend(l)


func _toggle_ready() -> void:
	var mine: Dictionary = Net.lobby.players.get(Net.my_id(), {})
	Net.request_lobby_ready(not bool(mine.get("ready", false)))


func _start() -> void:
	Net.request_start()


func _leave() -> void:
	Net.leave()


func _on_message(text: String) -> void:
	_status.text = text


## En la fase 1 la partida en red aún no existe: se avisa y se sigue en la sala.
func _on_match_started(mode: String, _seed: int, roster: Array) -> void:
	_status.text = "¡%s con %d plazas! La partida en línea llega en la fase 2: de momento seguís en la sala." % [
		String(GameModes.MODES[mode]["name"]), roster.size()]


## Fuera de la sala: de vuelta al menú, que enseña el motivo (si lo hay).
func _on_left(_reason: String) -> void:
	get_parent().add_child(ModeMenu.new())
	queue_free()
```

- [ ] **Step 2: "EN LÍNEA" en el menú**

En `ui/mode_menu.gd`:

(a) Después de `var _skills: Label`, añadir:

```gdscript
var _name_edit: LineEdit
var _online_status: Label
```

(b) Sustituir el bloque de la fila de JUGAR:

```gdscript
	var play := _button("JUGAR", Vector2(340, 88), 42, Color(0.55, 0.36, 0.08))
	play.pressed.connect(_play)
	var play_row := HBoxContainer.new()
	play_row.alignment = BoxContainer.ALIGNMENT_CENTER
	play_row.add_child(play)
	col.add_child(play_row)
```

por:

```gdscript
	var play := _button("JUGAR", Vector2(300, 88), 42, Color(0.55, 0.36, 0.08))
	play.pressed.connect(_play)
	var play_row := HBoxContainer.new()
	play_row.alignment = BoxContainer.ALIGNMENT_CENTER
	play_row.add_theme_constant_override("separation", 12)
	play_row.add_child(play)
	# En línea (2026-09-18, fase 1 del juego en línea): tu nombre y a la sala del servidor.
	_name_edit = LineEdit.new()
	_name_edit.text = Net.player_name
	_name_edit.max_length = Identity.NAME_MAX
	_name_edit.placeholder_text = "Tu nombre"
	_name_edit.custom_minimum_size = Vector2(220, 88)
	_name_edit.add_theme_font_size_override("font_size", 26)
	play_row.add_child(_name_edit)
	var online := _button("EN LÍNEA", Vector2(220, 88), 32, Color(0.12, 0.32, 0.5))
	online.pressed.connect(play_online)
	play_row.add_child(online)
	col.add_child(play_row)
	_online_status = _label(18, Color(1.0, 0.75, 0.6))
	_online_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_online_status.text = Net.last_error
	_online_status.visible = Net.last_error != ""
	col.add_child(_online_status)
```

(c) Al final del fichero, añadir:

```gdscript
## "EN LÍNEA": guarda el nombre, conecta con el servidor y, cuando te mete en la sala, cambia el menú
## por la sala (Lobby) en esta misma capa.
func play_online() -> void:
	Net.remember_name(_name_edit.text)
	_name_edit.text = Net.player_name
	if not Net.lobby_ready.is_connected(_on_lobby_ready):
		Net.lobby_ready.connect(_on_lobby_ready)
		Net.left.connect(_on_left)
	_online_status.visible = true
	_online_status.text = "Conectando con el servidor…"
	if Net.join(Net.server_address()) != OK:
		_online_status.text = "No se pudo conectar."


func _on_lobby_ready() -> void:
	get_parent().add_child(Lobby.new())
	queue_free()


func _on_left(reason: String) -> void:
	_online_status.visible = true
	_online_status.text = reason if reason != "" else "Fuera de la sala."
```

- [ ] **Step 3: Ver que pasa**

Run: `godot --headless --path . --import >/dev/null 2>&1; tools/check.sh net`
Expected:
```
✓ cliente Ana
✓ cliente Beto
✓ cliente Viejo
    servidor: [RED] empieza 3v3 · semilla … · 6 plazas
RESULTADO: OK
```
y en Ana y Beto `[RED] partida iniciada: 3v3 · … reparto Ana(1, Tormentero), bot(1, …), bot(1, …), Beto(2, Caballero esqueleto), bot(2, …), bot(2, …)`.

- [ ] **Step 4: Punto de control** — `tools/check.sh parse ui/lobby.gd ui/mode_menu.gd` → `RESULTADO: OK`.

---

### Task 7: Evidencia visual (menú y sala, en móvil y escritorio)

**Files:** ninguno (capturas en `export/red/`, que Godot ignora gracias a `export/.gdignore`).

- [ ] **Step 1: El menú con "EN LÍNEA"**

Run:
```bash
mkdir -p export/red
for res in 1280x720 1600x720; do godot --path . --resolution $res -- --mode=menu --touch --shot=export/red/menu_$res.png --wait=60; done
```
Mirar las dos capturas: la fila JUGAR · nombre · EN LÍNEA cabe en el panel, nada se sale ni se
solapa, botones de 64 px o más.

- [ ] **Step 2: La sala con dos jugadores**

Run:
```bash
godot --headless --path . -- --server --transport=ws --port=17790 --identity=/tmp/s.json > /tmp/s.log 2>&1 &
sleep 4
godot --headless --path . -- --mode=menu --nodecor --client=ws://127.0.0.1:17790 --name=Beto --identity=/tmp/b.json --netprobe=lobby_probe --want-mode=3v3 --want-legend=3 --want-team=2 --hold --secs=90 > /tmp/b.log 2>&1 &
sleep 2
for res in 1280x720 1600x720; do godot --path . --resolution $res -- --mode=menu --touch --client=ws://127.0.0.1:17790 --name=Ana --identity=/tmp/a$res.json --netprobe=lobby_probe --want-mode=3v3 --want-legend=0 --want-team=1 --hold --shot=export/red/sala_$res.png --wait=400; done
kill %1 %2 2>/dev/null
```
Nota: la primera ventana que entra es la líder (Beto entra antes, así que Beto es líder en la
captura; Ana ve la sala sin los controles de líder). Mirar las capturas: dos columnas (EQUIPO
AZUL / EQUIPO ROJO) con Ana y Beto en su equipo, sus leyendas, LÍDER / LISTO / esperando y los
huecos "Bot"; nada cortado a 1280×720.

- [ ] **Step 3: Si algo no cabe**, ajustar tamaños en `ui/lobby.gd` (`custom_minimum_size` de las
  columnas o de las etiquetas) o en la fila de JUGAR de `ui/mode_menu.gd`, repetir el Step 1 o 2 y
  volver a mirar. No se da por hecho sin haber mirado las cuatro capturas.

---

### Task 8: Documentación y puerta completa

**Files:**
- Modify: `README.md`, `CLAUDE.md`

- [ ] **Step 1: README** — sección nueva `## Juego en línea (en construcción)` antes de
  `## Opciones útiles para probar`, con este contenido:

```markdown
## Juego en línea (en construcción)

Diseño y fases: `docs/superpowers/specs/2026-09-18-juego-en-linea-design.md` (petición del usuario,
2026-09-18: PvP y Horda en línea, desde el APK y el navegador, con la sala del 2D y el servidor en
Railway). **Hecho: fase 1, la sala.** En el menú, tu nombre y **EN LÍNEA** llevan a la sala del
servidor: cada equipo en su columna con sus jugadores, su leyenda y si están listos, y los huecos
que llenarán los bots. El primero en entrar es el líder: elige el modo (Horda o 1v1-4v4; en la Horda,
cuántos sois) e inicia cuando todos han marcado ¡Listo!. El servidor sortea la semilla y reparte las
plazas; **la partida en red llega en la fase 2**: de momento, al iniciar se avisa y se sigue en la sala.

- El servidor es el mismo juego sin pantalla: `godot --headless --path . -- --server --transport=ws`
  (puerto 7777, o el de la variable `PORT` en Railway). Es la única autoridad: el cliente solo pide.
- Por defecto se conecta a `wss://fallen-legends-production.up.railway.app` (el dominio que tenía
  el 2D; sus APK se quedarán sin servidor cuando el servicio pase a ser este). Para uno local:
  `godot --path . -- --client=ws://127.0.0.1:7777`.
- **En el móvil aún no conecta**: el APK sigue sin permiso de Internet hasta la fase 4.
- Protocolo `Net.PROTOCOL` = 100: un cliente con otra versión es rechazado con el motivo.
- Prueba: `tools/net_check.sh` (dentro de `tools/check.sh`) arranca un servidor y tres clientes sin
  pantalla: dos entran por el menú, eligen, se ponen listos y el líder inicia un 3v3; el tercero
  tiene otra versión y el servidor lo echa.
```

  Y en `## Opciones útiles para probar`, añadir estas líneas al bloque de flags:

```
--server        servidor dedicado del juego en línea (sin pantalla; no monta mapa)
--transport=ws  el servidor por WebSocket (en Railway sale solo: hay variable PORT)
--port=N        puerto del servidor (7777)
--client=DIR    servidor al que va EN LÍNEA (ws://ip:puerto, wss://dominio o ip:puerto)
--name=X        tu nombre en la sala (si no, el guardado)
--identity=RUTA fichero de identidad propio (varias instancias en la misma máquina)
--protocol=N    solo pruebas: fingir otra versión del protocolo
--netprobe=X    sonda de red (tests/X.gd) bajo el autoload Net; lobby_probe admite --want-mode,
                --want-legend, --want-team, --expect, --expect-kick, --hold y --secs
```

- [ ] **Step 2: CLAUDE.md**
  - En "Qué es", cambiar `Sin red por ahora.` por `Juego en línea en construcción (fase 1 hecha: la
    sala; ver docs/superpowers/specs/2026-09-18-juego-en-linea-design.md).`
  - En "Comandos", añadir:
    ```
    tools/net_check.sh                               # sala en línea: servidor y clientes sin pantalla (también en tools/check.sh)
    godot --headless --path . -- --server --transport=ws   # servidor dedicado del juego en línea
    ```
  - En "Flags de prueba", añadir `--server`, `--transport`, `--port`, `--client`, `--name`,
    `--identity`, `--protocol`, `--netprobe`.
  - En la tabla de "Arquitectura", añadir filas:
    `| net/net.gd | autoload Net | Conexión (WebSocket/ENet), registro con PROTOCOL, sala (autoridad en el servidor) y arranque; --server, --client, --netprobe |`,
    `| net/lobby_rules.gd | LobbyRules | Pura: líder, equipos, leyendas sin repetir en un equipo, listos, reparto de plazas con bots |`,
    `| ui/lobby.gd | Lobby | La sala: equipos en columnas, tu leyenda y equipo, modo (líder), listo e iniciar |`,
    `| ui/ui_kit.gd | UiKit | Etiqueta y botón compartidos por el menú y la sala |`,
    `| net/net_address.gd, net/identity.gd | NetAddress, Identity | Copiados del 2D: dirección→transporte; id de dispositivo y apodo |`.
  - En la regla 3, añadir tras "Android sin permisos de red": `(hasta la fase 4 del juego en línea,
    por decisión del usuario del 2026-09-18)`.

- [ ] **Step 3: Puerta completa**

Run: `tools/check.sh`
Expected: todo en ✓, incluido `== Red: la sala en línea` con los tres clientes, y `RESULTADO: OK`.

- [ ] **Step 4: Cierre** — contar al usuario qué hay, con las capturas de `export/red/`, y
  preguntar si quiere commit (solo si lo pide) antes del plan de la fase 2.

---

## Añadido durante la ejecución

- **Etiquetas "1VS1" … "4VS4"** (petición del usuario, 2026-09-18, a mitad del plan: "dice 2v2, debería
  decir 2VS2 ... 4VS4"): tarea extra entre la 3 y la 4 con `GameModes.short_name(mode)`, su prueba en
  `tests/test_game_modes.gd` y el menú de inicio usándola; la sala (tarea 6) también la usa. Su texto
  completo está en el espacio de trabajo del plan (`task-3b-brief.md`).
