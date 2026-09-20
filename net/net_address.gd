## Dirección de servidor -> transporte. El esquema de la dirección decide cómo se conecta el cliente:
## Copiado de arena-arpg (scripts/net_address.gd) el 2026-09-18 para el juego en línea del 3D.
##   "1.2.3.4", "1.2.3.4:9000", "juego.ejemplo.com"  -> ENet (UDP): lo normal, la mejor latencia.
##   "wss://juego.ejemplo.com", "ws://ip:puerto"      -> WebSocket (TCP): atraviesa proxys y redes que
##      bloquean UDP (wifis de colegios, oficinas, hoteles) y es la única opción en plataformas sin UDP
##      de entrada, como Railway. A cambio, con pérdida de paquetes se nota más tirón que con UDP.
## Sin autoloads para que tests/test_net_address.gd lo cargue con `godot -s`.
class_name NetAddress
extends RefCounted

const WS := "ws"
const ENET := "enet"

## Devuelve {"transport": "enet"|"ws", "host": String, "port": int, "url": String}.
## En ENet `host`/`port` son lo que usa create_client; en WebSocket se conecta con `url` entera.
static func parse(text: String, default_port: int) -> Dictionary:
	var raw := text.strip_edges()
	var lower := raw.to_lower()
	if lower.begins_with("wss://") or lower.begins_with("ws://"):
		var secure := lower.begins_with("wss://")
		var scheme := "wss://" if secure else "ws://"
		var rest := raw.substr(scheme.length())
		var url := scheme + rest
		# Puerto explícito en la autoridad ("host:puerto/lo-que-sea"); si no, el del esquema.
		var authority := rest.split("/")[0]
		var port := 443 if secure else 80
		if authority.contains(":") and not authority.contains("]"):
			var parts := authority.rsplit(":", true, 1)
			if parts.size() == 2 and parts[1].is_valid_int():
				port = int(parts[1])
		return {"transport": WS, "host": authority, "port": port, "url": url}
	var host := raw
	var host_port := default_port
	if host.contains(":") and not host.contains("]"):
		# "ip:puerto" (túneles y servidores en puertos distintos); si lo de after no es un número, se deja tal cual.
		var parts := host.rsplit(":", true, 1)
		if parts.size() == 2 and parts[1].is_valid_int():
			host = parts[0]
			host_port = int(parts[1])
	if host == "":
		host = "127.0.0.1"
	return {"transport": ENET, "host": host, "port": host_port, "url": ""}
