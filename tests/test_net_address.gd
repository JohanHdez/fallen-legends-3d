## Prueba de lógica pura de las direcciones de servidor: `godot --headless --path . -s tests/test_net_address.gd`
## `NetAddress.parse` decide el transporte por la forma de la dirección: "wss://host" y "ws://host" van por
## WebSocket (TCP 443/80, atraviesa proxys y redes que bloquean UDP; necesario en Railway, que no admite UDP
## de entrada) y cualquier otra cosa por ENet/UDP, admitiendo "ip", "ip:puerto" y nombres de dominio.
extends SceneTree

func _init() -> void:
	var failures := 0
	var d := 7777

	# ENet: IP sola, IP con puerto, dominio, vacío (-> local).
	var a := NetAddress.parse("1.2.3.4", d)
	failures += _check("ip sola", a.transport == "enet" and a.host == "1.2.3.4" and a.port == d, a)
	a = NetAddress.parse(" 1.2.3.4:9000 ", d)
	failures += _check("ip con puerto y espacios", a.transport == "enet" and a.host == "1.2.3.4" and a.port == 9000, a)
	a = NetAddress.parse("juego.ejemplo.com", d)
	failures += _check("dominio", a.transport == "enet" and a.host == "juego.ejemplo.com" and a.port == d, a)
	a = NetAddress.parse("", d)
	failures += _check("vacío es local", a.transport == "enet" and a.host == "127.0.0.1" and a.port == d, a)
	a = NetAddress.parse("1.2.3.4:noesnumero", d)
	failures += _check("puerto no numérico se ignora", a.host == "1.2.3.4:noesnumero" and a.port == d, a)

	# WebSocket: el esquema manda; el puerto por defecto es 443 (wss) u 80 (ws) y la url viaja entera.
	a = NetAddress.parse("wss://juego.up.railway.app", d)
	failures += _check("wss", a.transport == "ws" and a.url == "wss://juego.up.railway.app" and a.port == 443, a)
	a = NetAddress.parse("ws://192.168.1.5:8080", d)
	failures += _check("ws con puerto", a.transport == "ws" and a.url == "ws://192.168.1.5:8080" and a.port == 8080, a)
	a = NetAddress.parse("WSS://Juego.Ejemplo.Com/sala", d)
	failures += _check("esquema en mayúsculas", a.transport == "ws" and a.url.begins_with("wss://"), a)
	a = NetAddress.parse("  wss://juego.ejemplo.com  ", d)
	failures += _check("wss con espacios", a.transport == "ws" and a.url == "wss://juego.ejemplo.com", a)

	# Sin esquema nunca es WebSocket: "ws" podría ser un nombre de máquina de la red local.
	a = NetAddress.parse("ws", d)
	failures += _check("'ws' a secas es enet", a.transport == "enet" and a.host == "ws", a)

	print("test_net_address: %d fallos" % failures)
	quit(1 if failures > 0 else 0)

func _check(name: String, ok: bool, got: Variant) -> int:
	if not ok:
		print("FALLO: %s -> %s" % [name, got])
	return 0 if ok else 1
