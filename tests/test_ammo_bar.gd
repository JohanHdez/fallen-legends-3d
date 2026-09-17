## Prueba de lógica pura de AmmoBar (ui/ammo_bar.gd), sin escena:
##   godot --headless --path . -s tests/test_ammo_bar.gd
## Cuánto se llena cada segmento según el nivel de munición (Fighter.ammo_level): los llenos,
## el que está volviendo a medias y los vacíos.
extends SceneTree

var failures := 0


func _check(ok: bool, msg: String) -> void:
	if not ok:
		print("FALLO: " + msg)
		failures += 1


func _init() -> void:
	# 1,25 = uno lleno, el segundo a un cuarto, el tercero vacío.
	_check(is_equal_approx(AmmoBar.segment_fill(1.25, 0), 1.0), "primer segmento lleno")
	_check(is_equal_approx(AmmoBar.segment_fill(1.25, 1), 0.25), "segundo a un cuarto")
	_check(is_equal_approx(AmmoBar.segment_fill(1.25, 2), 0.0), "tercero vacío")
	# Llena y vacía.
	for i in 3:
		_check(is_equal_approx(AmmoBar.segment_fill(3.0, i), 1.0), "llena: segmento %d lleno" % i)
		_check(is_equal_approx(AmmoBar.segment_fill(0.0, i), 0.0), "vacía: segmento %d vacío" % i)
	# Solo el que está volviendo cuenta como parcial.
	_check(AmmoBar.is_partial(1.25, 1) and not AmmoBar.is_partial(1.25, 0) and not AmmoBar.is_partial(1.25, 2),
		"solo el segundo está volviendo")
	_check(not AmmoBar.is_partial(2.0, 2), "con 2 justos el tercero aún no se dibuja volviendo")
	print("test_ammo_bar: %s (%d fallos)" % ["OK" if failures == 0 else "FALLO", failures])
	quit(1 if failures > 0 else 0)
