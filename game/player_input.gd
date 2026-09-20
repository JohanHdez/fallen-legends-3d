## La entrada del jugador: teclado, ratón, táctil y apuntado. Sale de main.gd el 2026-09-20 para la
## fase 0 del juego en línea (docs/superpowers/specs/2026-09-18-juego-en-linea-design.md): el
## servidor sin pantalla no tiene entrada, y main.gd estaba a 2.901 líneas de las 3.000 del tope.
## No cambia nada de lo que hacía: mismas constantes, mismos nombres y las mismas trazas.
class_name PlayerInput
extends Node

var main: Main

# --- táctil ---
# Las mismas que scripts/touch_controls.gd del juego 2D, para que el tacto sea idéntico.
const JOY_RADIUS := 95.0
const JOY_RUN := 0.92               # joystick al borde = correr (en el móvil no hay tecla Mayúsculas)
const JOY_GRAB := 1.7        # el joystick responde hasta este múltiplo de su radio
const KNOB_RADIUS := 42.0
const DEAD_ZONE := 0.18
const ABILITY_SIDE := 92.0
const MAIN_SIDE := 120.0
# Botón de agacharse (petición del usuario: en el móvil no había forma). Conmuta con un toque:
# mantenerlo mientras mueves y atacas pediría tres dedos. Va arriba a la derecha del joystick, fuera
# de la zona que lo agarra (JOY_RADIUS × JOY_GRAB).
const CROUCH_BTN := 3
const CROUCH_RADIUS := 36.0
const CROUCH_OFFSET := Vector2(160.0, -135.0)
# Botón de órdenes del Rey liche (sale con esqueletos vivos): tocar alterna Atacar/Reagrupar y
# arrastrar coloca la Emboscada. En teclado, F; mantenida más de ORDERS_TAP, apunta la emboscada.
const ORDERS_BTN := 4
const ORDERS_RADIUS := 38.0
const ORDERS_OFFSET := Vector2(-190.0, -130.0)   # desde la básica
const ORDERS_TAP := 0.3
const AIM_DEAD := 18.0       # px de arrastre a partir de los cuales se apunta a mano
const AIM_RADIUS := 110.0    # px de arrastre que equivalen al alcance máximo

var _touch_crouch := false        # el botón de agacharse en táctil
var _preview := -1                 # qué habilidad se está apuntando (-1 ninguna)
var _joy_idx := -1
var _joy_origin := Vector2.ZERO
var _joy_vec := Vector2.ZERO
var _look_idx := -1
var _aim_btn := -1
var _aim_drag := Vector2.ZERO
var _aim_idx := -1


func _setup_touch() -> void:
	if not main.touch:
		return
	var layer := CanvasLayer.new()
	layer.layer = 20
	main.add_child(layer)
	main.touch_ui = Control.new()
	main.touch_ui.set_script(load("res://touch_ui.gd"))
	main.touch_ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	main.touch_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	main.touch_ui.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR   # los SVG se reescalan suaves
	main.touch_ui.main = main
	layer.add_child(main.touch_ui)


## Posición fija del joystick, igual que en el juego (no aparece donde tocas).
func joy_center() -> Vector2:
	return Vector2(190.0, get_viewport().get_visible_rect().size.y - 250.0)


## Misma distribución que touch_controls._layout(): básica grande abajo a la derecha,
## táctica a su izquierda y definitiva arriba. Más el botón de agacharse junto al joystick.
func button_rects() -> Array:
	var v := get_viewport().get_visible_rect().size
	var main_c := Vector2(v.x - 100.0, v.y - 110.0)
	return [
		{"idx": 0, "c": main_c, "r": MAIN_SIDE / 2.0, "name": String(main._abil(0)["n"])},
		{"idx": 1, "c": main_c + Vector2(-170.0, 20.0), "r": ABILITY_SIDE / 2.0, "name": String(main._abil(1)["n"])},
		{"idx": 2, "c": main_c + Vector2(-60.0, -165.0), "r": ABILITY_SIDE / 2.0, "name": String(main._abil(2)["n"])},
		{"idx": CROUCH_BTN, "c": crouch_center(joy_center()), "r": CROUCH_RADIUS, "name": "Agacharse"},
	] + ([{"idx": ORDERS_BTN, "c": main_c + ORDERS_OFFSET, "r": ORDERS_RADIUS,
		"name": Minions.ORDER_NAMES[main.pf.minion_order]}] if main._has_minions() else [])


static func crouch_center(joy: Vector2) -> Vector2:
	return joy + CROUCH_OFFSET


## Dónde caería la emboscada que estás apuntando ahora (F mantenida o arrastrando el botón), o INF.
func _ambush_aim() -> Vector3:
	if not main._has_minions():
		return Vector3.INF
	if main._orders_hold >= ORDERS_TAP:
		return Minions.ambush_point(main.pf.pos(), _aim_point(Minions.AMBUSH_RANGE))
	if _aim_btn == ORDERS_BTN and _aim_drag.length() > AIM_DEAD:
		return Minions.ambush_point(main.pf.pos(), _drag_point(Minions.AMBUSH_RANGE))
	return Vector3.INF


## Punto del suelo que marca un arrastre táctil de `_aim_drag`, a `rng_m` como mucho.
func _drag_point(rng_m: float) -> Vector3:
	var f := clampf(_aim_drag.length() / AIM_RADIUS, 0.0, 1.0)
	var basis := main.cam.global_transform.basis
	var fwd := Vector3(-basis.z.x, 0, -basis.z.z).normalized()
	var right := Vector3(basis.x.x, 0, basis.x.z).normalized()
	var dir := (right * _aim_drag.x - fwd * _aim_drag.y).normalized()
	var at := main.player.global_position + dir * (rng_m * f)
	at.y = 0.0
	return at


## Segundos que faltan, para el número del centro del botón.
func button_center(idx: int) -> Vector2:
	for b in button_rects():
		if b["idx"] == idx:
			return b["c"]
	return Vector2.ZERO


func _button_at(p: Vector2) -> int:
	for b in button_rects():
		if p.distance_to(b["c"]) <= b["r"] + 12.0:
			return b["idx"]
	return -1


func _input(e: InputEvent) -> void:
	if not main.touch or main.touch_ui == null:
		return
	if main._frozen():
		return
	if e is InputEventScreenTouch:
		var t := e as InputEventScreenTouch
		if t.pressed:
			var b := _button_at(t.position)
			if b == CROUCH_BTN:
				_touch_crouch = not _touch_crouch
			elif b >= 0:
				_aim_btn = b
				_aim_idx = t.index          # el dedo que manda esta habilidad
				_aim_drag = Vector2.ZERO
				_preview = b if b != ORDERS_BTN else -1
			elif t.position.distance_to(joy_center()) <= JOY_RADIUS * JOY_GRAB:
				_joy_idx = t.index
				_joy_origin = joy_center()
				_joy_vec = _joy_from(t.position)
			else:
				_look_idx = t.index
		else:
			# Cada dedo suelta LO SUYO: antes cualquier dedo levantado disparaba la habilidad,
			# así que soltar el joystick la lanzaba y soltar el botón ya no hacía nada.
			if t.index == _aim_idx:
				_aim_idx = -1
				_release_aim()
			if t.index == _joy_idx:
				_joy_idx = -1
				_joy_vec = Vector2.ZERO
			if t.index == _look_idx:
				_look_idx = -1
		main.touch_ui.queue_redraw()
	elif e is InputEventScreenDrag:
		var d := e as InputEventScreenDrag
		if d.index == _aim_idx and _aim_btn >= 0:
			_aim_drag = d.position - button_center(_aim_btn)
		elif d.index == _joy_idx:
			_joy_vec = _joy_from(d.position)
		elif d.index == _look_idx:
			main._yaw -= d.relative.x * 0.006
			main._pitch = clampf(main._pitch - d.relative.y * 0.005, -1.35, 0.35)
		main.touch_ui.queue_redraw()


## Vector del joystick a partir de dónde está el dedo, con la zona muerta del juego.
func _joy_from(p: Vector2) -> Vector2:
	var v := (p - joy_center()) / JOY_RADIUS
	if v.length() < DEAD_ZONE:
		return Vector2.ZERO
	return v.limit_length(1.0)


## Soltar el botón: si apenas se arrastró es un toque (apuntado automático); si se arrastró,
## la dirección y la distancia del arrastre mandan, como el apuntado táctil del juego.
func _release_aim() -> void:
	var idx := _aim_btn
	_aim_btn = -1
	_preview = -1
	if idx < 0:
		return
	if idx == ORDERS_BTN:
		main._orders_release(Vector3.INF if _aim_drag.length() <= AIM_DEAD else _drag_point(Minions.AMBUSH_RANGE))
		return
	if _aim_drag.length() <= AIM_DEAD:
		_try_cast(idx)
		return
	_try_cast(idx, _drag_point(main._ability_range(idx)))


# ---------------------------------------------------------------- poderes

func _build_aim() -> void:
	main._aim_ring = main.vfx.ring(5.0, main.SPARK, 0.55)
	main._aim_ring.visible = false
	main.add_child(main._aim_ring)
	main._aim_dot = main.vfx.ring(0.22, main.SPARK, 0.9)
	main.add_child(main._aim_dot)


## Dónde apunta la mira: rayo desde el centro de la pantalla al plano del suelo, recortado
## al alcance de la habilidad. En 3ª persona esto sustituye al ratón sobre el mapa isométrico.
func _aim_point(max_range: float) -> Vector3:
	var origin := main.cam.global_position
	var dir := -main.cam.global_transform.basis.z
	var p := main.player.global_position
	if dir.y < -0.01:
		p = origin + dir * (-origin.y / dir.y)
	else:
		p = main.player.global_position + Vector3(dir.x, 0, dir.z).normalized() * max_range
	p.y = 0.0
	var from := main.player.global_position
	from.y = 0.0
	var off := p - from
	if off.length() > max_range:
		p = from + off.normalized() * max_range
	return p


## El punto que marcaría el arrastre actual, para pintar el anillo antes de soltar.
func _aim_point_touch(idx: int) -> Vector3:
	if _aim_drag.length() <= AIM_DEAD:
		return _auto_aim(idx)
	var f := clampf(_aim_drag.length() / AIM_RADIUS, 0.0, 1.0)
	var basis := main.cam.global_transform.basis
	var fwd := Vector3(-basis.z.x, 0, -basis.z.z).normalized()
	var right := Vector3(basis.x.x, 0, basis.x.z).normalized()
	var dir := (right * _aim_drag.x - fwd * _aim_drag.y).normalized()
	var at := main.player.global_position + dir * (main._ability_range(idx) * f)
	at.y = 0.0
	return at


## Toque sin arrastre: al enemigo más cercano dentro del alcance; si no, al frente.
func _auto_aim(i: int) -> Vector3:
	var rng_m := main._ability_range(i)
	var near := main.combat.foes_in(main.pf.team, main.player.global_position, rng_m, 1, true)
	if not near.is_empty():
		var p: Vector3 = near[0]["node"].global_position
		p.y = 0.0
		return p
	var f := Vector3(sin(main.player_model.rotation.y), 0, cos(main.player_model.rotation.y))
	return main.player.global_position + f * rng_m * 0.7


## Tu lanzamiento: intercambio con el señuelo si toca, y si no, al punto que marque la mira (ratón)
## o al enemigo más cercano (toque sin arrastre).
func _try_cast(i: int, at := Vector3.INF) -> void:
	if main.combat.try_swap(main.pf, i):
		return
	if i == 0 and main.pf.ammo_max > 0 and main.pf.ammo <= 0 and main.team_mode != null:
		main.team_mode.dry_fire()
	if not main.pf.ability_ready(i):
		return
	if at == Vector3.INF:
		at = _auto_aim(i) if main.touch else _aim_point(main.pf.ability_range(i))
	main.combat.start_cast(main.pf, i, at)


## Solo para pruebas headless: lanza lo que esté listo hacia el enemigo más cercano.
func _auto_cast() -> void:
	if main.pf.dash_left > 0.0:
		return              # durante la embestida no se lanza nada (si no, pisa su animación)
	var near := main.combat.foes_in(main.pf.team, main.player.global_position, 30.0, 1, true)
	if near.is_empty() or main.player_model == null:
		return
	var to: Vector3 = near[0]["node"].global_position - main.player.global_position
	to.y = 0.0
	if to.length() > 0.1:
		main.player_model.rotation.y = atan2(to.x, to.z)
	for idx in [2, 1, 0]:
		if main._ability_ready(idx):
			var at := main.player.global_position + to.normalized() * minf(to.length(), main._ability_range(idx))
			_try_cast(idx, at)
			return


func _unhandled_input(e: InputEvent) -> void:
	if main._mode == "menu" or main.player == null:
		return
	if main._frozen():
		return
	if e is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var mm := e as InputEventMouseMotion
		main._yaw -= mm.relative.x * 0.005
		main._pitch = clampf(main._pitch - mm.relative.y * 0.004, -1.35, 0.35)
	elif e is InputEventMouseButton:
		var mb := e as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed:
			main.spring.spring_length = maxf(2.0, main.spring.spring_length - 0.8)
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed:
			main.spring.spring_length = minf(30.0, main.spring.spring_length + 0.8)
		elif mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed and not main.touch:
			_try_cast(0)
		elif mb.button_index == MOUSE_BUTTON_RIGHT and not main.touch:
			# mantener = ver el radio, soltar = colocar (como el apuntado táctil del juego)
			if mb.pressed:
				_preview = 1
			else:
				_preview = -1
				_try_cast(1)
	elif e is InputEventKey and not (e as InputEventKey).echo:
		var k := e as InputEventKey
		if k.pressed:
			match k.physical_keycode:
				KEY_ESCAPE:
					Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED else Input.MOUSE_MODE_CAPTURED
				KEY_C:
					main._cam_mode = 1 - main._cam_mode
					main._apply_cam_mode()
				KEY_Q:
					_try_cast(0)
				KEY_E:
					_preview = 1
				KEY_R:
					_preview = 2
				KEY_F:
					if main._has_minions():
						main._orders_hold = 0.0
				KEY_TAB:
					if main.team_mode == null and main._horde_team_size() == 1:   # con equipo, la de la partida
						main.switch_legend(1)
				KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6, KEY_7:
					if main.team_mode == null and main._horde_team_size() == 1:
						main.switch_legend(k.physical_keycode - KEY_1 - main._legend)
				KEY_F10:
					get_tree().quit()
		else:
			match k.physical_keycode:
				KEY_E:
					if _preview == 1:
						_preview = -1
						_try_cast(1)
				KEY_R:
					if _preview == 2:
						_preview = -1
						_try_cast(2)
				KEY_F:
					if main._orders_hold >= 0.0:
						var at := _ambush_aim() if main._orders_hold >= ORDERS_TAP else Vector3.INF
						main._orders_hold = -1.0
						main._orders_release(at)
