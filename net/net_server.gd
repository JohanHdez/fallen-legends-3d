## Nodo del servidor dedicado (hijo del autoload Net, así que sobrevive a los cambios de escena):
## monta la partida que la sala repartió y lleva su tick a 60 Hz mientras Main no puede. Con
## `--server`, Main apaga su propio `_physics_process` (no hay cámara que seguir ni HUD que pintar),
## así que es NetServer quien llama a Combat y TeamMode directamente, igual que main.gd lo haría en
## una partida normal, pero sin nada de lo que solo sirve para pintar.
## Fase 2 del juego en línea (docs/superpowers/specs/2026-09-18-juego-en-linea-design.md), tarea 3 de
## docs/superpowers/plans/2026-09-20-juego-en-linea-f2-partida.md: las plazas humanas (`Fighter.peer
## != 0`) las mueve RemoteControl con el control que manda cada jugador (Net._input_frame/_cast); las
## de bot (`peer == 0`), BotBrain, como siempre. Las fotos al cliente (tarea 4) llegan después: hoy
## el servidor no le enseña nada a nadie salvo por `--log` (ver on_disconnect). Desde la tarea 4
## también manda una foto del mundo 20 veces por segundo (_send_snapshot): la primera vez que el
## juego en línea se ve de verdad, no solo se simula.
class_name NetServer
extends Node

const SNAPSHOT_DT := 1.0 / 20.0     # 20 fotos/s (spec, § Protocolo)

var mode := ""
var match_seed := 0
var roster: Array = []
var main: Main = null      # se engancha solo cuando Main vuelve a construirse tras reload_current_scene
var running := false
var _cast_ms := {}              # peer -> último lanzamiento aceptado (ms), para el tope de arriba
var _start_pos: Dictionary = {}   # peer -> posición cuando llegó su primer control (para medir cuánto
                                   # se movió: tarea 3, sin fotos todavía que se lo enseñen al cliente)
var _acks := {}                 # peer -> número de secuencia del ÚLTIMO control suyo ya aplicado
                                 # (tarea 5): se lo decimos en SU propia foto para que reconcilie -sin
                                 # esto, `ack` iba siempre a 0 y ningún cliente sabía qué controles
                                 # podía dejar de reproducir tras una corrección-.
var _snap_t := 0.0
var _snap_log_t := 0.0          # --log: cada cuánto se recuerdan los KB/s (no en cada foto, sería spam)


## El líder pulsó Iniciar (Net._request_start ya sorteó la semilla y repartió las plazas): guarda la
## partida y espera a que Main se reconstruya y llame a attach(). No recarga la escena él mismo (eso
## lo hace Net, que es quien tiene la referencia al árbol en ese momento).
func start(p_mode: String, p_seed: int, p_roster: Array) -> void:
	mode = p_mode
	match_seed = p_seed
	roster = p_roster.duplicate(true)
	main = null
	_start_pos.clear()        # partida nueva: nadie ha mandado un control todavía
	_acks.clear()
	running = true


## Fin de la partida: para el tick y suelta el Main viejo. Hoy lo llama Net._on_peer_disconnected en
## cuanto la sala se queda sin nadie (una partida abandonada no debe seguir "en marcha" para siempre,
## revisión de la tarea 2, hallazgo 2); volver a la sala con el marcador puesto es la tarea 7.
func stop() -> void:
	running = false
	main = null
	_start_pos.clear()
	_acks.clear()


func has_match() -> bool:
	return running


## Main, ya con el mapa y TeamMode.setup_from_roster hechos, se engancha aquí para que NetServer
## lleve su tick (Main._ready lo llama al final, con --server y partida en marcha).
func attach(p_main: Main) -> void:
	main = p_main


## Mismo orden que Main._physics_process/_tick_powers sin nada de lo que solo pinta (revisión de la
## tarea 2, hallazgo 1: antes tick_world iba al final y move_bots antes que _tick_zone, así que un
## proyectil o el gas de este fotograma resolvían contra una posición distinta según quién simulara
## la partida). RemoteControl NO se llama desde aquí: Net.on_input ya escribió wish/run/crouch en
## cuanto llegó el paquete (antes de este fotograma o al principio de él, como el teclado local
## escribe wish en cuanto Godot procesa el evento), así que tick_fighter y move_bots ya lo ven.
func _physics_process(delta: float) -> void:
	if not running or main == null or main.team_mode == null:
		return
	var combat := main.combat
	for f: Fighter in combat.fighters:
		combat.tick_fighter(f, delta)
	main.team_mode.tick_brains(delta)
	combat.tick_world(delta)
	main.team_mode.tick(delta)
	main._tick_zone(delta)
	main.team_mode.move_bots(delta)
	_snap_t += delta
	if _snap_t >= SNAPSHOT_DT:
		_snap_t -= SNAPSHOT_DT
		_send_snapshot()


## Foto del mundo, 20 veces por segundo: posición, orientación, animación, vida y marca de cada
## leyenda -sin criaturas todavía, la Horda en línea es la fase 3-. Tarea 5: ya NO es la misma foto
## para todos (`ack` fijo a 0, tarea 4): cada jugador humano recibe la SUYA, con su propio `ack` -el
## último control suyo que ya aplicamos-, para que `NetClient` sepa qué controles puede dejar de
## reproducir al reconciliar. El grueso de la foto (leyendas, zona, reloj) se calcula UNA vez; solo el
## campo `ack` cambia por jugador, así que no sale más caro en bytes (Net.send_snapshot_to explica por
## qué el transporte ya mandaba una copia por jugador de todos modos).
func _send_snapshot() -> void:
	var combat := main.combat
	var fighters: Array = []
	for f: Fighter in combat.fighters:
		fighters.append({
			"id": f.id, "pos": f.pos(),
			"yaw": f.model.rotation.y if f.model != null else 0.0,
			"anim": NetCodec.anim_index(f.anim.current_animation if f.anim != null else ""),
			"hp": f.hp() / maxf(f.hp_max(), 1.0), "downed": f.downed, "marked": f.marked_t > 0.0,
		})
	var base := {
		"t": Time.get_ticks_msec() / 1000.0, "fighters": fighters,
		"zone": main._zone_r if main.zone_active() else 0.0,
		"clock": main.team_mode.rules.round_time_left, "round": main.team_mode.rules.round,
	}
	var net := NetService.node()
	var peers := multiplayer.get_peers()
	var last_bytes := 0
	var sent := 0
	for f: Fighter in combat.fighters:
		# Los bots no tienen peer (0); un humano que se desconectó a mitad de partida sigue con su
		# `peer` de antes (nadie se lo pone a 0 todavía: revive/bot de repuesto es la tarea 7), así que
		# hay que comprobar que ese peer SIGUE conectado antes de dirigirle un `rpc_id` -si no, es la
		# misma clase de carrera que ya toleran `_kick.rpc_id`/`_lobby_state.rpc_id` en net.gd, pero
		# aquí sería en CADA foto (20/s) en vez de una vez, así que mejor no arriesgarse-.
		if f.peer == 0 or not peers.has(f.peer):
			continue
		base["ack"] = int(_acks.get(f.peer, 0))
		# Lo suyo, que el cliente no puede saber solo: la munición que le queda de verdad (gastarla la
		# decide `combat.start_cast` aquí, no su botón) y la carga de la definitiva (sube con el daño
		# que hace, y el daño también lo decidimos aquí). Antes el cliente pintaba su propio ciclo de
		# recarga mientras el servidor ya no disparaba nada: sin aviso ni sonido (revisión de la
		# tarea 5b, 2026-09-20).
		base["ammo"] = f.ammo
		base["ammo_t"] = f.ammo_t / maxf(f.ammo_reload, 0.01)
		base["ult_charge"] = f.ult_charge
		var bytes := NetCodec.encode_snapshot(base)
		net.send_snapshot_to(f.peer, bytes)
		last_bytes = bytes.size()
		sent += 1
	if main._args.has("log") and sent > 0:
		# Throttle a ojo (SNAPSHOT_DT por foto mandada, no el delta real del fotograma): sobra
		# precisión para un aviso cada 2 s, y así no hace falta pasarse el delta hasta aquí. Todas las
		# fotos de esta tanda pesan igual (el `ack` es un entero de tamaño fijo): con la del último
		# jugador mandado sobra para el aviso.
		_snap_log_t -= SNAPSHOT_DT
		if _snap_log_t <= 0.0:
			_snap_log_t = 2.0
			print("[RED] foto: %d bytes (%d leyendas) · %.1f KB/s por jugador" % [
				last_bytes, fighters.size(), last_bytes * 20.0 / 1024.0])


## Control recibido de un jugador (Net._input_frame, ya con la secuencia comprobada): se aplica al
## momento, como si lo escribiera su teclado o su joystick. Guarda dónde estaba la primera vez que
## controló, para poder decir luego cuánto se movió (moved_distance).
func on_input(peer_id: int, d: Dictionary) -> void:
	var f := fighter_for_peer(peer_id)
	if f == null:
		return
	if not _start_pos.has(peer_id):
		_start_pos[peer_id] = f.pos()
	# El `ack` de su PRÓXIMA foto (tarea 5): este control ya se aplica AHORA, así que ya se puede dar
	# por confirmado -si `Net._input_frame` lo dejó llegar hasta aquí es porque su secuencia era mayor
	# que la última suya, así que no hace falta un maxi() defensivo, pero tampoco estorba tenerlo.
	_acks[peer_id] = maxi(int(d.get("seq", 0)), int(_acks.get(peer_id, 0)))
	RemoteControl.apply(f, d)


## Quiere lanzar la ranura `slot` hacia `at` (Net._cast): las reglas de siempre -recarga, munición-
## las comprueba combat.try_cast (f.ability_ready), la MISMA comprobación que usa cualquier lanzador
## local o BotBrain, así que un cliente trucado no lanza más rápido. El alcance NO lo comprueba nada
## de eso (en local lo recorta PlayerInput._aim_point ANTES de llamar a start_cast): aquí se recorta
## otra vez, con la misma cuenta, para que tampoco lance más lejos si el cliente no lo hizo.
func on_cast(peer_id: int, slot: int, at: Vector3) -> void:
	if not running or main == null or slot < 0 or slot > 2:
		return
	# Tope de frecuencia: `_cast` es fiable, así que un cliente trucado podría mandarlo mil veces por
	# segundo. No conseguiría lanzar más (las recargas las comprueba el servidor), pero sí hacerle
	# trabajar. 20 por segundo es más de lo que puede pulsar una persona (revisión, 2026-09-20).
	var now := Time.get_ticks_msec()
	if now - int(_cast_ms.get(peer_id, -1000)) < 50:
		return
	_cast_ms[peer_id] = now
	# Un punto fabricado a mano puede traer NaN o infinito, y TODA comparación con NaN es falsa: el
	# recorte de alcance de abajo no recortaría nada. Aquí no se confía en el cliente, así que el
	# punto se valida antes de tocarlo (revisión de la tarea 3, 2026-09-20).
	if not (is_finite(at.x) and is_finite(at.y) and is_finite(at.z)):
		return
	at = at.clamp(Vector3(-NetCodec.MAP_MAX, -NetCodec.MAP_MAX, -NetCodec.MAP_MAX),
		Vector3(NetCodec.MAP_MAX, NetCodec.MAP_MAX, NetCodec.MAP_MAX))
	var f := fighter_for_peer(peer_id)
	if f == null:
		return
	var rng: float = f.ability_range(slot)
	var from := f.pos()
	from.y = 0.0
	var to := at
	to.y = 0.0
	var off := to - from
	if off.length() > rng:
		to = from + off.normalized() * rng
	# --log (tarea 5b, el dedo y las habilidades en línea): la comprobación es la MISMA que hace
	# combat.try_cast un instante después (f.ability_ready), mirada ANTES de lanzar para poder decir
	# también cuándo el servidor RECHAZA el botón -sin recarga o sin munición-, que es justo lo que
	# demuestra que el cliente no decide nada: pulsar solo pide, y aquí se ve la respuesta de verdad.
	if main._args.has("log"):
		if f.ability_ready(slot):
			print("[RED] %s lanza la ranura %d (recarga %.1fs)" % [f.display_name, slot, float(f.abil(slot).get("cd", 0.0))])
		else:
			print("[RED] %s pide la ranura %d pero no está lista: la ignoro" % [f.display_name, slot])
	main.combat.try_cast(f, slot, to)


## El Fighter que maneja este peer, o null si no hay partida, no está en el reparto o ya se fue (los
## bots no tienen peer: 0 nunca es de nadie).
func fighter_for_peer(peer_id: int) -> Fighter:
	if main == null or peer_id == 0:
		return null
	for f: Fighter in main.combat.fighters:
		if f.peer == peer_id:
			return f
	return null


## Cuánto se ha movido desde su primer control, o -1.0 si nunca mandó ninguno.
func moved_distance(peer_id: int) -> float:
	if not _start_pos.has(peer_id):
		return -1.0
	var f := fighter_for_peer(peer_id)
	if f == null:
		return -1.0
	return f.pos().distance_to(_start_pos[peer_id] as Vector3)


## Un jugador se fue a mitad de partida (Net._on_peer_disconnected): su leyenda se queda quieta,
## nadie la maneja hasta que un bot la recoja (tarea 7, decisión ya tomada, no se adelanta aquí). De
## paso, con --log, dice cuánto llegó a moverse: es lo único que el servidor le puede "enseñar" a la
## sonda de la tarea 3 sin fotos todavía (tarea 4 se las manda de verdad).
func on_disconnect(peer_id: int, pname: String) -> void:
	var f := fighter_for_peer(peer_id)
	if f == null:
		return
	f.wish = Vector3.ZERO
	f.run = false
	if main != null and main._args.has("log"):
		var d := moved_distance(peer_id)
		if d >= 0.0:
			print("[RED] %s se movió %.1f m antes de irse; su leyenda (%s) se queda quieta" % [pname, d, f.display_name])
		else:
			print("[RED] la leyenda de %s (%s) se queda quieta: nadie la maneja" % [pname, f.display_name])
