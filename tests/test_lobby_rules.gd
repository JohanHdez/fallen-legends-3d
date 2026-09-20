## Prueba de las reglas de la sala en línea (net/lobby_rules.gd), sin red:
##   godot --headless --path . -s tests/test_lobby_rules.gd
## Petición del usuario (2026-09-18): "tráete la sala que manejamos en el proyecto 2D donde puedes ver
## a tu equipo en un lobby". Líder, equipos, leyendas sin repetir dentro de un equipo, listos, y el
## reparto de plazas con bots al empezar.
extends SceneTree

var failures := 0


func _check(ok: bool, msg: String) -> void:
	if not ok:
		print("FALLO: " + msg)
		failures += 1


func _init() -> void:
	_test_join_and_leader()
	_test_mode_and_teams()
	_test_ready_and_start()
	_test_roster()
	_test_sync()
	print("test_lobby_rules: %s (%d fallos)" % ["OK" if failures == 0 else "FALLO", failures])
	quit(1 if failures > 0 else 0)


func _test_join_and_leader() -> void:
	var s := LobbyRules.new()   # 2v2 por defecto
	var a := s.add(10, "Ana")
	var b := s.add(11, "Beto")
	_check(s.leader == 10, "el primero en llegar es el líder (líder %d)" % s.leader)
	_check(int(a["team"]) == 1 and int(b["team"]) == 2, "en 2v2 se reparten: Ana %d, Beto %d" % [a["team"], b["team"]])
	s.add(10, "Ana")
	_check(s.order.size() == 2 and s.players.size() == 2, "con sitio de sobra, registrarse otra vez tampoco duplica (%d en orden)" % s.order.size())
	s.add(12, "Caro")
	s.add(13, "Dani")
	_check(s.add(14, "Eva").is_empty(), "un 2v2 no admite a un quinto")
	_check(s.count_team(1) == 2 and s.count_team(2) == 2, "dos y dos (%d/%d)" % [s.count_team(1), s.count_team(2)])
	_check(int(s.players[12]["legend"]) != int(s.players[10]["legend"]), "Caro no repite la leyenda de su compañera Ana")
	# Registrarse dos veces (cliente con un fallo o trucado) no puede duplicarte: antes te volvía a
	# meter en `order` —dos plazas tuyas en el reparto— y, con la sala llena, te echaba por "sala
	# llena" siendo ya de la casa (auditoría de seguridad, 2026-09-20).
	var again := s.add(10, "Ana")
	_check(str(again) == str(s.players[10]), "con la sala llena, registrarse otra vez devuelve tu ficha: %s" % str(again))
	_check(s.order.size() == 4 and s.players.size() == 4, "y no te duplica (%d en orden, %d jugadores)" % [s.order.size(), s.players.size()])
	s.remove(10)
	_check(s.leader == 11, "si se va el líder, lo es el siguiente en llegar (líder %d)" % s.leader)
	s.remove(11)
	s.remove(12)
	s.remove(13)
	_check(s.leader == 0 and s.players.is_empty(), "sala vacía, sin líder")


func _test_mode_and_teams() -> void:
	var s := LobbyRules.new()
	s.add(1, "Ana")
	s.add(2, "Beto")
	s.add(3, "Caro")
	_check(s.set_mode(2, "4v4") != "", "solo el líder cambia el modo")
	_check(s.mode == "2v2", "el modo no cambió (%s)" % s.mode)
	_check(s.set_mode(1, "1v1") != "", "tres no caben en un 1v1")
	s.set_ready(2, true)
	_check(s.set_mode(1, "4v4") == "", "el líder pasa a 4v4")
	_check(not bool(s.players[2]["ready"]), "cambiar de modo quita el listo a todos")
	_check(s.set_team(2, 1) == "", "Beto se pasa al equipo 1")
	_check(int(s.players[2]["team"]) == 1, "Beto está en el 1")
	var ana_legend := int(s.players[1]["legend"])
	_check(s.set_legend(2, ana_legend) != "", "Beto no puede llevar la leyenda de su compañera Ana")
	s.set_team(3, 2)
	_check(s.set_legend(3, ana_legend) == "", "Caro, del otro equipo, sí puede llevarla")
	_check(s.set_team(1, 3) != "", "no existe el equipo 3")
	_check(s.set_mode(1, "horda") == "", "a la Horda")
	var legends := []
	for id in s.players:
		_check(int(s.players[id]["team"]) == 1, "en la Horda todos al equipo 1 (%s)" % s.players[id]["name"])
		legends.append(int(s.players[id]["legend"]))
	_check(_unique(legends), "al juntarse en un equipo no repiten leyenda: %s" % str(legends))
	_check(s.set_team(2, 2) != "", "en la Horda no se cambia de equipo")
	_check(s.horde_team >= 3, "la Horda tiene al menos una plaza por humano (%d)" % s.horde_team)
	_check(s.set_horde_team(1, 2) == "" and s.horde_team == 3, "el equipo de la Horda no baja de los humanos que hay (%d)" % s.horde_team)
	_check(s.set_horde_team(2, 4) != "", "solo el líder elige el tamaño del equipo")


func _test_ready_and_start() -> void:
	var s := LobbyRules.new()
	s.add(1, "Ana")
	s.add(2, "Beto")
	s.add(3, "Caro")
	_check(s.ready_needed() == 2, "listos hacen falta los que no son líder (%d)" % s.ready_needed())
	_check(s.can_start(1) != "", "sin listos no se empieza")
	s.set_ready(2, true)
	_check(s.can_start(1) != "", "con uno de dos listos, tampoco")
	s.set_ready(3, true)
	_check(s.can_start(1) == "", "todos listos: el líder puede empezar")
	_check(s.can_start(2) != "", "otro que no es el líder no puede")


func _test_roster() -> void:
	var s := LobbyRules.new()          # 2v2: Ana (1), Beto (2); los otros dos huecos, bots
	s.add(1, "Ana")
	s.add(2, "Beto")
	var r := s.roster(1234)
	_check(r.size() == 4, "un 2v2 son cuatro plazas (%d)" % r.size())
	if r.size() == 4:
		_check(int(r[0]["team"]) == 1 and int(r[0]["peer"]) == 1, "la primera plaza es Ana, del equipo 1")
		_check(int(r[1]["team"]) == 1 and int(r[1]["peer"]) == 0, "la segunda, un bot del equipo 1")
		_check(int(r[2]["team"]) == 2 and int(r[2]["peer"]) == 2, "la tercera, Beto, del equipo 2")
		_check(int(r[3]["team"]) == 2 and int(r[3]["peer"]) == 0, "la cuarta, un bot del equipo 2")
	for t in [1, 2]:
		var legends := []
		for slot in r:
			if int(slot["team"]) == t:
				legends.append(int(slot["legend"]))
		_check(_unique(legends), "equipo %d sin leyendas repetidas: %s" % [t, str(legends)])
	_check(str(s.roster(1234)) == str(r), "la misma semilla da el mismo reparto")
	var h := LobbyRules.new()
	h.add(5, "Ana")
	h.set_mode(5, "horda")
	h.add(6, "Beto")
	h.set_horde_team(5, 3)
	var hr := h.roster(7)
	_check(hr.size() == 3, "Horda de 3: tres plazas (%d)" % hr.size())
	var bots := 0
	for slot in hr:
		_check(int(slot["team"]) == 1, "en la Horda todas las plazas son del equipo 1")
		if int(slot["peer"]) == 0:
			bots += 1
	_check(bots == 1, "dos humanos y un bot (%d bots)" % bots)


func _test_sync() -> void:
	var s := LobbyRules.new()
	s.add(1, "Ana")
	s.add(2, "Beto")
	s.set_mode(1, "3v3")
	s.set_ready(2, true)
	var c := LobbyRules.new()
	c.from_dict(s.to_dict())
	_check(c.mode == "3v3" and c.leader == 1 and c.players.size() == 2, "la copia del cliente tiene modo, líder y jugadores")
	_check(bool(c.players[2]["ready"]) and String(c.players[2]["name"]) == "Beto", "y quién está listo")
	_check(c.order == s.order, "y el orden de llegada")
	s.players[2]["name"] = "Otro"
	_check(String(c.players[2]["name"]) == "Beto", "la copia no comparte datos con el original")


func _unique(a: Array) -> bool:
	var seen := {}
	for v in a:
		if seen.has(v):
			return false
		seen[v] = true
	return true
