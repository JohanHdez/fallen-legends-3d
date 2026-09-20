## La sala del juego en línea (fase 1: docs/superpowers/specs/2026-09-18-juego-en-linea-design.md),
## portada de scripts/lobby.gd del 2D a petición del usuario (2026-09-18: "tráete la sala que
## manejamos en el proyecto 2D donde puedes ver a tu equipo en un lobby"). Los equipos en columnas
## con cada jugador, su leyenda y si está listo, más los huecos que llenarán los bots; tu leyenda y
## tu equipo; el líder elige el modo (y en la Horda cuántos sois) e inicia cuando todos están
## listos. Todo lo decide el servidor: aquí solo se pide (Net.request_*) y se pinta Net.lobby.
class_name Lobby
extends Control

const GOLD := UiKit.GOLD
const TEAM_COL := {1: Color(0.45, 0.7, 1.0), 2: Color(1.0, 0.45, 0.4)}
const READY_COL := Color(0.45, 1.0, 0.55)
const WAIT_COL := Color(0.62, 0.6, 0.55)
const BOT_COL := Color(0.55, 0.57, 0.62)

var _mode_buttons := {}
var _horde_row: HBoxContainer
var _horde_buttons := {}
var _team_row: HBoxContainer
var _team_buttons := {}
var _legend_label: Label
var _columns: HBoxContainer
var _ready_button: Button
var _start_button: Button
var _status: Label
var _net: NetService


func _ready() -> void:
	_net = NetService.node()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var veil := ColorRect.new()
	veil.color = Color(0.02, 0.03, 0.06, 0.5)
	veil.set_anchors_preset(Control.PRESET_FULL_RECT)
	veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(veil)
	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.04, 0.05, 0.09, 0.9)
	sb.set_corner_radius_all(20)
	sb.content_margin_left = 30
	sb.content_margin_right = 30
	sb.content_margin_top = 20
	sb.content_margin_bottom = 22
	panel.add_theme_stylebox_override("panel", sb)
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	panel.custom_minimum_size = Vector2(900, 0)
	add_child(panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	panel.add_child(col)

	var title := UiKit.label(40, GOLD)
	title.text = "SALA EN LÍNEA"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(title)

	# Modo (solo el líder).
	var modes := HBoxContainer.new()
	modes.alignment = BoxContainer.ALIGNMENT_CENTER
	modes.add_theme_constant_override("separation", 8)
	var group := ButtonGroup.new()
	for id: String in GameModes.ORDER:
		var b := UiKit.button(GameModes.short_name(id), Vector2(120, 64), 24)
		b.toggle_mode = true
		b.button_group = group
		b.pressed.connect(_pick_mode.bind(id))
		modes.add_child(b)
		_mode_buttons[id] = b
	col.add_child(modes)

	# Horda: cuántos sois (humanos + bots; solo el líder).
	_horde_row = HBoxContainer.new()
	_horde_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_horde_row.add_theme_constant_override("separation", 8)
	var hl := UiKit.label(22, Color(0.85, 0.87, 0.95))
	hl.text = "Equipo de"
	_horde_row.add_child(hl)
	var hgroup := ButtonGroup.new()
	for n in range(1, HordeMode.MAX_TEAM + 1):
		var hb := UiKit.button(str(n), Vector2(64, 64), 26)
		hb.toggle_mode = true
		hb.button_group = hgroup
		hb.pressed.connect(_pick_horde_team.bind(n))
		_horde_row.add_child(hb)
		_horde_buttons[n] = hb
	col.add_child(_horde_row)

	# Tu leyenda y tu equipo.
	var mine := HBoxContainer.new()
	mine.alignment = BoxContainer.ALIGNMENT_CENTER
	mine.add_theme_constant_override("separation", 10)
	var prev := UiKit.button("◀", Vector2(64, 64), 28)
	prev.pressed.connect(_step_legend.bind(-1))
	mine.add_child(prev)
	_legend_label = UiKit.label(28, GOLD)
	_legend_label.custom_minimum_size = Vector2(260, 0)
	_legend_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mine.add_child(_legend_label)
	var next := UiKit.button("▶", Vector2(64, 64), 28)
	next.pressed.connect(_step_legend.bind(1))
	mine.add_child(next)
	_team_row = HBoxContainer.new()
	_team_row.add_theme_constant_override("separation", 8)
	for t: int in [1, 2]:
		var tb := UiKit.button("Azul" if t == 1 else "Rojo", Vector2(110, 64), 24, (TEAM_COL[t] as Color).darkened(0.55))
		tb.pressed.connect(_pick_team.bind(t))
		_team_row.add_child(tb)
		_team_buttons[t] = tb
	mine.add_child(_team_row)
	col.add_child(mine)

	# Los equipos, en columnas.
	_columns = HBoxContainer.new()
	_columns.alignment = BoxContainer.ALIGNMENT_CENTER
	_columns.add_theme_constant_override("separation", 24)
	col.add_child(_columns)

	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 14)
	var leave := UiKit.button("Salir", Vector2(160, 72), 26)
	leave.pressed.connect(_leave)
	buttons.add_child(leave)
	_ready_button = UiKit.button("¡Listo!", Vector2(240, 72), 28, Color(0.12, 0.4, 0.2))
	_ready_button.pressed.connect(_toggle_ready)
	buttons.add_child(_ready_button)
	_start_button = UiKit.button("Iniciar partida", Vector2(280, 72), 28, Color(0.55, 0.36, 0.08))
	_start_button.pressed.connect(_start)
	buttons.add_child(_start_button)
	col.add_child(buttons)

	_status = UiKit.label(18, Color(1.0, 0.8, 0.6))
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(_status)

	_net.lobby_changed.connect(_refresh)
	_net.lobby_message.connect(_on_message)
	_net.match_started.connect(_on_match_started)
	_net.left.connect(_on_left)
	_refresh()


func _refresh() -> void:
	var s: LobbyRules = _net.lobby
	var me: int = _net.my_id()
	var leader: bool = _net.is_leader()
	for id: String in _mode_buttons:
		var b: Button = _mode_buttons[id]
		b.set_pressed_no_signal(id == s.mode)
		b.disabled = not leader
		# Deshabilitado, el estilo del tema tapa el de "pulsado": sin esto, quien no es líder veía
		# los cinco modos iguales y no sabía a qué se apuntaba (captura de la sala, 2026-09-20).
		UiKit.mark(b, id == s.mode)
	_horde_row.visible = s.is_horde()
	for n: int in _horde_buttons:
		var hb: Button = _horde_buttons[n]
		hb.set_pressed_no_signal(n == s.horde_team)
		hb.disabled = not leader or n < s.players.size()
		UiKit.mark(hb, n == s.horde_team)
	_team_row.visible = not s.is_horde()
	var mine: Dictionary = s.players.get(me, {})
	if not mine.is_empty():
		_legend_label.text = String(LegendData.LEGENDS[int(mine["legend"])]["name"])
	# Tu equipo, marcado: los dos botones llevan su color de equipo siempre, así que sin el borde
	# dorado no se sabía en cuál estabas (captura de la sala, 2026-09-20).
	for t: int in _team_buttons:
		UiKit.mark(_team_buttons[t] as Button, int(mine.get("team", 0)) == t, (TEAM_COL[t] as Color).darkened(0.55))
	_fill_columns(s, me)
	_ready_button.visible = not leader
	_ready_button.text = "Cancelar listo" if bool(mine.get("ready", false)) else "¡Listo!"
	_start_button.visible = leader
	_start_button.disabled = not s.all_ready()


## Una columna por equipo (en la Horda, una): cada jugador con su leyenda y LÍDER, LISTO o
## esperando; después, un "Bot" por cada hueco que llenará un bot al empezar.
func _fill_columns(s: LobbyRules, me: int) -> void:
	for c in _columns.get_children():
		c.queue_free()
	var teams := [1] if s.is_horde() else [1, 2]
	for t: int in teams:
		var box := VBoxContainer.new()
		box.custom_minimum_size = Vector2(420, 0)
		box.add_theme_constant_override("separation", 6)
		var head := UiKit.label(24, TEAM_COL[t])
		head.text = "TU EQUIPO" if s.is_horde() else ("EQUIPO AZUL" if t == 1 else "EQUIPO ROJO")
		box.add_child(head)
		for id in s.order:
			var p: Dictionary = s.players[id]
			if int(p["team"]) != t:
				continue
			var state := "LÍDER" if int(id) == s.leader else ("LISTO" if bool(p["ready"]) else "esperando")
			var state_col := GOLD if int(id) == s.leader else (READY_COL if bool(p["ready"]) else WAIT_COL)
			box.add_child(_row(String(p["name"]), String(LegendData.LEGENDS[int(p["legend"])]["name"]),
				state, state_col, int(id) == me))
		for k in s.team_size() - s.count_team(t):
			box.add_child(_row("Bot", "leyenda al azar", "bot", BOT_COL, false))
		_columns.add_child(box)


func _row(who: String, legend: String, state: String, state_col: Color, me: bool) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var a := UiKit.label(22, GOLD if me else Color(0.95, 0.95, 1.0))
	a.text = who
	a.custom_minimum_size = Vector2(150, 0)
	row.add_child(a)
	var b := UiKit.label(20, Color(0.82, 0.84, 0.92))
	b.text = legend
	b.custom_minimum_size = Vector2(170, 0)
	row.add_child(b)
	var c := UiKit.label(18, state_col)
	c.text = state
	row.add_child(c)
	return row


func _pick_mode(id: String) -> void:
	_net.request_mode(id)


func _pick_horde_team(n: int) -> void:
	_net.request_horde_team(n)


func _pick_team(t: int) -> void:
	_net.request_team(t)


## La siguiente leyenda que no lleve ya un compañero.
func _step_legend(d: int) -> void:
	var s: LobbyRules = _net.lobby
	var mine: Dictionary = s.players.get(_net.my_id(), {})
	if mine.is_empty():
		return
	var taken := s.legends_in(int(mine["team"]), _net.my_id())
	var l := int(mine["legend"])
	for k in LegendData.PLAYABLE:
		l = wrapi(l + d, 0, LegendData.PLAYABLE)
		if l not in taken:
			break
	_net.request_legend(l)


func _toggle_ready() -> void:
	var mine: Dictionary = _net.lobby.players.get(_net.my_id(), {})
	_net.request_lobby_ready(not bool(mine.get("ready", false)))


func _start() -> void:
	_net.request_start()


func _leave() -> void:
	_net.leave()


func _on_message(text: String) -> void:
	_status.text = text


## En la fase 1 la partida en red aún no existe: se avisa y se sigue en la sala.
func _on_match_started(mode: String, _seed: int, roster: Array) -> void:
	_status.text = "¡%s con %d plazas! La partida en línea llega en la fase 2: de momento seguís en la sala." % [
		String(GameModes.MODES[mode]["name"]), roster.size()]


## Fuera de la sala: de vuelta al menú, que enseña el motivo (si lo hay).
func _on_left(_reason: String) -> void:
	get_parent().add_child(ModeMenu.new())
	queue_free()
