## Juego en línea, servidor (tarea 3 de docs/superpowers/plans/2026-09-20-juego-en-linea-f2-partida.md):
## traduce el control que mandó un jugador (el Dictionary que devuelve NetCodec.decode_input) al
## Fighter que maneja, exactamente como lo haría su teclado o su joystick en local: solo escribe
## `wish`, `run`, `crouch`, `holding_basic` y el yaw con el que mira (Combat.face_dir lo usa para
## orientarlo, porque el servidor no tiene ratón que leer). NO lanza ninguna habilidad: eso es
## `_cast`, aparte y fiable (net/net.gd), porque un botón no se puede perder como un control de 30 Hz.
class_name RemoteControl
extends RefCounted


## `input` es el Dictionary de NetCodec.decode_input: {"wish": Vector2, "run", "crouch", "basic",
## "yaw"}. "basic" es holding_basic (mantener la básica carga el mandoble del Rompemareas, igual que
## en local). `wish` ya llega en el plano del mundo (x, z): el cliente lo calculó con su propia
## cámara, como hoy hace main.gd sin red.
static func apply(f: Fighter, input: Dictionary) -> void:
	var wish: Vector2 = input.get("wish", Vector2.ZERO)
	f.wish = Vector3(wish.x, 0.0, wish.y)
	f.run = bool(input.get("run", false))
	f.crouch = bool(input.get("crouch", false))
	f.holding_basic = bool(input.get("basic", false))
	f.aim_yaw = float(input.get("yaw", 0.0))
