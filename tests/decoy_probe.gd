## Sonda: romper un señuelo de la Ilusionista marca a quien lo rompió (idea del usuario).
##   godot --headless --fixed-fps 60 --path . -- --mode=2v2 --legend=2 --autoplay --probe=decoy_probe [--secs=400]
## Tu leyenda es la Ilusionista (la lleva un bot). Comprueba, durante toda la partida:
##  - cada marca nueva dura Fighter.MARK_TIME y es para el equipo contrario al marcado;
##  - marcado no se puede esconder (Combat.is_hidden da false);
##  - lleva el contorno (MarkFx) si y solo si lo ve tu equipo, y se le quita al acabar;
##  - los bots del equipo que lo marcó apuntan a un marcado (el más cercano, si hay varios) si lo
##    tienen a tiro;
##  - hay al menos una marca (los bots disparan a los señuelos, así que alguno se rompe).
extends Node

var main: Node
var _t := 0.0
var _secs := 400.0
var _prev := {}          # id de leyenda -> marked_t del fotograma anterior
var _expired := {}       # id de leyenda -> segundo de partida en que se le acabó la marca
var _was_alive := {}     # id de leyenda -> ¿vivía en el fotograma anterior?
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
		if f.marked_t <= 0.0 and float(_prev[f.id]) > 0.0:
			_expired[f.id] = _t
		# El contorno se pone o se quita en el tick de la leyenda, que va ANTES del daño y del cambio
		# de ronda: si muere o se le borra la marca en este fotograma, se nota en el siguiente.
		var steady: bool = f.alive() == bool(_was_alive.get(f.id, f.alive())) and \
				(f.marked_t > 0.0) == (float(_prev[f.id]) > 0.0)
		_was_alive[f.id] = f.alive()
		_prev[f.id] = f.marked_t
		if f.marked_t <= 0.0:
			if steady and _has_outline(f):
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
		if steady and _has_outline(f) != should:
			_problems.append("%s: contorno %s (marcado para %d, tú eres %d)" % [f.display_name,
				"puesto" if _has_outline(f) else "sin poner", f.mark_team, main.pf.team])
		# Tras pensar al menos una vez, los bots del equipo que lo marcó apuntan a un marcado: a este o
		# a otro más cercano (con dos marcados a la vez va al de más cerca). Vale también uno al que
		# se le acaba de pasar la marca y todavía no ha vuelto a pensar.
		if age >= BotBrain.THINK + 0.05 and f.alive():
			for o: Fighter in combat.fighters:
				if o.brain == null or o.team != f.mark_team or not o.alive():
					continue
				if o.pos().distance_to(f.pos()) > BotBrain.SEARCH_RANGE - 1.0:
					continue
				var b := o.brain as BotBrain
				var aimed: Fighter = null
				if String(b.target.get("kind", "")) == "fighter":
					aimed = combat.fighter_by_id(int(b.target["fid"]))
				var ok := aimed != null and (aimed.marked_for(o.team) \
						or _t - float(_expired.get(aimed.id, -99.0)) <= BotBrain.THINK + 0.05)
				if not ok:
					_problems.append("%s no apunta a un marcado (marcado %s de hace %.2f s a %.1f m; apunta a %s)" % [
						o.display_name, f.display_name, age, o.pos().distance_to(f.pos()),
						aimed.display_name if aimed != null else String(b.target.get("kind", "nadie"))])
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
