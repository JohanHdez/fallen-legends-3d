## Reglas de la sala del juego en línea, sin red: quién es el líder, en qué equipo y con qué leyenda
## está cada uno, quién está listo, si se puede empezar y el reparto de plazas (humanos y bots) al
## empezar. La usan el servidor (la de verdad) y los clientes (una copia, para pintar la sala). Pura
## para probarla con `godot -s` (tests/test_lobby_rules.gd). Portada de las reglas de sala de
## scripts/net.gd del 2D con los modos del 3D; diseño en
## docs/superpowers/specs/2026-09-18-juego-en-linea-design.md.
class_name LobbyRules
extends RefCounted

const MAX_PLAYERS := 8        # un 4v4 lleno

var players := {}             # id de peer -> {"name": String, "team": int, "legend": int, "ready": bool}
var order: Array = []         # ids por orden de llegada: si se va el líder, lo es el siguiente
var mode := "2v2"
var horde_team := HordeMode.MAX_TEAM   # Horda: plazas del equipo (humanos + bots)
var leader := 0               # 0 = nadie


func is_horde() -> bool:
	return mode == "horda"


## Plazas por equipo: las del modo por equipos o, en la Horda, las que eligió el líder.
func team_size() -> int:
	return horde_team if is_horde() else GameModes.team_size(mode)


## Humanos que caben: en la Horda, HordeMode.MAX_TEAM; por equipos, los dos equipos llenos.
func capacity() -> int:
	return HordeMode.MAX_TEAM if is_horde() else GameModes.team_size(mode) * 2


func count_team(team: int, except_id := 0) -> int:
	var n := 0
	for id in players:
		if int(id) != except_id and int(players[id]["team"]) == team:
			n += 1
	return n


## Leyendas ya cogidas en un equipo: dentro de un equipo no se repiten; entre equipos, sí (como
## GameModes.pick_legends sin conexión).
func legends_in(team: int, except_id := 0) -> Array:
	var out: Array = []
	for id in players:
		if int(id) != except_id and int(players[id]["team"]) == team:
			out.append(int(players[id]["legend"]))
	return out


func free_legend(team: int, except_id := 0) -> int:
	var used := legends_in(team, except_id)
	for l in LegendData.PLAYABLE:
		if l not in used:
			return l
	return 0


## Entra alguien: al equipo con más sitio (en la Horda, al 1) y con una leyenda que su equipo no
## lleve. Devuelve su ficha, o {} si la sala está llena para este modo.
func add(id: int, name: String) -> Dictionary:
	# Ya estabas dentro: un registro repetido (cliente con un fallo o trucado) no te duplica en
	# `order` —eran dos plazas tuyas en el reparto y, al irte, un líder fantasma— ni te echa por
	# "sala llena" siendo ya de la casa (auditoría de seguridad, 2026-09-20).
	if players.has(id):
		return players[id]
	if players.size() >= mini(capacity(), MAX_PLAYERS):
		return {}
	var team := 1 if is_horde() else (2 if count_team(2) < count_team(1) else 1)
	var p := {"name": name, "team": team, "legend": free_legend(team), "ready": false}
	players[id] = p
	order.append(id)
	if leader == 0:
		leader = id
	horde_team = maxi(horde_team, players.size())
	return p


func remove(id: int) -> void:
	players.erase(id)
	order.erase(id)
	if leader == id:
		leader = int(order[0]) if not order.is_empty() else 0


## Cambia el modo (solo el líder). Quita el listo a todos: nadie queda comprometido con un modo que
## no ha visto (como el 2D). "" si se pudo; si no, el motivo.
func set_mode(by: int, m: String) -> String:
	if by != leader:
		return "Solo el líder cambia el modo."
	if not GameModes.MODES.has(m):
		return "Ese modo no existe."
	if m == mode:
		return ""
	var old := mode
	mode = m
	if players.size() > capacity():
		mode = old
		return "Sois %d: no cabéis en %s." % [players.size(), String(GameModes.MODES[m]["name"])]
	if is_horde():
		horde_team = maxi(horde_team, players.size())
	_reseat()
	unready_all()
	return ""


## Tras cambiar de modo: en la Horda todos al equipo 1; por equipos, cada uno se queda en el suyo si
## cabe. Si dos del mismo equipo llevan la misma leyenda, la conserva el que llegó antes.
func _reseat() -> void:
	var size := team_size()
	var counts := {1: 0, 2: 0}
	for id in order:
		var p: Dictionary = players[id]
		var t := 1 if is_horde() else int(p["team"])
		if t != 1 and t != 2:
			t = 1
		if not is_horde() and int(counts[t]) >= size:
			t = 3 - t
		counts[t] = int(counts[t]) + 1
		p["team"] = t
	var seen := {1: [], 2: []}
	for id in order:
		var p: Dictionary = players[id]
		var t := int(p["team"])
		if int(p["legend"]) in (seen[t] as Array):
			for l in LegendData.PLAYABLE:
				if l not in (seen[t] as Array):
					p["legend"] = l
					break
		(seen[t] as Array).append(int(p["legend"]))


## Cambia de equipo (por equipos; en la Horda vais todos juntos). Si su leyenda ya la lleva alguien
## del equipo nuevo, se le da una libre.
func set_team(id: int, t: int) -> String:
	if not players.has(id) or (t != 1 and t != 2):
		return "Equipo no válido."
	if is_horde():
		return "En la Horda vais todos juntos."
	var p: Dictionary = players[id]
	if int(p["team"]) == t:
		return ""
	if count_team(t) >= team_size():
		return "Ese equipo ya está lleno."
	p["team"] = t
	if int(p["legend"]) in legends_in(t, id):
		p["legend"] = free_legend(t, id)
	return ""


func set_legend(id: int, legend: int) -> String:
	if not players.has(id) or legend < 0 or legend >= LegendData.PLAYABLE:
		return "Leyenda no válida."
	var p: Dictionary = players[id]
	if legend in legends_in(int(p["team"]), id):
		return "Esa leyenda ya la lleva tu compañero."
	p["legend"] = legend
	return ""


func set_ready(id: int, r: bool) -> void:
	if players.has(id):
		players[id]["ready"] = r


## Horda: plazas del equipo (solo el líder; nunca menos que los humanos que hay).
func set_horde_team(by: int, n: int) -> String:
	if by != leader:
		return "Solo el líder elige el tamaño del equipo."
	horde_team = clampi(n, maxi(players.size(), 1), HordeMode.MAX_TEAM)
	return ""


func unready_all() -> void:
	for id in players:
		players[id]["ready"] = false


## "¡Listo!": lo marcan todos menos el líder (pulsar Iniciar ya es su listo), como en el 2D.
func ready_needed() -> int:
	return players.size() - (1 if players.has(leader) else 0)


func ready_count() -> int:
	var n := 0
	for id in players:
		if int(id) != leader and bool(players[id]["ready"]):
			n += 1
	return n


func all_ready() -> bool:
	return ready_count() >= ready_needed()


## ¿Puede empezar `by`? "" si sí; si no, el motivo para enseñárselo.
func can_start(by: int) -> String:
	if by != leader:
		return "Solo el líder puede iniciar."
	if players.is_empty():
		return "No hay nadie en la sala."
	if not all_ready():
		return "Faltan jugadores por marcar ¡Listo! (%d/%d)." % [ready_count(), ready_needed()]
	return ""


## Reparto al empezar, en el orden en que se crearán las leyendas: equipo 1 y luego equipo 2; en
## cada uno, los humanos por orden de llegada y después los bots. Los bots cogen leyendas que su
## equipo no lleve, barajadas con la semilla de la partida: todos los aparatos sacan el mismo reparto.
func roster(seed: int) -> Array:
	var r := RandomNumberGenerator.new()
	r.seed = seed
	var out: Array = []
	var teams := [1] if is_horde() else [1, 2]
	for t: int in teams:
		var used: Array = []
		for id in order:
			var p: Dictionary = players[id]
			if int(p["team"]) == t:
				out.append({"team": t, "legend": int(p["legend"]), "peer": int(id), "name": String(p["name"])})
				used.append(int(p["legend"]))
		var free: Array = []
		for l in LegendData.PLAYABLE:
			if l not in used:
				free.append(l)
		for i in range(free.size() - 1, 0, -1):
			var j := r.randi_range(0, i)
			var tmp: int = free[i]
			free[i] = free[j]
			free[j] = tmp
		for k in team_size() - count_team(t):
			var leg: int = int(free[k % free.size()]) if not free.is_empty() else 0
			out.append({"team": t, "legend": leg, "peer": 0, "name": String(LegendData.LEGENDS[leg]["name"])})
	return out


## Para mandarla por la red y pintarla en los clientes (copias, no referencias).
func to_dict() -> Dictionary:
	return {"players": players.duplicate(true), "order": order.duplicate(), "mode": mode,
		"horde_team": horde_team, "leader": leader}


func from_dict(d: Dictionary) -> void:
	players = (d.get("players", {}) as Dictionary).duplicate(true)
	order = (d.get("order", []) as Array).duplicate()
	mode = String(d.get("mode", "2v2"))
	horde_team = int(d.get("horde_team", HordeMode.MAX_TEAM))
	leader = int(d.get("leader", 0))
