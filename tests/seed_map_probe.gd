## Sonda: el plano de una partida, para VER qué cambia de una partida a otra (petición del usuario,
## 2026-09-18: "ver si cambian los arbustos a praderas donde sí se vean bien los enemigos").
##   godot --headless --path . -- --seed=N --touch --probe=seed_map_probe --out=/ruta/plano.png
##   godot --headless --path . -- --seed=N --mode=2v2 --probe=seed_map_probe --out=/ruta/plano.png
## Cada celda a 8 px: muro, agua, pradera, planicie (casi blanca) y hierba alta (verde oscuro).
## Encima: en la Horda, tu salida (blanco) y las celdas por donde entran las oleadas 1, 2 y 3
## (naranja, amarillo, rosa); por equipos, la zona de salida de cada uno (azul, rojo). Imprime qué
## parte de cada cosa cae en hierba alta y FALLA si sales con hierba alta al lado (la regla del
## 2026-09-18: se sale en campo abierto). `--seed=N` hace de la semilla que pone el menú (`fl_seed`).
extends Node

const PX := 8
const COL_ME := Color(1, 1, 1)
const COL_WAVES := [Color(1.0, 0.55, 0.1), Color(1.0, 0.9, 0.2), Color(1.0, 0.4, 0.75)]
const COL_TEAM := {1: Color(0.35, 0.65, 1.0), 2: Color(1.0, 0.25, 0.2)}

var main: Node


func _ready() -> void:
	main = get_parent()
	for i in 3:
		await get_tree().physics_frame      # que el modo termine de montarse
	var img := Image.create(main.mw * PX, main.mh * PX, false, Image.FORMAT_RGB8)
	for x in main.mw:
		for y in main.mh:
			img.fill_rect(Rect2i(x * PX, y * PX, PX, PX), _terrain(x, y))
	var lines: Array = ["semilla %s · hierba alta: %d celdas (%d %% del campo) · planicie: %d" % [
		main._args.get("seed", "-"), _count(main.tall_grass), _field_pct(main.tall_grass), _count(main.plains)]]
	var problems: Array = []
	if main.team_mode != null:
		var a1: Array = main.team_mode.areas.get(1, [])
		var a2: Array = main.team_mode.areas.get(2, [])
		if not a1.is_empty() and not a2.is_empty():
			var apart := Vector2(a1[0]).distance_to(Vector2(a2[0]))
			lines.append("las zonas de salida quedan a %.0f celdas (%.0f m)" % [apart, apart * Main.CELL])
		for team in [1, 2]:
			var cells: Array = main.team_mode.areas.get(team, [])
			for c: Vector2i in cells:
				_dot(img, c, COL_TEAM[team], 3)
			lines.append("zona %s: %d %% en hierba alta" % ["azul" if team == 1 else "roja", _tall_pct(cells)])
			if _tall_pct(cells) > 0:
				problems.append("la zona de salida %d tiene hierba alta" % team)
	elif main.horde != null:
		var h: Horde = main.horde
		var saved: int = h.wave
		for w in 3:
			h.wave = w + 1
			var cells: Array = h._wave_spawn_cells()
			for c: Vector2i in cells:
				_dot(img, c, COL_WAVES[w], 2)
			lines.append("oleada %d: entra por %d celdas, %d %% en hierba alta" % [w + 1, cells.size(), _tall_pct(cells)])
		h.wave = saved
		var me: Vector2i = main._cell_of(main.player.global_position)
		_dot(img, me, COL_ME, 3)
		var around := _tall_pct(main._cells_around(me, 3))
		lines.append("tu salida (%d, %d): %s, %d %% de hierba alta a 3 celdas" % [me.x, me.y,
			"en hierba alta" if main.tall_grass[me.x][me.y] else "en pradera", around])
		if around > 0:
			problems.append("sales con hierba alta a menos de 3 celdas")
	if main._args.has("out"):
		img.save_png(String(main._args["out"]))
	for l in lines:
		print("[PLANO] %s" % l)
	for p in problems:
		print("[PLANO] problema: %s" % p)
	print("seed_map_probe: %s" % ("OK" if problems.is_empty() else "FALLO"))
	main.get_tree().quit(0 if problems.is_empty() else 1)


func _terrain(x: int, y: int) -> Color:
	var cell: int = main.grid[x][y]
	if cell == MapBuilder.WATER:
		return Minimap.COL_WATER
	if not MapBuilder.walkable(cell):
		return Minimap.COL_BLOCK
	if main.tall_grass[x][y]:
		return Color(0.12, 0.42, 0.10)       # más oscura y saturada que en el minimapa, para verla bien
	if main.plains[x][y]:
		return Color(0.86, 0.90, 0.72)       # planicie: casi rasa
	return Color(0.62, 0.72, 0.50)


func _dot(img: Image, c: Vector2i, col: Color, size: int) -> void:
	var o := (PX - size * 2) / 2
	img.fill_rect(Rect2i(c.x * PX + o, c.y * PX + o, size * 2, size * 2), col)


func _count(m: Array) -> int:
	var n := 0
	for x in main.mw:
		for y in main.mh:
			if m[x][y]:
				n += 1
	return n


## Qué parte de la pradera transitable (zona 0) ocupa un mapa.
func _field_pct(m: Array) -> int:
	var n := 0
	var field := 0
	for x in main.mw:
		for y in main.mh:
			if MapBuilder.walkable(main.grid[x][y]) and int(main.zones[x][y]) == 0:
				field += 1
				if m[x][y]:
					n += 1
	return int(round(100.0 * n / maxf(field, 1.0)))


func _tall_pct(cells: Array) -> int:
	if cells.is_empty():
		return 0
	var n := 0
	for c: Vector2i in cells:
		if main.tall_grass[c.x][c.y]:
			n += 1
	return int(round(100.0 * n / cells.size()))
