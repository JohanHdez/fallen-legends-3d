## HUD de una partida por equipos: marcador y reloj arriba, últimas bajas a la derecha (debajo del
## minimapa), cuenta
## atrás cuando caes y la pantalla final con el resumen y los botones de Revancha y Menú.
## Construido en código, con tamaños pensados para el dedo (botones de 64 px o más).
class_name MatchHud
extends Control

## De quién saca lo que pinta. Sin conexión lo rellena TeamMode con lo suyo; en línea lo rellena
## NetClient, que lleva su propia copia de `TeamMatch` alimentada con lo que manda el servidor (la
## foto trae reloj, ronda y rondas ganadas; las bajas llegan por aviso). Antes este HUD leía
## `tm.combat.fighters`, `tm.main.pf` y `tm.revive` directamente, y por eso no había forma de
## enseñárselo a un cliente en línea, que no tiene ninguna de las tres (2026-09-20).
var main: Main
var rules: TeamMatch
var mode := ""
var revive: ReviveSystem = null      # null en línea: la reanimación en red es la tarea 7
## Tu equipo. Sin conexión siempre es el 1 (Azul), y por eso la pantalla final decía "¡VICTORIA!"
## cuando ganaba el 1 a secas; en línea la sala te puede poner en el 2, así que ahí eso sería
## mentira justo en el momento de la partida que más se mira (2026-09-20).
var my_team := 1
var dots := Callable()               # {1: "●○", 2: "●●"}: quién sigue en pie en cada equipo
var on_restart := Callable()
var on_menu := Callable()
var _score: RichTextLabel
var _goal: Label
var _feed: RichTextLabel
var _down: Label
var _mark: Label
var _end: PanelContainer
var _banner: Label
var _banner_t := 0.0


func setup(p_tm: TeamMode) -> void:
	main = p_tm.main
	rules = p_tm.rules
	mode = p_tm.mode
	revive = p_tm.revive
	my_team = p_tm.main.pf.team if p_tm.main.pf != null else 1
	dots = p_tm.hud_dots
	on_restart = p_tm.restart
	on_menu = p_tm.to_menu
	_build()


## Lo mismo para un cliente en línea (net/net_client.gd): sin TeamMode, sin ReviveSystem y con los
## puntos del marcador sacados de la última foto en vez de `combat.fighters`.
func setup_online(p_main: Main, p_rules: TeamMatch, p_mode: String, p_team: int, p_dots: Callable,
		p_menu: Callable) -> void:
	main = p_main
	rules = p_rules
	mode = p_mode
	my_team = p_team
	dots = p_dots
	on_menu = p_menu
	_build()


func _build() -> void:
	# set_anchors_AND_OFFSETS_preset, no set_anchors_preset: ya en el árbol, la segunda conserva el
	# tamaño que tenía el nodo (0×0) y todo lo "centrado" acababa en la esquina superior izquierda.
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	var top := PanelContainer.new()
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_theme_stylebox_override("panel", _box(Color(0.04, 0.05, 0.08, 0.72), 14))
	top.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	top.offset_top = 10
	top.grow_horizontal = Control.GROW_DIRECTION_BOTH
	add_child(top)
	var col := VBoxContainer.new()
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_theme_constant_override("separation", 0)
	top.add_child(col)
	_score = RichTextLabel.new()
	_score.bbcode_enabled = true
	_score.fit_content = true
	_score.scroll_active = false
	_score.autowrap_mode = TextServer.AUTOWRAP_OFF
	_score.custom_minimum_size = Vector2(420, 0)
	_score.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_score.add_theme_font_size_override("normal_font_size", 30)
	_score.add_theme_font_size_override("bold_font_size", 30)
	col.add_child(_score)
	_goal = _label(15, Color(0.85, 0.85, 0.9, 0.9))
	_goal.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(_goal)

	_feed = RichTextLabel.new()
	_feed.bbcode_enabled = true
	_feed.fit_content = true
	_feed.scroll_active = false
	_feed.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_feed.add_theme_font_size_override("normal_font_size", 18)
	_feed.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_feed.offset_left = -360
	_feed.offset_top = Minimap.bottom() + 8.0     # debajo del minimapa
	_feed.offset_right = -14
	_feed.custom_minimum_size = Vector2(346, 0)
	add_child(_feed)

	_down = _label(34, Color(1, 0.86, 0.6))
	_down.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_down.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_down.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_down.offset_top = -120
	add_child(_down)

	# Aviso cuando TE marcan por romper un señuelo: te ven a través de todo y no puedes esconderte.
	_mark = _label(24, Color(1.0, 0.45, 0.4))
	_mark.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_mark.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_mark.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_mark.offset_top = 104
	add_child(_mark)

	_banner = _label(58, Color(1, 0.86, 0.45))
	_banner.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_banner.offset_top = -210
	_banner.add_theme_constant_override("outline_size", 10)
	add_child(_banner)


## Cartel grande en el centro (inicio y final de ronda), que se va solo.
func banner(text: String, color := Color(1, 0.86, 0.45)) -> void:
	_banner.text = text
	_banner.add_theme_color_override("font_color", color)
	_banner.modulate.a = 1.0
	_banner_t = TeamMatch.ROUND_BREAK - 0.5


func _label(sz: int, c: Color) -> Label:
	var l := Label.new()
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_size_override("font_size", sz)
	l.add_theme_color_override("font_color", c)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 6)
	return l


func _box(c: Color, radius: int) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = c
	sb.set_corner_radius_all(radius)
	sb.content_margin_left = 18
	sb.content_margin_right = 18
	sb.content_margin_top = 6
	sb.content_margin_bottom = 8
	return sb


static func _hex(c: Color) -> String:
	return c.to_html(false)


func _process(_delta: float) -> void:
	if rules == null or not dots.is_valid():
		return
	var m := rules
	var t := int(ceil(m.round_time_left))
	# Rondas ganadas a los lados y, junto a cada equipo, un punto por leyenda: lleno en pie, hueco caída.
	var dots_now: Dictionary = dots.call()
	_score.text = "[center][b][color=#%s]AZUL %d[/color][/b] [color=#%s]%s[/color]    Ronda %d · %d:%02d    [color=#%s]%s[/color] [b][color=#%s]%d ROJO[/color][/b][/center]" % [
		_hex(TeamMode.TEAM_COLORS[1]), int(m.round_wins[1]), _hex(TeamMode.TEAM_COLORS[1]), dots_now[1],
		m.round, t / 60, t % 60,
		_hex(TeamMode.TEAM_COLORS[2]), dots_now[2], _hex(TeamMode.TEAM_COLORS[2]), int(m.round_wins[2])]
	_goal.text = "%s · al mejor de %d · gana la ronda quien deja al rival sin nadie en pie" % [
		String(GameModes.MODES[mode]["name"]), m.rounds_to_win * 2 - 1]
	if _banner_t > 0.0:
		_banner_t -= _delta
		_banner.modulate.a = clampf(_banner_t / 0.6, 0.0, 1.0)
	var lines: Array = []
	for e in m.feed:
		if float(e["age"]) > 6.0:
			continue
		var victim := "[color=#%s]%s[/color]" % [_hex(TeamMode.TEAM_COLORS.get(int(e["victim_team"]), Color.WHITE)), e["victim"]]
		if String(e["killer"]) == "":
			lines.append("[right]%s cae en el gas[/right]" % victim)
		else:
			lines.append("[right][color=#%s]%s[/color]  ✕  %s[/right]" % [
				_hex(TeamMode.TEAM_COLORS.get(int(e["killer_team"]), Color.WHITE)), e["killer"], victim])
	_feed.text = "\n".join(lines.slice(maxi(lines.size() - 4, 0)))
	var pf := main.hud_fighter()
	_down.text = ""
	if m.state == "playing" and pf != null and revive != null:
		if pf.downed:
			if pf.revive_progress > 0.0:
				_down.text = "Te están levantando… %d %%" % int(pf.revive_progress * 100.0)
			else:
				_down.text = "Derribado · %d s: arrástrate hacia un compañero para que se agache a tu lado" % int(ceil(pf.bleed_t))
		elif not pf.alive():
			_down.text = "Has muerto · vuelves en la ronda siguiente"
		else:
			var lifting := revive.helping(pf)
			if lifting != null:
				_down.text = "Levantando a %s… %d %%" % [lifting.display_name, int(lifting.revive_progress * 100.0)]
			else:
				# Por equipos faltaba el aviso: solo lo tenía la Horda (usuario, 2026-09-18).
				var mate := main.downed_mate()
				if mate != null:
					_down.text = Revive.hint(pf.pos().distance_to(mate.pos()), pf.crouch,
						main.touch, mate.display_name)
	if pf != null and pf.alive() and pf.marked_t > 0.0 and pf.mark_team != pf.team:
		_mark.text = "¡Te han marcado por romper un señuelo! Te ven a través de todo · %d s" % int(ceil(pf.marked_t))
	else:
		_mark.text = ""


## ¿Ya se enseñó la pantalla final? Lo mira la sonda de la tarea 7 para comprobar que una partida en
## línea TERMINA de cara al jugador, no solo en el servidor.
func has_end() -> bool:
	return _end != null


## Pantalla final: resultado, marcador por leyenda y botones.
func show_end() -> void:
	if _end != null:
		return
	var r := rules.result
	var winner := int(r.get("winner", 0))
	_end = PanelContainer.new()
	_end.add_theme_stylebox_override("panel", _box(Color(0.03, 0.04, 0.07, 0.9), 18))
	_end.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_end.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_end.grow_vertical = Control.GROW_DIRECTION_BOTH
	add_child(_end)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	_end.add_child(col)
	var title := _label(52, Color(1, 0.82, 0.35) if winner == my_team else (Color(1, 0.45, 0.4) if winner != 0 else Color(0.9, 0.9, 0.95)))
	title.text = "¡VICTORIA!" if winner == my_team else ("DERROTA" if winner != 0 else "EMPATE")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(title)
	var why := _label(20, Color(0.85, 0.85, 0.9))
	why.text = "Rondas %d - %d" % [int(r["rounds"][1]), int(r["rounds"][2])]
	why.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(why)
	var grid := GridContainer.new()
	# Bajas, CAÍDAS (veces derribado) y MUERTES (las que nadie levantó): son cosas distintas y el
	# usuario echaba de menos las terceras (2026-09-18).
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 28)
	col.add_child(grid)
	for team in [1, 2]:
		var head := _label(22, TeamMode.TEAM_COLORS[team])
		head.text = "Equipo %s" % TeamMode.TEAM_NAMES[team]
		grid.add_child(head)
		for txt in ["Bajas", "Caídas", "Muertes"]:
			var h := _label(16, Color(0.7, 0.7, 0.75))
			h.text = txt
			grid.add_child(h)
		for fid in rules.scores:
			var s: Dictionary = rules.scores[fid]
			if int(s["team"]) != team:
				continue
			for txt in [String(s["name"]), str(s["kills"]), str(s.get("downs", 0)), str(s["deaths"])]:
				var cell := _label(20, Color(1, 1, 0.8) if s["is_player"] else Color.WHITE)
				cell.text = txt
				grid.add_child(cell)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 24)
	col.add_child(row)
	# En línea no hay "Revancha" de uno solo: se vuelve a la sala (tarea 7), así que ese botón solo
	# sale si alguien puso `on_restart`.
	if on_restart.is_valid():
		row.add_child(_button("Revancha", on_restart))
	row.add_child(_button("Menú", on_menu))


func _button(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(220, 68)
	b.add_theme_font_size_override("font_size", 28)
	b.add_theme_stylebox_override("normal", _box(Color(0.18, 0.2, 0.28, 0.95), 12))
	b.add_theme_stylebox_override("hover", _box(Color(0.28, 0.32, 0.45, 0.98), 12))
	b.add_theme_stylebox_override("pressed", _box(Color(0.12, 0.13, 0.18, 1.0), 12))
	b.pressed.connect(cb)
	return b
