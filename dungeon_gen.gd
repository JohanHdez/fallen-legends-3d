## Generador de mazmorras por salas (lógica pura, determinista por semilla).
## Devuelve {"grid": Array, "rooms": [{"rect": Rect2i, "kind": "start"|"normal"|"boss"}]}.
class_name DungeonGen
extends RefCounted

const CORRIDOR_WIDTH := 2

static func generate(seed: int, w := 26, h := 26, room_count := 6) -> Dictionary:
	for attempt in 20:
		var rng := RandomNumberGenerator.new()
		rng.seed = seed + attempt * 104729
		var grid := MapBuilder.empty_grid(w, h, MapBuilder.WALL)
		var rooms: Array[Dictionary] = []
		var tries := 0
		while rooms.size() < room_count and tries < 400:
			tries += 1
			var rw := rng.randi_range(4, 6)
			var rh := rng.randi_range(4, 6)
			var rect := Rect2i(rng.randi_range(2, w - rw - 3), rng.randi_range(2, h - rh - 3), rw, rh)
			var overlaps := false
			for r in rooms:
				if (r.rect as Rect2i).grow(2).intersects(rect):
					overlaps = true
					break
			if not overlaps:
				rooms.append({"rect": rect, "kind": "normal"})
		if rooms.size() < 3:
			continue
		# Orden por distancia a la primera sala: la primera es el inicio, la última el jefe.
		var origin: Vector2i = (rooms[0].rect as Rect2i).get_center()
		var rest := rooms.slice(1)
		rest.sort_custom(func(a, b): return _dist2(a.rect.get_center(), origin) < _dist2(b.rect.get_center(), origin))
		var ordered: Array[Dictionary] = [rooms[0]]
		ordered.append_array(rest)
		rooms = ordered
		rooms[0].kind = "start"
		rooms[-1].kind = "boss"
		for r in rooms:
			_carve_rect(grid, r.rect)
		for i in range(1, rooms.size()):
			_carve_corridor(grid, rng, (rooms[i - 1].rect as Rect2i).get_center(), (rooms[i].rect as Rect2i).get_center())
		if MapBuilder.all_connected(grid):
			return {"grid": grid, "rooms": rooms}
	# Fallback: una sola sala grande.
	var grid := MapBuilder.empty_grid(w, h, MapBuilder.WALL)
	var rect := Rect2i(4, 4, w - 8, h - 8)
	_carve_rect(grid, rect)
	return {"grid": grid, "rooms": [{"rect": rect, "kind": "start"}, {"rect": rect, "kind": "boss"}]}

static func _dist2(a: Vector2i, b: Vector2i) -> int:
	var d := a - b
	return d.x * d.x + d.y * d.y

static func _carve_rect(grid: Array, rect: Rect2i) -> void:
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			grid[y][x] = MapBuilder.FLOOR

## Pasillo en L (horizontal y luego vertical, o al revés) de CORRIDOR_WIDTH celdas.
static func _carve_corridor(grid: Array, rng: RandomNumberGenerator, from: Vector2i, to: Vector2i) -> void:
	var mid := Vector2i(to.x, from.y) if rng.randf() < 0.5 else Vector2i(from.x, to.y)
	_carve_line(grid, from, mid)
	_carve_line(grid, mid, to)

static func _carve_line(grid: Array, a: Vector2i, b: Vector2i) -> void:
	var w := MapBuilder.width(grid)
	var h := grid.size()
	var step := (b - a).sign()
	var c := a
	while true:
		for dy in CORRIDOR_WIDTH:
			for dx in CORRIDOR_WIDTH:
				var x := c.x + dx
				var y := c.y + dy
				if x > 0 and x < w - 1 and y > 0 and y < h - 1:
					grid[y][x] = MapBuilder.FLOOR
		if c == b:
			break
		c += step

## Celdas de suelo dentro de una sala (sin el borde), para colocar enemigos y jugadores.
static func room_cells(grid: Array, rect: Rect2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var inner := rect.grow(-1)
	for y in range(inner.position.y, inner.end.y):
		for x in range(inner.position.x, inner.end.x):
			if grid[y][x] == MapBuilder.FLOOR:
				out.append(Vector2i(x, y))
	return out
