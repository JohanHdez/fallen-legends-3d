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


func _ready() -> void:
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
		var b := _button("Horda" if id == "horda" else id.to_upper(), Vector2(128, 64), 26)
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

	var play := _button("JUGAR", Vector2(340, 88), 42, Color(0.55, 0.36, 0.08))
	play.pressed.connect(_play)
	var play_row := HBoxContainer.new()
	play_row.alignment = BoxContainer.ALIGNMENT_CENTER
	play_row.add_child(play)
	col.add_child(play_row)

	var hint := _label(15, Color(0.7, 0.72, 0.8))
	hint.text = "Teclado: WASD · clic / Q básica · E táctica · R definitiva · Ctrl agacharse · C cámara"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(hint)
	_set_mode(mode)
	_refresh_legend()


func _label(sz: int, c: Color) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", sz)
	l.add_theme_color_override("font_color", c)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 5)
	return l


func _button(text: String, min_size: Vector2, sz: int, base := Color(0.16, 0.18, 0.26)) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = min_size
	b.add_theme_font_size_override("font_size", sz)
	for st in [["normal", base], ["hover", base.lightened(0.18)], ["pressed", GOLD.darkened(0.45)],
			["focus", base.lightened(0.1)]]:
		var s := StyleBoxFlat.new()
		s.bg_color = st[1]
		s.set_corner_radius_all(12)
		s.border_color = GOLD if st[0] == "pressed" else Color(1, 1, 1, 0.08)
		s.set_border_width_all(2)
		b.add_theme_stylebox_override(st[0], s)
	b.add_theme_color_override("font_pressed_color", Color.WHITE)
	return b


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
