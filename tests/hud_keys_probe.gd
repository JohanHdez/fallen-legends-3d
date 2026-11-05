## Sonda: el HUD de la esquina es UNA línea, sin teclas ni habilidades, y las habilidades se ven
## como botones en pantalla también con teclado.
##   godot --headless --fixed-fps 60 --path . -- --mode=2v2 --autoplay --touch --probe=hud_keys_probe
##   godot --headless --fixed-fps 60 --path . -- --mode=2v2 --autoplay --probe=hud_keys_probe
##   godot --headless --fixed-fps 60 --path . -- --autoplay --probe=hud_keys_probe          # Horda
## Historia: el 2026-09-20 el usuario pidió quitar las teclas con el dedo ("yo estoy en un celular, a
## mí no me sirve ese texto"); el 2026-11-05, que la esquina tenía demasiado texto y que en PC las
## habilidades con Q/E/R no se veían. Desde entonces las teclas están en la pausa, y las habilidades
## son los botones de touch_ui.gd en los dos modos (con teclado, con "Clic izq / Clic der / Espacio").
## No se puede comprobar con una captura: con `--shot`, main._process sale antes de escribir el HUD.
## Salida 0 si se cumple, 1 si no.
extends Node

## Cualquiera de estas en el HUD significa que se están explicando controles de teclado y ratón.
const KEY_WORDS := ["WASD", "clic", "Clic", "Shift", "Ctrl", "Esc", "rueda", "F10", "Espacio"]

var main: Node
var _t := 0.0
var _secs := 12.0
var _checked := 0
var _bad: Array = []


func _ready() -> void:
	main = get_parent()
	_secs = float(main._args.get("secs", "12"))


func _process(delta: float) -> void:
	_t += delta
	# Deja que arranque la partida (el HUD se escribe en cada fotograma de main._process).
	if _t < 2.0:
		return
	var text := String(main.hud.text) if main.hud != null else ""
	if main.team_mode == null and text == "":
		if _t > _secs:
			_finish(["el HUD de la Horda nunca escribió nada en %.0f s" % _secs])
		return
	_checked += 1
	for w: String in KEY_WORDS:
		if w in text:
			_bad.append("el HUD nombra teclas (%s): %s" % [w, text])
			break
	if "\n" in text:
		_bad.append("el HUD ocupa más de una línea: %s" % text.replace("\n", " / "))
	for i in 3:
		var n := String(main._abil(i)["n"])
		if n in text:
			_bad.append("el HUD repite en texto la habilidad '%s', que ya tiene botón: %s" % [n, text])
	if main.team_mode == null and not ("OLEADA" in text):
		_bad.append("el HUD de la Horda no dice la oleada: %s" % text)
	# Los botones: en los dos modos tiene que existir la capa y dar las tres habilidades.
	if main.touch_ui == null:
		_bad.append("no hay botones de habilidad en pantalla (touch_ui)")
	else:
		var abil := 0
		for b: Dictionary in main.input.button_rects():
			if int(b["idx"]) <= 2:
				abil += 1
				if not bool(main.touch) and String(b.get("key", "")) == "":
					_bad.append("con teclado, el botón %d no dice qué tecla lo lanza" % int(b["idx"]))
		if abil != 3:
			_bad.append("hay %d botones de habilidad, no 3" % abil)
	if not _bad.is_empty() or _checked >= 120:
		_finish(_bad)


func _finish(bad: Array) -> void:
	set_process(false)
	var mode := "táctil" if bool(main.touch) else "teclado"
	if bad.is_empty():
		print("[SONDA] hud_keys_probe (%s): %d fotogramas mirados; el HUD dice: %s" % [
			mode, _checked, String(main.hud.text)])
		print("hud_keys_probe: OK")
		get_tree().quit(0)
		return
	for b: String in bad:
		print("FALLO: %s" % b)
	print("hud_keys_probe: FALLO (%s)" % mode)
	get_tree().quit(1)
