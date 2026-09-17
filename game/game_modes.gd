## Modos de juego y su montaje: qué modos hay, dónde sale cada equipo, qué leyendas llevan los
## bots y dónde reaparece quien cae. Lógica pura sobre la rejilla `[x][y]` de main.gd
## (tests/test_game_modes.gd). Decisiones y motivos: docs/superpowers/specs/2026-09-16-modos-por-equipos-design.md
class_name GameModes
extends RefCounted

const ORDER := ["horda", "1v1", "2v2", "3v3", "4v4"]
const MODES := {
	"horda": {"name": "Horda", "team_size": 0,
		"desc": "Oleadas de criaturas que no acaban. Aguanta, escóndete en la hierba y sube la racha."},
	"1v1": {"name": "Duelo 1 contra 1", "team_size": 1,
		"desc": "Tu leyenda contra otra. Gana quien llegue antes a 15 bajas."},
	"2v2": {"name": "2 contra 2", "team_size": 2,
		"desc": "Tú y un compañero contra dos rivales. El gas va cerrando el mapa."},
	"3v3": {"name": "3 contra 3", "team_size": 3,
		"desc": "Tres por bando. Juntad habilidades: la trampa del Tormentero y el ancla se entienden."},
	"4v4": {"name": "4 contra 4", "team_size": 4,
		"desc": "Batalla completa: cuatro leyendas por equipo, 15 bajas o 15 minutos."},
}
const AREA_RADIUS := 4.5        # celdas alrededor del punto de salida de cada equipo
const AREA_REACH := 0.55        # a qué fracción del radio del gas queda cada punto de salida
const GAS_MARGIN := 3.0         # celdas de holgura con el borde del gas inicial


static func is_pvp(mode: String) -> bool:
	return team_size(mode) > 0


static func team_size(mode: String) -> int:
	return int(MODES.get(mode, {}).get("team_size", 0))


## Celda de campo con sus 8 vecinas transitables.
static func _open_field(grid: Array, zones: Array, x: int, y: int) -> bool:
	var w := grid.size()
	var h := (grid[0] as PackedInt32Array).size()
	if x < 1 or y < 1 or x >= w - 1 or y >= h - 1 or zones[x][y] != 0:
		return false
	for dx in [-1, 0, 1]:
		for dy in [-1, 0, 1]:
			if not MapBuilder.walkable(grid[x + dx][y + dy]):
				return false
	return true


## Las dos zonas de salida {1: celdas, 2: celdas}, opuestas respecto al centro y dentro del círculo
## inicial del gas (`radius` en celdas). Se prueba en 8 direcciones y se queda la que da más sitio
## al equipo que menos tiene. Cada lista va ordenada por cercanía a su punto de salida.
static func spawn_areas(grid: Array, zones: Array, radius: float) -> Dictionary:
	var w := grid.size()
	var h := (grid[0] as PackedInt32Array).size()
	var center := Vector2(w * 0.5, h * 0.5)
	var best := {}
	var best_score := -1
	for k in 8:
		var dir := Vector2.from_angle(TAU * k / 8.0)
		var anchors := {1: center + dir * radius * AREA_REACH, 2: center - dir * radius * AREA_REACH}
		var found := {1: [], 2: []}
		for team in [1, 2]:
			var anchor: Vector2 = anchors[team]
			var cells: Array = []
			for x in range(int(anchor.x - AREA_RADIUS) - 1, int(anchor.x + AREA_RADIUS) + 2):
				for y in range(int(anchor.y - AREA_RADIUS) - 1, int(anchor.y + AREA_RADIUS) + 2):
					if x < 0 or y < 0 or x >= w or y >= h:
						continue
					var c := Vector2(x, y)
					if c.distance_to(anchor) > AREA_RADIUS or c.distance_to(center) > radius - GAS_MARGIN:
						continue
					if _open_field(grid, zones, x, y):
						cells.append(Vector2i(x, y))
			cells.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
				var da := Vector2(a).distance_to(anchor)
				var db := Vector2(b).distance_to(anchor)
				return da < db if not is_equal_approx(da, db) else (a.x < b.x or (a.x == b.x and a.y < b.y)))
			found[team] = cells
		var score := mini(found[1].size(), found[2].size())
		if score > best_score:
			best_score = score
			best = found
	return best


## Leyendas de cada equipo {1: [...], 2: [...]}: la tuya la primera del equipo 1, y ninguna repetida
## dentro de un mismo equipo (entre equipos sí, como en el juego). Solo las `playable` en rotación.
static func pick_legends(player_legend: int, size: int, playable: int, rng: RandomNumberGenerator) -> Dictionary:
	var pool1: Array = []
	var pool2: Array = []
	for i in playable:
		if i != player_legend:
			pool1.append(i)
		pool2.append(i)
	_shuffle(pool1, rng)
	_shuffle(pool2, rng)
	var t1: Array = [player_legend]
	for i in maxi(size - 1, 0):
		t1.append(pool1[i % pool1.size()])
	# En el duelo, mejor contra OTRA leyenda: un espejo no enseña nada del emparejamiento.
	if size == 1 and pool2.size() > 1 and int(pool2[0]) == player_legend:
		pool2.push_back(pool2.pop_front())
	var t2: Array = []
	for i in size:
		t2.append(pool2[i % pool2.size()])
	return {1: t1, 2: t2}


static func _shuffle(a: Array, rng: RandomNumberGenerator) -> void:
	for i in range(a.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = a[i]
		a[i] = a[j]
		a[j] = tmp


## Dónde reaparece una leyenda: en su zona de salida si el área limpia la cubre; si el gas ya se la
## ha comido, en la celda de campo despejada DENTRO del área limpia que más lejos quede de los
## rivales. `zone_center` y `zone_radius` van en celdas.
static func respawn_cell(home: Array, grid: Array, zones: Array, zone_center: Vector2, zone_radius: float,
		foes: Array, margin := 1.5) -> Vector2i:
	var inside: Array = []
	for c: Vector2i in home:
		if Vector2(c).distance_to(zone_center) <= zone_radius - margin:
			inside.append(c)
	if inside.is_empty():
		var w := grid.size()
		var h := (grid[0] as PackedInt32Array).size()
		for x in range(maxi(int(zone_center.x - zone_radius), 1), mini(int(zone_center.x + zone_radius) + 1, w - 1)):
			for y in range(maxi(int(zone_center.y - zone_radius), 1), mini(int(zone_center.y + zone_radius) + 1, h - 1)):
				if Vector2(x, y).distance_to(zone_center) <= zone_radius - margin and _open_field(grid, zones, x, y):
					inside.append(Vector2i(x, y))
	if inside.is_empty():
		return home[0] if not home.is_empty() else Vector2i(int(zone_center.x), int(zone_center.y))
	if foes.is_empty():
		return inside[0]
	var best: Vector2i = inside[0]
	var best_d := -1.0
	for c: Vector2i in inside:
		var near := INF
		for foe: Vector2i in foes:
			near = minf(near, Vector2(c).distance_to(Vector2(foe)))
		if near > best_d + 0.001:
			best_d = near
			best = c
	return best
