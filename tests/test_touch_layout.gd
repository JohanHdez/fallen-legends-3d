## Prueba del reparto de los controles táctiles (main.gd), sin escena:
##   godot --headless --path . -s tests/test_touch_layout.gd
## El botón de agacharse (petición del usuario: "no vi la opción de agacharme") mide al menos 64 px
## y queda fuera de la zona que agarra el joystick, que responde hasta JOY_GRAB veces su radio.
extends SceneTree

var failures := 0


func _check(ok: bool, msg: String) -> void:
	if not ok:
		print("FALLO: " + msg)
		failures += 1


func _init() -> void:
	_check(PlayerInput.CROUCH_RADIUS * 2.0 >= 64.0, "el botón de agacharse mide %.0f px (mínimo 64)" % (PlayerInput.CROUCH_RADIUS * 2.0))
	for h in [720.0, 1080.0]:
		var joy := Vector2(190.0, h - 250.0)
		var c := PlayerInput.crouch_center(joy)
		var grab := PlayerInput.JOY_RADIUS * PlayerInput.JOY_GRAB
		_check(c.distance_to(joy) >= grab + PlayerInput.CROUCH_RADIUS,
			"a %d px de alto el botón pisa la zona del joystick (%.0f < %.0f)" % [h, c.distance_to(joy), grab + PlayerInput.CROUCH_RADIUS])
		_check(c.x - PlayerInput.CROUCH_RADIUS >= 0.0 and c.y - PlayerInput.CROUCH_RADIUS >= 70.0, "a %d px de alto el botón se sale por arriba o a la izquierda" % h)
	# Botón de órdenes del Rey liche: fuera de la básica (60 px), la táctica (46) y la definitiva (46),
	# con los mismos desplazamientos que main.input.button_rects(), y de 64 px o más.
	_check(PlayerInput.ORDERS_RADIUS * 2.0 >= 64.0, "el botón de órdenes mide %.0f px" % (PlayerInput.ORDERS_RADIUS * 2.0))
	for other in [[Vector2.ZERO, PlayerInput.MAIN_SIDE / 2.0], [Vector2(-170.0, 20.0), PlayerInput.ABILITY_SIDE / 2.0], [Vector2(-60.0, -165.0), PlayerInput.ABILITY_SIDE / 2.0]]:
		var gap: float = PlayerInput.ORDERS_OFFSET.distance_to(other[0]) - PlayerInput.ORDERS_RADIUS - float(other[1])
		_check(gap >= 8.0, "el botón de órdenes queda a %.0f px de un botón de habilidad" % gap)
	# Correr en el móvil (2026-09-18): el joystick al borde. Tiene que quedar por encima de la zona
	# muerta y por debajo de 1, o no se llegaría nunca.
	_check(PlayerInput.JOY_RUN > PlayerInput.DEAD_ZONE and PlayerInput.JOY_RUN < 1.0, "el umbral de correr (%.2f) es alcanzable" % PlayerInput.JOY_RUN)
	_check(PlayerInput.JOY_RUN >= 0.8, "y no se corre sin querer al andar (%.2f)" % PlayerInput.JOY_RUN)
	print("test_touch_layout: %s (%d fallos)" % ["OK" if failures == 0 else "FALLO", failures])
	quit(1 if failures > 0 else 0)
