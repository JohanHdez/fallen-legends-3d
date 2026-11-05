## Piezas de UI de los menús construidos en código (menú de inicio y sala en línea): etiqueta con
## contorno y botón redondeado, de 64 px o más para el dedo. Son las de ModeMenu, sacadas aquí al
## añadir la sala (2026-09-18) para no copiarlas.
class_name UiKit
extends RefCounted

const GOLD := Color(1.0, 0.82, 0.38)
const SYMBOL_FONT := "res://ui/fonts/DejaVuSans.ttf"


## La fuente por defecto de Godot (Open Sans) no trae ◀ ▶ ▲ ▼ ● ○ ↔ ☰ ✕. En escritorio y Android
## los presta la fuente del sistema, pero en la web no hay sistema: salían cuadritos con el código
## (2026-11-04). DejaVu Sans (licencia libre, ui/fonts/DejaVuSans-LICENSE.txt) va de respaldo de la
## fuente por defecto, así que basta con llamarla una vez al arrancar; repetirla no duplica nada.
static func install_symbol_font() -> void:
	var sym: Font = load(SYMBOL_FONT)
	for f: Font in [ThemeDB.fallback_font, ThemeDB.get_default_theme().default_font]:
		if f == null or f.fallbacks.has(sym):
			continue
		var fb := f.fallbacks.duplicate()
		fb.append(sym)
		f.fallbacks = fb


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


## Marca el botón que está puesto ahora mismo (el modo de la sala, el tamaño del equipo, tu equipo):
## fondo dorado y borde dorado, o el suyo de siempre si no lo está. Hace falta porque un botón
## deshabilitado se dibuja con el estilo `disabled` del tema, que tapa el de "pulsado": en la sala,
## quien no es líder veía los cinco modos iguales y no sabía si jugaba un 1VS1 o un 4VS4 (se vio en
## la captura de la sala, 2026-09-20).
static func mark(b: Button, on: bool, base := Color(0.16, 0.18, 0.26)) -> void:
	for st in ["normal", "disabled"]:
		var s := StyleBoxFlat.new()
		s.bg_color = GOLD.darkened(0.45) if on else (base.darkened(0.3) if st == "disabled" else base)
		s.set_corner_radius_all(12)
		s.border_color = GOLD if on else Color(1, 1, 1, 0.08)
		s.set_border_width_all(2)
		b.add_theme_stylebox_override(st, s)
	b.add_theme_color_override("font_disabled_color", Color(1, 0.95, 0.85) if on else Color(0.58, 0.59, 0.66))
