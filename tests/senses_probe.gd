## Sonda: sentidos de las criaturas de la Horda (petición del usuario, 2026-09-17).
##   godot --headless --fixed-fps 60 --path . -- --team=2 --autoplay --near=8 --zombies=20 --probe=senses_probe [--secs=90]
##   godot --headless --fixed-fps 60 --path . -- --team=1 --near=6 --zombies=14 --nozone --probe=senses_probe --hide [--secs=60]
## Comprueba: cada detección cumple las reglas de CreatureSenses; cada grito avisa solo a criaturas a
## 30 m o menos; hay gritos; las criaturas que deambulan se mueven (no se quedan quietas); y con --hide
## (tu leyenda agachada y quieta en la mancha de hierba alta más cercana) nadie te descubre desde más
## lejos de lo que permiten las reglas.
extends Node

const WINDOW := 10.0

var main: Node
var _t := 0.0
var _secs := 90.0
var _hide := false
var _window_t := 0.0
var _start_pos := {}          # criatura (id de nodo) -> posición al empezar la ventana, si deambulaba
var _moved := 0
var _checked := 0
var _problems: Array = []


func _ready() -> void:
	main = get_parent()
	_hide = main._args.has("hide")
	_secs = float(main._args.get("secs", "60" if _hide else "90"))
	if main.horde == null:
		print("senses_probe: FALLO (hace falta la Horda)")
		main.get_tree().quit(1)
		return
	if _hide:
		var c := _nearest_grass()
		if c.x < 0:
			print("senses_probe: FALLO (no hay hierba alta)")
			main.get_tree().quit(1)
			return
		var p: Vector3 = main._cell_pos(c.x, c.y) + Vector3(0, 0.2, 0)
		main.pf.body.global_position = p
		main.pf.prev_pos = p
		main.pf.last_seen = p
		print("[SONDA] escondida en la hierba alta de la celda %s" % c)


func _nearest_grass() -> Vector2i:
	var here: Vector2i = main._cell_of(main.pf.pos())
	var best := Vector2i(-1, -1)
	var best_d := INF
	for x in main.mw:
		for y in main.mh:
			if main.tall_grass[x][y] and MapBuilder.walkable(main.grid[x][y]):
				var d := Vector2(x - here.x, y - here.y).length()
				if d < best_d:
					best_d = d
					best = Vector2i(x, y)
	return best


func _physics_process(delta: float) -> void:
	_t += delta
	if _hide:
		main.input._touch_crouch = true             # agachada todo el rato, sin moverse (nadie la maneja)
	_window_t -= delta
	if _window_t <= 0.0:
		_window_t = WINDOW
		for z in main.horde.zombies:
			var key: int = (z["node"] as Node).get_instance_id()
			if _start_pos.has(key) and float(z["dead_t"]) < 0.0 and z.get("state", "") == "wander" \
					and float(z.get("stun_t", 0.0)) < 100.0:
				_checked += 1
				if Horde._flat_dist(_start_pos[key], (z["node"] as Node3D).global_position) > 3.0:
					_moved += 1
		_start_pos.clear()
		for z in main.horde.zombies:
			if float(z["dead_t"]) < 0.0 and z.get("state", "") == "wander":
				_start_pos[(z["node"] as Node).get_instance_id()] = (z["node"] as Node3D).global_position
	if _t >= _secs or (main.horde_mode != null and main.horde_mode.over):
		_finish()


func _finish() -> void:
	set_physics_process(false)
	var h: Horde = main.horde
	var bad := 0
	for d: Dictionary in h.detections:
		var ok := true
		if d["hidden"]:
			ok = float(d["dist"]) <= (CreatureSenses.HIDDEN_CHASE if d["chasing"] else CreatureSenses.HIDDEN_NEAR)
		else:
			ok = bool(d["los"]) and float(d["dist"]) <= CreatureSenses.sight_range(float(d["night"]))
		if not ok:
			bad += 1
	if bad > 0:
		_problems.append("%d detecciones no cumplen las reglas" % bad)
	for a in h.alerted:
		if float(a) > CreatureSenses.ALERT_RADIUS + 0.01:
			_problems.append("un grito avisó a una criatura a %.1f m" % float(a))
			break
	if not _hide and h.shouts == 0:
		_problems.append("en %.0f s ninguna criatura descubrió a nadie" % _t)
	if _checked >= 3 and float(_moved) / float(_checked) < 0.7:
		_problems.append("solo %d de %d criaturas que deambulaban se movieron más de 3 m en %.0f s" % [_moved, _checked, WINDOW])
	var hidden_seen := 0
	for d: Dictionary in h.detections:
		if d["hidden"]:
			hidden_seen += 1
	print("[SONDA] sentidos en %.0f s: %d detecciones (%d con la leyenda escondida), %d gritos, %d avisadas, deambulando se movieron %d de %d" % [
		_t, h.detections.size(), hidden_seen, h.shouts, h.alerted.size(), _moved, _checked])
	for p in _problems:
		print("[SONDA] problema: %s" % p)
	print("senses_probe: %s" % ("OK" if _problems.is_empty() else "FALLO"))
	main.get_tree().quit(0 if _problems.is_empty() else 1)
