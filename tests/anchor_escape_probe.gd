## Sonda: del remolino del Ancla clavada se puede salir (petición del usuario, 2026-11-05: "el ancla
## que los atrae es imposible de escapar").
##   godot --headless --fixed-fps 60 --path . -- --mode=1v1 --legend=N --nozone --probe=anchor_escape_probe [--run]
## Clava el Ancla clavada del rival (Combat.cast_buff con los datos del Rompemareas) justo donde está
## tu leyenda, deja al rival aturdido para que no meta daño propio y te hace huir en línea recta hacia
## un lado libre, caminando (o corriendo con --run). Mide cuánto tardas en salir de los 4,7 m y cuánto
## daño te hace el remolino. Exige salir antes de que acabe (5 s).
## Salida 0 si sales, 1 si no.
extends Node

var main: Node
var _t := 0.0
var _foe: Fighter = null
var _dir := Vector3.ZERO
var _run := false
var _cast := false
var _hp0 := 0.0
var _out_t := -1.0
var _end_t := 0.0


func _ready() -> void:
	main = get_parent()
	_run = main._args.has("run")
	if main.team_mode == null:
		print("anchor_escape_probe: FALLO (hace falta --mode=1v1)")
		main.get_tree().quit(1)


func _physics_process(delta: float) -> void:
	_t += delta
	var pf: Fighter = main.pf
	if _foe == null:
		for f: Fighter in main.combat.fighters:
			if f.team != pf.team:
				_foe = f
	if _foe == null:
		return
	_foe.rec["stun_t"] = 1.0              # quieto y sin lanzar: el único daño es el del remolino
	if not _cast:
		if _t < 1.5:
			return
		_dir = _free_dir(pf)
		if _dir == Vector3.ZERO:
			_finish("no hay ningún lado libre de 6 m para huir")
			return
		var ab: Dictionary = LegendData.ABILITIES["rompemareas"][2]
		main.combat.cast_buff(_foe, ab, pf.pos(), float(ab["rad"]) * LegendData.PX)
		_foe.buff_at = Vector3(pf.pos().x, 0.0, pf.pos().z)
		_hp0 = pf.hp()
		_end_t = _t + float(ab["dur"])
		_cast = true
	# Huir: main mueve a tu leyenda con wish 0 (sin teclado); aquí se la mueve como si pulsaras.
	pf.wish = _dir
	pf.run = _run
	main.combat.move_fighter(pf, delta)
	var d := Vector2(pf.pos().x - _foe.buff_at.x, pf.pos().z - _foe.buff_at.z).length()
	if _out_t < 0.0 and d > _foe.buff_rad:
		_out_t = _t - (_end_t - 5.0)
	if _t >= _end_t + 0.2 or not pf.alive():
		_finish("")


## Un lado hacia el que se pueda andar 6 m sin chocar.
func _free_dir(pf: Fighter) -> Vector3:
	for k in 8:
		var a := TAU * k / 8.0
		var dir := Vector3(cos(a), 0.0, sin(a))
		if not pf.body.test_move(pf.body.global_transform, dir * 6.0):
			return dir
	return Vector3.ZERO


func _finish(err: String) -> void:
	set_physics_process(false)
	if err != "":
		print("anchor_escape_probe: FALLO (%s)" % err)
		get_tree().quit(1)
		return
	var pf: Fighter = main.pf
	var how := "corriendo" if _run else "caminando"
	print("[SONDA] anchor_escape_probe: %s (%s, %.1f m/s) · %s · %.0f de daño del remolino" % [
		String(pf.data()["name"]), how, pf.speed() * (Combat.RUN_MULT if _run else 1.0),
		("sale a los %.1f s" % _out_t) if _out_t >= 0.0 else "NO sale en 5 s", _hp0 - pf.hp()])
	if _out_t < 0.0:
		print("anchor_escape_probe: FALLO")
		get_tree().quit(1)
		return
	print("anchor_escape_probe: OK")
	get_tree().quit(0)
