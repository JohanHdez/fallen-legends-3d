## HUD de la Horda en equipo: vida de cada compañero arriba a la derecha, bajo el minimapa (o su cuenta atrás si ha
## caído), el aviso del centro cuando caes o levantas a alguien, y la pantalla final cuando cae todo el
## equipo, con la oleada alcanzada, bajas y caídas, Revancha y Menú. Construido en código, con botones
## de 64 px o más.
class_name HordeHud
extends Control

var hm: HordeMode
var _rows: Array = []                # [{f, name: Label, bar: ProgressBar, state: Label}]
var _down: Label
var _end: PanelContainer
var _banner: Label
var _banner_t := 0.0


func setup(p_hm: HordeMode) -> void:
	hm = p_hm
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)   # ya en el árbol: si no, queda en 0×0
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	if hm.size > 1:
		var panel := PanelContainer.new()
		panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.add_theme_stylebox_override("panel", _box(Color(0.04, 0.05, 0.08, 0.7), 12))
		panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
		panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
		panel.offset_top = Minimap.bottom() + 8.0     # debajo del minimapa
		panel.offset_right = -12
		add_child(panel)
		var col := VBoxContainer.new()
		col.mouse_filter = Control.MOUSE_FILTER_IGNORE
		col.add_theme_constant_override("separation", 4)
		panel.add_child(col)
		for f: Fighter in hm.team():
			var row := HBoxContainer.new()
			row.mouse_filter = Control.MOUSE_FILTER_IGNORE
			row.add_theme_constant_override("separation", 8)
			col.add_child(row)
			var name := _label(17, Color(1, 1, 0.8) if f.is_player else Color.WHITE)
			name.text = "Tú (%s)" % f.display_name if f.is_player else f.display_name
			name.custom_minimum_size = Vector2(170, 0)
			row.add_child(name)
			var bar := ProgressBar.new()
			bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
			bar.show_percentage = false
			bar.custom_minimum_size = Vector2(120, 14)
			bar.max_value = 1.0
			var fill := StyleBoxFlat.new()
			fill.bg_color = Color(0.35, 0.9, 0.35)
			bar.add_theme_stylebox_override("fill", fill)
			var bg := StyleBoxFlat.new()
			bg.bg_color = Color(0, 0, 0, 0.6)
			bar.add_theme_stylebox_override("background", bg)
			bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			row.add_child(bar)
			var state := _label(16, Color(1.0, 0.6, 0.35))
			state.custom_minimum_size = Vector2(120, 0)
			row.add_child(state)
			_rows.append({"f": f, "bar": bar, "state": state})

	_banner = _label(40, Color(1.0, 0.5, 0.35))
	_banner.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_banner.offset_top = 90
	add_child(_banner)

	_down = _label(30, Color(1, 0.86, 0.6))
	_down.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_down.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_down.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_down.offset_top = -120
	add_child(_down)


## Cartel que se va solo (el gas avanza y la horda se endurece).
func banner(text: String) -> void:
	_banner.text = text
	_banner.modulate.a = 1.0
	_banner_t = 3.0


func _process(_delta: float) -> void:
	if hm == null:
		return
	if _banner_t > 0.0:
		_banner_t -= _delta
		_banner.modulate.a = clampf(_banner_t / 0.6, 0.0, 1.0)
	for r in _rows:
		var f: Fighter = r["f"]
		var st: Label = r["state"]
		if f.alive():
			st.text = ""
		elif f.downed and f.revive_progress > 0.0:
			st.text = "levantando %d %%" % int(f.revive_progress * 100.0)
		elif f.downed:
			st.text = "DERRIBADO · %d s" % int(ceil(f.bleed_t))
		else:
			st.text = "MUERTO"
		(r["bar"] as ProgressBar).value = f.bleed_t / Revive.BLEED_TIME if f.downed else f.hp() / maxf(f.hp_max(), 1.0)
	var pf := hm.main.pf
	_down.text = ""
	if hm.over or pf == null:
		return
	if pf.downed:
		if pf.revive_progress > 0.0:
			_down.text = "Te están levantando… %d %%" % int(pf.revive_progress * 100.0)
		else:
			_down.text = "Derribado · %d s: arrástrate hacia un compañero para que se agache a tu lado" % int(ceil(pf.bleed_t))
	elif not pf.alive():
		_down.text = "Has muerto · vuelves con la oleada siguiente" if hm.team_alive() > 0 else "Has muerto"
	else:
		var lifting := hm.revive.helping(pf)
		if lifting != null:
			_down.text = "Levantando a %s… %d %%" % [lifting.display_name, int(lifting.revive_progress * 100.0)]
		elif _someone_down():
			_down.text = "Un compañero está derribado: agáchate a su lado para levantarlo"


func _someone_down() -> bool:
	for f: Fighter in hm.team():
		if f.downed:
			return true
	return false


## Pantalla final: oleada alcanzada, tiempo, bajas y caídas de cada leyenda, y botones.
func show_end() -> void:
	if _end != null:
		return
	_end = PanelContainer.new()
	_end.add_theme_stylebox_override("panel", _box(Color(0.03, 0.04, 0.07, 0.9), 18))
	_end.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_end.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_end.grow_vertical = Control.GROW_DIRECTION_BOTH
	add_child(_end)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	_end.add_child(col)
	var title := _label(50, Color(1, 0.45, 0.4))
	title.text = "HAS MUERTO" if hm.size == 1 else "LA HORDA OS HA SUPERADO"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(title)
	var t := int(hm.time)
	var why := _label(22, Color(0.9, 0.9, 0.95))
	why.text = "Oleada %d · %d:%02d" % [hm.main.horde.wave, t / 60, t % 60]
	why.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(why)
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 28)
	col.add_child(grid)
	for txt in ["Leyenda", "Bajas", "Caídas"]:
		var h := _label(16, Color(0.7, 0.7, 0.75))
		h.text = txt
		grid.add_child(h)
	for f: Fighter in hm.team():
		for txt in ["Tú (%s)" % f.display_name if f.is_player else f.display_name, str(hm.kills_of(f)), str(f.deaths)]:
			var cell := _label(20, Color(1, 1, 0.8) if f.is_player else Color.WHITE)
			cell.text = txt
			grid.add_child(cell)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 24)
	col.add_child(row)
	row.add_child(_button("Revancha", hm.restart))
	row.add_child(_button("Menú", hm.to_menu))


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
	sb.content_margin_left = 16
	sb.content_margin_right = 16
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	return sb


func _button(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(220, 72)
	b.add_theme_font_size_override("font_size", 28)
	b.pressed.connect(cb)
	return b
