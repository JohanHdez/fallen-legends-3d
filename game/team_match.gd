## Reglas de una partida por equipos (1v1 a 4v4) AL MEJOR DE 3 RONDAS (petición del usuario,
## 2026-09-16): una ronda la gana el equipo que deja al rival sin nadie en pie, sin reapariciones
## dentro de la ronda; la partida, el primero que gana ROUNDS_TO_WIN. Entre rondas hay un descanso
## y todo vuelve a su sitio. Lógica pura, sin escena (tests/test_team_match.gd).
##
## Estados: "playing" (ronda en juego), "break" (descanso tras una ronda), "over" (partida acabada).
## Eventos que recoge TeamMode con take_event(): "round_end", "round_start", "over".
class_name TeamMatch
extends RefCounted

const ROUNDS_TO_WIN := 2            # al mejor de 3
const ROUND_TIME := 150.0           # tope de una ronda: el gas debería decidirla antes
const ROUND_BREAK := 4.0            # descanso entre rondas, con el cartel del resultado
const MAX_ROUNDS := 6               # con empates encadenados, se acaba aquí
const FEED_KEEP := 6

var rounds_to_win := ROUNDS_TO_WIN
var round_time := ROUND_TIME
var round := 1
var round_wins := {1: 0, 2: 0}
var round_time_left := ROUND_TIME
var break_t := 0.0
var state := "playing"
## id de leyenda -> {"name", "team", "legend", "kills", "deaths", "is_player"}
var scores := {}
## Últimas bajas, la más antigua primero: {"killer", "victim", "killer_team", "victim_team", "age"}
var feed: Array = []
## Resultado de la última ronda: {"round", "winner": 1 | 2 | 0 (nadie), "reason": "eliminación" | "tiempo"}
var last_round := {}
## Al acabar: {"winner": 1 | 2 | 0 (empate), "rounds": {1: n, 2: n}}
var result := {}
var _events: Array = []


func setup(to_win := ROUNDS_TO_WIN, p_round_time := ROUND_TIME) -> void:
	rounds_to_win = maxi(to_win, 1)
	round_time = maxf(p_round_time, 5.0)
	round = 1
	round_wins = {1: 0, 2: 0}
	round_time_left = round_time
	state = "playing"
	scores.clear()
	feed.clear()
	last_round = {}
	result = {}
	_events.clear()


func add_fighter(fid: int, name: String, team: int, legend: int, is_player := false) -> void:
	scores[fid] = {"name": name, "team": team, "legend": legend, "kills": 0, "downs": 0, "deaths": 0,
		"is_player": is_player}


## La han DERRIBADO: se apunta aparte de la muerte, porque de un derribo se vuelve si un compañero
## llega a tiempo (petición del usuario, 2026-09-18: "faltan las muertes también").
func on_down(fid: int) -> void:
	if state == "playing" and scores.has(fid):
		scores[fid]["downs"] = int(scores[fid]["downs"]) + 1


## Bajas de un equipo en toda la partida (estadística; no decide rondas).
func team_kills(team: int) -> int:
	var total := 0
	for s in scores.values():
		if int(s["team"]) == team:
			total += int(s["kills"])
	return total


## Ha caído `victim_fid` a manos de `killer_fid` (-1 = sin autor: el gas). Anota la caída y, si el
## autor es de OTRO equipo, la baja. Fuera de una ronda en juego no cuenta nada.
func on_kill(killer_fid: int, victim_fid: int) -> Dictionary:
	if state != "playing" or not scores.has(victim_fid):
		return {}
	var victim: Dictionary = scores[victim_fid]
	victim["deaths"] = int(victim["deaths"]) + 1
	var killer: Dictionary = scores.get(killer_fid, {})
	var counted := not killer.is_empty() and killer_fid != victim_fid \
		and int(killer["team"]) != int(victim["team"])
	if counted:
		killer["kills"] = int(killer["kills"]) + 1
	feed.append({"killer": String(killer.get("name", "")), "victim": String(victim["name"]),
		"killer_team": int(killer.get("team", 0)), "victim_team": int(victim["team"]), "age": 0.0})
	while feed.size() > FEED_KEEP:
		feed.pop_front()
	return {"counted": counted, "killer": String(killer.get("name", "")), "victim": String(victim["name"])}


## Tras una caída, con cuántos quedan en pie en cada equipo {1: n, 2: n}: si un equipo se queda
## sin nadie, la ronda es del otro; si caen los dos a la vez, la ronda no es de nadie.
func check_elimination(alive: Dictionary) -> void:
	if state != "playing":
		return
	var a := int(alive.get(1, 0))
	var b := int(alive.get(2, 0))
	if a > 0 and b > 0:
		return
	_end_round(0 if a == 0 and b == 0 else (1 if b == 0 else 2), "eliminación")


## Envejece el registro de bajas (el HUD deja de enseñar cada línea a los 6 s). Aparte de `tick`
## porque un cliente en línea necesita ESTO y nada más: lleva su propia copia de TeamMatch solo para
## pintar, y quien decide rondas y relojes es el servidor (2026-09-20).
func age_feed(delta: float) -> void:
	for e in feed:
		e["age"] = float(e["age"]) + delta


## Avanza relojes. `alive` y `hp` (vida sumada en fracciones, {1: x, 2: y}) deciden la ronda si se
## acaba el tiempo: más leyendas en pie, y si hay las mismas, más vida.
func tick(delta: float, alive := {}, hp := {}) -> void:
	age_feed(delta)
	match state:
		"playing":
			round_time_left -= delta
			if round_time_left <= 0.0:
				round_time_left = 0.0
				_end_round(time_winner(alive, hp), "tiempo")
		"break":
			break_t -= delta
			if break_t <= 0.0:
				round += 1
				round_time_left = round_time
				state = "playing"
				_events.append("round_start")


static func time_winner(alive: Dictionary, hp: Dictionary) -> int:
	var a := int(alive.get(1, 0))
	var b := int(alive.get(2, 0))
	if a != b:
		return 1 if a > b else 2
	var ha := float(hp.get(1, 0.0))
	var hb := float(hp.get(2, 0.0))
	if is_equal_approx(ha, hb):
		return 0
	return 1 if ha > hb else 2


func _end_round(winner: int, reason: String) -> void:
	last_round = {"round": round, "winner": winner, "reason": reason}
	if winner > 0:
		round_wins[winner] = int(round_wins[winner]) + 1
	_events.append("round_end")
	if winner > 0 and int(round_wins[winner]) >= rounds_to_win:
		_finish(winner)
	elif round >= MAX_ROUNDS:
		var a := int(round_wins[1])
		var b := int(round_wins[2])
		_finish(0 if a == b else (1 if a > b else 2))
	else:
		state = "break"
		break_t = ROUND_BREAK


func _finish(winner: int) -> void:
	state = "over"
	result = {"winner": winner, "rounds": {1: int(round_wins[1]), 2: int(round_wins[2])}}
	_events.append("over")


## El siguiente evento pendiente ("" si no hay).
func take_event() -> String:
	return String(_events.pop_front()) if not _events.is_empty() else ""
