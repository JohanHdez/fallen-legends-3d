## Prueba de la lógica pura del minimapa (ui/minimap.gd), sin escena:
##   godot --headless --path . -s tests/test_minimap.gd
## Petición del usuario (2026-09-17): un mapa arriba a la derecha que gira con la cámara (lo que tienes
## delante, arriba) y enseña en rojo a los enemigos que ve tu equipo: a menos de SIGHT de ti o de un
## compañero y sin esconderse; los marcados siempre y quien acaba de atacar también.
extends SceneTree

var failures := 0


func _check(ok: bool, msg: String) -> void:
	if not ok:
		print("FALLO: " + msg)
		failures += 1


func _near(a: Vector2, b: Vector2) -> bool:
	return a.distance_to(b) < 0.001


func _init() -> void:
	_test_to_map()
	_test_enemy_seen()
	_test_clamp_edge()
	print("test_minimap: %s (%d fallos)" % ["OK" if failures == 0 else "FALLO", failures])
	quit(1 if failures > 0 else 0)


func _test_to_map() -> void:
	# Cámara con yaw 0 mira hacia -Z: lo de delante sale arriba y lo de la derecha (+X), a la derecha.
	_check(_near(Minimap.to_map(0.0, -10.0, 0.0, 2.0), Vector2(0, -20)), "yaw 0: delante, arriba")
	_check(_near(Minimap.to_map(10.0, 0.0, 0.0, 2.0), Vector2(20, 0)), "yaw 0: a la derecha, a la derecha")
	_check(_near(Minimap.to_map(0.0, 10.0, 0.0, 2.0), Vector2(0, 20)), "yaw 0: detrás, abajo")
	# Girada 90° a la izquierda mira hacia -X: eso es lo que sale arriba, y su derecha (basis.x) es -Z.
	var q := PI / 2.0
	_check(_near(Minimap.to_map(-10.0, 0.0, q, 1.0), Vector2(0, -10)), "yaw 90°: -X delante, arriba")
	_check(_near(Minimap.to_map(0.0, -10.0, q, 1.0), Vector2(10, 0)), "yaw 90°: -Z a la derecha")
	var basis := Basis(Vector3.UP, q)
	_check(_near(Minimap.to_map(basis.x.x, basis.x.z, q, 1.0), Vector2(1, 0)), "la derecha de la cámara, a la derecha")
	_check(_near(Minimap.to_map(-basis.z.x, -basis.z.z, q, 1.0), Vector2(0, -1)), "lo que mira la cámara, arriba")
	# Gira pero no deforma: la distancia en el mapa es la del mundo por la escala.
	_check(is_equal_approx(Minimap.to_map(3.0, 4.0, 1.234, 3.0).length(), 15.0), "conserva la distancia")


func _test_enemy_seen() -> void:
	var s := Minimap.SIGHT
	_check(is_equal_approx(s, BotBrain.SEARCH_RANGE), "ve lo mismo que un bot (23 m)")
	_check(Minimap.enemy_seen(false, false, false, s - 1.0), "cerca y a la vista: sale")
	_check(Minimap.enemy_seen(false, false, false, s), "justo en el límite: sale")
	_check(not Minimap.enemy_seen(false, false, false, s + 1.0), "lejos: no sale")
	_check(not Minimap.enemy_seen(false, true, false, 2.0), "escondido (hierba o invisible): no sale aunque esté al lado")
	_check(Minimap.enemy_seen(true, false, false, 200.0), "marcado: sale aunque esté lejos")
	_check(Minimap.enemy_seen(true, true, false, 200.0), "marcado: sale aunque se agache")
	_check(Minimap.enemy_seen(false, false, true, 200.0), "acaba de atacar: sale aunque esté lejos")
	_check(not Minimap.enemy_seen(false, true, true, 200.0), "invisible (la Fiesta) no sale")


func _test_clamp_edge() -> void:
	# Lo que cae fuera del cuadro se pega al borde en su misma dirección.
	_check(_near(Minimap.clamp_edge(Vector2(30, -40), 100.0), Vector2(30, -40)), "dentro no se toca")
	_check(_near(Minimap.clamp_edge(Vector2(300, 0), 100.0), Vector2(100, 0)), "a la derecha, al borde derecho")
	_check(_near(Minimap.clamp_edge(Vector2(200, 200), 100.0), Vector2(100, 100)), "en diagonal, a la esquina")
	_check(_near(Minimap.clamp_edge(Vector2(50, -400), 100.0), Vector2(12.5, -100)), "arriba, al borde de arriba en su dirección")
