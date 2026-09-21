## Juego en línea, cliente (tarea 4 de docs/superpowers/plans/2026-09-20-juego-en-linea-f2-partida.md,
## ampliado en la tarea 5): guarda las dos últimas fotos del servidor (Net._snapshot, 20/s) y, cada
## fotograma, pinta el instante `ahora - DELAY` interpolando entre ellas para los DEMÁS -si una foto
## llega tarde, el tirón no se nota, a cambio de verlos con ese retraso a propósito (spec, "Cliente:
## pintar lo que manda el servidor")-. TU leyenda es distinta (tarea 5, "predicción y reconciliación"):
## tiene un `Fighter` de verdad, con cuerpo y colisión, que se mueve AL MOMENTO con el mismo
## `combat.move_fighter` que usaría sin conexión; cada control que se manda al servidor se guarda, y
## cuando llega una foto que dice hasta dónde ha confirmado el servidor (`ack`), se vuelve a la
## posición confirmada y se reproducen los controles que todavía no ha confirmado. No se predicen
## habilidades, daño ni muertes -de eso solo manda el servidor-. Vive como hijo del autoload Net
## (net/net.gd), así que sobrevive a recargar la escena cuando el líder pulsa Iniciar -igual que
## NetServer, que hace lo mismo en el servidor-.
class_name NetClient
extends Node

const DELAY := 0.1     # s de diferido del spec para los DEMÁS: "sin él, cualquier foto que llegue tarde da un tirón"
const SEND_DT := 1.0 / 30.0        # tus controles al servidor, al ritmo que pide el spec
const RECONCILE_SNAP := 1.5        # spec, tarea 5: más de esto de error, se salta sin más
const RECONCILE_SMOOTH := 0.2      # spec, tarea 5: menos, se suaviza en este tiempo
const MAX_PENDING := 90            # 3 s de controles a 30 Hz: si el servidor no confirma nada en ese
                                    # tiempo (caído, o un --lag disparatado) no tiene sentido seguir
                                    # guardándolos todos -se pierde precisión de la reconciliación, pero
                                    # se evita una cola sin tope-.

var mode := ""
var match_seed := 0
var roster: Array = []
var main: Main = null
var view: NetView = null
var my_fighter_id := -1     # el índice del reparto que te toca a ti (-1 si no juegas, solo miras)
var running := false

var _prev: Dictionary = {}      # foto decodificada más vieja de las dos que se interpolan
var _cur: Dictionary = {}       # ...y la más nueva
var _prev_t := 0.0              # cuándo LLEGÓ cada una (reloj local, Time.get_ticks_msec()): así no
var _cur_t := 0.0               # hace falta sincronizar relojes con el servidor para interpolar
var _last_snapshot_t := -INF    # el `t` (reloj del SERVIDOR) de la última foto que se aplicó de
                                 # verdad (revisión de la tarea 4, hallazgo 2): una foto con un `t`
                                 # igual o más viejo se descarta, en vez de fiarse de la hora LOCAL de
                                 # llegada -con WebSocket/TCP no se ve, pero la reconciliación necesita
                                 # saber de verdad cuál es la más nueva, y un transporte por UDP el día
                                 # de mañana sí podría entregarlas desordenadas-.
var _bench_t := 0.0             # --bench: acumulado para el aviso de ms/fotograma de red
var _bench_usec := 0
var _bench_n := 0
var _bench_phys_t := 0.0        # --bench (tarea 5): lo mismo, pero del coste de PREDECIR (fotograma de física)
var _bench_phys_usec := 0
var _bench_phys_n := 0

# --- tarea 5: predicción y reconciliación de TU leyenda ---
var predicted: Fighter = null   # tu leyenda de verdad: cuerpo y colisión reales, como sin conexión
var ammo_bar: AmmoBar = null    # tu munición bajo tu vida (null si tu leyenda dispara sin límite)
var forced_wish := Vector2.INF  # Vector2.INF = lee el teclado/ratón de verdad; una sonda sin ventana
var forced_run := false         # puede fijar esto en vez (no hay teclado que leer en --headless), como
var forced_crouch := false      # el `wish` de Vector2 que ya usa NetService.send_input: en el plano del mundo.
var _pending: Array = []        # controles YA MANDADOS que el servidor todavía no ha confirmado, en
                                 # orden: cada uno {"seq", "wish", "run", "crouch", "basic", "yaw", "dt"}
var _scratch_input := {}         # se reutiliza al predecir (60 Hz) para no asignar por fotograma
# Lo que va tu leyenda POR DELANTE de la última posición que el servidor ha confirmado. No es un
# defecto: es exactamente para lo que existe la predicción, y en régimen vale más o menos
# (retardo + edad de la foto) x velocidad. Sirve de termómetro: si la reconciliación repone menos
# distancia de la que tocaba, el adelanto se encoge y tu leyenda va por detrás de donde el servidor
# te tiene, sin dar un solo tirón (medido el 2026-09-20 con --lag=150: 0,13 m reproduciendo mal
# contra 0,38 m reproduciendo bien, y lo teórico son ~0,36 m). El "error" de cada reconciliación NO
# sirve para esto: sale casi igual en los dos casos, porque la predicción viva se equivoca lo mismo.
var lead_sum := 0.0
var lead_n := 0
# La medida DIRECTA del asunto: a qué velocidad avanza la reproducción de los controles pendientes,
# contra la velocidad a la que avanza tu predicción viva. Las dos son del cliente y en las mismas
# unidades, así que su cociente debe rondar 1. Reproduciendo mal (una llamada por control cuando cada
# control son dos pasos de física) se queda en 0,5: un factor de dos, imposible de confundir con
# ruido. El adelanto de arriba también lo delata, pero por un margen mucho más fino.
var replay_dist := 0.0
var replay_dt := 0.0
var _send_t := 0.0
var _predicted_marked := false
var _mesh_offset := Vector3.ZERO   # cuánto se retrasa el MODELO (no el cuerpo de colisión, que ya está
var _mesh_t_left := 0.0            # en el sitio bueno) tras una corrección pequeña; se apaga solo
var _lag_ms := 0                # --lag=N (sondas): retraso artificial de las fotos que LLEGAN, para
var _delayed: Array = []        # probar la reconciliación con una red mala de verdad sin montar una
var snapped_last_reconcile := false   # tarea 5: ¿la ÚLTIMA reconciliación saltó (error > RECONCILE_SNAP)
                                       # en vez de suavizarse? Un salto es una corrección DE VERDAD (p.
                                       # ej. el primer par de fotos de la partida, con el servidor
                                       # todavía en `ack=0` porque no ha tenido tiempo de confirmar
                                       # ningún control tuyo): el spec lo permite explícitamente ("si el
                                       # error pasa de 1,5 m, salta") y una sonda que lo contara como
                                       # "tirón" estaría probando otra cosa. Una sonda lo lee y lo apaga
                                       # para no contar dos veces el mismo salto.


## El líder pulsó Iniciar (Net._start_match ya lo emitió y va a recargar la escena): guarda el
## reparto y espera a que Main se reconstruya y llame a attach().
func start(p_mode: String, p_seed: int, p_roster: Array) -> void:
	mode = p_mode
	match_seed = p_seed
	roster = p_roster.duplicate(true)
	main = null
	if view != null:
		view.clear()
	view = null
	# La leyenda predicha de la partida ANTERIOR (si la hubo) cuelga del Main viejo, que está a punto
	# de desaparecer con el reload_current_scene() que viene: se suelta explícito aquí, como ya hacía
	# `view` arriba, en vez de confiar en que el árbol se la lleve por delante.
	if predicted != null and predicted.body != null and is_instance_valid(predicted.body):
		predicted.body.queue_free()
	predicted = null
	ammo_bar = null          # colgaba del cuerpo que se acaba de soltar
	_pending.clear()
	_send_t = 0.0
	_mesh_offset = Vector3.ZERO
	_mesh_t_left = 0.0
	_predicted_marked = false
	_last_snapshot_t = -INF
	snapped_last_reconcile = false
	_delayed.clear()
	# Una sonda pudo dejar fijado un mando de prueba en la partida anterior (revancha, o varias
	# partidas seguidas en el mismo proceso): una nueva partida empieza siempre leyendo el
	# teclado/ratón de verdad, no lo que quedara puesto.
	forced_wish = Vector2.INF
	forced_run = false
	forced_crouch = false
	_prev = {}
	_cur = {}
	running = true


## Fin de la partida (tarea 7): para de pintar y suelta lo que había dibujado.
func stop() -> void:
	running = false
	main = null
	if view != null:
		view.clear()
	view = null
	if predicted != null and predicted.body != null and is_instance_valid(predicted.body):
		predicted.body.queue_free()
	predicted = null
	ammo_bar = null          # colgaba del cuerpo que se acaba de soltar
	_pending.clear()


func has_match() -> bool:
	return running


## Main, ya con el mapa montado -sin leyendas, sin bots, sin combate: eso lo pinta esta clase según
## van llegando las fotos- se engancha aquí (Main._ready lo llama al final, sin --server y con
## partida en marcha).
func attach(p_main: Main) -> void:
	main = p_main
	view = NetView.new()
	view.setup(main, roster)
	my_fighter_id = -1
	var my_peer := NetService.node().my_id()
	for i in roster.size():
		if int((roster[i] as Dictionary).get("peer", 0)) == my_peer:
			my_fighter_id = i
			break
	_lag_ms = maxi(0, int(NetService.node().cmdline.get("lag", "0")))


## Foto recibida (Net._snapshot): con --lag=0 (lo normal) se aplica al momento; si no, se guarda para
## aplicarla `_lag_ms` más tarde -simula una red peor de lo que es de verdad el bucle local, sin tener
## que montar un proxy-. La descodificación se hace aquí, no al aplicarla, para no tener que guardar
## los bytes crudos (y porque un paquete corrupto se descarta cuanto antes).
func on_snapshot(bytes: PackedByteArray) -> void:
	var d := NetCodec.decode_snapshot(bytes)
	if d.is_empty():
		return
	if _lag_ms <= 0:
		_ingest_snapshot(d)
		return
	_delayed.append({"at": Time.get_ticks_msec() / 1000.0 + float(_lag_ms) / 1000.0, "d": d})


## Fotos ya decodificadas cuyo retraso artificial (--lag) ya pasó: se aplican en el mismo orden en que
## llegaron (una cola, no una pila), así que el retraso no las desordena por su cuenta -solo simula que
## tardan más, no que se adelanten unas a otras-.
func _drain_lag(now: float) -> void:
	while not _delayed.is_empty() and float(_delayed[0]["at"]) <= now:
		_ingest_snapshot((_delayed.pop_front() as Dictionary)["d"])


## Una foto YA decodificada, lista para pintarse y (si es la tuya) reconciliar. Descarta la que no sea
## más nueva que la última aplicada (revisión de la tarea 4, hallazgo 2: por `t`, el reloj del
## SERVIDOR, no por cuándo ha llegado aquí).
func _ingest_snapshot(d: Dictionary) -> void:
	if is_stale(float(d.get("t", 0.0)), _last_snapshot_t):
		return
	_last_snapshot_t = float(d["t"])
	_prev = _cur
	_prev_t = _cur_t
	_cur = d
	_cur_t = Time.get_ticks_msec() / 1000.0
	_reconcile(d)


## Tu posición según la ÚLTIMA foto (sin interpolar: para la sonda de la tarea 4, que solo quiere saber
## cuánto se ha movido tu leyenda EN EL SERVIDOR, no cómo se pinta). Vector3.INF si todavía no ha
## llegado ninguna foto con tu id. No cambia con la predicción: sigue siendo la verdad del servidor.
func my_pos() -> Vector3:
	if my_fighter_id < 0:
		return Vector3.INF
	for e in _cur.get("fighters", []):
		if int((e as Dictionary)["id"]) == my_fighter_id:
			return (e as Dictionary)["pos"]
	return Vector3.INF


## Dónde se VE tu leyenda predicha ahora mismo (cuerpo real + el pequeño desfase visual del modelo que
## se está reabsorbiendo tras una corrección pequeña): lo que mide la sonda de la tarea 5 para
## comprobar que una corrección no da un tirón hacia atrás. Vector3.INF si todavía no existe (los
## primeros ~100 ms de partida, antes de la primera foto con tu id).
func predicted_visual_pos() -> Vector3:
	if predicted == null:
		return Vector3.INF
	var offset := predicted.model.position if predicted.model != null else Vector3.ZERO
	return predicted.body.global_position + offset


func _physics_process(delta: float) -> void:
	if not running or main == null or predicted == null:
		return
	var t0 := Time.get_ticks_usec()
	_apply_local_input(delta)
	# Solo el CRONÓMETRO del botón (tarea 5b), no la habilidad: nunca se llama combat.tick_fighter
	# sobre `predicted` (eso ticaría regeneración, veneno, definitiva por carga… todo lo que decide
	# el servidor). `Fighter.tick_cooldowns` es pura cuenta atrás; ver request_cast/_predict_cooldown.
	predicted.tick_cooldowns(delta)
	_settle_mesh(delta)
	if main._args.has("bench"):
		_bench_phys_usec += Time.get_ticks_usec() - t0
		_bench_phys_n += 1
		_bench_phys_t += delta
		if _bench_phys_t >= 1.0:
			print("[RED] cliente: %.3f ms/fotograma de física predicha (%d muestras)" % [
				(float(_bench_phys_usec) / maxf(float(_bench_phys_n), 1.0)) / 1000.0, _bench_phys_n])
			_bench_phys_t = 0.0
			_bench_phys_usec = 0
			_bench_phys_n = 0
	_send_t += delta
	if _send_t >= SEND_DT:
		var dt := _send_t
		_send_t = 0.0
		_send_control(dt)


## Aplica AHORA MISMO, sin esperar al servidor, tu intención de este fotograma de física: el mismo
## `combat.move_fighter` que movería a `pf` sin conexión, sobre el mismo mapa y las mismas colisiones
## (spec, tarea 5). Es lo que hace que soltar el joystick/las teclas responda al instante en vez de
## a los 100 ms de la foto.
func _apply_local_input(delta: float) -> void:
	var d := _read_local_input(_scratch_input)
	var wish: Vector2 = d["wish"]
	predicted.wish = Vector3(wish.x, 0.0, wish.y)
	predicted.run = bool(d["run"])
	predicted.crouch = bool(d["crouch"])
	predicted.holding_basic = bool(d["basic"])
	main.combat.move_fighter(predicted, delta)


## Tu intención ahora mismo, en el plano del mundo (igual que RemoteControl.apply lo entiende): del
## dedo (joystick/botón de la básica de game/player_input.gd, tarea 5b) si `main.touch`, si no del
## teclado y el ratón de verdad, o de `forced_wish` si una sonda sin ventana lo ha fijado a mano (no
## hay teclado real en --headless). No incluye abilidades ni apuntado: eso sigue sin predecirse.
## Rellena `out` en vez de devolver un diccionario nuevo: esto se llama 60 veces por segundo para
## predecir y otras 30 para mandar, y crear un Dictionary por llamada va contra la regla del repo de
## no asignar en el camino caliente (revisión de la tarea 5, 2026-09-20). Quien MANDA el control sí
## necesita uno propio —se queda guardado en `_pending` hasta que el servidor lo confirme—, así que
## ese pasa uno nuevo; quien solo predice reutiliza `_scratch_input`.
func _read_local_input(out: Dictionary) -> Dictionary:
	out["yaw"] = main._yaw
	if forced_wish != Vector2.INF:
		out["wish"] = forced_wish
		out["run"] = forced_run
		out["crouch"] = forced_crouch
		out["basic"] = false
		return out
	var wish := Vector2.ZERO
	var run := false
	var crouch := false
	var basic := false
	if main.touch and main.input != null:
		# El vector del joystick está en pantalla (x = derecha, y = adelante/atrás LOCAL): se pasa al
		# plano del mundo con la MISMA cuenta que main._physics_process usaría sin conexión (línea
		# 2302 de main.gd, antes de esta tarea la única que existía).
		var basis := main.cam.global_transform.basis
		var fwd := -basis.z
		fwd.y = 0.0
		fwd = fwd.normalized()
		var right := basis.x
		right.y = 0.0
		right = right.normalized()
		var jv: Vector2 = main.input._joy_vec
		var w3 := right * jv.x - fwd * jv.y
		wish = Vector2(w3.x, w3.z)
		run = jv.length() >= main.input.JOY_RUN
		crouch = main.input._touch_crouch
		basic = main.input._aim_btn == 0
	elif Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and main.cam != null:
		var basis := main.cam.global_transform.basis
		var fwd := -basis.z
		fwd.y = 0.0
		fwd = fwd.normalized()
		var right := basis.x
		right.y = 0.0
		right = right.normalized()
		var w3 := Vector3.ZERO
		if Input.is_physical_key_pressed(KEY_W): w3 += fwd
		if Input.is_physical_key_pressed(KEY_S): w3 -= fwd
		if Input.is_physical_key_pressed(KEY_D): w3 += right
		if Input.is_physical_key_pressed(KEY_A): w3 -= right
		wish = Vector2(w3.x, w3.z)
		run = Input.is_physical_key_pressed(KEY_SHIFT)
		crouch = Input.is_physical_key_pressed(KEY_CTRL)
		basic = Input.is_physical_key_pressed(KEY_Q)
	out["wish"] = wish
	out["run"] = run
	out["crouch"] = crouch
	out["basic"] = basic
	return out


## Manda tu control al servidor (30 Hz) y lo guarda en `_pending` con el número que Net.send_input le
## puso -no uno propio: si cada uno llevara su cuenta podrían desincronizarse-. `dt` es lo que ha
## pasado desde el control anterior: al reconciliar, reproducirlo con este mismo `dt` reparte el
## tiempo real transcurrido entre los controles pendientes, en vez de inventar uno.
func _send_control(dt: float) -> void:
	var d := _read_local_input({})       # este SÍ se guarda en `_pending`: tiene que ser suyo
	var seq := NetService.node().send_input(d)
	if seq < 0:
		return
	d["seq"] = seq
	d["dt"] = dt
	_pending.append(d)
	while _pending.size() > MAX_PENDING:
		_pending.pop_front()


## El botón de una habilidad, pulsado de verdad (game/player_input.gd._try_cast, tarea 5b): manda la
## PETICIÓN al servidor -el único que decide si de verdad hay recarga, munición y alcance
## (net/net_server.gd.on_cast -> combat.try_cast, las reglas de siempre)- y arranca el cronómetro DEL
## BOTÓN sobre la leyenda predicha (_predict_cooldown), para que se vea algo mientras la respuesta no
## ha llegado. Es una aproximación OPTIMISTA, no lo que decidió el servidor: la foto de hoy
## (NetCodec.encode_snapshot) no manda recargas/cargas/munición por leyenda, así que si el servidor
## RECHAZA el lanzamiento (fuera de alcance, sin munición…) el botón se ensombrece igual, sin que
## nada lo corrija hasta que le toque volver a estar listo, salvo en lo único que sí viaja en la foto:
## la MUNICIÓN y la CARGA de la definitiva (2026-09-20). Esas dos NO se predicen aquí a propósito
## -gastar un disparo lo decide `combat.start_cast` en el servidor-: así la barra enseña exactamente
## los disparos que le quedan a la leyenda de verdad, con 50 ms de retraso (una foto) en vez de una
## cuenta propia que puede no coincidir. Se ve fallar quitando los dos campos del códec: la barra se
## queda llena para siempre (tools/net_check.sh lo vigila con Elsa).
func request_cast(slot: int, at: Vector3) -> void:
	if predicted == null:
		return
	NetService.node().send_cast(slot, at)
	_predict_cooldown(predicted, slot)


## Disparar sin munición: la barra parpadea en rojo y suena a hueco, igual que sin conexión
## (TeamMode.dry_fire). Lo llama game/player_input.gd cuando el botón de la básica no está listo
## por munición; sin esto, en línea el arma dejaba de disparar sin decir nada.
func dry_fire() -> void:
	if ammo_bar != null:
		ammo_bar.dry_fire()


## Cobra la recarga o la carga LOCALMENTE, con la misma cuenta que Combat.start_cast usaría sin
## conexión (game/fighter.gd ya sabe leerla: cooldown_left/fraction/text, ability_ready). Nunca toca
## `ult_charge`, `windup`, ni ejecuta el efecto de verdad: eso sigue siendo solo del servidor.
func _predict_cooldown(f: Fighter, slot: int) -> void:
	if slot == 2 and f.ult_by_charge:
		return          # por carga: la lleva `ult_charge`, y esa no se toca aquí (no se predice, tarea 5)
	var ab := f.abil(slot)
	var cd := float(ab.get("cd", 1.0))
	if int(ab.get("chg", 0)) > 0:
		f.chg[slot] = maxi(0, f.chg[slot] - 1)
		if f.chg_t[slot] <= 0.0:
			f.chg_t[slot] = cd
	else:
		f.cd[slot] = cd


## Una foto tuya de verdad (con tu id): la primera vez, nace tu leyenda predicha justo donde dice el
## servidor; las siguientes, reconcilia -vuelve a la posición confirmada y reproduce lo que todavía no
## se ha confirmado- y refleja lo que el servidor SÍ decide (vida, derribo, marca): eso nunca se
## predice, solo se muestra tal cual llega (spec, tarea 5: "no se predicen habilidades, daño ni
## muertes").
func _reconcile(d: Dictionary) -> void:
	if my_fighter_id < 0:
		return
	var mine: Dictionary = {}
	for e in d.get("fighters", []):
		if int((e as Dictionary)["id"]) == my_fighter_id:
			mine = e
			break
	if mine.is_empty():
		return
	var server_pos: Vector3 = mine["pos"]
	if predicted == null:
		_spawn_predicted(server_pos)
		return      # recién nacida, ya está exactamente donde toca: nada que reconciliar todavía
	var hp_frac := float(mine["hp"])
	predicted.rec["hp"] = hp_frac * predicted.hp_max()
	# Munición y carga de la definitiva TAL CUAL las tiene el servidor (NetCodec: van en el
	# encabezado, son tuyas, no de una leyenda de la lista). El cliente las predice entre foto y foto
	# -`tick_cooldowns` repone, `request_cast` gasta- pero quien manda es esto: si el servidor
	# rechazó el lanzamiento, el disparo vuelve a su sitio en la siguiente foto (50 ms).
	if predicted.ammo_max > 0:
		predicted.ammo = clampi(int(d.get("ammo", 0)), 0, predicted.ammo_max)
		predicted.ammo_t = float(d.get("ammo_t", 0.0)) * predicted.ammo_reload
	if predicted.ult_by_charge:
		predicted.ult_charge = float(d.get("ult_charge", 0.0))
	predicted.downed = bool(mine["downed"])
	main._set_bar(predicted.bar, hp_frac)
	var marked := bool(mine["marked"])
	if marked != _predicted_marked:
		_predicted_marked = marked
		MarkFx.apply(predicted.model, marked)
	_pending = pending_after(_pending, int(d.get("ack", 0)))
	var before := predicted.body.global_position
	# Lo que se estaba VIENDO justo antes de esta reconciliación, no solo dónde estaba el cuerpo: si la
	# anterior corrección todavía no había acabado de suavizarse (a más de 5 Hz de reconciliaciones, lo
	# normal es que no le haya dado tiempo a los 0,2 s de RECONCILE_SMOOTH), `predicted.model.position`
	# todavía debe una parte de aquel desfase. Ignorarlo aquí y limitarse a `before - reconciled` (como
	# hacía esta función al principio) tira esa deuda sin más, así que el MODELO da un salto -que no
	# sale en ningún "error" registrado, porque el cuerpo de colisión siempre estuvo bien- del tamaño
	# de lo que quedaba por suavizar. Arreglado con --lag=150 y --log: el peor "retroceso" que medía la
	# sonda (0,742 m) coincidía justo con el error de una reconciliación que iba por el camino suave.
	var visual_before := before + (predicted.model.position if predicted.model != null else Vector3.ZERO)
	# Solo se reconcilia el PLANO (X/Z): la Y no la maneja ningún control -no hay salto- y es la
	# gravedad/`move_and_slide` quien la resuelve sola, mejor que nadie, con tal de que no se la
	# toquemos. Teletransportar también la Y aquí (como hacía esta función al principio) desincroniza
	# a `is_on_floor()` del sitio real donde está el suelo bajo los pies: cada reconciliación (20/s)
	# volvía a soltar la leyenda 15-20 cm por encima de donde la gravedad la había asentado, así que
	# nunca llegaba a asentarse del todo y generaba un vaivén vertical que colaba error de sobra en la
	# medida de "retroceso" de la sonda (hallado con --log en la propia tarea 5: la X del servidor
	# coincidía casi siempre con la nuestra, era la Y la que oscilaba entre 0 y 0,19 m sin parar).
	var confirmed := Vector3(server_pos.x, before.y, server_pos.z)
	# Reproducir un control NO es llamar una vez a move_fighter: `move_and_slide()` (dentro) ignora el
	# delta que se le pasa y avanza SIEMPRE un paso de física. Como un control se manda cada 1/30 s y
	# la física va a 60, cada control son DOS pasos: llamando una sola vez se repone la mitad de la
	# distancia y la leyenda se queda permanentemente por detrás de donde el servidor la tiene. No es
	# un tirón (por eso la sonda no lo veía: medía el peor salto entre fotogramas), es una meseta:
	# 0,735 m de error sostenido con 150 ms de retardo. Lo cazó la revisión de la tarea 5 (2026-09-20).
	var phys_dt := 1.0 / float(Engine.physics_ticks_per_second)
	var step := func(pos: Vector3, input: Dictionary) -> Vector3:
		predicted.body.global_position = pos
		var wish: Vector2 = input["wish"]
		predicted.wish = Vector3(wish.x, 0.0, wish.y)
		predicted.run = bool(input["run"])
		predicted.crouch = bool(input["crouch"])
		for i in maxi(1, int(round(float(input["dt"]) / phys_dt))):
			main.combat.move_fighter(predicted, phys_dt)
		var moved := predicted.body.global_position
		replay_dist += Vector2(pos.x, pos.z).distance_to(Vector2(moved.x, moved.z))
		replay_dt += float(input["dt"])
		return moved
	# `move_fighter` también descuenta los temporizadores de animación (conjuro, queja por un golpe).
	# Reproducir los pendientes en CADA foto (20 veces por segundo, varios controles cada vez) los
	# envejecería mucho más rápido que el reloj, y la leyenda dejaría de conjurar a media animación.
	# Se guardan y se reponen: la reconciliación corrige POSICIÓN, no el resto (2026-09-20).
	var anim_t := predicted.cast_anim_t
	var hit_t := predicted.hit_anim_t
	var hit_cd := predicted.hit_anim_cd
	var reconciled: Vector3 = reconcile(confirmed, _pending, step)
	predicted.cast_anim_t = anim_t
	predicted.hit_anim_t = hit_t
	predicted.hit_anim_cd = hit_cd
	var error := Vector2(before.x, before.z).distance_to(Vector2(reconciled.x, reconciled.z))
	if not _pending.is_empty():          # sin pendientes no hay adelanto que medir
		lead_sum += Vector2(before.x, before.z).distance_to(Vector2(server_pos.x, server_pos.z))
		lead_n += 1
	predicted.body.global_position = reconciled
	if main._args.has("log") and error > 0.05:
		print("[RED] reconciliar: ack=%d pendientes=%d server_pos=%s antes=%s reconciliado=%s error=%.3f" % [
			int(d.get("ack", 0)), _pending.size(), server_pos, before, reconciled, error])
	snapped_last_reconcile = should_snap(error)
	if snapped_last_reconcile:
		_mesh_offset = Vector3.ZERO
		_mesh_t_left = 0.0
		if predicted.model != null:
			predicted.model.position = Vector3.ZERO
	else:
		# El cuerpo de colisión YA está en el sitio bueno (arriba): lo que se suaviza es solo el
		# MODELO, con un desfase que se reabsorbe en RECONCILE_SMOOTH s (_settle_mesh) -así una
		# corrección pequeña, que pasa varias veces por segundo con cualquier red normal, no se ve
		# como un tirón, y una grande (el `if` de arriba) se ve tal cual, que es preferible a
		# suavizar 1,5 m y que parezca que atraviesas las paredes a cámara lenta-. Se aplica YA, no en
		# el siguiente `_settle_mesh` (_physics_process): entre que se teletransporta el cuerpo aquí y
		# que le toca el turno a `_settle_mesh`, cualquiera que mire `predicted_visual_pos()` -la propia
		# cámara, o la sonda de la tarea 5- vería el salto SIN compensar todavía. Y se suma a lo que
		# YA se estaba viendo (`visual_before`, arriba), no a la posición desnuda del cuerpo: así una
		# corrección encadenada justo detrás de otra que no había acabado de suavizarse no pierde esa
		# deuda por el camino.
		_mesh_offset = visual_before - reconciled
		_mesh_t_left = RECONCILE_SMOOTH
		if predicted.model != null:
			predicted.model.position = _mesh_offset


## Reabsorbe `_mesh_offset` en RECONCILE_SMOOTH s (lineal: de sobra para un desfase de centímetros).
func _settle_mesh(delta: float) -> void:
	if predicted == null or predicted.model == null or _mesh_t_left <= 0.0:
		return
	_mesh_t_left = maxf(0.0, _mesh_t_left - delta)
	predicted.model.position = _mesh_offset * (_mesh_t_left / RECONCILE_SMOOTH)


## Tu leyenda de verdad, con los mismos constructores que `Combat.spawn_fighter` usa sin conexión
## (cuerpo, cápsula de colisión, modelo, animaciones, barra): así choca con el mapa igual que si no
## hubiera red, y `Combat.face_dir` la orienta hacia `main.cam_forward()` -como a cualquier jugador
## local- porque nunca se le toca `peer` (se queda a 0, el valor de "nadie remoto la maneja").
func _spawn_predicted(at: Vector3) -> void:
	var entry: Dictionary = roster[my_fighter_id]
	predicted = main.combat.spawn_fighter(int(entry.get("legend", 0)),
		int(entry.get("team", Fighter.TEAM_BLUE)), true, at)
	# Las MISMAS reglas que el servidor le aplicó a esta plaza (TeamMode.setup_from_roster): vida ×3,
	# definitiva por carga y munición en la básica. Sin ellas tu leyenda predicha salía con
	# `ammo_max == 0` -que en este juego significa "dispara sin límite"- y con la definitiva por
	# recarga, así que el botón de la básica nunca se apagaba y el de la definitiva contaba
	# segundos en vez de carga (revisión de la tarea 5b, 2026-09-20). La Horda en línea es la fase 3:
	# cuando llegue, sus reglas serán otras, de ahí la comprobación del modo.
	if GameModes.is_pvp(mode):
		TeamMode.apply_pvp_rules(predicted)
	if predicted.ammo_max > 0:
		# Tu munición bajo tu barra de vida, igual que sin conexión (TeamMode la crea ahí para `pf`;
		# aquí no hay TeamMode ninguno, así que la cuelga el cliente).
		ammo_bar = AmmoBar.new()
		predicted.body.add_child(ammo_bar)
		ammo_bar.setup(predicted, main.combat.bar_height(predicted)
			- Main.BAR_H * 0.5 - 0.03 - AmmoBar.HEIGHT * 0.5, Main.BAR_W)


func _process(delta: float) -> void:
	if not running or main == null or view == null:
		return
	var t0 := Time.get_ticks_usec()
	_drain_lag(Time.get_ticks_msec() / 1000.0)
	if not _cur.is_empty():
		var now := Time.get_ticks_msec() / 1000.0
		var a := 1.0
		if not _prev.is_empty() and _cur_t > _prev_t:
			a = clampf((now - DELAY - _prev_t) / (_cur_t - _prev_t), 0.0, 1.0)
		var cur_list: Array = _cur.get("fighters", [])
		var prev_list: Array = _prev.get("fighters", [])
		for cf in cur_list:
			var c: Dictionary = cf
			var id := int(c["id"])
			if id == my_fighter_id and predicted != null:
				continue    # tarea 5: tu leyenda ya se predice y se pinta sola; esto es para los DEMÁS
			var pos: Vector3 = c["pos"]
			var yaw: float = float(c["yaw"])
			if a < 1.0:
				for pfx in prev_list:
					var p: Dictionary = pfx
					if int(p["id"]) == id:
						pos = (p["pos"] as Vector3).lerp(pos, a)
						yaw = lerp_angle(float(p["yaw"]), yaw, a)
						break
			view.apply_fighter(id, pos, yaw, int(c["anim"]), float(c["hp"]), bool(c["marked"]))
		view.finish_frame()
	if predicted != null:
		_update_aim()
	_follow_camera()
	# El gas solo cambia de radio aquí (main._apply_zone no toca vida ni daño, así que sigue siendo
	# el servidor quien decide eso): sin esto la pared se quedaba en su tamaño inicial para siempre.
	if main._zone_wall != null:
		main._zone_r = float(_cur.get("zone", main._zone_r))
		main._apply_zone()
	if main._args.has("bench"):
		_bench_usec += Time.get_ticks_usec() - t0
		_bench_n += 1
		_bench_t += delta
		if _bench_t >= 1.0:
			print("[RED] cliente: %.2f ms/fotograma de red (interpolar y pintar, %d muestras)" % [
				(float(_bench_usec) / maxf(float(_bench_n), 1.0)) / 1000.0, _bench_n])
			_bench_t = 0.0
			_bench_usec = 0
			_bench_n = 0


## El aro y el punto de mira (tarea 5b): sin conexión los mueve main._tick_powers cada fotograma de
## física, pero esa función no corre aquí -Main._physics_process se sale al momento porque `pf` no
## existe nunca en línea (a propósito, ver game/player_input.gd._fighter)-, así que se repite el
## mismo trocito (main.gd líneas 2348-2353, sin lo de los esbirros del Rey liche: `predicted` nunca
## tiene, `main._has_minions()` ya da false sin `pf`). Sin esto la mira no se movía nunca apuntando
## con el dedo o el ratón en una partida de verdad.
func _update_aim() -> void:
	var input := main.input
	if input == null:
		return
	var prev_r := main._ability_range(input._preview) if input._preview >= 0 else 6.0
	var aim := input._aim_point(prev_r)
	if main.touch and input._aim_btn >= 0:
		aim = input._aim_point_touch(input._preview)
	main._aim_dot.position = aim + Vector3(0, 0.05, 0)
	main._aim_ring.visible = input._preview >= 1
	if input._preview >= 1:
		main._aim_ring.position = aim + Vector3(0, 0.05, 0)
		var r := main._ability_radius(input._preview)
		var t := main._aim_ring.mesh as TorusMesh
		t.outer_radius = r
		t.inner_radius = maxf(0.05, r - 0.12)


## La cámara sigue a TU leyenda: si ya existe la predicha (tarea 5), sobre ELLA -al instante, sin el
## retraso de la foto-; si todavía no (los primeros ~100 ms de partida), sobre el fantasma que pinta
## NetView, como en la tarea 4.
func _follow_camera() -> void:
	if main.pivot == null:
		return
	var at := Vector3.INF
	if predicted != null:
		at = predicted_visual_pos()
	elif my_fighter_id >= 0:
		var actor: NetView.Actor = view.actors.get(my_fighter_id)
		if actor != null:
			at = actor.body.global_position
	if at == Vector3.INF:
		return
	main.pivot.global_position = at + Vector3(0, main._cam_height, 0)
	main.pivot.rotation.y = main._yaw
	main.spring.rotation.x = main._pitch


# =====================================================================
# Puro (tarea 5): reconciliación, sin nodos ni Combat, para tests/test_net_predict.gd
# =====================================================================

## De todos los controles YA MANDADOS, cuáles quedan por confirmar tras una foto con este `ack` -el
## servidor ya aplicó hasta `ack` inclusive, así que solo hace falta reproducir los que vengan
## DESPUÉS-. `sent` es un Array de Dictionary con al menos "seq"; no se asume que venga ordenado (por
## si acaso), aunque en la práctica `_pending` siempre lo está.
static func pending_after(sent: Array, ack: int) -> Array:
	var out: Array = []
	for e in sent:
		if int((e as Dictionary)["seq"]) > ack:
			out.append(e)
	return out


## Reproduce, EN ORDEN, los controles que aún no ha confirmado el servidor, empezando desde la
## posición que el servidor SÍ confirmó -no desde donde estaba prediciendo antes, que es justo el
## error que se quiere corregir-. `step(pos, input)` hace el paso de verdad: en el juego de verdad es
## `combat.move_fighter` con colisión real (ver `_reconcile`, arriba); aquí, y en la prueba pura, basta
## con que sea determinista, porque lo que hay que comprobar es el ORDEN y el CONTEO de controles que
## se reproducen, no la física en sí (que ya prueban `tests/rocks_probe.gd` y compañía).
static func reconcile(confirmed: Vector3, pending: Array, step: Callable) -> Vector3:
	var pos := confirmed
	for input in pending:
		pos = step.call(pos, input)
	return pos


## A partir de qué distancia de error una corrección es demasiado grande para suavizarla y hay que
## saltar directamente (spec: "si el error pasa de 1,5 m, salta; si es menor, se suaviza").
static func should_snap(error_m: float) -> bool:
	return error_m > RECONCILE_SNAP


## Una foto con este `t` (reloj del SERVIDOR) es vieja o repetida frente a la última que se aplicó de
## verdad: no hay que pintarla ni reconciliar con ella (revisión de la tarea 4, hallazgo 2).
static func is_stale(t: float, last_t: float) -> bool:
	return t <= last_t
