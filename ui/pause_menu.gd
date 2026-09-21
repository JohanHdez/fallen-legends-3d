## Pausa: botón ☰ arriba a la izquierda (y la tecla P) que detiene la partida y ofrece Seguir,
## Reiniciar o volver al Menú. Sin esto, en móvil no había forma de salir de una partida ni de la
## Horda sin cerrar la aplicación. Sigue funcionando con el árbol en pausa (PROCESS_MODE_ALWAYS).
## En una partida EN LÍNEA existe igual (2026-09-20: antes no se creaba, y el móvil se quedaba sin
## salida), pero no para el mundo ni ofrece "Reiniciar": ver toggle() y _to_menu().
class_name PauseMenu
extends Control

var main: Main
var _panel: PanelContainer
var _fps_btn: Button
var _was_captured := false


## Se cuelga a sí misma de Main en su propia capa, por encima del táctil (capa 40) para que el botón
## se pueda pulsar con el dedo. Lo monta aquí y no en main.gd porque main.gd no crece (CLAUDE.md) y
## porque así la capa y el menú viajan juntos.
static func install(p_main: Main) -> PauseMenu:
	var layer := CanvasLayer.new()
	layer.layer = 40
	p_main.add_child(layer)
	var menu := PauseMenu.new()
	layer.add_child(menu)
	menu.setup(p_main)
	return menu


func setup(p_main: Main) -> void:
	main = p_main
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var open := _button("☰", Vector2(64, 56), 30)
	open.position = Vector2(12, 10)
	open.pressed.connect(toggle)
	add_child(open)

	_panel = PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.03, 0.04, 0.07, 0.9)
	sb.set_corner_radius_all(18)
	sb.set_content_margin_all(28)
	_panel.add_theme_stylebox_override("panel", sb)
	add_child(_panel)
	_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 14)
	_panel.add_child(col)
	var title := Label.new()
	title.text = "PAUSA"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 44)
	title.add_theme_color_override("font_color", Color(1.0, 0.82, 0.38))
	col.add_child(title)
	# En línea no hay "Reiniciar": la partida es de todos, no se recarga la escena de uno solo. Lo que
	# sí hace falta es una salida -antes, en una partida en red no se creaba ni este menú ni el atajo
	# P, así que en el móvil la única forma de salir era matar la aplicación (revisión de la tarea
	# 5b, 2026-09-20)-.
	var entries := [["Seguir", toggle], ["Reiniciar", _restart], ["Menú", _to_menu]]
	if main.net_client != null:
		entries = [["Seguir", toggle], ["Salir de la partida", _to_menu]]
	for entry in entries:
		var b := _button(entry[0], Vector2(300, 68), 30)
		b.pressed.connect(entry[1])
		col.add_child(b)
	# Contador de FPS: para mirar el rendimiento en el móvil sin flags de consola (petición del
	# usuario, 2026-09-17).
	_fps_btn = _button("", Vector2(300, 56), 22)
	_fps_btn.pressed.connect(_toggle_fps)
	col.add_child(_fps_btn)
	_update_fps_btn()
	# Controles de teclado: agacharse con Ctrl no se decía en ningún sitio. Con el dedo no se enseñan
	# (petición del usuario, 2026-09-20): ahí están los botones en pantalla, incluido el ▼.
	if not main.touch:
		var keys := Label.new()
		keys.text = "Teclado: WASD mover · Shift correr · Ctrl agacharse\nQ o clic básica · E táctica · R definitiva · C cámara · P pausa"
		keys.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		keys.add_theme_font_size_override("font_size", 16)
		keys.add_theme_color_override("font_color", Color(0.8, 0.82, 0.9, 0.9))
		col.add_child(keys)
	_panel.visible = false


func _toggle_fps() -> void:
	main.set_fps_visible(not main.show_fps)
	_update_fps_btn()


func _update_fps_btn() -> void:
	if _fps_btn != null:
		_fps_btn.text = "FPS: sí" if main.show_fps else "FPS: no"


func _button(text: String, min_size: Vector2, sz: int) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = min_size
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", sz)
	for st in [["normal", Color(0.16, 0.18, 0.26, 0.92)], ["hover", Color(0.26, 0.3, 0.42, 0.96)],
			["pressed", Color(0.1, 0.11, 0.16, 1.0)]]:
		var s := StyleBoxFlat.new()
		s.bg_color = st[1]
		s.set_corner_radius_all(12)
		b.add_theme_stylebox_override(st[0], s)
	return b


func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventKey and (e as InputEventKey).pressed and not (e as InputEventKey).echo \
			and (e as InputEventKey).physical_keycode == KEY_P:
		toggle()
		get_viewport().set_input_as_handled()


func toggle() -> void:
	var opening := not _panel.visible
	_panel.visible = opening
	if main.net_client == null:
		get_tree().paused = opening
	else:
		# En línea el mundo NO se para: el servidor sigue simulando y los demás jugando, así que
		# pausar el árbol solo te dejaría ciego -y tu leyenda seguiría corriendo allí con el último
		# control que mandaste, porque el servidor repite el que tenga hasta que llegue otro-. Lo que
		# se corta es la ENTRADA, y no basta con taparla con este Control: el joystick se lee en
		# `PlayerInput._input()`, que corre ANTES del GUI. De ahí `blocked` (y soltar lo que el dedo
		# tuviera puesto, o el joystick se queda clavado en su último valor y sales corriendo).
		# `mouse_filter` sí sirve para lo demás: los clics de ratón van por `_unhandled_input`, que el
		# GUI sí intercepta. Y WASD se cae solo: `_read_local_input` solo lo lee con el ratón capturado.
		mouse_filter = Control.MOUSE_FILTER_STOP if opening else Control.MOUSE_FILTER_IGNORE
		if main.input != null:
			main.input.blocked = opening
			if opening:
				main.input.release_touch()
	if opening:
		_was_captured = Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif _was_captured:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _restart() -> void:
	get_tree().paused = false
	Engine.set_meta("fl_seed", Main.new_seed())   # partida nueva, sorteo nuevo (usuario, 2026-09-18)
	Engine.set_meta("fl_mode", main._mode)
	Engine.set_meta("fl_legend", main.pf.legend)
	get_tree().reload_current_scene()


func _to_menu() -> void:
	get_tree().paused = false
	# En línea hay que soltar la conexión ANTES de recargar: `Net.leave` para al cliente (deja de
	# haber partida), y sin eso `Main._pick_mode` volvería a entrar en la misma partida en cuanto la
	# escena se reconstruyera.
	if main.net_client != null:
		NetService.node().leave()
	if Engine.has_meta("fl_mode"):
		Engine.remove_meta("fl_mode")
	var me := main.hud_fighter()
	if me != null:           # en línea, antes de la primera foto con tu id, no hay leyenda todavía
		Engine.set_meta("fl_legend", me.legend)
	get_tree().reload_current_scene()
