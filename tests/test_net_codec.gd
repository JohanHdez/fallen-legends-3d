## Prueba pura del códec de red (net/net_codec.gd), sin conexión:
##   godot --headless --path . -s tests/test_net_codec.gd
## Comprueba la ida y vuelta de un control (cliente -> servidor) y de una foto (servidor -> cliente):
## error de cuantización, tamaño en bytes con el presupuesto del spec (≤ 30 KB/s a 20 fotos/s, unos
## 1500 bytes/s por foto de sobra) y que la basura (bytes a medias, de un cliente trucado o de la
## red) no revienta el juego. Diseño: docs/superpowers/specs/2026-09-18-juego-en-linea-design.md
## (§ Protocolo); plan: docs/superpowers/plans/2026-09-20-juego-en-linea-f2-partida.md (Task 1).
extends SceneTree

var failures := 0


func _check(ok: bool, msg: String) -> void:
	if not ok:
		print("FALLO: " + msg)
		failures += 1


func _init() -> void:
	_test_input_roundtrip()
	_test_input_garbage()
	_test_input_trucado()
	_test_snapshot_roundtrip()
	_test_snapshot_size()
	_test_snapshot_garbage()
	_test_anims_table()
	print("test_net_codec: %s (%d fallos)" % ["OK" if failures == 0 else "FALLO", failures])
	quit(1 if failures > 0 else 0)


## Ida y vuelta de un control de 30 Hz: número de secuencia, joystick, correr/agachar/básica y el
## yaw con el que orientarse (Task 3 lo manda con cada control).
func _test_input_roundtrip() -> void:
	var sent := {"seq": 12345, "wish": Vector2(0.7, -0.4), "run": true, "crouch": false,
		"basic": true, "yaw": 2.35}
	var bytes := NetCodec.encode_input(sent)
	var got := NetCodec.decode_input(bytes)
	_check(not got.is_empty(), "decode_input de bytes válidos no da {}")
	_check(int(got.get("seq", -1)) == 12345, "seq va y vuelve igual (%s)" % got.get("seq"))
	var w: Vector2 = got.get("wish", Vector2.ZERO)
	_check(w.distance_to(sent["wish"]) < 0.02, "wish va y vuelve casi igual (%s vs %s)" % [w, sent["wish"]])
	_check(got.get("run", false) == true and got.get("crouch", true) == false and got.get("basic", false) == true,
		"banderas de correr/agachar/básica van y vuelven igual (%s)" % got)
	var dyaw: float = absf(angle_difference(float(got.get("yaw", 0.0)), sent["yaw"]))
	_check(dyaw < deg_to_rad(1.5), "yaw del control por debajo de 1,5° de error (%.3f°)" % rad_to_deg(dyaw))

	# Con los extremos: run/crouch/basic a false, wish en (0,0) y en las esquinas (-1,-1)/(1,1).
	for wish in [Vector2.ZERO, Vector2(-1, -1), Vector2(1, 1)]:
		var b2 := NetCodec.encode_input({"seq": 0, "wish": wish, "run": false, "crouch": false, "basic": false, "yaw": 0.0})
		var g2 := NetCodec.decode_input(b2)
		_check(g2.get("wish", Vector2(99, 99)).distance_to(wish) < 0.02, "wish en la esquina %s va y vuelve" % wish)


## Un cliente trucado (o un paquete a medias por la red) manda menos bytes de los que hacen falta:
## no debe reventar, tiene que devolver {} para que quien llama lo ignore sin más.
func _test_input_garbage() -> void:
	_check(NetCodec.decode_input(PackedByteArray()).is_empty(), "decode_input de un paquete vacío da {}")
	var full := NetCodec.encode_input({"seq": 1, "wish": Vector2(0.5, 0.5), "run": true, "crouch": true, "basic": true, "yaw": 1.0})
	_check(NetCodec.decode_input(full.slice(0, 3)).is_empty(), "decode_input de un control a medias (3 de %d bytes) da {}" % full.size())


## Un cliente trucado no manda lo que manda encode_input: manda los bytes que le da la gana. El eje
## sale de un byte con signo, y -128 (que encode_input nunca produce) daría 1,008 por eje y un
## empujón de magnitud 1,43 (hallazgo de la revisión de la tarea 1, 2026-09-20). El códec es el
## borde donde se deja de confiar en el cliente: aquí se corta, no más adelante.
func _test_input_trucado() -> void:
	var buf := StreamPeerBuffer.new()
	buf.put_u32(7)          # seq
	buf.put_8(-128)         # wish.x al límite del byte
	buf.put_8(-128)         # wish.y
	buf.put_u8(0)           # banderas
	buf.put_u8(0)           # yaw
	var d := NetCodec.decode_input(buf.data_array)
	_check(not d.is_empty(), "el control fabricado a mano se lee")
	if d.is_empty():
		return
	var w: Vector2 = d["wish"]
	_check(absf(w.x) <= 1.0 and absf(w.y) <= 1.0, "cada eje se queda en [-1, 1]: %v" % w)
	_check(w.length() <= 1.4149, "y el empujón no pasa de la diagonal (%.3f)" % w.length())


## Ida y vuelta de una foto de 8 leyendas (4v4 lleno): posición, yaw, animación, vida, derribo y
## marca de cada una. El error de posición por debajo de 1 cm y el de yaw por debajo de 1,5° (README
## § "el error de cuantización no se nota").
func _test_snapshot_roundtrip() -> void:
	var fighters := []
	for i in 8:
		fighters.append({
			"id": i,
			# Repartidas por casi todo el mundo (±200 m), no solo cerca del centro, para que el error
			# de cuantización se mida en el peor caso, no en el mejor.
			"pos": Vector3(-190.0 + i * 54.0, 0.3 + i * 0.1, 150.0 - i * 40.0),
			"yaw": fmod(float(i) * 0.9, TAU),
			"anim": i % NetCodec.ANIMS.size(),
			"hp": clampf(1.0 - i * 0.12, 0.0, 1.0),
			"downed": i == 3,
			"marked": i == 5,
		})
	var sent := {"t": 12.5, "ack": 999, "fighters": fighters, "zone": 0.42, "clock": 87.5, "round": 2,
		"ammo": 2, "ammo_t": 0.4, "ult_charge": 0.73}
	var bytes := NetCodec.encode_snapshot(sent)
	var got := NetCodec.decode_snapshot(bytes)
	_check(not got.is_empty(), "decode_snapshot de bytes válidos no da {}")
	_check(int(got.get("round", -1)) == 2, "la ronda va y vuelve igual")
	_check(int(got.get("ack", -1)) == 999, "el ack va y vuelve igual")
	# Lo TUYO (2026-09-20): munición, lo que falta para el próximo disparo y la carga de la
	# definitiva. Sin esto el cliente pintaba el botón con su propia cuenta optimista mientras el
	# servidor ya no disparaba nada.
	_check(int(got.get("ammo", -1)) == 2, "la munición va y vuelve igual")
	_check(absf(float(got.get("ammo_t", -1.0)) - 0.4) <= 1.0 / 255.0 + 0.0001, "lo que falta del disparo que vuelve, por debajo de 1/255")
	_check(absf(float(got.get("ult_charge", -1.0)) - 0.73) <= 1.0 / 255.0 + 0.0001, "la carga de la definitiva, por debajo de 1/255")
	_check(absf(float(got.get("t", -1.0)) - 12.5) < 0.01, "el instante va y vuelve igual")
	_check(absf(float(got.get("zone", -1.0)) - 0.42) < 0.01, "la zona va y vuelve igual")
	_check(absf(float(got.get("clock", -1.0)) - 87.5) < 0.01, "el reloj va y vuelve igual")
	var back: Array = got.get("fighters", [])
	_check(back.size() == 8, "vuelven las 8 leyendas (%d)" % back.size())
	var max_pos_err := 0.0
	var max_yaw_err := 0.0
	for i in back.size():
		var f: Dictionary = back[i]
		var orig: Dictionary = fighters[i]
		var perr: float = (f["pos"] as Vector3).distance_to(orig["pos"])
		max_pos_err = maxf(max_pos_err, perr)
		var yerr: float = absf(angle_difference(float(f["yaw"]), float(orig["yaw"])))
		max_yaw_err = maxf(max_yaw_err, yerr)
		_check(int(f["id"]) == orig["id"], "id de la leyenda %d va y vuelve" % i)
		_check(int(f["anim"]) == orig["anim"], "anim de la leyenda %d va y vuelve (%s vs %s)" % [i, f["anim"], orig["anim"]])
		_check(absf(float(f["hp"]) - orig["hp"]) <= 1.0 / 255.0 + 0.0001, "vida de la leyenda %d por debajo de 1/255 de error" % i)
		_check(bool(f["downed"]) == orig["downed"], "derribo de la leyenda %d va y vuelve" % i)
		_check(bool(f["marked"]) == orig["marked"], "marca de la leyenda %d va y vuelve" % i)
	_check(max_pos_err < 0.01, "error de posición por debajo de 1 cm (peor caso %.4f m)" % max_pos_err)
	_check(max_yaw_err < deg_to_rad(1.5), "error de yaw por debajo de 1,5° (peor caso %.3f°)" % rad_to_deg(max_yaw_err))
	print("  medido: error de posición %.4f m, error de yaw %.3f°" % [max_pos_err, rad_to_deg(max_yaw_err)])


## Presupuesto de bytes del spec (§ Protocolo): una foto de 8 leyendas por debajo de 200 bytes; con
## 40 criaturas de la Horda (F3), por debajo de 700. A 20 fotos/s eso deja de sobra el objetivo de
## ≤ 30 KB/s por jugador.
func _test_snapshot_size() -> void:
	var fighters := []
	for i in 8:
		fighters.append({"id": i, "pos": Vector3(i * 10.0, 0.0, -i * 5.0), "yaw": 0.3 * i,
			"anim": i, "hp": 1.0, "downed": false, "marked": false})
	var small := NetCodec.encode_snapshot({"t": 1.0, "ack": 1, "fighters": fighters, "zone": 0.0, "clock": 0.0, "round": 1})
	_check(small.size() < 200, "8 leyendas por debajo de 200 bytes (%d)" % small.size())
	print("  medido: %d bytes con 8 leyendas" % small.size())

	var creatures := []
	for i in 40:
		creatures.append({"id": 100 + i, "pos": Vector3(i * 2.0, 0.0, i * -2.0), "yaw": 0.1 * i,
			"anim": i % NetCodec.ANIMS.size(), "hp": 0.8})
	var big := NetCodec.encode_snapshot({"t": 1.0, "ack": 1, "fighters": fighters, "creatures": creatures,
		"zone": 0.0, "clock": 0.0, "round": 1})
	_check(big.size() < 700, "8 leyendas + 40 criaturas por debajo de 700 bytes (%d)" % big.size())
	print("  medido: %d bytes con 8 leyendas + 40 criaturas" % big.size())
	var back := NetCodec.decode_snapshot(big)
	_check(back.get("creatures", []).size() == 40, "las 40 criaturas vuelven (%d)" % back.get("creatures", []).size())


## Un cliente trucado puede mandar cualquier cosa: bytes vacíos, un mensaje a medias (declara más
## leyendas o criaturas de las que trae) tiene que dar {} y no una excepción que tire el servidor.
func _test_snapshot_garbage() -> void:
	_check(NetCodec.decode_snapshot(PackedByteArray()).is_empty(), "decode_snapshot de un paquete vacío da {}")
	_check(NetCodec.decode_snapshot(PackedByteArray([1, 2, 3])).is_empty(), "decode_snapshot de 3 bytes sueltos da {}")
	var fighters := []
	for i in 8:
		fighters.append({"id": i, "pos": Vector3.ZERO, "yaw": 0.0, "anim": 0, "hp": 1.0, "downed": false, "marked": false})
	var full := NetCodec.encode_snapshot({"t": 1.0, "ack": 1, "fighters": fighters, "zone": 0.0, "clock": 0.0, "round": 1})
	# A medio camino de la lista de leyendas: el encabezado dice 8 pero solo llegan datos para menos.
	var half := full.slice(0, full.size() - 20)
	_check(NetCodec.decode_snapshot(half).is_empty(), "decode_snapshot de una foto cortada a medias da {} (%d de %d bytes)" % [half.size(), full.size()])
	# Solo el encabezado, ninguna leyenda.
	_check(NetCodec.decode_snapshot(full.slice(0, 5)).is_empty(), "decode_snapshot de solo 5 bytes del encabezado da {}")


## La tabla de animaciones es la unión de las que de verdad se ven en una partida por equipos
## (HERO_ANIMS + HERO_ANIMS_2 de data/legend_data.gd: ninguna otra biblioteca se injerta en un
## Fighter jugable). Cabe en un byte (≤ 255) y no tiene huecos ni repetidos.
func _test_anims_table() -> void:
	var expected := (LegendData.HERO_ANIMS + "," + LegendData.HERO_ANIMS_2).split(",")
	_check(NetCodec.ANIMS.size() == expected.size(), "NetCodec.ANIMS trae todas las animaciones de HERO_ANIMS* (%d vs %d)" % [NetCodec.ANIMS.size(), expected.size()])
	for name in expected:
		_check(NetCodec.ANIMS.has(name), "NetCodec.ANIMS incluye %s" % name)
	_check(NetCodec.ANIMS.size() <= 255, "la tabla de animaciones cabe en un byte (%d)" % NetCodec.ANIMS.size())
	var seen := {}
	for name in NetCodec.ANIMS:
		_check(not seen.has(name), "%s no está repetida en NetCodec.ANIMS" % name)
		seen[name] = true
	_check(NetCodec.anim_index("Idle") == NetCodec.ANIMS.find("Idle"), "anim_index encuentra Idle")
	_check(NetCodec.anim_name(NetCodec.anim_index("Sword_Attack")) == "Sword_Attack", "anim_name deshace anim_index")
	_check(NetCodec.anim_index("Esto_No_Existe") == 0, "una animación desconocida no revienta: cae en el índice 0")
