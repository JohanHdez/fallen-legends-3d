## Prueba de lógica pura de MapLayout (world/map_layout.gd):
##   godot --headless --path . -s tests/test_map_layout.gd
## Transposición de la rejilla, huella de una malla en planta, encaje de una roca en su celda y
## elección de celdas para los peñascos sin romper la conectividad del mapa.
extends SceneTree

const SEED := 1234

var failures := 0


func _check(ok: bool, msg: String) -> void:
	if not ok:
		print("FALLO: " + msg)
		failures += 1


func _init() -> void:
	_test_transpose()
	_test_footprint()
	_test_fit()
	_test_fit_in_cell()
	_test_cover_cells()
	print("test_map_layout: %s (%d fallos)" % ["OK" if failures == 0 else "FALLO", failures])
	quit(1 if failures > 0 else 0)


func _test_transpose() -> void:
	var m: Dictionary = MapBuilder.horde_map(SEED)
	var rows: Array = m["grid"]
	var t := MapLayout.transpose(rows)
	var ok := true
	for y in rows.size():
		for x in (rows[y] as PackedInt32Array).size():
			if t[x][y] != rows[y][x]:
				ok = false
	_check(ok, "transpose: t[x][y] debe ser rows[y][x]")
	_check(MapLayout.transpose(t) == rows, "transpose dos veces debe devolver la rejilla original")
	# La copia es independiente: escribir en ella no toca el original.
	var before: int = rows[3][2]
	t[2][3] = 99
	_check(rows[3][2] == before, "transpose debe devolver una copia, no compartir filas")
	# Las celdas que devuelve MapBuilder (x, y) caen en suelo leídas a la manera de main.gd.
	var tz := MapLayout.transpose(m["zones"])
	var bad := 0
	for c: Vector2i in MapBuilder.edge_cells(rows):
		if not MapBuilder.walkable(MapLayout.transpose(rows)[c.x][c.y]):
			bad += 1
	_check(bad == 0, "edge_cells leídas tras transponer: %d celdas bloqueadas" % bad)
	for c: Vector2i in MapBuilder.cemetery_graves(rows, m["zones"], SEED):
		_check(tz[c.x][c.y] == 2, "tumba %s fuera del cementerio tras transponer" % c)


func _test_footprint() -> void:
	# Un cubo de 2 m apoyado en el suelo y una punta alta: por debajo de 1 m la punta no cuenta.
	var pts := PackedVector3Array()
	for x in [-1.0, 1.0]:
		for y in [0.0, 0.8]:
			for z in [-1.0, 1.0]:
				pts.append(Vector3(x, y, z))
	pts.append(Vector3(9.0, 3.0, 0.0))
	var low := MapLayout.footprint(pts, 1.0)
	var maxd := 0.0
	for p in low:
		maxd = maxf(maxd, p.length())
	_check(absf(maxd - sqrt(2.0)) < 0.01, "footprint bajo 1 m debe ignorar la punta alta (radio %.2f)" % maxd)
	var all := MapLayout.footprint(pts)
	var reach := 0.0
	for p in all:
		reach = maxf(reach, p.x)
	_check(absf(reach - 9.0) < 0.01, "footprint sin límite de altura debe incluir la punta")


func _test_fit() -> void:
	# Huella descentrada (como las rocas de Quaternius): un rectángulo de 3,2 × 3 con el pivote
	# desplazado. Girada lo que sea, tiene que caber justa en el radio pedido alrededor del origen.
	var hull := PackedVector2Array([Vector2(-1.7, -1.1), Vector2(1.5, -1.1), Vector2(1.5, 1.9), Vector2(-1.7, 1.9)])
	for yaw in [0.0, 0.7, 2.1, 4.0]:
		var fit := MapLayout.fit_footprint(hull, yaw, 1.2)
		var s: float = fit["scale"]
		var off: Vector2 = fit["offset"]
		var xf := MapLayout.fit_transform(fit, yaw, Vector3(10.0, 0.0, -4.0), 1.25)
		var far := 0.0
		for p in hull:
			var w := xf * Vector3(p.x, 0.0, p.y)
			far = maxf(far, Vector2(w.x - 10.0, w.z + 4.0).length())
		_check(far <= 1.2 + 0.001, "fit yaw %.1f: la huella se sale del radio (%.3f)" % [yaw, far])
		_check(far >= 1.2 * 0.8, "fit yaw %.1f: la huella queda demasiado pequeña (%.3f)" % [yaw, far])
		_check(s > 0.0 and s < 1.0, "fit yaw %.1f: escala %.3f fuera de rango" % [yaw, s])
		_check(absf(xf.basis.get_scale().y - s * 1.25) < 0.001, "fit_transform debe estirar en vertical")
		_check(off.length() < 1.0, "fit yaw %.1f: desplazamiento absurdo %s" % [yaw, off])


func _test_fit_in_cell() -> void:
	var hull := PackedVector2Array([Vector2(-1.7, -1.1), Vector2(1.5, -1.1), Vector2(1.5, 1.9), Vector2(-1.7, 1.9)])
	const H := 1.5        # media celda
	const TOL := 0.1      # lo que puede asomar hacia el suelo
	const OVER := 1.0     # lo que puede meterse en una vecina bloqueada
	# Pared: izquierda, arriba y abajo bloqueadas; derecha y la diagonal (+1, +1) son suelo.
	# `blocked` va por [dx + 1][dz + 1].
	var blocked := [[true, true, true], [true, true, true], [true, false, false]]
	for yaw in [0.0, 0.5, 1.3, 2.6, 3.9, 5.5]:
		var fit := MapLayout.fit_in_cell(hull, yaw, blocked, H, TOL, OVER, 1.15)
		var s: float = fit["scale"]
		var xf := MapLayout.fit_transform(fit, yaw, Vector3.ZERO, 1.0)
		var bad := ""
		for p in hull:
			var w := xf * Vector3(p.x, 0.0, p.y)
			if w.x > H + TOL + 0.001:
				bad = "asoma al suelo de la derecha (x=%.2f)" % w.x
			elif w.x < -(H + OVER) - 0.001 or absf(w.z) > H + OVER + 0.001:
				bad = "se mete demasiado en una vecina bloqueada (%.2f, %.2f)" % [w.x, w.z]
			elif w.x > H + TOL + 0.001 and w.z > H + TOL + 0.001:
				bad = "invade la diagonal de suelo (%.2f, %.2f)" % [w.x, w.z]
		_check(bad == "", "fit_in_cell yaw %.1f: %s" % [yaw, bad])
		_check(s <= 1.15 + 0.001, "fit_in_cell yaw %.1f: pasa de la escala máxima (%.2f)" % [yaw, s])
		_check(s >= 0.6, "fit_in_cell yaw %.1f: roca demasiado pequeña para una pared (%.2f)" % [yaw, s])
	# Diagonal de suelo con las dos ortogonales bloqueadas: la esquina no puede entrar en ella.
	var corner := [[true, true, true], [true, true, true], [true, true, false]]
	for yaw in [0.0, 0.8, 2.4]:
		var fit := MapLayout.fit_in_cell(hull, yaw, corner, H, TOL, OVER, 1.15)
		var xf := MapLayout.fit_transform(fit, yaw, Vector3.ZERO, 1.0)
		for p in hull:
			var w := xf * Vector3(p.x, 0.0, p.y)
			_check(not (w.x > H + TOL + 0.001 and w.z > H + TOL + 0.001),
				"fit_in_cell esquina yaw %.1f: invade la diagonal (%.2f, %.2f)" % [yaw, w.x, w.z])
	# Pilar suelto (todo suelo alrededor): cabe en su celda con la tolerancia.
	var alone := [[false, false, false], [false, true, false], [false, false, false]]
	var fit2 := MapLayout.fit_in_cell(hull, 0.9, alone, H, TOL, OVER, 1.15)
	var xf2 := MapLayout.fit_transform(fit2, 0.9, Vector3.ZERO, 1.0)
	for p in hull:
		var w := xf2 * Vector3(p.x, 0.0, p.y)
		_check(absf(w.x) <= H + TOL + 0.001 and absf(w.z) <= H + TOL + 0.001,
			"fit_in_cell pilar: se sale de su celda (%.2f, %.2f)" % [w.x, w.z])


func _test_cover_cells() -> void:
	var m: Dictionary = MapBuilder.horde_map(SEED)
	var grid := MapLayout.transpose(m["grid"])
	var zones := MapLayout.transpose(m["zones"])
	var w := grid.size()
	var h := (grid[0] as PackedInt32Array).size()
	var home := Vector2i(21, 21)
	var avoid: Array = []
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	var cells := MapLayout.pick_cover_cells(grid, zones, avoid, home, 50, 2, rng)
	_check(cells.size() >= 30, "pick_cover_cells: solo %d celdas" % cells.size())
	for i in cells.size():
		var c: Vector2i = cells[i]
		_check(Vector2(c - home).length() >= 3.0, "peñasco %s demasiado cerca de la aparición" % c)
		for dx in [-1, 0, 1]:
			for dy in [-1, 0, 1]:
				var n: Vector2i = c + Vector2i(dx, dy)
				_check(MapBuilder.walkable(grid[n.x][n.y]) and zones[n.x][n.y] == 0,
					"peñasco %s sin despeje alrededor (%s)" % [c, n])
		for j in range(i + 1, cells.size()):
			var o: Vector2i = cells[j]
			_check(maxi(absi(c.x - o.x), absi(c.y - o.y)) >= 2, "peñascos pegados %s %s" % [c, o])
	_check(grid == MapLayout.transpose(m["grid"]), "pick_cover_cells no debe modificar la rejilla")
	# Determinista con la misma semilla.
	var rng2 := RandomNumberGenerator.new()
	rng2.seed = SEED
	_check(MapLayout.pick_cover_cells(grid, zones, avoid, home, 50, 2, rng2) == cells, "pick_cover_cells no es determinista")
	# Con los peñascos como celdas bloqueadas el mapa sigue conexo y sin callejones ni bolsas.
	for c: Vector2i in cells:
		grid[c.x][c.y] = MapBuilder.MOUNTAIN
	_check(MapBuilder.all_connected(grid), "con peñascos el mapa deja de ser conexo")
	_check(MapBuilder.dead_end_cells(grid).is_empty(), "con peñascos aparecen callejones: %s" % [MapBuilder.dead_end_cells(grid)])
	_check(MapBuilder.trapped_cells(grid).is_empty(), "con peñascos aparecen bolsas: %s" % [MapBuilder.trapped_cells(grid)])
