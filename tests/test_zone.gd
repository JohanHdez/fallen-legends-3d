## Prueba del gas demoníaco (main.gd), sin escena:
##   godot --headless --path . -s tests/test_zone.gd
## Hasta dónde se cierra: en la Horda se para al 60 % del radio inicial (petición del usuario: "no es
## necesario que la zona avance tanto en el modo zombie"); por equipos, hasta ZONE_MIN como siempre.
extends SceneTree

var failures := 0


func _check(ok: bool, msg: String) -> void:
	if not ok:
		print("FALLO: " + msg)
		failures += 1


func _init() -> void:
	_check(is_equal_approx(Main.HORDE_ZONE_STOP, 0.6), "en la Horda se para al 60 %%")
	_check(is_equal_approx(Main.zone_floor(63.0, false), 63.0 * 0.6), "Horda: 63 m de radio inicial se para en 37,8 m")
	_check(is_equal_approx(Main.zone_floor(41.0, true), Main.ZONE_MIN), "por equipos cierra hasta ZONE_MIN")
	_check(Main.zone_floor(63.0, false) > Main.ZONE_MIN, "la Horda deja más sitio que los modos por equipos")
	print("test_zone: %s (%d fallos)" % ["OK" if failures == 0 else "FALLO", failures])
	quit(1 if failures > 0 else 0)
