## Prueba de lógica pura del mapa de la Horda con la semilla del juego (main.MAP_SEED = 1234):
##   godot --headless --path . -s tests/test_map.gd
## Sin autoloads ni escena: solo MapBuilder/DungeonGen, los mismos ficheros que el juego 2D.
## Las cifras son las del README ("42×42 celdas, 1.302 de suelo, 462 bloqueadas, 6 tumbas"): si
## cambian, o cambió map_builder.gd (hay que copiarlo del 2D con tools/sync_2d.sh) o cambió
## MAP_SEED. Código de salida 1 si hay fallos.
extends SceneTree

const SEED := 1234   # main.MAP_SEED (no se puede leer de main.gd sin instanciar la escena)

func _init() -> void:
	var failures := 0
	var m: Dictionary = MapBuilder.horde_map(SEED)
	var grid: Array = m["grid"]
	var zones: Array = m["zones"]
	var h := grid.size()
	var w := MapBuilder.width(grid)
	if w != 42 or h != 42:
		print("FALLO: el mapa mide %dx%d, se esperaba 42x42" % [w, h])
		failures += 1
	var floor_n := 0
	var blocked := 0
	for y in h:
		for x in w:
			if MapBuilder.walkable(grid[y][x]):
				floor_n += 1
			if MapBuilder.blocks(grid[y][x]):
				blocked += 1
	if floor_n != 1302 or blocked != 462:
		print("FALLO: suelo=%d bloqueadas=%d (README: 1302 / 462)" % [floor_n, blocked])
		failures += 1
	if not MapBuilder.all_connected(grid):
		print("FALLO: el mapa no es conexo")
		failures += 1
	if not MapBuilder.dead_end_cells(grid).is_empty() or not MapBuilder.trapped_cells(grid).is_empty():
		print("FALLO: callejones o bolsas sin huida: %s %s" % [MapBuilder.dead_end_cells(grid), MapBuilder.trapped_cells(grid)])
		failures += 1
	var rooms: Array = m["rooms"]
	if rooms.size() < 4:
		print("FALLO: %d salas de cueva, se esperaban al menos 4" % rooms.size())
		failures += 1
	var graves: Array = MapBuilder.cemetery_graves(grid, zones, SEED)
	if graves.size() != 6:
		print("FALLO: %d tumbas, se esperaban 6" % graves.size())
		failures += 1
	var edges: Array = MapBuilder.edge_cells(grid)
	if edges.size() < 20:
		print("FALLO: solo %d celdas de borde" % edges.size())
		failures += 1
	# Determinismo: dos llamadas con la misma semilla dan el mismo mapa.
	var m2: Dictionary = MapBuilder.horde_map(SEED)
	if m2["grid"] != grid or m2["zones"] != zones:
		print("FALLO: horde_map no es determinista con la misma semilla")
		failures += 1

	# --- Convención de índices ---
	# MapBuilder guarda grid[y][x] y devuelve celdas Vector2i(x, y); main.gd lee grid[x][y] sobre
	# la rejilla TRANSPUESTA (MapLayout.transpose). Leídas así, todas las celdas de MapBuilder tienen
	# que caer donde dicen. Antes de transponer, 11 celdas de entrada de la horda eran roca de cueva.
	var tgrid := MapLayout.transpose(grid)
	var tzones := MapLayout.transpose(zones)
	var bad_edges := 0
	for c: Vector2i in edges:
		if not MapBuilder.walkable(tgrid[c.x][c.y]):
			bad_edges += 1
	if bad_edges > 0:
		print("FALLO: %d de %d celdas de borde caen en celda bloqueada leídas como main.gd" % [bad_edges, edges.size()])
		failures += 1
	for c: Vector2i in graves:
		if not MapBuilder.walkable(tgrid[c.x][c.y]) or tzones[c.x][c.y] != 2:
			print("FALLO: tumba %s fuera del cementerio o en celda bloqueada leída como main.gd" % c)
			failures += 1

	print("test_map: %s (%d fallos) — %dx%d, suelo %d, bloqueadas %d, tumbas %d, bordes %d"
		% ["OK" if failures == 0 else "FALLO", failures, w, h, floor_n, blocked, graves.size(), edges.size()])
	quit(1 if failures > 0 else 0)
