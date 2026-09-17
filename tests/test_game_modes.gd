## Prueba de lógica pura de GameModes y NavGrid (game/game_modes.gd, game/nav_grid.gd):
##   godot --headless --path . -s tests/test_game_modes.gd
## Tabla de modos, zonas de salida opuestas y despejadas, reparto de leyendas sin repetir dentro de
## un equipo, celda de reaparición dentro del gas y lejos de los rivales, y caminos de la navegación.
extends SceneTree

const SEED := 1234

var failures := 0


func _check(ok: bool, msg: String) -> void:
	if not ok:
		print("FALLO: " + msg)
		failures += 1


func _init() -> void:
	var m: Dictionary = MapBuilder.horde_map(SEED)
	var grid := MapLayout.transpose(m["grid"])
	var zones := MapLayout.transpose(m["zones"])
	_test_modes()
	var areas := _test_spawn_areas(grid, zones)
	_test_legends()
	_test_respawn(grid, zones, areas)
	_test_nav(grid, areas)
	print("test_game_modes: %s (%d fallos)" % ["OK" if failures == 0 else "FALLO", failures])
	quit(1 if failures > 0 else 0)


func _test_modes() -> void:
	_check(GameModes.ORDER == ["horda", "1v1", "2v2", "3v3", "4v4"], "orden de modos: %s" % [GameModes.ORDER])
	_check(not GameModes.is_pvp("horda") and GameModes.team_size("horda") == 0, "la horda no es por equipos")
	for n in [1, 2, 3, 4]:
		var id := "%dv%d" % [n, n]
		_check(GameModes.is_pvp(id) and GameModes.team_size(id) == n, "%s debe ser por equipos de %d" % [id, n])
		_check(String(GameModes.MODES[id].get("name", "")) != "", "%s sin nombre" % id)
	_check(not GameModes.is_pvp("inventado") and GameModes.team_size("inventado") == 0, "modo desconocido")


func _test_spawn_areas(grid: Array, zones: Array) -> Dictionary:
	var w := grid.size()
	var h := (grid[0] as PackedInt32Array).size()
	var center := Vector2(w * 0.5, h * 0.5)
	var radius := minf(w, h) * 0.5
	var areas := GameModes.spawn_areas(grid, zones, radius)
	for team in [1, 2]:
		var cells: Array = areas.get(team, [])
		_check(cells.size() >= 8, "zona de salida %d con solo %d celdas" % [team, cells.size()])
		for c: Vector2i in cells:
			_check(MapBuilder.walkable(grid[c.x][c.y]) and zones[c.x][c.y] == 0, "celda de salida %s no es campo transitable" % c)
			_check(Vector2(c).distance_to(center) <= radius - 3.0, "celda de salida %s fuera del gas inicial" % c)
			var open := true
			for dx in [-1, 0, 1]:
				for dy in [-1, 0, 1]:
					if not MapBuilder.walkable(grid[c.x + dx][c.y + dy]):
						open = false
			_check(open, "celda de salida %s sin despeje alrededor" % c)
	if areas.get(1, []).is_empty() or areas.get(2, []).is_empty():
		return areas
	var a := Vector2(areas[1][0]) - center
	var b := Vector2(areas[2][0]) - center
	_check(a.dot(b) < 0.0, "las zonas de salida no están en lados opuestos (%s, %s)" % [a, b])
	_check(Vector2(areas[1][0]).distance_to(Vector2(areas[2][0])) >= 15.0, "zonas de salida demasiado cerca")
	# Determinista.
	_check(GameModes.spawn_areas(grid, zones, radius) == areas, "spawn_areas no es determinista")
	# Por equipos el área limpia arranca al 65 % (TeamMode.PVP_ZONE_SCALE): sigue habiendo sitio para
	# cuatro por equipo, dentro de ese círculo, y más cerca que en el mapa entero.
	var small := radius * TeamMode.PVP_ZONE_SCALE
	var near := GameModes.spawn_areas(grid, zones, small)
	for team in [1, 2]:
		var cells: Array = near.get(team, [])
		_check(cells.size() >= 8, "área limpia pequeña: zona de salida %d con solo %d celdas" % [team, cells.size()])
		for c: Vector2i in cells:
			_check(Vector2(c).distance_to(center) <= small - 3.0, "área limpia pequeña: %s fuera del gas inicial" % c)
	if not near.get(1, []).is_empty() and not near.get(2, []).is_empty():
		_check(Vector2(near[1][0]).distance_to(Vector2(near[2][0])) < Vector2(areas[1][0]).distance_to(Vector2(areas[2][0])),
			"con el área pequeña las salidas deben quedar más cerca")
	return areas


func _test_legends() -> void:
	for n in [1, 2, 3, 4]:
		for player_legend in [0, 3, 6]:
			var rng := RandomNumberGenerator.new()
			rng.seed = SEED + n
			var picks := GameModes.pick_legends(player_legend, n, 7, rng)
			var t1: Array = picks.get(1, [])
			var t2: Array = picks.get(2, [])
			_check(t1.size() == n and t2.size() == n, "%dv%d: equipos de %d y %d" % [n, n, t1.size(), t2.size()])
			if t1.is_empty():
				continue
			_check(int(t1[0]) == player_legend, "%dv%d: tu leyenda debe ir la primera" % [n, n])
			for team in [t1, t2]:
				var seen := {}
				for l in team:
					_check(int(l) >= 0 and int(l) < 7, "%dv%d: leyenda %d fuera de rotación" % [n, n, l])
					_check(not seen.has(l), "%dv%d: leyenda %d repetida en un equipo" % [n, n, l])
					seen[l] = true


func _test_respawn(grid: Array, zones: Array, areas: Dictionary) -> void:
	var w := grid.size()
	var center := Vector2(w * 0.5, w * 0.5)
	var home: Array = areas.get(1, [])
	if home.is_empty():
		return
	# Gas abierto del todo: reaparece en su zona.
	var c := GameModes.respawn_cell(home, grid, zones, center, 21.0, [])
	_check(home.has(c), "con el gas abierto debe reaparecer en su zona (%s)" % c)
	# Gas cerrado lejos de su zona: reaparece dentro del área limpia y lejos del rival.
	var far_center := Vector2(areas[2][0])
	var foe := Vector2i(far_center) + Vector2i(1, 0)
	var c2 := GameModes.respawn_cell(home, grid, zones, far_center, 8.0, [foe])
	_check(Vector2(c2).distance_to(far_center) <= 8.0 - 1.0, "reaparece fuera del área limpia (%s)" % c2)
	_check(MapBuilder.walkable(grid[c2.x][c2.y]), "reaparece en celda bloqueada (%s)" % c2)
	_check(Vector2(c2).distance_to(Vector2(foe)) >= 4.0, "reaparece pegado al rival (%s)" % c2)


func _test_nav(grid: Array, areas: Dictionary) -> void:
	var nav := NavGrid.new()
	nav.build(grid)
	if areas.get(1, []).is_empty():
		return
	var from: Vector2i = areas[1][0]
	var to: Vector2i = areas[2][0]
	var path := nav.path(from, to)
	_check(path.size() > 2, "no hay camino entre las zonas de salida")
	if path.is_empty():
		return
	_check(path[0] == from and path[path.size() - 1] == to, "el camino no empieza y acaba donde debe")
	for i in path.size():
		var c: Vector2i = path[i]
		_check(MapBuilder.walkable(grid[c.x][c.y]), "el camino pisa una celda bloqueada %s" % c)
		if i > 0:
			var d: Vector2i = c - path[i - 1]
			_check(absi(d.x) <= 1 and absi(d.y) <= 1, "salto en el camino %s -> %s" % [path[i - 1], c])
			if d.x != 0 and d.y != 0:
				var p: Vector2i = path[i - 1]
				_check(MapBuilder.walkable(grid[p.x + d.x][p.y]) and MapBuilder.walkable(grid[p.x][p.y + d.y]),
					"el camino corta una esquina en %s" % c)
	# Destino bloqueado: lleva a la celda transitable más cercana.
	var blocked := Vector2i(-1, -1)
	for x in grid.size():
		for y in (grid[0] as PackedInt32Array).size():
			if blocked.x < 0 and not MapBuilder.walkable(grid[x][y]) and x > 3 and y > 3:
				blocked = Vector2i(x, y)
	var p2 := nav.path(from, blocked)
	_check(not p2.is_empty(), "con destino bloqueado debe acercarse igualmente")
