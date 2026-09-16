## PROTOTIPO DESECHABLE — no forma parte de Fallen Legends, vive fuera del repo.
##
## Levanta EL MISMO mapa de horda que genera el juego: `map_builder.gd` es una copia literal
## del que usa Fallen Legends, así que la rejilla (pasillos, cuevas, cementerio) es idéntica.
## Lo que cambia es el dibujo: en vez de tiles isométricos de Flare, props 3D del
## Stylized Nature MegaKit de Quaternius, recorridos por una cámara en tercera persona.
extends Node3D

# Todo vive DENTRO del proyecto: en un APK no existen las rutas del Mac.
const NATURE := "res://models/nature/"
const CHARS := "res://models/chars/"
const OUTFITS := CHARS
const BESTIARY := CHARS
const UAL1 := CHARS + "UAL1_Standard.glb"
const UAL2 := CHARS + "UAL2_Standard.glb"

const CELL := 3.0        # metros por celda del mapa del juego (192x96 px en isométrico)
const WALL_H := 7.0      # alto de la colisión de los muros
const MAP_SEED := 1234
const GRASS_FIELDS := 16       # manchas de hierba alta donde esconderse agachado
const GRASS_RADIUS := 3        # celdas de radio de cada mancha
const COVER_ROCKS := 50        # peñascos sueltos por el campo, para cubrirse
const CROUCH_MULT := 0.45      # lo que frena ir agachado
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
const SPOTTED_TIME := 3.0      # segundos que te delata atacar desde la maleza
const WALK := 6.0
const SPRINT := 10.0
const GRAVITY := 22.0
const TURN_SPEED := 10.0

# --- horda ---
const ZOMBIE_HP := 60.0
const ZOMBIE_SPEED := 2.4
const ZOMBIE_DMG := 9.0
const ZOMBIE_REACH := 2.0
const ZOMBIE_SWING := 1.5      # s entre zarpazos
const ZOMBIE_TINT := Color(0.55, 0.78, 0.48)
const MAX_ALIVE := 40          # tope de zombis vivos a la vez

# Especies de la horda. Los esqueletos son el grueso; el licántropo y el duende son los dos
# modelos del Bestiary que estaban sin usar, y le dan a la oleada la variedad que tiene el
# juego, donde conviven zombis, licántropos y duendes. `w` es el peso del sorteo y el resto
# multiplica sobre ZOMBIE_HP/SPEED/DMG. `eyes` es la escala de las brasas (0 = sin brasas).
const SPECIES := [
	{"id": "esqueleto", "model": "Skeleton_B.glb", "w": 33, "hp": 1.0, "spd": 1.0, "dmg": 1.0,
		"eyes": 1.0, "eye_col": Color(1.0, 0.45, 0.12), "rad": 0.40, "cap": 1.7,
		"bar": 2.1, "bscale": 1.0, "reach": 2.0, "minw": 1, "grave": true},
	{"id": "esqueleto_hacha", "model": "Skeleton_A.glb", "w": 15, "hp": 1.2, "spd": 0.95, "dmg": 1.25,
		"eyes": 1.0, "eye_col": Color(1.0, 0.45, 0.12), "rad": 0.40, "cap": 1.7,
		"bar": 2.1, "bscale": 1.0, "reach": 2.0, "minw": 1, "grave": true},
	{"id": "licantropo", "model": "Lycan.glb", "w": 19, "hp": 1.8, "spd": 1.35, "dmg": 1.4,
		"eyes": 1.4, "eye_col": Color(1.0, 0.85, 0.25), "rad": 0.50, "cap": 1.9,
		"bar": 2.4, "bscale": 1.2, "reach": 2.3, "minw": 1, "grave": false},
	{"id": "duende", "model": "Puglin.glb", "w": 30, "hp": 0.65, "spd": 1.5, "dmg": 0.6,
		"eyes": 0.6, "eye_col": Color(0.5, 1.0, 0.35), "rad": 0.30, "cap": 0.9,
		"bar": 1.3, "bscale": 0.7, "reach": 1.6, "minw": 1, "grave": false},
	# El guardián infernal es el tercer modelo que quedaba sin usar y aquí hace de élite:
	# raro, lento y muy duro, para que las oleadas tardías cambien de forma y no solo de número.
	{"id": "guardian", "model": "Hellwarden.glb", "w": 7, "hp": 3.2, "spd": 0.85, "dmg": 1.9,
		"eyes": 1.5, "eye_col": Color(1.0, 0.25, 0.10), "rad": 0.60, "cap": 2.2,
		"bar": 2.7, "bscale": 1.45, "reach": 2.5, "minw": 3, "grave": false},
]
const SPAWN_EVERY := 0.5       # sale uno cada tanto, como el goteo del juego
const WAVE_BREAK := 4.0
const FLOW_EVERY := 0.4        # cada cuánto se recalcula el campo de flujo
const PLAYER_HP := 210.0   # el Tormentero, de data/classes/tormentero.tres
const ATTACK_RANGE := 2.8
const ATTACK_ARC := 1.05       # ~60 grados a cada lado
const ATTACK_DMG := 55.0
const RESPAWN_TIME := 4.0

# Jefe: el Rompemareas (Tidebreaker) en vez del dragón, que en el juego sigue siendo 2D.
const BOSS_WAVE := 5           # sale en esta oleada y en sus múltiplos
const BOSS_HP_MULT := 12.0
const BOSS_DMG_MULT := 2.5
const BOSS_SPEED_MULT := 0.75
const BOSS_REACH := 3.2

# --- poderes del Tormentero, con los números reales de data/abilities/*.tres ---
# El juego mide en píxeles: una celda son 192 px y aquí 3 m, así que 1 px = 1,5625 cm.
const PX := CELL / 192.0
const CROSS := 14.0            # tamaño de la mira en píxeles de pantalla

# Esfera voltaica (PROJECTILE, teledirigida)
# Trampa eléctrica (TRAP)
# Tormenta eléctrica (ZONE + campo residual)
const SPARK := Color(0.62, 0.80, 1.0)

# --- esporas del Clérigo, con las constantes de player.gd del juego ---
const SPORE_BASE := 10.0
const SPORE_GROWTH := 1.5           # el daño por segundo crece esto por cada infectado
const SPORE_MAX_TARGETS := 7        # ...contando como mucho estos
const SPORE_DPS_MAX := 60.0
const SPORE_KILL_MULT := 1.25       # y se multiplica cada vez que muere un infectado
const SPORE_SPREAD := 320.0 * PX    # radio de contagio al morir uno (5 m)
const SPORE_CONTAGION := 130.0 * PX # radio de contagio por cercanía en cada tick (2 m)
const SPORE_TIME := 10.0
const SPORE_COL := Color(0.5, 1.0, 0.4)
const SLOW_MULT := 0.5         # el gas Nox deja a la mitad de velocidad (Ability.slow)

# --- Baliza Nox (beacon.gd del juego) ---
const BEACON_HP := 60.0
const BEACON_TRIGGER := 130.0 * PX   # 2 m: a esa distancia un enemigo la despierta
const BEACON_TINT := Color(0.95, 1.35, 0.8)

# --- guardia automática del Caballero (player.GUARD_* del juego) ---
const GUARD_DELAY := 0.4         # segundos quieto antes de cubrirse solo
const GUARD_DAMAGE_MULT := 0.55  # recibe un 45 % menos
const KNOCK_TIME := 0.35         # lo que dura el desplazamiento de un empujón
const PULL_SPEED := 14.0         # m/s a los que el arpón arrastra: el tiempo sale de la distancia

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
const GUARD_COL := Color(0.45, 0.72, 1.0) # azul acero de la guardia del Caballero
# Encaje del arma en el puño: ajustado a ojo sobre capturas, es lo único aquí que no sale de un dato.
const WEAPON_POS := Vector3(0.0, 0.02, 0.0)
const WEAPON_ROT := Vector3(0.0, 0.0, 0.0)
const TORCH_RANGE := 14.0

# --- señuelos del Ilusionista (decoy.gd del juego) ---
const DECOY_TINT := Color(0.85, 0.8, 1.35)   # holograma violeta claro
const DECOY_ALPHA := 0.88
const DECOY_FLICKER := 0.06
const DECOY_SPAWN_FX := 1.5                  # lo que tarda en materializarse
const SWAP_COOLDOWN := 1.0                   # el intercambio se salta la recarga, pero no es gratis

# --- carga del Mandoble del Rompemareas (player.CHARGE_*) ---
const MELEE_ARC := 126.0       # abanico por defecto de un golpe cuerpo a cuerpo, en grados
const CHARGE_MIN := 0.35      # mantener menos de esto es un mandoble normal
const CHARGE_MAX := 1.2       # y más de esto ya no suma
const CHARGE_RAD := 1.9       # radio a tope
const CHARGE_DMG := 2.1       # daño a tope

# --- esbirros del Liche (player.gd del juego) ---
const MINION_HARD_MAX := 10
const ARMY_KEEP := 3

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
const NECK := 1.55   # altura del cuello en la pose de reposo

## Las 7 leyendas jugables de Net.CLASSES, con los modelos que usa el juego
## (player.CLASS_SPRITES para las criaturas, Wardrobe.DEFAULT_LOOKS para las humanas)
## y sus cifras reales de data/classes/*.tres. Vida y velocidad tal cual; la velocidad
## se convierte de px/s a m/s con PX.
const HEAD_M := {"path": CHARS + "Superhero_Male_FullBody.gltf", "cut": NECK}
const HEAD_F := {"path": CHARS + "Superhero_Female_FullBody.gltf", "cut": NECK}


## Las 21 habilidades, con los números tal cual de data/abilities/*.tres. Las distancias van en
## píxeles del juego y se convierten a metros con PX. `cast` es el preaviso (cast_time).
const ABILITIES := {
	"tormentero": [
		{"n": "Esfera voltaica", "col": Color(0.6, 0.8, 1.0), "sfx": "proj_bolt", "k": "proj", "cd": 0.6, "cast": 0.14, "dmg": 22.0, "rng": 660.0, "spd": 620.0, "homing": true},
		{"n": "Trampa eléctrica", "col": Color(0.5, 0.75, 1.0), "sfx": "trap", "k": "trap", "cd": 10.0, "cast": 0.3, "dmg": 18.0, "rng": 320.0, "rad": 320.0,
		 "dur": 10.0, "stun": 1.0, "chg": 3, "act": 5, "tick": 2.0, "tgt": 3},
		{"n": "Tormenta eléctrica", "col": Color(0.7, 0.8, 1.0), "sfx": "storm", "k": "zone", "cd": 30.0, "cast": 0.5, "dmg": 45.0, "rng": 520.0, "rad": 340.0,
		 "delay": 0.6, "stun": 3.5, "field": 10.0, "fdmg": 18.0, "fstun": 1.2},
	],
	"clerigo": [
		{"n": "Golpe sagrado", "col": Color(1.0, 0.95, 0.5), "sfx": "proj_arcane", "k": "proj", "cd": 0.6, "cast": 0.12, "dmg": 16.0, "rng": 680.0, "spd": 620.0, "homing": true},
		# Sanación: el .tres trae 260 px; x3 a petición del usuario (4,1 m -> 12,2 m).
		{"n": "Sanación", "col": Color(0.5, 1.0, 0.5), "sfx": "heal", "k": "heal", "cd": 7.0, "cast": 0.3, "heal": 35.0, "rad": 780.0},
		{"n": "Esporas", "col": Color(0.5, 1.0, 0.4), "sfx": "gas", "k": "spores", "cd": 40.0, "cast": 0.5, "dmg": 10.0, "rng": 520.0, "rad": 190.0,
		 "field": 10.0, "fdmg": 10.0, "tick": 1.0},
	],
	"ilusionista": [
		{"n": "Pistola espectral", "col": Color(0.85, 0.65, 1.0), "sfx": "proj_arcane", "k": "proj", "cd": 0.18, "cast": 0.06, "dmg": 9.0, "rng": 820.0, "spd": 1000.0, "homing": true},
		{"n": "Señuelo", "col": Color(0.75, 0.55, 1.0), "sfx": "decoy", "k": "decoy", "cd": 12.0, "cast": 0.25,
		 "rng": 260.0, "rad": 70.0, "dur": 20.0, "n_decoys": 1, "move": 2, "swap": true, "act": 1},
		{"n": "Fiesta de clones", "col": Color(0.9, 0.6, 1.0), "sfx": "decoy", "k": "decoy", "cd": 35.0, "cast": 0.4,
		 "rng": 0.0, "rad": 110.0, "dur": 20.0, "n_decoys": 5, "move": 1, "invis": 4.0},
	],
	"caballero": [
		{"n": "Lanzada", "col": Color(0.85, 0.85, 0.9), "sfx": "melee", "k": "melee", "cd": 0.8, "cast": 0.2, "dmg": 30.0, "rad": 115.0},
		# Corte de hacha (antes "Carga con escudo": el Caballero lleva hacha, no escudo).
		# Preaviso largo a propósito: se ve tomar impulso antes de salir.
		{"n": "Corte de hacha", "col": Color(0.8, 0.3, 0.3), "sfx": "dash", "k": "dash", "cd": 7.0,
		 "cast": 0.12, "dmg": 25.0, "rng": 700.0, "rad": 70.0, "spd": 900.0, "shove": 5.5, "sync": true},
		# Muro de espinas: el .tres trae 46 px de radio; x3 a petición del usuario (0,7 m -> 2,2 m).
		{"n": "Muro de espinas", "col": Color(0.85, 0.35, 0.3), "sfx": "spikes", "k": "spikes", "cd": 25.0, "cast": 0.5, "dmg": 20.0, "rng": 840.0, "rad": 138.0,
		 "dur": 10.0, "stun": 2.0, "tick": 1.0},
	],
	"rompemareas": [
		{"n": "Mandoble de ancla", "col": Color(0.85, 0.72, 0.45), "sfx": "melee", "k": "melee", "cd": 1.1, "cast": 0.3,
		 "dmg": 60.0, "rad": 170.0, "charge": true, "dust": true, "arc": 180.0},
		# "Enganche", no "Arponazo": lo que lanza es su ANCLA encadenada, no un arpón (nombre
		# elegido por el usuario). SIN teledirigir (petición suya): se clava donde apuntaste, no
		# persigue a nadie. A cambio `catch` es ancho —190 px = 3,0 m— para que el que estaba ahí
		# cuando la tiraste siga entrando aunque se haya movido un poco. Dos números que ya NO coinciden con `data/abilities/arponazo.tres`, los dos a
		# petición suya: recarga 20 s (el .tres dice 7) y alcance 1200 px = 19 m (el .tres dice 520
		# = 8,3 m). `--cd=N` recorta las recargas para probar sin esperar.
		{"n": "Enganche", "col": Color(0.8, 0.68, 0.42), "sfx": "harpoon", "k": "proj", "cd": 20.0, "cast": 0.3, "dmg": 34.0, "rng": 1200.0, "spd": 780.0,
		 "stun": 0.5, "pull": true, "solid": "anchor", "catch": 190.0},
		{"n": "Ancla clavada", "col": Color(0.85, 0.7, 0.4), "sfx": "buff", "k": "buff", "cd": 26.0, "cast": 0.5, "dmg": 26.0, "rng": 300.0, "dur": 5.0,
		 "resist": 0.3, "root": true, "tick": 0.8},
	],
	"liche": [
		{"n": "Rayo gélido", "col": Color(0.5, 0.9, 1.0), "sfx": "proj_frost", "k": "proj", "cd": 0.7, "cast": 0.14, "dmg": 26.0, "rng": 700.0, "spd": 650.0, "homing": true},
		{"n": "Alzar esqueleto", "col": Color(0.85, 0.9, 0.75), "sfx": "summon", "k": "summon", "cd": 6.0, "cast": 0.3, "rad": 70.0, "chg": 3, "count": 1},
		{"n": "Alzar ejército", "col": Color(0.8, 0.9, 0.7), "sfx": "summon", "k": "summon", "cd": 30.0, "cast": 0.6, "rng": 400.0, "rad": 90.0, "count": 7},
	],
	"quimico": [
		{"n": "Frasco corrosivo", "col": Color(0.75, 0.95, 0.3), "sfx": "proj_flask", "k": "proj", "cd": 0.6, "cast": 0.12, "dmg": 20.0, "rng": 640.0, "spd": 640.0, "homing": true},
		{"n": "Baliza Nox", "col": Color(0.75, 0.95, 0.3), "sfx": "trap", "k": "beacon", "cd": 10.0, "cast": 0.3,
		 "dmg": 8.0, "rng": 320.0, "rad": 320.0, "dur": 10.0, "chg": 3, "act": 5, "tick": 0.5, "slow": 0.5},
		{"n": "Granada Nox", "col": Color(0.6, 0.95, 0.25), "sfx": "gas", "k": "gas", "cd": 30.0, "cast": 0.5, "dmg": 10.0, "rng": 560.0, "rad": 460.0,
		 "field": 20.0, "fdmg": 10.0, "tick": 1.0, "slow": 0.5},
	],
	"guerrero": [
		{"n": "Tajo", "col": Color(1.0, 0.85, 0.6), "sfx": "melee", "k": "melee", "cd": 0.8, "cast": 0.12, "dmg": 30.0, "rad": 80.0},
		{"n": "Embestida", "col": Color(1.0, 0.5, 0.3), "sfx": "dash", "k": "dash", "cd": 6.0, "cast": 0.3,
		 "dmg": 20.0, "rng": 220.0, "rad": 70.0, "spd": 700.0, "shove": 3.5, "anim": "Shield_Dash"},
		{"n": "Terremoto", "col": Color(0.8, 0.6, 0.3), "sfx": "burst", "k": "zone", "cd": 10.0, "cast": 0.5, "dmg": 45.0, "rng": 0.0, "rad": 170.0,
		 "delay": 0.7, "knock": 5.5, "fx": "dust", "field": 0.3, "fdmg": 0.0, "anim": "Sword_Regular_B"},
	],
	"arquero": [
		{"n": "Flecha", "col": Color(0.9, 0.9, 0.7), "sfx": "harpoon", "k": "proj", "cd": 0.45, "cast": 0.12, "dmg": 18.0, "rng": 820.0, "spd": 760.0},
		# Retirada: la única carga que va HACIA ATRÁS. Sin daño: es una esquiva.
		{"n": "Retirada", "col": Color(0.7, 0.9, 1.0), "sfx": "dash", "k": "dash", "cd": 6.0, "cast": 0.12,
		 "dmg": 0.0, "rng": 190.0, "rad": 0.0, "spd": 1100.0, "back": true, "anim": "Roll"},
		{"n": "Lluvia de flechas", "col": Color(0.8, 0.9, 0.4), "sfx": "spikes", "k": "zone", "cd": 9.0, "cast": 0.45, "dmg": 50.0, "rng": 620.0, "rad": 130.0,
		 "delay": 0.9, "fx": "arrows", "field": 0.3, "fdmg": 0.0},
	],
	"ciclope": [
		{"n": "Mazazo", "col": Color(0.8, 0.8, 0.7), "sfx": "melee", "k": "melee", "cd": 1.3, "cast": 0.22, "dmg": 48.0, "rad": 100.0,
		 "anim": "Sword_Regular_A"},
		{"n": "Lanzar roca", "col": Color(0.55, 0.5, 0.45), "sfx": "proj_flask", "k": "proj", "cd": 5.0, "cast": 0.35, "dmg": 42.0, "rng": 620.0, "spd": 480.0,
		 "anim": "OverhandThrow", "adur": 1.0},
		{"n": "Golpe de tierra", "col": Color(0.6, 0.5, 0.3), "sfx": "burst", "k": "zone", "cd": 9.0, "cast": 0.4, "dmg": 60.0, "rng": 0.0, "rad": 180.0,
		 "delay": 0.8, "knock": 8.0, "fx": "dust", "field": 0.3, "fdmg": 0.0, "anim": "Sword_Regular_A"},
	],
}

const LEGENDS := [
	{"id": "tormentero", "name": "Tormentero", "hp": 210.0, "speed": 225.0, "tint": Color(0.55, 0.75, 1.0),
	 "models": [HEAD_M, CHARS + "Male_Peasant.gltf", CHARS + "Male_Ranger_Head_Hood.gltf",
		CHARS + "Male_Ranger_Acc_Pauldron.gltf"]},
	{"id": "clerigo", "name": "Clérigo", "hp": 240.0, "speed": 220.0, "tint": Color.WHITE,
	 "models": [HEAD_M, CHARS + "Male_Ranger.gltf"]},
	{"id": "ilusionista", "name": "Ilusionista", "hp": 200.0, "speed": 240.0, "tint": Color.WHITE,
	 "models": [HEAD_F, CHARS + "Female_Ranger.gltf", CHARS + "Hair_Long.gltf"]},
	{"id": "caballero", "name": "Caballero esqueleto", "hp": 380.0, "speed": 200.0, "tint": Color.WHITE, "guard": true,
	 "models": [CHARS + "Skeleton_A.glb"]},
	{"id": "rompemareas", "name": "Rompemareas", "hp": 360.0, "speed": 205.0, "tint": Color.WHITE,
	 "models": [CHARS + "Tidebreaker.glb"]},
	{"id": "liche", "name": "Rey liche", "hp": 220.0, "speed": 215.0, "tint": Color(0.60, 0.85, 0.75),
	 "models": [CHARS + "Skeleton_B.glb"]},
	{"id": "quimico", "name": "Químico", "hp": 230.0, "speed": 225.0, "tint": Color.WHITE,
	 "models": [CHARS + "Imp.glb"]},
	# --- de aquí abajo, FUERA DE LA ROTACIÓN (ver PLAYABLE) ---
	# Las tres RETIRADAS del juego (Net.RETIRED_CLASSES): siguen con datos y habilidades, pero no
	# se pueden elegir "hasta pulirlas". Parte de por qué están sin pulir es que no tienen arte:
	# guerrero y arquero no salen en Wardrobe.DEFAULT_LOOKS (caen al atuendo del Clérigo) y el
	# cíclope usa el hobgoblin 2D "de relleno hasta tener un sprite propio". El aspecto que llevan
	# aquí es una propuesta, no algo heredado. Se quedan escritas pero apartadas, igual que en el
	# juego: `--legend=7`, `8` o `9` las saca para probarlas, Tab y las teclas no las tocan.
	# Túnica de peón (sin capucha) + hombrera y el pelo rapado a la vista: con Male_Ranger salía
	# calcado al Clérigo, porque esa pieza trae capucha y tapaba el pelo.
	{"id": "guerrero", "name": "Guerrero", "hp": 280.0, "speed": 210.0, "tint": Color(1.24, 0.86, 0.74),
	 "models": [HEAD_M, CHARS + "Male_Peasant.gltf", CHARS + "Male_Ranger_Acc_Pauldron.gltf",
		CHARS + "Hair_Buzzed.gltf"], "weapon": "sword"},
	# Tinte suave: con el verde de su clase a tope el pelo salía turquesa.
	{"id": "arquero", "name": "Arquero", "hp": 200.0, "speed": 245.0, "tint": Color(0.92, 1.1, 0.95),
	 "models": [HEAD_F, CHARS + "Female_Peasant.gltf", CHARS + "Hair_Long.gltf"], "weapon": "bow"},
	# El cíclope del juego es un hobgoblin: un duende GRANDE. Aquí es el mismo Puglin de la horda
	# a ×2,6, que lo deja en 2,4 m — la misma altura que sus 210 px del juego a 85,6 px/m. El
	# tinte azulado es el suyo de player.CLASS_SPRITES.
	{"id": "ciclope", "name": "Cíclope", "hp": 400.0, "speed": 185.0, "tint": Color(0.7, 0.8, 1.1),
	 "models": [CHARS + "Puglin.glb"], "scale": 2.6, "weapon": "club"},
]

## Cuántas de LEGENDS entran en la rotación. Las de después son las retiradas del juego.
const PLAYABLE := 7

# Solo se injertan las animaciones que se usan: copiarlas las 43 por personaje cuesta caro
# cuando hay 40 zombis en pantalla.
# Roll = la voltereta de Retirada del Arquero. Las de UAL2 van en su propia pasada.
const HERO_ANIMS := "Idle,Jog_Fwd,Sword_Attack,Spell_Simple_Shoot,Death01,Roll,Crouch_Idle,Crouch_Fwd"
# Sword_Regular_A (0,43 s) y _B (0,53 s) miden casi lo que dura un preaviso, así que salen a
# velocidad casi natural. Sword_Heavy_Combo dura 4,33 s: estirado al preaviso salía a 12x, un
# temblor en vez de un mazazo.
const HERO_ANIMS_2 := "OverhandThrow,Sword_Regular_A,Sword_Regular_B,Shield_Dash"
const ZOMBIE_ANIMS_1 := "Death01,Sword_Attack"
const ZOMBIE_ANIMS_2 := "Zombie_Idle,Zombie_Walk_Fwd,Zombie_Scratch"

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

var grid: Array
var zones: Array
var tall_grass: Array             # [x][y] true = hierba alta: agachado ahí no te ven
var mw := 0
var mh := 0
var rng := RandomNumberGenerator.new()
var _gltf_cache := {}

var player: CharacterBody3D
var player_anim: AnimationPlayer      # la primera capa, para consultar estado
var player_anims: Array = []          # todas las capas, para reproducir en bloque
var player_model: Node3D
var pivot: Node3D
var spring: SpringArm3D
var cam: Camera3D
var hud: Label
var _yaw := 0.0
var _pitch := -0.26
var _attacking := false
var _legend := 0
var _cast_anim_t := 0.0   # mientras corre, la animación de conjuro manda sobre andar/correr
var _cam_mode := 0        # 0 = sobre el hombro, 1 = vista alta tipo ARPG
var _cam_height := 1.5
var _shot := ""           # --shot=ruta.png: captura y sale (para enseñar el prototipo sin jugarlo)
var _shot_wait := 30
var _dbg := false
var _props := 0

var zombies: Array = []        # {node, anim, hp, swing_t, dead_t}
var _flow: Array = []          # campo de flujo: _flow[x][y] = celda siguiente hacia el jugador
var _flow_t := 0.0
var _wave := 0
var _left_to_spawn := 0
var _spawn_t := 0.0
var _break_t := 0.0
var _kills := 0
var _streak := 0                   # bajas desde la última muerte
var _first_kill_done := false
var _badge_img: TextureRect = null
var _badge_cap: Label = null
var _badge_tween: Tween = null
var _badge_tex := {}
var _php := 210.0
var _pdead_t := 0.0
var _spawn_cells: Array = []
var _grave_cells: Array = []
var _zombie_mats := {}
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
var _hurt_t := 0.0

var _cd := [0.0, 0.0, 0.0]          # recarga restante de cada ranura
var _chg := [0, 0, 0]               # cargas disponibles (las habilidades que las usan)
var _chg_t := [0.0, 0.0, 0.0]
var _windup := -1.0                # preaviso en curso (cast_time), como Caster.windups
var _windup_idx := -1
var _windup_at := Vector3.ZERO
var bolts: Array = []              # esferas en vuelo
var traps: Array = []              # trampas puestas
var storms: Array = []             # tormentas y sus nubes
var sparks: Array = []             # destellos de rayo, puramente visuales
var spikes: Array = []             # muros de espinas creciendo
var allies: Array = []             # esbirros del liche y señuelos del ilusionista
var _buff_left := 0.0
var _buff_resist := 0.0
var _buff_root := false
var _buff_dmg := 0.0
var _buff_rad := 0.0
var _buff_tick := 0.0
var _buff_fx: Node3D = null
var _dash_vec := Vector3.ZERO
var _dash_left := 0.0
var _dash_dmg := 0.0
var _dash_rad := 0.0
var _dash_hit := {}
var _dash_shove := 0.0
var _dash_speed := 0.0
var _dash_done := 0.0
var _dash_t := 0.0
var _dash_dur := 1.0
var _dash_total := 0.0
var _dash_from := Vector3.ZERO
var _dash_want := 0.0
var _spore_dps := 0.0
var _spore_tick := 0.0
var _hidden_t := 0.0
var _crouch := false              # agachado: más lento, y oculto si estás en hierba alta
var _spotted_t := 0.0             # atacar te delata unos segundos aunque sigas agachado
var _last_seen := Vector3.ZERO    # dónde te vieron por última vez: adonde van mientras te escondes
var _prev_ppos := Vector3.ZERO
var _player_step := Vector3.ZERO
var _swing_charge_t := 0.0
var _swap_t := 0.0
var _still_t := 0.0
var _guard := false
var _guard_fx: Node3D = null
var _bubble_sh: Shader = null     # uno para todas: compilarlo por burbuja cuesta y se filtra
var player_bar: Node3D = null
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
var _cd_cap := 0.0                # --cd=N: recorta TODAS las recargas, solo para pruebas
var _cycle := DAY_CYCLE
var torch: OmniLight3D = null
var _charge_mult := 1.0
var beacons: Array = []            # barriles de gas del Químico
var _summon_queue: Array = []
var _summon_t := 0.0
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
	touch = OS.has_feature("mobile") or OS.has_feature("web_ios") or OS.has_feature("web_android") \
		or DisplayServer.is_touchscreen_available() or _args.has("touch")
	rng.seed = MAP_SEED
	var t0 := Time.get_ticks_msec()
	var m: Dictionary = MapBuilder.horde_map(MAP_SEED)
	grid = m["grid"]
	zones = m["zones"]
	mw = grid.size()
	mh = (grid[0] as Array).size()
	print("mapa %dx%d generado con el MISMO map_builder.gd del juego" % [mw, mh])

	_setup_environment()
	_build_ground()
	_build_blockers()
	_build_grass_fields()      # antes que la decoración: decide dónde va la hierba alta
	if not _args.has("nodecor"):
		_scatter_decor()
		_scatter_cover()
	_build_graves(m)
	_build_collision()
	_spawn_player()
	_spawn_companions()
	_build_hud()
	if not _args.has("nozone"):
		if _args.has("zonewait"):
			_zone_wait = maxf(float(_args["zonewait"]), 0.0)
		if _args.has("zonefast"):
			_zone_fast = maxf(float(_args["zonefast"]), 0.1)
		_setup_zone()
	_setup_horde()
	_build_aim()
	reset_abilities()
	_setup_music()
	_setup_touch()
	_apply_cam_args()
	if _shot == "" and not touch:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	print("construido en %d ms — %d props" % [Time.get_ticks_msec() - t0, _props])


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
	if _args.has("legend"):
		# Salta el recorte de PLAYABLE a propósito: es la única vía a las retiradas.
		set_legend(int(_args["legend"]))
	if _args.has("boss"):
		_spawn_boss()      # después de --near, para que salga al lado (solo pruebas)
	if _args.has("cd"):
		_cd_cap = maxf(float(_args["cd"]), 0.1)
		print("recargas recortadas a %.1f s (solo prueba)" % _cd_cap)
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
			xf = xf.rotated(Vector3.UP, rng.randf() * TAU)
			xf = xf.scaled(Vector3.ONE * rng.randf_range(0.85, 1.15))
			xf.origin = _cell_pos(x, y) + Vector3(rng.randf_range(-0.5, 0.5), 0, rng.randf_range(-0.5, 0.5))
			by_model.get_or_add(name, []).append(xf)
	for name in by_model:
		_multimesh(NATURE + name + ".gltf", by_model[name])


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

	_zone_ring = _ring(1.0, ZONE_GLOW, 0.45)     # aro en el suelo, para ver el borde exacto
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
	if _php > 0.0 and _outside_zone(player.global_position):
		_damage_player(ZONE_DPS * 0.5)
		_burst("smoke_02", player.global_position + Vector3(0, 1.0, 0),
			Color(ZONE_GLOW.r, ZONE_GLOW.g, ZONE_GLOW.b, 0.5), 8, 0.9, 1.2, 0.8, 0.35, 80.0, 0.6)
	for z in zombies:
		if z["dead_t"] < 0.0 and _outside_zone((z["node"] as Node3D).global_position):
			_damage_zombie(z, ZONE_DPS * 0.5)


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


## Peñascos sueltos por el campo para cubrirse. Llevan colisión propia (capa del mundo), así que
## frenan igual al jugador y a las criaturas. Se quedan pequeños respecto a la celda de 3 m a
## propósito: el campo de flujo de las criaturas razona por celdas y no sabe que están ahí, así
## que hay que dejarles sitio de sobra para rodearlos.
func _scatter_cover() -> void:
	var by_model := {}
	var body := StaticBody3D.new()
	body.collision_layer = L_WORLD
	body.collision_mask = 0
	add_child(body)
	var n := 0
	# Lejos de donde aparece el jugador: en la primera prueba le tocó un peñasco justo encima y
	# arrancó la partida subido a él, a 2,2 m del suelo.
	var home := _spawn_cell()
	for i in COVER_ROCKS * 10:
		if n >= COVER_ROCKS:
			break
		var x := rng.randi_range(2, mw - 3)
		var y := rng.randi_range(2, mh - 3)
		if not MapBuilder.walkable(grid[x][y]) or zones[x][y] != 0 or tall_grass[x][y]:
			continue
		if Vector2(x - home.x, y - home.y).length() < 3.0:
			continue
		var p := _cell_pos(x, y)
		var sc := rng.randf_range(1.4, 2.1)
		var xf := Transform3D.IDENTITY.rotated(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * sc)
		xf.origin = p
		by_model.get_or_add("Rock_Medium_%d" % (1 + rng.randi() % 3), []).append(xf)
		var cs := CollisionShape3D.new()
		var cyl := CylinderShape3D.new()
		cyl.radius = 0.52 * sc     # ajustado al bulto visible: si es menor, te metes dentro de la roca
		cyl.height = 2.2
		cs.shape = cyl
		cs.position = p + Vector3(0, 1.1, 0)
		body.add_child(cs)
		n += 1
	for name in by_model:
		_multimesh(NATURE + name + ".gltf", by_model[name])
	print("peñascos de cobertura: %d" % n)


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


## Las 6 tumbas que el juego coloca en el cementerio: losa plana y lápida de pie.
func _build_graves(m: Dictionary) -> void:
	var cells: Array = MapBuilder.cemetery_graves(grid, zones, MAP_SEED)
	var slabs: Array = []
	var stones: Array = []
	for c in cells:
		var p := _cell_pos(c.x, c.y)
		var yaw := rng.randf_range(-0.25, 0.25)
		var slab := Transform3D.IDENTITY.rotated(Vector3.UP, yaw)
		slab.origin = p + Vector3(0, 0.02, 0.4)
		slabs.append(slab)
		var stone := Transform3D.IDENTITY.rotated(Vector3.UP, yaw)
		stone = stone.scaled(Vector3(0.9, 2.2, 0.35))
		stone.origin = p + Vector3(0, 0, -0.9)
		stones.append(stone)
	_multimesh(NATURE + "RockPath_Square_Wide.gltf", slabs)
	_multimesh(NATURE + "Pebble_Square_4.gltf", stones)
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
			if MapBuilder.walkable(grid[x][y]):
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


func _spawn_player() -> void:
	var c := _spawn_cell()
	player = CharacterBody3D.new()
	player.collision_layer = L_PLAYER
	player.collision_mask = L_WORLD
	player.position = _cell_pos(c.x, c.y) + Vector3(0, 0.2, 0)
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.45
	cap.height = 1.8
	cs.shape = cap
	cs.position = Vector3(0, 0.9, 0)
	player.add_child(cs)
	# cuerpo base debajo del atuendo: los atuendos no traen cabeza (el peón salía sin cara)
	var made := _make_character(LEGENDS[_legend]["models"])
	player_model = made.get("node")
	if player_model != null:
		_tint_model(player_model, LEGENDS[_legend]["tint"])
		var sc0 := float(LEGENDS[_legend].get("scale", 1.0))
		if sc0 != 1.0:
			player_model.scale = Vector3.ONE * sc0
		_attach_weapon(player_model, String(LEGENDS[_legend].get("weapon", "")))
	player_anims = made.get("anims", [])
	player_anim = player_anims[0] if player_anims.size() > 0 else null
	if player_model != null:
		player.add_child(player_model)
	torch = OmniLight3D.new()
	torch.light_color = Color(1.0, 0.82, 0.55)
	torch.omni_range = TORCH_RANGE
	torch.light_energy = 0.0
	torch.position = Vector3(0, 1.5, 0)
	player.add_child(torch)
	player_bar = _make_bar(player, _bar_height(player_model), BAR_ALLY)
	add_child(player)
	if player_anim != null:
		_play_all(player_anims, "Idle")
		player_anim.animation_finished.connect(_on_anim_done)

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


func set_legend(i: int) -> void:
	_legend = clampi(i, 0, LEGENDS.size() - 1)
	if player_model != null:
		player.remove_child(player_model)
		player_model.queue_free()
	var made := _make_character(LEGENDS[_legend]["models"])
	player_model = made.get("node")
	player_anims = made.get("anims", [])
	player_anim = player_anims[0] if player_anims.size() > 0 else null
	if player_model != null:
		_tint_model(player_model, LEGENDS[_legend]["tint"])
		# El Cíclope es un duende a ×2,6: la escala va en el modelo, no en la cápsula, que se
		# deja como está a propósito (el jugador solo choca con el mundo y agrandarla lo dejaría
		# atascado entre los árboles).
		var sc := float(LEGENDS[_legend].get("scale", 1.0))
		if sc != 1.0:
			player_model.scale = Vector3.ONE * sc
		_attach_weapon(player_model, String(LEGENDS[_legend].get("weapon", "")))
		player.add_child(player_model)
	if player_anim != null:
		_play_all(player_anims, "Idle")
		if not player_anim.animation_finished.is_connected(_on_anim_done):
			player_anim.animation_finished.connect(_on_anim_done)
	_php = LEGENDS[_legend]["hp"]
	# La antorcha y la barra cuelgan del jugador, que NO se recrea al cambiar de leyenda:
	# solo hay que rehacerlas si por lo que sea faltan. La altura sí cambia con la leyenda.
	if player_bar == null or not is_instance_valid(player_bar):
		player_bar = _make_bar(player, 2.25, BAR_ALLY)
	player_bar.position.y = _bar_height(player_model)
	reset_abilities()
	print("leyenda: %s (%d vida, %.1f m/s, %.2f m de alto, barra a %.2f)" % [
		LEGENDS[_legend]["name"], int(_php), legend_speed(),
		_model_top(player_model) * maxf(player_model.scale.y, 0.01) if player_model != null else 0.0,
		player_bar.position.y if player_bar != null else 0.0])


func legend_speed() -> float:
	return float(LEGENDS[_legend]["speed"]) * PX


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
	if not touch:
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

func _ring(radius: float, color: Color, alpha := 0.9) -> MeshInstance3D:
	var t := TorusMesh.new()
	t.inner_radius = maxf(0.05, radius - 0.12)
	t.outer_radius = radius
	var mi := MeshInstance3D.new()
	mi.mesh = t
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(color.r, color.g, color.b, alpha)
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	mi.material_override = m
	return mi


## Disco tenue para el relleno de una zona ya colocada (sin borde duro, como en el juego 2D).
func _disc(radius: float, color: Color, alpha := 0.18) -> MeshInstance3D:
	var c := CylinderMesh.new()
	c.top_radius = radius
	c.bottom_radius = radius
	c.height = 0.04
	var mi := MeshInstance3D.new()
	mi.mesh = c
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(color.r, color.g, color.b, alpha)
	mi.material_override = m
	return mi


func _build_aim() -> void:
	_aim_ring = _ring(5.0, SPARK, 0.55)
	_aim_ring.visible = false
	add_child(_aim_ring)
	_aim_dot = _ring(0.22, SPARK, 0.9)
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


## Color de una habilidad, tal cual viene de su .tres.
func _acol(i: int) -> Color:
	return _abil(i).get("col", SPARK)


func _abil(i: int) -> Dictionary:
	var list: Array = ABILITIES.get(LEGENDS[_legend]["id"], ABILITIES["tormentero"])
	return list[i] if i < list.size() else list[0]


func _ability_range(i: int) -> float:
	var r := float(_abil(i).get("rng", 0.0)) * PX
	return r if r > 0.1 else 2.5      # 0 = centrada en uno mismo


func _ability_radius(i: int) -> float:
	return float(_abil(i).get("rad", 24.0)) * PX


func _ability_ready(i: int) -> bool:
	if _php <= 0.0 or _windup >= 0.0:
		return false
	var ab := _abil(i)
	if int(ab.get("chg", 0)) > 0:
		return _chg[i] > 0
	return _cd[i] <= 0.0


## ¿Esta ranura está lista para INTERCAMBIAR en vez de lanzar? (player.swap_ready del juego)
## Cuando lo está, el botón no enseña recarga: enseña que puedes cambiarte de sitio.
func swap_ready(i: int) -> bool:
	return _abil(i).get("swap", false) and _swap_t <= 0.0 and not _decoy_alive().is_empty()


func cooldown_left(i: int) -> float:
	var ab := _abil(i)
	if int(ab.get("chg", 0)) > 0:
		return _chg_t[i] if _chg[i] < int(ab["chg"]) else 0.0
	return _cd[i]


func cooldown_fraction(i: int) -> float:
	var ab := _abil(i)
	var total := float(ab.get("cd", 1.0))
	if int(ab.get("chg", 0)) > 0:
		return clampf(_chg_t[i] / total, 0.0, 1.0) if _chg[i] < int(ab["chg"]) else 0.0
	return clampf(_cd[i] / total, 0.0, 1.0)


## Rellena las cargas al cambiar de leyenda.
func reset_abilities() -> void:
	for i in 3:
		_cd[i] = 0.0
		_chg[i] = int(_abil(i).get("chg", 0))
		_chg_t[i] = 0.0


## Cobra la recarga o la carga y arranca el preaviso; el efecto sale al agotarse (player.try_cast).
func _try_cast(i: int, at := Vector3.INF) -> void:
	var ab := _abil(i)
	if ab.get("swap", false) and _swap_t <= 0.0:
		var al := _decoy_alive()
		if not al.is_empty():
			_swap_t = SWAP_COOLDOWN   # se salta la recarga, pero no es gratis
			_swap_with_decoy(al)
			return
	if not _ability_ready(i):
		return
	if at == Vector3.INF:
		at = _auto_aim(i) if touch else _aim_point(_ability_range(i))
	var cd := float(ab["cd"])
	if _cd_cap > 0.0:
		cd = minf(cd, _cd_cap)     # --cd=N: solo para probar sin esperar la recarga real
	if int(ab.get("chg", 0)) > 0:
		_chg[i] -= 1
		if _chg_t[i] <= 0.0:
			_chg_t[i] = cd
	else:
		_cd[i] = cd
	_windup = float(ab.get("cast", 0.25))
	_windup_idx = i
	_windup_at = at
	# `adur` alarga SOLO la animación, no el preaviso: el lanzamiento de roca dura 1,33 s y
	# comprimido a los 0,35 s del preaviso salía a 3,8x. El conjuro sale a su hora igual.
	var dur := maxf(float(ab.get("adur", 0.0)), maxf(_windup, 0.35))
	_cast_anim_t = dur
	# Cada habilidad puede pedir su propia animación ("anim"): el mazazo del Cíclope y el
	# terremoto del Guerrero usan un tajo corto, la roca OverhandThrow y la Retirada Roll.
	# Si no la pide, o el modelo no la trae, se cae al reparto de siempre.
	var anim: String = String(ab.get("anim", ""))
	if anim == "" or player_anim == null or not player_anim.has_animation(anim):
		anim = "Sword_Attack" if ab["k"] in ["melee", "dash"] else "Spell_Simple_Shoot"
	_play_all(player_anims, anim)
	if player_anim != null and player_anim.has_animation(anim):
		var alen := player_anim.get_animation(anim).length
		for ap in player_anims:
			ap.speed_scale = alen / dur
	if String(ab["k"]) != "decoy":
		_hidden_t = 0.0              # disparar te delata; sacar más señuelos no
		_spotted_t = SPOTTED_TIME    # y el camuflaje de la hierba tampoco aguanta un ataque
	_sfx(String(ab.get("sfx", "proj_arcane")))
	var face := at - player.global_position
	face.y = 0.0
	if face.length() > 0.1 and player_model != null:
		player_model.rotation.y = atan2(face.x, face.z)


## Toque sin arrastre: al enemigo más cercano dentro del alcance; si no, al frente.
func _auto_aim(i: int) -> Vector3:
	var rng_m := _ability_range(i)
	var near := _nearest_in(player.global_position, rng_m, 1)
	if not near.is_empty():
		var p: Vector3 = near[0]["node"].global_position
		p.y = 0.0
		return p
	var f := Vector3(sin(player_model.rotation.y), 0, cos(player_model.rotation.y))
	return player.global_position + f * rng_m * 0.7


func _do_cast(i: int, at: Vector3) -> void:
	var ab := _abil(i)
	var rad := _ability_radius(i)
	match String(ab["k"]):
		"proj":
			_cast_projectile(ab, at)
		"melee":
			_cast_melee(ab, at, rad)
		"dash":
			_cast_dash(ab, at, rad)
		"heal":
			_cast_heal(ab, rad)
		"buff":
			_cast_buff(ab)
		"zone":
			_cast_zone(ab, at, rad, true)
		"gas":
			_cast_zone(ab, at, rad, false)
		"spores":
			_cast_spores(ab, at, rad)
		"trap":
			_cast_trap(ab, at, rad, false)
		"beacon":
			_cast_beacon(ab, at, rad)
		"spikes":
			_cast_spikes(ab, at)
		"summon":
			_cast_summon(ab, at)
		"decoy":
			_cast_decoy(ab, at)


# -- proyectil ------------------------------------------------------

func _cast_projectile(ab: Dictionary, at: Vector3) -> void:
	var col: Color = ab.get("col", SPARK)
	var b := Node3D.new()
	# Proyectil SÓLIDO (hoy solo el ancla): en vez de la bola de luz de siempre, el objeto que de
	# verdad sale volando, girando y con la cadena tendida hasta la mano.
	if String(ab.get("solid", "")) == "anchor":
		_cast_anchor(ab, at, b, col)
		return
	var core := MeshInstance3D.new()
	var sph := SphereMesh.new()
	sph.radius = 0.20
	sph.height = 0.40
	sph.radial_segments = 10
	sph.rings = 6
	core.mesh = sph
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(col.r + 0.25, col.g + 0.25, col.b + 0.25)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	core.material_override = m
	b.add_child(core)
	# estela corta pegada a la bola, no una rociada en todas direcciones
	var trail := _emitter(b, "spark_04", Color(col.r, col.g, col.b, 0.9), 0.12, 18, 0.28, 0.2, 0.45)
	trail.position = Vector3.ZERO
	b.position = player.global_position + Vector3(0, 1.2, 0)
	add_child(b)
	var l := OmniLight3D.new()
	l.light_color = col
	l.light_energy = 3.0
	l.omni_range = 6.0
	b.add_child(l)
	bolts.append({"node": b, "target": _homing_target(at) if ab.get("homing", false) else null,
		"to": at, "life": 3.0, "dmg": float(ab.get("dmg", 10.0)),
		"stun": float(ab.get("stun", 0.0)), "pull": ab.get("pull", false),
		"spd": float(ab.get("spd", 620.0)) * PX, "col": col,
		"catch": float(ab.get("catch", 0.0)) * PX if ab.has("catch") else 1.2})


## El ancla encadenada. Misma tubería que el resto de proyectiles (vive en `bolts`), pero con
## malla propia, giro y cadena.
func _cast_anchor(ab: Dictionary, at: Vector3, b: Node3D, col: Color) -> void:
	b.add_child(_make_anchor())
	b.position = player.global_position + Vector3(0, 1.3, 0)
	add_child(b)
	var l := OmniLight3D.new()      # un punto de luz tenue, para que de noche se siga con la vista
	l.light_color = Color(1.0, 0.86, 0.6)
	l.light_energy = 0.8
	l.omni_range = 4.0
	b.add_child(l)
	var chain := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.035
	cm.bottom_radius = 0.035
	cm.height = 1.0
	cm.radial_segments = 5
	cm.rings = 1
	chain.mesh = cm
	var cmat := StandardMaterial3D.new()
	cmat.albedo_color = Color(0.30, 0.28, 0.25)
	cmat.roughness = 0.9
	chain.material_override = cmat
	add_child(chain)
	bolts.append({"node": b, "target": _homing_target(at) if ab.get("homing", false) else null,
		"to": at, "life": 4.0, "dmg": float(ab.get("dmg", 10.0)),
		"stun": float(ab.get("stun", 0.0)), "pull": ab.get("pull", false),
		"spd": float(ab.get("spd", 620.0)) * PX, "col": col, "chain": chain, "spin": true,
		"catch": float(ab.get("catch", 60.0)) * PX})


## La esfera es teledirigida: busca el enemigo más cercano al punto apuntado.
func _homing_target(at: Vector3) -> CharacterBody3D:
	var best: CharacterBody3D = null
	var best_d := 4.0
	for z in zombies:
		if z["dead_t"] >= 0.0:
			continue
		var d: float = at.distance_to(z["node"].global_position)
		if d < best_d:
			best_d = d
			best = z["node"]
	return best


func _tick_bolts(delta: float) -> void:
	for i in range(bolts.size() - 1, -1, -1):
		var b: Dictionary = bolts[i]
		var node: Node3D = b["node"]
		var goal: Vector3 = b["to"]
		var tgt = b["target"]
		if tgt != null and is_instance_valid(tgt):
			goal = tgt.global_position + Vector3(0, 1.0, 0)
		var to := goal - node.position
		var step: float = float(b["spd"]) * delta
		b["life"] -= delta
		if to.length() <= step or b["life"] <= 0.0:
			for z in _nearest_in(node.position, float(b.get("catch", 1.2)), 1):
				_damage_zombie(z, float(b["dmg"]), float(b["stun"]))
				if b["pull"]:
					_pull(z, player.global_position)
			var bc: Color = b.get("col", SPARK)
			if b.get("spin", false):
				# El ancla es hierro: al clavarse salta tierra, no chispas mágicas.
				_burst("dirt_02", node.position, Color(0.66, 0.56, 0.40, 0.95), 18, 0.7, 3.0, 0.4, -4.0, 60.0, 0.3)
				_burst("smoke_04", node.position, Color(0.78, 0.72, 0.60, 0.5), 10, 0.9, 1.2, 0.7, 0.2, 70.0, 0.4)
			else:
				_flash(node.position, Color(bc.r + 0.2, bc.g + 0.2, bc.b + 0.2), 1.4, 0.16)
				_burst("spark_04", node.position, bc, 6, 0.22, 2.5, 0.3, -4.0, 35.0)
			if b.get("chain") != null and is_instance_valid(b["chain"]):
				(b["chain"] as Node).queue_free()
			node.queue_free()
			bolts.remove_at(i)
			continue
		node.position += to.normalized() * step
		if b.get("spin", false):
			node.rotate_object_local(Vector3.FORWARD, delta * 9.0)   # el ancla vuela girando
		if b.get("chain") != null and is_instance_valid(b["chain"]):
			_span(b["chain"], player.global_position + Vector3(0, 1.3, 0), node.position)


## Arrastra al enemigo hacia un punto: es el empujón con el signo cambiado (Ability.pull).
func _pull(z: Dictionary, to: Vector3) -> void:
	var body: CharacterBody3D = z["node"]
	var d := to - body.global_position
	d.y = 0.0
	var dist := d.length() - 0.9        # se queda a un brazo, no encima
	if dist <= 0.1:
		return
	# Arrastre VISIBLE, no teletransporte: antes saltaba de golpe y encima con un tope de 6 m, así
	# que desde el alcance máximo (8,3 m) ni siquiera llegaba a los pies. Ahora tira a velocidad
	# fija y el tiempo sale de la distancia, o sea que llega venga de donde venga.
	var secs := clampf(dist / PULL_SPEED, 0.12, 0.9)
	_knock(z, d.normalized(), dist / secs, secs)
	if _args.has("meleelog"):
		print("[ENGANCHE] tira de un enemigo %.1f m en %.2f s" % [dist, secs])


# -- cuerpo a cuerpo, carga, curación y mejora -----------------------

func _cast_melee(ab: Dictionary, at: Vector3, rad: float) -> void:
	# El giro cargado del Rompemareas: hasta x1,9 de radio y x2,1 de daño, y a 360 grados.
	var full: bool = bool(ab.get("charge", false)) and _charge_mult > 1.02
	rad *= lerpf(1.0, CHARGE_RAD, _charge_mult - 1.0) if full else 1.0
	var origin := player.global_position
	var face := at - origin
	face.y = 0.0
	if face.length() < 0.1:
		face = Vector3(sin(player_model.rotation.y), 0, cos(player_model.rotation.y))
	face = face.normalized()
	var fx := _disc(rad, ab.get("col", Color(1, 0.9, 0.6)), 0.22)
	fx.position = origin + face * rad * 0.5 + Vector3(0, 0.05, 0)
	add_child(fx)
	sparks.append({"node": fx, "life": 0.18})
	_burst("slash_02", origin + face * rad * 0.6 + Vector3(0, 1.0, 0), Color(1, 0.95, 0.8),
		4, 0.25, 1.0, rad * 0.9, 0.0, 20.0)
	if bool(ab.get("dust", false)):
		_swing_dust(origin, face, rad, full, float(ab.get("arc", MELEE_ARC)))
	# Apertura del golpe, en grados de abanico total. El Mandoble de ancla barre 180°: todo lo que
	# tenga delante, de hombro a hombro (petición del usuario). Cargado es la vuelta entera.
	var half := deg_to_rad(float(ab.get("arc", MELEE_ARC))) * 0.5
	var hits := 0
	var widest := 0.0
	for z in _nearest_in(origin, rad + 0.6):
		var to: Vector3 = z["node"].global_position - origin
		to.y = 0.0
		var ang := face.angle_to(to.normalized()) if to.length() > 0.1 else 0.0
		if not full and ang > half:
			continue
		widest = maxf(widest, ang)
		hits += 1
		_damage_zombie(z, float(ab.get("dmg", 20.0)) * (lerpf(1.0, CHARGE_DMG, _charge_mult - 1.0) if full else 1.0),
			float(ab.get("stun", 0.0)))
	if _args.has("meleelog"):
		print("[GOLPE] %s: %.1f m de radio, abanico %.0f°%s, tocó a %d (el más abierto a %.0f°)" % [
			ab["n"], rad, 360.0 if full else rad_to_deg(half * 2.0),
			" CARGADO" if full else "", hits, rad_to_deg(widest)])


## El ancla pesa: cada mandoble levanta el suelo (petición del usuario). El abanico de polvo sigue
## al golpe — el cono de ~63° a cada lado en el mandoble normal, la vuelta entera si va cargado —
## así que se ve DÓNDE ha pegado, que es justo lo que hace legible un área de golpe grande.
func _swing_dust(origin: Vector3, face: Vector3, rad: float, full: bool, arc := MELEE_ARC,
		amount := 1.0) -> void:
	var span := TAU if full else deg_to_rad(arc)
	var n := maxi(int(clampi(int(span / 0.42), 5, 11) * amount), 3)
	var base_a := atan2(face.x, face.z)
	for k in n:
		var a: float = base_a + lerpf(-span * 0.5, span * 0.5, float(k) / float(n - 1))
		var p := origin + Vector3(sin(a), 0.0, cos(a)) * rad * 0.75 + Vector3(0, 0.08, 0)
		_burst("dirt_02", p, Color(0.72, 0.62, 0.45, 0.95), maxi(int(16 * amount), 4), 0.85, 3.0, 0.55, -3.2, 72.0, 0.4)
		_burst("dirt_03", p, Color(0.58, 0.48, 0.34, 0.9), maxi(int(6 * amount), 2), 0.6, 3.6, 0.3, -5.0, 45.0, 0.25)
	# Una polvareda baja que une el abanico, para que no se vean matas sueltas. Clara a propósito:
	# sobre hierba verde un marrón oscuro no se lee.
	_burst("smoke_04", origin + face * rad * (0.0 if full else 0.45) + Vector3(0, 0.15, 0),
		Color(0.80, 0.74, 0.62, 0.62), maxi(int(28 * amount), 8), 1.3, 1.3, 1.15, 0.3, 78.0, rad * 0.6)


## Empujón suave: el enemigo se desplaza y frena, en vez de teletransportarse.
func _knock(z: Dictionary, dir: Vector3, force: float, secs := KNOCK_TIME) -> void:
	z["knock"] = Vector3(dir.x, 0, dir.z).normalized() * force
	z["knock_t"] = secs


func _cast_dash(ab: Dictionary, at: Vector3, rad: float) -> void:
	var d := at - player.global_position
	d.y = 0.0
	if d.length() < 0.3:
		d = Vector3(sin(player_model.rotation.y), 0, cos(player_model.rotation.y))
	# Retirada del Arquero: la única que se aleja del cursor en vez de ir hacia él. Va a alcance
	# fijo, porque hacia atrás no hay nada que "señalar": d solo marca de qué te separas.
	if bool(ab.get("back", false)):
		d = -d.normalized() * float(ab.get("rng", 190.0)) * PX
	# Llega justo donde señalaste, sin pasarse del alcance de la habilidad.
	_dash_vec = d.normalized() * minf(d.length(), float(ab.get("rng", 700.0)) * PX)
	_dash_total = _dash_vec.length()
	_dash_done = 0.0
	_dash_t = 0.0
	_dash_dur = 1.0
	var danim := String(ab.get("anim", "Sword_Attack"))
	if player_anim == null or not player_anim.has_animation(danim):
		danim = "Sword_Attack"
	var alen := 1.0
	if player_anim != null and player_anim.has_animation(danim):
		alen = player_anim.get_animation(danim).length
	# Dos maneras de cronometrar una carga:
	#   "sync" (el Corte de hacha del Caballero, a petición del usuario) = el desplazamiento dura
	#     lo que la animación, que va a velocidad normal; el golpe termina justo al llegar.
	#   lo normal = manda la velocidad del juego (Ability.dash_speed) y la animación se adapta.
	#     La Embestida son 4,6 m a 700 px/s: 0,31 s. Estirar ahí una animación de 1,1 s a la
	#     inversa daría un paseo en vez de una carga.
	var sp := 1.0
	if bool(ab.get("sync", false)) or float(ab.get("spd", 0.0)) <= 0.0:
		_dash_dur = alen
	else:
		_dash_dur = maxf(_dash_total / (float(ab["spd"]) * PX), 0.08)
		sp = clampf(alen / _dash_dur, 0.5, 3.0)
	if player_anim != null and player_anim.has_animation(danim):
		_play_all(player_anims, danim)
		for ap in player_anims:
			ap.speed_scale = sp
	_dash_left = _dash_dur
	# La voltereta del Arquero dura más que su salto (0,17 s): el guardián de animación aguanta
	# hasta que acaba, o se cortaría a medio giro.
	_cast_anim_t = maxf(_dash_dur, alen / maxf(sp, 0.01))
	_dash_dmg = float(ab.get("dmg", 20.0))
	_dash_rad = rad
	_dash_shove = float(ab.get("shove", 0.0))
	_dash_hit.clear()
	if _args.has("dashlog"):
		_dash_from = player.global_position
		_dash_want = _dash_vec.length()
	_sfx("melee")


func _cast_heal(ab: Dictionary, rad: float) -> void:
	_php = minf(_php + float(ab.get("heal", 30.0)), float(LEGENDS[_legend]["hp"]))
	var fx := _disc(rad, ab.get("col", Color(0.5, 1.0, 0.6)), 0.28)
	fx.position = player.global_position + Vector3(0, 0.06, 0)
	add_child(fx)
	sparks.append({"node": fx, "life": 0.6})
	_burst("star_06", player.global_position + Vector3(0, 0.4, 0), ab.get("col", Color(0.55, 1.0, 0.6)),
		26, 1.1, 2.2, 0.55, 1.6, 30.0, rad * 0.5)


func _cast_buff(ab: Dictionary) -> void:
	_buff_left = float(ab.get("dur", 5.0))
	_buff_resist = float(ab.get("resist", 0.3))
	_buff_root = bool(ab.get("root", false))
	_buff_dmg = float(ab.get("dmg", 0.0))
	_buff_rad = float(ab.get("rng", 300.0)) * PX
	_buff_tick = 0.0
	var fx := _ring(_buff_rad, ab.get("col", Color(1.0, 0.8, 0.35)), 0.7)
	fx.position = Vector3(0, 0.06, 0)
	player.add_child(fx)
	_buff_fx = fx


# -- zonas, gas, trampas y balizas -----------------------------------

## `burst` = golpe inicial tras el aviso (Tormenta). Sin él es solo una nube (Gas, Esporas).
func _cast_zone(ab: Dictionary, at: Vector3, rad: float, burst: bool) -> void:
	var col: Color = ab.get("col", SPARK)
	var node := Node3D.new()
	node.position = at
	node.add_child(_ring(rad, col, 0.85))
	node.add_child(_disc(rad, col, 0.12))
	add_child(node)
	if not burst:
		_gas_cloud(node, rad, col)
		# Estallido: la granada revienta con una bocanada gorda antes de asentarse la nube.
		_burst("smoke_07", at + Vector3(0, 1.0, 0), Color(col.r, col.g, col.b, 0.9),
			70, 1.8, 5.0, rad * 0.30, 0.15, 95.0, rad * 0.35)
		_burst("smoke_02", at + Vector3(0, 0.4, 0), Color(col.r * 0.85, col.g, col.b * 0.6, 0.8),
			55, 2.4, 2.5, rad * 0.24, 0.05, 95.0, rad * 0.55)
	storms.append({"node": node, "delay": float(ab.get("delay", 0.0)) if burst else 0.0,
		"field": float(ab.get("field", 6.0)), "tick": 0.0, "hit": not burst, "rad": rad,
		"dmg": float(ab.get("dmg", 0.0)), "stun": float(ab.get("stun", 0.0)),
		"fdmg": float(ab.get("fdmg", 8.0)), "fstun": float(ab.get("fstun", 0.0)),
		"every": float(ab.get("tick", 2.0)), "slow": float(ab.get("slow", 0.0)),
		"knock": float(ab.get("knock", 0.0)), "fx": String(ab.get("fx", "spark")),
		"col": col, "bolts": 7 if burst else 0})


## `beacon` = espera armada y al activarse suelta una nube en vez de descargar rayos.
func _cast_trap(ab: Dictionary, at: Vector3, rad: float, beacon: bool) -> void:
	var col: Color = ab.get("col", SPARK)
	var node := Node3D.new()
	node.position = at
	node.add_child(_disc(rad, col, 0.10))
	node.add_child(_ring(rad, col, 0.35))
	var core := _disc(0.5, col, 0.8)
	core.position = Vector3(0, 0.03, 0)
	node.add_child(core)
	add_child(node)
	traps.append({"node": node, "armed": true, "left": float(ab.get("dur", 10.0)),
		"tick": 0.0, "rad": rad, "dmg": float(ab.get("dmg", 12.0)),
		"stun": float(ab.get("stun", 0.0)), "every": float(ab.get("tick", 2.0)),
		"tgt": int(ab.get("tgt", 99)), "beacon": beacon, "slow": float(ab.get("slow", 0.0))})
	var cap := int(ab.get("act", 5))
	while traps.size() > cap:
		var old: Dictionary = traps.pop_front()
		old["node"].queue_free()


## Barril de gas: bloquea el paso, tiene vida y espera dormido. Lo despierta un enemigo a 2 m
## o cualquier golpe; entonces suelta la nube y se agota.
func _cast_beacon(ab: Dictionary, at: Vector3, rad: float) -> void:
	var body := StaticBody3D.new()
	body.position = at + Vector3(0, 0.0, 0)
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.42
	cyl.bottom_radius = 0.48
	cyl.height = 1.25
	var mi := MeshInstance3D.new()
	mi.mesh = cyl
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(ab["col"]) * BEACON_TINT
	m.emission_enabled = true
	m.emission = Color(ab["col"]) * 0.35
	m.roughness = 0.5
	mi.material_override = m
	mi.position = Vector3(0, 0.63, 0)
	body.add_child(mi)
	var cs := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = 0.45
	shape.height = 1.3
	cs.shape = shape
	cs.position = Vector3(0, 0.65, 0)
	body.add_child(cs)
	add_child(body)
	_emitter(body, "smoke_04", Color(ab["col"].r, ab["col"].g, ab["col"].b, 0.25), 0.3, 6, 1.4, 0.5, 0.5)
	beacons.append({"node": body, "hp": BEACON_HP, "rad": rad, "dur": float(ab.get("dur", 10.0)),
		"dmg": float(ab.get("dmg", 8.0)), "every": float(ab.get("tick", 0.5)),
		"slow": float(ab.get("slow", 0.5)), "col": ab["col"], "spent": false})
	var cap := int(ab.get("act", 5))
	while beacons.size() > cap:
		var old: Dictionary = beacons.pop_front()
		old["node"].queue_free()


## La baliza que tenga a mano un enemigo, para que la muela a golpes.
func _beacon_in_reach(from: Vector3, r: float) -> Dictionary:
	for bc in beacons:
		if bc["spent"]:
			continue
		if from.distance_to((bc["node"] as Node3D).global_position) <= r:
			return bc
	return {}


func _tick_beacons(delta: float) -> void:
	for i in range(beacons.size() - 1, -1, -1):
		var bc: Dictionary = beacons[i]
		var node: Node3D = bc["node"]
		if bc["spent"]:
			continue
		var near := not _nearest_in(node.global_position, BEACON_TRIGGER, 1).is_empty()
		if near or float(bc["hp"]) <= 0.0:
			bc["spent"] = true
			_pop_beacon(bc)
			node.queue_free()
			beacons.remove_at(i)


## Reventar la baliza: suelta la nube de gas donde estaba.
func _pop_beacon(bc: Dictionary) -> void:
	var at: Vector3 = (bc["node"] as Node3D).global_position
	var col: Color = bc["col"]
	_burst("smoke_07", at + Vector3(0, 0.8, 0), Color(col.r, col.g, col.b, 0.8), 26, 1.2, 3.0, 2.0, 0.2, 90.0)
	_sfx("gas")
	var node := Node3D.new()
	node.position = at
	node.add_child(_ring(float(bc["rad"]), col, 0.7))
	node.add_child(_disc(float(bc["rad"]), col, 0.10))
	add_child(node)
	_gas_cloud(node, float(bc["rad"]), col)
	storms.append({"node": node, "delay": 0.0, "field": float(bc["dur"]), "tick": 0.0, "hit": true,
		"rad": float(bc["rad"]), "dmg": 0.0, "stun": 0.0, "fdmg": float(bc["dmg"]), "fstun": 0.0,
		"every": float(bc["every"]), "slow": float(bc["slow"]), "bolts": 0})


## Nube densa: tres capas de humo a distintas alturas y velocidades. Una sola capa se veía
## rala y no tapaba nada.
func _gas_cloud(node: Node3D, rad: float, col: Color) -> void:
	# Muchas bocanadas MEDIANAS, no pocas gigantes: con partículas de 6 m la cámara se metía
	# dentro de ellas y no se veía nada.
	# En móvil, la mitad: son ~1.500 partículas por nube entre las tres capas.
	var n := int(clampf(rad * (35.0 if touch else 70.0), 110.0, 700.0))
	# Verde amarillento y bien opaco: sobre hierba verde, un verde apagado no se ve.
	var tint := Color(0.72, 1.0, 0.25, 0.95)
	var low := _emitter(node, "smoke_04", tint, rad * 0.92, n, 3.6, 0.14, rad * 0.40)
	low.position = Vector3(0, 0.30, 0)
	var mid := _emitter(node, "smoke_02", Color(tint.r, tint.g, tint.b, 0.80), rad * 0.80,
		int(n * 0.7), 4.2, 0.30, rad * 0.32)
	mid.position = Vector3(0, 1.00, 0)
	var top := _emitter(node, "smoke_09", Color(tint.r * 0.9, tint.g, tint.b, 0.60), rad * 0.62,
		int(n * 0.45), 4.8, 0.52, rad * 0.26)
	top.position = Vector3(0, 1.80, 0)


func _tick_traps(delta: float) -> void:
	for i in range(traps.size() - 1, -1, -1):
		var t: Dictionary = traps[i]
		var node: Node3D = t["node"]
		if t["armed"]:
			if _nearest_in(node.position, float(t["rad"])).is_empty():
				continue          # armada sin caducar, como en el juego
			t["armed"] = false
			t["tick"] = 0.0
		t["left"] -= delta
		t["tick"] -= delta
		if t["tick"] <= 0.0:
			t["tick"] = float(t["every"])
			for z in _nearest_in(node.position, float(t["rad"]), int(t["tgt"])):
				_damage_zombie(z, float(t["dmg"]), float(t["stun"]))
				if float(t["slow"]) > 0.0:
					z["slow_t"] = 2.0
				if not t["beacon"]:
					_spark(z["node"].global_position)
		if t["left"] <= 0.0:
			node.queue_free()
			traps.remove_at(i)


func _tick_storms(delta: float) -> void:
	for i in range(storms.size() - 1, -1, -1):
		var st: Dictionary = storms[i]
		var node: Node3D = st["node"]
		var rad := float(st["rad"])
		if not st["hit"]:
			st["delay"] -= delta
			if st["delay"] <= 0.0:
				st["hit"] = true
				_zone_burst(st, node.position, rad)
				for z in _nearest_in(node.position, rad):
					_damage_zombie(z, float(st["dmg"]), float(st["stun"]))
					if float(st["knock"]) > 0.0:
						var away: Vector3 = (z["node"] as Node3D).global_position - node.position
						away.y = 0.0
						if away.length() < 0.05:
							away = Vector3(1, 0, 0)
						_knock(z, away.normalized(), float(st["knock"]))
			continue
		st["field"] -= delta
		st["tick"] -= delta
		if st["tick"] <= 0.0 and float(st["fdmg"]) > 0.0:
			st["tick"] = float(st["every"])
			for z in _nearest_in(node.position, rad):
				_damage_zombie(z, float(st["fdmg"]), float(st["fstun"]))
				if float(st["slow"]) > 0.0:
					z["slow_t"] = 2.0
					z["blind_t"] = 2.5     # dentro del humo no te ve: deambula
		if st["field"] <= 0.0:
			node.queue_free()
			storms.remove_at(i)


# -- muro de espinas -------------------------------------------------

## Brota desde los pies hacia el punto apuntado; solo daña el tramo ya salido.
func _cast_spikes(ab: Dictionary, at: Vector3) -> void:
	var dir := at - player.global_position
	dir.y = 0.0
	if dir.length() < 0.3:
		dir = Vector3(sin(player_model.rotation.y), 0, cos(player_model.rotation.y))
	spikes.append({"from": player.global_position, "dir": dir.normalized(),
		"len": _ability_range(2), "grown": 0.0, "left": float(ab.get("dur", 10.0)),
		"tick": 0.0, "every": float(ab.get("tick", 1.0)), "rad": _ability_radius(2),
		"dmg": float(ab.get("dmg", 20.0)), "stun": float(ab.get("stun", 2.0)), "nodes": []})


## Mata de púas: tres conos inclinados que salen del suelo. Antes era un disco plano de 70 cm
## sobre hierba verde y sencillamente no se veía.
func _spike_clump(rad: float) -> Node3D:
	var root := Node3D.new()
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.86, 0.87, 0.78)
	mat.roughness = 0.6
	var grow := clampf(rad / 0.72, 1.0, 3.0)       # 0,72 m era el radio original
	for i in int(3 * grow):
		var c := CylinderMesh.new()
		c.top_radius = 0.0
		c.bottom_radius = 0.13 * grow
		c.height = rng.randf_range(1.0, 1.5) * grow
		c.radial_segments = 6
		var mi := MeshInstance3D.new()
		mi.mesh = c
		mi.material_override = mat
		var a := TAU * i / float(maxi(1, int(3 * grow))) + rng.randf() * 0.7
		mi.position = Vector3(cos(a), 0, sin(a)) * rad * rng.randf_range(0.15, 0.75) + Vector3(0, c.height * 0.45, 0)
		mi.rotation = Vector3(rng.randf_range(-0.25, 0.25), a, rng.randf_range(-0.25, 0.25))
		root.add_child(mi)
	# marca oscura en el suelo, aplastada como las zonas del juego
	var mark := _disc(rad, Color(0.25, 0.2, 0.12), 0.35)
	mark.position = Vector3(0, 0.03, 0)
	root.add_child(mark)
	return root


func _tick_spikes(delta: float) -> void:
	for i in range(spikes.size() - 1, -1, -1):
		var sp: Dictionary = spikes[i]
		var full := float(sp["len"])
		if sp["grown"] < full:
			sp["grown"] = minf(full, float(sp["grown"]) + full * delta / 0.6)
			while float(sp["nodes"].size()) * 1.1 < float(sp["grown"]):
				var d := _spike_clump(float(sp["rad"]))
				d.position = sp["from"] + sp["dir"] * (sp["nodes"].size() * 1.1) + Vector3(0, 0.0, 0)
				add_child(d)
				_burst("dirt_02", d.position, Color(0.75, 0.68, 0.5), 8, 0.5, 3.0, 0.5, -5.0)
				sp["nodes"].append(d)
		sp["left"] -= delta
		sp["tick"] -= delta
		if sp["tick"] <= 0.0:
			sp["tick"] = float(sp["every"])
			for n in sp["nodes"]:
				for z in _nearest_in((n as Node3D).position, float(sp["rad"])):
					_damage_zombie(z, float(sp["dmg"]), float(sp["stun"]))
		if sp["left"] <= 0.0:
			for n in sp["nodes"]:
				(n as Node3D).queue_free()
			spikes.remove_at(i)


# -- esbirros y señuelos ---------------------------------------------

func _cast_summon(ab: Dictionary, at: Vector3) -> void:
	var n := int(ab.get("count", 1))
	var rad := _ability_radius(1)
	var base := at if float(ab.get("rng", 0.0)) > 0.0 else player.global_position
	if n > 1:
		# El ejército: antes de alzarlo caen todos los esqueletos salvo los 3 más recientes.
		var mine: Array = []
		for al in allies:
			if al["kind"] == "minion":
				mine.append(al)
		while mine.size() > ARMY_KEEP:
			var old: Dictionary = mine.pop_front()
			old["hp"] = 0.0
	for k in n:
		var a := TAU * k / maxi(1, n)
		_summon_queue.append(base + Vector3(cos(a), 0, sin(a)) * rad)


func _tick_summon_queue(delta: float) -> void:
	if _summon_queue.is_empty():
		return
	_summon_t -= delta
	if _summon_t > 0.0:
		return
	_summon_t = 0.5                  # brotan de uno en uno, como en el juego
	var mine := 0
	for al in allies:
		if al["kind"] == "minion":
			mine += 1
	if mine >= MINION_HARD_MAX:
		_summon_queue.clear()
		return
	_spawn_ally("minion", _summon_queue.pop_front(), 0.0)


func _cast_decoy(ab: Dictionary, at: Vector3) -> void:
	var n := int(ab.get("n_decoys", 1))
	var rad := _ability_radius(1)
	var mode := int(ab.get("move", 1))
	# Los giros saltan el 0 para que ningún clon quede pegado al jugador copiándole tal cual.
	for k in n:
		var a := TAU * (k + 1) / (n + 1)
		var pos: Vector3
		var dir := Vector3.ZERO
		if mode == 2:                      # FORWARD: sale hacia donde apuntas y sigue de largo
			dir = at - player.global_position
			dir.y = 0.0
			dir = dir.normalized() if dir.length() > 0.1 else Vector3(sin(player_model.rotation.y), 0, cos(player_model.rotation.y))
			pos = player.global_position + dir * 1.2
		else:                              # SPREAD: corro alrededor, cada uno mirando a un lado
			pos = player.global_position + Vector3(cos(a), 0, sin(a)) * rad
		_spawn_ally("decoy", pos, float(ab.get("dur", 20.0)), mode, a, dir)
	if float(ab.get("invis", 0.0)) > 0.0:
		_hidden_t = float(ab["invis"])


## ¿Hay un señuelo suyo vivo para intercambiarse con él? (Ability.decoy_swap)
func _decoy_alive() -> Dictionary:
	for al in allies:
		if al["kind"] == "decoy" and float(al["hp"]) > 0.0 \
				and absf((al["node"] as Node3D).global_position.y) < 5.0:
			return al
	return {}


## Intercambia sitio con el señuelo: tú apareces donde esté y él donde estabas tú.
func _swap_with_decoy(al: Dictionary) -> void:
	var body: CharacterBody3D = al["node"]
	var mine := player.global_position
	var to := body.global_position
	var lim_x := mw * CELL * 0.5 - CELL
	var lim_z := mh * CELL * 0.5 - CELL
	to.x = clampf(to.x, -lim_x, lim_x)
	to.z = clampf(to.z, -lim_z, lim_z)
	to.y = maxf(to.y, 0.3)     # el suelo es un plano infinito que solo frena desde arriba:
	player.global_position = to
	_prev_ppos = to            # el salto NO es "paso": si no, los clones lo copian y se dispara
	body.global_position = mine
	_burst("magic_02", mine + Vector3(0, 0.9, 0), DECOY_TINT, 18, 0.5, 3.0, 0.6, 0.3)
	_burst("magic_02", player.global_position + Vector3(0, 0.9, 0), DECOY_TINT, 18, 0.5, 3.0, 0.6, 0.3)
	_sfx("decoy")


## Un aliado: el esbirro pelea, el señuelo solo distrae. Los enemigos los toman por objetivo
## cuando están más cerca que el jugador.
func _spawn_ally(kind: String, pos: Vector3, life: float, mode := 1, turn := 0.0, dir := Vector3.ZERO) -> void:
	var made: Dictionary
	if kind == "decoy":
		made = _make_character(LEGENDS[_legend]["models"])
	else:
		if _zombie_proto == null:
			_proto_of(SPECIES[0])      # fuerza la carga del prototipo del esqueleto
		made = _make_character([CHARS + "Skeleton_B.glb"], [[UAL1, ZOMBIE_ANIMS_1], [UAL2, ZOMBIE_ANIMS_2]])
	var model: Node3D = made.get("node")
	if model == null:
		return
	if kind == "decoy":
		pass    # SIN tinte a propósito: si se distinguen, no confunden a nadie.
	else:
		_tint_model(model, Color(0.65, 1.0, 0.8))   # esbirro: verde pálido, para no confundirlo
	var body := CharacterBody3D.new()
	body.collision_layer = L_CREATURE
	body.collision_mask = L_WORLD | L_CREATURE
	body.position = pos + Vector3(0, 0.3, 0)
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.4
	cap.height = 1.7
	cs.shape = cap
	cs.position = Vector3(0, 0.85, 0)
	body.add_child(cs)
	body.add_child(model)
	add_child(body)
	if kind == "decoy":
		# Bocanada de humo en vez de estirarlos desde el suelo: así aparecen de golpe, del tamaño
		# correcto, y el humo tapa el instante en que salen.
		_burst("smoke_07", body.position + Vector3(0, 0.8, 0), Color(0.85, 0.85, 0.9, 0.7),
			22, 1.0, 2.2, 1.6, 0.3, 80.0, 0.5)
		_burst("smoke_04", body.position + Vector3(0, 0.4, 0), Color(0.8, 0.8, 0.85, 0.6),
			14, 1.3, 1.2, 2.2, 0.1, 90.0, 0.7)
	else:
		_burst("magic_05", body.position + Vector3(0, 0.9, 0), Color(0.6, 1.0, 0.7), 20, 0.8, 3.0, 0.9, 1.0)
	var anims := _anims_of(model)
	_play_all(anims, "Idle" if kind == "decoy" else "Zombie_Walk_Fwd")
	if kind == "decoy":
		model.rotation.y = (player_model.rotation.y + turn) if mode == 1 else atan2(dir.x, dir.z)
	var abar := _make_bar(body, 2.2, BAR_ALLY)
	allies.append({"node": body, "anims": anims, "kind": kind, "bar": abar, "hpmax": 60.0, "hp": 60.0,
		"life": life, "swing_t": 0.0, "mode": mode, "turn": turn, "dir": dir,
		"spawn_t": 0.0, "model": model})


func _tick_allies(delta: float) -> void:
	for i in range(allies.size() - 1, -1, -1):
		var al: Dictionary = allies[i]
		var body: CharacterBody3D = al["node"]
		if al["life"] > 0.0:
			al["life"] -= delta
		if al["hp"] <= 0.0 or (al["life"] < 0.0 and float(al["life"]) > -900.0):
			body.queue_free()
			allies.remove_at(i)
			continue
		if al["kind"] == "decoy":
			_tick_decoy(al, body, delta)
			continue
		al["swing_t"] = maxf(0.0, float(al["swing_t"]) - delta)
		var near := _nearest_in(body.global_position, 18.0, 1)
		if near.is_empty():
			continue
		var tgt: CharacterBody3D = near[0]["node"]
		var d := tgt.global_position - body.global_position
		d.y = 0.0
		if d.length() <= 2.0:
			if al["swing_t"] <= 0.0:
				al["swing_t"] = 1.4
				_damage_zombie(near[0], 18.0)
				_play_all(al["anims"], "Sword_Attack")
		else:
			body.velocity.x = d.normalized().x * 3.0
			body.velocity.z = d.normalized().z * 3.0
			var m := body.get_child(1) as Node3D
			if m != null:
				m.rotation.y = lerp_angle(m.rotation.y, atan2(d.x, d.z), 8.0 * delta)
		body.velocity.y -= GRAVITY * delta
		if body.is_on_floor() and body.velocity.y < 0.0:
			body.velocity.y = -1.0
		body.move_and_slide()


## El señuelo NO te sigue: repite tu desplazamiento girado a su propia orientación (SPREAD),
## o sale de largo hacia donde apuntaste (FORWARD). Así, si tú avanzas, cada clon avanza hacia
## donde mira él; y si te paras, se paran todos.
func _tick_decoy(al: Dictionary, body: CharacterBody3D, delta: float) -> void:
	var model: Node3D = al["model"]
	# Orientación: la del jugador MÁS su propio giro, recalculada cada frame. Antes se fijaba solo
	# al nacer, así que al girar tú el clon seguía mirando a donde miraba al aparecer: corría bien
	# pero de lado.
	if int(al["mode"]) == 2:
		model.rotation.y = atan2((al["dir"] as Vector3).x, (al["dir"] as Vector3).z)
	elif player_model != null:
		model.rotation.y = player_model.rotation.y + float(al["turn"])
	var step := Vector3.ZERO
	if int(al["mode"]) == 2:
		step = (al["dir"] as Vector3) * legend_speed() * delta
	else:
		step = (_player_step as Vector3).rotated(Vector3.UP, float(al["turn"]))
	step.y = 0.0
	if step.length() > 0.0001:
		body.move_and_collide(step)
	body.velocity.y -= GRAVITY * delta
	if body.is_on_floor() and body.velocity.y < 0.0:
		body.velocity.y = -1.0
	body.move_and_slide()
	# 2. Gestos: el clon reproduce EXACTAMENTE lo que hace el jugador, incluido lanzar.
	#    Es lo que de verdad confunde: si tú conjuras, los cinco conjuran.
	if player_anim != null:
		var cur := player_anim.current_animation
		var anims: Array = al["anims"]
		for ap in anims:
			if cur != "" and ap.current_animation != cur and ap.has_animation(cur):
				ap.play(cur)
			ap.speed_scale = player_anim.speed_scale


## A quién persigue un enemigo: al aliado más cercano si lo tiene a tiro, si no al jugador.
## Devuelve el propio aliado (o null si es el jugador) para poder morderlo.
func _enemy_prey(from: Vector3) -> Dictionary:
	var best_d := from.distance_to(player.global_position) if not player_hidden() else 1e9
	var prey: Dictionary = {}
	for al in allies:
		var d: float = from.distance_to((al["node"] as Node3D).global_position)
		if d < best_d and d < 14.0:
			best_d = d
			prey = al
	return prey


## Nadie puede apuntarte: por la invisibilidad del Ilusionista, o porque estás AGACHADO dentro de
## una mancha de hierba alta. Atacar te delata unos segundos (`_spotted_t`), así que el camuflaje
## sirve para colarte o escapar, no para disparar desde la maleza sin consecuencias.
func player_hidden() -> bool:
	if _hidden_t > 0.0:
		return true
	return _crouch and _spotted_t <= 0.0 and in_tall_grass(player.global_position)


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
	return _last_seen if player_hidden() else player.global_position


## Daño a un aliado. Un solo golpe disipa un señuelo, como en el juego.
func _hurt_ally(al: Dictionary, dmg: float) -> void:
	if al["kind"] == "decoy":
		al["hp"] = 0.0
		var at: Vector3 = (al["node"] as Node3D).global_position + Vector3(0, 0.9, 0)
		_burst("magic_02", at, DECOY_TINT, 22, 0.6, 3.5, 0.7, 0.4)
	else:
		al["hp"] = float(al["hp"]) - dmg


# -- esporas ---------------------------------------------------------

## Infecta al apuntado y a los que tenga cerca. A partir de ahí la plaga se mantiene sola:
## contagia por cercanía, el daño crece con cada infectado y salta al morir uno.
func _cast_spores(ab: Dictionary, at: Vector3, rad: float) -> void:
	_spore_dps = SPORE_BASE
	for z in _nearest_in(at, rad):
		_infect(z)
	_burst("magic_04", at + Vector3(0, 0.8, 0), SPORE_COL, 24, 0.9, 3.0, 0.8, 0.5, 70.0, rad * 0.5)


## Los bultos: cuatro protuberancias pegadas al cuerpo, como pediste.
## Solo infecta a criaturas: los señuelos y los esbirros NO cogen la plaga (petición del usuario;
## además en `allies` no hay `dead_t`, así que entrar aquí con uno sería un error).
func _infect(z: Dictionary) -> void:
	if not z.has("dead_t") or z["dead_t"] >= 0.0 or float(z.get("spore_t", 0.0)) > 0.0:
		return
	if z.get("boss", false):
		return                      # los jefes resisten la plaga, como en el juego
	z["spore_t"] = SPORE_TIME
	var body: Node3D = z["node"]
	var lumps := Node3D.new()
	var mat := StandardMaterial3D.new()
	mat.albedo_color = SPORE_COL
	mat.emission_enabled = true
	mat.emission = SPORE_COL * 0.6
	# A la medida del bicho: en un duende de 0,93 m los bultos del esqueleto le flotaban
	# por encima de la cabeza.
	var hs := float(z.get("cap", 1.7)) / 1.7
	for i in 4:
		var sph := SphereMesh.new()
		var r := rng.randf_range(0.10, 0.20) * hs
		sph.radius = r
		sph.height = r * 2.0
		sph.radial_segments = 6
		sph.rings = 4
		var mi := MeshInstance3D.new()
		mi.mesh = sph
		mi.material_override = mat
		var a := TAU * i / 4.0 + rng.randf()
		mi.position = Vector3(cos(a) * 0.22 * hs, rng.randf_range(0.5, 1.5) * hs, sin(a) * 0.22 * hs)
		lumps.add_child(mi)
	_emitter(lumps, "magic_03", Color(SPORE_COL.r, SPORE_COL.g, SPORE_COL.b, 0.5), 0.35, 8, 1.2, 0.35, 0.35)
	body.add_child(lumps)
	z["spore_fx"] = lumps


func _cure(z: Dictionary) -> void:
	z["spore_t"] = 0.0
	if z.get("spore_fx") != null and is_instance_valid(z["spore_fx"]):
		z["spore_fx"].queue_free()
	z["spore_fx"] = null


## Al morir un infectado los bultos revientan y la plaga salta a los de alrededor.
func _spore_burst(z: Dictionary) -> void:
	var at: Vector3 = (z["node"] as Node3D).global_position + Vector3(0, 0.9, 0)
	_burst("magic_04", at, SPORE_COL, 30, 1.0, 5.0, 0.7, -1.0, 90.0, 0.3)
	_flash(at, SPORE_COL, 1.6, 0.3)
	_spore_dps = minf(_spore_dps * SPORE_KILL_MULT, SPORE_DPS_MAX)
	var before := 0
	for o in zombies:
		if float(o.get("spore_t", 0.0)) > 0.0: before += 1
	for other in _nearest_in(at, SPORE_SPREAD):
		if other != z:
			_infect(other)
	if _args.has("sporelog"):
		var after := 0
		for o in zombies:
			if float(o.get("spore_t", 0.0)) > 0.0: after += 1
		print("[ESPORAS] estalla un infectado: %d -> %d contagiados, daño/s x1.25 = %.1f" % [before - 1, after, _spore_dps])
	_cure(z)


func _tick_spores(delta: float) -> void:
	_spore_tick -= delta
	var do_tick := _spore_tick <= 0.0
	if do_tick:
		_spore_tick = 1.0
	var infected: Array = []
	for z in zombies:
		if z["dead_t"] >= 0.0 or float(z.get("spore_t", 0.0)) <= 0.0:
			continue
		z["spore_t"] = float(z["spore_t"]) - delta
		if float(z["spore_t"]) <= 0.0:
			_cure(z)
			continue
		infected.append(z)
	if not do_tick or infected.is_empty():
		return
	_spore_dps = minf(_spore_dps + SPORE_GROWTH * mini(infected.size(), SPORE_MAX_TARGETS), SPORE_DPS_MAX)
	if _args.has("sporelog"):
		print("[ESPORAS] infectados=%d  daño/s=%.1f" % [infected.size(), _spore_dps])
	for z in infected:
		var at: Vector3 = (z["node"] as Node3D).global_position
		for other in _nearest_in(at, SPORE_CONTAGION):
			_infect(other)
		_damage_zombie(z, _spore_dps)


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
	if torch != null:
		torch.light_energy = n * 2.2          # la antorcha se aviva al anochecer
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


## Dónde cuelga la barra de vida de una leyenda: justo encima de la cabeza (o del ancha, o del
## mazo). `"bar"` en LEGENDS lo fuerza si alguna vez hace falta.
func _bar_height(model: Node3D) -> float:
	if LEGENDS[_legend].has("bar"):
		return float(LEGENDS[_legend]["bar"])
	if model == null:
		return 2.25
	var top := _model_top(model) * maxf(model.scale.y, 0.01)
	return maxf(top, 1.2) + BAR_GAP


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


# -- partículas (Kenney Particle Pack) -------------------------------

## Material de partícula: cartel que siempre mira a cámara, sin iluminar, teñible.
## Las texturas de Kenney son blancas, así que el color sale del `color` del emisor.
func _fx_mat(tex: String) -> QuadMesh:
	var key := "mesh:" + tex
	if _fx_cache.has(key):
		return _fx_cache[key]
	var q := QuadMesh.new()
	q.size = Vector2.ONE
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	# Aditivo para lo que brilla (chispas, magia, luz); mezcla normal para humo y tierra,
	# que en aditivo se lavan a blanco y parecen vapor.
	m.blend_mode = BaseMaterial3D.BLEND_MODE_MIX if tex.begins_with("smoke") or tex.begins_with("dirt") \
		else BaseMaterial3D.BLEND_MODE_ADD
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.albedo_texture = load("res://assets/particles/%s.png" % tex)
	m.vertex_color_use_as_albedo = true
	m.disable_receive_shadows = true
	q.material = m
	_fx_cache[key] = q
	return q


## Estallido de una sola vez: se libera solo al terminar.
func _burst(tex: String, pos: Vector3, color: Color, amount := 16, life := 0.6,
		speed := 4.0, size := 0.6, grav := -2.0, spread := 60.0, from_radius := 0.1) -> void:
	var p := CPUParticles3D.new()
	p.mesh = _fx_mat(tex)
	p.position = pos
	p.amount = amount
	p.lifetime = life
	p.one_shot = true
	p.explosiveness = 0.9
	p.direction = Vector3.UP
	p.spread = spread
	p.initial_velocity_min = speed * 0.4
	p.initial_velocity_max = speed
	p.gravity = Vector3(0, grav, 0)
	p.scale_amount_min = size * 0.6
	p.scale_amount_max = size
	p.color = color
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = from_radius
	add_child(p)
	sparks.append({"node": p, "life": life + 0.4})


## Emisor continuo colgado de un nodo: la nube de gas, el aura de la mejora.
func _emitter(parent: Node3D, tex: String, color: Color, radius: float,
		amount := 40, life := 2.0, rise := 0.35, size := 2.0) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.mesh = _fx_mat(tex)
	p.amount = amount
	p.lifetime = life
	p.direction = Vector3.UP
	p.spread = 25.0
	p.initial_velocity_min = rise * 0.4
	p.initial_velocity_max = rise
	p.gravity = Vector3.ZERO
	p.scale_amount_min = size * 0.6
	p.scale_amount_max = size
	p.color = color
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = radius
	p.position = Vector3(0, 0.3, 0)
	parent.add_child(p)
	return p


# -- efectos y utilidades --------------------------------------------

## Fogonazo esférico que crece y se apaga. Lee como "aquí ha impactado algo".
func _flash(at: Vector3, color: Color, size := 1.2, life := 0.18) -> void:
	var mi := MeshInstance3D.new()
	var sph := SphereMesh.new()
	sph.radius = size * 0.5
	sph.height = size
	sph.radial_segments = 10
	sph.rings = 6
	mi.mesh = sph
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.albedo_color = color
	mi.material_override = m
	mi.position = at
	add_child(mi)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(mi, "scale", Vector3.ONE * 1.8, life)
	tw.tween_property(m, "albedo_color:a", 0.0, life)
	tw.chain().tween_callback(mi.queue_free)


## Rayo: una línea QUEBRADA de arriba abajo. Antes era un cilindro recto, que no lee como rayo.
func _spark(at: Vector3, col := Color(0.85, 0.92, 1.0)) -> void:
	var root := Node3D.new()
	add_child(root)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.albedo_color = Color(col.r, col.g, col.b, 1.0)
	var top := 9.0
	var segs := 7
	var pts: Array[Vector3] = []
	for i in segs + 1:
		var t := float(i) / segs
		var wob := (1.0 - absf(t - 0.5) * 1.6) * 0.55      # más quebrado por el centro
		pts.append(at + Vector3(rng.randf_range(-wob, wob), top * (1.0 - t), rng.randf_range(-wob, wob)))
	for i in segs:
		var a: Vector3 = pts[i]
		var b: Vector3 = pts[i + 1]
		var d := b - a
		var c := CylinderMesh.new()
		c.top_radius = 0.05
		c.bottom_radius = 0.05
		c.height = d.length()
		c.radial_segments = 4
		var mi := MeshInstance3D.new()
		mi.mesh = c
		mi.material_override = mat
		mi.transform = Transform3D(Basis(Quaternion(Vector3.UP, d.normalized())), a + d * 0.5)
		root.add_child(mi)
	sparks.append({"node": root, "life": 0.18})
	_flash(at + Vector3(0, 0.3, 0), col, 1.6, 0.22)


func _damage_zombie(z: Dictionary, dmg: float, stun := 0.0) -> void:
	if z["dead_t"] >= 0.0:
		return
	z["hp"] -= dmg
	z["bar_t"] = BAR_SHOW
	if stun > 0.0:
		z["stun_t"] = maxf(z.get("stun_t", 0.0), stun * (0.35 if z.get("boss", false) else 1.0))
	if z["hp"] <= 0.0:
		_kill_zombie(z)


## Los `n` enemigos vivos más cercanos a un punto dentro de un radio.
func _nearest_in(at: Vector3, radius: float, n := 999) -> Array:
	var found: Array = []
	for z in zombies:
		if z["dead_t"] >= 0.0:
			continue
		var d: float = at.distance_to(z["node"].global_position)
		if d <= radius:
			found.append({"z": z, "d": d})
	found.sort_custom(func(a, b): return a["d"] < b["d"])
	var out: Array = []
	for i in mini(n, found.size()):
		out.append(found[i]["z"])
	return out


## Solo para pruebas headless: lanza lo que esté listo hacia el enemigo más cercano.
func _auto_cast() -> void:
	if _dash_left > 0.0:
		return              # durante la embestida no se lanza nada (si no, pisa su animación)
	var near := _nearest_in(player.global_position, 30.0, 1)
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


func _tick_powers(delta: float) -> void:
	_player_step = player.global_position - _prev_ppos
	_player_step.y = 0.0
	if _player_step.length() > 1.0:
		_player_step = Vector3.ZERO   # eso no es andar, es un teletransporte
	_prev_ppos = player.global_position
	_hidden_t = maxf(0.0, _hidden_t - delta)
	_spotted_t = maxf(0.0, _spotted_t - delta)
	if not player_hidden():
		_last_seen = player.global_position
	_swap_t = maxf(0.0, _swap_t - delta)
	# Red de seguridad: nada debería caerse del mundo, pero si pasa, se recupera en vez de
	# quedarse cayendo eternamente (el suelo es un plano infinito y no frena desde abajo).
	# Tope duro cada frame. Da igual qué lo empuje (depenetración de un muro, un intercambio,
	# gravedad acumulada): el jugador NO sale del mundo. Antes acababa a 1 km de altura.
	var lx := mw * CELL * 0.5 - CELL
	var lz := mh * CELL * 0.5 - CELL
	var p := player.global_position
	var fixed := Vector3(clampf(p.x, -lx, lx), clampf(p.y, 0.2, 25.0), clampf(p.z, -lz, lz))
	if not fixed.is_equal_approx(p):
		player.global_position = fixed
		player.velocity.y = 0.0
		_prev_ppos = fixed
	for al in allies:
		var ab_node: Node3D = al["node"]
		if ab_node.global_position.y < -5.0:
			al["hp"] = 0.0
	# Mantener la básica carga el mandoble (solo la leyenda que lo tiene).
	var holding := (_aim_btn == 0) or (not touch and Input.is_physical_key_pressed(KEY_Q))
	if _abil(0).get("charge", false) and holding and _php > 0.0:
		_swing_charge_t = minf(_swing_charge_t + delta, CHARGE_MAX)
	elif _swing_charge_t > 0.0 and not holding:
		_swing_charge_t = 0.0
	_charge_mult = 1.0
	if _swing_charge_t >= CHARGE_MIN:
		_charge_mult = 1.0 + (_swing_charge_t - CHARGE_MIN) / (CHARGE_MAX - CHARGE_MIN)
	for i in 3:
		_cd[i] = maxf(0.0, _cd[i] - delta)
		var ab := _abil(i)
		var maxc := int(ab.get("chg", 0))
		if maxc > 0 and _chg[i] < maxc:
			_chg_t[i] -= delta
			if _chg_t[i] <= 0.0:
				_chg[i] += 1
				_chg_t[i] = float(ab["cd"]) if _chg[i] < maxc else 0.0

	if _windup >= 0.0:
		_windup -= delta
		if _windup <= 0.0:
			_windup = -1.0
			_do_cast(_windup_idx, _windup_at)
			_windup_idx = -1

	_tick_buff(delta)
	_tick_dash(delta)
	_tick_guard(delta)
	_tick_daylight(delta)
	_tick_bars(delta)

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

	_tick_bolts(delta)
	_tick_traps(delta)
	_tick_beacons(delta)
	_tick_storms(delta)
	_tick_spikes(delta)
	_tick_spores(delta)
	_tick_summon_queue(delta)
	_tick_allies(delta)
	for i in range(sparks.size() - 1, -1, -1):
		sparks[i]["life"] -= delta
		if sparks[i]["life"] <= 0.0:
			sparks[i]["node"].queue_free()
			sparks.remove_at(i)


## Refresca todas las barras: verdes los tuyos, rojas las criaturas.
func _tick_bars(delta: float) -> void:
	_set_bar(player_bar, _php / maxf(float(LEGENDS[_legend]["hp"]), 1.0))
	for z in zombies:
		if z.has("bar"):
			# La escala tiene que ser la MISMA con la que se creó la barra: _set_bar la usa para
			# recolocar el relleno, y con el duende (0,7) o el licántropo (1,2) quedaba descentrado.
			_set_bar(z["bar"], float(z["hp"]) / maxf(float(z.get("hpmax", ZOMBIE_HP)), 1.0),
				float(z.get("bscale", 1.0)))
			_tick_enemy_bar(z, delta)
	for al in allies:
		if al.has("bar"):
			_set_bar(al["bar"], float(al["hp"]) / maxf(float(al.get("hpmax", 60.0)), 1.0))


## La vida de una criatura solo se ve cuando la golpeas, y se va sola (petición del usuario): con
## 40 bichos a la vez el claro era una pared de barras rojas y no se veía la pelea. El jefe es la
## excepción: su barra es el objetivo de la oleada y no se esconde.
func _tick_enemy_bar(z: Dictionary, delta: float) -> void:
	var bar: Node3D = z["bar"]
	if bar == null or not is_instance_valid(bar):
		return
	if z.get("boss", false):
		return
	var t := float(z.get("bar_t", 0.0))
	if t <= 0.0:
		if bar.visible:
			bar.visible = false
		return
	t = maxf(t - delta, 0.0)
	z["bar_t"] = t
	bar.visible = t > 0.0
	_fade_bar(bar, clampf(t / BAR_FADE, 0.0, 1.0))


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


## Guardia automática del Caballero: se cubre solo tras estar quieto, y atacar NO la rompe.
## La rompen moverse, cargar o que te aturdan.
func _tick_guard(delta: float) -> void:
	if not LEGENDS[_legend].get("guard", false) or _php <= 0.0:
		_guard = false
		_still_t = 0.0
	else:
		var moving := _player_step.length() > 0.02 or _dash_left > 0.0
		if moving:
			_still_t = 0.0
			_guard = false
		else:
			_still_t += delta
			_guard = _still_t >= GUARD_DELAY
	if _guard and _guard_fx == null:
		_guard_fx = _bubble(1.05, GUARD_COL)
		_guard_fx.position = Vector3(0, 0.95, 0)
		player.add_child(_guard_fx)
	elif not _guard and _guard_fx != null:
		_guard_fx.queue_free()
		_guard_fx = null
	if _guard_fx != null:
		var pulse := 1.0 + sin(float(Time.get_ticks_msec()) * 0.004) * 0.045
		_guard_fx.scale = Vector3(pulse, pulse, pulse)


## Burbuja de guardia. El aro en el suelo era otro círculo blanco de los que el juego ya quitó
## (CLAUDE.md, "marcas en el suelo"), y encima el esqueleto no lleva escudo que levantar. Esta es
## la misma idea que la burbuja de inmunidad del 2D, pero en 3D una esfera translúcida a secas se
## ve como un disco plano que tapa el fondo: el brillo va por FRESNEL, así que enciende el borde
## y deja el centro casi transparente, que es lo que la lee como cascarón y no como mancha.
func _bubble(radius: float, color: Color) -> MeshInstance3D:
	var sph := SphereMesh.new()
	sph.radius = radius
	sph.height = radius * 2.0
	sph.radial_segments = 24
	sph.rings = 12
	var mi := MeshInstance3D.new()
	mi.mesh = sph
	var sh: Shader = _bubble_sh
	if sh == null:
		sh = Shader.new()
		_bubble_sh = sh
		sh.code = """
shader_type spatial;
render_mode blend_add, cull_disabled, unshaded, depth_draw_never, shadows_disabled;
uniform vec4 col : source_color;
uniform float power = 3.0;
void fragment() {
	float f = pow(1.0 - abs(dot(normalize(NORMAL), normalize(VIEW))), power);
	ALBEDO = col.rgb;
	ALPHA = col.a * f;
}
"""
	var m := ShaderMaterial.new()
	m.shader = sh
	m.set_shader_parameter("col", Color(color.r, color.g, color.b, 0.62))
	m.set_shader_parameter("power", 3.4)
	mi.material_override = m
	return mi


func _tick_buff(delta: float) -> void:
	if _buff_left <= 0.0:
		return
	_buff_left -= delta
	_buff_tick -= delta
	if _buff_tick <= 0.0:
		_buff_tick = 0.8
		# El aura del Ancla clavada es otro golpe suyo y también levanta polvo, pero a la mitad:
		# repite cada 0,8 s y con la carga del mandoble entero la nube no se despejaba nunca.
		_swing_dust(player.global_position, Vector3(0, 0, 1), _buff_rad, true, MELEE_ARC, 0.45)
		for z in _nearest_in(player.global_position, _buff_rad):
			_damage_zombie(z, _buff_dmg)
			_pull(z, player.global_position)
	if _buff_left <= 0.0 and _buff_fx != null:
		_buff_fx.queue_free()
		_buff_fx = null


## Distancia de un punto al segmento recorrido este frame. Sin esto, un tajo a 17 m/s
## deja entre frame y frame huecos de más de medio metro y se salta enemigos.
func _seg_dist(p: Vector3, a: Vector3, b: Vector3) -> float:
	var ab := b - a
	var l2 := ab.length_squared()
	if l2 < 0.0001:
		return p.distance_to(a)
	var t := clampf((p - a).dot(ab) / l2, 0.0, 1.0)
	return p.distance_to(a + ab * t)


func _tick_dash(delta: float) -> void:
	if _dash_left <= 0.0:
		return
	if player_model != null and _dash_vec.length() > 0.01:
		player_model.rotation.y = atan2(_dash_vec.x, _dash_vec.z)
	# Avanza según lo que lleva de animación, con arranque suave: llega exactamente al acabar.
	_dash_t = minf(_dash_t + delta, _dash_dur)
	var f := smoothstep(0.0, 1.0, _dash_t / _dash_dur)
	var want := _dash_total * f
	var len_step := maxf(want - _dash_done, 0.0)
	_dash_done = want
	var step := _dash_vec.normalized() * len_step
	var from := player.global_position
	_dash_left -= delta
	if _dash_t >= _dash_dur:
		_dash_left = 0.0
		if _args.has("dashlog"):
			var enemigos := 0
			for z in _nearest_in(_dash_from.lerp(player.global_position, 0.5), _dash_total):
				if _seg_dist((z["node"] as Node3D).global_position, _dash_from, player.global_position) <= _dash_rad:
					enemigos += 1
			print("[EMBESTIDA] quería %.1f m, recorrió %.1f m en %.2f s (animación %.2f s), arrolló %d de %d" % [
				_dash_total, _dash_from.distance_to(player.global_position),
				_dash_t, _dash_dur, _dash_hit.size(), enemigos])
	if _dash_left <= 0.0 and player_anim != null and _cast_anim_t <= 0.0:
		for ap in player_anims:
			ap.speed_scale = 1.0
	player.velocity = Vector3.ZERO
	player.move_and_collide(step)
	# Humo continuo a los pies: es lo que hace que no parezca que se desliza.
	_burst("smoke_04", player.global_position + Vector3(0, 0.12, 0),
		Color(0.82, 0.80, 0.72, 0.75), 5, 0.65, 1.1, 0.85, 0.1, 75.0, 0.35)
	_burst("dirt_01", player.global_position + Vector3(0, 0.15, 0),
		Color(0.78, 0.72, 0.58), 5, 0.5, 2.2, 0.45, -3.0, 50.0)
	var fwd := _dash_vec.normalized()
	var perp := fwd.cross(Vector3.UP).normalized()
	var to := player.global_position
	for z in _nearest_in(from.lerp(to, 0.5), from.distance_to(to) * 0.5 + _dash_rad):
		if _dash_hit.has(z["node"]):
			continue
		if _seg_dist((z["node"] as Node3D).global_position, from, to) > _dash_rad:
			continue
		_dash_hit[z["node"]] = true
		_damage_zombie(z, _dash_dmg)
		if _dash_shove > 0.0:
			# A un lado o a otro según de qué lado del corte esté: se abre en dos.
			var off: Vector3 = (z["node"] as Node3D).global_position - player.global_position
			var side := signf(off.dot(perp))
			if absf(side) < 0.01:
				side = 1.0 if rng.randf() < 0.5 else -1.0
			_knock(z, perp * side, _dash_shove)
		_burst("slash_03", (z["node"] as Node3D).global_position + Vector3(0, 1.0, 0),
			Color(1, 0.9, 0.85), 3, 0.2, 1.0, 1.4, 0.0, 15.0)


# ---------------------------------------------------------------- horda

func _setup_horde() -> void:
	_spawn_cells = MapBuilder.edge_cells(grid)
	_grave_cells = MapBuilder.cemetery_graves(grid, zones, MAP_SEED)
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
	zombies.append({"node": body, "anims": anims, "bar": bbar,
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
	body.position = at + Vector3(0, 0.2, 0) if placed else \
		_cell_pos(c.x, c.y) + Vector3(rng.randf_range(-0.8, 0.8), 0.2, rng.randf_range(-0.8, 0.8))
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
	zombies.append({"node": body, "anims": anims, "bar": bar, "hpmax": hpmax, "hp": hpmax,
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


## Estira un cilindro de altura 1 para que vaya de `a` a `b`. Es como se dibuja la cadena, que
## cambia de largo cada fotograma mientras el ancla vuela.
func _span(mi: MeshInstance3D, a: Vector3, b: Vector3) -> void:
	var dir := b - a
	var len := dir.length()
	if len < 0.01:
		mi.visible = false
		return
	mi.visible = true
	var y := dir / len
	var ref := Vector3.RIGHT if absf(y.dot(Vector3.RIGHT)) < 0.9 else Vector3.FORWARD
	var x := ref.cross(y).normalized()
	var z := x.cross(y).normalized()
	mi.transform = Transform3D(Basis(x * 1.0, y * len, z * 1.0), (a + b) * 0.5)


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


func _tint_zombie(model: Node3D) -> void:
	for entry in _meshes_of(model):
		var mi: MeshInstance3D = entry["node"]
		var mesh: Mesh = entry["mesh"]
		for i in mesh.get_surface_count():
			var base := mesh.surface_get_material(i)
			if not (base is BaseMaterial3D):
				continue
			var key := "%s#%d" % [base.resource_name, i]
			if not _zombie_mats.has(key):
				var dup := (base as BaseMaterial3D).duplicate() as BaseMaterial3D
				dup.albedo_color = dup.albedo_color * ZOMBIE_TINT
				_zombie_mats[key] = dup
			mi.set_surface_override_material(i, _zombie_mats[key])


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
	var bc := _beacon_in_reach(pos, reach + 0.6)
	if not bc.is_empty():
		body.velocity = Vector3(0, body.velocity.y, 0)
		if z["swing_t"] <= 0.0:
			z["swing_t"] = ZOMBIE_SWING
			bc["hp"] = float(bc["hp"]) - ZOMBIE_DMG * 2.0
			_play_all(anims, "Sword_Attack")
			_burst("spark_04", (bc["node"] as Node3D).global_position + Vector3(0, 0.7, 0),
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
				_damage_player(dmg)
			else:
				_hurt_ally(prey, dmg)
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


## El estallido de una zona. Rayos para la tormenta, una corona de tierra para los golpes de
## suelo (Terremoto y Golpe de tierra) y una andanada que cae del cielo para la Lluvia de flechas.
func _zone_burst(st: Dictionary, at: Vector3, rad: float) -> void:
	var col: Color = st.get("col", SPARK)
	match String(st.get("fx", "spark")):
		"dust":
			# Ojo con el orden: el penúltimo par es (gravedad, apertura) y el último el radio de
			# emisión. El TAMAÑO es el argumento 7: ponerle ahí el radio de la zona daba
			# partículas de 3 m y la cámara se metía dentro, como ya pasó con el gas.
			_burst("dirt_02", at + Vector3(0, 0.2, 0), Color(0.62, 0.52, 0.38, 0.95),
				90, 1.1, 3.5, 0.9, -3.0, 80.0, rad * 0.8)
			_burst("smoke_04", at + Vector3(0, 0.3, 0), Color(0.70, 0.62, 0.50, 0.7),
				45, 1.6, 1.6, 1.5, 0.3, 70.0, rad * 0.9)
			for k in 8:
				var a := TAU * k / 8.0
				_burst("dirt_03", at + Vector3(cos(a), 0.1, sin(a)) * rad * 0.85,
					Color(0.55, 0.46, 0.33, 0.9), 12, 0.9, 2.6, 0.5, -3.0, 85.0, 0.4)
		"arrows":
			# Caen de arriba: nacen a 6 m y la gravedad fuerte las clava en el suelo. `_burst`
			# siempre lanza hacia arriba, así que la caída tiene que salir de la gravedad.
			# Pocas y finas: 70 partículas aditivas en una bola de 2,5 m se suman hasta dar un
			# disco crema opaco, no una andanada. Se ven mejor 34 estrías que 70 manchas.
			_burst("trace_01", at + Vector3(0, 6.0, 0), Color(col.r, col.g, col.b, 0.5),
				34, 0.85, 0.6, 0.22, -18.0, 15.0, rad * 0.95)
			_burst("dirt_01", at + Vector3(0, 0.15, 0), Color(0.6, 0.55, 0.4, 0.8),
				30, 0.8, 1.6, 0.5, -2.0, 80.0, rad * 0.8)
		_:
			for k in int(st.get("bolts", 0)):
				var a := TAU * k / maxi(1, int(st["bolts"]))
				_spark(at + Vector3(cos(a), 0, sin(a)) * rad * 0.6 * rng.randf())


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


func _damage_player(amount: float) -> void:
	if _php <= 0.0:
		return
	var mult := (1.0 - _buff_resist) if _buff_left > 0.0 else 1.0
	if _guard:
		mult *= GUARD_DAMAGE_MULT
	_php -= amount * mult
	_hurt_t = 0.25
	if _php <= 0.0:
		_php = 0.0
		_streak = 0
		_pdead_t = RESPAWN_TIME
		_play_all(player_anims, "Death01")


func _player_attack() -> void:
	var origin := player.global_position
	var facing := Vector3(sin(player_model.rotation.y), 0, cos(player_model.rotation.y))
	var hits := 0
	for z in zombies:
		if z["dead_t"] >= 0.0:
			continue
		var body: CharacterBody3D = z["node"]
		var to := body.global_position - origin
		to.y = 0.0
		if to.length() > ATTACK_RANGE:
			continue
		if facing.angle_to(to.normalized()) > ATTACK_ARC:
			continue
		z["hp"] -= ATTACK_DMG
		z["bar_t"] = BAR_SHOW
		hits += 1
		if z["hp"] <= 0.0:
			_kill_zombie(z)


func _kill_zombie(z: Dictionary) -> void:
	z["dead_t"] = 0.0
	if float(z.get("spore_t", 0.0)) > 0.0:
		_spore_burst(z)
	_kills += 1
	_streak += 1
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
	_pdead_t -= delta
	if _pdead_t > 0.0:
		return
	var c := _spawn_cell()
	player.position = _cell_pos(c.x, c.y) + Vector3(0, 0.3, 0)
	_php = PLAYER_HP
	_play_all(player_anims, "Idle")


func _build_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	hud = Label.new()
	hud.position = Vector2(14, 10)
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
					switch_legend(1)
				KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6, KEY_7:
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


func _attack() -> void:
	if _attacking or _php <= 0.0 or player_anim == null or not player_anim.has_animation("Sword_Attack"):
		return
	_attacking = true
	_play_all(player_anims, "Sword_Attack")
	_player_attack()


func _on_anim_done(name: StringName) -> void:
	if name == "Sword_Attack":
		_attacking = false


func _physics_process(delta: float) -> void:
	if player == null:
		return
	_hurt_t = maxf(0.0, _hurt_t - delta)
	_tick_player_death(delta)
	_tick_powers(delta)
	_tick_horde(delta)
	_tick_zone(delta)
	var basis := cam.global_transform.basis
	var fwd := -basis.z
	fwd.y = 0.0
	fwd = fwd.normalized()
	var right := basis.x
	right.y = 0.0
	right = right.normalized()

	var wish := Vector3.ZERO
	var winding_dash := _windup >= 0.0 and _windup_idx >= 0 and String(_abil(_windup_idx)["k"]) == "dash"
	var locked := _dash_left > 0.0 or winding_dash or (_buff_left > 0.0 and _buff_root) \
		or _swing_charge_t >= CHARGE_MIN
	if locked:
		pass
	elif touch and _php > 0.0:
		wish = right * _joy_vec.x - fwd * _joy_vec.y
	elif not locked and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and _php > 0.0:
		if Input.is_physical_key_pressed(KEY_W): wish += fwd
		if Input.is_physical_key_pressed(KEY_S): wish -= fwd
		if Input.is_physical_key_pressed(KEY_D): wish += right
		if Input.is_physical_key_pressed(KEY_A): wish -= right
	var moving := wish.length() > 0.01
	if moving:
		wish = wish.normalized()
	# Agacharse: Ctrl mantenido. Frena mucho, pero dentro de una mancha de hierba alta te borra
	# del mapa para las criaturas.
	_crouch = not locked and _php > 0.0 and (Input.is_physical_key_pressed(KEY_CTRL) or _touch_crouch)
	var spd := legend_speed()
	if _crouch:
		spd *= CROUCH_MULT
	elif Input.is_physical_key_pressed(KEY_SHIFT):
		spd *= 1.6

	player.velocity.x = wish.x * spd
	player.velocity.z = wish.z * spd
	player.velocity.y -= GRAVITY * delta
	if player.is_on_floor() and player.velocity.y < 0.0:
		player.velocity.y = -1.0
	player.move_and_slide()

	if moving and player_model != null:
		var target := atan2(wish.x, wish.z)
		player_model.rotation.y = lerp_angle(player_model.rotation.y, target, TURN_SPEED * delta)

	_cast_anim_t = maxf(0.0, _cast_anim_t - delta)
	if player_anim != null and not _attacking and _cast_anim_t <= 0.0 and _php > 0.0:
		var want := ("Crouch_Fwd" if moving else "Crouch_Idle") if _crouch \
			else ("Jog_Fwd" if moving else "Idle")
		if not player_anim.has_animation(want):
			want = "Jog_Fwd" if moving else "Idle"
		if player_anim.current_animation != want:
			_play_all(player_anims, want)
		for ap2 in player_anims:
			ap2.speed_scale = (spd / legend_speed()) if moving else 1.0

	# La cámara baja con el jugador: agachado detrás de un peñasco tienes que ver lo mismo que él.
	var want_h := _cam_height * (0.62 if _crouch else 1.0)
	pivot.global_position = player.global_position + Vector3(0, want_h, 0)
	pivot.rotation.y = _yaw
	spring.rotation.x = _pitch


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
	if _streak >= 10:
		return mini(_kills, 11)
	if _streak >= 3:
		return mini(_streak, 9)
	return 0


func _show_badge(badge: int) -> void:
	if badge == 0 or not KILL_REWARD_NAMES.has(badge):
		return
	print("INSIGNIA %d: %s  (racha %d, bajas %d)" % [badge, KILL_REWARD_NAMES[badge], _streak, _kills])
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
	if int(ab.get("chg", 0)) > 0:
		return "[%s %d/%d]" % [name, _chg[i], int(ab["chg"])]
	if _cd[i] > 0.0:
		return "[%s %.0fs]" % [name, _cd[i]]
	return "[%s LISTA]" % name

var _log_t := 0.0
var _last_anim := ""
var _fx_t := 0.0

func _process(_d: float) -> void:
	if touch_ui != null:
		touch_ui.queue_redraw()
	if _args.has("fxtest") and player != null:
		# mantiene rayos y una esfera a la vista, para poder juzgarlos en una captura
		_fx_t -= _d
		if _fx_t <= 0.0:
			_fx_t = 0.12
			var f := Vector3(sin(player_model.rotation.y), 0, cos(player_model.rotation.y))
			_spark(player.global_position + f * 4.0 + Vector3(rng.randf_range(-1.5, 1.5), 0, rng.randf_range(-1.5, 1.5)))
			if bolts.is_empty():
				# El proyectil de la leyenda, sea cual sea su ranura: el Rompemareas lo tiene en
				# la 1 (el Enganche), no en la básica, y antes salía una bola con los datos del
				# mandoble.
				var pi := 0
				for k in 3:
					if String(_abil(k)["k"]) == "proj":
						pi = k
						break
				_cast_projectile(_abil(pi), player.global_position + f * 16.0)
			if _decoy_alive().is_empty() and String(_abil(1)["k"]) == "decoy":
				_do_cast(1, player.global_position + f * 4.0)   # para ver el botón de intercambio
			# Si la definitiva es una zona, se relanza en bucle: así el estallido (el polvo del
			# Terremoto, la andanada de la Lluvia) siempre está a la vista para juzgarlo.
			if storms.is_empty() and String(_abil(2)["k"]) == "zone":
				_do_cast(2, player.global_position + f * float(_abil(2).get("rng", 0.0)) * PX)
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
	var cx := int(round(player.global_position.x / CELL + mw * 0.5))
	var cy := int(round(player.global_position.z / CELL + mh * 0.5))
	var zone := "campo"
	if cx >= 0 and cx < mw and cy >= 0 and cy < mh:
		zone = ["campo", "cueva", "cementerio"][zones[cx][cy]]
	var estado := "MUERTO — vuelves en %.0f s" % maxf(_pdead_t, 0.0) if _php <= 0.0 else "vida %d/%d" % [int(_php), int(PLAYER_HP)]
	var oculto := ""
	if _crouch:
		oculto = "  ·  AGACHADO" + ("  ·  OCULTO" if player_hidden() else "")
	hud.text = ("%s  ·  OLEADA %d   ·   criaturas vivas %d   ·   por salir %d   ·   bajas %d   ·   %s%s\n"
		+ "%d FPS   |   %d props   |   celda %d,%d (%s)%s\n"
		+ "%s   %s   %s\n"
		+ "clic izq / Q · clic der o E (mantener para ver el radio) · R definitiva\n"
		+ "WASD mover · Shift correr · Ctrl agacharse · ratón girar · rueda zoom · C cámara · Esc ratón · F10 salir") % [
		String(LEGENDS[_legend]["name"]), _wave, zombies.size(), _left_to_spawn, _kills, estado, oculto,
		Engine.get_frames_per_second(), _props, cx, cy, zone, _zone_hud(),
		_slot(0), _slot(1), _slot(2)]
