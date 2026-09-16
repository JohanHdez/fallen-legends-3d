## Mapa isométrico: rejilla de la arena, geometría de celdas (192×96, como los tiles de Flare),
## colisión, navegación y utilidades de conectividad/spawns. Todo determinista por semilla.
## El dibujo del mapa está en map_view.gd.
class_name MapBuilder
extends RefCounted

const FLOOR := 0
const WALL := 1
const WATER := 2    # bloquea como un muro pero es plano (se ve a través)
const BRIDGE := 3   # transitable, se dibuja como puente
const MOUNTAIN := 4 # bloquea; se dibuja como macizo de roca

static func walkable(v: int) -> bool:
	return v == FLOOR or v == BRIDGE

static func blocks(v: int) -> bool:
	return v == WALL or v == WATER or v == MOUNTAIN
## Tamaño de celda isométrica (el de los tiles de Flare).
const TILE_W := 192
const TILE_H := 96

## Rombo de una celda, relativo a su centro (colisión y navegación).
static func diamond() -> PackedVector2Array:
	return PackedVector2Array([Vector2(0, -TILE_H / 2.0), Vector2(TILE_W / 2.0, 0), Vector2(0, TILE_H / 2.0), Vector2(-TILE_W / 2.0, 0)])

## Centro en el mundo de una celda (rombo hacia abajo, como TileMap "diamond down").
static func cell_center(c: Vector2i) -> Vector2:
	return Vector2((c.x - c.y) * TILE_W / 2.0 + TILE_W / 2.0, (c.x + c.y) * TILE_H / 2.0 + TILE_H / 2.0)

## Celda que contiene un punto del mundo.
static func world_to_cell(p: Vector2) -> Vector2i:
	var a := (p.x - TILE_W / 2.0) / (TILE_W / 2.0)   # x - y
	var b := (p.y - TILE_H / 2.0) / (TILE_H / 2.0)   # x + y
	return Vector2i(roundi((a + b) / 2.0), roundi((b - a) / 2.0))

## Muros que tocan suelo: los únicos que se dibujan y colisionan (el resto es roca invisible).
static func touches_floor(grid: Array, x: int, y: int) -> bool:
	for dy in [-1, 0, 1]:
		for dx in [-1, 0, 1]:
			if (dx != 0 or dy != 0) and walkable(get_cell(grid, x + dx, y + dy)):
				return true
	return false

## Añade al cuerpo estático un polígono por cada muro que toca suelo.
## Muros y montañas en `body` (capa 2). El agua va en `water_body` (capa 8) si se da: bloquea el paso de
## jugadores y criaturas, pero los proyectiles la sobrevuelan (como en Flare).
static func build_collision(grid: Array, body: StaticBody2D, water_body: StaticBody2D = null) -> void:
	for c in body.get_children():
		c.queue_free()
	if water_body:
		for c in water_body.get_children():
			c.queue_free()
	for y in grid.size():
		for x in width(grid):
			var v: int = grid[y][x]
			if blocks(v) and touches_floor(grid, x, y):
				var poly := CollisionPolygon2D.new()
				poly.polygon = diamond()
				poly.position = cell_center(Vector2i(x, y))
				(water_body if v == WATER and water_body else body).add_child(poly)

# ---------------------------------------------------------------------------
# Navegación: un solo mallado horneado a partir de los contornos del suelo, con margen de agente
# ---------------------------------------------------------------------------
const AGENT_RADIUS := 12.0

static func build_navigation(grid: Array, region: NavigationRegion2D, obstacles: Array[Vector2] = []) -> void:
	var src := NavigationMeshSourceGeometryData2D.new()
	for o in obstacles:
		var r := 34.0
		src.add_obstruction_outline(PackedVector2Array([o + Vector2(-r, -r * 0.5), o + Vector2(r, -r * 0.5), o + Vector2(r, r * 0.5), o + Vector2(-r, r * 0.5)]))
	for loop in floor_outlines(grid):
		# Contornos exteriores (área horaria en pantalla) = transitables; huecos = obstrucciones.
		if _signed_area(loop) > 0.0:
			src.add_traversable_outline(loop)
		else:
			loop.reverse()
			src.add_obstruction_outline(loop)
	var navpoly := NavigationPolygon.new()
	navpoly.agent_radius = AGENT_RADIUS
	NavigationServer2D.bake_from_source_geometry_data(navpoly, src)
	region.navigation_polygon = navpoly

## Contornos cerrados del área de suelo: aristas de cada rombo en orden horario; las aristas
## compartidas por dos celdas de suelo se anulan y las restantes se encadenan en bucles.
static func floor_outlines(grid: Array) -> Array[PackedVector2Array]:
	var edges := {}   # Vector2i(origen) -> Array[Vector2i(destino)]
	var offsets := [Vector2i(0, -TILE_H / 2), Vector2i(TILE_W / 2, 0), Vector2i(0, TILE_H / 2), Vector2i(-TILE_W / 2, 0)]
	for y in grid.size():
		for x in width(grid):
			if not walkable(grid[y][x]):
				continue
			var c := Vector2i(cell_center(Vector2i(x, y)).round())
			for i in 4:
				var a: Vector2i = c + offsets[i]
				var b: Vector2i = c + offsets[(i + 1) % 4]
				if edges.has(b) and (edges[b] as Array).has(a):
					(edges[b] as Array).erase(a)
					if (edges[b] as Array).is_empty():
						edges.erase(b)
				else:
					if not edges.has(a):
						edges[a] = []
					(edges[a] as Array).append(b)
	var loops: Array[PackedVector2Array] = []
	while not edges.is_empty():
		var start: Vector2i = edges.keys()[0]
		var loop := PackedVector2Array([Vector2(start)])
		var cur: Vector2i = _pop_edge(edges, start)
		var guard := 0
		while cur != start and guard < 100000:
			loop.append(Vector2(cur))
			cur = _pop_edge(edges, cur)
			guard += 1
		loops.append(loop)
	return loops

static func _pop_edge(edges: Dictionary, from: Vector2i) -> Vector2i:
	var outs: Array = edges[from]
	var to: Vector2i = outs.pop_back()
	if outs.is_empty():
		edges.erase(from)
	return to

static func _signed_area(poly: PackedVector2Array) -> float:
	var a := 0.0
	for i in poly.size():
		var p := poly[i]
		var q := poly[(i + 1) % poly.size()]
		a += p.x * q.y - q.x * p.y
	return a * 0.5

# ---------------------------------------------------------------------------
# Rejillas
# ---------------------------------------------------------------------------
static func empty_grid(w: int, h: int, value := WALL) -> Array:
	var grid: Array = []
	for y in h:
		var row := PackedInt32Array()
		row.resize(w)
		row.fill(value)
		grid.append(row)
	return grid

static func width(grid: Array) -> int:
	return grid[0].size() if grid.size() > 0 else 0

static func get_cell(grid: Array, x: int, y: int) -> int:
	if y < 0 or y >= grid.size() or x < 0 or x >= grid[y].size():
		return WALL
	return grid[y][x]

## Arena estilo "Age of Empires": borde de bosque, bosques en grupos, pedregales y claros. Simétrica
## en los 4 cuadrantes y siempre conexa. Con `river`, un río de 3 celdas (x - y ∈ {0, 1, 2}, vertical en
## pantalla) separa los dos lados y se cruza por tres puentes de 3 celdas.
static func arena_grid(seed: int, w := 18, h := 18, river := false) -> Array:
	for attempt in 12:
		var rng := RandomNumberGenerator.new()
		rng.seed = seed + attempt * 7919
		var grid := empty_grid(w, h, FLOOR)
		for x in w:
			grid[0][x] = WALL
			grid[h - 1][x] = WALL
		for y in h:
			grid[y][0] = WALL
			grid[y][w - 1] = WALL
		# Bosques: grupos de 3-7 celdas por paseo aleatorio, espejados en los 4 cuadrantes.
		var forests := 2 + (w - 14) / 6
		for i in forests:
			var c := Vector2i(rng.randi_range(2, w / 2 - 3), rng.randi_range(2, h / 2 - 3))
			var size := rng.randi_range(2, 5)
			for k in size:
				_set_mirrored(grid, c, WALL)
				c += [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)][rng.randi() % 4]
				c.x = clampi(c.x, 2, w / 2 - 3)
				c.y = clampi(c.y, 2, h / 2 - 3)
		# Pedregales: 1-2 rocas sueltas por cuadrante.
		for i in rng.randi_range(1, 2):
			_set_mirrored(grid, Vector2i(rng.randi_range(2, w / 2 - 2), rng.randi_range(2, h / 2 - 2)), WALL)
		# Montañas: macizos de 6-14 celdas por paseo aleatorio, espejados.
		var mountains := 1 + (w - 14) / 8
		for i in mountains:
			var c := Vector2i(rng.randi_range(3, w / 2 - 4), rng.randi_range(3, h / 2 - 4))
			var size := rng.randi_range(6, 14)
			for k in size:
				_set_mirrored(grid, c, MOUNTAIN)
				var dir: Vector2i = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)][rng.randi() % 4]
				c += dir
				c.x = clampi(c.x, 3, w / 2 - 4)
				c.y = clampi(c.y, 3, h / 2 - 4)
		if river:
			# Río de 3 filas (a lo largo del eje x: diagonal limpia en pantalla, como en Age of Empires)
			# y tres puentes de 2 celdas de ancho que lo cruzan por el eje y.
			var c := h / 2 - 1
			var bridges := [w / 2 - 1, rng.randi_range(3, w / 2 - 5), rng.randi_range(w / 2 + 3, w - 5)]
			for y in range(c - 1, c + 4):
				for x in range(1, w - 1):
					if y == c - 1 or y == c + 3:
						grid[y][x] = FLOOR   # orillas despejadas
						continue
					var on_bridge := false
					for bx in bridges:
						if x == bx or x == bx + 1:
							on_bridge = true
					grid[y][x] = BRIDGE if on_bridge else WATER
		# Los claros de aparición no tienen obstáculos.
		for y in range(1, h - 1):
			for x in range(1, w - 1):
				if grid[y][x] != WALL and grid[y][x] != MOUNTAIN:
					continue
				if river:
					if y <= 3 or y >= h - 4:
						grid[y][x] = FLOOR
				elif x - y <= -(w - 3) + 2 or x - y >= (w - 3) - 2:
					grid[y][x] = FLOOR
		if all_connected(grid) and spawn_cells(grid, 1).size() >= 4 and spawn_cells(grid, 2).size() >= 4:
			return grid
	return empty_grid(w, h, FLOOR)

static func _set_mirrored(grid: Array, c: Vector2i, v: int) -> void:
	var w := width(grid)
	var h := grid.size()
	for m in [c, Vector2i(w - 1 - c.x, c.y), Vector2i(c.x, h - 1 - c.y), Vector2i(w - 1 - c.x, h - 1 - c.y)]:
		if m.x > 0 and m.x < w - 1 and m.y > 0 and m.y < h - 1:
			grid[m.y][m.x] = v

## Todas las celdas de suelo son alcanzables entre sí.
static func all_connected(grid: Array) -> bool:
	var w := width(grid)
	var h := grid.size()
	var start := Vector2i(-1, -1)
	var total := 0
	for y in h:
		for x in w:
			if walkable(grid[y][x]):
				total += 1
				if start.x < 0:
					start = Vector2i(x, y)
	if total == 0:
		return false
	var seen := {}
	var stack: Array[Vector2i] = [start]
	seen[start] = true
	while stack.size() > 0:
		var c: Vector2i = stack.pop_back()
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n: Vector2i = c + d
			if walkable(get_cell(grid, n.x, n.y)) and not seen.has(n):
				seen[n] = true
				stack.append(n)
	return seen.size() == total

static func has_water(grid: Array) -> bool:
	for row in grid:
		for v in row:
			if v == WATER:
				return true
	return false

## Celdas de suelo rodeadas de suelo (aptas para aparecer). side: 0 = cualquiera, 1 y 2 = cada bando.
## Sin río, los bandos son las puntas izquierda/derecha; con río, cada orilla (filas altas y bajas).
static func spawn_cells(grid: Array, side := 0) -> Array[Vector2i]:
	var w := width(grid)
	var h := grid.size()
	var river := has_water(grid)
	var out: Array[Vector2i] = []
	for y in h:
		for x in w:
			if grid[y][x] != FLOOR:
				continue
			# Lejos del borde de bosque (que tapa la vista).
			if x < 3 or y < 3 or x > w - 4 or y > h - 4:
				continue
			if river:
				# Cada orilla aparece en su franja despejada (sin bosques), lejos del río.
				if side == 1 and y > 3:
					continue
				if side == 2 and y < h - 4:
					continue
			else:
				# En pantalla la x crece con (x - y): izquierda = puntas con x - y muy negativo.
				if side == 1 and x - y >= -w / 4:
					continue
				if side == 2 and x - y <= w / 4:
					continue
			if grid[y][x] != FLOOR:
				continue
			var ok := true
			for dy in [-1, 0, 1]:
				for dx in [-1, 0, 1]:
					if get_cell(grid, x + dx, y + dy) != FLOOR:
						ok = false
			if ok:
				out.append(Vector2i(x, y))
	return out

# ---------------------------------------------------------------------------
# Campo de la Horda: mapa grande y abierto, sin callejones ni bolsas
# ---------------------------------------------------------------------------
## Los obstáculos van en una rejilla de bloques de HORDE_BLOCK celdas: cada bloque deja un margen de
## HORDE_MARGIN celdas y lleva 1-2 rectángulos (bosque/pedregal o montaña) en su interior, o queda
## despejado. Así entre grupos siempre hay pasillos de 2·HORDE_MARGIN celdas que forman una malla de
## bucles: desde cualquier punto hay al menos dos direcciones de huida. En algunos cruces se deja una
## roca suelta como pilar para rodear. Los jugadores aparecen en el centro y los zombis entran por el
## anillo junto al borde (`edge_cells`).
const HORDE_BLOCK := 8
const HORDE_MARGIN := 2
const ESCAPE_LEN := 2   # celdas libres en línea recta que cuentan como vía de huida (detecta bolsas, tolera pilares)

const CAVE_W := 10   # cuevas de esquina: ancho (bloque de la esquina + anillo) y alto a lo largo del borde;
const CAVE_H := 18   # sus lados hacia el campo dan siempre a un pasillo (nunca a un grupo de árboles)
const CAVE_ROOMS := 4
## Cementerio: cuadrado de la esquina norte (la opuesta a las cuevas) marcado como zona 2; ahí van
## las tumbas malditas (objetos `tumba` de las que brotan zombis), separadas GRAVE_GAP celdas.
const CEMETERY_SIZE := 12
const GRAVES := 6
const GRAVE_GAP := 3

## Mapa completo de la horda: el campo de `horde_grid` más dos cuevas en las esquinas este y oeste
## (salas unidas en anillo por pasillos de 2 celdas, con varias entradas desde el campo, así que
## siguen sin existir callejones) y el cementerio de la esquina norte. Devuelve {"grid", "zones"
## (1 = cueva, para dibujarla con su tileset; 2 = cementerio, teñido), "rooms" (Rect2i de las
## salas), "cemetery" (Rect2i)}. Determinista por semilla.
static func horde_map(seed: int, w := 42, h := 42) -> Dictionary:
	for attempt in 16:
		var rng := RandomNumberGenerator.new()
		rng.seed = seed + attempt * 6151
		var grid := _horde_field(rng, w, h)
		var zones := empty_grid(w, h, 0)
		var rooms: Array[Rect2i] = []
		var east := Rect2i(w - 1 - CAVE_W, 1, CAVE_W, CAVE_H)
		var west := Rect2i(1, h - 1 - CAVE_H, CAVE_W, CAVE_H)
		var east_rooms := _carve_cave(grid, zones, rng, east, [Vector2i(-1, 0), Vector2i(0, 1)])
		var west_rooms := _carve_cave(grid, zones, rng, west, [Vector2i(1, 0), Vector2i(0, -1)])
		rooms.append_array(east_rooms)
		rooms.append_array(west_rooms)
		if east_rooms.size() < 2 or west_rooms.size() < 2:
			continue
		_fill_cave_pockets(grid, zones)
		if all_connected(grid) and dead_end_cells(grid).is_empty() and trapped_cells(grid).is_empty() and edge_cells(grid).size() >= 20:
			return {"grid": grid, "zones": zones, "rooms": rooms, "cemetery": _mark_cemetery(zones)}
	var fallback := horde_grid(seed, w, h)
	var fallback_zones := empty_grid(w, h, 0)
	return {"grid": fallback, "zones": fallback_zones, "rooms": [], "cemetery": _mark_cemetery(fallback_zones)}

## Marca como zona 2 (cementerio) el cuadrado de la esquina norte que no sea cueva; devuelve su rectángulo.
static func _mark_cemetery(zones: Array) -> Rect2i:
	var rect := Rect2i(1, 1, CEMETERY_SIZE, CEMETERY_SIZE)
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			if zones[y][x] == 0:
				zones[y][x] = 2
	return rect

## Celdas para las tumbas del cementerio: suelo despejado (8 vecinos de suelo) de la zona 2, hasta GRAVES,
## separadas al menos GRAVE_GAP celdas (Chebyshev) para no cerrar los pasillos. Determinista por semilla.
static func cemetery_graves(grid: Array, zones: Array, seed: int) -> Array[Vector2i]:
	var candidates: Array[Vector2i] = []
	for y in grid.size():
		for x in width(grid):
			if not zones.is_empty() and zones[y][x] == 2 and grid[y][x] == FLOOR and open_cell(grid, Vector2i(x, y)):
				candidates.append(Vector2i(x, y))
	var rng := RandomNumberGenerator.new()
	rng.seed = seed ^ 0x27d4eb2f
	for i in range(candidates.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp := candidates[i]
		candidates[i] = candidates[j]
		candidates[j] = tmp
	var out: Array[Vector2i] = []
	for c in candidates:
		if out.size() >= GRAVES:
			break
		var far := true
		for g in out:
			if maxi(absi(g.x - c.x), absi(g.y - c.y)) < GRAVE_GAP:
				far = false
				break
		if far:
			out.append(c)
	return out

## Cueva de esquina: rellena `region` de roca, excava CAVE_ROOMS salas unidas en anillo y abre una
## entrada por cada tramo de campo que toca los lados indicados en `field_sides` (direcciones hacia
## el campo). Las salas pueden tocar el borde del mapa: por ahí también entran zombis.
static func _carve_cave(grid: Array, zones: Array, rng: RandomNumberGenerator, region: Rect2i, field_sides: Array) -> Array[Rect2i]:
	for y in range(region.position.y, region.end.y):
		for x in range(region.position.x, region.end.x):
			grid[y][x] = WALL
			zones[y][x] = 1
	var rooms: Array[Rect2i] = []
	var tries := 0
	while rooms.size() < CAVE_ROOMS and tries < 200:
		tries += 1
		var rw := rng.randi_range(4, 6)   # con 3 quedarían celdas con una sola vía de huida en los extremos
		var rh := rng.randi_range(4, 6)
		# Margen de 2 hacia el campo (para que la roca se vea) y ninguno hacia el borde del mapa.
		var x0 := region.position.x + (2 if Vector2i(-1, 0) in field_sides else 0)
		var x1 := region.end.x - rw - (2 if Vector2i(1, 0) in field_sides else 0)
		var y0 := region.position.y + (2 if Vector2i(0, -1) in field_sides else 0)
		var y1 := region.end.y - rh - (2 if Vector2i(0, 1) in field_sides else 0)
		if x1 < x0 or y1 < y0:
			continue
		var rect := Rect2i(rng.randi_range(x0, x1), rng.randi_range(y0, y1), rw, rh)
		if rooms.is_empty():
			# La primera sala toca el borde del mapa: por ahí entran zombis (celdas de `edge_cells`).
			if Vector2i(1, 0) not in field_sides:
				rect.position.x = x1
			elif Vector2i(-1, 0) not in field_sides:
				rect.position.x = x0
		var overlaps := false
		for r in rooms:
			if r.grow(1).intersects(rect):
				overlaps = true
				break
		if not overlaps:
			rooms.append(rect)
	if rooms.size() < 2:
		return rooms
	for r in rooms:
		DungeonGen._carve_rect(grid, r)
	# Anillo: salas ordenadas por ángulo alrededor del centro y unidas en círculo (siempre dos caminos).
	var center := Vector2(region.get_center())
	rooms.sort_custom(func(a: Rect2i, b: Rect2i) -> bool:
		return (Vector2(a.get_center()) - center).angle() < (Vector2(b.get_center()) - center).angle())
	for i in rooms.size():
		DungeonGen._carve_corridor(grid, rng, rooms[i].get_center(), rooms[(i + 1) % rooms.size()].get_center())
	# Entradas: cada tramo de suelo del campo pegado a un lado abre un pasillo hasta la sala más cercana.
	for side in field_sides:
		var runs := _outside_floor_runs(grid, region, side)
		for run in runs:
			var entrance: Vector2i = run
			var best: Rect2i = rooms[0]
			var best_d := 1.0e9
			for r in rooms:
				var d := Vector2(r.get_center()).distance_to(Vector2(entrance))
				if d < best_d:
					best_d = d
					best = r
			DungeonGen._carve_corridor(grid, rng, entrance, best.get_center())
	return rooms

## Tapia las celdas de cueva sin dos vías de huida (rincones de pasillos) hasta que no quede ninguna;
## la comprobación de conexión posterior descarta el intento si eso partiera la cueva.
static func _fill_cave_pockets(grid: Array, zones: Array) -> void:
	for round in 12:
		var filled := 0
		for c in dead_end_cells(grid) + trapped_cells(grid):
			if zones[c.y][c.x] == 1 and walkable(grid[c.y][c.x]):
				grid[c.y][c.x] = WALL
				filled += 1
		if filled == 0:
			return

## Celdas del borde interior de `region` (lado `side`) en el centro de cada tramo de suelo exterior.
static func _outside_floor_runs(grid: Array, region: Rect2i, side: Vector2i) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	if side.x != 0:
		var x := region.position.x if side.x < 0 else region.end.x - 1
		for y in range(region.position.y, region.end.y):
			cells.append(Vector2i(x, y))
	else:
		var y := region.position.y if side.y < 0 else region.end.y - 1
		for x in range(region.position.x, region.end.x):
			cells.append(Vector2i(x, y))
	var out: Array[Vector2i] = []
	var run: Array[Vector2i] = []
	cells.append(Vector2i(-99, -99))   # centinela: cierra el último tramo
	for c: Vector2i in cells:
		var outside: Vector2i = c + side
		if c.x >= 0 and walkable(get_cell(grid, outside.x, outside.y)):
			run.append(c)
		else:
			if run.size() >= 8:
				out.append(run[run.size() / 4])        # tramos largos: dos entradas
				out.append(run[run.size() * 3 / 4 - 1])
			elif run.size() >= 2:
				out.append(run[run.size() / 2 - 1])   # centro del tramo (el pasillo mide 2)
			run.clear()
	return out

## Solo el campo (sin cuevas): `horde_map` lo usa como base y las pruebas lo consultan.
static func horde_grid(seed: int, w := 42, h := 42) -> Array:
	for attempt in 16:
		var rng := RandomNumberGenerator.new()
		rng.seed = seed + attempt * 6151
		var grid := _horde_field(rng, w, h)
		if all_connected(grid) and dead_end_cells(grid).is_empty() and trapped_cells(grid).is_empty() and edge_cells(grid).size() >= 20:
			return grid
	var fallback := empty_grid(w, h, FLOOR)
	for x in w:
		fallback[0][x] = WALL
		fallback[h - 1][x] = WALL
	for y in h:
		fallback[y][0] = WALL
		fallback[y][w - 1] = WALL
	return fallback

## Campo abierto con la malla de bloques y pilares (sin validar).
static func _horde_field(rng: RandomNumberGenerator, w: int, h: int) -> Array:
	if true:
		var grid := empty_grid(w, h, FLOOR)
		for x in w:
			grid[0][x] = WALL
			grid[h - 1][x] = WALL
		for y in h:
			grid[y][0] = WALL
			grid[y][w - 1] = WALL
		var nx := (w - 6) / HORDE_BLOCK
		var ny := (h - 6) / HORDE_BLOCK
		var ox := (w - nx * HORDE_BLOCK) / 2
		var oy := (h - ny * HORDE_BLOCK) / 2
		var inner := HORDE_BLOCK - 2 * HORDE_MARGIN
		for by in ny:
			for bx in nx:
				var roll := rng.randf()
				if roll < 0.1:
					continue   # claro
				var v := MOUNTAIN if roll < 0.35 else WALL
				var base := Vector2i(ox + bx * HORDE_BLOCK + HORDE_MARGIN, oy + by * HORDE_BLOCK + HORDE_MARGIN)
				for k in rng.randi_range(1, 2):
					var rw := rng.randi_range(2, inner)
					var rh := rng.randi_range(2, inner)
					var r := Rect2i(base + Vector2i(rng.randi_range(0, inner - rw), rng.randi_range(0, inner - rh)), Vector2i(rw, rh))
					for y in range(r.position.y, r.end.y):
						for x in range(r.position.x, r.end.x):
							grid[y][x] = v
		# Pilares en los cruces de pasillos (nunca en el cruce central, donde se aparece).
		for by in range(1, ny):
			for bx in range(1, nx):
				if (bx == nx / 2 and by == ny / 2) or rng.randf() > 0.35:
					continue
				var c := Vector2i(ox + bx * HORDE_BLOCK + rng.randi_range(-1, 0), oy + by * HORDE_BLOCK + rng.randi_range(-1, 0))
				if open_cell(grid, c):
					grid[c.y][c.x] = WALL
		return grid
	return []

## Celda de suelo con las 8 vecinas de suelo (sitio despejado para aparecer o dejar recursos).
static func open_cell(grid: Array, c: Vector2i) -> bool:
	for dy in [-1, 0, 1]:
		for dx in [-1, 0, 1]:
			if get_cell(grid, c.x + dx, c.y + dy) != FLOOR:
				return false
	return true

## Celdas transitables con menos de dos vecinos ortogonales transitables (callejones de una celda).
static func dead_end_cells(grid: Array) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for y in grid.size():
		for x in width(grid):
			if not walkable(grid[y][x]):
				continue
			var n := 0
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				if walkable(get_cell(grid, x + d.x, y + d.y)):
					n += 1
			if n < 2:
				out.append(Vector2i(x, y))
	return out

## Celdas transitables desde las que no salen al menos dos vías de huida: una vía es una línea recta
## ortogonal de ESCAPE_LEN celdas libres. Detecta bolsas y pasillos cerrados de cualquier anchura.
static func trapped_cells(grid: Array) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for y in grid.size():
		for x in width(grid):
			if walkable(grid[y][x]) and escape_routes(grid, Vector2i(x, y)) < 2:
				out.append(Vector2i(x, y))
	return out

static func escape_routes(grid: Array, c: Vector2i) -> int:
	var routes := 0
	for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var ok := true
		for k in range(1, ESCAPE_LEN + 1):
			if not walkable(get_cell(grid, c.x + d.x * k, c.y + d.y * k)):
				ok = false
				break
		if ok:
			routes += 1
	return routes

## Celdas de suelo del anillo interior pegado al borde (por donde entran los zombis).
static func edge_cells(grid: Array) -> Array[Vector2i]:
	var w := width(grid)
	var h := grid.size()
	var out: Array[Vector2i] = []
	for y in range(1, h - 1):
		for x in range(1, w - 1):
			if (x == 1 or y == 1 or x == w - 2 or y == h - 2) and grid[y][x] == FLOOR:
				out.append(Vector2i(x, y))
	return out

## Celdas de suelo rodeadas de suelo a menos de `radius` celdas (Chebyshev) de `center`.
static func cells_near(grid: Array, center: Vector2i, radius: int) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for y in range(center.y - radius, center.y + radius + 1):
		for x in range(center.x - radius, center.x + radius + 1):
			if get_cell(grid, x, y) == FLOOR and open_cell(grid, Vector2i(x, y)):
				out.append(Vector2i(x, y))
	return out
