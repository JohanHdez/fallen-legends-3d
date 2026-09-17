## Minimapa arriba a la derecha (petición del usuario, 2026-09-17): el terreno alrededor de lo que sigue
## la cámara, girado con ella (lo que tienes delante queda arriba). Tú en el centro con una flecha
## blanca, tus compañeros en azul (naranja si están derribados), el borde del gas en violeta y, en rojo,
## los enemigos que ve tu equipo: a menos de SIGHT de ti o de un compañero y sin esconderse; los marcados
## por romper un señuelo y quien acaba de atacar, estén donde estén. Lo que cae fuera del cuadro se pega
## al borde. En la Horda, las criaturas y el jefe igual. Se redibuja cada REFRESH s, no en cada fotograma.
class_name Minimap
extends Control

const SIZE := 190.0                    # px de lado
const MARGIN := 12.0                   # px hasta el borde de la pantalla
const VIEW := 34.0                     # metros del centro al borde del cuadro
const SIGHT := BotBrain.SEARCH_RANGE   # lo que ve una leyenda: lo mismo que un bot (23 m)
const REFRESH := 0.05                  # 20 redibujos por segundo
const COL_BG := Color(0.04, 0.05, 0.08, 0.72)
const COL_FLOOR := Color(0.33, 0.40, 0.29)
const COL_GRASS := Color(0.22, 0.31, 0.18)
const COL_BLOCK := Color(0.11, 0.12, 0.11)
const COL_WATER := Color(0.17, 0.26, 0.36)
const COL_ME := Color(1.0, 1.0, 1.0)
const COL_ALLY := Color(0.35, 0.65, 1.0)
const COL_DOWN := Color(1.0, 0.55, 0.25)
const COL_ENEMY := Color(1.0, 0.22, 0.2)
const COL_ZONE := Color(0.78, 0.5, 1.0, 0.95)
const COL_EDGE := Color(1, 1, 1, 0.35)

var main: Main
var seen_ids := {}        # id del nodo de cada enemigo que salió en rojo en el último redibujo (sondas)
var allies_shown := 0     # compañeros dibujados en el último redibujo (sondas)
var draws := 0            # redibujos hechos (sondas)
var _tex: ImageTexture
var _t := 0.0


## Esquina superior derecha. Tiene que estar ya en el árbol (si no, el ancla deja el nodo en 0×0).
func setup(p_main: Main) -> void:
	main = p_main
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST   # una celda, un bloque nítido
	set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	offset_left = -MARGIN - SIZE
	offset_right = -MARGIN
	offset_top = MARGIN
	offset_bottom = MARGIN + SIZE
	_tex = ImageTexture.create_from_image(_terrain())


## Hasta dónde baja el mapa: lo que va en la misma esquina se pone debajo.
static func bottom() -> float:
	return MARGIN + SIZE


## Punto del mundo relativo al centro (dx, dz) → píxeles desde el centro del mapa, con la cámara en
## `yaw` mirando hacia arriba. La cámara mira a -basis.z = (-sin yaw, -cos yaw) y su derecha es
## (cos yaw, -sin yaw): es la rotación de Transform2D por `yaw`, la misma que usa draw_set_transform.
static func to_map(dx: float, dz: float, yaw: float, ppm: float) -> Vector2:
	var c := cos(yaw)
	var s := sin(yaw)
	return Vector2(dx * c - dz * s, dx * s + dz * c) * ppm


## ¿Sale en rojo? Marcado, siempre; escondido (hierba o invisible), nunca; si acaba de atacar, esté
## donde esté; si no, a menos de SIGHT de alguien de tu equipo.
static func enemy_seen(marked: bool, hidden: bool, spotted: bool, team_dist: float) -> bool:
	if marked:
		return true
	if hidden:
		return false
	return spotted or team_dist <= SIGHT


## Pega al borde del cuadro (lado 2·half) lo que cae fuera, en su misma dirección.
static func clamp_edge(p: Vector2, half: float) -> Vector2:
	var m := maxf(absf(p.x), absf(p.y))
	return p if m <= half else p * (half / m)


## Una imagen de mw×mh con un píxel por celda: suelo, hierba alta, agua y lo que bloquea.
func _terrain() -> Image:
	var img := Image.create(maxi(main.mw, 1), maxi(main.mh, 1), false, Image.FORMAT_RGB8)
	for x in main.mw:
		for y in main.mh:
			var cell: int = main.grid[x][y]
			var col := COL_FLOOR
			if cell == MapBuilder.WATER:
				col = COL_WATER
			elif not MapBuilder.walkable(cell):
				col = COL_BLOCK
			elif not main.tall_grass.is_empty() and main.tall_grass[x][y]:
				col = COL_GRASS
			img.set_pixel(x, y, col)
	return img


func _process(delta: float) -> void:
	_t -= delta
	if _t <= 0.0:
		_t = REFRESH
		queue_redraw()


func _draw() -> void:
	if main == null or main.pf == null:
		return
	draws += 1
	var half := SIZE * 0.5
	var c := Vector2(half, half)
	var ppm := half / VIEW
	var yaw := main._yaw
	var at := main.pivot.global_position     # lo que sigue la cámara (un compañero si has caído)
	var me: Fighter = main.pf
	draw_rect(Rect2(Vector2.ZERO, size), COL_BG)
	# Terreno: la textura en unidades de celda; el píxel u cubre del mundo (u - mw/2 - 0,5)·CELL.
	draw_set_transform(c, yaw, Vector2.ONE * ppm * Main.CELL)
	draw_texture(_tex, Vector2(-at.x / Main.CELL - main.mw * 0.5 - 0.5, -at.z / Main.CELL - main.mh * 0.5 - 0.5))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if main.zone_active():
		var zc := main._zone_c
		draw_arc(c + to_map(zc.x - at.x, zc.z - at.z, yaw, ppm), main._zone_r * ppm, 0.0, TAU, 64, COL_ZONE, 2.0, true)

	seen_ids.clear()
	for z in main.zombies:
		if int(z.get("team", 0)) != me.team and float(z["dead_t"]) < 0.0:
			_enemy(z, false, false, false, c, at, yaw, ppm, 3.5)
	for al in main.combat.allies:
		if int(al.get("team", -1)) != me.team and float(al["hp"]) > 0.0:
			_enemy(al, false, bool(al.get("hidden", false)), false, c, at, yaw, ppm, 3.5)
	for f: Fighter in main.combat.fighters:
		if f.team != me.team and not f.dead():
			_enemy(f.rec, f.marked_for(me.team), main.combat.is_hidden(f), f.spotted_t > 0.0, c, at, yaw, ppm,
				5.0 if f.alive() else 3.5)

	allies_shown = 0
	for f: Fighter in main.combat.fighters:
		if f.team != me.team or f == me or f.dead():
			continue
		allies_shown += 1
		var p := clamp_edge(to_map(f.pos().x - at.x, f.pos().z - at.z, yaw, ppm), half - 4.0)
		draw_circle(c + p, 5.5, Color.BLACK)
		draw_circle(c + p, 4.5, COL_DOWN if f.downed else COL_ALLY)
	if not me.dead():
		var p := c + clamp_edge(to_map(me.pos().x - at.x, me.pos().z - at.z, yaw, ppm), half - 6.0)
		var fwd := me.facing()
		var d := to_map(fwd.x, fwd.z, yaw, 1.0).normalized()
		var side := Vector2(-d.y, d.x)
		var tri := PackedVector2Array([p + d * 9.0, p - d * 6.0 + side * 6.5, p - d * 6.0 - side * 6.5])
		draw_colored_polygon(tri, COL_DOWN if me.downed else COL_ME)
		draw_polyline(PackedVector2Array([tri[0], tri[1], tri[2], tri[0]]), Color.BLACK, 1.5, true)
	draw_rect(Rect2(Vector2.ZERO, size), COL_EDGE, false, 2.0)


## Un enemigo en rojo si lo ve tu equipo (enemy_seen). Los marcados llevan un aro.
func _enemy(z: Dictionary, marked: bool, hidden: bool, spotted: bool, c: Vector2, at: Vector3, yaw: float,
		ppm: float, r: float) -> void:
	var pos: Vector3 = (z["node"] as Node3D).global_position
	if not enemy_seen(marked, hidden, spotted, _team_dist(pos)):
		return
	seen_ids[(z["node"] as Node3D).get_instance_id()] = true
	var p := c + clamp_edge(to_map(pos.x - at.x, pos.z - at.z, yaw, ppm), SIZE * 0.5 - r)
	draw_circle(p, r + 1.0, Color.BLACK)
	draw_circle(p, r, COL_ENEMY)
	if marked:
		draw_arc(p, r + 3.5, 0.0, TAU, 20, COL_ENEMY, 1.5, true)


## Lo que le falta a tu equipo para verlo: la distancia desde el más cercano (derribados incluidos:
## tumbados también miran).
func _team_dist(pos: Vector3) -> float:
	var best := INF
	for f: Fighter in main.combat.fighters:
		if f.team == main.pf.team and not f.dead():
			best = minf(best, f.pos().distance_to(pos))
	return best
