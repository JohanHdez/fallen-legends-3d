## Sonda: el HUD de la esquina no explica el teclado cuando juegas con el dedo.
##   godot --headless --fixed-fps 60 --path . -- --mode=2v2 --autoplay --touch --probe=hud_keys_probe
##   godot --headless --fixed-fps 60 --path . -- --team=2 --autoplay --probe=hud_keys_probe
## Petición del usuario (2026-09-20): "aparecen descripciones de cómo juegas en PC, pero yo estoy en
## un celular, a mí no me sirve ese texto". Con `--touch` el HUD no debe nombrar ninguna tecla; sin
## él tiene que seguir nombrándolas (el escritorio no pierde nada). Vale para la Horda y por equipos.
## No se puede comprobar con una captura: con `--shot`, main._process sale antes de escribir el HUD.
## Salida 0 si se cumple, 1 si no.
extends Node

## Cualquiera de estas en el HUD significa que se están explicando controles de teclado y ratón.
const KEY_WORDS := ["WASD", "clic", "Shift", "Ctrl", "Esc", "rueda", "F10"]

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
	if text == "":
		if _t > _secs:
			_finish(["el HUD nunca escribió nada en %.0f s" % _secs])
		return
	var found: Array = []
	for w: String in KEY_WORDS:
		if w in text:
			found.append(w)
	_checked += 1
	if bool(main.touch) and not found.is_empty():
		_bad.append("con el dedo, el HUD nombra teclas: %s" % str(found))
	elif not bool(main.touch) and found.is_empty():
		_bad.append("con teclado, el HUD dejó de nombrar las teclas: %s" % text.replace("\n", " / "))
	# También hay que seguir viendo lo que importa: tu nombre y tu vida.
	if not ("vida" in text or "CAÍDO" in text):
		_bad.append("el HUD no dice tu vida: %s" % text.replace("\n", " / "))
	if not _bad.is_empty() or _checked >= 120:
		_finish(_bad)


func _finish(bad: Array) -> void:
	set_process(false)
	var mode := "táctil" if bool(main.touch) else "teclado"
	if bad.is_empty():
		print("[SONDA] hud_keys_probe (%s): %d fotogramas mirados; el HUD dice: %s" % [
			mode, _checked, String(main.hud.text).replace("\n", " / ")])
		print("hud_keys_probe: OK")
		get_tree().quit(0)
		return
	for b: String in bad:
		print("FALLO: %s" % b)
	print("hud_keys_probe: FALLO (%s)" % mode)
	get_tree().quit(1)
