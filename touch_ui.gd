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

var main: Node = null


func _draw() -> void:
	if main == null:
		return
	var font := ThemeDB.fallback_font
	# Joystick: base fija y pomo que sigue al dedo, igual que en el juego.
	var jc: Vector2 = main.joy_center()
	_round(TEX.underlay, jc, main.JOY_RADIUS, Color(1, 1, 1, 0.85))
	var knob: Vector2 = jc + main._joy_vec * main.JOY_RADIUS
	_round(TEX.move, knob, main.KNOB_RADIUS * 1.15,
		Color(1, 1, 1, 1.0 if main._joy_idx >= 0 else 0.85))

	for b in main.button_rects():
		if int(b["idx"]) == main.CROUCH_BTN:
			_crouch(b, font)
		elif int(b["idx"]) == main.ORDERS_BTN:
			_orders(b, font)
		else:
			_ability(b, font)


func _ability(b: Dictionary, font: Font) -> void:
	var i: int = b["idx"]
	var c: Vector2 = b["c"]
	var pressed: bool = main._aim_btn == i
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
	if frac > 0.0 and not swap:
		_sector(c, r * 0.92, frac, Color(0, 0, 0, 0.55))
		var cds: String = main.cooldown_text(i)      # segundos, o "73%" si la definitiva va por carga
		var cs := font.get_string_size(cds, HORIZONTAL_ALIGNMENT_CENTER, -1, 22)
		draw_string_outline(font, c + Vector2(-cs.x / 2.0, 8.0), cds,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 22, 4, Color(0, 0, 0, 0.9))
		draw_string(font, c + Vector2(-cs.x / 2.0, 8.0), cds,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(1, 1, 0.8))
	elif int(main._abil(i).get("chg", 0)) > 0 and not swap:
		var chs := "%d/%d" % [main._chg[i], int(main._abil(i)["chg"])]
		var cs2 := font.get_string_size(chs, HORIZONTAL_ALIGNMENT_CENTER, -1, 16)
		var at: Vector2 = c + Vector2(r * 0.55 - cs2.x / 2.0, r * 0.8)
		draw_string_outline(font, at, chs, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, 4, Color(0, 0, 0, 0.9))
		draw_string(font, at, chs, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.8, 1.0, 0.6))

	# Munición de la básica por equipos: un arco por disparo alrededor del botón, como la barra
	# que va debajo de tu vida.
	if i == 0 and main.pf != null and main.pf.ammo_max > 0:
		_ammo_arcs(c, r + 7.0, main.pf.ammo_max, main.pf.ammo_level())

	# Apuntado a mano: anillo de alcance y el icono desplazado hacia donde caerá.
	if pressed and main._aim_drag.length() >= main.AIM_DEAD:
		draw_arc(c, main.AIM_RADIUS, 0.0, TAU, 64, Color(1, 1, 1, 0.45), 2.0)
		_round(icon, c + main._aim_drag.limit_length(main.AIM_RADIUS), r * 0.5, Color(1, 1, 1, 0.9))

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
	var pressed: bool = main._aim_btn == main.ORDERS_BTN
	var order: String = main.pf.minion_order
	draw_circle(c, r * 0.92, Color(0.18, 0.26, 0.2, 0.85) if order != "ambush" else Color(0.3, 0.22, 0.12, 0.9))
	_round(TEX.underlay, c, r * (1.06 if pressed else 1.0), Color(0.8, 1.2, 0.85, 0.95))
	var icon := {"attack": "▲", "regroup": "●", "ambush": "▼"}.get(order, "▲") as String
	var sz := font.get_string_size(icon, HORIZONTAL_ALIGNMENT_LEFT, -1, 28)
	draw_string_outline(font, c + Vector2(-sz.x * 0.5, 10.0), icon, HORIZONTAL_ALIGNMENT_LEFT, -1, 28, 5, Color(0, 0, 0, 0.9))
	draw_string(font, c + Vector2(-sz.x * 0.5, 10.0), icon, HORIZONTAL_ALIGNMENT_LEFT, -1, 28, Color(0.85, 1.0, 0.8))
	if pressed and main._aim_drag.length() >= main.AIM_DEAD:
		draw_arc(c, main.AIM_RADIUS, 0.0, TAU, 64, Color(0.8, 1.0, 0.8, 0.45), 2.0)
		draw_circle(c + main._aim_drag.limit_length(main.AIM_RADIUS), 10.0, Color(0.8, 1.0, 0.8, 0.8))
	var sub := "Esqueletos: %s" % String(b["name"])
	var ss := font.get_string_size(sub, HORIZONTAL_ALIGNMENT_CENTER, -1, 13)
	var ty: float = c.y + r + 15.0
	draw_string_outline(font, Vector2(c.x - ss.x / 2.0, ty), sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, 4, Color(0, 0, 0, 0.9))
	draw_string(font, Vector2(c.x - ss.x / 2.0, ty), sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.85, 1.0, 0.8))


## Agacharse: la misma base que los demás, una flecha hacia abajo y un aro dorado mientras está activo.
func _crouch(b: Dictionary, font: Font) -> void:
	var c: Vector2 = b["c"]
	var r: float = b["r"]
	var on: bool = main._touch_crouch
	# Fondo oscuro propio: los demás botones llevan un icono de color y este solo una flecha, que
	# sobre la hierba no se distinguía.
	draw_circle(c, r * 0.92, Color(0.35, 0.28, 0.08, 0.85) if on else Color(0.05, 0.06, 0.1, 0.6))
	_round(TEX.underlay, c, r, Color(1.3, 1.1, 0.6, 0.95) if on else Color(1, 1, 1, 0.85))
	if on:
		draw_arc(c, r - 3.0, 0.0, TAU, 40, Color(1.0, 0.85, 0.35, 0.95), 4.0, true)
	var arrow := "▼"
	var sz := font.get_string_size(arrow, HORIZONTAL_ALIGNMENT_LEFT, -1, 30)
	draw_string_outline(font, c + Vector2(-sz.x * 0.5, 11.0), arrow, HORIZONTAL_ALIGNMENT_LEFT, -1, 30, 5, Color(0, 0, 0, 0.9))
	draw_string(font, c + Vector2(-sz.x * 0.5, 11.0), arrow, HORIZONTAL_ALIGNMENT_LEFT, -1, 30,
		Color(1.0, 0.9, 0.5) if on else Color(1, 1, 1))
	var sub: String = b["name"]
	var ss := font.get_string_size(sub, HORIZONTAL_ALIGNMENT_CENTER, -1, 13)
	var ty: float = c.y + r + 15.0
	draw_string_outline(font, Vector2(c.x - ss.x / 2.0, ty), sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, 4, Color(0, 0, 0, 0.9))
	draw_string(font, Vector2(c.x - ss.x / 2.0, ty), sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(1, 1, 1, 0.95))


func _round(tex: Texture2D, center: Vector2, radius: float, tint: Color) -> void:
	draw_texture_rect(tex, Rect2(center - Vector2(radius, radius),
		Vector2(radius * 2.0, radius * 2.0)), false, tint)


## Un arco por disparo, desde las 12 en sentido horario: lleno, a medias (el que vuelve) o vacío.
func _ammo_arcs(center: Vector2, radius: float, n: int, level: float) -> void:
	var span := TAU / float(n)
	var gap := 0.16
	for k in n:
		var a0 := -PI / 2.0 + span * k + gap * 0.5
		var a1 := a0 + span - gap
		draw_arc(center, radius, a0, a1, 24, Color(0, 0, 0, 0.6), 8.0, true)
		var fill := AmmoBar.segment_fill(level, k)
		if fill > 0.0:
			var col := AmmoBar.COL_PART if AmmoBar.is_partial(level, k) else AmmoBar.COL_FULL
			draw_arc(center, radius, a0, a0 + (a1 - a0) * fill, 24, col, 5.0, true)


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
