## Sonda de la sala en línea (fase 1 del juego en línea). Un cliente sin pantalla que entra por el
## menú (pulsa "EN LÍNEA", como un jugador), elige leyenda y equipo y se pone listo; si es el líder,
## cambia al modo pedido y, cuando están todos (--expect) y listos, inicia. Comprueba que la sala
## (Lobby) enseña a cada jugador y que llega el arranque con el reparto completo, sin leyendas
## repetidas dentro de un equipo. Con --expect-kick comprueba lo contrario: que el servidor lo echa
## (otra versión del protocolo). La lanza tools/net_check.sh con un servidor y varios clientes:
##   godot --headless --path . -- --mode=menu --client=ws://127.0.0.1:17777 --name=Ana \
##     --netprobe=lobby_probe --want-mode=3v3 --want-legend=0 --want-team=1 --expect=2
## La carga el autoload Net (--netprobe), así que su padre es Net.
extends Node

var net: Node
var _t := 0.0
var _secs := 60.0
var _pressed := false
var _asked := false
var _done := false
var _requests := 0


func _ready() -> void:
	net = get_parent()
	_secs = float(net.cmdline.get("secs", "60"))
	net.lobby_changed.connect(_on_lobby_changed)
	net.match_started.connect(_on_match_started)
	net.left.connect(_on_left)


func _process(delta: float) -> void:
	_t += delta
	if _t > _secs and not _done:
		if net.cmdline.has("hold"):
			get_tree().quit(0)
		else:
			_finish(["no terminó en %.0f s (en la sala: %s)" % [_secs, str(net.in_lobby())]])
		return
	# Entra por el menú, como un jugador: busca el ModeMenu y pulsa "EN LÍNEA".
	if not _pressed:
		for n in get_tree().root.find_children("*", "Control", true, false):
			if n is ModeMenu:
				_pressed = true
				var menu := n as ModeMenu
				# --menu-legend=N: como si la hubieras elegido en el menú antes de pulsar EN LÍNEA.
				# El 2026-09-20 se entraba a la sala con otra: el servidor te daba una libre al
				# registrarte y nadie le decía cuál querías.
				if net.cmdline.has("menu-legend"):
					menu.legend = int(net.cmdline["menu-legend"])
				menu.play_online()
				break


func _on_lobby_changed() -> void:
	if not net.in_lobby() or net.cmdline.has("expect-kick") or _done:
		return
	var s: LobbyRules = net.lobby
	var mine: Dictionary = s.players.get(net.my_id(), {})
	if mine.is_empty():
		return
	_requests += 1
	if _requests > 40:
		_finish(["la sala no llega al estado pedido tras 40 cambios"])
		return
	var want_mode := String(net.cmdline.get("want-mode", s.mode))
	var want_team := int(net.cmdline.get("want-team", mine["team"]))
	var want_legend := int(net.cmdline.get("want-legend", mine["legend"]))
	if net.is_leader() and s.mode != want_mode:
		net.request_mode(want_mode)
		return
	if s.mode != want_mode:
		return                          # espera a que el líder ponga el modo
	if not s.is_horde() and int(mine["team"]) != want_team:
		net.request_team(want_team)
		return
	if int(mine["legend"]) != want_legend:
		net.request_legend(want_legend)
		return
	if net.cmdline.has("hold"):
		if not net.is_leader() and not bool(mine["ready"]):
			net.request_lobby_ready(true)
		return
	if net.is_leader():
		if s.players.size() >= int(net.cmdline.get("expect", "1")) and s.all_ready() and not _asked:
			_asked = true
			net.request_start()
	elif not bool(mine["ready"]):
		net.request_lobby_ready(true)


func _on_match_started(mode: String, seed_value: int, roster: Array) -> void:
	if _done:
		return
	var s: LobbyRules = net.lobby
	var problems: Array = []
	var want_mode := String(net.cmdline.get("want-mode", mode))
	if mode != want_mode:
		problems.append("empezó %s y se pidió %s" % [mode, want_mode])
	var cap := s.team_size() * (1 if s.is_horde() else 2)
	if roster.size() != cap:
		problems.append("reparto de %d plazas para %s (deberían ser %d)" % [roster.size(), mode, cap])
	var me_seen := false
	for t in [1, 2]:
		var seen := {}
		for slot: Dictionary in roster:
			if int(slot["team"]) != t:
				continue
			if seen.has(int(slot["legend"])):
				problems.append("el equipo %d repite %s" % [t, String(LegendData.LEGENDS[int(slot["legend"])]["name"])])
			seen[int(slot["legend"])] = true
			if int(slot["peer"]) == net.my_id():
				me_seen = true
				if net.cmdline.has("want-legend") and int(slot["legend"]) != int(net.cmdline["want-legend"]):
					problems.append("salgo con otra leyenda (%d)" % int(slot["legend"]))
				# Sin pedir nada, la leyenda es la que traías del menú (bug del 2026-09-20: entrabas
				# a la sala con otra, porque el servidor te daba una libre y nadie le decía cuál).
				if net.cmdline.has("menu-legend") and not net.cmdline.has("want-legend") \
						and int(slot["legend"]) != int(net.cmdline["menu-legend"]):
					problems.append("salgo con %s y en el menú elegí %s" % [
						String(LegendData.LEGENDS[int(slot["legend"])]["name"]),
						String(LegendData.LEGENDS[int(net.cmdline["menu-legend"])]["name"])])
	if not me_seen:
		problems.append("no estoy en el reparto")
	# La sala enseña a todos los jugadores (petición del usuario: "donde puedes ver a tu equipo").
	var texts := _lobby_texts()
	if texts.is_empty():
		problems.append("no hay sala (Lobby) en pantalla")
	for id in s.players:
		var nm := String(s.players[id]["name"])
		if nm not in texts:
			problems.append("la sala no enseña a %s" % nm)
	print("[RED] partida iniciada: %s · semilla %d · reparto %s" % [mode, seed_value, _describe(roster)])
	_finish(problems)


func _on_left(reason: String) -> void:
	if _done:
		return
	if net.cmdline.has("expect-kick"):
		if reason.contains("versión"):
			print("[RED] rechazado como se esperaba: %s" % reason)
			_finish([])
		else:
			_finish(["me echaron por otra cosa: %s" % reason])
		return
	_finish(["salí de la sala: %s" % reason])


## Todos los textos de las etiquetas de la sala en pantalla.
func _lobby_texts() -> Array:
	var out: Array = []
	for n in get_tree().root.find_children("*", "Control", true, false):
		if n is Lobby:
			for l in (n as Node).find_children("*", "Label", true, false):
				out.append((l as Label).text)
	return out


func _describe(roster: Array) -> String:
	var parts: Array = []
	for slot: Dictionary in roster:
		parts.append("%s(%d, %s)" % ["bot" if int(slot["peer"]) == 0 else String(slot["name"]), int(slot["team"]),
			String(LegendData.LEGENDS[int(slot["legend"])]["name"])])
	return ", ".join(parts)


func _finish(problems: Array) -> void:
	_done = true
	for p in problems:
		print("[RED] problema: %s" % p)
	print("lobby_probe: %s" % ("OK" if problems.is_empty() else "FALLO"))
	get_tree().quit(0 if problems.is_empty() else 1)
