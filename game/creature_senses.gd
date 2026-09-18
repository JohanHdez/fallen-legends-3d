## Reglas puras de los sentidos de las criaturas de la Horda (petición del usuario, 2026-09-17: "si me
## agacho ellos no me ven, pero si pasan cerca o sobre mí sí me ven; con alertar a uno, los demás saben
## mi ubicación"). Quién las aplica es Horde, criatura a criatura y escalonado cada CHECK_EVERY.
class_name CreatureSenses
extends RefCounted

const SIGHT_DAY := 12.0          # metros a los que te ven de día, sin nada en medio
const SIGHT_NIGHT := 8.0         # y de noche cerrada
const HIDDEN_NEAR := 1.5         # escondido: solo si pasan por encima
const HIDDEN_CHASE := 4.0        # escondido, la que ya te persigue: agacharte 2 m más allá no basta
const ALERT_RADIUS := 30.0       # el grito de la que te descubre (decisión del usuario)
const LOSE_AFTER := 3.0          # segundos sin verte hasta ir a buscarte donde te vio
const SEARCH_TIME := 8.0         # rebuscando antes de volver a deambular
## Deambular no puede ser eterno: la criatura que lleva esto sin ver a nadie se lanza hacia la leyenda
## más cercana. Sin esto, una sola criatura perdida en una esquina dejaba la oleada sin acabar nunca
## (lo cazó tests/horde_probe.gd) y la horda no apretaba.
const HUNT_AFTER := 20.0
const WANDER_CELLS := 10         # hasta dónde elige su siguiente meta al deambular
const CHECK_EVERY := 0.25        # cada cuánto mira (escalonado entre criaturas)


## Hasta dónde ve según la noche (0 = mediodía, 1 = noche cerrada).
static func sight_range(night: float) -> float:
	return lerpf(SIGHT_DAY, SIGHT_NIGHT, clampf(night, 0.0, 1.0))


## ¿Ve a una leyenda a `dist` metros? Escondida (agachada en hierba alta o invisible) solo pegado, y
## algo más lejos si ya la perseguía; a la vista, a su alcance de vista y sin nada que tape.
static func can_see(dist: float, hidden: bool, chasing: bool, night: float, los: bool) -> bool:
	if hidden:
		return dist <= (HIDDEN_CHASE if chasing else HIDDEN_NEAR)
	return los and dist <= sight_range(night)


## ¿Nada tapa entre dos celdas? Tapan muros y macizos de roca (los peñascos pasan a MOUNTAIN); el agua
## es plana y se ve a través. Bresenham sobre la rejilla transpuesta (grid[x][y]), sin los extremos.
static func los_clear(grid: Array, a: Vector2i, b: Vector2i) -> bool:
	var x := a.x
	var y := a.y
	var dx := absi(b.x - a.x)
	var dy := -absi(b.y - a.y)
	var sx := 1 if a.x < b.x else -1
	var sy := 1 if a.y < b.y else -1
	var err := dx + dy
	while not (x == b.x and y == b.y):
		var e2 := 2 * err
		if e2 >= dy:
			err += dy
			x += sx
		if e2 <= dx:
			err += dx
			y += sy
		if x == b.x and y == b.y:
			break
		if x < 0 or x >= grid.size() or y < 0 or y >= (grid[x] as PackedInt32Array).size():
			return false
		var v: int = grid[x][y]
		if v == MapBuilder.WALL or v == MapBuilder.MOUNTAIN:
			return false
	return true


## ¿Oye el grito? En el plano, a ALERT_RADIUS o menos.
static func hears(shouter: Vector3, listener: Vector3) -> bool:
	return Vector2(listener.x - shouter.x, listener.z - shouter.z).length() <= ALERT_RADIUS


## ¿Lleva deambulando lo bastante como para ir a buscar a alguien?
static func hunts(wander_t: float) -> bool:
	return wander_t >= HUNT_AFTER
