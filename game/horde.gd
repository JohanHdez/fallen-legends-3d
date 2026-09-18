## La Horda: oleadas de criaturas, especies, jefe, campo de flujo hacia el jugador e IA de cada
## criatura. Sacada de main.gd el 2026-09-17 sin cambiar nada (13 trazas deterministas idénticas),
## para poder cambiarla después: sentidos de las criaturas, Horda en equipo y jefe-leyenda.
## main.gd la crea solo en la Horda y le da cuerda cada fotograma.
class_name Horde
extends RefCounted

var main: Main
var combat: Combat
var vfx: Vfx
var rng: RandomNumberGenerator

const BOSS_LEGEND := "rompemareas"
const BOSS_LEGEND_HP := 4.0            # a medir: el zombi-jefe de antes tenía 720 y este sale con 1.440
const BOSS_HP_PER_PLAYER := 0.2        # horde.gd del 2D
const BOSS_LEGEND_DMG := 1.5           # horde.BOSS_DMG_MULT del 2D
const BOSS_SCALE := 1.3
# Dificultad (petición del usuario, 2026-09-17: "fue muy fácil", "muy dóciles", "mientras avancen las
# zonas podríamos hacerlos un poco más difíciles"). Daño de base por encima del 2D, +10 % de vida por
# oleada (horde.HP_PER_WAVE del 2D) y, por cada tramo que cierra el gas, más vida, daño y velocidad
# para lo que salga desde entonces (vida) y para todas a la vez (daño y velocidad).
# Con equipo salen bastantes más criaturas y más de un jefe (petición del usuario, 2026-09-17:
# "deja que salgan más Rompemareas... y más cantidad dependiendo si hay más personas"). Antes eran
# 3 criaturas más por compañero y 8 vivas más; ahora el doble largo, y los jefes se multiplican.
const PER_PLAYER_SPAWN := 6            # criaturas más en cada oleada por cada compañero
const PER_PLAYER_ALIVE := 10           # y vivas a la vez
# Esquema de jefes y final que fijó el usuario (2026-09-17): la Horda son 10 oleadas, los Rompemareas
# empiezan en la 5 y van subiendo (1, 2, 3, 4) hasta quedarse en cuatro a partir de la 8. Superar la
# oleada 10 es GANAR: antes las oleadas no acababan nunca.
const WAVES := 10
const BOSS_FIRST := 5                  # primera oleada con jefe
const BOSS_MAX := 4                    # tope de jefes a la vez
# Con 70 criaturas vivas, mover el esqueleto de todas es lo que más cuesta en el móvil: las que están
# a más de esto de la cámara se quedan quietas de animación (se siguen moviendo por el mapa) y vuelven
# a animarse al acercarse. Petición del usuario (2026-09-17): "los FPS mínimo 30, ideal 60".
const ANIM_FAR := 30.0
# Por dónde entra cada oleada (petición del usuario, 2026-09-18: "procurar que cuando empiece la
# partida siempre sean en zonas diferentes porque normalmente la oleada está siendo siempre en los
# pastos altos"). Antes las celdas de salida se fijaban UNA vez —en el móvil, un anillo alrededor de
# donde empezabas— y todas las oleadas llegaban por el mismo lado. Ahora cada oleada escoge un
# abanico alrededor del equipo y el abanico gira 137,5° por oleada (el ángulo de oro, el mismo truco
# que reparte a los esqueletos de la emboscada): en diez oleadas no se repite dirección.
const SECTOR_HALF := 1.05              # ±60° de abanico
const SECTOR_TURN := 2.39996           # 137,5° de giro de una oleada a la siguiente
const SECTOR_MIN := 4                  # con menos celdas que esto, el abanico no vale: se usa todo
const CREATURE_DMG := 1.3
const HP_PER_WAVE := 0.1
const GAS_STAGES := 4
const STAGE_HP := 0.15
const STAGE_DMG := 0.10
const STAGE_SPD := 0.05

var zombies: Array = []        # {node, anim, hp, swing_t, dead_t}
var _flows := {}               # id de leyenda viva -> campo de flujo hacia ella: [x][y] = celda siguiente
var _flow_t := 0.0
var wave := 0
var left_to_spawn := 0
var spawn_t := 0.0
var _break_t := 0.0
var spawn_cells: Array = []
var wave_cells: Array = []           # las de ESTA oleada: el abanico por el que entra (sondas)
var _grave_cells: Array = []
var spawned := {}                    # cuántas han salido de cada especie (solo para --log)
var boss_alive := false
var stage := 0                       # tramo del gas: 0 esperando, 1-4 cerrando (dificultad)
var shouts := 0                      # gritos de criaturas que descubren a alguien (sondas)
var detections: Array = []           # {dist, hidden, chasing, night, los} de cada detección (sondas)
var alerted: Array = []              # a qué distancia oyó cada criatura avisada el grito (sondas)
var _sense_seq := 0                  # reparte las comprobaciones de sentidos entre fotogramas

const SEEN_FRESH := 0.5              # la vio hace menos de esto: va a por ella por su campo de flujo
const WANDER_SPEED := 0.55           # deambulando van despacio; rebuscando, algo más; persiguiendo, a tope
const SEARCH_SPEED := 0.8
# La mitad de las metas al deambular caen cerca del centro del área limpia, que es donde el gas acaba
# empujando a todos: con metas solo al azar alrededor de cada una, tardaban casi un minuto en dar con
# alguien y una oleada podía quedarse atascada con tres criaturas paseando lejos.
const WANDER_TO_CENTER := 0.5
const CENTER_CELLS := 6

func _init(p_main: Main) -> void:
	main = p_main
	combat = p_main.combat
	vfx = p_main.vfx
	rng = p_main.rng


## Solo para pruebas: criaturas QUIETAS en fila delante del jugador, a 6, 11, 16, 21... m. Sirve
## para medir a ojo el alcance de una habilidad sin que se te echen encima mientras apuntas.
func spawn_targets(n: int) -> void:
	# En la dirección en la que mira la CÁMARA, no el modelo: al arrancar no coinciden, y con la
	# del modelo las dianas salían detrás del jugador, fuera de plano.
	var f := Vector3(-sin(main._yaw), 0, -cos(main._yaw))
	if main.player_model != null:
		main.player_model.rotation.y = atan2(f.x, f.z)
	var right := f.cross(Vector3.UP).normalized()
	var puestas := 0
	for i in n:
		var d := 6.0 + i * 5.0
		# Escalonadas a izquierda y derecha: en fila recta se tapan unas a otras y no se ve
		# cuál está a qué distancia.
		var at := main.player.global_position + f * d + right * (1.6 if i % 2 == 0 else -1.6)
		var before := zombies.size()
		spawn_zombie(at)
		if zombies.size() <= before:
			continue
		var z: Dictionary = zombies[zombies.size() - 1]
		z["stun_t"] = 900.0                  # clavadas: son dianas, no enemigos
		var lbl := Label3D.new()             # con la distancia encima, para no medir a ojo
		lbl.text = "%d m" % int(round(d))
		lbl.font_size = 72
		lbl.pixel_size = 0.004
		lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		lbl.no_depth_test = true
		lbl.outline_size = 18
		lbl.position = Vector3(0, 2.6, 0)
		(z["node"] as Node3D).add_child(lbl)
		puestas += 1
	print("dianas: %d a 6, 11, 16... m, escalonadas y con su distancia escrita" % puestas)


## Tramo del gas: 0 mientras espera; al empezar a cerrar, 1; y uno más por cada cuarto del cierre hasta
## GAS_STAGES.
static func gas_stage(r0: float, r: float, stop: float, closing: bool) -> int:
	if not closing:
		return 0
	var p := clampf((r0 - r) / maxf(r0 - stop, 0.01), 0.0, 1.0)
	return mini(1 + int(floor(p * GAS_STAGES)), GAS_STAGES)


## Vida de lo que sale en la oleada `w` con el gas en el tramo `s`.
## Criaturas de la oleada `w` con `party` leyendas en el equipo.
static func wave_size(w: int, party: int) -> int:
	return 6 + w * 4 + PER_PLAYER_SPAWN * (party - 1)      # horde._wave_plan del 2D, con más por compañero


## Cuántas criaturas pueden estar vivas a la vez.
static func alive_cap(party: int) -> int:
	return Main.MAX_ALIVE + PER_PLAYER_ALIVE * (party - 1)


## Vida de CADA jefe cuando salen `count` a la vez: se reparte por la raíz del número, así que cuatro
## jefes no son cuatro veces la vida (serían 9.000 y no hay quien los tumbe) sino el doble en total,
## repartido en cuatro cuerpos que pegan cada uno por su cuenta.
static func boss_hp_mult(party: int, count: int) -> float:
	return BOSS_LEGEND_HP * (1.0 + BOSS_HP_PER_PLAYER * float(party - 1)) / sqrt(float(maxi(count, 1)))


## Rompemareas de la oleada `w`: ninguno antes de BOSS_FIRST; después uno más por oleada hasta BOSS_MAX.
static func boss_count(w: int) -> int:
	return clampi(w - BOSS_FIRST + 1, 0, BOSS_MAX)


## ¿Se acabó la Horda con victoria? Última oleada, sin criaturas vivas, sin jefes en pie y sin nada
## por salir.
static func run_over(w: int, alive: int, boss_alive: bool, left: int) -> bool:
	return w >= WAVES and alive <= 0 and not boss_alive and left <= 0


static func hp_mult(w: int, s: int) -> float:
	return (1.0 + HP_PER_WAVE * float(maxi(w - 1, 0))) * (1.0 + STAGE_HP * float(s))


static func dmg_mult(s: int) -> float:
	return CREATURE_DMG * (1.0 + STAGE_DMG * float(s))


static func speed_mult(s: int) -> float:
	return 1.0 + STAGE_SPD * float(s)


## Leyendas del equipo en la partida (vivas o caídas): las oleadas escalan con ellas, como en el 2D.
func party_size() -> int:
	var n := 0
	for f: Fighter in combat.fighters:
		if f.team != Fighter.TEAM_HORDE:
			n += 1
	return maxi(n, 1)


## Dirección (radianes, en celdas x/y) por la que entra la oleada `w`.
static func wave_angle(w: int) -> float:
	return fposmod(float(w) * SECTOR_TURN, TAU)


## Las celdas de `cells` que caen en el abanico de la oleada `w` visto desde `center`. Si el abanico
## se queda sin celdas (el borde del mapa por ese lado no es suelo), vale cualquiera: más vale una
## oleada por donde sea que una oleada que no sale.
static func sector_cells(cells: Array, center: Vector2i, w: int) -> Array:
	var a := wave_angle(w)
	var out: Array = []
	for c: Vector2i in cells:
		var d := Vector2(c.x - center.x, c.y - center.y)
		if d.length() < 0.5:
			continue
		if absf(wrapf(d.angle() - a, -PI, PI)) <= SECTOR_HALF:
			out.append(c)
	return out if out.size() >= SECTOR_MIN else cells


func setup() -> void:
	spawn_cells = MapBuilder.edge_cells(main._mb_grid)
	_grave_cells = MapBuilder.cemetery_graves(main._mb_grid, main._mb_zones, Main.MAP_SEED)
	_rebuild_flows()
	wave = int(main._args.get("wave", "2" if main.touch else "1")) - 1
	_start_wave()
	print("horda lista: %d celdas de borde, %d tumbas" % [spawn_cells.size(), _grave_cells.size()])


func _start_wave() -> void:
	wave += 1
	if main.horde_mode != null:
		main.horde_mode.on_wave_start()   # las muertas del equipo vuelven
	left_to_spawn = wave_size(wave, party_size())
	wave_cells = _wave_spawn_cells()
	_break_t = 0.0
	var n := boss_count(wave)
	for i in n:
		spawn_boss(n)
	if n > 0:
		print("oleada %d de %d: %d criaturas + %d JEFE(S) Rompemareas" % [wave, WAVES, left_to_spawn, n])
	else:
		print("oleada %d de %d: %d criaturas" % [wave, WAVES, left_to_spawn])


## Las celdas por las que sale ESTA oleada: el abanico que le toca, alrededor del equipo AHORA (no de
## donde empezó la partida). En el móvil el abanico se recorta a un anillo cercano, o las criaturas
## tardarían media oleada en llegar.
func _wave_spawn_cells() -> Array:
	if spawn_cells.is_empty():
		return []
	var center := main._cell_of(_team_center())
	var pool := spawn_cells
	if main.touch and not main._args.has("near"):
		var near := main._cells_around(center, 9)
		if near.size() >= SECTOR_MIN:
			pool = near
	return sector_cells(pool, center, wave)


## El centro del equipo: la media de las leyendas que siguen en juego (la tuya, si no queda nadie).
func _team_center() -> Vector3:
	var acc := Vector3.ZERO
	var n := 0
	for f: Fighter in combat.fighters:
		if f.team != Fighter.TEAM_HORDE and not f.dead():
			acc += f.pos()
			n += 1
	return acc / float(n) if n > 0 else main.player.global_position


## El jefe de la oleada: una leyenda Rompemareas llevada por un bot del bando de la horda, como el
## jefe-leyenda del 2D (level.spawn_boss_legend), con sus tres poderes: mandoble cargado, Enganche que te
## arrastra y Ancla clavada. Antes era un zombi grande con su modelo que solo pegaba de cerca, y el
## usuario lo notó: "nunca usó sus poderes contra mí" (2026-09-17). Vida ×BOSS_LEGEND_HP de la de la
## leyenda, más un 20 % por compañero (horde.BOSS_HP_PER_PLAYER del 2D), y todo su daño ×1,5.
func spawn_boss(count := 1) -> void:
	var out_cells: Array = wave_cells if not wave_cells.is_empty() else spawn_cells
	if out_cells.is_empty():
		return
	var c: Vector2i = out_cells[rng.randi() % out_cells.size()]
	var f := combat.spawn_fighter(_legend_index(BOSS_LEGEND), Fighter.TEAM_HORDE, false,
		main._cell_pos(c.x, c.y) + Vector3(0, 0.3, 0))
	f.hp_mult = boss_hp_mult(party_size(), count)
	f.rec["hpmax"] = f.hp_max()
	f.rec["hp"] = f.hp_max()
	f.dmg_mult = BOSS_LEGEND_DMG
	f.regen = false          # con 1.700 de vida, el 8 %/s eran 138 por segundo: no había quien lo tumbara
	f.display_name = "Jefe Rompemareas"
	f.reset_abilities()
	if f.model != null:
		f.model.scale *= BOSS_SCALE          # más grande que el Rompemareas de un compañero
		if f.bar != null:
			f.bar.position.y = combat.bar_height(f)
	f.label = TeamMode.make_label(f, "JEFE ROMPEMAREAS")
	f.label.modulate = Color(1.0, 0.55, 0.35)
	f.brain = BotBrain.new(f, combat, main)
	boss_alive = true


## El jefe ha caído: deja de contar, la baja es de quien lo tumbó y el cuerpo se retira al rato.
func on_boss_down(f: Fighter, by: Fighter) -> void:
	boss_alive = false
	for o: Fighter in combat.fighters:
		if o.team == Fighter.TEAM_HORDE and o.alive():
			boss_alive = true                # otro jefe de otra oleada sigue en pie
	print("¡jefe abatido!")
	if by == null or by.is_player:
		main._kills += 1
		main.pf.streak += 1
		main._show_badge(main._badge_for())
	else:
		by.kills += 1
		by.streak += 1
	var body := f.body
	main.get_tree().create_timer(2.5).timeout.connect(func() -> void:
		if is_instance_valid(body):
			body.visible = false)


static func _legend_index(id: String) -> int:
	for i in LegendData.LEGENDS.size():
		if String(LegendData.LEGENDS[i]["id"]) == id:
			return i
	return 0


## Un campo de flujo por leyenda viva del equipo, cada FLOW_EVERY: la criatura que persigue a una va por
## el suyo. Antes había uno solo hacia el jugador, y las criaturas sabían siempre dónde estaba.
func _rebuild_flows() -> void:
	for f: Fighter in combat.fighters:
		if f.team == Fighter.TEAM_HORDE:
			continue
		if f.alive():
			_flows[f.id] = _bfs([main._cell_of(f.pos())])
		else:
			_flows.erase(f.id)


## Animación solo para las criaturas de cerca (ANIM_FAR). Solo toca el AnimationPlayer cuando cambia
## de lado, así que no cuesta nada por fotograma.
func _anim_lod(z: Dictionary, pos: Vector3) -> void:
	var anims: Array = z["anims"]
	if anims.is_empty():
		return
	var near: bool = pos.distance_squared_to(main.pivot.global_position) <= ANIM_FAR * ANIM_FAR
	if bool(z.get("anim_on", true)) == near:
		return
	z["anim_on"] = near
	for ap in anims:
		(ap as AnimationPlayer).active = near


## Campo de flujo por BFS desde `goals`: cada celda guarda la siguiente hacia la meta más cercana. Es
## lo que permite que 40 criaturas recorran los pasillos sin una malla de navegación ni una ruta por
## bicho.
func _bfs(goals: Array) -> Array:
	var flow: Array = []
	for x in main.mw:
		var col := []
		col.resize(main.mh)
		col.fill(Vector2i(-1, -1))
		flow.append(col)
	var q: Array[Vector2i] = []
	for goal: Vector2i in goals:
		if not main._in_map(goal) or not MapBuilder.walkable(main.grid[goal.x][goal.y]) or flow[goal.x][goal.y].x != -1:
			continue
		q.append(goal)
		flow[goal.x][goal.y] = goal
	var head := 0
	var dirs := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
		Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1)]
	while head < q.size():
		var c: Vector2i = q[head]
		head += 1
		for d in dirs:
			var n: Vector2i = c + d
			if not main._in_map(n) or flow[n.x][n.y].x != -1:
				continue
			if not MapBuilder.walkable(main.grid[n.x][n.y]):
				continue
			# en diagonal, no cortar esquinas por dentro de un muro
			if d.x != 0 and d.y != 0:
				if not MapBuilder.walkable(main.grid[c.x + d.x][c.y]) or not MapBuilder.walkable(main.grid[c.x][c.y + d.y]):
					continue
			flow[n.x][n.y] = c
			q.append(n)
	return flow


## Sale por el abanico de esta oleada (bordes del mapa, o un anillo cercano en el móvil) o de una
## tumba, como en la Horda del juego.
func spawn_zombie(at := Vector3.INF) -> void:
	var placed := at != Vector3.INF     # sitio fijo: lo usan las dianas de prueba
	var out_cells: Array = wave_cells if not wave_cells.is_empty() else spawn_cells
	if zombies.size() >= alive_cap(party_size()) or (not placed and out_cells.is_empty()):
		return
	var from_grave := not placed and not _grave_cells.is_empty() and rng.randf() < 0.3
	var c := Vector2i.ZERO
	if not placed:
		c = _grave_cells[rng.randi() % _grave_cells.size()] if from_grave \
			else out_cells[rng.randi() % out_cells.size()]
	# De una tumba solo sale lo que tiene sentido que estuviera enterrado.
	var sp := _pick_species(from_grave)
	var proto := main._proto_of(sp)
	if proto == null:
		return
	var model := proto.duplicate() as Node3D
	if model == null:
		return
	var body := CharacterBody3D.new()
	body.collision_layer = Main.L_CREATURE
	body.collision_mask = Main.L_WORLD | Main.L_CREATURE
	# De una tumba brota sobre la losa, delante de la lápida (que está a -0,9 y ahora choca): con el
	# reparto de ±0,8 de siempre algunas nacían dentro de la piedra.
	var jitter := Vector3(rng.randf_range(-0.6, 0.6), 0.2, rng.randf_range(0.1, 1.1)) if from_grave \
		else Vector3(rng.randf_range(-0.8, 0.8), 0.2, rng.randf_range(-0.8, 0.8))
	body.position = at + Vector3(0, 0.2, 0) if placed else main._cell_pos(c.x, c.y) + jitter
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = float(sp["rad"])
	cap.height = float(sp["cap"])
	cs.shape = cap
	cs.position = Vector3(0, float(sp["cap"]) * 0.5, 0)
	body.add_child(cs)
	body.add_child(model)
	main.add_child(body)
	var anims := main._anims_of(model)
	main._play_all(anims, "Zombie_Walk_Fwd", rng.randf() * 1.5)
	if float(sp["eyes"]) > 0.0:
		main._add_eyes(model, sp["eye_col"], float(sp["eyes"]))
	var bar := main._make_bar(body, float(sp["bar"]), Main.BAR_ENEMY, float(sp["bscale"]))
	bar.visible = false        # solo se asoma al recibir un golpe (petición del usuario)
	var hpmax := Main.ZOMBIE_HP * float(sp["hp"]) * hp_mult(wave, stage)
	zombies.append({"node": body, "kind": "zombie", "team": Fighter.TEAM_HORDE, "anims": anims, "bar": bar, "hpmax": hpmax, "hp": hpmax,
		"swing_t": 0.0, "dead_t": -1.0, "stun_t": 0.0, "sp": sp["id"],
		"spd": float(sp["spd"]), "dmg": float(sp["dmg"]), "reach": float(sp["reach"]),
		"bscale": float(sp["bscale"]), "cap": float(sp["cap"]),
		# Sentidos (etapa 4 de la Horda en equipo): nace deambulando, sin saber dónde está nadie.
		"state": "wander", "know": -1, "last": Vector3.ZERO, "seen_t": 99.0, "search_t": 0.0, "wander_t": 0.0,
		"sense_t": CreatureSenses.CHECK_EVERY * float(_sense_seq % 5) / 5.0, "goal": Vector3.INF,
		"path": [], "path_goal": Vector2i(-999, -999), "wait_t": 0.0, "alert_t": 0.0, "stuck_t": 0.0})
	_sense_seq += 1
	spawned[sp["id"]] = int(spawned.get(sp["id"], 0)) + 1


## Sorteo por pesos, con dos filtros: de una tumba solo sale lo que tiene sentido que
## estuviera enterrado (un licántropo saliendo de una lápida no se sostiene) y las élites
## esperan a su oleada.
func _pick_species(from_grave := false) -> Dictionary:
	var pool: Array = []
	var total := 0
	for sp in Main.SPECIES:
		if from_grave and not bool(sp["grave"]):
			continue
		if wave < int(sp["minw"]):
			continue          # las élites no salen en las primeras oleadas
		pool.append(sp)
		total += int(sp["w"])
	if pool.is_empty():
		return Main.SPECIES[0]
	var r := rng.randi() % total
	for sp in pool:
		r -= int(sp["w"])
		if r < 0:
			return sp
	return pool[0]


func tick(delta: float) -> void:
	if main.music != null:
		main._play_music(boss_alive)
	if main.zone_active():
		var s := gas_stage(main._zone_r0, main._zone_r, main._zone_floor(), main._zone_t > main._zone_wait)
		if s > stage:
			stage = s
			print("[HORDA] el gas avanza: tramo %d de %d, las criaturas se endurecen" % [stage, GAS_STAGES])
			if main.horde_mode != null and main.horde_mode.hud != null:
				main.horde_mode.hud.banner("¡La horda se endurece! (%d/%d)" % [stage, GAS_STAGES])
	_flow_t -= delta
	if _flow_t <= 0.0:
		_flow_t = Main.FLOW_EVERY
		_rebuild_flows()

	# goteo de aparición y cambio de oleada
	if left_to_spawn > 0:
		spawn_t -= delta
		if spawn_t <= 0.0:
			spawn_t = Main.SPAWN_EVERY
			var t0 := Time.get_ticks_usec()
			spawn_zombie()
			var ms := (Time.get_ticks_usec() - t0) / 1000.0
			if main._args.has("bench"):
				print("   spawn: %.1f ms" % ms)
			left_to_spawn -= 1
	elif zombies.is_empty() and not boss_alive:     # la oleada del jefe no acaba hasta tumbarlo
		if run_over(wave, zombies.size(), boss_alive, left_to_spawn):
			if main.horde_mode != null:
				main.horde_mode.on_victory()
			return
		_break_t += delta
		if _break_t >= Main.WAVE_BREAK:
			_start_wave()

	for i in range(zombies.size() - 1, -1, -1):
		var z: Dictionary = zombies[i]
		var body: CharacterBody3D = z["node"]
		if z["dead_t"] >= 0.0:
			z["dead_t"] += delta
			if z["dead_t"] > 2.5:
				body.queue_free()
				zombies.remove_at(i)
			continue
		_tick_zombie(z, body, delta)


func _tick_zombie(z: Dictionary, body: CharacterBody3D, delta: float) -> void:
	var pos := body.global_position
	_anim_lod(z, pos)
	z["swing_t"] = maxf(0.0, z["swing_t"] - delta)
	_tick_alert(z, delta)
	# El empujón/tirón se resuelve ANTES que el aturdimiento. Si se mira después, cualquier
	# habilidad que aturda y empuje a la vez deja al enemigo clavado — es exactamente el fallo
	# que el juego 2D arregló en `enemy._tick_ai`. El aturdimiento sigue descontando igual.
	if float(z.get("knock_t", 0.0)) > 0.0:
		z["knock_t"] = float(z["knock_t"]) - delta
		if z.get("stun_t", 0.0) > 0.0:
			z["stun_t"] = float(z["stun_t"]) - delta
		var k: Vector3 = z.get("knock", Vector3.ZERO)
		body.velocity.x = k.x
		body.velocity.z = k.z
		body.velocity.y -= Main.GRAVITY * delta
		body.move_and_slide()
		return
	if z.get("stun_t", 0.0) > 0.0:
		z["stun_t"] -= delta
		body.velocity.x = 0.0
		body.velocity.z = 0.0
		body.velocity.y -= Main.GRAVITY * delta
		body.move_and_slide()
		return
	var anims: Array = z["anims"]
	var ap: AnimationPlayer = anims[0] if anims.size() > 0 else null

	var reach: float = float(z.get("reach", Main.ZOMBIE_REACH))
	# Si tiene una baliza a mano la rompe: es lo que la activa por daño (enemy._beacon_in_reach).
	var bc := combat.beacon_in_reach(Fighter.TEAM_HORDE, pos, reach + 0.6)
	if not bc.is_empty():
		body.velocity = Vector3(0, body.velocity.y, 0)
		if z["swing_t"] <= 0.0:
			z["swing_t"] = Main.ZOMBIE_SWING
			bc["hp"] = float(bc["hp"]) - Main.ZOMBIE_DMG * 2.0
			main._play_all(anims, "Sword_Attack")
			vfx.burst("spark_04", (bc["node"] as Node3D).global_position + Vector3(0, 0.7, 0),
				bc["col"], 8, 0.3, 2.5, 0.3, -3.0)
		body.velocity.y -= Main.GRAVITY * delta
		body.move_and_slide()
		return
	if float(z.get("blind_t", 0.0)) > 0.0:
		# Cegado por el gas Nox: pierde el rumbo y deambula hasta que se le pasa.
		z["blind_t"] = float(z["blind_t"]) - delta
		if not z.has("blind_dir") or rng.randf() < 0.02:
			var a := rng.randf() * TAU
			z["blind_dir"] = Vector3(cos(a), 0, sin(a))
		var wander: Vector3 = z["blind_dir"]
		var bspd: float = Main.ZOMBIE_SPEED * float(z.get("spd", 1.0)) * Main.SLOW_MULT * 0.6
		body.velocity.x = wander.x * bspd
		body.velocity.z = wander.z * bspd
		var mdl := body.get_child(1) as Node3D
		if mdl != null:
			mdl.rotation.y = lerp_angle(mdl.rotation.y, atan2(wander.x, wander.z), 3.0 * delta)
		if ap != null and ap.current_animation != "Zombie_Walk_Fwd":
			main._play_all(anims, "Zombie_Walk_Fwd")
		body.velocity.y -= Main.GRAVITY * delta
		if body.is_on_floor() and body.velocity.y < 0.0:
			body.velocity.y = -1.0
		body.move_and_slide()
		return
	# Sentidos (escalonados) y estado: deambular, perseguir o rebuscar.
	z["seen_t"] = float(z["seen_t"]) + delta
	z["sense_t"] = float(z["sense_t"]) - delta
	if float(z["sense_t"]) <= 0.0:
		z["sense_t"] = CreatureSenses.CHECK_EVERY
		_sense(z, pos)
	_tick_state(z, pos, delta)
	var prey := _prey_for(z, pos)
	var prey_d := INF
	if not prey.is_empty():
		var pp: Vector3 = (prey["node"] as Node3D).global_position
		prey_d = Vector2(pp.x - pos.x, pp.z - pos.z).length()
	if prey_d <= reach:
		body.velocity = Vector3(0, body.velocity.y, 0)
		if z["swing_t"] <= 0.0:
			z["swing_t"] = Main.ZOMBIE_SWING
			var dmg := Main.ZOMBIE_DMG * float(z.get("dmg", 1.0)) * dmg_mult(stage)
			combat.hurt(prey, dmg)
			main._play_all(anims, "Sword_Attack")
		elif ap != null and ap.current_animation == "":
			main._play_all(anims, "Zombie_Idle")
	else:
		var dir := _steer_dir(z, pos, prey)
		var moving := dir.length() > 0.01
		dir += _separation(body) * 0.6
		dir.y = 0.0
		if dir.length() > 0.01:
			dir = dir.normalized()
			var zspd: float = Main.ZOMBIE_SPEED * float(z.get("spd", 1.0)) * speed_mult(stage)
			if prey.is_empty():
				zspd *= WANDER_SPEED if z["state"] == "wander" else (SEARCH_SPEED if z["state"] == "search" else 1.0)
			if float(z.get("slow_t", 0.0)) > 0.0:
				z["slow_t"] = float(z["slow_t"]) - delta
				zspd *= Main.SLOW_MULT
			body.velocity.x = dir.x * zspd
			body.velocity.z = dir.z * zspd
			var model := body.get_child(1) as Node3D
			if model != null:
				model.rotation.y = lerp_angle(model.rotation.y, atan2(dir.x, dir.z), 8.0 * delta)
		else:
			body.velocity.x = 0.0
			body.velocity.z = 0.0
		if ap != null and ap.current_animation != "Sword_Attack":
			var want := "Zombie_Walk_Fwd" if moving else "Zombie_Idle"
			if ap.current_animation != want:
				main._play_all(anims, want)
		# Atascada contra algo con una meta: a otra cosa (si no, se quedaba empujando una pared).
		if moving and body.get_real_velocity().length() < 0.2:
			z["stuck_t"] = float(z["stuck_t"]) + delta
			if float(z["stuck_t"]) > 2.0:
				z["stuck_t"] = 0.0
				z["goal"] = Vector3.INF if z["state"] == "wander" else z["goal"]
				z["path"] = []
		else:
			z["stuck_t"] = 0.0

	body.velocity.y -= Main.GRAVITY * delta
	if body.is_on_floor() and body.velocity.y < 0.0:
		body.velocity.y = -1.0
	body.move_and_slide()


## Mira a su alrededor: la leyenda viva más cercana que vea según CreatureSenses. Si es nueva para ella,
## grita. Lo que ve lo apunta en `detections` para las sondas.
func _sense(z: Dictionary, pos: Vector3) -> void:
	var night: float = main._night_amount(main._day_t)
	var here: Vector2i = main._cell_of(pos)
	var best: Fighter = null
	var best_d := INF
	var rec := {}
	for f: Fighter in combat.fighters:
		if f.team == Fighter.TEAM_HORDE or not f.alive():
			continue
		var d := Vector2(f.pos().x - pos.x, f.pos().z - pos.z).length()
		if d >= best_d:
			continue
		var hidden := combat.is_hidden(f)
		var chasing: bool = z["state"] == "chase" and int(z["know"]) == f.id
		var los := true
		if not hidden:
			if d > CreatureSenses.sight_range(night):
				continue
			los = CreatureSenses.los_clear(main.grid, here, main._cell_of(f.pos()))
		if CreatureSenses.can_see(d, hidden, chasing, night, los):
			best = f
			best_d = d
			rec = {"dist": d, "hidden": hidden, "chasing": chasing, "night": night, "los": los}
	if best == null:
		return
	if detections.size() < 400:
		detections.append(rec)
	var knew: bool = z["state"] == "chase" and int(z["know"]) == best.id
	z["state"] = "chase"
	z["know"] = best.id
	z["last"] = best.pos()
	z["seen_t"] = 0.0
	if not knew:
		_shout(z, best)


## La que descubre a alguien grita ("!" y sonido) y avisa a las que estén a ALERT_RADIUS o menos: saben
## a quién y dónde. Las que ya persiguen a alguien siguen a lo suyo.
func _shout(z: Dictionary, f: Fighter) -> void:
	shouts += 1
	var from := (z["node"] as Node3D).global_position
	_show_alert(z)
	if main.pf != null:
		var d := from.distance_to(main.pf.pos())
		if d < 30.0:
			main._sfx("summon", -10.0 - d * 0.5)
	for o in zombies:
		if o == z or float(o["dead_t"]) >= 0.0 or o.get("state", "") == "chase":
			continue
		var op := (o["node"] as Node3D).global_position
		if CreatureSenses.hears(from, op):
			o["state"] = "chase"
			o["know"] = f.id
			o["last"] = f.pos()
			o["seen_t"] = 0.0
			o["path"] = []
			if alerted.size() < 400:
				alerted.append(Vector2(op.x - from.x, op.z - from.z).length())


## Pasa de un estado a otro: si pierde a quien persigue 3 s, va a rebuscar donde la vio; si rebusca 8 s
## sin encontrarla, vuelve a deambular. Deambulando elige metas al azar y espera un poco en cada una.
func _tick_state(z: Dictionary, pos: Vector3, delta: float) -> void:
	match String(z["state"]):
		"chase":
			var f := combat.fighter_by_id(int(z["know"]))
			if f == null or not f.alive() or float(z["seen_t"]) >= CreatureSenses.LOSE_AFTER:
				z["state"] = "search"
				z["search_t"] = CreatureSenses.SEARCH_TIME
				z["goal"] = z["last"]
				z["path"] = []
		"search":
			z["search_t"] = float(z["search_t"]) - delta
			if float(z["search_t"]) <= 0.0:
				z["state"] = "wander"
				z["wander_t"] = 0.0
				z["goal"] = Vector3.INF
				z["path"] = []
			elif z["goal"] == Vector3.INF or _flat_dist(pos, z["goal"]) < 1.2:
				z["goal"] = _goal_near(z["last"], 3)
				z["path"] = []
		"wander":
			# La horda aprieta: tras un rato sin ver a nadie, va derecha a la leyenda más cercana.
			z["wander_t"] = float(z.get("wander_t", 0.0)) + delta
			if CreatureSenses.hunts(float(z["wander_t"])):
				var target := _nearest_legend(pos)
				if target != null:
					z["state"] = "chase"
					z["know"] = target.id
					z["last"] = target.pos()
					z["seen_t"] = CreatureSenses.LOSE_AFTER * 0.5   # va a por él, pero sin "verlo"
					z["wander_t"] = 0.0
					z["goal"] = Vector3.INF
					z["path"] = []
					return
			if z["goal"] == Vector3.INF:
				z["goal"] = _wander_goal(pos)
				z["path"] = []
			elif _flat_dist(pos, z["goal"]) < 1.2:
				if float(z["wait_t"]) <= 0.0:
					z["wait_t"] = rng.randf_range(0.5, 1.5)
				else:
					z["wait_t"] = float(z["wait_t"]) - delta
					if float(z["wait_t"]) <= 0.0:
						z["goal"] = Vector3.INF


## A quién puede morder: la leyenda que persigue mientras la ve, o el esbirro o señuelo más cercano a
## menos de 14 m (los señuelos están para engañar). Vacío si no hay nadie.
## La leyenda viva (o derribada) más cercana a un punto, para que la horda sepa hacia dónde ir.
func _nearest_legend(pos: Vector3) -> Fighter:
	var best: Fighter = null
	var best_d := INF
	for f: Fighter in combat.fighters:
		if f.team == Fighter.TEAM_HORDE or f.dead():
			continue
		var d := pos.distance_to(f.pos())
		if d < best_d:
			best_d = d
			best = f
	return best


func _prey_for(z: Dictionary, pos: Vector3) -> Dictionary:
	var best_d := 1e9
	var prey: Dictionary = {}
	if z["state"] == "chase" and float(z["seen_t"]) < SEEN_FRESH:
		var f := combat.fighter_by_id(int(z["know"]))
		if f != null and f.alive():
			best_d = pos.distance_to(f.pos())
			prey = f.rec
	for al in combat.allies:
		if float(al["hp"]) <= 0.0 or al.get("hidden", false):
			continue                         # enterrados en una emboscada: no se ven
		var d: float = pos.distance_to((al["node"] as Node3D).global_position)
		if d < best_d and d < 14.0:
			best_d = d
			prey = al
	return prey


## Hacia dónde anda: a su presa (por el campo de flujo de esa leyenda si está lejos), o por su ruta a la
## meta del estado: última posición conocida, sitio donde rebusca o meta de deambular.
func _steer_dir(z: Dictionary, pos: Vector3, prey: Dictionary) -> Vector3:
	if not prey.is_empty():
		var tp: Vector3 = (prey["node"] as Node3D).global_position
		if String(prey.get("kind", "")) == "fighter" and _flat_dist(pos, tp) >= Main.CELL * 1.6:
			var flow: Array = _flows.get(int(prey["fid"]), [])
			var c: Vector2i = main._cell_of(pos)
			if not flow.is_empty() and main._in_map(c) and (flow[c.x][c.y] as Vector2i).x != -1:
				var nxt: Vector2i = flow[c.x][c.y]
				return _flat(main._cell_pos(nxt.x, nxt.y) - pos)
		return _flat(tp - pos)
	var goal: Vector3 = z["last"] if z["state"] == "chase" else z["goal"]
	if goal == Vector3.INF or _flat_dist(pos, goal) < 1.2:
		return Vector3.ZERO
	return _follow(z, pos, goal)


## Sigue una ruta de NavGrid hacia `goal`; la recalcula solo si cambia la celda de destino.
func _follow(z: Dictionary, pos: Vector3, goal: Vector3) -> Vector3:
	var here: Vector2i = main._cell_of(pos)
	var there: Vector2i = main._cell_of(goal)
	if here == there or main.nav == null:
		return _flat(goal - pos)
	var path: Array = z["path"]
	if path.is_empty() or z["path_goal"] != there:
		path = main.nav.path(here, there)
		z["path"] = path
		z["path_goal"] = there
	while path.size() > 1 and (path[0] == here or _flat_dist(main._cell_pos(path[0].x, path[0].y), pos) < 0.9):
		path.remove_at(0)
	if path.is_empty():
		return _flat(goal - pos)
	var c: Vector2i = path[0]
	return _flat(main._cell_pos(c.x, c.y) - pos)


## Meta para deambular: una celda transitable al azar a WANDER_CELLS o menos, dentro del área limpia.
## Si no la encuentra (o está fuera del área limpia), hacia el centro.
func _wander_goal(pos: Vector3) -> Vector3:
	if main.zone_active() and rng.randf() < WANDER_TO_CENTER:
		return _goal_near(main._zone_c, CENTER_CELLS)
	var here: Vector2i = main._cell_of(pos)
	var r := CreatureSenses.WANDER_CELLS
	for i in 8:
		var c := here + Vector2i(rng.randi_range(-r, r), rng.randi_range(-r, r))
		if not main._in_map(c) or not MapBuilder.walkable(main.grid[c.x][c.y]):
			continue
		var p: Vector3 = main._cell_pos(c.x, c.y)
		if main.zone_active() and main._outside_zone(p):
			continue
		return p
	if main.zone_active():
		var to_c: Vector3 = main._zone_c - pos
		to_c.y = 0.0
		return pos + to_c.limit_length(float(r) * Main.CELL)
	return pos


## Una celda transitable al azar a `r` celdas o menos de `center` (rebuscar alrededor), o el propio sitio.
func _goal_near(center: Vector3, r: int) -> Vector3:
	var c0: Vector2i = main._cell_of(center)
	for i in 6:
		var c := c0 + Vector2i(rng.randi_range(-r, r), rng.randi_range(-r, r))
		if main._in_map(c) and MapBuilder.walkable(main.grid[c.x][c.y]):
			return main._cell_pos(c.x, c.y)
	return center


## El "!" sobre la criatura que grita, un segundo.
func _show_alert(z: Dictionary) -> void:
	var lbl: Label3D = z.get("alert")
	if lbl == null or not is_instance_valid(lbl):
		lbl = Label3D.new()
		lbl.text = "!"
		lbl.font_size = 110
		lbl.pixel_size = 0.006
		lbl.outline_size = 18
		lbl.modulate = Color(1.0, 0.35, 0.2)
		lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		lbl.no_depth_test = true
		var bar: Node3D = z.get("bar")
		lbl.position = Vector3(0, (bar.position.y if bar != null else 2.0) + 0.55, 0)
		(z["node"] as Node3D).add_child(lbl)
		z["alert"] = lbl
	z["alert_t"] = 1.0
	lbl.visible = true


func _tick_alert(z: Dictionary, delta: float) -> void:
	if float(z.get("alert_t", 0.0)) <= 0.0:
		return
	z["alert_t"] = float(z["alert_t"]) - delta
	var lbl: Label3D = z.get("alert")
	if lbl != null and is_instance_valid(lbl):
		lbl.visible = float(z["alert_t"]) > 0.0


static func _flat(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z).normalized() if Vector2(v.x, v.z).length() > 0.001 else Vector3.ZERO


static func _flat_dist(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


## Empuje suave entre zombis para que rodeen en vez de apilarse (el juego hace lo mismo
## en enemy._separation, pero allí con celdas espaciales).
func _separation(body: CharacterBody3D) -> Vector3:
	var push := Vector3.ZERO
	var pos := body.global_position
	for z in zombies:
		var other: CharacterBody3D = z["node"]
		if other == body or z["dead_t"] >= 0.0:
			continue
		var d := pos - other.global_position
		d.y = 0.0
		var l := d.length()
		if l > 0.01 and l < 1.3:
			push += d / l * (1.3 - l)
	return push


func kill_zombie(z: Dictionary, by: Fighter = null) -> void:
	z["dead_t"] = 0.0
	if float(z.get("spore_t", 0.0)) > 0.0:
		combat.spore_burst(z)
	if by == null or by.is_player:
		main._kills += 1              # las insignias son tuyas: las bajas de tus compañeros no cuentan
		main.pf.streak += 1
		main._show_badge(main._badge_for())
	else:
		by.kills += 1
		by.streak += 1
	var body: CharacterBody3D = z["node"]
	body.velocity = Vector3.ZERO
	var cs := body.get_child(0) as CollisionShape3D
	if cs != null:
		cs.disabled = true
	main._play_all(z["anims"], "Death01")
