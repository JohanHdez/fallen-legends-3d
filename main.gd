## Fallen Legends 3D: la escena de juego. Construye el mapa (el MISMO que genera la Horda del juego
## 2D con `map_builder.gd`, dibujado con props 3D del Stylized Nature MegaKit de Quaternius), la
## cámara en tercera persona, el control del jugador (teclado, ratón y táctil), la horda y el HUD.
## El combate de cualquier leyenda vive en game/combat.gd, los datos en data/legend_data.gd y los
## efectos en fx/vfx.gd. Arquitectura y reglas: CLAUDE.md.
class_name Main
extends Node3D

# Todo vive DENTRO del proyecto: en un APK no existen las rutas del Mac.
const NATURE := "res://models/nature/"
const CHARS := LegendData.CHARS
const OUTFITS := LegendData.OUTFITS
const BESTIARY := LegendData.BESTIARY
const UAL1 := LegendData.UAL1
const UAL2 := LegendData.UAL2

const CELL := 3.0        # metros por celda del mapa del juego (192x96 px en isométrico)
const WALL_H := 7.0      # alto de la colisión de los muros
const MAP_SEED := 1234
const GRASS_FIELDS := 16       # manchas de hierba alta donde esconderse agachado
const GRASS_RADIUS := 3        # celdas de radio de cada mancha
const COVER_ROCKS := 50        # peñascos sueltos por el campo, para cubrirse (uno por celda despejada)
const COVER_RADIUS := 1.3      # radio de la huella de un peñasco: cabe en su celda de 3 m con holgura
const COVER_STRETCH := 1.4     # estirado en vertical, para que tape a alguien de pie (~1,7-2 m)
const COVER_GAP := 2           # celdas (Chebyshev) entre peñascos
const WALL_ROCK_TOL := 0.1     # roca de muro: lo que puede asomar hacia el suelo (media celda = 1,5)
const WALL_ROCK_OVER := 1.0    # ...y lo que puede solaparse con la roca vecina, para que la pared no tenga huecos
const WALL_ROCK_STRETCH := 1.1
const GRAVE_STONE := Vector3(2.2, 5.2, 0.7)   # escala del guijarro que hace de lápida: ~0,75 × 0,9 m
# --- gas demoníaco (la zona que se cierra) ---
# OJO DE DISEÑO: en el juego esto sería SOLO para PvP (1v1 a 4v4), nunca para la horda; aquí va
# sobre la horda porque el prototipo no tiene PvP y es el único sitio donde se puede ver.
const ZONE_WAIT := 120.0       # 2 min de gracia antes de que el gas empiece a cerrar
const ZONE_SHRINK := 0.24      # m/s que avanza: poco a poco, ~3,7 min hasta cerrarse del todo
const ZONE_MIN := 10.0         # radio en el que se para
const ZONE_DPS := 7.0          # daño por segundo dentro del gas
const ZONE_WALL_H := 16.0      # alto de la pared de humo
# Negro VIOLÁCEO, no negro puro: de noche el negro puro es invisible y de día es un agujero.
const ZONE_COL := Color(0.09, 0.05, 0.13)
const ZONE_GLOW := Color(0.40, 0.09, 0.50)
const WALK := 6.0
const SPRINT := 10.0
const GRAVITY := 22.0

# --- horda ---
const ZOMBIE_HP := 60.0
const ZOMBIE_SPEED := 2.4
const ZOMBIE_DMG := 9.0
const ZOMBIE_REACH := 2.0
const ZOMBIE_SWING := 1.5      # s entre zarpazos
const MAX_ALIVE := 40          # tope de zombis vivos a la vez

# Especies de la horda: data/legend_data.gd.
const SPECIES := LegendData.SPECIES
const SPAWN_EVERY := 0.5       # sale uno cada tanto, como el goteo del juego
const WAVE_BREAK := 4.0
const FLOW_EVERY := 0.4        # cada cuánto se recalcula el campo de flujo
const PLAYER_HP := 210.0   # el Tormentero, de data/classes/tormentero.tres

# Jefe: el Rompemareas (Tidebreaker) en vez del dragón, que en el juego sigue siendo 2D.
const BOSS_WAVE := 5           # sale en esta oleada y en sus múltiplos
const BOSS_HP_MULT := 12.0
const BOSS_DMG_MULT := 2.5
const BOSS_SPEED_MULT := 0.75
const BOSS_REACH := 3.2

# --- poderes del Tormentero, con los números reales de data/abilities/*.tres ---
# El juego mide en píxeles: una celda son 192 px y aquí 3 m, así que 1 px = 1,5625 cm.
const PX := LegendData.PX        # = CELL / 192
const CROSS := 14.0            # tamaño de la mira en píxeles de pantalla

# Esfera voltaica (PROJECTILE, teledirigida)
# Trampa eléctrica (TRAP)
# Tormenta eléctrica (ZONE + campo residual)
const SPARK := Vfx.SPARK

# Esporas, baliza, guardia, señuelos, carga del mandoble y esbirros: game/combat.gd.
const SLOW_MULT := Combat.SLOW_MULT


# Capas de colisión, con el mismo reparto que el juego: el jugador choca SOLO con el mundo
# (muros, valla, balizas) y las criaturas chocan con el mundo y entre sí. Así una embestida
# no se para en el primer enemigo, que es lo que hace el juego 2D con las máscaras 10 y 14.
const L_WORLD := 1
const L_CREATURE := 2
const L_PLAYER := 4
# --- barras de vida ---
const BAR_W := 0.95
const BAR_H := 0.11
const BAR_ALLY := Color(0.35, 0.9, 0.35)
const BAR_ENEMY := Color(0.9, 0.28, 0.24)
const BAR_GAP := 0.30          # hueco entre la coronilla y la barra
const BAR_SHOW := 2.5          # s que la barra de una criatura sigue a la vista tras el golpe
const BAR_FADE := 0.7          # los últimos segundos se van en desvanecido, no de golpe

# --- ciclo día/noche, con los tiempos y colores de level.gd del juego ---
const DAY_TIME := 120.0
const DUSK_TIME := 90.0
const NIGHT_TIME := 120.0
const DAWN_TIME := 90.0
const DAY_CYCLE := DAY_TIME + DUSK_TIME + NIGHT_TIME + DAWN_TIME
const DAY_COLOR := Color(1.0, 0.98, 0.94)
const NIGHT_COLOR := Color(0.34, 0.4, 0.66)
const EYE_COL := Color(1.0, 0.45, 0.12)   # brasa naranja en las cuencas
# Encaje del arma en el puño: ajustado a ojo sobre capturas, es lo único aquí que no sale de un dato.
const WEAPON_POS := Vector3(0.0, 0.02, 0.0)
const WEAPON_ROT := Vector3(0.0, 0.0, 0.0)


# --- táctil ---
# Las mismas que scripts/touch_controls.gd del juego 2D, para que el tacto sea idéntico.
const JOY_RADIUS := 95.0
const JOY_GRAB := 1.7        # el joystick responde hasta este múltiplo de su radio
const KNOB_RADIUS := 42.0
const DEAD_ZONE := 0.18
const ABILITY_SIDE := 92.0
const MAIN_SIDE := 120.0
const AIM_DEAD := 18.0       # px de arrastre a partir de los cuales se apunta a mano
const AIM_RADIUS := 110.0    # px de arrastre que equivalen al alcance máximo
# Datos de leyendas y habilidades: data/legend_data.gd. Alias para no tocar cada uso.
const NECK := LegendData.NECK
const HEAD_M := LegendData.HEAD_M
const HEAD_F := LegendData.HEAD_F
const ABILITIES := LegendData.ABILITIES
const LEGENDS := LegendData.LEGENDS
const PLAYABLE := LegendData.PLAYABLE
const HERO_ANIMS := LegendData.HERO_ANIMS
const HERO_ANIMS_2 := LegendData.HERO_ANIMS_2
const ZOMBIE_ANIMS_1 := LegendData.ZOMBIE_ANIMS_1
const ZOMBIE_ANIMS_2 := LegendData.ZOMBIE_ANIMS_2

# Qué prop dibuja cada celda bloqueada, según la zona del juego (0 campo, 1 cueva, 2 cementerio).
const FOREST := ["CommonTree_1", "CommonTree_2", "CommonTree_3", "CommonTree_4", "CommonTree_5",
	"Pine_1", "Pine_2", "Pine_3", "Pine_4", "Pine_5",
	"TwistedTree_1", "TwistedTree_2", "TwistedTree_3"]
const CAVE_ROCK := ["Rock_Medium_1", "Rock_Medium_2", "Rock_Medium_3"]
const BONEYARD := ["DeadTree_1", "DeadTree_2", "DeadTree_3", "DeadTree_4", "DeadTree_5"]

const FIELD_DECOR := ["Grass_Common_Short", "Grass_Common_Tall", "Grass_Wispy_Short", "Grass_Wispy_Tall",
	"Flower_3_Group", "Flower_4_Group", "Clover_1", "Clover_2", "Bush_Common", "Bush_Common_Flowers",
	"Fern_1", "Plant_1", "Mushroom_Common"]
const CAVE_DECOR := ["Pebble_Round_1", "Pebble_Round_3", "Pebble_Square_2", "Pebble_Square_5",
	"Mushroom_Laetiporus"]
const GRAVE_DECOR := ["Grass_Wispy_Short", "Pebble_Square_1", "Pebble_Square_4", "Mushroom_Common"]

# Colores del suelo por zona: pradera, roca de cueva, tierra de cementerio.
const GROUND := [Color(0.26, 0.37, 0.19), Color(0.26, 0.26, 0.28), Color(0.32, 0.29, 0.23)]

var grid: Array                   # [x][y], transpuesta de la de MapBuilder (ver _ready)
var zones: Array
var _mb_grid: Array               # [y][x], la de MapBuilder tal cual: para sus funciones
var _mb_zones: Array
var _cover_cells := {}            # Vector2i -> true: celdas ocupadas por un peñasco de cobertura
var tall_grass: Array             # [x][y] true = hierba alta: agachado ahí no te ven
var mw := 0
var mh := 0
var rng := RandomNumberGenerator.new()
var vfx: Vfx                      # efectos visuales (fx/vfx.gd)
var combat: Combat                # habilidades, daño y leyendas (game/combat.gd)
var pf: Fighter = null            # tu leyenda (combat.fighters[0])
var _mode := "horda"              # "menu", "horda", "1v1", "2v2", "3v3" o "4v4" (GameModes)
var team_mode: TeamMode = null    # partida por equipos (null en la Horda y en el menú)
var nav: NavGrid = null           # navegación de los bots

# Alias de tu leyenda, para que la cámara, el control y el HUD se lean como antes.
var player: CharacterBody3D:
	get: return pf.body if pf != null else null
var player_model: Node3D:
	get: return pf.model if pf != null else null
var player_anims: Array:
	get: return pf.anims if pf != null else []
var player_anim: AnimationPlayer:
	get: return pf.anim if pf != null else null
var _legend: int:
	get: return pf.legend if pf != null else 0
var _php: float:
	get: return pf.hp() if pf != null else 0.0
	set(v):
		if pf != null:
			pf.rec["hp"] = v
var _chg: Array:                  # lo lee touch_ui.gd
	get: return pf.chg if pf != null else [0, 0, 0]
var _gltf_cache := {}

var pivot: Node3D
var spring: SpringArm3D
var cam: Camera3D
var hud: Label
var _yaw := 0.0
var _pitch := -0.26
var _cam_mode := 0        # 0 = sobre el hombro, 1 = vista alta tipo ARPG
var _cam_height := 1.5
var _shot := ""           # --shot=ruta.png: captura y sale (para enseñar el prototipo sin jugarlo)
var _shot_wait := 30
var _dbg := false
var _props := 0
var _placed := {}         # ruta de modelo -> transformadas de sus copias (MultiMesh); lo leen las sondas

var zombies: Array = []        # {node, anim, hp, swing_t, dead_t}
var _flow: Array = []          # campo de flujo: _flow[x][y] = celda siguiente hacia el jugador
var _flow_t := 0.0
var _wave := 0
var _left_to_spawn := 0
var _spawn_t := 0.0
var _break_t := 0.0
var _kills := 0
var _first_kill_done := false
var _badge_img: TextureRect = null
var _badge_cap: Label = null
var _badge_tween: Tween = null
var _badge_tex := {}
var _spawn_cells: Array = []
var _grave_cells: Array = []
var _zombie_proto: Node3D = null      # el esqueleto de espada; también sirve de esbirro del liche
var _species_proto := {}              # id de especie -> modelo del que se duplican los demás
var _spawned := {}                    # cuántas han salido de cada especie (solo para --log)
var _boss_proto: Node3D = null
var _boss_alive := false
var music: AudioStreamPlayer = null
var _sfx_pool: Array = []
var _sfx_next := 0
var _sfx_cache := {}
var _fx_cache := {}
var _music_boss := false

var sun: DirectionalLight3D = null
var world_env: Environment = null
var _day_t := 0.0
var _zone_c := Vector3.ZERO       # centro actual del área limpia
var _zone_c0 := Vector3.ZERO      # centro de salida: el del mapa
var _zone_c1 := Vector3.ZERO      # adonde acabará cerrándose (sale sorteado)
var _zone_r := 0.0
var _zone_r0 := 0.0
var _zone_t := 0.0                # segundos que lleva la partida
var _zone_wall: MeshInstance3D = null
var _zone_ring: MeshInstance3D = null
var _zone_hurt := 0.0
var _zone_veil: ColorRect = null
var _zone_veil_a := 0.0
var _zone_wait := ZONE_WAIT       # --zonewait=N lo acorta para probar
var _zone_fast := 1.0             # --zonefast=N acelera el cierre para probar
var _touch_crouch := false        # el botón de agacharse en táctil
var _brasas_n := -1.0             # último valor de noche aplicado a las brasas
var _cycle := DAY_CYCLE
var _aim_ring: MeshInstance3D = null
var _aim_dot: MeshInstance3D = null
var _preview := -1                 # qué habilidad se está apuntando (-1 ninguna)

var touch := false
var touch_ui: Control = null
var _joy_idx := -1
var _joy_origin := Vector2.ZERO
var _joy_vec := Vector2.ZERO
var _look_idx := -1
var _aim_btn := -1
var _aim_drag := Vector2.ZERO
var _aim_idx := -1


func _ready() -> void:
	_collect_args()
	# `is_touchscreen_available()` devuelve true en cualquier escritorio porque project.godot activa
	# `emulate_touch_from_mouse` (para probar el táctil con el ratón): el Mac arrancaba SIEMPRE en
	# modo móvil, con joystick en pantalla, sin capturar el ratón, sin sombras y en la oleada 2. La
	# emulación no cuenta como pantalla táctil; `--touch` la sigue forzando para probar.
	var real_touchscreen := DisplayServer.is_touchscreen_available() and not Input.is_emulating_touch_from_mouse()
	touch = OS.has_feature("mobile") or OS.has_feature("web_ios") or OS.has_feature("web_android") \
		or real_touchscreen or _args.has("touch")
	_mode = _pick_mode()
	rng.seed = MAP_SEED
	vfx = Vfx.new(self, rng, touch)
	combat = Combat.new(self, vfx)
	var t0 := Time.get_ticks_msec()
	var m: Dictionary = MapBuilder.horde_map(MAP_SEED)
	# MapBuilder guarda [y][x] y este script lee [x][y] en todas partes: antes se dibujaba el mapa
	# TRANSPUESTO y las celdas de MapBuilder (bordes, tumbas) caían en otro sitio; 11 de las 121
	# celdas de entrada de la horda eran roca de cueva. Se transpone una vez aquí, y las llamadas a
	# MapBuilder usan las rejillas originales (_mb_grid, _mb_zones).
	_mb_grid = m["grid"]
	_mb_zones = m["zones"]
	grid = MapLayout.transpose(_mb_grid)
	zones = MapLayout.transpose(_mb_zones)
	mw = grid.size()
	mh = (grid[0] as PackedInt32Array).size()
	print("mapa %dx%d generado con el MISMO map_builder.gd del juego" % [mw, mh])

	_setup_environment()
	_build_ground()
	_build_blockers()
	_build_grass_fields()      # antes que la decoración: decide dónde va la hierba alta
	if not _args.has("nodecor"):
		_scatter_cover()           # antes que la decoración: su celda deja de ser suelo
		_scatter_decor()
	_build_graves(m)
	_build_collision()
	_spawn_player()
	if _mode == "horda":
		_spawn_companions()
	_build_hud()
	if not _args.has("nozone") and _mode != "menu":
		if _args.has("zonewait"):
			_zone_wait = maxf(float(_args["zonewait"]), 0.0)
		if _args.has("zonefast"):
			_zone_fast = maxf(float(_args["zonefast"]), 0.1)
		_setup_zone()
	if _mode == "menu":
		_setup_menu()
	elif GameModes.is_pvp(_mode):
		team_mode = TeamMode.new(self)
		team_mode.setup(_mode)
	else:
		_setup_horde()
	_build_aim()
	if _mode != "menu" and team_mode == null:
		reset_abilities()
	_setup_music()
	if _mode != "menu":
		_setup_touch()
		# Pausa con Seguir / Reiniciar / Menú: por encima del táctil, para que el botón se pueda pulsar.
		var pause_layer := CanvasLayer.new()
		pause_layer.layer = 40
		add_child(pause_layer)
		var pause := PauseMenu.new()
		pause_layer.add_child(pause)
		pause.setup(self)
	_apply_cam_args()
	if _shot == "" and not touch and _mode != "menu":
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	print("construido en %d ms — %d props" % [Time.get_ticks_msec() - t0, _props])
	# --probe=nombre: engancha tests/nombre.gd como hijo, igual que las sondas del juego 2D. La
	# sonda mira el estado de la partida y sale con código 0 (bien) o 1 (fallo).
	if _args.has("probe"):
		var probe_script := load("res://tests/%s.gd" % String(_args["probe"])) as Script
		if probe_script == null:
			push_error("no existe la sonda tests/%s.gd" % _args["probe"])
			get_tree().quit(2)
		else:
			add_child(probe_script.new())


## Opciones de línea de comandos, para sacar vistas sin tener que jugar:
##   --shot=/tmp/a.png  --cam=1  --yaw=45  --pitch=-30  --dist=12  --at=21,21  --dbg
var _args := {}

func _collect_args() -> void:
	for a in OS.get_cmdline_user_args():
		var kv := String(a).split("=")
		_args[kv[0].lstrip("-")] = kv[1] if kv.size() > 1 else "1"
	_shot = _args.get("shot", "")
	_dbg = _args.has("dbg")


func _apply_cam_args() -> void:
	if _args.has("cam"):
		_cam_mode = int(_args["cam"])
		_apply_cam_mode()
	if _args.has("yaw"): _yaw = deg_to_rad(float(_args["yaw"]))
	if _args.has("pitch"): _pitch = deg_to_rad(float(_args["pitch"]))
	if _args.has("dist"): spring.spring_length = float(_args["dist"])
	if _args.has("cycle"):
		_cycle = maxf(10.0, float(_args["cycle"]))
	if _args.has("night"):
		_day_t = DAY_TIME + DUSK_TIME + 10.0      # empezar de noche, para probar
	if _args.has("wait"):
		_shot_wait = int(_args["wait"])
	if _args.has("zombies"):
		_left_to_spawn = int(_args["zombies"])
		_spawn_t = 0.0
	if _args.has("at"):
		var a := String(_args["at"])
		var c := Vector2i(-1, -1)
		if a == "cem":
			c = _cell_in_zone(2)
		elif a == "cueva":
			c = _cell_in_zone(1)
		else:
			var p := a.split(",")
			if p.size() == 2:
				c = Vector2i(int(p[0]), int(p[1]))
		if c.x >= 0:
			player.position = _cell_pos(c.x, c.y) + Vector3(0, 0.3, 0)
	if _args.has("roster"):
		_show_roster()
	if _args.has("near"):
		_spawn_cells = _cells_around(_cell_of(player.position), maxi(3, int(_args["near"]) if String(_args["near"]).is_valid_int() else 10))
		print("aparición cercana: %d celdas" % _spawn_cells.size())
	if _args.has("legend") and team_mode == null and _mode != "menu":
		# Salta el recorte de PLAYABLE a propósito: es la única vía a las retiradas.
		# (Por equipos la aplica TeamMode antes de repartir leyendas a los bots.)
		set_legend(int(_args["legend"]))
	if _args.has("boss"):
		_spawn_boss()      # después de --near, para que salga al lado (solo pruebas)
	if _args.has("cd"):
		combat.cd_cap = maxf(float(_args["cd"]), 0.1)
		print("recargas recortadas a %.1f s (solo prueba)" % combat.cd_cap)
	if _args.has("dianas"):
		var n := int(_args["dianas"]) if String(_args["dianas"]).is_valid_int() else 4
		_spawn_targets(n)


## Alinea las 7 leyendas delante de la cámara para verlas de una vez.
func _show_roster() -> void:
	var base := player.global_position
	for i in PLAYABLE:
		var made := _make_character(LEGENDS[i]["models"])
		var n: Node3D = made.get("node")
		if n == null:
			continue
		_tint_model(n, LEGENDS[i]["tint"])
		var sc := float(LEGENDS[i].get("scale", 1.0))
		if sc != 1.0:
			n.scale = Vector3.ONE * sc
		n.position = base + Vector3((i - (PLAYABLE - 1) * 0.5) * 2.0, 0.0, 3.5)
		n.rotation.y = PI
		add_child(n)
		_play_all(made.get("anims", []), "Idle", i * 0.3)
		var lbl := Label3D.new()
		lbl.text = LEGENDS[i]["name"]
		lbl.font_size = 96
		lbl.pixel_size = 0.0022
		lbl.position = n.position + Vector3(0, _model_top(n) * maxf(n.scale.y, 0.01) + 0.2, 0)
		lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		lbl.outline_size = 24
		add_child(lbl)
	if player_model != null:
		player_model.visible = false


## Solo para pruebas: criaturas QUIETAS en fila delante del jugador, a 6, 11, 16, 21... m. Sirve
## para medir a ojo el alcance de una habilidad sin que se te echen encima mientras apuntas.
func _spawn_targets(n: int) -> void:
	# En la dirección en la que mira la CÁMARA, no el modelo: al arrancar no coinciden, y con la
	# del modelo las dianas salían detrás del jugador, fuera de plano.
	var f := Vector3(-sin(_yaw), 0, -cos(_yaw))
	if player_model != null:
		player_model.rotation.y = atan2(f.x, f.z)
	var right := f.cross(Vector3.UP).normalized()
	var puestas := 0
	for i in n:
		var d := 6.0 + i * 5.0
		# Escalonadas a izquierda y derecha: en fila recta se tapan unas a otras y no se ve
		# cuál está a qué distancia.
		var at := player.global_position + f * d + right * (1.6 if i % 2 == 0 else -1.6)
		var before := zombies.size()
		_spawn_zombie(at)
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


## Celdas transitables a menos de `r` celdas de `c`, para medir con la multitud encima.
func _cells_around(c: Vector2i, r: int) -> Array:
	var out: Array = []
	for x in range(maxi(0, c.x - r), mini(mw, c.x + r + 1)):
		for y in range(maxi(0, c.y - r), mini(mh, c.y + r + 1)):
			if MapBuilder.walkable(grid[x][y]) and Vector2(x - c.x, y - c.y).length() > 1.5:
				out.append(Vector2i(x, y))
	return out


## Celda transitable más céntrica de una zona (1 cueva, 2 cementerio).
func _cell_in_zone(z: int) -> Vector2i:
	var acc := Vector2(0, 0)
	var n := 0
	for x in mw:
		for y in mh:
			if zones[x][y] == z:
				acc += Vector2(x, y)
				n += 1
	if n == 0:
		return Vector2i(-1, -1)
	var mid := acc / float(n)
	var best := Vector2i(-1, -1)
	var best_d := 1e9
	for x in mw:
		for y in mh:
			if zones[x][y] != z or not MapBuilder.walkable(grid[x][y]):
				continue
			var d := Vector2(x - mid.x, y - mid.y).length()
			if d < best_d:
				best_d = d
				best = Vector2i(x, y)
	return best


# ---------------------------------------------------------------- mundo

func _setup_environment() -> void:
	var env := Environment.new()
	var sky := Sky.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.30, 0.50, 0.80)
	sky_mat.sky_horizon_color = Color(0.72, 0.80, 0.86)
	sky_mat.ground_horizon_color = Color(0.72, 0.80, 0.86)
	sky_mat.ground_bottom_color = Color(0.30, 0.33, 0.28)
	sky.sky_material = sky_mat
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_sky_contribution = 0.35
	env.ambient_light_color = Color(0.42, 0.47, 0.55)
	env.ambient_light_energy = 0.4
	env.ssao_enabled = not touch
	env.fog_enabled = true
	env.fog_density = 0.0022
	env.fog_light_color = Color(0.70, 0.78, 0.85)
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	world_env = env
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48, -125, 0)
	sun.light_energy = 1.0
	sun.light_color = Color(1.0, 0.96, 0.88)
	sun.shadow_enabled = not _args.has("noshadow") and not touch
	sun.directional_shadow_max_distance = 30.0 if touch else 55.0
	add_child(sun)


## Posición en metros del centro de la celda (x, y), con el mapa centrado en el origen.
## Textura de suelo: ruido suave horneado sobre el color de la zona. El suelo era un plano de
## color liso y se notaba mucho en las zonas despejadas.
func _ground_tex(base: Color) -> ImageTexture:
	var key := "ground:%s" % base
	if _fx_cache.has(key):
		return _fx_cache[key]
	var n := FastNoiseLite.new()
	n.noise_type = FastNoiseLite.TYPE_SIMPLEX
	n.frequency = 0.035
	n.seed = 7
	var size := 256
	var img := Image.create(size, size, false, Image.FORMAT_RGB8)
	for y in size:
		for x in size:
			var v := n.get_noise_2d(float(x), float(y)) * 0.5 + 0.5      # 0..1
			var f := 0.82 + v * 0.36
			img.set_pixel(x, y, Color(base.r * f, base.g * f, base.b * f))
	var tex := ImageTexture.create_from_image(img)
	_fx_cache[key] = tex
	return tex


func _cell_pos(x: int, y: int) -> Vector3:
	return Vector3((x - mw * 0.5) * CELL, 0.0, (y - mh * 0.5) * CELL)


## Un solo ArrayMesh para todo el suelo, con el color de cada celda en los vértices:
## pradera, roca de cueva o tierra de cementerio, según las zonas que devuelve el juego.
func _build_ground() -> void:
	var tools: Array = []
	for i in GROUND.size():
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		st.set_normal(Vector3.UP)
		tools.append(st)
	var h := CELL * 0.5
	for x in mw:
		for y in mh:
			var z: int = zones[x][y]
			if z >= tools.size():
				z = 0
			var st: SurfaceTool = tools[z]
			var p := _cell_pos(x, y)
			var a := p + Vector3(-h, 0, -h)
			var b := p + Vector3(h, 0, -h)
			var d := p + Vector3(h, 0, h)
			var e := p + Vector3(-h, 0, h)
			for v in [a, b, d, a, d, e]:
				st.set_uv(Vector2(v.x, v.z))
				st.add_vertex(v)
	for i in tools.size():
		var mi := MeshInstance3D.new()
		mi.mesh = (tools[i] as SurfaceTool).commit()
		var mat := StandardMaterial3D.new()
		mat.albedo_texture = _ground_tex(GROUND[i])
		mat.uv1_scale = Vector3(0.09, 0.09, 1.0)   # se repite cada ~11 m
		mat.roughness = 1.0
		mi.material_override = mat
		add_child(mi)


## Cada celda bloqueada del mapa (muro o montaña) se convierte en un árbol o una roca.
func _build_blockers() -> void:
	var by_model := {}
	for x in mw:
		for y in mh:
			var cell: int = grid[x][y]
			if cell != MapBuilder.WALL and cell != MapBuilder.MOUNTAIN:
				continue
			var z: int = zones[x][y]
			var pool: Array = FOREST
			if cell == MapBuilder.MOUNTAIN or z == 1:
				pool = CAVE_ROCK
			elif z == 2:
				pool = BONEYARD
			var name: String = pool[rng.randi() % pool.size()]
			var xf := Transform3D.IDENTITY
			if pool == CAVE_ROCK and _next_to_floor(x, y):
				# Roca que da a un pasillo: las de Quaternius miden ~3,2 m con el pivote desplazado y,
				# puestas a escala 1 con ±0,5 m de holgura, invadían el pasillo hasta 2 m más allá de
				# su caja de colisión: las criaturas se pegaban a la caja y quedaban medio metidas en
				# la piedra. Encajada por su huella real no asoma al suelo más de WALL_ROCK_TOL, y se
				# solapa con sus vecinas de muro para que no queden huecos con pared invisible.
				var shape := _rock_shape(NATURE + name + ".gltf")
				var yaw := rng.randf() * TAU
				var fit := MapLayout.fit_in_cell(shape["hull"], yaw, _blocked_around(x, y), CELL * 0.5,
					WALL_ROCK_TOL, WALL_ROCK_OVER, rng.randf_range(1.0, 1.15))
				xf = MapLayout.fit_transform(fit, yaw, _cell_pos(x, y), WALL_ROCK_STRETCH)
			else:
				# Árboles (el tronco no invade: asoma la copa, por encima de las cabezas) y rocas de
				# dentro del macizo, que nadie puede tocar.
				xf = xf.rotated(Vector3.UP, rng.randf() * TAU)
				xf = xf.scaled(Vector3.ONE * rng.randf_range(0.85, 1.15))
				xf.origin = _cell_pos(x, y) + Vector3(rng.randf_range(-0.5, 0.5), 0, rng.randf_range(-0.5, 0.5))
			(by_model.get_or_add(name, []) as Array).append(xf)
	for name in by_model:
		_multimesh(NATURE + name + ".gltf", by_model[name])


## Qué vecinas de (x, y) son muro, como [dx + 1][dz + 1]. Fuera del mapa cuenta como muro.
func _blocked_around(x: int, y: int) -> Array:
	var out: Array = []
	for dx in [-1, 0, 1]:
		var col: Array = []
		for dy in [-1, 0, 1]:
			var nx: int = x + dx
			var ny: int = y + dy
			col.append(nx < 0 or ny < 0 or nx >= mw or ny >= mh or not MapBuilder.walkable(grid[nx][ny]))
		out.append(col)
	return out


## ¿Alguna de las 8 celdas vecinas es suelo? Es lo que decide si una roca de muro está a la vista y
## al alcance de alguien.
func _next_to_floor(x: int, y: int) -> bool:
	for dx in [-1, 0, 1]:
		for dy in [-1, 0, 1]:
			var nx: int = x + dx
			var ny: int = y + dy
			if nx >= 0 and ny >= 0 and nx < mw and ny < mh and MapBuilder.walkable(grid[nx][ny]):
				return true
	return false


## Hierba, flores, setas y guijarros sobre el suelo transitable. Es lo que hace que
## el mapa se vea "de kit" en vez de una rejilla de cajas.
# -- gas demoníaco: la zona que se cierra ---------------------------

## El gas está en el borde del mapa DESDE EL PRIMER SEGUNDO (petición del usuario): el área limpia
## arranca siendo el círculo inscrito en el mapa, así que las cuatro esquinas ya son gas. A los
## ZONE_WAIT segundos empieza a cerrarse, y mientras se cierra el centro se va DESPLAZANDO hacia un
## punto sorteado: si solo encogiera, la partida acabaría siempre en el mismo sitio.
func _setup_zone() -> void:
	_zone_c0 = _cell_pos(mw / 2, mh / 2)
	_zone_c0.y = 0.0
	_zone_r0 = minf(mw, mh) * CELL * 0.5
	# El final cae en cualquier parte, pero entero dentro del mapa.
	var margin := _zone_r0 - ZONE_MIN - 4.0
	var a := rng.randf() * TAU
	_zone_c1 = _zone_c0 + Vector3(cos(a), 0, sin(a)) * rng.randf() * maxf(margin, 0.0)
	_zone_c = _zone_c0
	_zone_r = _zone_r0

	var cyl := CylinderMesh.new()
	cyl.top_radius = 1.0            # radio 1: la escala del nodo hace el resto cada fotograma
	cyl.bottom_radius = 1.0
	cyl.height = ZONE_WALL_H
	cyl.cap_top = false
	cyl.cap_bottom = false
	cyl.radial_segments = 64
	cyl.rings = 6
	_zone_wall = MeshInstance3D.new()
	_zone_wall.mesh = cyl
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
render_mode blend_mix, cull_disabled, unshaded, depth_draw_never, shadows_disabled;
uniform vec4 col : source_color;
uniform vec4 glow : source_color;
uniform float wall_h = 16.0;
uniform float t = 0.0;
varying float vh;
void vertex() {
	// La altura sale del VÉRTICE, no de la UV: la V del CylinderMesh cambia de convención y
	// adivinarla costó dos intentos (una vez salió el resplandor en la cresta, otra la pared
	// entera transparente). En espacio de objeto la Y va de -h/2 a +h/2 y eso no falla.
	vh = clamp(0.5 - VERTEX.y / wall_h, 0.0, 1.0);    // 1 abajo, 0 arriba
}
void fragment() {
	float n = 0.5 + 0.5 * sin(UV.x * 52.0 + t * 1.3) * sin(vh * 7.0 - t * 0.9);
	// Negro casi entero: el violeta solo asoma en el último palmo, lo justo para que de noche
	// se distinga el borde y de día no sea un agujero recortado.
	ALBEDO = mix(col.rgb, glow.rgb, pow(vh, 5.0) * 0.35);
	ALPHA = clamp(pow(vh, 0.8) * (0.80 + 0.30 * n), 0.0, 0.96);
}
"""
	var m := ShaderMaterial.new()
	m.shader = sh
	m.set_shader_parameter("col", ZONE_COL)
	m.set_shader_parameter("glow", ZONE_GLOW)
	m.set_shader_parameter("wall_h", ZONE_WALL_H)
	_zone_wall.material_override = m
	add_child(_zone_wall)

	_zone_ring = vfx.ring(1.0, ZONE_GLOW, 0.45)     # aro en el suelo, para ver el borde exacto
	add_child(_zone_ring)
	_build_zone_veil()
	_apply_zone()
	print("gas demoníaco: borde a %.0f m, cierra a los %.0f s hacia %v" % [_zone_r0, _zone_wait, _zone_c1])


## Velo de pantalla para cuando estás DENTRO del gas (petición del usuario): una viñeta violeta
## que late al ritmo del daño. Va en su propia capa por encima del mundo y por debajo del HUD, y
## no intercepta el ratón. Es viñeta y no un rectángulo plano a propósito: tapar el centro de la
## pantalla mientras te están matando es justo lo contrario de lo que necesitas.
func _build_zone_veil() -> void:
	var cl := CanvasLayer.new()
	cl.layer = 5
	add_child(cl)
	_zone_veil = ColorRect.new()
	_zone_veil.set_anchors_preset(Control.PRESET_FULL_RECT)
	_zone_veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sh := Shader.new()
	sh.code = """
shader_type canvas_item;
uniform vec4 col : source_color;
uniform float amt = 0.0;
void fragment() {
	float v = smoothstep(0.18, 0.78, length(UV - vec2(0.5)) * 1.42);
	// El centro casi limpio: teñir de morado el sitio donde estás mirando mientras te matan es
	// justo lo contrario de ayudar. El aviso va por los bordes.
	COLOR = vec4(col.rgb, col.a * amt * (0.05 + 0.92 * v));
}
"""
	var m := ShaderMaterial.new()
	m.shader = sh
	m.set_shader_parameter("col", Color(0.52, 0.06, 0.60, 0.72))
	m.set_shader_parameter("amt", 0.0)
	_zone_veil.material = m
	cl.add_child(_zone_veil)


## Coloca la pared y el aro con el centro y el radio de ahora.
func _apply_zone() -> void:
	if _zone_wall == null:
		return
	_zone_wall.position = _zone_c + Vector3(0, ZONE_WALL_H * 0.5 - 1.0, 0)
	_zone_wall.scale = Vector3(_zone_r, 1.0, _zone_r)
	_zone_ring.position = _zone_c + Vector3(0, 0.1, 0)
	_zone_ring.scale = Vector3(_zone_r, 1.0, _zone_r)


func _tick_zone(delta: float) -> void:
	if _zone_wall == null:
		return
	_zone_t += delta
	if _zone_t > _zone_wait and _zone_r > ZONE_MIN:
		_zone_r = maxf(_zone_r - ZONE_SHRINK * _zone_fast * delta, ZONE_MIN)
		# El centro viaja al mismo ritmo que encoge el radio, para que llegue justo al final.
		var p := clampf((_zone_r0 - _zone_r) / maxf(_zone_r0 - ZONE_MIN, 0.01), 0.0, 1.0)
		_zone_c = _zone_c0.lerp(_zone_c1, p)
	_apply_zone()
	var mat := _zone_wall.material_override as ShaderMaterial
	if mat != null:
		mat.set_shader_parameter("t", _zone_t)
	# El velo sube y baja suave, y late mientras estás dentro: que se note que te está matando.
	var inside_gas := _php > 0.0 and _outside_zone(player.global_position)
	var want := (0.60 + 0.28 * sin(_zone_t * 7.0)) if inside_gas else 0.0
	_zone_veil_a = move_toward(_zone_veil_a, want, delta * (4.0 if inside_gas else 2.0))
	if _zone_veil != null and _zone_veil.material != null:
		(_zone_veil.material as ShaderMaterial).set_shader_parameter("amt", _zone_veil_a)
	# Daño dentro del gas. Aquí lo comen también las criaturas: es gas demoníaco, quema a todo
	# lo que respire. En PvP no habría criaturas y el efecto sería el mismo para todos.
	_zone_hurt -= delta
	if _zone_hurt > 0.0:
		return
	_zone_hurt = 0.5
	for f: Fighter in combat.fighters:
		if f.alive() and _outside_zone(f.pos()):
			# Por equipos la vida va ×3 y el gas también: si no, dejaría de apretar.
			combat.hurt(f.rec, ZONE_DPS * 0.5 * f.hp_mult)
			vfx.burst("smoke_02", f.pos() + Vector3(0, 1.0, 0),
				Color(ZONE_GLOW.r, ZONE_GLOW.g, ZONE_GLOW.b, 0.5), 8, 0.9, 1.2, 0.8, 0.35, 80.0, 0.6)
	for z in zombies:
		if z["dead_t"] < 0.0 and _outside_zone((z["node"] as Node3D).global_position):
			combat.hurt(z, ZONE_DPS * 0.5)


func _outside_zone(at: Vector3) -> bool:
	return Vector2(at.x - _zone_c.x, at.z - _zone_c.z).length() > _zone_r


## Lo que el HUD dice del gas: primero la cuenta atrás, después a qué distancia tienes el borde.
func _zone_hud() -> String:
	if _zone_wall == null:
		return ""
	if _zone_t < _zone_wait:
		var left := _zone_wait - _zone_t
		return "   |   el gas cierra en %d:%02d" % [int(left) / 60, int(left) % 60]
	if _outside_zone(player.global_position):
		return "   |   ¡ESTÁS EN EL GAS!"
	var d := _zone_r - Vector2(player.global_position.x - _zone_c.x, player.global_position.z - _zone_c.z).length()
	return "   |   borde del gas a %d m (radio %d)" % [int(d), int(_zone_r)]


## Manchas de hierba CRECIDA repartidas por el campo. Marcarlas en `tall_grass` es lo que hace
## que el camuflaje sepa dónde vale: agachado dentro de una, las criaturas te pierden.
func _build_grass_fields() -> void:
	tall_grass = []
	for x in mw:
		var col := []
		col.resize(mh)
		col.fill(false)
		tall_grass.append(col)
	var placed := 0
	var cells := 0
	for i in GRASS_FIELDS * 8:
		if placed >= GRASS_FIELDS:
			break
		var cx := rng.randi_range(3, mw - 4)
		var cy := rng.randi_range(3, mh - 4)
		if not MapBuilder.walkable(grid[cx][cy]) or zones[cx][cy] != 0:
			continue
		var r := rng.randi_range(2, GRASS_RADIUS)
		for x in range(maxi(cx - r, 0), mini(cx + r + 1, mw)):
			for y in range(maxi(cy - r, 0), mini(cy + r + 1, mh)):
				if Vector2(x - cx, y - cy).length() > r + 0.3:
					continue
				if not MapBuilder.walkable(grid[x][y]) or zones[x][y] != 0 or tall_grass[x][y]:
					continue
				tall_grass[x][y] = true
				cells += 1
		placed += 1
	print("hierba alta: %d manchas, %d celdas" % [placed, cells])


## Peñascos sueltos por el campo para cubrirse. Antes eran rocas a escala 1,4-2,1 (4,5-7 m de ancho)
## con un cilindro de colisión de ~1 m centrado en el pivote, y el pivote de estas rocas está
## desplazado casi un metro: los personajes se metían DENTRO de la roca (tests/rocks_probe.gd lo
## medía en 3.300 de cada 3.600 fotogramas). Ahora cada peñasco:
##  - ocupa UNA celda despejada (MapLayout.pick_cover_cells) que pasa a MOUNTAIN, así que el campo de
##    flujo lo rodea, nadie aparece encima y no cierra pasillos;
##  - se escala y se centra por su huella real para caber en COVER_RADIUS, estirado en vertical;
##  - choca con su envolvente convexa real, con los puntos ya transformados (sin formas escaladas).
func _scatter_cover() -> void:
	var body := StaticBody3D.new()
	body.collision_layer = L_WORLD
	body.collision_mask = 0
	add_child(body)
	var by_model := {}
	var cells := MapLayout.pick_cover_cells(grid, zones, tall_grass, _spawn_cell(), COVER_ROCKS, COVER_GAP, rng)
	for c in cells:
		var name := "Rock_Medium_%d" % (1 + rng.randi() % 3)
		var shape := _rock_shape(NATURE + name + ".gltf")
		if shape.is_empty():
			continue
		var yaw := rng.randf() * TAU
		var fit := MapLayout.fit_footprint(shape["hull"], yaw, COVER_RADIUS * rng.randf_range(0.85, 1.0))
		var xf := MapLayout.fit_transform(fit, yaw, _cell_pos(c.x, c.y), COVER_STRETCH)
		(by_model.get_or_add(name, []) as Array).append(xf)
		var pts := PackedVector3Array()
		for p: Vector3 in shape["hull3d"]:
			pts.append(xf * p)
		var convex := ConvexPolygonShape3D.new()
		convex.points = pts
		var cs := CollisionShape3D.new()
		cs.shape = convex
		body.add_child(cs)
		grid[c.x][c.y] = MapBuilder.MOUNTAIN
		_cover_cells[c] = true
	for name in by_model:
		_multimesh(NATURE + name + ".gltf", by_model[name])
	print("peñascos de cobertura: %d" % cells.size())


## Huella en planta y envolvente convexa (espacio del modelo) de una roca, calculadas una vez.
func _rock_shape(path: String) -> Dictionary:
	var key := "rock:" + path
	if _fx_cache.has(key):
		return _fx_cache[key]
	var scene := _load_gltf(path)
	if scene == null:
		return {}
	var verts := PackedVector3Array()
	var hull3d := PackedVector3Array()
	for e in _meshes_of(scene):
		var mesh: Mesh = e["mesh"]
		var exf: Transform3D = e["xform"]
		for s in mesh.get_surface_count():
			for v: Vector3 in mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX]:
				verts.append(exf * v)
		for v: Vector3 in mesh.create_convex_shape(true, true).points:
			hull3d.append(exf * v)
	var out := {"hull": MapLayout.footprint(verts), "hull3d": hull3d}
	_fx_cache[key] = out
	return out


func _scatter_decor() -> void:
	var by_model := {}
	for x in mw:
		for y in mh:
			if not MapBuilder.walkable(grid[x][y]):
				continue
			if rng.randf() > 0.45:
				continue
			var z: int = zones[x][y]
			var pool: Array = FIELD_DECOR
			if z == 1:
				pool = CAVE_DECOR
			elif z == 2:
				pool = GRAVE_DECOR
			var name: String = pool[rng.randi() % pool.size()]
			var xf := Transform3D.IDENTITY
			xf = xf.rotated(Vector3.UP, rng.randf() * TAU)
			xf = xf.scaled(Vector3.ONE * rng.randf_range(0.7, 1.3))
			xf.origin = _cell_pos(x, y) + Vector3(rng.randf_range(-1.2, 1.2), 0, rng.randf_range(-1.2, 1.2))
			by_model.get_or_add(name, []).append(xf)
	_scatter_grass(by_model)
	for name in by_model:
		_multimesh(NATURE + name + ".gltf", by_model[name])


## Matas de hierba a manta sobre el campo: sin esto el suelo se ve como una moqueta lisa.
func _scatter_grass(by_model: Dictionary) -> void:
	var tufts := ["Grass_Common_Short", "Grass_Common_Tall", "Grass_Wispy_Short", "Grass_Wispy_Tall"]
	for x in mw:
		for y in mh:
			if not MapBuilder.walkable(grid[x][y]) or zones[x][y] != 0:
				continue
			# En una mancha de hierba alta: el triple de matas, solo las variedades altas y a
			# mayor escala. Tiene que verse de lejos que ahí dentro cabe alguien.
			var field: bool = not tall_grass.is_empty() and tall_grass[x][y]
			var pool: Array = ["Grass_Common_Tall", "Grass_Wispy_Tall"] if field else tufts
			var count: int = (6 if touch else 12) if field else (2 if touch else 4)
			for i in count:
				var xf := Transform3D.IDENTITY
				xf = xf.rotated(Vector3.UP, rng.randf() * TAU)
				xf = xf.scaled(Vector3.ONE * (rng.randf_range(1.0, 1.5) if field else rng.randf_range(0.45, 0.8)))
				xf.origin = _cell_pos(x, y) + Vector3(rng.randf_range(-1.4, 1.4), 0, rng.randf_range(-1.4, 1.4))
				by_model.get_or_add(pool[rng.randi() % pool.size()], []).append(xf)


## Las 6 tumbas que el juego coloca en el cementerio: losa plana y lápida de pie. La lápida medía
## 31 × 37 cm y no chocaba con nada, así que las criaturas que salían de la tumba y cualquiera que
## pasara la atravesaban. Ahora mide ~75 × 90 cm (GRAVE_STONE) y lleva su caja de colisión; las
## criaturas brotan sobre la losa, delante de ella (_spawn_zombie).
func _build_graves(m: Dictionary) -> void:
	var cells: Array = MapBuilder.cemetery_graves(_mb_grid, _mb_zones, MAP_SEED)
	var slabs: Array = []
	var stones: Array = []
	var stone_path := NATURE + "Pebble_Square_4.gltf"
	var stone_box := AABB()
	var parts := _meshes_of(_load_gltf(stone_path)) if _load_gltf(stone_path) != null else []
	if not parts.is_empty():
		stone_box = (parts[0]["xform"] as Transform3D) * (parts[0]["mesh"] as Mesh).get_aabb()
	var body := StaticBody3D.new()
	body.collision_layer = L_WORLD
	body.collision_mask = 0
	add_child(body)
	for c in cells:
		var p := _cell_pos(c.x, c.y)
		var yaw := rng.randf_range(-0.25, 0.25)
		var slab := Transform3D.IDENTITY.rotated(Vector3.UP, yaw)
		slab.origin = p + Vector3(0, 0.02, 0.4)
		slabs.append(slab)
		# Primero la escala y luego el giro: al revés el guijarro se cizalla.
		var stone := Transform3D(Basis(Vector3.UP, yaw) * Basis.from_scale(GRAVE_STONE), p + Vector3(0, 0, -0.9))
		stones.append(stone)
		if stone_box.size != Vector3.ZERO:
			var box := BoxShape3D.new()
			box.size = stone_box.size * GRAVE_STONE
			var cs := CollisionShape3D.new()
			cs.shape = box
			cs.transform = Transform3D(Basis(Vector3.UP, yaw), stone * stone_box.get_center())
			body.add_child(cs)
	_multimesh(NATURE + "RockPath_Square_Wide.gltf", slabs)
	_multimesh(stone_path, stones)
	print("cementerio: %d tumbas (las mismas que saca el juego)" % cells.size())


## Una caja por celda bloqueada. La colisión sigue siendo de rejilla, igual que en el juego:
## los árboles asoman sobre el pasillo pero no lo estrechan.
func _build_collision() -> void:
	var floor_body := StaticBody3D.new()
	var floor_cs := CollisionShape3D.new()
	var plane := WorldBoundaryShape3D.new()
	plane.plane = Plane(Vector3.UP, 0.0)
	floor_cs.shape = plane
	floor_body.add_child(floor_cs)
	add_child(floor_body)

	var body := StaticBody3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(CELL, WALL_H, CELL)
	var n := 0
	for x in mw:
		for y in mh:
			# Los peñascos de cobertura ya chocan con su propia envolvente: una caja de 3 m sería
			# una pared invisible alrededor de una roca de 2,6.
			if MapBuilder.walkable(grid[x][y]) or _cover_cells.has(Vector2i(x, y)):
				continue
			var cs := CollisionShape3D.new()
			cs.shape = box
			cs.position = _cell_pos(x, y) + Vector3(0, WALL_H * 0.5, 0)
			body.add_child(cs)
			n += 1
	# Valla perimetral: el mapa no tenía borde, solo un suelo infinito, así que cualquiera
	# (señuelos, esbirros, el propio jugador tras un intercambio) podía irse al vacío.
	var half_x := mw * CELL * 0.5
	var half_z := mh * CELL * 0.5
	var wall := BoxShape3D.new()
	wall.size = Vector3(mw * CELL + 8.0, WALL_H * 2.0, 4.0)
	for side in [Vector3(0, 0, -half_z - 2.0), Vector3(0, 0, half_z + 2.0)]:
		var cs2 := CollisionShape3D.new()
		cs2.shape = wall
		cs2.position = side + Vector3(0, WALL_H, 0)
		body.add_child(cs2)
	var wall2 := BoxShape3D.new()
	wall2.size = Vector3(4.0, WALL_H * 2.0, mh * CELL + 8.0)
	for side in [Vector3(-half_x - 2.0, 0, 0), Vector3(half_x + 2.0, 0, 0)]:
		var cs3 := CollisionShape3D.new()
		cs3.shape = wall2
		cs3.position = side + Vector3(0, WALL_H, 0)
		body.add_child(cs3)
	add_child(body)
	print("colisión: %d celdas bloqueadas + valla perimetral" % n)


# ---------------------------------------------------------------- carga de modelos

func _load_gltf(path: String) -> Node3D:
	if _gltf_cache.has(path):
		return _gltf_cache[path]
	var packed := load(path) as PackedScene
	if packed == null:
		push_error("no se pudo cargar %s" % path)
		return null
	var n := packed.instantiate() as Node3D
	_gltf_cache[path] = n
	return n


## Devuelve las mallas de un glTF con su transformada relativa a la raíz.
func _meshes_of(root: Node) -> Array:
	var out: Array = []
	_walk_meshes(root, Transform3D.IDENTITY, out)
	return out


func _walk_meshes(n: Node, t: Transform3D, out: Array) -> void:
	var xf := t
	if n is Node3D:
		xf = t * (n as Node3D).transform
	if n is MeshInstance3D and (n as MeshInstance3D).mesh != null:
		out.append({"mesh": (n as MeshInstance3D).mesh, "xform": xf, "node": n})
	for c in n.get_children():
		_walk_meshes(c, xf, out)


## Dibuja N copias de un modelo en una sola llamada por malla. Con 451 muros y ~580 adornos,
## instanciar escenas una a una sería inviable; así son ~25 draw calls en total.
func _multimesh(path: String, transforms: Array) -> void:
	if transforms.is_empty():
		return
	var scene := _load_gltf(path)
	if scene == null:
		return
	for entry in _meshes_of(scene):
		_fix_vertex_colors(entry["mesh"], entry["node"])
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = entry["mesh"]
		mm.instance_count = transforms.size()
		for i in transforms.size():
			mm.set_instance_transform(i, (transforms[i] as Transform3D) * (entry["xform"] as Transform3D))
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		add_child(mmi)
	_props += transforms.size()
	# En headless el renderizador de relleno no guarda las transformadas del MultiMesh: las sondas
	# (tests/rocks_probe.gd) leen de aquí dónde quedó cada copia.
	(_placed.get_or_add(path, []) as Array).append_array(transforms)


## Quaternius guarda datos de viento en COLOR_0. Godot los interpreta como color de albedo
## y las copas salen rojas; se desactiva para que valga la textura.
var _green_leaf: Texture2D = null

func _leaf_texture() -> Texture2D:
	# Con load() viaja dentro del PCK; Image.load_from_file lee del disco y en el APK no existe.
	if _green_leaf == null:
		_green_leaf = load(NATURE + "Leaves_NormalTree_C.png") as Texture2D
	return _green_leaf


func _fix_vertex_colors(mesh: Mesh, mi: MeshInstance3D) -> void:
	for i in mesh.get_surface_count():
		var mat := mi.get_surface_override_material(i)
		if mat == null:
			mat = mesh.surface_get_material(i)
		elif mesh is ArrayMesh:
			(mesh as ArrayMesh).surface_set_material(i, mat)   # que lo vea el MultiMesh
		if mat is BaseMaterial3D:
			var bm := mat as BaseMaterial3D
			if _dbg:
				print("  material %s  vcol=%s  albedo=%s  tex=%s" % [bm.resource_name,
					bm.vertex_color_use_as_albedo, bm.albedo_color,
					"sí" if bm.albedo_texture != null else "NO"])
			bm.vertex_color_use_as_albedo = false
			if bm.resource_name == "Leaves_TwistedTree":
				var t := _leaf_texture()
				if t != null:
					bm.albedo_texture = t
		elif _dbg:
			print("  superficie %d sin BaseMaterial3D: %s" % [i, mat])


## Carga un atuendo y le injerta las animaciones de la Universal Animation Library,
## exactamente como hace tools/sprite3d/render.gd para pre-renderizar las hojas.
## `passes` es una lista de [fichero_de_animaciones, "Nombre1,Nombre2"]. Los zombis necesitan dos:
## la locomoción zombi está en la librería 2 y la muerte solo en la 1 (igual que en batch.py).
func _make_character(models: Array, passes: Array = []) -> Dictionary:
	var model := Node3D.new()
	for spec in models:
		var path: String = spec["path"] if spec is Dictionary else spec
		var src := _load_gltf(path)
		if src == null:
			continue
		var layer := src.duplicate() as Node3D
		if spec is Dictionary and spec.has("cut"):
			for e in _meshes_of(layer):
				var mi: MeshInstance3D = e["node"]
				mi.mesh = _cut_above(e["mesh"], float(spec["cut"]))
		model.add_child(layer)
	if passes.is_empty():
		passes = [[UAL1, HERO_ANIMS], [UAL2, HERO_ANIMS_2]]
	var skels: Array = []
	_all_of_class(model, "Skeleton3D", skels)
	if skels.is_empty():
		push_error("no se pudo animar %s" % str(models))
		return {"node": model, "anims": []}
	# una capa = un esqueleto propio; se anima cada uno y se mueven en bloque
	var players: Array = []
	for skel in skels:
		var ap := AnimationPlayer.new()
		model.add_child(ap)
		ap.root_node = ap.get_path_to(model)
		var skel_path := String(model.get_path_to(skel))
		players.append(_fill_player(ap, skel_path, passes))
	return {"node": model, "anims": players}


func _fill_player(ap: AnimationPlayer, skel_path: String, passes: Array) -> AnimationPlayer:
	var lib := AnimationLibrary.new()
	for p in passes:
		var anims := _load_gltf(p[0])
		var src_ap := _find_class(anims, "AnimationPlayer") as AnimationPlayer
		if src_ap == null:
			continue
		var wanted := String(p[1]).split(",") if String(p[1]) != "" else PackedStringArray()
		for name in src_ap.get_animation_list():
			if wanted.size() > 0 and not wanted.has(name):
				continue
			var a: Animation = src_ap.get_animation(name).duplicate(true)
			for i in a.get_track_count():
				var tp := String(a.track_get_path(i))
				var colon := tp.find(":")
				if colon < 0:
					continue
				a.track_set_path(i, NodePath(skel_path + tp.substr(colon)))
			lib.add_animation(name, a)
	ap.add_animation_library("", lib)
	return ap


## Todas las capas de un personaje deben reproducir lo mismo o se descoserían.
func _play_all(anims: Array, name: String, at := -1.0) -> void:
	for ap in anims:
		if ap.has_animation(name):
			ap.play(name)
			if at >= 0.0:
				ap.seek(at, true)


func _anims_of(node: Node) -> Array:
	var out: Array = []
	_all_of_class(node, "AnimationPlayer", out)
	return out


## Recorta una malla quedándose con los triángulos por encima de `cut` (altura en la pose de
## reposo) y conserva huesos y pesos, así que la pieza sigue animándose. Es como se saca la
## CABEZA del cuerpo base: el pack no trae una malla de cabeza suelta, y apilar el cuerpo entero
## debajo de la ropa no la tapa, la atraviesa.
func _cut_above(src: Mesh, cut: float) -> ArrayMesh:
	var out := ArrayMesh.new()
	for si in src.get_surface_count():
		var a := src.surface_get_arrays(si)
		var verts: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
		var idx: PackedInt32Array = a[Mesh.ARRAY_INDEX]
		if _dbg:
			print("  sup %d: %d vértices, %d índices" % [si, verts.size(), idx.size()])
		if verts.is_empty() or idx.is_empty():
			continue
		var remap := {}
		var order: Array = []
		var keep := PackedInt32Array()
		var i := 0
		while i + 2 < idx.size():
			var v0 := idx[i]
			var v1 := idx[i + 1]
			var v2 := idx[i + 2]
			if verts[v0].y >= cut and verts[v1].y >= cut and verts[v2].y >= cut:
				for v in [v0, v1, v2]:
					if not remap.has(v):
						remap[v] = order.size()
						order.append(v)
					keep.append(remap[v])
			i += 3
		if _dbg:
			var lo := 1e9
			var hi := -1e9
			for v in verts:
				lo = minf(lo, v.y)
				hi = maxf(hi, v.y)
			print("  recorte sup %d: %d tris -> %d, y=[%.2f, %.2f], corte %.2f" % [
				si, idx.size() / 3, keep.size() / 3, lo, hi, cut])
		if keep.is_empty():
			continue
		var na := []
		na.resize(Mesh.ARRAY_MAX)
		for k in [Mesh.ARRAY_VERTEX, Mesh.ARRAY_NORMAL, Mesh.ARRAY_TANGENT, Mesh.ARRAY_COLOR,
				Mesh.ARRAY_TEX_UV, Mesh.ARRAY_TEX_UV2, Mesh.ARRAY_BONES, Mesh.ARRAY_WEIGHTS]:
			if a[k] != null:
				na[k] = _pick(a[k], order, verts.size())
		na[Mesh.ARRAY_INDEX] = keep
		out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, na)
		out.surface_set_material(out.get_surface_count() - 1, src.surface_get_material(si))
	return out


## Reordena un array de vértices (o de 4 valores por vértice, como huesos y pesos).
func _pick(arr, order: Array, n_verts: int):
	var stride: int = maxi(1, arr.size() / maxi(1, n_verts))
	var out = arr.duplicate()
	out.resize(order.size() * stride)
	for i in order.size():
		for k in stride:
			out[i * stride + k] = arr[order[i] * stride + k]
	return out


func _find_class(root: Node, cls: String) -> Node:
	if root.get_class() == cls:
		return root
	for c in root.get_children():
		var r := _find_class(c, cls)
		if r != null:
			return r
	return null


func _all_of_class(root: Node, cls: String, acc: Array) -> void:
	if root.get_class() == cls:
		acc.append(root)
	for c in root.get_children():
		_all_of_class(c, cls, acc)


# ---------------------------------------------------------------- personajes y cámara

## Tu leyenda y la cámara que la sigue. El cuerpo, el modelo y el estado de lanzador los crea el
## combate (Fighter); aquí solo va lo que es TUYO: la cámara en tercera persona.
func _spawn_player() -> void:
	var c := _spawn_cell()
	pf = combat.spawn_fighter(0, Fighter.TEAM_BLUE, true, _cell_pos(c.x, c.y) + Vector3(0, 0.2, 0))
	pivot = Node3D.new()
	add_child(pivot)
	spring = SpringArm3D.new()
	spring.spring_length = 5.0
	spring.margin = 0.3
	pivot.add_child(spring)
	cam = Camera3D.new()
	cam.fov = 70.0
	cam.current = true
	spring.add_child(cam)
	_apply_cam_mode()


## Cambia de leyenda en caliente (teclas 1-7, Tab, --legend).
func set_legend(i: int) -> void:
	combat.set_legend(pf, i)


## ¿Hay partida por equipos? (la Horda no lo es)
func is_pvp() -> bool:
	return team_mode != null


## Una leyenda ha caído. En la Horda solo cuenta para la racha (ya la pone a cero el combate);
## por equipos, marcador, insignias y registro de bajas.
func on_fighter_down(f: Fighter, by: Fighter) -> void:
	if team_mode != null:
		team_mode.on_fighter_down(f, by)


## Gas nuevo para otra ronda: vuelve al borde del mapa, espera otra vez y sortea hacia dónde cierra.
func reset_zone() -> void:
	if _zone_wall == null:
		return
	_zone_t = 0.0
	_zone_c = _zone_c0
	_zone_r = _zone_r0
	var margin := _zone_r0 - ZONE_MIN - 4.0
	var a := rng.randf() * TAU
	_zone_c1 = _zone_c0 + Vector3(cos(a), 0, sin(a)) * rng.randf() * maxf(margin, 0.0)
	_apply_zone()


## ¿Está el gas demoníaco en juego?
func zone_active() -> bool:
	return _zone_wall != null


## Qué se juega: `--mode=` manda; si no, lo que eligió el menú (Engine "fl_mode", sobrevive a
## recargar la escena); si no, en headless o con cualquier opción de prueba la Horda de siempre
## (así las sondas y capturas no cambian); y si no, el menú de inicio.
func _pick_mode() -> String:
	if _args.has("mode"):
		var m := String(_args["mode"])
		return m if GameModes.MODES.has(m) or m == "menu" else "horda"
	if Engine.has_meta("fl_mode"):
		var chosen := String(Engine.get_meta("fl_mode"))
		return chosen if GameModes.MODES.has(chosen) else "horda"
	if DisplayServer.get_name() == "headless" or not _args.is_empty():
		return "horda"
	return "menu"


## Menú de inicio sobre el mapa: tu leyenda escondida, la cámara dando vueltas alta y el menú encima.
func _setup_menu() -> void:
	if player_model != null:
		player_model.visible = false
	if pf.bar != null:
		pf.bar.visible = false
	if hud != null:
		hud.visible = false
	_cam_mode = 1
	_apply_cam_mode()
	spring.spring_length = 34.0
	_pitch = -0.55
	var layer := CanvasLayer.new()
	layer.layer = 30
	add_child(layer)
	var menu := ModeMenu.new()
	layer.add_child(menu)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


# Tu leyenda vista desde el control y el HUD táctil (touch_ui.gd lee estas).
func _abil(i: int) -> Dictionary:
	return pf.abil(i)


func _ability_range(i: int) -> float:
	return pf.ability_range(i)


func _ability_radius(i: int) -> float:
	return pf.ability_radius(i)


func _ability_ready(i: int) -> bool:
	return pf.ability_ready(i)


func swap_ready(i: int) -> bool:
	return combat.swap_ready(pf, i)


func cooldown_left(i: int) -> float:
	return pf.cooldown_left(i)


func cooldown_fraction(i: int) -> float:
	return pf.cooldown_fraction(i)


func cooldown_text(i: int) -> String:
	return pf.cooldown_text(i)


func reset_abilities() -> void:
	pf.reset_abilities()


## Tu lanzamiento: intercambio con el señuelo si toca, y si no, al punto que marque la mira (ratón)
## o al enemigo más cercano (toque sin arrastre).
func _try_cast(i: int, at := Vector3.INF) -> void:
	if combat.try_swap(pf, i):
		return
	if i == 0 and pf.ammo_max > 0 and pf.ammo <= 0 and team_mode != null:
		team_mode.dry_fire()
	if not pf.ability_ready(i):
		return
	if at == Vector3.INF:
		at = _auto_aim(i) if touch else _aim_point(pf.ability_range(i))
	combat.start_cast(pf, i, at)


## Celda de suelo de campo más cercana al centro del mapa.
func _spawn_cell() -> Vector2i:
	var best := Vector2i(mw / 2, mh / 2)
	var best_d := 1e9
	for x in mw:
		for y in mh:
			if not MapBuilder.walkable(grid[x][y]) or zones[x][y] != 0:
				continue
			var d := Vector2(x - mw * 0.5, y - mh * 0.5).length()
			if d < best_d:
				best_d = d
				best = Vector2i(x, y)
	return best


## Tres compañeros de pie junto al jugador: es "la sala" del juego, pero en 3D.
## Tinte de leyenda (el liche es un esqueleto teñido, como en el juego).
func _tint_model(model: Node3D, c: Color) -> void:
	if c == Color.WHITE:
		return
	for e in _meshes_of(model):
		var mi: MeshInstance3D = e["node"]
		var mesh: Mesh = e["mesh"]
		for i in mesh.get_surface_count():
			var base := mesh.surface_get_material(i)
			if base is BaseMaterial3D:
				var dup := (base as BaseMaterial3D).duplicate() as BaseMaterial3D
				dup.albedo_color = dup.albedo_color * c
				mi.set_surface_override_material(i, dup)


## Cambia de leyenda en caliente: rehace el modelo y aplica vida y velocidad.
## Rota entre las leyendas EN ROTACIÓN. Las retiradas quedan fuera; solo `set_legend` llega a ellas.
func switch_legend(delta_i: int) -> void:
	set_legend(wrapi(_legend + delta_i, 0, PLAYABLE))


func _spawn_companions() -> void:
	var c := _spawn_cell()
	var spots := [Vector3(3.0, 0, 1.5), Vector3(-3.0, 0, 1.5), Vector3(0, 0, 3.5)]
	# solo atuendos con capucha: Peasant no trae cabeza y saldría decapitado
	var outfits := [[OUTFITS + "Female_Ranger.gltf"],
		[OUTFITS + "Male_Ranger.gltf"],
		[OUTFITS + "Female_Ranger.gltf"]]
	for i in outfits.size():
		var made := _make_character(outfits[i])
		var n: Node3D = made.get("node")
		if n == null:
			continue
		n.position = _cell_pos(c.x, c.y) + spots[i]
		n.rotation.y = rng.randf() * TAU
		add_child(n)
		_play_all(made.get("anims", []), "Idle", rng.randf() * 2.0)   # que no respiren a la vez


## Música: tema de batalla en las oleadas normales y el del jefe cuando entra el Rompemareas.
## Se reencola al terminar en vez de usar el bucle del recurso, que depende del formato.
func _setup_music() -> void:
	music = AudioStreamPlayer.new()
	music.volume_db = -9.0
	add_child(music)
	music.finished.connect(func(): music.play())
	_play_music(false)


## Efectos de sonido con una pequeña reserva de reproductores, para que varios suenen a la vez.
func _sfx(name: String, vol := -6.0) -> void:
	if _sfx_pool.is_empty():
		for i in 8:
			var p := AudioStreamPlayer.new()
			add_child(p)
			_sfx_pool.append(p)
	if not _sfx_cache.has(name):
		var st: AudioStream = null
		for ext in [".wav", ".ogg"]:
			var path := "res://assets/audio/spells/%s%s" % [name, ext]
			if ResourceLoader.exists(path):
				st = load(path)
				break
		if st == null:
			st = load("res://assets/audio/sfx/impactPunch_heavy_001.ogg") if \
				ResourceLoader.exists("res://assets/audio/sfx/impactPunch_heavy_001.ogg") else null
		_sfx_cache[name] = st
	var stream: AudioStream = _sfx_cache[name]
	if stream == null:
		return
	var pl: AudioStreamPlayer = _sfx_pool[_sfx_next]
	_sfx_next = (_sfx_next + 1) % _sfx_pool.size()
	pl.stream = stream
	pl.volume_db = vol
	pl.pitch_scale = randf_range(0.94, 1.06)
	pl.play()


func _play_music(boss: bool) -> void:
	if music.playing and boss == _music_boss:
		return
	_music_boss = boss
	var path := "res://assets/audio/music/bossbattle_22k.wav" if boss \
		else "res://assets/audio/music/battleThemeA.mp3"
	var st := load(path)
	if st == null:
		return
	music.stream = st
	music.play()


# ---------------------------------------------------------------- táctil

func _setup_touch() -> void:
	if not touch:
		return
	var layer := CanvasLayer.new()
	layer.layer = 20
	add_child(layer)
	touch_ui = Control.new()
	touch_ui.set_script(load("res://touch_ui.gd"))
	touch_ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	touch_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	touch_ui.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR   # los SVG se reescalan suaves
	touch_ui.main = self
	layer.add_child(touch_ui)


## Posición fija del joystick, igual que en el juego (no aparece donde tocas).
func joy_center() -> Vector2:
	return Vector2(190.0, get_viewport().get_visible_rect().size.y - 250.0)


## Misma distribución que touch_controls._layout(): básica grande abajo a la derecha,
## táctica a su izquierda y definitiva arriba.
func button_rects() -> Array:
	var v := get_viewport().get_visible_rect().size
	var main_c := Vector2(v.x - 100.0, v.y - 110.0)
	return [
		{"idx": 0, "c": main_c, "r": MAIN_SIDE / 2.0, "name": String(_abil(0)["n"])},
		{"idx": 1, "c": main_c + Vector2(-170.0, 20.0), "r": ABILITY_SIDE / 2.0, "name": String(_abil(1)["n"])},
		{"idx": 2, "c": main_c + Vector2(-60.0, -165.0), "r": ABILITY_SIDE / 2.0, "name": String(_abil(2)["n"])},
	]


## Segundos que faltan, para el número del centro del botón.
func button_center(idx: int) -> Vector2:
	for b in button_rects():
		if b["idx"] == idx:
			return b["c"]
	return Vector2.ZERO


func _button_at(p: Vector2) -> int:
	for b in button_rects():
		if p.distance_to(b["c"]) <= b["r"] + 12.0:
			return b["idx"]
	return -1


func _input(e: InputEvent) -> void:
	if not touch or touch_ui == null:
		return
	if team_mode != null and team_mode.rules.state != "playing":
		return
	if e is InputEventScreenTouch:
		var t := e as InputEventScreenTouch
		if t.pressed:
			var b := _button_at(t.position)
			if b >= 0:
				_aim_btn = b
				_aim_idx = t.index          # el dedo que manda esta habilidad
				_aim_drag = Vector2.ZERO
				_preview = b
			elif t.position.distance_to(joy_center()) <= JOY_RADIUS * JOY_GRAB:
				_joy_idx = t.index
				_joy_origin = joy_center()
				_joy_vec = _joy_from(t.position)
			else:
				_look_idx = t.index
		else:
			# Cada dedo suelta LO SUYO: antes cualquier dedo levantado disparaba la habilidad,
			# así que soltar el joystick la lanzaba y soltar el botón ya no hacía nada.
			if t.index == _aim_idx:
				_aim_idx = -1
				_release_aim()
			if t.index == _joy_idx:
				_joy_idx = -1
				_joy_vec = Vector2.ZERO
			if t.index == _look_idx:
				_look_idx = -1
		touch_ui.queue_redraw()
	elif e is InputEventScreenDrag:
		var d := e as InputEventScreenDrag
		if d.index == _aim_idx and _aim_btn >= 0:
			_aim_drag = d.position - button_center(_aim_btn)
		elif d.index == _joy_idx:
			_joy_vec = _joy_from(d.position)
		elif d.index == _look_idx:
			_yaw -= d.relative.x * 0.006
			_pitch = clampf(_pitch - d.relative.y * 0.005, -1.35, 0.35)
		touch_ui.queue_redraw()


## Vector del joystick a partir de dónde está el dedo, con la zona muerta del juego.
func _joy_from(p: Vector2) -> Vector2:
	var v := (p - joy_center()) / JOY_RADIUS
	if v.length() < DEAD_ZONE:
		return Vector2.ZERO
	return v.limit_length(1.0)


## Soltar el botón: si apenas se arrastró es un toque (apuntado automático); si se arrastró,
## la dirección y la distancia del arrastre mandan, como el apuntado táctil del juego.
func _release_aim() -> void:
	var idx := _aim_btn
	_aim_btn = -1
	_preview = -1
	if idx < 0:
		return
	if _aim_drag.length() <= AIM_DEAD:
		_try_cast(idx)
		return
	var rng_m := _ability_range(idx)
	var f := clampf(_aim_drag.length() / AIM_RADIUS, 0.0, 1.0)
	var basis := cam.global_transform.basis
	var fwd := Vector3(-basis.z.x, 0, -basis.z.z).normalized()
	var right := Vector3(basis.x.x, 0, basis.x.z).normalized()
	var dir := (right * _aim_drag.x - fwd * _aim_drag.y).normalized()
	var at := player.global_position + dir * (rng_m * f)
	at.y = 0.0
	_try_cast(idx, at)


# ---------------------------------------------------------------- poderes

func _build_aim() -> void:
	_aim_ring = vfx.ring(5.0, SPARK, 0.55)
	_aim_ring.visible = false
	add_child(_aim_ring)
	_aim_dot = vfx.ring(0.22, SPARK, 0.9)
	add_child(_aim_dot)


## Dónde apunta la mira: rayo desde el centro de la pantalla al plano del suelo, recortado
## al alcance de la habilidad. En 3ª persona esto sustituye al ratón sobre el mapa isométrico.
func _aim_point(max_range: float) -> Vector3:
	var origin := cam.global_position
	var dir := -cam.global_transform.basis.z
	var p := player.global_position
	if dir.y < -0.01:
		p = origin + dir * (-origin.y / dir.y)
	else:
		p = player.global_position + Vector3(dir.x, 0, dir.z).normalized() * max_range
	p.y = 0.0
	var from := player.global_position
	from.y = 0.0
	var off := p - from
	if off.length() > max_range:
		p = from + off.normalized() * max_range
	return p


## El punto que marcaría el arrastre actual, para pintar el anillo antes de soltar.
func _aim_point_touch(idx: int) -> Vector3:
	if _aim_drag.length() <= AIM_DEAD:
		return _auto_aim(idx)
	var f := clampf(_aim_drag.length() / AIM_RADIUS, 0.0, 1.0)
	var basis := cam.global_transform.basis
	var fwd := Vector3(-basis.z.x, 0, -basis.z.z).normalized()
	var right := Vector3(basis.x.x, 0, basis.x.z).normalized()
	var dir := (right * _aim_drag.x - fwd * _aim_drag.y).normalized()
	var at := player.global_position + dir * (_ability_range(idx) * f)
	at.y = 0.0
	return at


## Toque sin arrastre: al enemigo más cercano dentro del alcance; si no, al frente.
func _auto_aim(i: int) -> Vector3:
	var rng_m := _ability_range(i)
	var near := combat.foes_in(pf.team, player.global_position, rng_m, 1, true)
	if not near.is_empty():
		var p: Vector3 = near[0]["node"].global_position
		p.y = 0.0
		return p
	var f := Vector3(sin(player_model.rotation.y), 0, cos(player_model.rotation.y))
	return player.global_position + f * rng_m * 0.7


## A quién persigue un enemigo: al aliado más cercano si lo tiene a tiro, si no al jugador.
## Devuelve el propio aliado (o null si es el jugador) para poder morderlo.
func _enemy_prey(from: Vector3) -> Dictionary:
	var best_d := from.distance_to(player.global_position) if not player_hidden() else 1e9
	var prey: Dictionary = {}
	for al in combat.allies:
		var d: float = from.distance_to((al["node"] as Node3D).global_position)
		if d < best_d and d < 14.0:
			best_d = d
			prey = al
	return prey


## Nadie puede apuntarte: por la invisibilidad del Ilusionista, o porque estás AGACHADO dentro de
## una mancha de hierba alta. Atacar te delata unos segundos (`_spotted_t`), así que el camuflaje
## sirve para colarte o escapar, no para disparar desde la maleza sin consecuencias.
func player_hidden() -> bool:
	return combat.is_hidden(pf)


## ¿Este punto cae en una mancha de hierba alta?
func in_tall_grass(at: Vector3) -> bool:
	if tall_grass.is_empty():
		return false
	var c := _cell_of(at)
	return _in_map(c) and tall_grass[c.x][c.y]


func _enemy_target(from: Vector3) -> Vector3:
	var prey := _enemy_prey(from)
	if not prey.is_empty():
		return (prey["node"] as Node3D).global_position
	# Escondido: siguen yendo al último sitio donde te vieron, no a donde estás. Sin esto la
	# invisibilidad no servía de nada cuando ibas solo: te seguían igual.
	return pf.last_seen if player_hidden() else player.global_position


# -- ciclo día/noche -------------------------------------------------

## Cuánta noche hay (0 = mediodía, 1 = noche cerrada), con las cuatro fases del juego y
## transiciones suavizadas. Es solo visual: no cambia nada de la simulación.
func _night_amount(t: float) -> float:
	var k := _cycle / DAY_CYCLE
	t = fposmod(t, _cycle)
	if t < DAY_TIME * k:
		return 0.0
	t -= DAY_TIME * k
	if t < DUSK_TIME * k:
		return smoothstep(0.0, 1.0, t / (DUSK_TIME * k))
	t -= DUSK_TIME * k
	if t < NIGHT_TIME * k:
		return 1.0
	t -= NIGHT_TIME * k
	return 1.0 - smoothstep(0.0, 1.0, t / (DAWN_TIME * k))


func _tick_daylight(delta: float) -> void:
	if sun == null:
		return
	_day_t += delta
	var n := _night_amount(_day_t)
	sun.light_color = DAY_COLOR.lerp(NIGHT_COLOR, n)
	for f: Fighter in combat.fighters:
		if f.torch != null:
			f.torch.light_energy = n * 2.2    # la antorcha se aviva al anochecer
	sun.light_energy = lerpf(1.0, 0.30, n)
	# Las brasas son para la noche: a pleno sol su luz no aportaba nada y teñía de naranja los
	# huesos de todos los esqueletos del claro. Se actualizan por tramos, no cada fotograma.
	if absf(n - _brasas_n) > 0.02:
		_brasas_n = n
		for node in get_tree().get_nodes_in_group("brasas"):
			var ol := node as OmniLight3D
			if ol != null:
				ol.light_energy = float(ol.get_meta("base", 0.9)) * (0.10 + 0.90 * n)
	if world_env != null:
		world_env.ambient_light_energy = lerpf(0.4, 0.26, n)
		world_env.ambient_light_color = Color(0.42, 0.47, 0.55).lerp(Color(0.26, 0.31, 0.52), n)
		world_env.fog_light_color = Color(0.70, 0.78, 0.85).lerp(Color(0.10, 0.13, 0.26), n)
		var sky := world_env.sky.sky_material as ProceduralSkyMaterial
		if sky != null:
			sky.sky_top_color = Color(0.30, 0.50, 0.80).lerp(Color(0.05, 0.07, 0.20), n)
			sky.sky_horizon_color = Color(0.72, 0.80, 0.86).lerp(Color(0.16, 0.20, 0.38), n)
			sky.ground_horizon_color = sky.sky_horizon_color
			sky.ground_bottom_color = Color(0.30, 0.33, 0.28).lerp(Color(0.05, 0.06, 0.12), n)


# -- barras de vida --------------------------------------------------

## Altura de lo que se dibuja, medida de las mallas. Es lo que decide dónde cuelga la barra: con
## un valor fijo para todas las leyendas, al Rompemareas (2,63 m con el ancla en alto) le quedaba
## cruzada por la cara. Se mide en el espacio del modelo, así que hay que multiplicar por su escala.
func _model_top(model: Node3D) -> float:
	var top := 0.0
	for e in _meshes_of(model):
		var mi: MeshInstance3D = e["node"]
		var t := Transform3D.IDENTITY
		var n: Node = mi
		while n != null and n != model:
			if n is Node3D:
				t = (n as Node3D).transform * t
			n = n.get_parent()
		var box: AABB = t * mi.get_aabb()
		top = maxf(top, box.position.y + box.size.y)
	return top


## Barra flotante: fondo oscuro + relleno que se encoge desde la izquierda. Sin prueba de
## profundidad, para que se lea aunque la tape la hierba.
func _make_bar(parent: Node3D, height: float, col: Color, scale := 1.0) -> Node3D:
	var root := Node3D.new()
	root.position = Vector3(0, height, 0)
	var w := BAR_W * scale
	var h := BAR_H * scale
	for i in 2:
		var q := QuadMesh.new()
		q.size = Vector2(w, h)
		var mi := MeshInstance3D.new()
		mi.mesh = q
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		# SIN esto la barra no se vacía nunca. El billboard rehace la base de la matriz para
		# encarar la cámara y en el camino se come la ESCALA del nodo: el `fill.scale.x` de
		# _set_bar se perdía y solo quedaba el desplazamiento, así que el relleno no menguaba,
		# se corría a la izquierda y asomaba el fondo por la derecha. Se moría con la barra llena.
		m.billboard_keep_scale = true
		m.no_depth_test = true
		m.render_priority = 8 + i
		m.albedo_color = Color(0.06, 0.06, 0.08, 0.75) if i == 0 else col
		mi.material_override = m
		if i == 1:
			mi.name = "Fill"
			mi.position.z = 0.01
		root.add_child(mi)
	parent.add_child(root)
	return root


## Ajusta el relleno: se encoge por la derecha manteniendo el borde izquierdo fijo.
func _set_bar(bar: Node3D, frac: float, scale := 1.0) -> void:
	if bar == null or not is_instance_valid(bar):
		return
	var fill := bar.get_node_or_null("Fill") as MeshInstance3D
	if fill == null:
		return
	var f := clampf(frac, 0.0, 1.0)
	var w := BAR_W * scale
	fill.scale.x = maxf(f, 0.001)
	fill.position.x = -w * 0.5 + w * f * 0.5


## Solo para pruebas headless: lanza lo que esté listo hacia el enemigo más cercano.
func _auto_cast() -> void:
	if pf.dash_left > 0.0:
		return              # durante la embestida no se lanza nada (si no, pisa su animación)
	var near := combat.foes_in(pf.team, player.global_position, 30.0, 1, true)
	if near.is_empty() or player_model == null:
		return
	var to: Vector3 = near[0]["node"].global_position - player.global_position
	to.y = 0.0
	if to.length() > 0.1:
		player_model.rotation.y = atan2(to.x, to.z)
	for idx in [2, 1, 0]:
		if _ability_ready(idx):
			var at := player.global_position + to.normalized() * minf(to.length(), _ability_range(idx))
			_try_cast(idx, at)
			return


## Alfa de las dos capas de la barra. El fondo va más tenue que el relleno, como al crearla.
func _fade_bar(bar: Node3D, a: float) -> void:
	for child in bar.get_children():
		var mi := child as MeshInstance3D
		if mi == null:
			continue
		var m := mi.material_override as StandardMaterial3D
		if m == null:
			continue
		var c := m.albedo_color
		m.albedo_color = Color(c.r, c.g, c.b, (0.75 if mi.name != "Fill" else 1.0) * a)


# ---------------------------------------------------------------- horda

func _setup_horde() -> void:
	_spawn_cells = MapBuilder.edge_cells(_mb_grid)
	_grave_cells = MapBuilder.cemetery_graves(_mb_grid, _mb_zones, MAP_SEED)
	_rebuild_flow(_cell_of(player.global_position))
	_wave = int(_args.get("wave", "2" if touch else "1")) - 1
	if touch and not _args.has("near"):
		_spawn_cells = _cells_around(_cell_of(player.global_position), 9)
	_start_wave()
	print("horda lista: %d celdas de borde, %d tumbas" % [_spawn_cells.size(), _grave_cells.size()])


func _start_wave() -> void:
	_wave += 1
	_left_to_spawn = 6 + _wave * 4
	_break_t = 0.0
	if _wave % BOSS_WAVE == 0:
		_spawn_boss()
		print("oleada %d: %d esqueletos + JEFE Rompemareas" % [_wave, _left_to_spawn])
	else:
		print("oleada %d: %d criaturas" % [_wave, _left_to_spawn])


## El jefe de la oleada: un Rompemareas con vida y daño multiplicados.
func _spawn_boss() -> void:
	if _spawn_cells.is_empty():
		return
	if _boss_proto == null:
		_boss_proto = _make_character([CHARS + "Tidebreaker.glb"],
			[[UAL1, ZOMBIE_ANIMS_1], [UAL2, ZOMBIE_ANIMS_2]]).get("node")
		if _boss_proto == null:
			return
	var c: Vector2i = _spawn_cells[rng.randi() % _spawn_cells.size()]
	var model := _boss_proto.duplicate() as Node3D
	var body := CharacterBody3D.new()
	body.collision_layer = L_CREATURE
	body.collision_mask = L_WORLD | L_CREATURE
	body.position = _cell_pos(c.x, c.y) + Vector3(0, 0.3, 0)
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.9
	cap.height = 2.4
	cs.shape = cap
	cs.position = Vector3(0, 1.2, 0)
	body.add_child(cs)
	body.add_child(model)
	add_child(body)
	var lbl := Label3D.new()
	lbl.text = "ROMPEMAREAS"
	lbl.font_size = 80
	lbl.pixel_size = 0.0028
	lbl.position = Vector3(0, 3.0, 0)
	lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lbl.outline_size = 22
	lbl.modulate = Color(1.0, 0.55, 0.35)
	body.add_child(lbl)
	var anims := _anims_of(model)
	_play_all(anims, "Zombie_Walk_Fwd")
	_add_eyes(model, Color(1.0, 0.25, 0.08))
	var bbar := _make_bar(body, 3.4, BAR_ENEMY, 2.2)
	zombies.append({"node": body, "kind": "zombie", "team": Fighter.TEAM_HORDE, "anims": anims, "bar": bbar,
		"hpmax": ZOMBIE_HP * BOSS_HP_MULT, "hp": ZOMBIE_HP * BOSS_HP_MULT,
		"swing_t": 0.0, "dead_t": -1.0, "stun_t": 0.0, "boss": true, "bscale": 2.2})
	_boss_alive = true


func _cell_of(p: Vector3) -> Vector2i:
	return Vector2i(int(round(p.x / CELL + mw * 0.5)), int(round(p.z / CELL + mh * 0.5)))


func _in_map(c: Vector2i) -> bool:
	return c.x >= 0 and c.x < mw and c.y >= 0 and c.y < mh


## Campo de flujo por BFS desde el jugador: cada celda guarda la siguiente hacia él. Es lo que
## permite que 40 zombis recorran los pasillos sin una malla de navegación ni una ruta por bicho.
func _rebuild_flow(goal: Vector2i) -> void:
	_flow = []
	for x in mw:
		var col := []
		col.resize(mh)
		col.fill(Vector2i(-1, -1))
		_flow.append(col)
	if not _in_map(goal) or not MapBuilder.walkable(grid[goal.x][goal.y]):
		return
	var q: Array[Vector2i] = [goal]
	_flow[goal.x][goal.y] = goal
	var head := 0
	var dirs := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
		Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1)]
	while head < q.size():
		var c: Vector2i = q[head]
		head += 1
		for d in dirs:
			var n: Vector2i = c + d
			if not _in_map(n) or _flow[n.x][n.y].x != -1:
				continue
			if not MapBuilder.walkable(grid[n.x][n.y]):
				continue
			# en diagonal, no cortar esquinas por dentro de un muro
			if d.x != 0 and d.y != 0:
				if not MapBuilder.walkable(grid[c.x + d.x][c.y]) or not MapBuilder.walkable(grid[c.x][c.y + d.y]):
					continue
			_flow[n.x][n.y] = c
			q.append(n)


## Sale por los bordes del mapa o de una tumba, como en la Horda del juego.
func _spawn_zombie(at := Vector3.INF) -> void:
	var placed := at != Vector3.INF     # sitio fijo: lo usan las dianas de prueba
	if zombies.size() >= MAX_ALIVE or (not placed and _spawn_cells.is_empty()):
		return
	var from_grave := not placed and not _grave_cells.is_empty() and rng.randf() < 0.3
	var c := Vector2i.ZERO
	if not placed:
		c = _grave_cells[rng.randi() % _grave_cells.size()] if from_grave \
			else _spawn_cells[rng.randi() % _spawn_cells.size()]
	# De una tumba solo sale lo que tiene sentido que estuviera enterrado.
	var sp := _pick_species(from_grave)
	var proto := _proto_of(sp)
	if proto == null:
		return
	var model := proto.duplicate() as Node3D
	if model == null:
		return
	var body := CharacterBody3D.new()
	body.collision_layer = L_CREATURE
	body.collision_mask = L_WORLD | L_CREATURE
	# De una tumba brota sobre la losa, delante de la lápida (que está a -0,9 y ahora choca): con el
	# reparto de ±0,8 de siempre algunas nacían dentro de la piedra.
	var jitter := Vector3(rng.randf_range(-0.6, 0.6), 0.2, rng.randf_range(0.1, 1.1)) if from_grave \
		else Vector3(rng.randf_range(-0.8, 0.8), 0.2, rng.randf_range(-0.8, 0.8))
	body.position = at + Vector3(0, 0.2, 0) if placed else _cell_pos(c.x, c.y) + jitter
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = float(sp["rad"])
	cap.height = float(sp["cap"])
	cs.shape = cap
	cs.position = Vector3(0, float(sp["cap"]) * 0.5, 0)
	body.add_child(cs)
	body.add_child(model)
	add_child(body)
	var anims := _anims_of(model)
	_play_all(anims, "Zombie_Walk_Fwd", rng.randf() * 1.5)
	if float(sp["eyes"]) > 0.0:
		_add_eyes(model, sp["eye_col"], float(sp["eyes"]))
	var bar := _make_bar(body, float(sp["bar"]), BAR_ENEMY, float(sp["bscale"]))
	bar.visible = false        # solo se asoma al recibir un golpe (petición del usuario)
	var hpmax := ZOMBIE_HP * float(sp["hp"])
	zombies.append({"node": body, "kind": "zombie", "team": Fighter.TEAM_HORDE, "anims": anims, "bar": bar, "hpmax": hpmax, "hp": hpmax,
		"swing_t": 0.0, "dead_t": -1.0, "stun_t": 0.0, "sp": sp["id"],
		"spd": float(sp["spd"]), "dmg": float(sp["dmg"]), "reach": float(sp["reach"]),
		"bscale": float(sp["bscale"]), "cap": float(sp["cap"])})
	_spawned[sp["id"]] = int(_spawned.get(sp["id"], 0)) + 1


## Sorteo por pesos, con dos filtros: de una tumba solo sale lo que tiene sentido que
## estuviera enterrado (un licántropo saliendo de una lápida no se sostiene) y las élites
## esperan a su oleada.
func _pick_species(from_grave := false) -> Dictionary:
	var pool: Array = []
	var total := 0
	for sp in SPECIES:
		if from_grave and not bool(sp["grave"]):
			continue
		if _wave < int(sp["minw"]):
			continue          # las élites no salen en las primeras oleadas
		pool.append(sp)
		total += int(sp["w"])
	if pool.is_empty():
		return SPECIES[0]
	var r := rng.randi() % total
	for sp in pool:
		r -= int(sp["w"])
		if r < 0:
			return sp
	return pool[0]


## Un modelo por especie, del que se duplican todos los demás: montar el esqueleto e injertar
## las animaciones cuesta ~40 ms y con un goteo de medio segundo se notaría.
func _proto_of(sp: Dictionary) -> Node3D:
	var id: String = sp["id"]
	if _species_proto.has(id):
		return _species_proto[id]
	var passes := [[UAL1, ZOMBIE_ANIMS_1], [UAL2, ZOMBIE_ANIMS_2]]
	var n: Node3D = _make_character([BESTIARY + String(sp["model"])], passes).get("node")
	_species_proto[id] = n
	if id == "esqueleto":
		_zombie_proto = n
	return n


## Tinte verdoso por override de superficie: si se tocara el material de la malla se teñiría
## también el campesino compañero, que comparte modelo.
## Un tramo de cilindro de `a` a `b`. CylinderMesh nace orientado en Y, así que hay que
## construirle la base a mano: look_at alinea -Z y dejaría el tubo atravesado.
func _segment(a: Vector3, b: Vector3, radius: float, mat: Material) -> MeshInstance3D:
	var m := CylinderMesh.new()
	m.top_radius = radius
	m.bottom_radius = radius
	m.height = maxf(a.distance_to(b), 0.001)
	m.radial_segments = 5
	m.rings = 1
	var mi := MeshInstance3D.new()
	mi.mesh = m
	mi.material_override = mat
	var dir := b - a
	if dir.length() < 0.0001:
		dir = Vector3.UP
	var y := dir.normalized()
	var ref := Vector3.RIGHT if absf(y.dot(Vector3.RIGHT)) < 0.9 else Vector3.FORWARD
	var x := ref.cross(y).normalized()
	var z := x.cross(y).normalized()
	mi.transform = Transform3D(Basis(x, y, z), (a + b) * 0.5)
	return mi


## Arco de madera construido con geometría. El pack de atuendos de Quaternius trae 24 piezas y
## NINGUNA es un arma (lo mismo le pasa al juego 2D, está anotado en su CLAUDE.md), así que un
## arquero sin arco no tenía arreglo con lo que hay: o se construye o no existe. Nueve tramos
## siguiendo un arco más la cuerda, colgados del hueso de la mano izquierda.
func _make_bow() -> Node3D:
	var root := Node3D.new()
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color(0.30, 0.19, 0.10)
	wood.roughness = 0.85
	var cord := StandardMaterial3D.new()
	cord.albedo_color = Color(0.88, 0.85, 0.74)
	cord.roughness = 1.0
	var segs := 9
	var half := deg_to_rad(64.0)
	var r := 0.42
	var pts: Array[Vector3] = []
	for i in segs + 1:
		var a := lerpf(-half, half, float(i) / float(segs))
		pts.append(Vector3(0.0, sin(a) * r, cos(a) * r - r * cos(half)))
	for i in segs:
		# las puntas más finas que el centro, como un arco de verdad
		var t := absf(float(i) - (segs - 1) * 0.5) / float(segs)
		root.add_child(_segment(pts[i], pts[i + 1], 0.018 - t * 0.014, wood))
	root.add_child(_segment(pts[0], pts[segs], 0.004, cord))
	return root


## Espada: hoja, gavilanes y empuñadura. Tres cajas bien puestas se leen como una espada a la
## distancia a la que se juega, y no hay que pedir arte de fuera.
func _make_sword() -> Node3D:
	var root := Node3D.new()
	var steel := StandardMaterial3D.new()
	# Mate y de albedo cálido a propósito. El entorno toma la luz ambiental del CIELO, que es
	# azul, y cualquier gris liso y pulido la refleja: con metallic 0,8 la espada salía azul
	# eléctrica, y aun a 0,25 seguía azulada. Sin metal y con mucha rugosidad se ve acero.
	steel.albedo_color = Color(0.82, 0.79, 0.71)
	steel.metallic = 0.0
	steel.roughness = 0.85
	var grip := StandardMaterial3D.new()
	grip.albedo_color = Color(0.25, 0.16, 0.10)
	var blade := BoxMesh.new()
	blade.size = Vector3(0.075, 0.82, 0.022)
	var bi := MeshInstance3D.new()
	bi.mesh = blade
	bi.material_override = steel
	bi.position = Vector3(0, 0.55, 0)
	root.add_child(bi)
	var cross := BoxMesh.new()
	cross.size = Vector3(0.30, 0.045, 0.045)
	var ci := MeshInstance3D.new()
	ci.mesh = cross
	ci.material_override = steel
	ci.position = Vector3(0, 0.14, 0)
	root.add_child(ci)
	var hilt := BoxMesh.new()
	hilt.size = Vector3(0.05, 0.22, 0.05)
	var hi := MeshInstance3D.new()
	hi.mesh = hilt
	hi.material_override = grip
	root.add_child(hi)
	return root


## Mazo del Cíclope: un tronco con una cabeza de piedra. OJO: cuelga de un hueso del modelo, así
## que hereda su escala x2,6. Se dibuja a 0,5 m para que en pantalla mida 1,3 m; a tamaño humano
## salía un mazo de 2,2 m, casi tan alto como el propio gigante.
func _make_club() -> Node3D:
	var root := Node3D.new()
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color(0.34, 0.22, 0.13)
	wood.roughness = 0.95
	var stone := StandardMaterial3D.new()
	stone.albedo_color = Color(0.46, 0.43, 0.38)   # cálida, o el cielo la pinta de azul
	stone.roughness = 1.0
	var shaft := CylinderMesh.new()
	shaft.top_radius = 0.028
	shaft.bottom_radius = 0.034
	shaft.height = 0.50
	shaft.radial_segments = 7
	var si := MeshInstance3D.new()
	si.mesh = shaft
	si.material_override = wood
	si.position = Vector3(0, 0.22, 0)
	root.add_child(si)
	var head := BoxMesh.new()
	head.size = Vector3(0.15, 0.18, 0.15)
	var hi := MeshInstance3D.new()
	hi.mesh = head
	hi.material_override = stone
	hi.position = Vector3(0, 0.52, 0)
	root.add_child(hi)
	return root


## Ancla encadenada: caña, cepo, dos uñas y la argolla. Es lo que el Rompemareas lanza de verdad
## (su modelo lleva un ancla, no un arpón), y hasta ahora salía disparada una bola de luz como la
## de todos los demás proyectiles — de ahí que no se entendiera qué tiraba.
func _make_anchor() -> Node3D:
	var root := Node3D.new()
	var iron := StandardMaterial3D.new()
	iron.albedo_color = Color(0.40, 0.38, 0.34)   # cálida: un gris liso refleja el cielo y sale azul
	iron.metallic = 0.0
	iron.roughness = 0.8
	root.add_child(_segment(Vector3(0, -0.34, 0), Vector3(0, 0.34, 0), 0.045, iron))   # caña
	root.add_child(_segment(Vector3(-0.26, 0.24, 0), Vector3(0.26, 0.24, 0), 0.032, iron))  # cepo
	for sgn in [-1.0, 1.0]:
		root.add_child(_segment(Vector3(0, -0.28, 0), Vector3(0.26 * sgn, -0.40, 0), 0.036, iron))
		root.add_child(_segment(Vector3(0.26 * sgn, -0.40, 0), Vector3(0.33 * sgn, -0.18, 0), 0.030, iron))
	var ring := TorusMesh.new()
	ring.inner_radius = 0.05
	ring.outer_radius = 0.09
	ring.rings = 8
	ring.ring_segments = 6
	var ri := MeshInstance3D.new()
	ri.mesh = ring
	ri.material_override = iron
	ri.position = Vector3(0, 0.40, 0)
	ri.rotation_degrees = Vector3(90, 0, 0)
	root.add_child(ri)
	return root


## Cuelga un arma del hueso de la mano. El pack de atuendos de Quaternius trae 24 piezas de ropa
## y NINGUN arma (el juego 2D lo tiene anotado igual), así que todo lo que lleven en la mano las
## leyendas humanas hay que construirlo. El arco va en la izquierda, que es la que lo sujeta;
## espada y mazo en la derecha.
func _attach_weapon(model: Node3D, kind: String) -> void:
	if kind == "":
		return
	var skels: Array = []
	_all_of_class(model, "Skeleton3D", skels)
	if skels.is_empty():
		return
	var skel: Skeleton3D = skels[0]
	var bone := "hand_l" if kind == "bow" else "hand_r"
	var idx := skel.find_bone(bone)
	if idx < 0:
		idx = skel.find_bone(bone.to_upper())
	if idx < 0:
		return
	var att := BoneAttachment3D.new()
	att.bone_name = skel.get_bone_name(idx)
	skel.add_child(att)
	var w: Node3D = null
	match kind:
		"bow": w = _make_bow()
		"sword": w = _make_sword()
		"club": w = _make_club()
	if w == null:
		return
	w.position = WEAPON_POS
	w.rotation_degrees = WEAPON_ROT
	att.add_child(w)


## Dos brasas en las cuencas. Van colgadas del hueso de la cabeza, así que siguen la animación.
## De noche son lo único que delata a un esqueleto a distancia.
func _add_eyes(model: Node3D, col := EYE_COL, sc := 1.0) -> void:
	var skels: Array = []
	_all_of_class(model, "Skeleton3D", skels)
	if skels.is_empty():
		return
	var skel: Skeleton3D = skels[0]
	var idx := skel.find_bone("head")
	if idx < 0:
		idx = skel.find_bone("Head")
	if idx < 0:
		return
	var att := BoneAttachment3D.new()
	att.bone_name = skel.get_bone_name(idx)
	skel.add_child(att)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = col
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	for sgn in [-1.0, 1.0]:
		var sph := SphereMesh.new()
		sph.radius = 0.035 * sc
		sph.height = 0.07 * sc
		sph.radial_segments = 6
		sph.rings = 4
		var mi := MeshInstance3D.new()
		mi.mesh = sph
		mi.material_override = mat
		mi.position = Vector3(0.045 * sgn * sc, 0.05 * sc, 0.10 * sc)
		att.add_child(mi)
	var l := OmniLight3D.new()
	l.light_color = col
	# Nace ya con el brillo que toca a esta hora: si no, cada bicho que sale de día llega a tope
	# y se queda así, porque _tick_daylight solo repasa el grupo cuando cambia la luz.
	var base := 0.9 * sc           # unas brasas pequeñas no alumbran como unas grandes
	l.light_energy = base * (0.10 + 0.90 * _night_amount(_day_t))
	l.set_meta("base", base)
	l.add_to_group("brasas")       # _tick_daylight las sube al anochecer y las baja de día
	l.omni_range = 2.2 * sc
	l.position = Vector3(0, 0.05 * sc, 0.15 * sc)
	att.add_child(l)


func _tick_horde(delta: float) -> void:
	if music != null:
		_play_music(_boss_alive)
	_flow_t -= delta
	if _flow_t <= 0.0:
		_flow_t = FLOW_EVERY
		_rebuild_flow(_cell_of(player.global_position))

	# goteo de aparición y cambio de oleada
	if _left_to_spawn > 0:
		_spawn_t -= delta
		if _spawn_t <= 0.0:
			_spawn_t = SPAWN_EVERY
			var t0 := Time.get_ticks_usec()
			_spawn_zombie()
			var ms := (Time.get_ticks_usec() - t0) / 1000.0
			if _args.has("bench"):
				print("   spawn: %.1f ms" % ms)
			_left_to_spawn -= 1
	elif zombies.is_empty():
		_break_t += delta
		if _break_t >= WAVE_BREAK:
			_start_wave()

	var ppos := player.global_position
	var alive := _php > 0.0
	for i in range(zombies.size() - 1, -1, -1):
		var z: Dictionary = zombies[i]
		var body: CharacterBody3D = z["node"]
		if z["dead_t"] >= 0.0:
			z["dead_t"] += delta
			if z["dead_t"] > 2.5:
				body.queue_free()
				zombies.remove_at(i)
			continue
		_tick_zombie(z, body, ppos, alive, delta)


func _tick_zombie(z: Dictionary, body: CharacterBody3D, ppos: Vector3, player_alive: bool, delta: float) -> void:
	var pos := body.global_position
	var to_player := _enemy_target(pos) - pos
	to_player.y = 0.0
	var dist := to_player.length()

	z["swing_t"] = maxf(0.0, z["swing_t"] - delta)
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
		body.velocity.y -= GRAVITY * delta
		body.move_and_slide()
		return
	if z.get("stun_t", 0.0) > 0.0:
		z["stun_t"] -= delta
		body.velocity.x = 0.0
		body.velocity.z = 0.0
		body.velocity.y -= GRAVITY * delta
		body.move_and_slide()
		return
	var anims: Array = z["anims"]
	var ap: AnimationPlayer = anims[0] if anims.size() > 0 else null

	var boss: bool = z.get("boss", false)
	var reach: float = BOSS_REACH if boss else float(z.get("reach", ZOMBIE_REACH))
	# Si tiene una baliza a mano la rompe: es lo que la activa por daño (enemy._beacon_in_reach).
	var bc := combat.beacon_in_reach(Fighter.TEAM_HORDE, pos, reach + 0.6)
	if not bc.is_empty():
		body.velocity = Vector3(0, body.velocity.y, 0)
		if z["swing_t"] <= 0.0:
			z["swing_t"] = ZOMBIE_SWING
			bc["hp"] = float(bc["hp"]) - ZOMBIE_DMG * 2.0
			_play_all(anims, "Sword_Attack")
			vfx.burst("spark_04", (bc["node"] as Node3D).global_position + Vector3(0, 0.7, 0),
				bc["col"], 8, 0.3, 2.5, 0.3, -3.0)
		body.velocity.y -= GRAVITY * delta
		body.move_and_slide()
		return
	if float(z.get("blind_t", 0.0)) > 0.0:
		# Cegado por el gas Nox: pierde el rumbo y deambula hasta que se le pasa.
		z["blind_t"] = float(z["blind_t"]) - delta
		if not z.has("blind_dir") or rng.randf() < 0.02:
			var a := rng.randf() * TAU
			z["blind_dir"] = Vector3(cos(a), 0, sin(a))
		var wander: Vector3 = z["blind_dir"]
		var bspd: float = ZOMBIE_SPEED * float(z.get("spd", 1.0)) * SLOW_MULT * 0.6
		body.velocity.x = wander.x * bspd
		body.velocity.z = wander.z * bspd
		var mdl := body.get_child(1) as Node3D
		if mdl != null:
			mdl.rotation.y = lerp_angle(mdl.rotation.y, atan2(wander.x, wander.z), 3.0 * delta)
		if ap != null and ap.current_animation != "Zombie_Walk_Fwd":
			_play_all(anims, "Zombie_Walk_Fwd")
		body.velocity.y -= GRAVITY * delta
		if body.is_on_floor() and body.velocity.y < 0.0:
			body.velocity.y = -1.0
		body.move_and_slide()
		return
	var prey := _enemy_prey(pos)
	# Si estás escondido, `dist` mide contra el último sitio donde te vieron, no contra ti: sin
	# esta guarda te pegaban al llegar allí aunque estuvieras tumbado en la hierba a diez metros.
	var can_hit: bool = (player_alive and not player_hidden()) or not prey.is_empty()
	if can_hit and dist <= reach:
		body.velocity = Vector3(0, body.velocity.y, 0)
		if z["swing_t"] <= 0.0:
			z["swing_t"] = ZOMBIE_SWING
			var dmg := ZOMBIE_DMG * (BOSS_DMG_MULT if boss else float(z.get("dmg", 1.0)))
			if prey.is_empty():
				combat.hurt(pf.rec, dmg)
			else:
				combat.hurt(prey, dmg)
			_play_all(anims, "Sword_Attack")
		elif ap != null and ap.current_animation == "":
			_play_all(anims, "Zombie_Idle")
	else:
		var dir := Vector3.ZERO
		if player_alive:
			var c := _cell_of(pos)
			if dist < CELL * 1.6 or not _in_map(c) or _flow[c.x][c.y].x == -1:
				dir = to_player
			else:
				var nxt: Vector2i = _flow[c.x][c.y]
				dir = _cell_pos(nxt.x, nxt.y) - pos
			dir.y = 0.0
			dir = dir.normalized()
		dir += _separation(body) * 0.6
		dir.y = 0.0
		if dir.length() > 0.01:
			dir = dir.normalized()
			var zspd: float = ZOMBIE_SPEED * (BOSS_SPEED_MULT if boss else float(z.get("spd", 1.0)))
			if float(z.get("slow_t", 0.0)) > 0.0:
				z["slow_t"] = float(z["slow_t"]) - delta
				zspd *= SLOW_MULT
			body.velocity.x = dir.x * zspd
			body.velocity.z = dir.z * zspd
			var model := body.get_child(1) as Node3D
			if model != null:
				model.rotation.y = lerp_angle(model.rotation.y, atan2(dir.x, dir.z), 8.0 * delta)
		else:
			body.velocity.x = 0.0
			body.velocity.z = 0.0
		if ap != null and ap.current_animation != "Sword_Attack" \
				and ap.current_animation != "Zombie_Walk_Fwd":
			_play_all(anims, "Zombie_Walk_Fwd")

	body.velocity.y -= GRAVITY * delta
	if body.is_on_floor() and body.velocity.y < 0.0:
		body.velocity.y = -1.0
	body.move_and_slide()


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


func _kill_zombie(z: Dictionary) -> void:
	z["dead_t"] = 0.0
	if float(z.get("spore_t", 0.0)) > 0.0:
		combat.spore_burst(z)
	_kills += 1
	pf.streak += 1
	_show_badge(_badge_for())
	if z.get("boss", false):
		_boss_alive = false
		print("¡jefe abatido!")
	var body: CharacterBody3D = z["node"]
	body.velocity = Vector3.ZERO
	var cs := body.get_child(0) as CollisionShape3D
	if cs != null:
		cs.disabled = true
	_play_all(z["anims"], "Death01")


func _tick_player_death(delta: float) -> void:
	if _php > 0.0:
		return
	pf.respawn_t -= delta
	if pf.respawn_t > 0.0:
		return
	var c := _spawn_cell()
	player.position = _cell_pos(c.x, c.y) + Vector3(0, 0.3, 0)
	_php = PLAYER_HP
	_play_all(player_anims, "Idle")


func _build_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	hud = Label.new()
	hud.position = Vector2(88, 10)     # a la derecha del botón de pausa (☰)
	hud.add_theme_color_override("font_color", Color.WHITE)
	hud.add_theme_color_override("font_outline_color", Color.BLACK)
	hud.add_theme_constant_override("outline_size", 5)
	layer.add_child(hud)
	var cross := Label.new()
	cross.text = "+"
	cross.add_theme_font_size_override("font_size", 26)
	cross.add_theme_color_override("font_color", Color(1, 1, 1, 0.8))
	cross.add_theme_color_override("font_outline_color", Color.BLACK)
	cross.add_theme_constant_override("outline_size", 4)
	cross.set_anchors_preset(Control.PRESET_CENTER)
	cross.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cross.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	layer.add_child(cross)


func _apply_cam_mode() -> void:
	if _cam_mode == 0:
		spring.spring_length = 5.0
		_pitch = -0.26
		_cam_height = 1.5
		spring.collision_mask = L_WORLD   # sobre el hombro sí esquiva los árboles
	else:
		spring.spring_length = 15.0
		_pitch = -0.95
		_cam_height = 1.0
		spring.collision_mask = 0      # vista alta: flota, si chocara se metería entre las copas


func _unhandled_input(e: InputEvent) -> void:
	if _mode == "menu" or player == null:
		return
	if team_mode != null and team_mode.rules.state != "playing":
		return
	if e is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var mm := e as InputEventMouseMotion
		_yaw -= mm.relative.x * 0.005
		_pitch = clampf(_pitch - mm.relative.y * 0.004, -1.35, 0.35)
	elif e is InputEventMouseButton:
		var mb := e as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed:
			spring.spring_length = maxf(2.0, spring.spring_length - 0.8)
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed:
			spring.spring_length = minf(30.0, spring.spring_length + 0.8)
		elif mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed and not touch:
			_try_cast(0)
		elif mb.button_index == MOUSE_BUTTON_RIGHT and not touch:
			# mantener = ver el radio, soltar = colocar (como el apuntado táctil del juego)
			if mb.pressed:
				_preview = 1
			else:
				_preview = -1
				_try_cast(1)
	elif e is InputEventKey and not (e as InputEventKey).echo:
		var k := e as InputEventKey
		if k.pressed:
			match k.physical_keycode:
				KEY_ESCAPE:
					Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED else Input.MOUSE_MODE_CAPTURED
				KEY_C:
					_cam_mode = 1 - _cam_mode
					_apply_cam_mode()
				KEY_Q:
					_try_cast(0)
				KEY_E:
					_preview = 1
				KEY_R:
					_preview = 2
				KEY_TAB:
					if team_mode == null:      # por equipos la leyenda es la de la partida
						switch_legend(1)
				KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6, KEY_7:
					if team_mode == null:
						switch_legend(k.physical_keycode - KEY_1 - _legend)
				KEY_F10:
					get_tree().quit()
		else:
			match k.physical_keycode:
				KEY_E:
					if _preview == 1:
						_preview = -1
						_try_cast(1)
				KEY_R:
					if _preview == 2:
						_preview = -1
						_try_cast(2)


## Una vuelta de física: tu muerte y reaparición, el combate (leyendas y mundo), la horda, el gas
## y por último tu movimiento, que lee el teclado o el joystick y lo pasa a tu leyenda.
func _physics_process(delta: float) -> void:
	if player == null:
		return
	if _mode == "menu":
		_yaw += delta * 0.06
		pivot.global_position = Vector3(0, 2.0, 0)
		pivot.rotation.y = _yaw
		spring.rotation.x = _pitch
		return
	if team_mode == null:
		_tick_player_death(delta)
	_tick_powers(delta)
	if team_mode == null:
		_tick_horde(delta)
	else:
		team_mode.tick(delta)
	_tick_zone(delta)
	var basis := cam.global_transform.basis
	var fwd := -basis.z
	fwd.y = 0.0
	fwd = fwd.normalized()
	var right := basis.x
	right.y = 0.0
	right = right.normalized()

	var wish := Vector3.ZERO
	var frozen := team_mode != null and team_mode.rules.state != "playing"
	if frozen or (team_mode != null and team_mode.autoplay):
		pass
	elif touch:
		wish = right * _joy_vec.x - fwd * _joy_vec.y
	elif Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		if Input.is_physical_key_pressed(KEY_W): wish += fwd
		if Input.is_physical_key_pressed(KEY_S): wish -= fwd
		if Input.is_physical_key_pressed(KEY_D): wish += right
		if Input.is_physical_key_pressed(KEY_A): wish -= right
	# Agacharse: Ctrl mantenido. Frena mucho, pero dentro de una mancha de hierba alta te borra
	# del mapa para las criaturas.
	pf.crouch = Input.is_physical_key_pressed(KEY_CTRL) or _touch_crouch
	pf.run = Input.is_physical_key_pressed(KEY_SHIFT)
	if team_mode == null or not team_mode.autoplay:
		pf.wish = wish
		combat.move_fighter(pf, delta)
	if team_mode != null:
		team_mode.move_bots(delta)

	# La cámara baja con el jugador: agachado detrás de un peñasco tienes que ver lo mismo que él.
	# Por rondas, si has caído sigue a un compañero en pie hasta que acabe la ronda.
	var want_h := _cam_height * (0.62 if pf.crouch else 1.0)
	var follow := pf
	if team_mode != null and not pf.alive():
		for o: Fighter in combat.fighters:
			if o.team == pf.team and o.alive():
				follow = o
				break
	pivot.global_position = follow.pos() + Vector3(0, want_h, 0)
	pivot.rotation.y = _yaw
	spring.rotation.x = _pitch


## Estado de todas las leyendas, luz, barras, mira y después todo lo que hay en el mundo.
func _tick_powers(delta: float) -> void:
	# Mantener la básica carga el mandoble (solo la leyenda que lo tiene).
	pf.holding_basic = (_aim_btn == 0) or (not touch and Input.is_physical_key_pressed(KEY_Q))
	for f: Fighter in combat.fighters:
		combat.tick_fighter(f, delta)
	_tick_daylight(delta)
	combat.tick_bars(delta)

	var prev_r := _ability_range(_preview) if _preview >= 0 else 6.0
	var aim := _aim_point(prev_r)
	if touch and _aim_btn >= 0:
		aim = _aim_point_touch(_preview)
	_aim_dot.position = aim + Vector3(0, 0.05, 0)
	_aim_ring.visible = _preview >= 1
	if _preview >= 1:
		_aim_ring.position = aim + Vector3(0, 0.05, 0)
		var r := _ability_radius(_preview)
		var t := _aim_ring.mesh as TorusMesh
		t.outer_radius = r
		t.inner_radius = maxf(0.05, r - 0.12)

	if _args.has("autocast"):
		_auto_cast()
	if team_mode != null:
		team_mode.tick_brains(delta)

	combat.tick_world(delta)


## Premios de racha del propio juego (hud.KILL_REWARD_NAMES). No hay insignia 2.
const KILL_REWARD_NAMES := {
	1: "Primera muerte", 3: "Triple muerte", 4: "Masacre", 5: "Imparable",
	6: "Carnicería", 7: "Infernal", 8: "Cataclismo", 9: "Leyenda caída",
	10: "La parca", 11: "La parca",
}


## Misma regla que match._reward_kill, sin la rotación de "La parca": aquí solo juegas tú,
## así que el título se gana por bajas totales en vez de por ser quien más lleva.
func _badge_for() -> int:
	if not _first_kill_done:
		_first_kill_done = true
		return 1
	# En match._reward_kill la condición de "La parca" es sobre la RACHA (total >= 10), no sobre
	# las bajas totales. Con bajas totales la insignia salía en CADA baja a partir de la décima.
	if pf.streak >= 10:
		return mini(_kills, 11)
	if pf.streak >= 3:
		return mini(pf.streak, 9)
	return 0


func _show_badge(badge: int) -> void:
	if badge == 0 or not KILL_REWARD_NAMES.has(badge):
		return
	print("INSIGNIA %d: %s  (racha %d, bajas %d)" % [badge, KILL_REWARD_NAMES[badge], pf.streak, _kills])
	if _badge_img == null:
		var layer := CanvasLayer.new()
		layer.layer = 25
		add_child(layer)
		_badge_img = TextureRect.new()
		_badge_img.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_badge_img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_badge_img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		layer.add_child(_badge_img)
		_badge_img.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
		_badge_img.offset_left = -64
		_badge_img.offset_top = -300
		_badge_img.offset_right = 64
		_badge_img.offset_bottom = -172
		_badge_img.pivot_offset = Vector2(64, 64)
		_badge_cap = Label.new()
		_badge_cap.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_badge_cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_badge_cap.position = Vector2(-46, 128)
		_badge_cap.size = Vector2(220, 28)
		_badge_cap.add_theme_color_override("font_color", Color(1, 0.84, 0.48))
		_badge_cap.add_theme_color_override("font_outline_color", Color.BLACK)
		_badge_cap.add_theme_constant_override("outline_size", 4)
		_badge_img.add_child(_badge_cap)
	if not _badge_tex.has(badge):
		var path := "res://assets/ui/kill_rewards/%dx64.png" % badge
		_badge_tex[badge] = load(path)
		if _badge_tex[badge] == null:
			push_error("insignia sin textura: %s" % path)
	_badge_img.texture = _badge_tex[badge]
	_badge_cap.text = String(KILL_REWARD_NAMES[badge])
	if _badge_tween and _badge_tween.is_valid():
		_badge_tween.kill()
	_badge_img.show()
	_badge_img.modulate = Color(1.4, 1.2, 1.0, 1.0)
	_badge_img.scale = Vector2.ONE * 1.25
	_sfx("badge", -4.0 - float(badge - 1) * 0.3)
	_badge_tween = create_tween()
	_badge_tween.set_parallel(true)
	_badge_tween.tween_property(_badge_img, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_badge_tween.tween_property(_badge_img, "modulate", Color.WHITE, 0.22)
	_badge_tween.chain().tween_interval(1.8)
	_badge_tween.chain().tween_property(_badge_img, "modulate:a", 0.0, 0.4)
	_badge_tween.chain().tween_callback(_badge_img.hide)


## Texto de una ranura de habilidad: recarga o cargas, como la barra del HUD del juego.
func _slot(i: int) -> String:
	var ab := _abil(i)
	var name := String(ab["n"])
	if swap_ready(i):
		return "[%s CAMBIAR]" % name
	if i == 2 and pf.ult_by_charge:
		return "[%s %s]" % [name, "LISTA" if pf.ability_ready(2) else "carga " + pf.cooldown_text(2)]
	if int(ab.get("chg", 0)) > 0:
		return "[%s %d/%d]" % [name, _chg[i], int(ab["chg"])]
	if i == 0 and pf.ammo_max > 0:
		return "[%s %d/%d]" % [name, pf.ammo, pf.ammo_max]
	if pf.cd[i] > 0.0:
		return "[%s %.0fs]" % [name, pf.cd[i]]
	return "[%s LISTA]" % name

var _log_t := 0.0
var _last_anim := ""
var _fx_t := 0.0

func _process(_d: float) -> void:
	if _mode == "menu":
		if _shot != "":
			_shot_wait -= 1
			if _shot_wait == 0:
				var mimg := get_viewport().get_texture().get_image()
				if mimg != null:
					mimg.save_png(_shot)
					print("captura: ", _shot)
				get_tree().quit()
		return
	if touch_ui != null:
		touch_ui.queue_redraw()
	if _args.has("fxtest") and player != null:
		# mantiene rayos y una esfera a la vista, para poder juzgarlos en una captura
		_fx_t -= _d
		if _fx_t <= 0.0:
			_fx_t = 0.12
			var f := Vector3(sin(player_model.rotation.y), 0, cos(player_model.rotation.y))
			vfx.spark(player.global_position + f * 4.0 + Vector3(rng.randf_range(-1.5, 1.5), 0, rng.randf_range(-1.5, 1.5)))
			if combat.bolts.is_empty():
				# El proyectil de la leyenda, sea cual sea su ranura: el Rompemareas lo tiene en
				# la 1 (el Enganche), no en la básica, y antes salía una bola con los datos del
				# mandoble.
				var pi := 0
				for k in 3:
					if String(_abil(k)["k"]) == "proj":
						pi = k
						break
				combat.cast_projectile(pf, pf.abil(pi), player.global_position + f * 16.0)
			if combat.decoy_alive(pf).is_empty() and String(_abil(1)["k"]) == "decoy":
				combat.do_cast(pf, 1, player.global_position + f * 4.0)   # para ver el botón de intercambio
			# Si la definitiva es una zona, se relanza en bucle: así el estallido (el polvo del
			# Terremoto, la andanada de la Lluvia) siempre está a la vista para juzgarlo.
			if combat.storms.is_empty() and String(_abil(2)["k"]) == "zone":
				combat.do_cast(pf, 2, player.global_position + f * float(_abil(2).get("rng", 0.0)) * PX)
	if _args.has("bench"):
		_log_t -= 1.0
		if _log_t <= 0.0:
			_log_t = 20.0
			print("[BENCH] vivos=%d fps=%d fisica=%.1fms render=%.1fms objetos=%d" % [
				zombies.size(), Engine.get_frames_per_second(),
				Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0,
				Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0,
				Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)])
	if _args.has("animlog") and player_anim != null:
		var cur := player_anim.current_animation + "@%.2f" % player_anim.speed_scale
		if cur != _last_anim:
			_last_anim = cur
			cur = player_anim.current_animation
			print("[ANIM] %s  (vel %.2f)" % [cur if cur != "" else "(ninguna)", player_anim.speed_scale])
	if _args.has("log"):
		_log_t -= _d
		if _log_t <= 0.0:
			_log_t = 1.0
			var d_min := 1e9
			for z in zombies:
				if z["dead_t"] < 0.0:
					d_min = minf(d_min, player.global_position.distance_to(z["node"].global_position))
			var tally := {}
			for z in zombies:
				var k: String = String(z.get("sp", "jefe" if z.get("boss", false) else "?"))
				tally[k] = int(tally.get(k, 0)) + 1
			print("[HORDA] pos=%v  limite=%.0f  oleada=%d vivos=%d porsalir=%d bajas=%d vida=%.0f mascercano=%.1fm fps=%d  %s" % [
				player.global_position, mw * CELL * 0.5,
				_wave, zombies.size(), _left_to_spawn, _kills, _php,
				d_min if d_min < 1e8 else -1.0, Engine.get_frames_per_second(), str(tally)])
			print("        salidas: %s" % str(_spawned))
	if _shot != "":
		_shot_wait -= 1
		if _shot_wait == 0:
			# En headless no hay textura de viewport y `img` llega nulo. Llamar a save_png sobre
			# nulo aborta la función, así que el quit() de abajo NUNCA se ejecutaba y la prueba
			# se quedaba corriendo para siempre en segundo plano. Con la guarda, --shot sirve
			# además de "corre N fotogramas y sal" para las pruebas sin ventana.
			var img := get_viewport().get_texture().get_image()
			if img != null:
				img.save_png(_shot)
				print("captura: ", _shot)
			else:
				print("sin ventana: no hay captura, pero se han corrido %s fotogramas" % _args.get("wait", "?"))
			get_tree().quit()
		return
	if hud == null:
		return
	if team_mode != null:
		var st := "vida %d/%d" % [int(_php), int(pf.hp_max())] if pf.alive() else "CAÍDO"
		hud.text = ("%s  ·  %s%s\n%d FPS%s\n%s   %s   %s\n"
			+ "clic izq / Q básica · clic der o E táctica · R definitiva · WASD · Shift correr · Ctrl agacharse · C cámara · Esc ratón · F10 salir") % [
			pf.display_name, st, ("  ·  OCULTO" if player_hidden() else ""),
			Engine.get_frames_per_second(), _zone_hud(), _slot(0), _slot(1), _slot(2)]
		return
	var cx := int(round(player.global_position.x / CELL + mw * 0.5))
	var cy := int(round(player.global_position.z / CELL + mh * 0.5))
	var zone := "campo"
	if cx >= 0 and cx < mw and cy >= 0 and cy < mh:
		zone = ["campo", "cueva", "cementerio"][zones[cx][cy]]
	var estado := "MUERTO — vuelves en %.0f s" % maxf(pf.respawn_t, 0.0) if _php <= 0.0 else "vida %d/%d" % [int(_php), int(PLAYER_HP)]
	var oculto := ""
	if pf.crouch:
		oculto = "  ·  AGACHADO" + ("  ·  OCULTO" if player_hidden() else "")
	hud.text = ("%s  ·  OLEADA %d   ·   criaturas vivas %d   ·   por salir %d   ·   bajas %d   ·   %s%s\n"
		+ "%d FPS   |   %d props   |   celda %d,%d (%s)%s\n"
		+ "%s   %s   %s\n"
		+ "clic izq / Q · clic der o E (mantener para ver el radio) · R definitiva\n"
		+ "WASD mover · Shift correr · Ctrl agacharse · ratón girar · rueda zoom · C cámara · Esc ratón · F10 salir") % [
		String(LEGENDS[_legend]["name"]), _wave, zombies.size(), _left_to_spawn, _kills, estado, oculto,
		Engine.get_frames_per_second(), _props, cx, cy, zone, _zone_hud(),
		_slot(0), _slot(1), _slot(2)]
