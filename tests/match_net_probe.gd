## Sonda de la partida en red (fase 2, tareas 3-5 de
## docs/superpowers/plans/2026-09-20-juego-en-linea-f2-partida.md): un cliente sin pantalla entra por
## el menú, se hace líder de una sala vacía (como "Cara" en la tarea 2), pide un modo y arranca en
## cuanto está listo -aquí SIEMPRE está solo, así que no hace falta nada de lo que ya prueba
## lobby_probe (equipos, leyendas, varios jugadores): esta sonda es sobre lo que pasa DESPUÉS de que
## la partida empiece-.
##
## Tarea 3/4: en cuanto llega match_started, espera a que tu leyenda predicha exista de verdad
## (`net.client.predicted != null`, tarea 5) -es la señal real de que el servidor ya reconstruyó la
## escena y llegó al menos una foto con tu id, en vez de adivinar un margen a ojo (duda de la tarea 3:
## "encajaría mejor una vez esté la foto de la tarea 4", y ya está)-, y entonces empuja "avanzar" hacia
## el centro del mapa (-X, la plaza 1 de un 1v1 nace SIEMPRE en (51, ~0.2, 0): el mapa sale de
## MAP_SEED, no de la semilla de la partida) durante --push-secs (8 s por defecto) fijando
## `net.client.forced_wish` -el mismo campo que leería un joystick de verdad, así la sonda ejercita
## EXACTAMENTE el camino de producción (NetClient._physics_process manda los controles solo, a 30 Hz)
## en vez de llamar a NetService.send_input() por su cuenta y por otro lado (que antes de la tarea 5
## habría competido con la predicción por quién manda cada control).
##
## Tarea 5: mientras empuja, muestrea `net.client.predicted_visual_pos()` cada fotograma y se queda con
## el peor retroceso (que la X aumente, ya que "avanzar" es hacia -X) entre dos fotogramas seguidos: la
## reconciliación no debe dar tirones hacia atrás de más de 0,3 m (spec). `--lag=N` (leído por
## net/net_client.gd, no por esta sonda) retrasa artificialmente las fotos que llegan, para probarlo
## con una red peor de lo que es de verdad el bucle local.
##   godot --headless --path . -- --mode=menu --client=ws://127.0.0.1:PUERTO --name=Nia \
##     --netprobe=match_net_probe --want-mode=1v1 --push-secs=8 [--lag=150]
##
## Tarea 5b (el dedo y las habilidades en línea): con --touch (el mismo flag que fuerza main.touch),
## en vez de forced_wish -que se salta el dedo por completo, como haría un teclado de mentira- esta
## sonda EMPUJA EL JOYSTICK DE VERDAD, escribiendo `main.input._joy_vec` -exactamente lo que
## game/player_input.gd._input() deja tras un toque real sobre el pomo, la única pieza que sí haría
## falta reproducir a mano (una InputEventScreenTouch fabricada a ojo, probado durante esta misma
## tarea, no llega a `_input()` en las mismas coordenadas: este proyecto usa stretch "canvas_items" y
## sin ventana real el reescalado deja la posición en otro sitio; usar la escritura de más abajo, como
## ya hacía `forced_wish` con el teclado, evita ese problema sin dejar de ejercitar lo NUEVO de esta
## tarea)- y TOCA EL BOTÓN DE VERDAD llamando a `main.input._try_cast(0)`, la misma función que
## `_release_aim()` invoca al soltar el dedo sin apenas arrastre. Ejercita el camino de producción
## entero a partir de ahí: NetClient._read_local_input (rama táctil, tarea 5b) -> combat.move_fighter
## / NetClient.request_cast -> NetService.send_cast -> el servidor (net/net_server.gd, on_cast, con
## --log confirma si la habilidad salió de verdad). "Vela fallar antes": sin esta tarea, `main.input`
## ni se creaba para un cliente en línea (el bloque de más abajo habría reventado contra un `null`),
## y `_read_local_input` no leía el joystick aunque existiera.
extends Node

const SETTLE_SECS := 1.0    # tras dejar de mandar, margen para que llegue la última foto (interpolación de 100 ms)
const MAX_BACKSTEP := 0.3   # spec, tarea 5: ningún fotograma retrocede más de esto
const CAST_TAP_AT := 1.0    # s tras empezar a empujar: de sobra para que el botón ya exista (tarea 5b)
## Cada cuánto se vuelve a tocar la básica. Tiene que ser MÁS RÁPIDO que la recarga de un disparo
## (LegendData.PVP_AMMO: 1 s por disparo) para que la munición baje de verdad en vez de quedarse
## rondando el tope; la recarga de la propia habilidad (0,6 s la del Tormentero) ya impide lanzar
## más rápido de lo que toca, así que tocar cada 0,2 s solo significa "el dedo insiste".
const CAST_TAP_EVERY := 0.2
const LEAVE_SECS := 2.0     # --leave-test: margen para que la escena se recargue tras salir

var net: Node
var _t := 0.0
var _secs := 30.0
var _push_secs := 8.0
var _want_mode := "1v1"
var _pressed := false
var _asked := false
var _started := false
var _ready_wait_t := 0.0    # cuánto se tardó de match_started a que existiera la leyenda predicha (diagnóstico)
var _pushing := false
var _push_t := 0.0
var _settle_t := -1.0       # -1 mientras se manda "avanzar"; 0+ mientras se espera la última foto
var _client_start_pos := Vector3.INF
var _predict_prev := Vector3.INF     # muestra anterior de predicted_visual_pos(), para medir el paso
var _worst_backstep := 0.0           # el peor retroceso visto entre dos fotogramas seguidos (tarea 5)
var _pushed_dist := 0.0              # lo que ha recorrido de verdad la predicción viva mientras empuja
var _live_prev := Vector3.INF
# El retroceso entre fotogramas es CIEGO a un error constante: si la reconciliación repone menos
# distancia de la que el servidor recorrió, la leyenda no da tirones, se queda a una distancia fija
# por detrás y ninguna muestra "salta" (revisión de la tarea 5, 2026-09-20: así convivían un
# "retroceso máximo 0,005 m" y un error real de 0,735 m). Esto mide lo otro: cuánto se separa de
# verdad lo predicho de lo confirmado, en régimen.
var _done := false
var _touch := false          # --touch (tarea 5b): toca de verdad en vez de forced_wish/forced_run
var _cast_tapped := false
var _tap_t := 0.0
var _taps := 0
# Munición (arreglo del 2026-09-20): la mínima que llegó a tener tu leyenda predicha. El cliente NO
# descuenta disparos por su cuenta (net/net_client.gd, request_cast): la munición baja SOLO cuando
# llega una foto del servidor con la de verdad. Así que ver este número por debajo del tope prueba
# de punta a punta que la foto la trae; antes se quedaba clavada en el tope para siempre y el botón
# seguía pintando su ciclo de recarga mientras el servidor ya no disparaba nada.
var _ammo_min := -1
var _ammo_max := 0
var _leaving := false        # --leave-test: ya se pulsó "Salir de la partida"
var _leave_t := 0.0
var _pause_problems: Array = []


func _ready() -> void:
	net = get_parent()
	_secs = float(net.cmdline.get("secs", "45"))
	_push_secs = float(net.cmdline.get("push-secs", "8"))
	_want_mode = String(net.cmdline.get("want-mode", "1v1"))
	_touch = net.cmdline.has("touch")
	net.lobby_changed.connect(_on_lobby_changed)
	net.match_started.connect(_on_match_started)
	net.left.connect(_on_left)


func _process(delta: float) -> void:
	if _done:
		return
	_t += delta
	if _t > _secs:
		_finish(["no terminó en %.0f s (empezó la partida: %s)" % [_secs, str(_started)]])
		return
	if not _pressed:
		for n in get_tree().root.find_children("*", "Control", true, false):
			if n is ModeMenu:
				_pressed = true
				(n as ModeMenu).play_online()
				break
		return
	if not _started:
		return
	# La posición que ve el CLIENTE en su última FOTO del servidor (tarea 4, sin predecir: para
	# comparar cuánto se ha movido con lo que dice el SERVIDOR, tools/net_check.sh diferencia las dos
	# cifras). Independiente de la predicción de abajo, que mide otra cosa.
	if net.client != null:
		var seen: Vector3 = net.client.my_pos()
		if seen != Vector3.INF and _client_start_pos == Vector3.INF:
			_client_start_pos = seen
	if _settle_t >= 0.0:
		_settle_t += delta
		if _settle_t < SETTLE_SECS:
			return
		if net.cmdline.has("leave-test"):
			_tick_leave(delta)
			return
		_report_client_move()
		_finish([])
		return
	if not _pushing:
		# Espera a que tu leyenda predicha exista de verdad antes de empujar: antes de eso,
		# `forced_wish` no lo lee nadie (NetClient._physics_process se sale al momento si
		# `predicted == null`), así que empujar antes sería tiempo perdido -y adivinar cuánto hacía
		# falta esperar es justo lo que la tarea 3 dejó pendiente-.
		_ready_wait_t += delta
		if net.client == null or net.client.predicted == null:
			return
		print("[RED] leyenda predicha lista %.1f s después de empezar la partida: empujo 'avanzar'" % _ready_wait_t)
		_pushing = true
		if _touch:
			_touch_push(true)
		else:
			net.client.forced_wish = Vector2(-1.0, 0.0)
			net.client.forced_run = true
	# Muestreo de la predicción (tarea 5): el peor salto hacia ATRÁS entre dos fotogramas seguidos.
	# "Avanzar" es hacia -X, así que retroceder es que la X aumente. Un SALTO de verdad (más de
	# RECONCILE_SNAP de error: net.client.snapped_last_reconcile) no cuenta como el "tirón" que el
	# plan quiere medir -el spec lo permite a propósito ("si el error pasa de 1,5 m, salta"), y en la
	# práctica pasa en el primer par de fotos de cada partida, mientras el servidor todavía no ha
	# confirmado ningún control (`ack=0`) y no hay lag que reconciliar todavía-: si acaba de saltar,
	# esta muestra solo REBASA el punto de partida, no se compara con la anterior.
	var now_pos: Vector3 = net.client.predicted_visual_pos()
	if now_pos != Vector3.INF and _live_prev != Vector3.INF:
		_pushed_dist += Vector2(_live_prev.x, _live_prev.z).distance_to(Vector2(now_pos.x, now_pos.z))
	if now_pos != Vector3.INF:
		_live_prev = now_pos
	if now_pos != Vector3.INF:
		if net.client.snapped_last_reconcile:
			net.client.snapped_last_reconcile = false
			_predict_prev = now_pos
		else:
			if _predict_prev != Vector3.INF:
				var backstep := now_pos.x - _predict_prev.x
				if backstep > _worst_backstep:
					_worst_backstep = backstep
			_predict_prev = now_pos
	_push_t += delta
	if _touch and _push_t >= CAST_TAP_AT:
		_tap_t += delta
		if not _cast_tapped or _tap_t >= CAST_TAP_EVERY:
			_cast_tapped = true
			_tap_t = 0.0
			_tap_ability(0)
		_sample_ammo()
	if _push_t > _push_secs and _touch:
		print("[RED] munición: %d de %d en el peor momento tras %d toques de la básica" % [
			_ammo_min, _ammo_max, _taps])
	if _push_t > _push_secs:
		var n := maxf(float(net.client.lead_n), 1.0)
		# Velocidad de la reproducción contra la de la predicción viva: si reproducir los controles
		# pendientes no repone la distancia que toca, este cociente cae a la mitad (2026-09-20).
		var live_speed := _pushed_dist / maxf(_push_t, 0.001)
		var replay_speed: float = net.client.replay_dist / maxf(float(net.client.replay_dt), 0.001)
		print("[RED] dejo de empujar 'avanzar' tras %.1f s; peor retroceso en un fotograma: %.3f m; adelanto sobre lo confirmado: %.3f m; velocidad reproducida/viva: %.2f (%.2f vs %.2f m/s)" % [
			_push_t, _worst_backstep, net.client.lead_sum / n,
			replay_speed / maxf(live_speed, 0.001), replay_speed, live_speed])
		if _touch:
			_touch_push(false)
		else:
			net.client.forced_wish = Vector2.INF
			net.client.forced_run = false
		_settle_t = 0.0


## Empuja el joystick DE VERDAD (tarea 5b): escribe `main.input._joy_vec`, lo que queda tras un toque
## real sobre el pomo -al borde, hacia "adelante" en pantalla, sin arrastrarlo hacia atrás nunca, así
## que un valor fijo "a tope" es exactamente lo que dejaría un dedo empujándolo hasta el borde-.
## `NetClient._read_local_input` (rama táctil de esta tarea) lo lee cada fotograma de física, así que
## basta con dejarlo puesto: sostener el pomo de verdad tampoco manda un evento por fotograma. Se
## probó primero fabricando InputEventScreenTouch de verdad y pasándolas por Input.parse_input_event
## (el camino más fiel), pero ese toque llega a game/player_input.gd._input() en OTRAS coordenadas de
## las que se mandan -este proyecto usa stretch "canvas_items" y sin ventana real el reescalado no
## coincide-, así que se descartó por el mismo motivo por el que ya existía `forced_wish` para el
## teclado: escribir el resultado que dejaría el dedo, no el evento crudo.
func _touch_push(down: bool) -> void:
	net.client.main.input._joy_vec = Vector2(0.0, -1.0) if down else Vector2.ZERO


## El botón de la básica (ranura 0), tocado de verdad: `PlayerInput._try_cast` es la MISMA función que
## `_release_aim()` llama al soltar el dedo sin apenas arrastre (un toque, no un arrastre: apunta sola
## al enemigo más cercano o al frente). Ejercita todo lo nuevo de la tarea 5b que hay detrás del botón:
## NetClient.request_cast -> NetService.send_cast -> el servidor (net/net_server.gd, on_cast).
func _tap_ability(slot: int) -> void:
	net.client.main.input._try_cast(slot)
	_taps += 1
	if _taps <= 1:
		print("[RED] toco la ranura %d con el dedo" % slot)


## Munición de tu leyenda predicha, como la pinta el HUD (ui/ammo_bar.gd y touch_ui.gd leen esto
## mismo). Se queda con la peor: ver que baja del tope es lo que prueba que la foto del servidor la
## trae de verdad. Una leyenda sin munición (la Ilusionista) deja `_ammo_max` a 0 y no es puerta.
func _sample_ammo() -> void:
	var me: Fighter = net.client.predicted
	if me == null or me.ammo_max <= 0:
		return
	_ammo_max = me.ammo_max
	_ammo_min = me.ammo if _ammo_min < 0 else mini(_ammo_min, me.ammo)


func _on_lobby_changed() -> void:
	if not net.in_lobby() or _started or _done:
		return
	var s: LobbyRules = net.lobby
	if not s.players.has(net.my_id()) or not net.is_leader():
		return       # esta sonda solo prueba el caso "líder solo" (sala vacía, como Cara en la tarea 2)
	if s.mode != _want_mode:
		net.request_mode(_want_mode)
		return
	if not _asked:
		_asked = true
		net.request_start()


func _on_match_started(mode: String, seed_value: int, roster: Array) -> void:
	if _done:
		return
	_started = true
	print("[RED] partida iniciada: %s · semilla %d · %d plazas · empujo 'avanzar' %.0f s en cuanto exista mi leyenda" % [
		mode, seed_value, roster.size(), _push_secs])


func _on_left(reason: String) -> void:
	if _done or _leaving:
		return       # con --leave-test, salir es lo que se está probando, no un problema
	_finish(["salí de la sala: %s" % reason])


## --leave-test: pulsa "Salir de la partida" del menú de pausa (ui/pause_menu.gd._to_menu, la MISMA
## función que el botón) y comprueba que la salida existe de verdad: se suelta la conexión, el
## cliente deja de tener partida y la escena vuelve al menú de inicio. Antes del 2026-09-20 esto no
## se podía ni intentar: en una partida en red no se creaba el menú de pausa, así que en el móvil la
## única forma de salir era matar la aplicación.
func _tick_leave(delta: float) -> void:
	if not _leaving:
		_leaving = true
		_report_client_move()
		var menus: Array = (net.client.main as Node).find_children("*", "PauseMenu", true, false)
		if menus.is_empty():
			_finish(["no hay menú de pausa que pulsar"])
			return
		var menu := menus[0] as PauseMenu
		_check_pause_blocks_input(menu)
		print("[RED] pulso 'Salir de la partida'")
		menu._to_menu()
		return
	_leave_t += delta
	if _leave_t < LEAVE_SECS:
		return
	var problems: Array = _pause_problems.duplicate()
	if net.in_lobby():
		problems.append("sigo registrado en el servidor tras salir de la partida")
	if net.client != null and net.client.has_match():
		problems.append("el cliente sigue con la partida en marcha tras salir")
	if get_tree().root.find_children("*", "ModeMenu", true, false).is_empty():
		problems.append("no se volvió al menú de inicio tras salir de la partida")
	else:
		print("[RED] de vuelta en el menú de inicio: la salida funciona")
	_finish(problems)


## Con la pausa abierta EN LÍNEA el mundo no se para (el servidor sigue simulando), así que la
## entrada hay que cortarla a mano: game/player_input.gd, `blocked`. Y no basta con que el menú se
## coma los toques -el joystick se lee en `_input()`, que corre ANTES del GUI-. Se comprueba con el
## MISMO toque en el MISMO sitio dos veces: con el menú cerrado tiene que agarrar el joystick, y con
## el menú abierto no. Y que abrir la pausa suelta el joystick que ya estuviera puesto: si no, se
## queda clavado en su último valor -`NetClient` lo lee cada fotograma- y la leyenda se va corriendo
## sola mientras miras el menú.
func _check_pause_blocks_input(menu: PauseMenu) -> void:
	var input: PlayerInput = net.client.main.input
	if input == null:
		_pause_problems.append("no hay PlayerInput que comprobar")
		return
	if not _grabs_joystick(input):
		_pause_problems.append("el toque de prueba no agarra el joystick ni con la pausa cerrada: la comprobación no valdría")
		return
	input._joy_vec = Vector2(0.0, -1.0)        # el dedo, puesto, justo antes de abrir el menú
	menu.toggle()
	if input._joy_vec != Vector2.ZERO:
		_pause_problems.append("abrir la pausa no soltó el joystick (%s): la leyenda se va corriendo sola" % input._joy_vec)
	if _grabs_joystick(input):
		_pause_problems.append("el joystick sigue respondiendo con la pausa abierta")
	else:
		print("[RED] con la pausa abierta el joystick no responde y el que había puesto se soltó")


## Un toque en el centro del joystick, por el mismo `_input` por el que entra un dedo de verdad.
func _grabs_joystick(input: PlayerInput) -> bool:
	input.release_touch()
	var t := InputEventScreenTouch.new()
	t.index = 7
	t.pressed = true
	t.position = input.joy_center()
	input._input(t)
	var got := input._joy_idx >= 0
	input.release_touch()
	return got


## Cuánto vio moverse el CLIENTE a su propia leyenda, desde la primera foto con su id hasta la
## última (tarea 4): tools/net_check.sh lo compara con lo que dijo el SERVIDOR (on_disconnect).
func _report_client_move() -> void:
	if net.client == null or _client_start_pos == Vector3.INF:
		print("[RED] el cliente nunca vio una foto con su propia leyenda")
		return
	var moved: float = (net.client.my_pos() as Vector3).distance_to(_client_start_pos)
	print("[RED] cliente vio moverse su leyenda %.1f m" % moved)


func _finish(problems: Array) -> void:
	_done = true
	# La pausa (☰ y la tecla P) tiene que existir TAMBIÉN en una partida en red: hasta el 2026-09-20
	# main.gd la creaba bajo el mismo `net_client == null` que el minimapa, así que un jugador de
	# móvil no tenía ninguna forma de salir de la partida salvo matar la aplicación.
	if _started and net.client != null and net.client.main != null:
		if (net.client.main as Node).find_children("*", "PauseMenu", true, false).is_empty():
			problems.append("no hay menú de pausa en la partida en línea: no se puede salir")
	# Munición de verdad: ver arriba (_sample_ammo). Solo con el dedo, que es quien toca el botón.
	if _touch and _ammo_max > 0 and _ammo_min >= _ammo_max:
		problems.append("la munición se quedó en %d de %d tras %d toques: la foto no la trae" % [
			_ammo_min, _ammo_max, _taps])
	if _pushing and _worst_backstep > MAX_BACKSTEP:
		problems.append("la predicción retrocedió %.3f m en un fotograma (más de los %.1f m que pide el plan)" % [
			_worst_backstep, MAX_BACKSTEP])
	for p in problems:
		print("[RED] problema: %s" % p)
	print("match_net_probe: %s" % ("OK" if problems.is_empty() else "FALLO"))
	# --probeshot=ruta (captura manual, tarea 4): se toma AQUÍ, justo cuando la sonda ya sabe que el
	# mundo lleva su estado final -no con main._shot_wait, que cuenta FOTOGRAMAS y con la ventana en
	# segundo plano macOS los da a 3-4 FPS (CLAUDE.md, "Rendimiento"): adivinar cuántos hacían falta
	# para esperar 25 s de verdad no era fiable-.
	var shot := String(net.cmdline.get("probeshot", ""))
	# --pauseshot: abre el menú de pausa ANTES de la captura, para mirar con los ojos que en una
	# partida en red existe de verdad y ofrece la salida (2026-09-20). Sin él la captura sale con el
	# juego a la vista, que es lo que interesa para la barra de munición.
	if shot != "" and net.cmdline.has("pauseshot") and net.client != null and net.client.main != null:
		var menus := (net.client.main as Node).find_children("*", "PauseMenu", true, false)
		if not menus.is_empty():
			(menus[0] as PauseMenu).toggle()
			await get_tree().process_frame
			await get_tree().process_frame
	if problems.is_empty() and shot != "":
		var img := get_viewport().get_texture().get_image()
		if img != null:
			img.save_png(shot)
			print("[RED] captura: %s" % shot)
	get_tree().quit(0 if problems.is_empty() else 1)
