## Sonda: la Horda en equipo con bots, de principio a fin.
##   godot --headless --fixed-fps 60 --path . -- --team=4 --autoplay --probe=horde_probe [--secs=420]
##   godot --headless --fixed-fps 60 --path . -- --team=1 --autoplay --probe=horde_probe --down-player=15 --expect-defeat --secs=40
##   godot --headless --fixed-fps 60 --path . -- --team=4 --autoplay --probe=horde_probe --down-one=20 --secs=120
## Comprueba: el equipo es de --team leyendas del equipo 1 con leyendas distintas; las criaturas
## golpean a más de una leyenda (van a por todo el equipo, no solo a ti); pasan oleadas; con caídas
## hay reanimaciones o vueltas solas; ninguna leyenda caída queda para siempre si hay alguien en pie;
## con --expect-defeat la partida acaba en derrota antes del tope; y con --down-one=S tumba a un
## compañero bot a los S s (los bots casi no caen) y exige que se levante antes de 70 s; --down-player=S
## tumba a tu leyenda (para probar la derrota sin depender del balance). Imprime oleada, bajas, caídas,
## reanimaciones y tiempo.
extends Node

var main: Node
var _t := 0.0
var _secs := 420.0
var _expect_defeat := false
var _hit_by_creature := {}   # id de leyenda -> true si una criatura le quitó vida
var _prev_hp := {}
var _max_down := {}          # id -> segundos seguidos derribada, lo más largo
var _down_t := {}
var _problems: Array = []
var _down_at := -1.0         # --down-one: cuándo tumbar a un compañero
var _downed: Fighter = null
var _stood_up_at := -1.0
var _down_player_at := -1.0  # --down-player: cuándo tumbarte a ti


func _ready() -> void:
	main = get_parent()
	_secs = float(main._args.get("secs", "420"))
	_expect_defeat = main._args.has("expect-defeat")
	_down_at = float(main._args.get("down-one", "-1"))
	_down_player_at = float(main._args.get("down-player", "-1"))
	if main.horde_mode == null:
		print("horde_probe: FALLO (hace falta la Horda, sin --mode)")
		main.get_tree().quit(1)
		return
	var hm: HordeMode = main.horde_mode
	var team: Array = hm.team()
	if team.size() != hm.size:
		_problems.append("el equipo tiene %d leyendas y debería tener %d" % [team.size(), hm.size])
	var seen := {}
	for f: Fighter in team:
		if seen.has(f.legend):
			_problems.append("leyenda repetida en el equipo: %s" % f.display_name)
		seen[f.legend] = true
		_prev_hp[f.id] = f.hp()
		_down_t[f.id] = 0.0
		_max_down[f.id] = 0.0


func _physics_process(delta: float) -> void:
	var hm: HordeMode = main.horde_mode
	if hm == null:
		return
	_t += delta
	if _down_at >= 0.0 and _downed == null and _t >= _down_at:
		for f: Fighter in hm.team():
			if not f.is_player and f.alive():
				_downed = f
				f.invuln_t = 0.0
				main.combat.hurt(f.rec, 1e6)
				_prev_hp[f.id] = 0.0          # este golpe no es de una criatura
				print("[SONDA] tumbado a propósito: %s a los %.0f s" % [f.display_name, _t])
				break
	if _down_player_at >= 0.0 and _t >= _down_player_at and main.pf.alive():
		main.pf.invuln_t = 0.0
		main.combat.hurt(main.pf.rec, 1e6)
		_prev_hp[main.pf.id] = 0.0
		_down_player_at = -1.0
		print("[SONDA] tumbada a propósito: tu leyenda a los %.0f s" % _t)
	if _downed != null and _stood_up_at < 0.0 and _downed.alive():
		_stood_up_at = _t
	for f: Fighter in hm.team():
		# Daño de criatura: baja la vida sin estar en el gas.
		if f.hp() < float(_prev_hp[f.id]) - 0.01 and not main._outside_zone(f.pos()):
			_hit_by_creature[f.id] = true
		_prev_hp[f.id] = f.hp()
		if f.downed:
			_down_t[f.id] = float(_down_t[f.id]) + delta
			_max_down[f.id] = maxf(float(_max_down[f.id]), float(_down_t[f.id]))
		else:
			_down_t[f.id] = 0.0
	if hm.over or _t >= _secs:
		_finish(hm)


func _finish(hm: HordeMode) -> void:
	set_physics_process(false)
	for f: Fighter in hm.team():
		# 45 s derribada, más lo que pare el reloj mientras la levantan a medias: el doble es imposible.
		if float(_max_down[f.id]) > Revive.BLEED_TIME * 2.0:
			_problems.append("%s estuvo derribada %.0f s: el derribo no se resuelve" % [f.display_name, float(_max_down[f.id])])
	# En partidas cortas los bots matan a las criaturas antes de que lleguen: se mira desde 5 min.
	if hm.size >= 2 and _t >= 300.0 and _hit_by_creature.size() < 2:
		_problems.append("las criaturas solo golpearon a %d leyenda(s) del equipo" % _hit_by_creature.size())
	if _down_at >= 0.0:
		if _downed == null:
			_problems.append("no hubo a quién tumbar")
		elif _stood_up_at < 0.0:
			_problems.append("%s no se levantó en %.0f s" % [_downed.display_name, _t - _down_at])
		else:
			print("[SONDA] %s se levantó a los %.1f s de caer" % [_downed.display_name, _stood_up_at - _down_at])
	if _expect_defeat and not hm.over:
		_problems.append("se esperaba derrota y la partida sigue a los %.0f s" % _t)
	if not _expect_defeat and main.horde.wave < 2:
		_problems.append("no pasó de la oleada %d en %.0f s" % [main.horde.wave, _t])
	var per := []
	for f: Fighter in hm.team():
		per.append("%s %d/%d" % [f.display_name, hm.kills_of(f), f.deaths])
	print("[SONDA] horda de %d en %.0f s · oleada %d · %s · derrota %s" % [hm.size, _t, main.horde.wave,
		", ".join(per), "sí" if hm.over else "no"])
	print("[SONDA] derribos: %d levantados, %d muertos por no levantarlos a tiempo · golpeados por criaturas: %d de %d" % [
		hm.revive.revives, hm.revive.bled_out, _hit_by_creature.size(), hm.size])
	for p in _problems:
		print("[SONDA] problema: %s" % p)
	print("horde_probe: %s" % ("OK" if _problems.is_empty() else "FALLO"))
	main.get_tree().quit(0 if _problems.is_empty() else 1)
