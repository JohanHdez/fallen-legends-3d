## Menú de inicio: elegir modo (Horda, 1v1, 2v2, 3v3, 4v4) y leyenda, y jugar. Sale sobre el propio
## mapa y está pensado también para el dedo.
## Distribución estilo pantalla de inicio del 2D (2026-11-09, ver
## docs/superpowers/specs/2026-11-09-pantalla-inicio-design.md): tu leyenda en 3D en el centro (la
## encuadra MenuStage), ◀ ▶ a sus lados para cambiarla, EN LÍNEA a la derecha, y abajo el equipo, el
## selector de modo ‹ › y JUGAR. Antes era un panel con todo apilado y la leyenda escondida.
## Al jugar guarda la elección en Engine (fl_mode, fl_legend) y recarga la escena: main.gd la lee
## al arrancar y monta la partida.
class_name ModeMenu
extends Control

const GOLD := Color(1.0, 0.82, 0.38)
const SIDE_W := 240.0          # ancho de las columnas laterales (EN LÍNEA a la derecha)

var mode := "horda"
var legend := 0
var team := 1                         # Horda: tú solo (1) o con 1-3 compañeros bot
var _team_row: HBoxContainer
var _team_buttons := {}
var _mode_name: Label
var _desc: Label
var _name: Label
var _stats: Label
var _skills: Label
var _name_edit: LineEdit
var _online_status: Label
var _net: NetService
var touch := false            # lo pone main.gd: con el dedo, el menú no enseña las teclas


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

	# Franjas oscuras arriba y abajo para leer el texto; el centro queda limpio para la leyenda.
	_add_band(true, 150.0, 0.6)
	_add_band(false, 230.0, 0.75)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 22)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(margin)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 10)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(root)

	# ── Arriba: tu nombre · título ──
	var top := HBoxContainer.new()
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(top)
	# En línea (2026-09-18, fase 1 del juego en línea): tu nombre y a la sala del servidor.
	_name_edit = LineEdit.new()
	_name_edit.text = _net.player_name
	_name_edit.max_length = Identity.NAME_MAX
	_name_edit.placeholder_text = "Tu nombre"
	_name_edit.custom_minimum_size = Vector2(SIDE_W, 60)
	_name_edit.add_theme_font_size_override("font_size", 24)
	top.add_child(_name_edit)
	var title := _label(44, GOLD)
	title.text = "FALLEN LEGENDS 3D"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(title)
	top.add_child(_spacer(SIDE_W))

	# ── Centro: ◀ leyenda ▶ · EN LÍNEA a la derecha ──
	var middle := HBoxContainer.new()
	middle.size_flags_vertical = Control.SIZE_EXPAND_FILL
	middle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(middle)
	middle.add_child(_spacer(SIDE_W))
	var stage := VBoxContainer.new()
	stage.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	middle.add_child(stage)
	var arrows := HBoxContainer.new()
	arrows.size_flags_vertical = Control.SIZE_EXPAND_FILL
	arrows.alignment = BoxContainer.ALIGNMENT_CENTER
	arrows.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(arrows)
	var prev := _button("◀", Vector2(76, 100), 36)
	prev.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	prev.pressed.connect(_step_legend.bind(-1))
	arrows.add_child(prev)
	# El hueco del centro es donde se ve la leyenda en el mapa (MenuStage la encuadra ahí).
	var hole := _spacer(360)
	arrows.add_child(hole)
	var next := _button("▶", Vector2(76, 100), 36)
	next.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	next.pressed.connect(_step_legend.bind(1))
	arrows.add_child(next)
	_name = _label(34, Color.WHITE)
	_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stage.add_child(_name)
	_stats = _label(17, Color(0.78, 0.83, 0.93))
	_stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stage.add_child(_stats)
	_skills = _label(17, Color(0.98, 0.9, 0.7))
	_skills.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_skills.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stage.add_child(_skills)

	var right := VBoxContainer.new()
	right.custom_minimum_size = Vector2(SIDE_W, 0)
	right.alignment = BoxContainer.ALIGNMENT_CENTER
	right.add_theme_constant_override("separation", 8)
	right.mouse_filter = Control.MOUSE_FILTER_IGNORE
	middle.add_child(right)
	var online := _button("EN LÍNEA", Vector2(SIDE_W, 76), 30, Color(0.12, 0.32, 0.5))
	online.pressed.connect(play_online)
	right.add_child(online)
	_online_status = _label(16, Color(1.0, 0.75, 0.6))
	_online_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_online_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_online_status.custom_minimum_size = Vector2(SIDE_W, 0)
	_online_status.text = _net.last_error
	_online_status.visible = _net.last_error != ""
	right.add_child(_online_status)

	# ── Abajo: equipo (Horda) · ‹ modo › · JUGAR ──
	var bottom := HBoxContainer.new()
	bottom.add_theme_constant_override("separation", 16)
	bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(bottom)
	# Horda en equipo (petición del usuario, 2026-09-17): solo se ve con la Horda elegida. Va dentro
	# de una caja de ancho fijo para que el modo y JUGAR no salten al aparecer o esconderse.
	var team_box := Control.new()
	team_box.custom_minimum_size = Vector2(380, 84)
	team_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom.add_child(team_box)
	_team_row = HBoxContainer.new()
	_team_row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_team_row.alignment = BoxContainer.ALIGNMENT_BEGIN
	_team_row.add_theme_constant_override("separation", 8)
	team_box.add_child(_team_row)
	var team_label := _label(18, Color(0.85, 0.86, 0.92))
	team_label.text = "Equipo:"
	team_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_team_row.add_child(team_label)
	var team_group := ButtonGroup.new()
	for n in range(1, HordeMode.MAX_TEAM + 1):
		var tb := _button("Solo" if n == 1 else "%d" % n, Vector2(60 if n > 1 else 76, 64), 22)
		tb.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		tb.toggle_mode = true
		tb.button_group = team_group
		tb.pressed.connect(_set_team.bind(n))
		_team_row.add_child(tb)
		_team_buttons[n] = tb
	(_team_buttons[team] as Button).button_pressed = true

	var carousel := HBoxContainer.new()
	carousel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	carousel.alignment = BoxContainer.ALIGNMENT_CENTER
	carousel.add_theme_constant_override("separation", 10)
	bottom.add_child(carousel)
	var mprev := _button("‹", Vector2(64, 84), 40)
	mprev.pressed.connect(_step_mode.bind(-1))
	carousel.add_child(mprev)
	var mode_info := VBoxContainer.new()
	mode_info.custom_minimum_size = Vector2(380, 0)
	mode_info.alignment = BoxContainer.ALIGNMENT_CENTER
	mode_info.add_theme_constant_override("separation", 0)
	carousel.add_child(mode_info)
	_mode_name = _label(28, GOLD)
	_mode_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mode_info.add_child(_mode_name)
	_desc = _label(15, Color(0.85, 0.86, 0.92))
	_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_desc.custom_minimum_size = Vector2(380, 40)
	mode_info.add_child(_desc)
	var mnext := _button("›", Vector2(64, 84), 40)
	mnext.pressed.connect(_step_mode.bind(1))
	carousel.add_child(mnext)

	var play := _button("JUGAR", Vector2(SIDE_W + 30, 84), 40, Color(0.62, 0.42, 0.08))
	play.pressed.connect(_play)
	bottom.add_child(play)

	# Las teclas, solo con teclado y ratón: en el móvil no se puede hacer nada de eso y el sitio se
	# aprovecha mejor (petición del usuario, 2026-09-20). Lo pone main.gd al crear el menú.
	if not touch:
		var hint := _label(14, Color(0.7, 0.72, 0.8))
		hint.text = "WASD mover · Clic izq básica · Clic der táctica · Espacio definitiva · Ctrl agacharse · C cámara"
		hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		root.add_child(hint)
	_set_mode(mode)
	_refresh_legend()


func _label(sz: int, c: Color) -> Label:
	return UiKit.label(sz, c)


func _button(text: String, min_size: Vector2, sz: int, base := Color(0.16, 0.18, 0.26)) -> Button:
	return UiKit.button(text, min_size, sz, base)


## Hueco de ancho fijo que no captura el ratón (para equilibrar columnas y dejar ver la leyenda).
func _spacer(w: float) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(w, 0)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


## Degradado oscuro arriba (de oscuro a transparente) o abajo (de transparente a oscuro).
func _add_band(at_top: bool, height: float, alpha: float) -> void:
	var g := Gradient.new()
	var dark := Color(0.02, 0.03, 0.06, alpha)
	var clear := Color(0.02, 0.03, 0.06, 0.0)
	g.set_color(0, dark if at_top else clear)
	g.set_color(1, clear if at_top else dark)
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.fill_from = Vector2(0, 0)
	tex.fill_to = Vector2(0, 1)
	var band := TextureRect.new()
	band.texture = tex
	band.stretch_mode = TextureRect.STRETCH_SCALE
	band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	band.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE if at_top else Control.PRESET_BOTTOM_WIDE)
	if at_top:
		band.offset_bottom = height
	else:
		band.offset_top = -height
	add_child(band)


func _set_mode(id: String) -> void:
	if not GameModes.MODES.has(id):
		id = "horda"
	mode = id
	_team_row.visible = id == "horda"
	_mode_name.text = String(GameModes.MODES[id]["name"])
	_desc.text = String(GameModes.MODES[id]["desc"])


func _step_mode(d: int) -> void:
	var i := GameModes.ORDER.find(mode)
	_set_mode(String(GameModes.ORDER[wrapi(i + d, 0, GameModes.ORDER.size())]))


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
	_show_legend()


## La leyenda del centro es tu leyenda de verdad en el mapa del menú: se cambia en caliente con el
## mismo cambio de las teclas 1-7 (Main.set_legend). Se busca la escena actual porque el menú también
## lo crea el Lobby al salir de una sala, sin pasar por main.gd.
func _show_legend() -> void:
	var main := get_tree().current_scene as Main
	if main == null or main._mode != "menu" or main.pf == null or main.pf.legend == legend:
		return
	main.set_legend(legend)


func _unhandled_input(e: InputEvent) -> void:
	if e.is_action_pressed("ui_left"):
		_step_legend(-1)
	elif e.is_action_pressed("ui_right"):
		_step_legend(1)
	elif e.is_action_pressed("ui_up"):
		_step_mode(-1)
	elif e.is_action_pressed("ui_down"):
		_step_mode(1)
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
	# Entras con la leyenda que habías elegido en el menú (petición del usuario, 2026-09-20: "había
	# seleccionado el Rompemareas y al meterme a la sala me puso el Tormentero"). Al registrarte, el
	# servidor te da una libre sin saber cuál querías; se la pides en cuanto estás dentro. Si un
	# compañero ya la lleva, el servidor lo rechaza y te quedas con la que te tocó: la sala manda.
	_net.request_legend(legend)
	get_parent().add_child(Lobby.new())
	queue_free()


func _on_left(reason: String) -> void:
	_online_status.visible = true
	_online_status.text = reason if reason != "" else "Fuera de la sala."
