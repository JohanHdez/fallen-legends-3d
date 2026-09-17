## Prueba de lógica pura de TeamMatch (game/team_match.gd):
##   godot --headless --path . -s tests/test_team_match.gd
## Al mejor de 3 rondas (petición del usuario, 2026-09-16): una ronda la gana el equipo que deja
## al rival sin nadie en pie; la partida, el primero que gana 2. Bajas y caídas con crédito,
## ronda por tiempo, eliminación mutua sin punto, descanso entre rondas y final.
extends SceneTree

var failures := 0


func _check(ok: bool, msg: String) -> void:
	if not ok:
		print("FALLO: " + msg)
		failures += 1


func _match(to_win := 2, round_time := 120.0) -> TeamMatch:
	var m := TeamMatch.new()
	m.setup(to_win, round_time)
	m.add_fighter(0, "Tú", 1, 0, true)
	m.add_fighter(1, "Clérigo", 1, 1)
	m.add_fighter(2, "Liche", 2, 5)
	m.add_fighter(3, "Trasgo Nox", 2, 6)
	return m


func _init() -> void:
	_check(TeamMatch.ROUNDS_TO_WIN == 2, "por defecto se gana con 2 rondas (al mejor de 3)")
	var m := _match()
	_check(m.state == "playing" and m.round == 1, "empieza jugando la ronda 1")

	# Bajas con crédito; sin autor (gas) solo cuenta la caída; del propio equipo no suma.
	var ev := m.on_kill(0, 2)
	_check(ev.get("counted", false), "una baja del rival cuenta")
	_check(int(m.scores[0]["kills"]) == 1 and int(m.scores[2]["deaths"]) == 1, "bajas y caídas por leyenda")
	_check(not m.on_kill(-1, 1).get("counted", true), "caer en el gas no suma baja")
	_check(not m.on_kill(3, 2).get("counted", true), "una baja del propio equipo no suma")

	# Mientras quede alguien en pie en los dos equipos, la ronda sigue.
	m.check_elimination({1: 1, 2: 1})
	_check(m.state == "playing", "con gente en pie en ambos lados la ronda sigue")
	# Rojo se queda sin nadie: ronda para Azul, descanso.
	m.check_elimination({1: 1, 2: 0})
	_check(m.state == "break" and int(m.round_wins[1]) == 1 and int(m.round_wins[2]) == 0, "ronda 1 para Azul: %s %s" % [m.state, m.round_wins])
	_check(int(m.last_round.get("winner", -1)) == 1 and String(m.last_round.get("reason", "")) == "eliminación", "resultado de ronda: %s" % [m.last_round])
	_check(m.take_event() == "round_end" and m.take_event() == "", "evento de fin de ronda una sola vez")
	# En el descanso no cuenta nada.
	m.on_kill(2, 0)
	_check(int(m.scores[2]["kills"]) == 0, "en el descanso no cuentan bajas")
	m.tick(TeamMatch.ROUND_BREAK + 0.1)
	_check(m.state == "playing" and m.round == 2, "tras el descanso empieza la ronda 2")
	_check(m.take_event() == "round_start", "evento de inicio de ronda")

	# Eliminación mutua: nadie suma, se repite con el siguiente número de ronda.
	m.check_elimination({1: 0, 2: 0})
	_check(int(m.round_wins[1]) == 1 and int(m.round_wins[2]) == 0 and int(m.last_round["winner"]) == 0, "eliminación mutua sin punto")
	m.tick(TeamMatch.ROUND_BREAK + 0.1)
	_check(m.round == 3 and m.state == "playing", "tras un empate sigue la ronda 3")

	# Segunda ronda de Azul: partida terminada.
	m.check_elimination({1: 2, 2: 0})
	_check(m.state == "over", "con 2 rondas Azul gana la partida")
	_check(int(m.result.get("winner", -1)) == 1 and m.result.get("rounds", {}) == {1: 2, 2: 0}, "resultado final: %s" % [m.result])
	var pending: Array = []
	var ev_name := m.take_event()
	while ev_name != "":
		pending.append(ev_name)
		ev_name = m.take_event()
	_check(pending.size() > 0 and pending[pending.size() - 1] == "over" and pending.has("round_end"), "eventos hasta el final: %s" % [pending])
	m.tick(10.0)
	_check(m.state == "over", "tras el final no vuelve a empezar")

	# Ronda por tiempo: gana quien tenga más leyendas en pie; si igual, más vida; si igual, nadie.
	var t := _match(2, 5.0)
	t.tick(6.0, {1: 1, 2: 2}, {1: 0.9, 2: 0.4})
	_check(int(t.last_round.get("winner", -1)) == 2 and String(t.last_round["reason"]) == "tiempo", "por tiempo gana quien más tiene en pie: %s" % [t.last_round])
	var h := _match(2, 5.0)
	h.tick(6.0, {1: 2, 2: 2}, {1: 1.2, 2: 1.5})
	_check(int(h.last_round.get("winner", -1)) == 2, "por tiempo con los mismos en pie gana quien más vida tiene")
	var d := _match(2, 5.0)
	d.tick(6.0, {1: 2, 2: 2}, {1: 1.5, 2: 1.5})
	_check(int(d.last_round.get("winner", -1)) == 0 and d.state == "break", "por tiempo en empate total nadie suma")

	# Tope de rondas: si se encadenan empates, acaba por rondas ganadas (o empate).
	var cap := _match()
	for i in TeamMatch.MAX_ROUNDS:
		cap.check_elimination({1: 0, 2: 0})
		cap.tick(TeamMatch.ROUND_BREAK + 0.1)
	_check(cap.state == "over" and int(cap.result.get("winner", -1)) == 0, "tras %d rondas sin ganador acaba en empate" % TeamMatch.MAX_ROUNDS)

	# El registro guarda como mucho FEED_KEEP y envejece.
	var f := _match()
	for i in TeamMatch.FEED_KEEP + 3:
		f.on_kill(0, 2)
	_check(f.feed.size() == TeamMatch.FEED_KEEP, "registro recortado a %d (tiene %d)" % [TeamMatch.FEED_KEEP, f.feed.size()])
	f.tick(2.0)
	_check(float(f.feed[0]["age"]) >= 2.0, "las entradas del registro envejecen")

	print("test_team_match: %s (%d fallos)" % ["OK" if failures == 0 else "FALLO", failures])
	quit(1 if failures > 0 else 0)
