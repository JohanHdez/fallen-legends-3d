## Menú de inicio: elegir modo (Horda, 1v1, 2v2, 3v3, 4v4) y leyenda, y jugar. Sale sobre el propio
## mapa, con la cámara dando vueltas. Construido en código y pensado también para el dedo.
## Al jugar guarda la elección en Engine (fl_mode, fl_legend) y recarga la escena: main.gd la lee
## al arrancar y monta la partida.
class_name ModeMenu
extends Control

const GOLD := Color(1.0, 0.82, 0.38)

var mode := "horda"
var legend := 0
var team := 1                         # Horda: tú solo (1) o con 1-3 compañeros bot
var _team_row: HBoxContainer
var _team_buttons := {}
var _mode_buttons := {}
var _desc: Label
var _name: Label
var _stats: Label
var _skills: Label
var _name_edit: LineEdit
var _online_status: Label
var _net: NetService


func _ready() -> void:
	_net = NetService.node()
	# set_anchors_AND_OFFSETS_preset, no set_anchors_preset: ya en el árbol, la segunda conserva el
	# tamaño que tenía el nodo (0×0) y todo lo "centrado" acababa en la esquina superior izquierda.
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if Engine.has_meta("fl_legend"):
		legend = clampi(int(Engine.get_meta("fl_legend")), 0, LegendData.PLAYABLE - 1)
	if Engine.has_meta("fl_last_mode"):
		mode = String(Engine.get_meta("fl_last_mode"))
	team = clampi(int(Engine.get_meta("fl_horde_team", 1)), 1, HordeMode.MAX_TEAM)
	var veil := ColorRect.new()
	veil.color = Color(0.02, 0.03, 0.06, 0.45)
	veil.set_anchors_preset(Control.PRESET_FULL_RECT)
	veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(veil)

	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.04, 0.05, 0.09, 0.86)
	sb.set_corner_radius_all(20)
	sb.content_margin_left = 34
	sb.content_margin_right = 34
	sb.content_margin_top = 24
	sb.content_margin_bottom = 28
	panel.add_theme_stylebox_override("panel", sb)
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	panel.custom_minimum_size = Vector2(760, 0)
	add_child(panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 14)
	panel.add_child(col)

	var title := _label(50, GOLD)
	title.text = "FALLEN LEGENDS 3D"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(title)

	var modes := HFlowContainer.new()
	modes.alignment = FlowContainer.ALIGNMENT_CENTER
	modes.add_theme_constant_override("h_separation", 10)
	modes.add_theme_constant_override("v_separation", 10)
	col.add_child(modes)
	var group := ButtonGroup.new()
	for id in GameModes.ORDER:
		var b := _button(GameModes.short_name(id), Vector2(128, 64), 26)
		b.toggle_mode = true
		b.button_group = group
		b.pressed.connect(_set_mode.bind(id))
		modes.add_child(b)
		_mode_buttons[id] = b
	# Horda en equipo (petición del usuario, 2026-09-17): solo se ve con la Horda elegida.
	_team_row = HBoxContainer.new()
	_team_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_team_row.add_theme_constant_override("separation", 10)
	col.add_child(_team_row)
	var team_label := _label(22, Color(0.85, 0.86, 0.92))
	team_label.text = "Equipo:"
	_team_row.add_child(team_label)
	var team_group := ButtonGroup.new()
	for n in range(1, HordeMode.MAX_TEAM + 1):
		var tb := _button("Solo" if n == 1 else "%d" % n, Vector2(96, 64), 24)
		tb.toggle_mode = true
		tb.button_group = team_group
		tb.pressed.connect(_set_team.bind(n))
		_team_row.add_child(tb)
		_team_buttons[n] = tb
	(_team_buttons[team] as Button).button_pressed = true

	_desc = _label(19, Color(0.85, 0.86, 0.92))
	_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_desc.custom_minimum_size = Vector2(680, 52)
	col.add_child(_desc)

	var pick := HBoxContainer.new()
	pick.alignment = BoxContainer.ALIGNMENT_CENTER
	pick.add_theme_constant_override("separation", 18)
	col.add_child(pick)
	var prev := _button("◀", Vector2(72, 96), 34)
	prev.pressed.connect(_step_legend.bind(-1))
	pick.add_child(prev)
	var info := VBoxContainer.new()
	info.custom_minimum_size = Vector2(460, 0)
	info.add_theme_constant_override("separation", 2)
	pick.add_child(info)
	_name = _label(36, Color.WHITE)
	_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info.add_child(_name)
	_stats = _label(18, Color(0.75, 0.8, 0.9))
	_stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info.add_child(_stats)
	_skills = _label(18, Color(0.95, 0.9, 0.75))
	_skills.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_skills.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.add_child(_skills)
	var next := _button("▶", Vector2(72, 96), 34)
	next.pressed.connect(_step_legend.bind(1))
	pick.add_child(next)

	var play := _button("JUGAR", Vector2(300, 88), 42, Color(0.55, 0.36, 0.08))
	play.pressed.connect(_play)
	var play_row := HBoxContainer.new()
	play_row.alignment = BoxContainer.ALIGNMENT_CENTER
	play_row.add_theme_constant_override("separation", 12)
	play_row.add_child(play)
	# En línea (2026-09-18, fase 1 del juego en línea): tu nombre y a la sala del servidor.
	_name_edit = LineEdit.new()
	_name_edit.text = _net.player_name
	_name_edit.max_length = Identity.NAME_MAX
	_name_edit.placeholder_text = "Tu nombre"
	_name_edit.custom_minimum_size = Vector2(220, 88)
	_name_edit.add_theme_font_size_override("font_size", 26)
	play_row.add_child(_name_edit)
	var online := _button("EN LÍNEA", Vector2(220, 88), 32, Color(0.12, 0.32, 0.5))
	online.pressed.connect(play_online)
	play_row.add_child(online)
	col.add_child(play_row)
	_online_status = _label(18, Color(1.0, 0.75, 0.6))
	_online_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_online_status.text = _net.last_error
	_online_status.visible = _net.last_error != ""
	col.add_child(_online_status)

	var hint := _label(15, Color(0.7, 0.72, 0.8))
	hint.text = "Teclado: WASD · clic / Q básica · E táctica · R definitiva · Ctrl agacharse · C cámara"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(hint)
	_set_mode(mode)
	_refresh_legend()


func _label(sz: int, c: Color) -> Label:
	return UiKit.label(sz, c)


func _button(text: String, min_size: Vector2, sz: int, base := Color(0.16, 0.18, 0.26)) -> Button:
	return UiKit.button(text, min_size, sz, base)


func _set_mode(id: String) -> void:
	if not GameModes.MODES.has(id):
		id = "horda"
	mode = id
	(_mode_buttons[id] as Button).button_pressed = true
	_team_row.visible = id == "horda"
	_desc.text = String(GameModes.MODES[id]["desc"])


func _set_team(n: int) -> void:
	team = n


func _step_legend(d: int) -> void:
	legend = wrapi(legend + d, 0, LegendData.PLAYABLE)
	_refresh_legend()


func _refresh_legend() -> void:
	var data: Dictionary = LegendData.LEGENDS[legend]
	_name.text = String(data["name"])
	_stats.text = "Vida %d  ·  Velocidad %.1f m/s" % [int(data["hp"]), float(data["speed"]) * LegendData.PX]
	var names := []
	for ab in LegendData.ABILITIES.get(data["id"], []):
		names.append(String(ab["n"]))
	_skills.text = "  ·  ".join(names)


func _unhandled_input(e: InputEvent) -> void:
	if e.is_action_pressed("ui_left"):
		_step_legend(-1)
	elif e.is_action_pressed("ui_right"):
		_step_legend(1)
	elif e.is_action_pressed("ui_accept"):
		_play()


func _play() -> void:
	# Semilla nueva en cada partida (petición del usuario, 2026-09-18): el mapa es el mismo, pero la
	# hierba, los eriales, la decoración, dónde sales y los sorteos de la partida cambian.
	Engine.set_meta("fl_seed", Main.new_seed())
	Engine.set_meta("fl_mode", mode)
	Engine.set_meta("fl_last_mode", mode)
	Engine.set_meta("fl_legend", legend)
	Engine.set_meta("fl_horde_team", team)
	get_tree().reload_current_scene()


## "EN LÍNEA": guarda el nombre, conecta con el servidor y, cuando te mete en la sala, cambia el menú
## por la sala (Lobby) en esta misma capa.
func play_online() -> void:
	_net.remember_name(_name_edit.text)
	_name_edit.text = _net.player_name
	if not _net.lobby_ready.is_connected(_on_lobby_ready):
		_net.lobby_ready.connect(_on_lobby_ready)
		_net.left.connect(_on_left)
	_online_status.visible = true
	_online_status.text = "Conectando con el servidor…"
	if _net.join(_net.server_address()) != OK:
		_online_status.text = "No se pudo conectar."


func _on_lobby_ready() -> void:
	get_parent().add_child(Lobby.new())
	queue_free()


func _on_left(reason: String) -> void:
	_online_status.visible = true
	_online_status.text = reason if reason != "" else "Fuera de la sala."
