## Juego en línea, cliente (tarea 4 de docs/superpowers/plans/2026-09-20-juego-en-linea-f2-partida.md,
## "Cliente: pintar lo que manda el servidor" del spec): un nodo por leyenda que aparece en las fotos
## del servidor. Se crea con los MISMOS constructores de modelo que el resto del juego
## (main._make_character, main._make_bar...) para que se vea igual que una partida sin conexión; cada
## foto se mueve, se anima y se colorea la barra; y se borra si deja de venir. NO es un `Fighter`: no
## combate, no colisiona, no tiene lanzador -el cliente no simula nada, solo pinta-.
class_name NetView
extends RefCounted

## Una leyenda pintada: su nodo, su modelo (para el yaw), sus capas de animación, la barra y el
## nombre. Nada de esto combate: son solo los mismos trozos visuales que arma Combat.spawn_fighter.
class Actor:
	var body: Node3D
	var model: Node3D
	var anims: Array = []
	var last_anim := -1
	var bar: Node3D
	var marked := false

var main: Main
var roster: Array = []
var my_team := Fighter.TEAM_BLUE
var actors := {}          # id (el índice del reparto) -> Actor
var _seen := {}           # reutilizado cada fotograma: a quién ha tocado esta vez (nadie más se borra)


## `p_roster`: el mismo Array que mandó el servidor al empezar (net.gd, match_started): id de
## leyenda, equipo, peer y nombre por plaza, en el MISMO orden en que el servidor creó sus Fighter
## (setup_from_roster), así que el índice del reparto es el `id` que trae cada foto.
func setup(p_main: Main, p_roster: Array) -> void:
	main = p_main
	roster = p_roster
	var my_peer := NetService.node().my_id()
	for entry in roster:
		if int((entry as Dictionary).get("peer", 0)) == my_peer:
			my_team = int((entry as Dictionary).get("team", Fighter.TEAM_BLUE))
			break


## Una leyenda de la foto, YA interpolada (NetClient hace el lerp): la pinta si ya existe, o la crea
## si es la primera vez que aparece.
func apply_fighter(id: int, pos: Vector3, yaw: float, anim_idx: int, hp: float, marked: bool) -> void:
	var a: Actor = actors.get(id)
	if a == null:
		a = _spawn(id)
		if a == null:
			return
		actors[id] = a
	_seen[id] = true
	a.body.position = pos
	if a.model != null:
		a.model.rotation.y = yaw
	if anim_idx != a.last_anim:
		a.last_anim = anim_idx
		var aname := NetCodec.anim_name(anim_idx)
		for p: AnimationPlayer in a.anims:
			if p.has_animation(aname):
				p.play(aname)
	main._set_bar(a.bar, hp)
	if a.bar != null:
		a.bar.visible = hp > 0.0
	if marked != a.marked:
		a.marked = marked
		MarkFx.apply(a.model, marked)


## Cierra la foto: quien no ha aparecido esta vez (`apply_fighter` no lo ha tocado) ha dejado de
## venir -se borra su nodo-. Llamarlo una vez por FOTOGRAMA DE PANTALLA pintado (60-144 Hz), después
## de todos los `apply_fighter` de esa vuelta.
## `actors.keys()` copia un Array nuevo cada vez que se llama (revisión de la tarea 4, hallazgo 1): con
## `combat.fighters` sin encoger nunca a media partida (solo `append`, `game/combat.gd`), lo normal es
## que NADIE deje de venir en ninguna foto, así que el barrido de abajo (y su asignación) se salta
## entero salvo el fotograma en el que de verdad falta alguien -que además solo puede pasar una vez
## por leyenda, cuando muere del todo o la Horda en línea (fase 3) quite una criatura-.
func finish_frame() -> void:
	if _seen.size() < actors.size():
		for id in actors.keys():
			if not _seen.has(id):
				var a: Actor = actors[id]
				if a.body != null and is_instance_valid(a.body):
					a.body.queue_free()
				actors.erase(id)
	_seen.clear()


## Fin de la partida o desconexión: fuera todo lo que se había pintado.
func clear() -> void:
	for id in actors:
		var a: Actor = actors[id]
		if a.body != null and is_instance_valid(a.body):
			a.body.queue_free()
	actors.clear()
	_seen.clear()


func _spawn(id: int) -> Actor:
	if id < 0 or id >= roster.size():
		return null      # una foto de otra partida o un id fuera del reparto: no se pinta
	var entry: Dictionary = roster[id]
	var legend := clampi(int(entry.get("legend", 0)), 0, LegendData.LEGENDS.size() - 1)
	var team := int(entry.get("team", Fighter.TEAM_BLUE))
	var data: Dictionary = LegendData.LEGENDS[legend]
	var a := Actor.new()
	a.body = Node3D.new()
	main.add_child(a.body)
	var made := main._make_character(data["models"])
	a.model = made.get("node")
	if a.model != null:
		main._tint_model(a.model, data["tint"])
		var sc := float(data.get("scale", 1.0))
		if sc != 1.0:
			a.model.scale = Vector3.ONE * sc
		main._attach_weapon(a.model, String(data.get("weapon", "")))
		a.body.add_child(a.model)
	a.anims = made.get("anims", [])
	if a.anims.size() > 0:
		main._play_all(a.anims, "Idle")
	var height := 2.25
	if a.model != null:
		height = maxf(main._model_top(a.model) * maxf(a.model.scale.y, 0.01), 1.2) + Main.BAR_GAP
	if data.has("bar"):
		height = float(data["bar"])
	a.bar = main._make_bar(a.body, height, Main.BAR_ALLY if team == my_team else Main.BAR_ENEMY)
	var label := Label3D.new()
	label.text = String(entry.get("name", data.get("name", "")))
	label.font_size = 44
	label.pixel_size = 0.004
	label.outline_size = 12
	label.modulate = TeamMode.TEAM_COLORS.get(team, Color.WHITE)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.render_priority = 10
	label.position = Vector3(0, height + 0.32, 0)
	a.body.add_child(label)
	return a
