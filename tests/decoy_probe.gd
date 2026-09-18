## Sonda: romper un señuelo de la Ilusionista marca a quien lo rompió (idea del usuario).
##   godot --headless --fixed-fps 60 --path . -- --mode=2v2 --legend=2 --autoplay --probe=decoy_probe [--secs=400]
##   godot --headless --fixed-fps 60 --path . -- --mode=2v2 --legend=2 --autoplay --probe=decoy_probe --down-decoys --secs=90
## Tu leyenda es la Ilusionista (la lleva un bot). Comprueba, durante toda la partida:
##  - cada marca nueva dura Fighter.MARK_TIME y es para el equipo contrario al marcado;
##  - marcado no se puede esconder (Combat.is_hidden da false);
##  - lleva el contorno (MarkFx) si y solo si lo ve tu equipo, y se le quita al acabar;
##  - los bots del equipo que lo marcó apuntan a un marcado (el más cercano, si hay varios) si lo
##    tienen a tiro;
##  - sus señuelos llevan su mismo letrero y, si está derribada, la misma animación de arrastrarse y
##    a su paso (petición del usuario, 2026-09-17). Casi nunca cae con señuelos fuera, así que
##    --down-decoys la tumba la primera vez que tiene uno y exige haberlo comprobado un rato;
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
var _downed_decoy_t := 0.0   # segundos con la Ilusionista derribada y algún señuelo suyo vivo
var _down_for := 0.0         # cuánto lleva derribada (lo del fotograma de caer se ve en el siguiente)
var _down_decoys := false    # --down-decoys: tumbarla en cuanto tenga un señuelo
var _forced := false
var _decoy_pos := {}         # id del cuerpo del señuelo -> posición del fotograma anterior
var _lag := {}               # id del cuerpo del señuelo -> [qué no copia, fotogramas seguidos]
var _born := {}              # id del cuerpo de un señuelo -> [segundo en que salió, modo, vida que le quedaba]
var _lifetimes := {1: [], 2: []}   # modo (1 fiesta, 2 señuelo) -> segundos que duró cada uno
var _broken := {1: 0, 2: 0}        # modo -> cuántos se rompieron antes de tiempo


func _ready() -> void:
	main = get_parent()
	_secs = float(main._args.get("secs", "400"))
	_down_decoys = main._args.has("down-decoys")
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
	# Las marcas que se acaban en este fotograma, antes de mirar a nadie: si no, un bot que apuntaba a
	# un marcado que va después en la lista parecería no apuntar a ninguno.
	for f: Fighter in combat.fighters:
		if f.marked_t <= 0.0 and float(_prev[f.id]) > 0.0:
			_expired[f.id] = _t
	for f: Fighter in combat.fighters:
		if f.marked_t > float(_prev[f.id]) + 0.5:
			_marks += 1
			if absf(f.marked_t - Fighter.MARK_TIME) > 0.05:
				_problems.append("%s marcado con %.2f s (debería %.1f)" % [f.display_name, f.marked_t, Fighter.MARK_TIME])
			if f.mark_team == f.team or f.mark_team < 0:
				_problems.append("%s marcado para su propio equipo (%d)" % [f.display_name, f.mark_team])
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
				# Recién levantado (reanimado o vuelto solo): aún no ha pensado con su objetivo nuevo.
				if o.invuln_t > Revive.INVULN - BotBrain.THINK - 0.05:
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
	_check_decoys(delta)
	_track_lifetimes()
	var rules: TeamMatch = main.team_mode.rules
	if rules.state == "over" or _t >= _secs:
		_finish()


## Sus señuelos la copian en todo, también derribada: la misma animación de arrastrarse, el mismo
## letrero encima ("¡DERRIBADO! 32 s") y a paso de arrastrarse. Si no, se sabría al momento cuál es la
## de verdad (petición del usuario, 2026-09-17).
func _check_decoys(delta: float) -> void:
	var pf: Fighter = main.pf
	if _down_decoys and not _forced and pf.alive() and pf.invuln_t <= 0.0 \
			and main.team_mode.rules.state == "playing" and not main.combat.decoy_alive(pf).is_empty():
		for o: Fighter in main.combat.fighters:
			if o.team != pf.team and o.alive():
				_forced = true
				main.combat.hurt(pf.rec, pf.hp_max() * 10.0, 0.0, o)
				print("[SONDA] tumbada con señuelos a los %.1f s" % _t)
				break
	_down_for = _down_for + delta if pf.downed else 0.0
	var text: String = pf.label.text if pf.label != null else ""
	var cur: String = pf.anim.current_animation if pf.anim != null else ""
	var any := false
	for al in main.combat.allies:
		if al["kind"] != "decoy" or int(al.get("owner", -1)) != pf.id or float(al["hp"]) <= 0.0:
			continue
		var body: Node3D = al["node"]
		var id := body.get_instance_id()
		var was: Vector3 = _decoy_pos.get(id, body.global_position)
		_decoy_pos[id] = body.global_position
		# El señuelo copia a su leyenda en el mundo, que va antes de que ella cambie de letrero o de
		# animación: va un fotograma por detrás. Solo es fallo si la diferencia dura dos seguidos.
		var why := ""
		var dl: Label3D = al.get("label")
		if pf.label != null and (dl == null or dl.text != text):
			why = "señuelo con otro letrero (él: %s, ella: %s)" % [dl.text if dl != null else "ninguno", text]
		elif _down_for >= 0.1:
			any = true
			var bar: Node3D = al["bar"]
			if not cur.begins_with(Revive.DOWNED_STATE):
				why = "derribada con la animación %s" % cur
			elif pf.bar != null and bar != null and bar.visible != pf.bar.visible:
				why = "señuelo con la barra %s y ella sin barra, derribada" % ("a la vista" if bar.visible else "escondida")
			else:
				for ap in al["anims"]:
					if (ap as AnimationPlayer).current_animation != cur:
						why = "señuelo con otra animación con la Ilusionista derribada (él: %s, ella: %s)" % [
							(ap as AnimationPlayer).current_animation, cur]
			var moved := Vector2(body.global_position.x - was.x, body.global_position.z - was.z).length()
			if why == "" and moved > pf.speed() * Revive.CRAWL_SPEED * delta * 1.5 + 0.01:
				why = "señuelo a %.1f m/s con ella derribada (arrastrándose va a %.1f)" % [
					moved / delta, pf.speed() * Revive.CRAWL_SPEED]
		# Por tipo (lo que va antes de los dos puntos o del paréntesis): dos desfases distintos en
		# fotogramas seguidos (animación en uno, letrero en el siguiente) no son un fallo.
		var kind := why.get_slice("(", 0)
		var prev: Array = _lag.get(id, ["", 0])
		var n := 0
		if why != "":
			n = int(prev[1]) + 1 if kind == String(prev[0]) else 1
		_lag[id] = [kind, n]
		if n >= 2:
			_problems.append(why)
			return
	if any:
		_downed_decoy_t += delta


## Cuánto duran de verdad los señuelos (la Fiesta dice 20 s, pero se los pueden romper antes).
func _track_lifetimes() -> void:
	var seen := {}
	for al in main.combat.allies:
		if al["kind"] != "decoy":
			continue
		var id: int = (al["node"] as Node3D).get_instance_id()
		seen[id] = true
		if not _born.has(id):
			_born[id] = [_t, int(al["mode"]), 0.0]
			# Los clones de la Fiesta aguantan como las leyendas (vida ×3 por equipos; petición del
			# usuario, 2026-09-17: con 60 duraban 5,5 s de los 20); el Señuelo se sigue rompiendo pronto.
			var owner: Fighter = main.combat.fighter_by_id(int(al["owner"]))
			var want := Combat.DECOY_HP * (owner.hp_mult if int(al["mode"]) == 1 else 1.0)
			if absf(float(al["hpmax"]) - want) > 0.01:
				_problems.append("señuelo (modo %d) con %.0f de vida (debería %.0f)" % [int(al["mode"]), float(al["hpmax"]), want])
		(_born[id] as Array)[2] = float(al["life"])
	for id in _born.keys():
		if seen.has(id):
			continue
		var b: Array = _born[id]
		(_lifetimes[int(b[1])] as Array).append(_t - float(b[0]))
		if float(b[2]) > 0.1:
			_broken[int(b[1])] = int(_broken[int(b[1])]) + 1
		_born.erase(id)


func _mean(a: Array) -> float:
	var s := 0.0
	for v in a:
		s += float(v)
	return s / maxf(a.size(), 1)


func _has_outline(f: Fighter) -> bool:
	if f.model == null:
		return false
	for mi in f.model.find_children("*", "MeshInstance3D", true, false):
		if (mi as MeshInstance3D).material_overlay == MarkFx.material():
			return true
	return false


func _finish() -> void:
	set_physics_process(false)
	if _down_decoys and _downed_decoy_t < 0.2:
		_problems.append("solo %.1f s con ella derribada y señuelos (tumbada: %s)" % [_downed_decoy_t, _forced])
	if _marks == 0:
		_problems.append("nadie quedó marcado en %.0f s: romper un señuelo no marca" % _t)
	print("[SONDA] señuelos: %d marcas, %.1f s marcados en total, %.1f s con ella derribada y señuelos, partida de %.0f s" % [
		_marks, _marked_time, _downed_decoy_t, _t])
	print("[SONDA] duran: fiesta %.1f s de media (%d clones, %d rotos antes de tiempo) · señuelo %.1f s (%d, %d rotos)" % [
		_mean(_lifetimes[1]), (_lifetimes[1] as Array).size(), _broken[1],
		_mean(_lifetimes[2]), (_lifetimes[2] as Array).size(), _broken[2]])
	for p in _problems:
		print("[SONDA] problema: %s" % p)
	print("decoy_probe: %s" % ("OK" if _problems.is_empty() else "FALLO"))
	main.get_tree().quit(0 if _problems.is_empty() else 1)
