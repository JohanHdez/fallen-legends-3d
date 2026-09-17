## Prueba de las reglas puras de las órdenes del Rey liche (game/minions.gd), sin escena:
##   godot --headless --path . -s tests/test_minions.gd
## Petición del usuario (2026-09-17): Reagrupar = lo siguen separados unos de otros; Emboscada = se
## esconden en una zona que eliges y saltan todos si pasa un enemigo; tocar alterna Atacar/Reagrupar.
extends SceneTree

var failures := 0


func _check(ok: bool, msg: String) -> void:
	if not ok:
		print("FALLO: " + msg)
		failures += 1


func _init() -> void:
	# Formación: 4 en el anillo de 2 m, 6 en el de 3,5 m, separados.
	var slots: Array[Vector2] = []
	for i in 10:
		slots.append(Minions.formation_slot(i))
	for i in 4:
		_check(is_equal_approx(slots[i].length(), Minions.RING_IN), "hueco %d a %.2f m (debería %.1f)" % [i, slots[i].length(), Minions.RING_IN])
	for i in range(4, 10):
		_check(is_equal_approx(slots[i].length(), Minions.RING_OUT), "hueco %d a %.2f m (debería %.1f)" % [i, slots[i].length(), Minions.RING_OUT])
	_check(_min_gap(slots) >= 1.4, "en formación hay dos a %.2f m (mínimo 1,4)" % _min_gap(slots))

	# Emboscada: dentro de 3 m y sin amontonarse.
	var hide: Array[Vector2] = []
	for i in 10:
		hide.append(Minions.ambush_slot(i, 10))
		_check(hide[i].length() <= Minions.AMBUSH_RADIUS + 0.001, "hueco de emboscada %d fuera de 3 m (%.2f)" % [i, hide[i].length()])
	_check(_min_gap(hide) >= 0.9, "en la emboscada hay dos a %.2f m (mínimo 0,9)" % _min_gap(hide))

	# Tocar alterna; desde la emboscada, tocar manda atacar.
	_check(Minions.toggle("attack") == "regroup", "Atacar -> Reagrupar")
	_check(Minions.toggle("regroup") == "attack", "Reagrupar -> Atacar")
	_check(Minions.toggle("ambush") == "attack", "Emboscada -> Atacar")

	# El punto de emboscada no pasa de 12 m.
	var p := Minions.ambush_point(Vector3.ZERO, Vector3(30, 5, 0))
	_check(is_equal_approx(Vector2(p.x, p.z).length(), Minions.AMBUSH_RANGE) and is_equal_approx(p.y, 0.0), "a 30 m se recorta a 12 m en el suelo (%s)" % p)
	var q := Minions.ambush_point(Vector3(1, 0, 1), Vector3(4, 0, 5))
	_check(q.is_equal_approx(Vector3(4, 0, 5)), "a 5 m se queda donde apuntas")
	_check(is_equal_approx(Minions.SPEED, 200.0 * LegendData.PX), "a la velocidad de los esbirros del 2D")
	print("test_minions: %s (%d fallos)" % ["OK" if failures == 0 else "FALLO", failures])
	quit(1 if failures > 0 else 0)


func _min_gap(pts: Array[Vector2]) -> float:
	var best := INF
	for i in pts.size():
		for j in range(i + 1, pts.size()):
			best = minf(best, pts[i].distance_to(pts[j]))
	return best
