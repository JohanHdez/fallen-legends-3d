## Geometría del mapa 3D que no depende de la escena: lógica pura, determinista y con pruebas
## (tests/test_map_layout.gd).
##  - Transposición: MapBuilder guarda `grid[y][x]`; main.gd lee `grid[x][y]`. Se transpone UNA vez
##    al cargar el mapa y las celdas que devuelve MapBuilder (x, y) valen tal cual.
##  - Encaje de rocas: las rocas de Quaternius miden ~3,2 m y tienen el pivote descentrado; para que
##    una roca ocupe SU celda y nada más, se escala y se centra por su huella real en planta.
##  - Peñascos de cobertura: celdas despejadas y separadas, que bloqueadas no rompen el mapa.
class_name MapLayout
extends RefCounted


## Copia transpuesta de una rejilla: `out[x][y] = rows[y][x]`. Filas como PackedInt32Array, igual
## que las de MapBuilder. Transponer dos veces devuelve la original.
static func transpose(rows: Array) -> Array:
	var out: Array = []
	if rows.is_empty():
		return out
	var h := rows.size()
	var w := (rows[0] as PackedInt32Array).size()
	for x in w:
		var col := PackedInt32Array()
		col.resize(h)
		for y in h:
			col[y] = rows[y][x]
		out.append(col)
	return out


## Envolvente convexa en planta (XZ) de los puntos que quedan por debajo de `max_y`. Con la altura
## de la cintura da la huella con la que choca un personaje, sin las copas ni los salientes altos.
static func footprint(points: PackedVector3Array, max_y := INF) -> PackedVector2Array:
	var flat := PackedVector2Array()
	for p in points:
		if p.y <= max_y:
			flat.append(Vector2(p.x, p.z))
	if flat.size() < 3:
		return flat
	return Geometry2D.convex_hull(flat)


## Escala y desplazamiento para que la huella `hull` (en el espacio del modelo), girada `yaw`
## alrededor de Y, quepa JUSTA en un círculo de radio `radius` centrado en el origen.
## Devuelve {"scale": float, "offset": Vector2 (en metros, planta XZ)}.
static func fit_footprint(hull: PackedVector2Array, yaw: float, radius: float) -> Dictionary:
	if hull.is_empty():
		return {"scale": 1.0, "offset": Vector2.ZERO}
	var rot := Basis(Vector3.UP, yaw)
	var turned := PackedVector2Array()
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for p in hull:
		var v := rot * Vector3(p.x, 0.0, p.y)
		var q := Vector2(v.x, v.z)
		turned.append(q)
		lo = lo.min(q)
		hi = hi.max(q)
	var center := (lo + hi) * 0.5
	var far := 0.0
	for q in turned:
		far = maxf(far, q.distance_to(center))
	var s := radius / maxf(far, 0.001)
	return {"scale": s, "offset": -center * s}


## Encaja una roca en SU celda de muro. Hacia las vecinas bloqueadas puede solaparse `over` metros
## (así una hilera de rocas se ve como una pared continua y no como pedruscos con huecos donde la
## caja de colisión sería una pared invisible); hacia el suelo solo asoma `tol`; y nunca entra en
## una diagonal de suelo. `blocked[dx + 1][dz + 1]` dice qué vecinas son muro (fuera del mapa
## cuenta como muro). La escala no pasa de `max_scale`. Devuelve {"scale", "offset"} respecto al
## centro de la celda, igual que fit_footprint.
static func fit_in_cell(hull: PackedVector2Array, yaw: float, blocked: Array, half: float, tol: float,
		over: float, max_scale: float) -> Dictionary:
	if hull.is_empty():
		return {"scale": 1.0, "offset": Vector2.ZERO}
	var rot := Basis(Vector3.UP, yaw)
	var turned := PackedVector2Array()
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for p in hull:
		var v := rot * Vector3(p.x, 0.0, p.y)
		var q := Vector2(v.x, v.z)
		turned.append(q)
		lo = lo.min(q)
		hi = hi.max(q)
	var size := (hi - lo).max(Vector2(0.001, 0.001))
	var center := (lo + hi) * 0.5
	var xmin := -(half + (over if blocked[0][1] else tol))
	var xmax := half + (over if blocked[2][1] else tol)
	var zmin := -(half + (over if blocked[1][0] else tol))
	var zmax := half + (over if blocked[1][2] else tol)
	var mid := Vector2((xmin + xmax) * 0.5, (zmin + zmax) * 0.5)
	var s := minf(max_scale, minf((xmax - xmin) / size.x, (zmax - zmin) / size.y))
	var off := mid - center * s
	for attempt in 40:
		off = mid - center * s
		var clear := true
		for d in [Vector2i(-1, -1), Vector2i(-1, 1), Vector2i(1, -1), Vector2i(1, 1)]:
			if blocked[d.x + 1][d.y + 1]:
				continue
			for q in turned:
				var w := q * s + off
				if w.x * d.x > half + tol and w.y * d.y > half + tol:
					clear = false
					break
			if not clear:
				break
		if clear:
			break
		s *= 0.95
	return {"scale": s, "offset": off}


## Transformada de una roca encajada: giro, escala (estirada `y_stretch` en vertical) y el centro de
## su huella sobre `at`.
static func fit_transform(fit: Dictionary, yaw: float, at: Vector3, y_stretch := 1.0) -> Transform3D:
	var s: float = fit["scale"]
	var off: Vector2 = fit["offset"]
	var basis := Basis(Vector3.UP, yaw).scaled(Vector3(s, s * y_stretch, s))
	return Transform3D(basis, at + Vector3(off.x, 0.0, off.y))


## Celdas para los peñascos de cobertura, en la convención de main.gd (`grid[x][y]`):
##  - campo (zona 0) con las 8 vecinas también de campo transitable;
##  - fuera de `avoid[x][y]` (hierba alta) si se da;
##  - a 3 celdas o más de `home` (donde aparece el jugador: una vez le tocó un peñasco encima);
##  - separadas `gap` celdas (Chebyshev) entre sí;
##  - y bloquearla no deja ninguna celda de alrededor sin sus dos vías de huida ni en callejón (los
##    mismos criterios con los que MapBuilder valida el mapa de la Horda).
## Orden sorteado con `rng`: determinista por semilla. No modifica `grid`.
## Altura de la hierba de una celda (petición del usuario, 2026-09-17: "zonas con pasto a la mitad de
## los personajes, otras con pasto alto"): 2 = alta (donde te escondes agachado), 1 = media (por la
## cintura, solo vista) y 0 = matas bajas. La alta manda sobre la media.
static func grass_tier(tall: bool, mid: bool) -> int:
	if tall:
		return 2
	return 1 if mid else 0


static func pick_cover_cells(grid: Array, zones: Array, avoid: Array, home: Vector2i, count: int,
		gap: int, rng: RandomNumberGenerator) -> Array[Vector2i]:
	var w := grid.size()
	var h := (grid[0] as PackedInt32Array).size() if w > 0 else 0
	var candidates: Array[Vector2i] = []
	for x in range(2, w - 2):
		for y in range(2, h - 2):
			if Vector2(x - home.x, y - home.y).length() < 3.0:
				continue
			var clear := true
			for dx in [-1, 0, 1]:
				for dy in [-1, 0, 1]:
					var nx: int = x + dx
					var ny: int = y + dy
					if not MapBuilder.walkable(grid[nx][ny]) or zones[nx][ny] != 0:
						clear = false
					elif not avoid.is_empty() and avoid[nx][ny]:
						clear = false
			if clear:
				candidates.append(Vector2i(x, y))
	for i in range(candidates.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp := candidates[i]
		candidates[i] = candidates[j]
		candidates[j] = tmp
	var work := grid.duplicate(true)
	var out: Array[Vector2i] = []
	for c in candidates:
		if out.size() >= count:
			break
		var far := true
		for o in out:
			if maxi(absi(c.x - o.x), absi(c.y - o.y)) < gap:
				far = false
				break
		if not far:
			continue
		work[c.x][c.y] = MapBuilder.MOUNTAIN
		if _keeps_escapes(work, c):
			out.append(c)
		else:
			work[c.x][c.y] = MapBuilder.FLOOR
	return out


## Tras bloquear `c`, ¿las celdas transitables de su cruz (hasta ESCAPE_LEN) conservan dos vías de
## huida y dos vecinas ortogonales? Solo esas pueden haber cambiado.
## MapBuilder lee `[y][x]`: sobre una rejilla `[x][y]` se le pasan las coordenadas al revés.
static func _keeps_escapes(work: Array, c: Vector2i) -> bool:
	var w := work.size()
	var h := (work[0] as PackedInt32Array).size()
	for dx in range(-MapBuilder.ESCAPE_LEN, MapBuilder.ESCAPE_LEN + 1):
		for dy in range(-MapBuilder.ESCAPE_LEN, MapBuilder.ESCAPE_LEN + 1):
			if dx != 0 and dy != 0:
				continue
			var x := c.x + dx
			var y := c.y + dy
			if x < 0 or y < 0 or x >= w or y >= h or not MapBuilder.walkable(work[x][y]):
				continue
			if MapBuilder.escape_routes(work, Vector2i(y, x)) < 2:
				return false
			var n := 0
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				if MapBuilder.walkable(MapBuilder.get_cell(work, y + d.y, x + d.x)):
					n += 1
			if n < 2:
				return false
	return true
