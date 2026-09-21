## Códec del juego en línea: controles (cliente -> servidor, 30 Hz) y fotos (servidor -> cliente,
## 20 Hz) a bytes y de vuelta. Puro (sin nodos) para probarlo con `godot -s`
## (tests/test_net_codec.gd). Diseño: docs/superpowers/specs/2026-09-18-juego-en-linea-design.md
## (§ Protocolo); plan: docs/superpowers/plans/2026-09-20-juego-en-linea-f2-partida.md (Task 1).
##
## Todo cuantizado con StreamPeerBuffer: posiciones en 16 bits (`MAP_MAX` de media anchura del
## mundo: el mapa son 42×42 celdas de 3 m, 126 m de lado, y sobra margen), yaw en 8 bits (256 pasos,
## menos de 1,5° de error), vida como fracción en 8 bits (×255) y la animación como índice de un
## byte en `ANIMS`, la tabla fija de las que de verdad se ven en una partida por equipos (unión de
## HERO_ANIMS y HERO_ANIMS_2 de data/legend_data.gd: ninguna otra biblioteca se injerta en un
## Fighter jugable). Un mensaje corto o a medias (cliente trucado, paquete cortado por la red)
## devuelve {} en vez de reventar: cada `decode_*` comprueba los bytes que quedan antes de leer.
class_name NetCodec
extends RefCounted

## Media anchura del mundo en metros: las posiciones se cuantizan a 16 bits dentro de ±MAP_MAX.
const MAP_MAX := 200.0

## Tamaño fijo de un control (Task 3): seq (u32) + wish.x/y (i8×2) + yaw (u8) + banderas (u8).
const INPUT_SIZE := 8

## Encabezado de una foto: t (float) + ack (u32) + zone (float) + clock (float) + round (u8) +
## número de leyendas (u8) + número de criaturas (u8), más los tres bytes de lo TUYO (abajo).
## Los tres van en el ENCABEZADO, no en la lista de leyendas, porque la foto ya se codifica una vez
## por jugador (net/net_server.gd: cada uno lleva su propio `ack`): cuestan 3 bytes por foto en
## total, no 3 por leyenda.
const SNAPSHOT_HEADER_SIZE := 22
## Una leyenda: id (u16) + pos (u16×3) + yaw (u8) + anim (u8) + vida (u8) + banderas (u8).
const ACTOR_FIGHTER_SIZE := 12
## Una criatura (Horda, F3): igual que una leyenda pero sin banderas (ni derribo ni marca).
const ACTOR_CREATURE_SIZE := 11

## Animaciones que de verdad se ven en una partida por equipos: copiadas a mano de
## LegendData.HERO_ANIMS + HERO_ANIMS_2 (2026-09-20; tests/test_net_codec.gd vigila que no se
## desincronicen). Un índice de un byte cuesta poco, así que van TODAS las injertadas en un Fighter
## jugable, no solo las que usa cada leyenda: la tabla es del protocolo, no de una leyenda.
const ANIMS: PackedStringArray = [
	"Idle", "Jog_Fwd", "Jog_Bwd", "Jog_Left", "Jog_Right", "Sword_Attack", "Spell_Simple_Shoot",
	"Death01", "Roll", "Crouch_Idle", "Crouch_Fwd", "Crouch_Bwd", "Crouch_Left", "Crouch_Right",
	"Crawl_Idle", "Crawl_Fwd", "Crawl_Bwd", "Crawl_Left", "Crawl_Right", "Fixing_Kneeling",
	"Hit_Chest", "Hit_Head", "Hit_Shoulder_L", "Hit_Shoulder_R", "Idle_Tired", "Pistol_Shoot",
	"Spell_Double_Shoot", "Spell_Double_Enter", "OverhandThrow", "Sword_Regular_A",
	"Sword_Regular_B", "Sword_Regular_C", "Sword_Regular_Combo", "Sword_Dash", "Shield_Dash",
	"Consume", "Idle_Rail_Call",
]


## Índice de una animación en ANIMS; 0 ("Idle") si no está, para que un nombre nuevo sin injertar en
## la tabla no reviente al codificar (se queda de pie en vez de crashear).
static func anim_index(name: String) -> int:
	var i := ANIMS.find(name)
	return i if i >= 0 else 0


## Nombre de una animación por su índice; "Idle" si el índice no existe (foto de un cliente trucado
## o de una versión distinta del protocolo).
static func anim_name(index: int) -> String:
	if index < 0 or index >= ANIMS.size():
		return "Idle"
	return ANIMS[index]


## {"seq": int, "wish": Vector2, "run": bool, "crouch": bool, "basic": bool, "yaw": float} -> bytes.
static func encode_input(d: Dictionary) -> PackedByteArray:
	var buf := StreamPeerBuffer.new()
	buf.put_u32(maxi(int(d.get("seq", 0)), 0))
	var wish: Vector2 = d.get("wish", Vector2.ZERO)
	buf.put_8(_axis_to_i8(wish.x))
	buf.put_8(_axis_to_i8(wish.y))
	buf.put_u8(_yaw_to_u8(float(d.get("yaw", 0.0))))
	var flags := 0
	if bool(d.get("run", false)):
		flags |= 1
	if bool(d.get("crouch", false)):
		flags |= 2
	if bool(d.get("basic", false)):
		flags |= 4
	buf.put_u8(flags)
	return buf.data_array


## bytes -> el mismo diccionario que encode_input, o {} si no llegan los INPUT_SIZE bytes (paquete
## a medias o basura de un cliente trucado).
static func decode_input(b: PackedByteArray) -> Dictionary:
	if b.size() < INPUT_SIZE:
		return {}
	var buf := StreamPeerBuffer.new()
	buf.data_array = b
	var seq := buf.get_u32()
	var wx := _i8_to_axis(buf.get_8())
	var wy := _i8_to_axis(buf.get_8())
	var yaw := _u8_to_yaw(buf.get_u8())
	var flags := buf.get_u8()
	return {
		"seq": seq,
		"wish": Vector2(wx, wy),
		"run": (flags & 1) != 0,
		"crouch": (flags & 2) != 0,
		"basic": (flags & 4) != 0,
		"yaw": yaw,
	}


## {"t", "ack", "fighters": Array, "zone", "clock", "round", "creatures": Array (opcional, F3)} ->
## bytes. Cada leyenda: {"id", "pos": Vector3, "yaw", "anim": int, "hp", "downed", "marked"}; cada
## criatura, lo mismo sin "downed" ni "marked".
## "ammo" (disparos enteros), "ammo_t" (0..1, lo que falta para que vuelva el siguiente) y
## "ult_charge" (0..1) son de QUIEN RECIBE la foto, no de una leyenda de la lista: son lo único de
## su ficha que el cliente no puede predecir solo -gastar munición y cargar la definitiva los decide
## el servidor, no el botón-, así que sin ellos el HUD del cliente mentía (2026-09-20).
static func encode_snapshot(d: Dictionary) -> PackedByteArray:
	var buf := StreamPeerBuffer.new()
	buf.put_float(float(d.get("t", 0.0)))
	buf.put_u32(maxi(int(d.get("ack", 0)), 0))
	buf.put_u8(clampi(int(d.get("ammo", 0)), 0, 255))
	buf.put_u8(_frac_to_u8(float(d.get("ammo_t", 0.0))))
	buf.put_u8(_frac_to_u8(float(d.get("ult_charge", 0.0))))
	buf.put_float(float(d.get("zone", 0.0)))
	buf.put_float(float(d.get("clock", 0.0)))
	buf.put_u8(clampi(int(d.get("round", 0)), 0, 255))
	var fighters: Array = d.get("fighters", [])
	var creatures: Array = d.get("creatures", [])
	var nf := mini(fighters.size(), 255)
	var nc := mini(creatures.size(), 255)
	buf.put_u8(nf)
	buf.put_u8(nc)
	for i in nf:
		_put_actor(buf, fighters[i], true)
	for i in nc:
		_put_actor(buf, creatures[i], false)
	return buf.data_array


## bytes -> el mismo diccionario que encode_snapshot (con "creatures" siempre presente, vacío si no
## venía ninguna), o {} si los bytes no alcanzan para lo que el propio encabezado declara: no hay
## que confiar en un cliente trucado ni en un paquete cortado por la red.
static func decode_snapshot(b: PackedByteArray) -> Dictionary:
	var buf := StreamPeerBuffer.new()
	buf.data_array = b
	buf.seek(0)
	if buf.get_available_bytes() < SNAPSHOT_HEADER_SIZE:
		return {}
	var t := buf.get_float()
	var ack := buf.get_u32()
	var ammo := buf.get_u8()
	var ammo_t := _u8_to_frac(buf.get_u8())
	var ult_charge := _u8_to_frac(buf.get_u8())
	var zone := buf.get_float()
	var clock := buf.get_float()
	var round_n := buf.get_u8()
	var nf := buf.get_u8()
	var nc := buf.get_u8()
	var need := nf * ACTOR_FIGHTER_SIZE + nc * ACTOR_CREATURE_SIZE
	if buf.get_available_bytes() < need:
		return {}
	var fighters: Array = []
	fighters.resize(nf)
	for i in nf:
		fighters[i] = _get_actor(buf, true)
	var creatures: Array = []
	creatures.resize(nc)
	for i in nc:
		creatures[i] = _get_actor(buf, false)
	return {"t": t, "ack": ack, "fighters": fighters, "zone": zone, "clock": clock,
		"round": round_n, "creatures": creatures,
		"ammo": ammo, "ammo_t": ammo_t, "ult_charge": ult_charge}


static func _put_actor(buf: StreamPeerBuffer, a: Dictionary, with_flags: bool) -> void:
	buf.put_u16(clampi(int(a.get("id", 0)), 0, 65535))
	var pos: Vector3 = a.get("pos", Vector3.ZERO)
	buf.put_u16(_pos_to_u16(pos.x))
	buf.put_u16(_pos_to_u16(pos.y))
	buf.put_u16(_pos_to_u16(pos.z))
	buf.put_u8(_yaw_to_u8(float(a.get("yaw", 0.0))))
	buf.put_u8(clampi(int(a.get("anim", 0)), 0, 255))
	buf.put_u8(_frac_to_u8(float(a.get("hp", 0.0))))
	if with_flags:
		var flags := 0
		if bool(a.get("downed", false)):
			flags |= 1
		if bool(a.get("marked", false)):
			flags |= 2
		buf.put_u8(flags)


static func _get_actor(buf: StreamPeerBuffer, with_flags: bool) -> Dictionary:
	var id := buf.get_u16()
	var x := _u16_to_pos(buf.get_u16())
	var y := _u16_to_pos(buf.get_u16())
	var z := _u16_to_pos(buf.get_u16())
	var yaw := _u8_to_yaw(buf.get_u8())
	var anim := buf.get_u8()
	var hp := _u8_to_frac(buf.get_u8())
	var out := {"id": id, "pos": Vector3(x, y, z), "yaw": yaw, "anim": anim, "hp": hp}
	if with_flags:
		var flags := buf.get_u8()
		out["downed"] = (flags & 1) != 0
		out["marked"] = (flags & 2) != 0
	return out


## Un eje del joystick (-1..1) a un byte con signo: 127 pasos, sobra para que no se note.
static func _axis_to_i8(v: float) -> int:
	return int(roundf(clampf(v, -1.0, 1.0) * 127.0))


## Al revés. El clamp NO sobra: un byte de -128 (que `_axis_to_i8` nunca produce, pero que un
## cliente trucado sí puede mandar a mano) daría un eje de -1,008 y, con los dos ejes, un empujón de
## magnitud 1,43. Hoy `Combat.move_fighter` normaliza y no pasaría nada, pero este fichero es el
## borde donde se deja de confiar en el cliente: se corta aquí (revisión de la tarea 1, 2026-09-20).
static func _i8_to_axis(v: int) -> float:
	return clampf(float(v) / 127.0, -1.0, 1.0)


## Coordenada dentro de ±MAP_MAX a 16 bits sin signo: (400 m de rango) / 65536 pasos ≈ 6 mm de
## error, invisible (comentario del plan).
static func _pos_to_u16(v: float) -> int:
	var c := clampf(v, -MAP_MAX, MAP_MAX)
	var frac := (c + MAP_MAX) / (2.0 * MAP_MAX)
	return clampi(int(roundf(frac * 65535.0)), 0, 65535)


static func _u16_to_pos(u: int) -> float:
	var frac := float(u) / 65535.0
	return frac * (2.0 * MAP_MAX) - MAP_MAX


## Ángulo en radianes a un byte (256 pasos de TAU/256 ≈ 1,4° cada uno, así que el error queda por
## debajo de 1,5°, lo que pide el plan).
static func _yaw_to_u8(yaw: float) -> int:
	var a := fposmod(yaw, TAU)
	return int(roundf(a / TAU * 256.0)) % 256


static func _u8_to_yaw(u: int) -> float:
	return float(u) / 256.0 * TAU


## Fracción 0..1 (de vida sobre la máxima) a un byte: ×255, como pide el plan.
static func _frac_to_u8(v: float) -> int:
	return clampi(int(roundf(clampf(v, 0.0, 1.0) * 255.0)), 0, 255)


static func _u8_to_frac(u: int) -> float:
	return float(u) / 255.0
