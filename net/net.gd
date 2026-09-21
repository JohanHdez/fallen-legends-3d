## Autoload "Net": conexión con el servidor, la sala y el arranque de partida del juego en línea
## (fase 1: docs/superpowers/specs/2026-09-18-juego-en-linea-design.md). El servidor (peer 1) es la
## única autoridad: aplica LobbyRules y manda el estado de la sala a todos; los clientes solo piden.
## Portado de scripts/net.gd del 2D (conexión, registro con versión del protocolo, búferes del
## WebSocket), sin perfiles, tienda ni reconexión.
##   Servidor:  godot --headless --path . -- --server [--transport=ws] [--port=N]
##   Cliente:   el menú ("EN LÍNEA"); --client=ws://ip:puerto para un servidor local.
## Sin conexión solo lee tu identidad guardada (user://identity.json: el nombre que enseña el menú y el
## id del dispositivo); no abre ninguna conexión: las partidas de siempre no pasan por aquí.
class_name NetService
extends Node

const DEFAULT_PORT := 7777
## Servidor de "EN LÍNEA": el mismo dominio que tenía el 2D en Railway (decisión del usuario,
## 2026-09-18). Los APK del 2D se quedan sin servidor al cambiar el servicio.
const DEFAULT_SERVER := "wss://fallen-legends-production.up.railway.app"
## Versión del protocolo: sube con cada cambio de mensajes y NUNCA baja. Empezó en 100 para no
## coincidir con el 2D (va por 3). Sube a 101 en la tarea 3 (fase 2 del juego en línea): mensajes
## nuevos, `_input_frame` y `_cast`; y a 102 el 2026-09-20, cuando la foto empezó a llevar también
## tu munición y la carga de tu definitiva (NetCodec: el encabezado cambia de tamaño, así que un
## cliente de la 101 leería las fotos corridas); y a 103 el mismo día, cuando la foto empezó a llevar
## también el marcador (rondas ganadas, al mejor de cuántas y estado) y nació el aviso de baja. Un
## cliente con otra versión —del 2D o de antes de esta— es rechazado o no se registra, y su menú lo dice.
const PROTOCOL := 103
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
var server: NetServer = null           # solo en el servidor dedicado: monta y simula la partida (fase 2)
var client: NetClient = null           # solo en un cliente: pinta la partida en marcha (fase 2, tarea 4)
var _input_seq := {}                   # servidor: peer -> último número de secuencia de control aceptado
var _my_input_seq := 0                 # cliente: el tuyo, siempre creciente (nunca se repite ni baja)


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
		server = NetServer.new()
		add_child(server)
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


## El autoload "Net" desde cualquier script, tipado. Con el nombre a secas (`Net.algo`), los scripts que lo
## usan no compilan antes de que existan los autoloads: las pruebas `godot -s` (compilan main.gd, que
## arrastra al menú) y la comprobación de sintaxis (--check-only) daban "Identifier not found: Net"
## (2026-09-18). Así, además, el analizador comprueba cada llamada.
static func node() -> NetService:
	return (Engine.get_main_loop() as SceneTree).root.get_node("Net") as NetService


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
	_input_seq.clear()
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
	# Se corta la conexión: si había una partida pintando, se acabó -soltar aquí al cliente evita que
	# siga interpolando fotos que ya no van a llegar, y que Main vuelva a entrar en ella al recargar
	# la escena (ui/pause_menu.gd, "Salir de la partida", 2026-09-20)-.
	if client != null and client.has_match():
		client.stop()
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
	var pname := String(who.get("name", "un peer sin registrar"))
	print("[RED] se va %s" % pname)
	# Partida en marcha (tarea 3): su leyenda se queda quieta -nadie la maneja- hasta que un bot la
	# recoja (tarea 7, decisión ya tomada: no se adelanta aquí). RemoteControl ya no volverá a
	# escribirle nada: sus últimos wish/run se quedarían clavados si no se pararan a mano.
	if dedicated and server != null and server.has_match():
		server.on_disconnect(id, pname)
	lobby.remove(id)
	_pids.erase(id)
	_input_seq.erase(id)
	# Sala vacía con una partida corriendo: se acabó de verdad (todos los humanos se fueron). Sin
	# esto, server.has_match() seguiría en true para siempre (stop() no lo llama nadie más todavía,
	# tarea 7) y el próximo "Iniciar" se rechazaría aunque no quedara nadie jugando la de antes
	# (revisión de la tarea 2, hallazgo 2: arrancar una partida mientras otra sigue viva).
	if dedicated and lobby.players.is_empty() and server != null and server.has_match():
		print("[RED] sala vacía: doy la partida por terminada")
		server.stop()
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
	# Registro repetido del mismo peer: se ignora (LobbyRules.add tampoco lo duplicaría). Así nadie
	# cambia su id de dispositivo a mitad de sesión ni se cuela dos veces (auditoría, 2026-09-20).
	if lobby.players.has(id):
		print("[RED] registro repetido de %s (peer %d): lo ignoro" % [String(lobby.players[id]["name"]), id])
		_lobby_state.rpc_id(id, lobby.to_dict())
		return
	var taken: Array = []
	for other in lobby.players:
		taken.append(String(lobby.players[other]["name"]))
	var nick := Identity.unique_name(Identity.sanitize_name(pname), taken)
	if lobby.add(id, nick).is_empty():
		_kick.rpc_id(id, "La sala está llena para este modo.")
		return
	# El id nunca se imprime (es el secreto del aparato): solo se deja rastro de que no valía.
	if not Identity.is_valid_id(pid):
		print("[RED] %s llega sin un id de dispositivo válido: le doy uno nuevo" % nick)
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


## Tu control, para el Fighter que manejas (juego en línea, tarea 3): SOLO tu intención, nunca un
## resultado (el servidor decide todo lo demás con las reglas de siempre). El número de secuencia lo
## pone esta función (siempre creciente): el servidor descarta lo que llegue con uno menor o igual al
## último que vio de ti. d: {"wish": Vector2, "run": bool, "crouch": bool, "basic": bool, "yaw": float}.
## Se manda 30 veces por segundo (net/net_client.gd, tarea 5: predicción y reconciliación). Devuelve el
## número de secuencia que le puso, para que quien lo mandó (NetClient) guarde el MISMO control en su
## cola de pendientes -si cada uno llevara la cuenta por su lado, podrían desincronizarse-.
func send_input(d: Dictionary) -> int:
	if dedicated:
		return -1
	_my_input_seq += 1
	var full := d.duplicate()
	full["seq"] = _my_input_seq
	_input_frame.rpc_id(1, NetCodec.encode_input(full))
	return _my_input_seq


## Quiero lanzar la ranura `slot` hacia `at`: fiable, un botón no se puede perder. El servidor
## comprueba recarga, munición y alcance con las reglas de siempre (net/net_server.gd, on_cast): un
## cliente trucado no lanza más rápido ni más lejos.
func send_cast(slot: int, at: Vector3) -> void:
	if dedicated:
		return
	_cast.rpc_id(1, slot, at)


## Foto del mundo para UN jugador, 20 veces por segundo (net/net_server.gd): tarea 5, cada peer recibe
## su PROPIA foto con su propio `ack` (el último control suyo que el servidor ya aplicó), no la misma
## para todos con `ack` a 0 como en la tarea 4 -la reconciliación necesita saber justo eso: cuáles de
## sus controles ya mandados puede dejar de reproducir-. No sale más caro en bytes: el transporte
## (WebSocket/ENet) ya manda una copia por conexión aunque se llame `.rpc()` a todos a la vez, así que
## pasar de una llamada `.rpc()` a `NetServer.roster.size()` llamadas `.rpc_id()` no añade tráfico, solo
## repite la codificación (barata, unos bytes con StreamPeerBuffer) una vez por jugador humano.
func send_snapshot_to(peer_id: int, bytes: PackedByteArray) -> void:
	if dedicated:
		_snapshot.rpc_id(peer_id, bytes)


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


## Tu control, 30 Hz (tarea 3): unreliable_ordered para no frenar el juego por un paquete perdido, y
## aun así el servidor comprueba el número de secuencia él mismo -unreliable_ordered no lo garantiza
## en todos los transportes, y un cliente trucado podría mandar los suyos fuera de orden a mano-. Lo
## que llega tarde o repetido se descarta sin más (ni siquiera se avisa: es tan frecuente como
## esperado con UDP/unreliable, no un error).
@rpc("any_peer", "unreliable_ordered")
func _input_frame(bytes: PackedByteArray) -> void:
	if not multiplayer.is_server() or server == null:
		return
	var id := multiplayer.get_remote_sender_id()
	var d := NetCodec.decode_input(bytes)
	if d.is_empty():
		return
	var seq := int(d["seq"])
	if seq <= int(_input_seq.get(id, -1)):
		return
	_input_seq[id] = seq
	server.on_input(id, d)


## Lanzar, fiable (tarea 3): el servidor decide si se puede -recarga, munición, alcance-, nunca el
## cliente (net/net_server.gd, on_cast -> combat.start_cast con las reglas de siempre).
@rpc("any_peer", "reliable")
func _cast(slot: int, at: Vector3) -> void:
	if not multiplayer.is_server() or server == null:
		return
	server.on_cast(multiplayer.get_remote_sender_id(), slot, at)


## Foto del mundo (servidor -> un peer, 20/s): solo la usa un cliente de verdad, con partida en
## marcha (NetClient, creado en _start_match). El servidor dedicado no se manda nada a sí mismo: ya
## tiene el estado de verdad en Main, y esto es `unreliable_ordered` sin `call_local` a propósito.
## `unreliable_ordered` (no `unreliable` a secas, como en la tarea 4) para que el transporte descarte
## él solo una foto que llegara desordenada; de todos modos `NetClient._ingest_snapshot` vuelve a
## comprobarlo por su cuenta con el campo `t` (revisión de la tarea 4, hallazgo 2: con WebSocket/TCP no
## se ve, pero la reconciliación de la tarea 5 se apoya en saber cuál es la foto más nueva, y un
## transporte UDP el día de mañana sí podría entregarlas fuera de orden).
## Una baja (servidor -> todos): quién mató a quién, por id de leyenda -el mismo id que llevan las
## fotos y el mismo índice que ocupa en el reparto de la sala-. Va `reliable` y no en la foto porque
## es un SUCESO: una foto perdida la corrige la siguiente, una baja perdida no vuelve.
@rpc("authority", "reliable")
func _kill(killer_id: int, victim_id: int) -> void:
	if dedicated or client == null:
		return
	client.on_kill(killer_id, victim_id)


## El servidor cuenta una baja a todos (lo llama game/team_mode.gd.on_fighter_death).
func send_kill(killer_id: int, victim_id: int) -> void:
	if multiplayer.multiplayer_peer == null or not multiplayer.is_server():
		return
	_kill.rpc(killer_id, victim_id)


@rpc("authority", "unreliable_ordered")
func _snapshot(bytes: PackedByteArray) -> void:
	if dedicated or client == null:
		return
	client.on_snapshot(bytes)


## El líder inicia: semilla nueva, reparto de plazas (humanos y bots) y aviso a todos. En el servidor
## dedicado, además, monta la partida de verdad (fase 2): guarda semilla y modo donde
## Main._pick_mode() los lee al recargar la escena (como hace el menú al pulsar JUGAR) y el reparto
## en NetServer, que sobrevive al cambio de escena por ser hijo de este autoload.
@rpc("any_peer", "reliable")
func _request_start() -> void:
	if not multiplayer.is_server():
		return
	var by := multiplayer.get_remote_sender_id()
	var err := lobby.can_start(by)
	if err != "":
		_notify.rpc_id(by, err)
		return
	# Ya hay una partida viva en este servidor (revisión de la tarea 2, hallazgo 2): sin esto, un
	# peer que se hiciera líder de una sala reciclada podía pisar el reparto/modo/semilla de la
	# partida en curso -y cortarle el tick- sin avisar a quien la estuviera jugando de verdad. Cuando
	# la sala se vacía de verdad, _on_peer_disconnected ya llama a server.stop() y esto se libera.
	if dedicated and server != null and server.has_match():
		_notify.rpc_id(by, "Ya hay una partida en marcha.")
		return
	var match_seed := Main.new_seed()
	var roster := lobby.roster(match_seed)
	lobby.unready_all()
	print("[RED] empieza %s · semilla %d · %d plazas" % [lobby.mode, match_seed, roster.size()])
	_broadcast_lobby()
	_start_match.rpc(lobby.mode, match_seed, roster)
	if dedicated:
		Engine.set_meta("fl_seed", match_seed)
		Engine.set_meta("fl_mode", lobby.mode)
		server.start(lobby.mode, match_seed, roster)
		get_tree().reload_current_scene()


@rpc("authority", "reliable", "call_local")
func _start_match(m: String, match_seed: int, roster: Array) -> void:
	match_started.emit(m, match_seed, roster)
	# Cliente de verdad (no el servidor dedicado, que ya se monta la partida arriba): pinta lo que
	# manda el servidor (fase 2, tarea 4). Guarda semilla y modo donde Main._pick_mode() los lee al
	# recargar -como el servidor- y crea el NetClient que sobrevive al recargo con el reparto de la
	# sala; Main._ready() lo detecta y no crea leyendas, bots ni team_mode: solo pinta.
	if not dedicated:
		if client == null:
			client = NetClient.new()
			add_child(client)
		client.start(m, match_seed, roster)
		Engine.set_meta("fl_seed", match_seed)
		Engine.set_meta("fl_mode", m)
		get_tree().reload_current_scene()


## Resultado de una regla: si falló, se lo dice solo a quien pidió; y siempre manda el estado (así
## también vuelve a su sitio quien pidió algo imposible).
func _apply(err: String) -> void:
	if err != "":
		_notify.rpc_id(multiplayer.get_remote_sender_id(), err)
	_broadcast_lobby()
