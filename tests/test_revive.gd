## Prueba de las reglas puras del derribo y la reanimación (game/revive.gd), sin escena:
##   godot --headless --path . -s tests/test_revive.gd
## Petición del usuario (2026-09-17): a 0 de vida quedas DERRIBADO, arrastrándote despacio; tienes 45 s
## para que un compañero agachado a tu lado te levante (3 s, con media vida); si no, mueres y la baja
## es de quien te derribó. Los golpes a un derribado le quitan tiempo. Muerto ya no se reanima.
extends SceneTree

var failures := 0


func _check(ok: bool, msg: String) -> void:
	if not ok:
		print("FALLO: " + msg)
		failures += 1


func _init() -> void:
	# Derribado: 45 s para que te levanten, arrastrándose a un cuarto de su velocidad.
	_check(is_equal_approx(Revive.BLEED_TIME, 45.0), "45 s derribado")
	_check(is_equal_approx(Revive.CRAWL_SPEED, 0.25), "se arrastra al 25 %% de su velocidad")

	# Rematar: el daño quita tiempo; el de media vida máxima se lo quita todo.
	var hp := 630.0
	_check(is_equal_approx(Revive.bleed_after_hit(45.0, 0.0, hp), 45.0), "sin daño no pierde tiempo")
	_check(is_equal_approx(Revive.bleed_after_hit(45.0, hp * Revive.FINISH_HP * 0.5, hp), 22.5), "un cuarto de vida le quita la mitad del tiempo")
	_check(is_equal_approx(Revive.bleed_after_hit(45.0, hp * Revive.FINISH_HP, hp), 0.0), "media vida de daño lo remata")
	_check(is_equal_approx(Revive.bleed_after_hit(10.0, hp, hp), 0.0), "no baja de 0")
	_check(Revive.bleed_after_hit(45.0, 22.0, hp) < 45.0 and Revive.bleed_after_hit(45.0, 22.0, hp) > 40.0, "un golpe normal quita unos segundos")

	# Levantar: 3 s agachado al lado; si se va, el progreso baja al mismo ritmo.
	_check(is_equal_approx(Revive.TIME, 3.0), "levantar tarda 3 s")
	_check(is_equal_approx(Revive.progress(0.0, true, 1.5), 0.5), "a mitad de tiempo, a mitad de progreso")
	_check(is_equal_approx(Revive.progress(0.5, false, 0.75), 0.25), "si se va, el progreso baja")
	_check(is_equal_approx(Revive.progress(0.9, true, 1.0), 1.0), "no pasa de 1")
	_check(is_equal_approx(Revive.progress(0.1, false, 1.0), 0.0), "no baja de 0")
	_check(is_equal_approx(Revive.RANGE, 90.0 * LegendData.PX), "alcance: 90 px del 2D (1,4 m)")
	_check(Revive.can_help(true, true, Revive.RANGE - 0.05), "vivo, agachado y al lado: ayuda")
	_check(not Revive.can_help(true, false, 0.5), "de pie no levanta: hay que agacharse")
	_check(not Revive.can_help(false, true, 0.5), "derribado no levanta")
	_check(not Revive.can_help(true, true, Revive.RANGE + 0.1), "demasiado lejos no levanta")
	_check(is_equal_approx(Revive.HP, 0.5) and is_equal_approx(Revive.INVULN, 3.0), "media vida y 3 s de inmunidad")
	print("test_revive: %s (%d fallos)" % ["OK" if failures == 0 else "FALLO", failures])
	quit(1 if failures > 0 else 0)
