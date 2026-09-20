## Sonda: el minimapa (petición del usuario, 2026-09-17).
##   godot --headless --fixed-fps 60 --path . -- --mode=2v2 --autoplay --touch --probe=minimap_probe [--secs=90]
##   godot --headless --fixed-fps 60 --path . -- --team=2 --autoplay --near=8 --zombies=20 --probe=minimap_probe [--secs=60]
## Comprueba: el mapa está arriba a la derecha, entero en pantalla y sin pisar el marcador, las bajas,
## el panel del equipo de la Horda, el botón ☰ ni los botones táctiles; en cada redibujo salen en rojo
## exactamente los enemigos que ve tu equipo (marcados siempre; escondidos nunca; quien acaba de atacar,
## esté donde esté; el resto, a BotBrain.SEARCH_RANGE o menos de alguien de tu equipo que no haya
## muerto) y en azul todos
## tus compañeros que no han muerto; y en la partida hubo enemigos en el mapa y enemigos fuera de él.
extends Node

var main: Node
var _t := 0.0
var _secs := 90.0
var _layout_done := false
var _pending := false      # hay algo apuntado a la espera de ver qué dibujó el mapa
var _hooked := false
var _expected := {}        # id del nodo del enemigo -> ¿debería salir en rojo?
var _names := {}           # id del nodo -> nombre, para los mensajes
var _allies := 0
var _compared := 0
var _shown := 0            # veces que un enemigo salió en rojo
var _unseen := 0           # veces que un enemigo vivo no salió (lejos o escondido)
var _problems: Array = []


func _ready() -> void:
	main = get_parent()
	_secs = float(main._args.get("secs", "90"))


func _process(delta: float) -> void:
	_t += delta
	var mm: Minimap = main.minimap
	if mm == null:
		_problems.append("no hay minimapa")
		_finish()
		return
	if not _hooked:
		_hooked = true
		# La señal `draw` sale justo antes de Minimap._draw: lo que se apunta ahí es el mundo que va a
		# dibujar. (Apuntarlo en _process no valía: entre medias se colaba un tic de física.)
		mm.draw.connect(_on_draw.bind(mm))
	if _t > 0.5 and not _layout_done:
		_layout_done = true
		_check_layout(mm)
	var over: bool = (main.team_mode != null and main.team_mode.rules.state == "over") \
		or (main.horde_mode != null and main.horde_mode.over)
	if _t >= _secs or over or _problems.size() >= 6:
		_finish()


func _on_draw(mm: Minimap) -> void:
	if _pending:
		_compare(mm)          # seen_ids todavía es lo del redibujo anterior
	_expect()
	_pending = true


## Lo que debería salir, con las reglas escritas aquí (no con Minimap.enemy_seen: si la regla del
## mapa se estropea, esta sonda lo tiene que notar).
func _expect() -> void:
	_expected.clear()
	var me: Fighter = main.pf
	var combat: Combat = main.combat
	for z in main.zombies:
		if int(z.get("team", 0)) != me.team and float(z["dead_t"]) < 0.0:
			_rule(z, false, false, false, "criatura")
	for al in combat.allies:
		if int(al.get("team", -1)) != me.team and float(al["hp"]) > 0.0:
			_rule(al, false, bool(al.get("hidden", false)), false, String(al["kind"]))
	for f: Fighter in combat.fighters:
		if f.team != me.team and not f.dead():
			_rule(f.rec, f.marked_t > 0.0 and f.mark_team == me.team, combat.is_hidden(f), f.spotted_t > 0.0,
				f.display_name)
	_allies = 0
	for f: Fighter in combat.fighters:
		if f.team == me.team and f != me and not f.dead():
			_allies += 1


func _rule(z: Dictionary, marked: bool, hidden: bool, spotted: bool, name: String) -> void:
	var pos: Vector3 = (z["node"] as Node3D).global_position
	var near := INF
	for f: Fighter in main.combat.fighters:
		if f.team == main.pf.team and f.hp() + (1.0 if f.downed else 0.0) > 0.0:
			near = minf(near, f.pos().distance_to(pos))
	var id := (z["node"] as Node3D).get_instance_id()
	_expected[id] = marked or (not hidden and (spotted or near <= BotBrain.SEARCH_RANGE))
	_names[id] = "%s a %.1f m%s%s%s" % [name, near, " marcado" if marked else "", " escondido" if hidden else "",
		" delatado" if spotted else ""]


func _compare(mm: Minimap) -> void:
	_compared += 1
	var shown: Dictionary = mm.seen_ids
	for id in _expected:
		var want: bool = _expected[id]
		if want:
			_shown += 1
		else:
			_unseen += 1
		if want != shown.has(id):
			_problems.append("%s: %s en el mapa" % [_names[id], "no sale" if want else "sale"])
	if mm.allies_shown != _allies:
		_problems.append("salen %d compañeros y hay %d" % [mm.allies_shown, _allies])


func _check_layout(mm: Minimap) -> void:
	var vp: Vector2 = main.get_viewport().get_visible_rect().size
	var r := mm.get_global_rect()
	if not mm.is_visible_in_tree():
		_problems.append("el mapa no se ve")
	if r.size.distance_to(Vector2(Minimap.SIZE, Minimap.SIZE)) > 1.0:
		_problems.append("el mapa mide %s" % str(r.size))
	if absf(r.end.x - (vp.x - Minimap.MARGIN)) > 1.0 or absf(r.position.y - Minimap.MARGIN) > 1.0:
		_problems.append("el mapa no está arriba a la derecha: %s en %s" % [str(r), str(vp)])
	var others: Array = []      # [nombre, rectángulo]
	var huds: Array = []
	if main.team_mode != null:
		huds.append(main.team_mode.hud)
		var feed: Control = main.team_mode.hud._feed
		if feed.get_global_rect().position.y < r.end.y:
			_problems.append("las bajas empiezan en y=%.0f, dentro del mapa (acaba en %.0f)" % [feed.get_global_rect().position.y, r.end.y])
	if main.horde_mode != null and main.horde_mode.hud != null:
		huds.append(main.horde_mode.hud)
	for h in huds:
		for ch in (h as Control).get_children():
			var c := ch as Control
			if c != null and c.is_visible_in_tree() and c.size.x > 1.0 and c.size.y > 1.0:
				others.append([c.get_class() + " " + str(c.name), c.get_global_rect()])
	for b in main.input.button_rects() if main.touch else []:
		var rad: float = b["r"]
		others.append(["botón " + String(b["name"]), Rect2(Vector2(b["c"]) - Vector2(rad, rad), Vector2(rad, rad) * 2.0)])
	others.append(["botón ☰", Rect2(12, 10, 64, 56)])
	for o in others:
		if (o[1] as Rect2).intersects(r):
			_problems.append("el mapa pisa %s (%s)" % [o[0], str(o[1])])


func _finish() -> void:
	set_process(false)
	if _compared < 10:
		_problems.append("solo se comparó %d veces: ¿el mapa no se redibuja?" % _compared)
	if _shown == 0:
		_problems.append("ningún enemigo salió en el mapa")
	if _unseen == 0:
		_problems.append("todos los enemigos salieron siempre: la regla no se probó")
	print("[SONDA] minimapa: %d redibujos comparados, %d enemigos en rojo y %d fuera, %.0f s" % [_compared, _shown, _unseen, _t])
	for p in _problems:
		print("[SONDA] problema: %s" % p)
	print("minimap_probe: %s" % ("OK" if _problems.is_empty() else "FALLO"))
	main.get_tree().quit(0 if _problems.is_empty() else 1)
