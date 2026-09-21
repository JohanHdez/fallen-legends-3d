## Dibuja los controles táctiles con el MISMO kit de iconos y las mismas medidas que
## scripts/touch_controls.gd del juego 2D: base (underlay), pomo (movimiento), básica (ataque),
## táctica (gadget) y definitiva (super_cargado / super_descargado).
extends Control

const TEX := {
	"underlay": preload("res://assets/ui/touch/underlay.svg"),
	"move": preload("res://assets/ui/touch/movimiento.svg"),
	"attack": preload("res://assets/ui/touch/ataque.svg"),
	"gadget": preload("res://assets/ui/touch/gadget_pocion.svg"),
	"super_off": preload("res://assets/ui/touch/super_descargado.svg"),
	"super_on": preload("res://assets/ui/touch/super_cargado.svg"),
}

# Cian: el verde se perdía contra la hierba en la primera captura, y el naranja ya es la munición.
const CHG_FULL := Color(0.35, 0.9, 1.0)          # carga de la táctica lista
const CHG_PART := Color(0.3, 0.65, 0.8, 0.8)     # la que está volviendo

var main: Node = null


func _draw() -> void:
	if main == null:
		return
	# En línea (tarea 5b), los primeros ~100 ms de partida: todavía no ha llegado la primera foto
	# con tu id, así que `net_client.predicted` -y con él `main._abil`, `main.cooldown_*`…- no existe.
	if main.net_client != null and main.net_client.predicted == null:
		return
	var font := ThemeDB.fallback_font
	# Joystick: base fija y pomo que sigue al dedo, igual que en el juego.
	var jc: Vector2 = main.input.joy_center()
	_round(TEX.underlay, jc, main.input.JOY_RADIUS, Color(1, 1, 1, 0.85))
	var knob: Vector2 = jc + main.input._joy_vec * main.input.JOY_RADIUS
	# Al borde se CORRE (main.input.JOY_RUN): el aro amarillo es lo único que lo dice, porque en el
	# móvil no hay tecla Mayúsculas (2026-09-18).
	var running: bool = main.input._joy_vec.length() >= main.input.JOY_RUN
	if running:
		draw_arc(jc, main.input.JOY_RADIUS - 2.0, 0.0, TAU, 48, Color(1.0, 0.85, 0.35, 0.85), 4.0, true)
	_round(TEX.move, knob, main.input.KNOB_RADIUS * (1.3 if running else 1.15),
		Color(1.0, 0.92, 0.6) if running else Color(1, 1, 1, 1.0 if main.input._joy_idx >= 0 else 0.85))

	for b in main.input.button_rects():
		if int(b["idx"]) == main.input.CROUCH_BTN:
			_crouch(b, font)
		elif int(b["idx"]) == main.input.ORDERS_BTN:
			_orders(b, font)
		else:
			_ability(b, font)


func _ability(b: Dictionary, font: Font) -> void:
	var i: int = b["idx"]
	var c: Vector2 = b["c"]
	# TU leyenda: sin conexión `pf`; en línea la predicha (main.hud_fighter). Antes esto miraba
	# `main.pf` a secas, que en línea es null SIEMPRE: los arcos de munición y de cargas no se
	# dibujaban nunca, y el botón de la básica pintaba su ciclo como si tuviera balas infinitas
	# (revisión de la tarea 5b, 2026-09-20).
	var me: Fighter = main.hud_fighter()
	var pressed: bool = main.input._aim_btn == i
	var r: float = b["r"] * (1.06 if pressed else 1.0)
	var ready: bool = main._ability_ready(i)
	var icon: Texture2D = TEX.attack
	if i == 1:
		icon = TEX.gadget
	elif i == 2:
		icon = TEX.super_on if ready else TEX.super_off
	# Listo para intercambiar: el botón se pone dorado y enseña la flecha, sin recarga.
	var swap: bool = main.swap_ready(i)
	_round(TEX.underlay, c, r, Color(1.35, 1.1, 0.55, 0.95) if swap else Color(1, 1, 1, 0.9))
	_round(icon, c, r * 0.92, Color(1.2, 1.1, 0.8) if swap else Color(1, 1, 1, 1.0))
	if swap:
		draw_arc(c, r - 3.0, 0.0, TAU, 40, Color(1.0, 0.85, 0.35, 0.95), 4.0, true)
		var sw := "↔"
		var f2 := ThemeDB.fallback_font
		var sws := f2.get_string_size(sw, HORIZONTAL_ALIGNMENT_LEFT, -1, 34)
		draw_string_outline(f2, c + Vector2(-sws.x * 0.5, 12.0), sw,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 34, 5, Color(0, 0, 0, 0.9))
		draw_string(f2, c + Vector2(-sws.x * 0.5, 12.0), sw,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 34, Color(1, 1, 1))

	var frac: float = main.cooldown_fraction(i)
	var maxc := int(main._abil(i).get("chg", 0))
	if maxc > 0 and not swap:
		_charges(c, r, i, maxc, font, me)
	elif frac > 0.0 and not swap:
		_sector(c, r * 0.92, frac, Color(0, 0, 0, 0.55))
		_center_text(c, main.cooldown_text(i), font)   # segundos, o "73%" si la definitiva va por carga

	# Munición de la básica por equipos: un arco por disparo alrededor del botón, como la barra
	# que va debajo de tu vida.
	if i == 0 and me.ammo_max > 0:
		_ammo_arcs(c, r + 7.0, me.ammo_max, me.ammo_level())

	# Apuntado a mano: anillo de alcance y el icono desplazado hacia donde caerá.
	if pressed and main.input._aim_drag.length() >= main.input.AIM_DEAD:
		draw_arc(c, main.input.AIM_RADIUS, 0.0, TAU, 64, Color(1, 1, 1, 0.45), 2.0)
		_round(icon, c + main.input._aim_drag.limit_length(main.input.AIM_RADIUS), r * 0.5, Color(1, 1, 1, 0.9))

	var sub: String = b["name"]
	var ss := font.get_string_size(sub, HORIZONTAL_ALIGNMENT_CENTER, -1, 13)
	var ty: float = c.y + r + 15.0
	draw_string_outline(font, Vector2(c.x - ss.x / 2.0, ty), sub,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 13, 4, Color(0, 0, 0, 0.9))
	draw_string(font, Vector2(c.x - ss.x / 2.0, ty), sub,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(1, 1, 1, 0.95))


## Órdenes del Rey liche: la orden puesta (▲ Atacar, ● Reagrupar, ▼ Emboscada) y, al arrastrar, el
## aro de alcance como al apuntar una habilidad.
func _orders(b: Dictionary, font: Font) -> void:
	var c: Vector2 = b["c"]
	var r: float = b["r"]
	var pressed: bool = main.input._aim_btn == main.input.ORDERS_BTN
	var order: String = main.pf.minion_order
	draw_circle(c, r * 0.92, Color(0.18, 0.26, 0.2, 0.85) if order != "ambush" else Color(0.3, 0.22, 0.12, 0.9))
	_round(TEX.underlay, c, r * (1.06 if pressed else 1.0), Color(0.8, 1.2, 0.85, 0.95))
	var icon := {"attack": "▲", "regroup": "●", "ambush": "▼"}.get(order, "▲") as String
	var sz := font.get_string_size(icon, HORIZONTAL_ALIGNMENT_LEFT, -1, 28)
	draw_string_outline(font, c + Vector2(-sz.x * 0.5, 10.0), icon, HORIZONTAL_ALIGNMENT_LEFT, -1, 28, 5, Color(0, 0, 0, 0.9))
	draw_string(font, c + Vector2(-sz.x * 0.5, 10.0), icon, HORIZONTAL_ALIGNMENT_LEFT, -1, 28, Color(0.85, 1.0, 0.8))
	if pressed and main.input._aim_drag.length() >= main.input.AIM_DEAD:
		draw_arc(c, main.input.AIM_RADIUS, 0.0, TAU, 64, Color(0.8, 1.0, 0.8, 0.45), 2.0)
		draw_circle(c + main.input._aim_drag.limit_length(main.input.AIM_RADIUS), 10.0, Color(0.8, 1.0, 0.8, 0.8))
	var sub := "Esqueletos: %s" % String(b["name"])
	var ss := font.get_string_size(sub, HORIZONTAL_ALIGNMENT_CENTER, -1, 13)
	var ty: float = c.y + r + 15.0
	draw_string_outline(font, Vector2(c.x - ss.x / 2.0, ty), sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, 4, Color(0, 0, 0, 0.9))
	draw_string(font, Vector2(c.x - ss.x / 2.0, ty), sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.85, 1.0, 0.8))


## Agacharse: la misma base que los demás, una flecha hacia abajo y un aro dorado mientras está activo.
func _crouch(b: Dictionary, font: Font) -> void:
	var c: Vector2 = b["c"]
	var r: float = b["r"]
	var on: bool = main.input._touch_crouch
	# Con un compañero derribado a tus pies, el botón se pone VERDE y avisa de que sirve para
	# levantarlo (petición del usuario, 2026-09-18: no encontraba cómo reanimar).
	var lift: bool = main.can_revive_now()
	# Fondo oscuro propio: los demás botones llevan un icono de color y este solo una flecha, que
	# sobre la hierba no se distinguía.
	draw_circle(c, r * 0.92, Color(0.35, 0.28, 0.08, 0.85) if on else Color(0.05, 0.06, 0.1, 0.6))
	_round(TEX.underlay, c, r, Color(1.3, 1.1, 0.6, 0.95) if on else Color(1, 1, 1, 0.85))
	if on:
		draw_arc(c, r - 3.0, 0.0, TAU, 40, Color(1.0, 0.85, 0.35, 0.95), 4.0, true)
	if lift:
		# Late, para que se vea entre la pelea.
		var pulse := 0.55 + 0.45 * sin(float(Time.get_ticks_msec()) * 0.007)
		draw_arc(c, r + 5.0, 0.0, TAU, 44, Color(0.4, 1.0, 0.5, 0.35 + 0.6 * pulse), 5.0, true)
	var arrow := "▼"
	var sz := font.get_string_size(arrow, HORIZONTAL_ALIGNMENT_LEFT, -1, 30)
	draw_string_outline(font, c + Vector2(-sz.x * 0.5, 11.0), arrow, HORIZONTAL_ALIGNMENT_LEFT, -1, 30, 5, Color(0, 0, 0, 0.9))
	draw_string(font, c + Vector2(-sz.x * 0.5, 11.0), arrow, HORIZONTAL_ALIGNMENT_LEFT, -1, 30,
		Color(1.0, 0.9, 0.5) if on else Color(1, 1, 1))
	var sub: String = "LEVANTAR" if lift else String(b["name"])
	var ss := font.get_string_size(sub, HORIZONTAL_ALIGNMENT_CENTER, -1, 13)
	var ty: float = c.y + r + 15.0
	draw_string_outline(font, Vector2(c.x - ss.x / 2.0, ty), sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, 4, Color(0, 0, 0, 0.9))
	draw_string(font, Vector2(c.x - ss.x / 2.0, ty), sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 13,
		Color(0.5, 1.0, 0.6) if lift else Color(1, 1, 1, 0.95))


func _round(tex: Texture2D, center: Vector2, radius: float, tint: Color) -> void:
	draw_texture_rect(tex, Rect2(center - Vector2(radius, radius),
		Vector2(radius * 2.0, radius * 2.0)), false, tint)


## Un arco por disparo, desde las 12 en sentido horario: lleno, a medias (el que vuelve) o vacío.
## Lo usan la munición de la básica (naranja) y las cargas de la táctica (cian).
func _ammo_arcs(center: Vector2, radius: float, n: int, level: float,
		full := AmmoBar.COL_FULL, part := AmmoBar.COL_PART) -> void:
	var span := TAU / float(n)
	var gap := 0.16
	for k in n:
		var a0 := -PI / 2.0 + span * k + gap * 0.5
		var a1 := a0 + span - gap
		draw_arc(center, radius, a0, a1, 24, Color(0, 0, 0, 0.6), 8.0, true)
		var fill := AmmoBar.segment_fill(level, k)
		if fill > 0.0:
			var col := part if AmmoBar.is_partial(level, k) else full
			draw_arc(center, radius, a0, a0 + (a1 - a0) * fill, 24, col, 5.0, true)


## Táctica con cargas (Trampa eléctrica, Alzar esqueleto, Baliza Nox): un arco por carga alrededor
## del botón, lleno si se puede lanzar y creciendo el que vuelve, y los segundos que le faltan
## (petición del usuario, 2026-09-18). Antes el botón se ensombrecía nada más gastar una aunque
## quedaran dos, y el "2/3" solo salía con todas llenas: no se sabía cuántas quedaban.
func _charges(c: Vector2, r: float, i: int, maxc: int, font: Font, me: Fighter) -> void:
	_ammo_arcs(c, r + 7.0, maxc, me.charge_level(i), CHG_FULL, CHG_PART)
	var left: float = me.cooldown_left(i)
	if left <= 0.0:
		return
	var secs := "%.1f" % left
	if me.chg[i] == 0:
		# Sin ninguna: sombra y segundos en grande, como una recarga normal.
		_sector(c, r * 0.92, main.cooldown_fraction(i), Color(0, 0, 0, 0.55))
		_center_text(c, secs, font)
		return
	# Quedan cargas: el botón sigue encendido y el contador va pequeño, abajo a la derecha.
	var cs := font.get_string_size(secs, HORIZONTAL_ALIGNMENT_CENTER, -1, 17)
	var at: Vector2 = c + Vector2(r * 0.62 - cs.x / 2.0, r * 0.82)
	draw_string_outline(font, at, secs, HORIZONTAL_ALIGNMENT_LEFT, -1, 17, 4, Color(0, 0, 0, 0.9))
	draw_string(font, at, secs, HORIZONTAL_ALIGNMENT_LEFT, -1, 17, CHG_FULL)


## Texto grande en el centro de un botón (segundos de recarga o "73%" de la definitiva).
func _center_text(c: Vector2, txt: String, font: Font) -> void:
	var cs := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_CENTER, -1, 22)
	draw_string_outline(font, c + Vector2(-cs.x / 2.0, 8.0), txt,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 22, 4, Color(0, 0, 0, 0.9))
	draw_string(font, c + Vector2(-cs.x / 2.0, 8.0), txt,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(1, 1, 0.8))


## Sector desde las 12 en sentido horario con la recarga pendiente.
func _sector(center: Vector2, radius: float, frac: float, color: Color) -> void:
	if frac <= 0.0:
		return
	var pts := PackedVector2Array([center])
	var n := maxi(3, int(48 * frac))
	for k in n + 1:
		var a := -PI / 2.0 + TAU * frac * k / n
		pts.append(center + Vector2(cos(a), sin(a)) * radius)
	draw_colored_polygon(pts, color)
