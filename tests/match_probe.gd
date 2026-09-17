## Sonda: una partida por equipos entera entre bots (tu leyenda también la lleva un bot), al mejor
## de 3 rondas.
##   godot --headless --fixed-fps 60 --path . -- --mode=4v4 --autoplay --probe=match_probe [--secs=600]
## Comprueba que la partida acaba, que se juegan al menos 2 rondas, que los dos equipos pelean
## (caídas en ambos lados), que nadie se queda clavado sin moverse y cuánto tardan en encontrarse.
## Imprime rondas, bajas por leyenda y qué tipos de habilidad se lanzaron. Salida 0 si todo va bien.
## Munición de la básica: todas la tienen salvo la Ilusionista, nunca se sale de 0..máximo y alguien
## llega a gastarla (si no, no está enganchada al lanzamiento).
extends Node

var main: Node
var _t := 0.0
var _secs := 600.0
var _hurt := {1: 0.0, 2: 0.0}   # vida perdida por equipo: que los dos reciban es que hay pelea
var _prev_hp := {}
var _moved := {}          # id de leyenda -> metros recorridos
var _last := {}
var _first_hit := -1.0
var _hp0 := {}
var _rules_bad: Array = []   # incumplimientos de la munición o de la activación de trampas
var _ammo_spent := false     # alguien bajó de su máximo
var _down_t := {}            # id -> segundos seguidos derribada (en juego)
var _stuck_down := ""        # alguien derribado mucho más de lo que permiten las reglas
var _downs := 0              # derribos vistos
var _down_ends := {"levantada": [], "muerta": []}   # cuánto duró cada derribo, según cómo acabó


func _ready() -> void:
	main = get_parent()
	_secs = float(main._args.get("secs", "600"))
	if main.team_mode == null:
		print("match_probe: FALLO (hace falta --mode=1v1..4v4)")
		main.get_tree().quit(1)
		return
	for f in main.combat.fighters:
		_last[f.id] = f.pos()
		_moved[f.id] = 0.0
		_hp0[f.id] = f.hp()
		_prev_hp[f.id] = f.hp()
		var want := 0 if String(f.data()["id"]) == "ilusionista" else 3
		if f.ammo_max != want:
			_rules_bad.append("%s con %d de munición máxima (debería %d)" % [f.display_name, f.ammo_max, want])


func _physics_process(delta: float) -> void:
	if main.team_mode == null:
		return
	_t += delta
	for f in main.combat.fighters:
		var p: Vector3 = f.pos()
		var step := Vector2(p.x - _last[f.id].x, p.z - _last[f.id].z).length()
		if step < 2.0:            # una reaparición no es andar
			_moved[f.id] += step
		_last[f.id] = p
		if _first_hit < 0.0 and f.alive() and f.hp() < _hp0[f.id] - 0.5:
			_first_hit = _t
		if f.hp() < float(_prev_hp[f.id]):
			_hurt[f.team] += float(_prev_hp[f.id]) - f.hp()
		_prev_hp[f.id] = f.hp()
		if f.ammo < 0 or f.ammo > f.ammo_max:
			if _rules_bad.size() < 4:
				_rules_bad.append("%s con %d/%d de munición" % [f.display_name, f.ammo, f.ammo_max])
		elif f.ammo < f.ammo_max:
			_ammo_spent = true
		if f.downed and main.team_mode.rules.state == "playing":
			if float(_down_t.get(f.id, 0.0)) == 0.0:
				_downs += 1
			_down_t[f.id] = float(_down_t.get(f.id, 0.0)) + delta
			# 45 s, más lo que pare el reloj mientras la levantan a medias: el doble es imposible.
			if float(_down_t[f.id]) > Revive.BLEED_TIME * 2.0:
				_stuck_down = f.display_name
		else:
			if float(_down_t.get(f.id, 0.0)) > 0.0:
				(_down_ends["levantada" if f.alive() else "muerta"] as Array).append(float(_down_t[f.id]))
			_down_t[f.id] = 0.0
	for t in main.combat.traps:
		if not t["armed"] and float(t["age"]) < Combat.PVP_ARM_TIME - 0.02 and _rules_bad.size() < 4:
			_rules_bad.append("una trampa saltó a los %.2f s, antes de activarse" % float(t["age"]))
	var rules: TeamMatch = main.team_mode.rules
	if rules.state == "over" or _t >= _secs:
		_finish(rules)


func _mean(a: Array) -> float:
	var s := 0.0
	for v in a:
		s += float(v)
	return s / maxf(a.size(), 1.0)


func _finish(rules: TeamMatch) -> void:
	set_physics_process(false)
	var problems: Array = []
	if rules.state != "over":
		problems.append("no acabó en %.0f s (rondas %d-%d)" % [_secs, int(rules.round_wins[1]), int(rules.round_wins[2])])
	elif rules.round < 2:
		problems.append("acabó en %d ronda: al mejor de 3 hacen falta al menos 2" % rules.round)
	if _hurt[1] < 50.0 or _hurt[2] < 50.0:
		problems.append("un equipo apenas recibe daño (%.0f / %.0f): no hay pelea de verdad" % [_hurt[1], _hurt[2]])
	var still: Array = []
	for f in main.combat.fighters:
		if _moved[f.id] < 10.0:
			still.append("%s(%d) %.1fm" % [f.display_name, f.team, _moved[f.id]])
	if not still.is_empty():
		problems.append("leyendas casi sin moverse: %s" % ", ".join(still))
	if main.combat.ult_casts == 0:
		problems.append("nadie lanzó una definitiva: la carga no se llena")
	if _first_hit < 0.0 or _first_hit > 45.0:
		problems.append("tardan demasiado en encontrarse (primer golpe a %.0f s)" % _first_hit)
	problems.append_array(_rules_bad)
	if _stuck_down != "":
		problems.append("%s estuvo derribada más de %.0f s: el derribo no se resuelve" % [_stuck_down, Revive.BLEED_TIME * 2.0])
	if not _ammo_spent:
		problems.append("nadie gastó munición: la básica no la usa")
	var per := []
	for fid in rules.scores:
		var s: Dictionary = rules.scores[fid]
		per.append("%s(%d) %d/%d" % [s["name"], s["team"], s["kills"], s["deaths"]])
	print("[SONDA] %s en %.0f s · %d rondas, ganadas %d-%d · ganador %s · bajas %d-%d · primer golpe a %.1f s" % [
		main.team_mode.mode, _t, rules.round, int(rules.round_wins[1]), int(rules.round_wins[2]),
		str(rules.result.get("winner", "-")), rules.team_kills(1), rules.team_kills(2), _first_hit])
	print("[SONDA] bajas/caídas: %s" % ", ".join(per))
	print("[SONDA] daño recibido por equipo: azul %.0f, rojo %.0f" % [_hurt[1], _hurt[2]])
	print("[SONDA] habilidades lanzadas por tipo: %s · definitivas: %d" % [str(main.combat.casts), main.combat.ult_casts])
	var sources: Array = main.combat.damage_by.keys()
	sources.sort_custom(func(a, b): return main.combat.damage_by[a] > main.combat.damage_by[b])
	var top := []
	for k in sources.slice(0, 8):
		top.append("%s %.0f" % [k, main.combat.damage_by[k]])
	print("[SONDA] daño a leyendas por origen: %s" % ", ".join(top))
	var shots: int = main.combat.soft_hits + main.combat.soft_misses
	print("[SONDA] teledirigidos: %d aciertan, %d fallan (%.0f%% de acierto)" % [main.combat.soft_hits,
		main.combat.soft_misses, 100.0 * main.combat.soft_hits / maxf(shots, 1.0)])
	print("[SONDA] trampas eléctricas: %d puestas, %d saltan nada más activarse, %d pisadas después · balizas Nox: %d puestas, %d reventadas" % [
		int(main.combat.casts.get("trap", 0)), main.combat.traps_on_top, main.combat.traps_sprung,
		int(main.combat.casts.get("beacon", 0)), main.combat.beacons_popped])
	print("[SONDA] rayos de tormenta: %d" % main.combat.storm_strikes)
	var rv: ReviveSystem = main.team_mode.revive
	print("[SONDA] derribos: %d · levantados por un compañero %d · muertos por no levantarlos a tiempo %d · duración media: levantada %.1f s, muerta %.1f s" % [
		_downs, rv.revives, rv.bled_out, _mean(_down_ends["levantada"]), _mean(_down_ends["muerta"])])
	var walked := []
	for f in main.combat.fighters:
		walked.append("%s %.0fm" % [f.display_name, _moved[f.id]])
	print("[SONDA] recorrido: %s" % ", ".join(walked))
	for p in problems:
		print("[SONDA] problema: %s" % p)
	print("match_probe: %s" % ("OK" if problems.is_empty() else "FALLO"))
	main.get_tree().quit(0 if problems.is_empty() else 1)
