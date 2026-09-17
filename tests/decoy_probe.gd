## Sonda: romper un señuelo de la Ilusionista marca a quien lo rompió (idea del usuario).
##   godot --headless --fixed-fps 60 --path . -- --mode=2v2 --legend=2 --autoplay --probe=decoy_probe [--secs=400]
## Tu leyenda es la Ilusionista (la lleva un bot). Comprueba, durante toda la partida:
##  - cada marca nueva dura Fighter.MARK_TIME y es para el equipo contrario al marcado;
##  - marcado no se puede esconder (Combat.is_hidden da false);
##  - lleva el contorno (MarkFx) si y solo si lo ve tu equipo, y se le quita al acabar;
##  - los bots del equipo que lo marcó lo eligen como objetivo si lo tienen a tiro;
##  - hay al menos una marca (los bots disparan a los señuelos, así que alguno se rompe).
extends Node

var main: Node
var _t := 0.0
var _secs := 400.0
var _prev := {}          # id de leyenda -> marked_t del fotograma anterior
var _marks := 0
var _marked_time := 0.0
var _problems: Array = []


func _ready() -> void:
	main = get_parent()
	_secs = float(main._args.get("secs", "400"))
	if main.team_mode == null:
		print("decoy_probe: FALLO (hace falta --mode=1v1..4v4)")
		main.get_tree().quit(1)
		return
	if String(main.pf.data()["id"]) != "ilusionista":
		print("decoy_probe: FALLO (hace falta --legend=2, la Ilusionista)")
		main.get_tree().quit(1)
		return
	for f in main.combat.fighters:
		_prev[f.id] = 0.0


func _physics_process(delta: float) -> void:
	if main.team_mode == null:
		return
	if _problems.size() >= 6:
		_finish()                # con seis fallos basta: no hace falta seguir la partida
		return
	_t += delta
	var combat: Combat = main.combat
	for f: Fighter in combat.fighters:
		if f.marked_t > float(_prev[f.id]) + 0.5:
			_marks += 1
			if absf(f.marked_t - Fighter.MARK_TIME) > 0.05:
				_problems.append("%s marcado con %.2f s (debería %.1f)" % [f.display_name, f.marked_t, Fighter.MARK_TIME])
			if f.mark_team == f.team or f.mark_team < 0:
				_problems.append("%s marcado para su propio equipo (%d)" % [f.display_name, f.mark_team])
		_prev[f.id] = f.marked_t
		if f.marked_t <= 0.0:
			if _has_outline(f):
				_problems.append("%s sigue con contorno sin estar marcado" % f.display_name)
			continue
		_marked_time += delta
		if combat.is_hidden(f):
			_problems.append("%s marcado pero escondido" % f.display_name)
		# Lo que pasa en el fotograma de la marca se ve en el siguiente: se mira con algo de margen.
		var age := Fighter.MARK_TIME - f.marked_t
		if age < 0.05:
			continue
		var should: bool = f.alive() and f.mark_team == main.pf.team
		if _has_outline(f) != should:
			_problems.append("%s: contorno %s (marcado para %d, tú eres %d)" % [f.display_name,
				"puesto" if _has_outline(f) else "sin poner", f.mark_team, main.pf.team])
		# Tras pensar al menos una vez, los bots del equipo que lo marcó van a por él.
		if age >= BotBrain.THINK + 0.05 and f.alive():
			for o: Fighter in combat.fighters:
				if o.brain == null or o.team != f.mark_team or not o.alive():
					continue
				if o.pos().distance_to(f.pos()) > BotBrain.SEARCH_RANGE - 1.0:
					continue
				var b := o.brain as BotBrain
				if b.target.is_empty() or b.target.get("node") != f.body:
					_problems.append("%s no apunta al marcado %s" % [o.display_name, f.display_name])
	var rules: TeamMatch = main.team_mode.rules
	if rules.state == "over" or _t >= _secs:
		_finish()


func _has_outline(f: Fighter) -> bool:
	if f.model == null:
		return false
	for mi in f.model.find_children("*", "MeshInstance3D", true, false):
		if (mi as MeshInstance3D).material_overlay == MarkFx.material():
			return true
	return false


func _finish() -> void:
	set_physics_process(false)
	if _marks == 0:
		_problems.append("nadie quedó marcado en %.0f s: romper un señuelo no marca" % _t)
	print("[SONDA] señuelos: %d marcas, %.1f s marcados en total, partida de %.0f s" % [_marks, _marked_time, _t])
	for p in _problems:
		print("[SONDA] problema: %s" % p)
	print("decoy_probe: %s" % ("OK" if _problems.is_empty() else "FALLO"))
	main.get_tree().quit(0 if _problems.is_empty() else 1)
