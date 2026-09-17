## Prueba de lógica pura de BotBrain (game/bot_brain.gd), sin escena:
##   godot --headless --path . -s tests/test_bot_brain.gd
## Cuándo dispara con munición (guarda el último disparo para cuando esté cerca) y cómo rodea una
## zona enemiga que se ve (trampa, baliza, nube, tormenta, espinas): sale si está dentro, no entra
## si va hacia ella y no se desvía si no le estorba.
extends SceneTree

var failures := 0


func _check(ok: bool, msg: String) -> void:
	if not ok:
		print("FALLO: " + msg)
		failures += 1


func _init() -> void:
	_test_should_shoot()
	_test_steer_around()
	print("test_bot_brain: %s (%d fallos)" % ["OK" if failures == 0 else "FALLO", failures])
	quit(1 if failures > 0 else 0)


func _test_should_shoot() -> void:
	# Sin munición (Horda, Ilusionista): a tiro, dispara.
	_check(BotBrain.should_shoot(0, 0, 9.0, 10.0), "sin límite y a tiro dispara")
	_check(not BotBrain.should_shoot(0, 0, 11.0, 10.0), "sin límite y fuera de alcance no dispara")
	# Con munición de sobra: a tiro, dispara.
	_check(BotBrain.should_shoot(3, 3, 9.0, 10.0), "con 3 y a tiro dispara")
	_check(BotBrain.should_shoot(2, 3, 9.0, 10.0), "con 2 y a tiro dispara")
	_check(not BotBrain.should_shoot(2, 3, 10.5, 10.0), "con 2 y fuera de alcance no dispara")
	# El último disparo lo guarda para cuando tiene más opciones de acertar.
	_check(not BotBrain.should_shoot(1, 3, 9.0, 10.0), "con el último, al borde del alcance no dispara")
	_check(BotBrain.should_shoot(1, 3, 10.0 * BotBrain.LAST_SHOT_REACH - 0.1, 10.0), "con el último y cerca dispara")
	# Vacío: nunca.
	_check(not BotBrain.should_shoot(0, 3, 1.0, 10.0), "sin munición no dispara")


func _test_steer_around() -> void:
	var c := Vector3(10, 0, 0)
	var r := 5.0
	# Lejos: no se desvía.
	var far := Vector3(-10, 0, 0)
	var d := Vector3(1, 0, 0)
	_check(BotBrain.steer_around(far, d, c, r).is_equal_approx(d), "lejos de la zona no se desvía")
	# Al borde y alejándose, o de lado: no se desvía.
	var edge := Vector3(10 - r - 0.5, 0, 0)          # a medio metro del borde, a la izquierda
	var away := Vector3(-1, 0, 0)
	_check(BotBrain.steer_around(edge, away, c, r).is_equal_approx(away), "si se aleja no se desvía")
	var sideways := Vector3(0, 0, 1)
	_check(BotBrain.steer_around(edge, sideways, c, r).is_equal_approx(sideways), "si va de lado no se desvía")
	# Al borde y yendo hacia dentro en diagonal: sigue de lado, sin entrar.
	var diag := Vector3(1, 0, 1).normalized()
	var s1 := BotBrain.steer_around(edge, diag, c, r)
	_check(s1.length() > 0.1, "en diagonal hacia la zona sigue moviéndose")
	_check(s1.dot(away) >= 0.0, "en diagonal hacia la zona no entra (%s)" % s1)
	_check(s1.dot(sideways) > 0.0, "en diagonal hacia la zona conserva su lado (%s)" % s1)
	# Al borde y de frente al centro: elige un lado y no entra.
	var s2 := BotBrain.steer_around(edge, Vector3(1, 0, 0), c, r)
	_check(s2.length() > 0.1, "de frente a la zona sigue moviéndose")
	_check(s2.dot(away) >= 0.0, "de frente a la zona no entra (%s)" % s2)
	# Dentro: sale, vaya hacia donde vaya.
	var inside := Vector3(8, 0, 1)
	var out := (inside - c).normalized()
	for want in [Vector3(1, 0, 0), Vector3(-1, 0, 0), Vector3(0, 0, -1), Vector3.ZERO]:
		var s3 := BotBrain.steer_around(inside, want, c, r)
		_check(s3.dot(out) > 0.0, "dentro de la zona sale (quería %s, va %s)" % [want, s3])
	# Justo en el centro: sale igual.
	_check(BotBrain.steer_around(c, Vector3.ZERO, c, r).length() > 0.1, "en el centro exacto sale hacia algún lado")
	# La altura no cuenta.
	var high := Vector3(far.x, 3.0, far.z)
	_check(BotBrain.steer_around(high, d, c, r).is_equal_approx(d), "la altura no cambia nada")
