## Navegación de los bots sobre la rejilla del mapa (`[x][y]` de main.gd) con AStarGrid2D: 8
## direcciones sin cortar esquinas, igual que el campo de flujo de la horda. Las criaturas siguen
## usando su campo de flujo (una búsqueda para 40 bichos hacia UN objetivo); los bots van cada uno
## a su sitio y aquí piden su propio camino. Probado en tests/test_game_modes.gd.
class_name NavGrid
extends RefCounted

var astar := AStarGrid2D.new()
var width := 0
var height := 0


func build(grid: Array) -> void:
	width = grid.size()
	height = (grid[0] as PackedInt32Array).size() if width > 0 else 0
	astar.region = Rect2i(0, 0, width, height)
	astar.cell_size = Vector2.ONE
	astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	astar.default_compute_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	astar.default_estimate_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	astar.update()
	for x in width:
		for y in height:
			if not MapBuilder.walkable(grid[x][y]):
				astar.set_point_solid(Vector2i(x, y), true)


func inside(c: Vector2i) -> bool:
	return c.x >= 0 and c.y >= 0 and c.x < width and c.y < height


func walkable(c: Vector2i) -> bool:
	return inside(c) and not astar.is_point_solid(c)


## Camino de celdas de `from` a `to`, ambas incluidas. Si `to` está bloqueada se va a la celda
## transitable más cercana; si no hay camino entero, el tramo que acerque más (allow_partial_path).
func path(from: Vector2i, to: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	if not walkable(from):
		from = nearest_walkable(from)
		if not walkable(from):
			return out
	if not walkable(to):
		to = nearest_walkable(to)
		if not walkable(to):
			return out
	for c in astar.get_id_path(from, to, true):
		out.append(c)
	return out


## La celda transitable más cercana a `c` (anillos crecientes; `c` si ninguna en 6 celdas).
func nearest_walkable(c: Vector2i) -> Vector2i:
	if walkable(c):
		return c
	for r in range(1, 7):
		var best := Vector2i(-1, -1)
		var best_d := INF
		for dx in range(-r, r + 1):
			for dy in range(-r, r + 1):
				if maxi(absi(dx), absi(dy)) != r:
					continue
				var n := c + Vector2i(dx, dy)
				if walkable(n):
					var d := Vector2(dx, dy).length()
					if d < best_d:
						best_d = d
						best = n
		if best.x >= 0:
			return best
	return c
