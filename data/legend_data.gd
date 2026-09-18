## Datos de leyendas, habilidades y criaturas de Fallen Legends 3D. Movido tal cual desde main.gd
## (2026-09-16) para que el combate, los bots y los menús lean lo mismo sin depender de la escena.
## Las cifras salen de `data/abilities/*.tres`, `data/classes/*.tres` y `data/enemies/*.tres` del
## juego 2D; las que se apartan llevan su porqué al lado. Las distancias van en PÍXELES del 2D y se
## pasan a metros con `PX` al usarlas.
class_name LegendData
extends RefCounted

## Píxeles del 2D a metros: una celda de 3 m son los 192 px de ancho de un tile isométrico de Flare.
const PX := 3.0 / 192.0

# Todo vive DENTRO del proyecto: en un APK no existen las rutas del Mac.
const CHARS := "res://models/chars/"
const OUTFITS := CHARS
const BESTIARY := CHARS
# UAL1 Pro (CC0, Quaternius, 2026-09-17): la misma biblioteca con 120 animaciones en vez de 43. Trae
# las que faltaban para andar de lado y hacia atrás (Jog_Left/Right/Bwd y sus versiones agachadas) y
# para gatear de verdad (Crawl_*), que sustituyen al apaño de nadar del derribo.
const UAL1 := CHARS + "UAL1_Pro.glb"
const UAL2 := CHARS + "UAL2_Standard.glb"

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
		 "dur": 10.0, "stun": 1.0, "chg": 3, "act": 5, "tick": 2.0, "tgt": 3,
		 "anim": "OverhandThrow", "adur": 0.9},   # la lanza a 5 m: se ve el gesto de tirarla
		{"n": "Tormenta eléctrica", "col": Color(0.7, 0.8, 1.0), "sfx": "storm", "k": "zone", "cd": 30.0, "cast": 0.5, "dmg": 45.0, "rng": 520.0, "rad": 340.0,
		 "delay": 0.6, "stun": 3.5, "field": 10.0, "fdmg": 18.0, "fstun": 1.2,
		 "anim": "Spell_Double_Shoot"},          # conjuro a dos manos para la definitiva
	],
	"clerigo": [
		# Desviación del 2D (petición del usuario, 2026-09-17, "para que el clérigo coja más fuerza"):
		# cada golpe que impacta envenena `toxin` s más (hasta Combat.TOXIN_MAX) y la toxina quita
		# `tdmg` por segundo. 2 s × 8 = 16 de daño extra por golpe, tanto como el impacto: con 4 por
		# segundo (lo primero que se midió) le triplicaba el daño pero no le daba victorias.
		{"n": "Golpe sagrado", "col": Color(1.0, 0.95, 0.5), "sfx": "proj_arcane", "k": "proj", "cd": 0.6, "cast": 0.12, "dmg": 16.0, "rng": 680.0, "spd": 620.0, "homing": true,
		 "toxin": 2.0, "tdmg": 8.0},
		# Sanación: el .tres trae 260 px; x3 a petición del usuario (4,1 m -> 12,2 m).
		{"n": "Sanación", "col": Color(0.5, 1.0, 0.5), "sfx": "heal", "k": "heal", "cd": 7.0, "cast": 0.3, "heal": 35.0, "rad": 780.0,
		 "anim": "Spell_Double_Shoot"},
		# Desviación del 2D (petición del usuario, 2026-09-18): el .tres trae 190 px de radio (3,0 m) y
		# aquí van 300 (4,7 m), porque la nube se esquivaba andando. Y al lanzarla se pega al enemigo
		# más cercano que haya bajo el punto apuntado (Combat.SNAP_R).
		{"n": "Esporas", "col": Color(0.5, 1.0, 0.4), "sfx": "gas", "k": "spores", "cd": 40.0, "cast": 0.5, "dmg": 10.0, "rng": 520.0, "rad": 300.0,
		 "field": 10.0, "fdmg": 10.0, "tick": 1.0, "snap": true,
		 "anim": "Consume", "adur": 1.1},        # idea del usuario: se bebe el frasco para soltarlas
	],
	"ilusionista": [
		{"n": "Pistola espectral", "col": Color(0.85, 0.65, 1.0), "sfx": "proj_arcane", "k": "proj", "cd": 0.18, "cast": 0.06, "dmg": 9.0, "rng": 820.0, "spd": 1000.0, "homing": true,
		 "anim": "Pistol_Shoot"},                # lleva pistola: hasta ahora disparaba conjurando
		{"n": "Señuelo", "col": Color(0.75, 0.55, 1.0), "sfx": "decoy", "k": "decoy", "cd": 12.0, "cast": 0.25,
		 "rng": 260.0, "rad": 70.0, "dur": 20.0, "n_decoys": 1, "move": 2, "swap": true, "act": 1},
		{"n": "Fiesta de clones", "col": Color(0.9, 0.6, 1.0), "sfx": "decoy", "k": "decoy", "cd": 35.0, "cast": 0.4,
		 "rng": 0.0, "rad": 110.0, "dur": 20.0, "n_decoys": 5, "move": 1, "invis": 4.0,
		 "anim": "Spell_Double_Shoot",
		 "tough": true},   # desviación: vida ×3 por equipos (en el 2D un golpe los deshace)
	],
	"caballero": [
		{"n": "Lanzada", "col": Color(0.85, 0.85, 0.9), "sfx": "melee", "k": "melee", "cd": 0.8, "cast": 0.2, "dmg": 30.0, "rad": 115.0,
		 "anim": "Sword_Regular_A"},
		# Corte de hacha (antes "Carga con escudo": el Caballero lleva hacha, no escudo).
		# Desviación del 2D (petición del usuario, 2026-09-18, "es muy lenta... debería poder escapar
		# usando esa habilidad muy rápido, y activársele cada 5 segundos y la cadencia y área de daño
		# deben aumentar"): recarga 7 -> 5 s, radio 70 -> 130 px (1,1 -> 2,0 m), daño 25 -> 32 y SIN
		# "sync": ya no dura lo que la animación (1,57 s para 10,9 m, un paseo) sino lo que marca
		# `spd` (1500 px/s = 23,4 m/s -> 0,47 s), con la animación acelerada al triple. Además
		# Combat.cast_dash le quita el `slow_t`: con el gas encima era todavía más lenta.
		{"n": "Corte de hacha", "col": Color(0.8, 0.3, 0.3), "sfx": "dash", "k": "dash", "cd": 5.0,
		 "cast": 0.12, "dmg": 32.0, "rng": 700.0, "rad": 130.0, "spd": 1500.0, "shove": 5.5,
		 "anim": "Sword_Dash"},
		# Muro de espinas: el .tres trae 46 px de radio; x3 a petición del usuario (0,7 m -> 2,2 m).
		{"n": "Muro de espinas", "col": Color(0.85, 0.35, 0.3), "sfx": "spikes", "k": "spikes", "cd": 25.0, "cast": 0.5, "dmg": 20.0, "rng": 840.0, "rad": 138.0,
		 "dur": 10.0, "stun": 2.0, "tick": 1.0,
		 "anim": "OverhandThrow", "adur": 1.0},
	],
	"rompemareas": [
		# Idea del usuario (2026-09-17): el mandoble normal es Sword_Regular_C y el CARGADO el combo.
		{"n": "Mandoble de ancla", "col": Color(0.85, 0.72, 0.45), "sfx": "melee", "k": "melee", "cd": 1.1, "cast": 0.3,
		 "dmg": 60.0, "rad": 170.0, "charge": true, "dust": true, "arc": 180.0,
		 "anim": "Sword_Regular_C", "adur": 1.0, "anim_charged": "Sword_Regular_Combo", "adur_charged": 1.6},
		# "Enganche", no "Arponazo": lo que lanza es su ANCLA encadenada, no un arpón (nombre
		# elegido por el usuario). SIN teledirigir (petición suya): se clava donde apuntaste, no
		# persigue a nadie. A cambio `catch` es ancho —190 px = 3,0 m— para que el que estaba ahí
		# cuando la tiraste siga entrando aunque se haya movido un poco. Dos números que ya NO coinciden con `data/abilities/arponazo.tres`, los dos a
		# petición suya: recarga 20 s (el .tres dice 7) y alcance 1200 px = 19 m (el .tres dice 520
		# = 8,3 m). `--cd=N` recorta las recargas para probar sin esperar.
		{"n": "Enganche", "col": Color(0.8, 0.68, 0.42), "sfx": "harpoon", "k": "proj", "cd": 20.0, "cast": 0.3, "dmg": 34.0, "rng": 1200.0, "spd": 780.0,
		 "stun": 0.5, "pull": true, "solid": "anchor", "catch": 190.0,
		 "anim": "OverhandThrow", "adur": 1.0},  # lanza el ancla por encima del hombro
		# Desviación del 2D (petición del usuario, 2026-09-18): el ancla se clava DONDE APUNTAS (hasta
		# 8,1 m) y ya no lo deja plantado —fuera "root"—, así que puede elegir dónde amontonar a los
		# enemigos y seguir peleando. El remolino tira de ellos en 4,7 m ("rad"), lo que antes era el
		# alcance.
		{"n": "Ancla clavada", "col": Color(0.85, 0.7, 0.4), "sfx": "buff", "k": "buff", "cd": 26.0, "cast": 0.5, "dmg": 26.0, "rng": 520.0, "rad": 300.0, "dur": 5.0,
		 "resist": 0.3, "tick": 0.8,
		 "anim": "Sword_Regular_B"},             # tajo de arriba abajo: clava el ancla en el suelo
	],
	"liche": [
		# Desviaciones del 2D (petición del usuario, 2026-09-18, "no dispara lo suficientemente rápido,
		# es malo contra todos"): el rayo sale cada 0,5 s en vez de 0,7 y los esqueletos se alzan cada
		# 4,5 s en vez de cada 6 (sus otros arreglos están en Minions). El DAÑO se queda en los 26 del
		# 2D: con 28 ganaba 10 de 12 duelos por parejas, más que ninguna.
		{"n": "Rayo gélido", "col": Color(0.5, 0.9, 1.0), "sfx": "proj_frost", "k": "proj", "cd": 0.5, "cast": 0.14, "dmg": 26.0, "rng": 700.0, "spd": 650.0, "homing": true},
		{"n": "Alzar esqueleto", "col": Color(0.85, 0.9, 0.75), "sfx": "summon", "k": "summon", "cd": 4.5, "cast": 0.3, "rad": 70.0, "chg": 3, "count": 1,
		 "anim": "Spell_Double_Shoot"},
		{"n": "Alzar ejército", "col": Color(0.8, 0.9, 0.7), "sfx": "summon", "k": "summon", "cd": 30.0, "cast": 0.6, "rng": 400.0, "rad": 90.0, "count": 7,
		 "anim": "Spell_Double_Enter"},          # levanta a los siete con las dos manos
	],
	"quimico": [
		{"n": "Frasco corrosivo", "col": Color(0.75, 0.95, 0.3), "sfx": "proj_flask", "k": "proj", "cd": 0.6, "cast": 0.12, "dmg": 20.0, "rng": 640.0, "spd": 640.0, "homing": true,
		 "anim": "OverhandThrow", "adur": 0.55},  # tira el frasco (rápido: uno cada 0,6 s)
		{"n": "Baliza Nox", "col": Color(0.75, 0.95, 0.3), "sfx": "trap", "k": "beacon", "cd": 10.0, "cast": 0.3,
		 "dmg": 8.0, "rng": 320.0, "rad": 320.0, "dur": 10.0, "chg": 3, "act": 5, "tick": 0.5, "slow": 0.5,
		 "anim": "OverhandThrow", "adur": 1.0},
		{"n": "Granada Nox", "col": Color(0.6, 0.95, 0.25), "sfx": "gas", "k": "gas", "cd": 30.0, "cast": 0.5, "dmg": 10.0, "rng": 560.0, "rad": 460.0,
		 "field": 20.0, "fdmg": 10.0, "tick": 1.0, "slow": 0.5,
		 "anim": "OverhandThrow", "adur": 1.1},
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

## Munición de la básica por equipos (idea del usuario, 2026-09-16; el 2D NO la tiene): `n` disparos
## que vuelven de uno en uno cada `reload` s, estilo Brawl, para que fallar cueste. Con esto las de
## distancia sostienen un 40 % menos de daño con la básica (cadencia/recarga: 0,6/1,0 y 0,7/1,15) y
## las cuerpo a cuerpo un 20 % (0,8/1,0 y 1,1/1,4), que ya les cuesta llegar. La Ilusionista NO está,
## a propósito (petición del usuario): no tiene habilidades de daño y su ventaja es la cantidad de
## disparos, así que dispara sin límite.
const PVP_AMMO := {
	"tormentero": {"n": 3, "reload": 1.0},
	"clerigo": {"n": 3, "reload": 1.0},
	"quimico": {"n": 3, "reload": 1.0},
	"liche": {"n": 3, "reload": 1.0},    # su rayo es lo único que tiene de lejos (usuario, 2026-09-18)
	"caballero": {"n": 3, "reload": 1.0},
	"rompemareas": {"n": 3, "reload": 1.4},
}

## Daño de la básica por equipos (petición del usuario, 2026-09-16; el 2D NO lo tiene): la
## Ilusionista necesitaba ~70 balas de 9 para tumbar a cualquiera y perdía 28 de 36 duelos. Solo por
## equipos: en la Horda su pistola sigue con el número del 2D.
const PVP_BASIC_DMG := {
	"ilusionista": 1.6,
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
	# Desviación del 2D (petición del usuario, 2026-09-17): allí se llama "Químico"; aquí lleva el
	# modelo de un diablillo con mazo y el usuario pidió un nombre acorde. El `id` NO cambia: es el
	# que casa con los datos del 2D.
	{"id": "quimico", "name": "Trasgo Nox", "hp": 230.0, "speed": 225.0, "tint": Color.WHITE,
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

# Solo se injertan las animaciones que se usan: copiarlas las 120 de la Pro por personaje cuesta caro
# cuando hay 70 criaturas en pantalla.
# Roll = la voltereta de Retirada del Arquero. Las de UAL2 van en su propia pasada.
# Cuatro direcciones para andar, para andar agachado y para arrastrarse derribado (Combat.move_anim
# elige según hacia dónde mira), Fixing_Kneeling es el gesto de quien levanta a un compañero, las
# Hit_* son la queja al recibir un golpe (por dónde le han dado) e Idle_Tired es cómo se queda de pie
# con menos de media vida (peticiones del usuario, 2026-09-17).
const HERO_ANIMS := "Idle,Jog_Fwd,Jog_Bwd,Jog_Left,Jog_Right,Sword_Attack,Spell_Simple_Shoot,Death01,Roll," \
	+ "Crouch_Idle,Crouch_Fwd,Crouch_Bwd,Crouch_Left,Crouch_Right," \
	+ "Crawl_Idle,Crawl_Fwd,Crawl_Bwd,Crawl_Left,Crawl_Right,Fixing_Kneeling," \
	+ "Hit_Chest,Hit_Head,Hit_Shoulder_L,Hit_Shoulder_R,Idle_Tired," \
	+ "Pistol_Shoot,Spell_Double_Shoot,Spell_Double_Enter"
# Sword_Regular_A (0,43 s) y _B (0,53 s) miden casi lo que dura un preaviso, así que salen a
# velocidad casi natural. Sword_Heavy_Combo dura 4,33 s: estirado al preaviso salía a 12x, un
# temblor en vez de un mazazo.
const HERO_ANIMS_2 := "OverhandThrow,Sword_Regular_A,Sword_Regular_B,Sword_Regular_C,Sword_Regular_Combo," \
	+ "Sword_Dash,Shield_Dash,Consume,Idle_Rail_Call"
const ZOMBIE_ANIMS_1 := "Death01,Sword_Attack"
const ZOMBIE_ANIMS_2 := "Zombie_Idle,Zombie_Walk_Fwd,Zombie_Scratch"
