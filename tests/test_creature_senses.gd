## Prueba de los sentidos de las criaturas (game/creature_senses.gd), sin escena:
##   godot --headless --path . -s tests/test_creature_senses.gd
## Petición del usuario (2026-09-17): agachado en la hierba no te ven, pero si pasan cerca o por encima
## sí; la que te descubre avisa a las que estén a 30 m; de noche se ve menos y los muros tapan.
extends SceneTree

var failures := 0


func _check(ok: bool, msg: String) -> void:
	if not ok:
		print("FALLO: " + msg)
		failures += 1


func _init() -> void:
	# Alcance de la vista: 12 m de día, 8 m de noche cerrada.
	_check(is_equal_approx(CreatureSenses.sight_range(0.0), 12.0), "de día se ve a 12 m")
	_check(is_equal_approx(CreatureSenses.sight_range(1.0), 8.0), "de noche se ve a 8 m")
	_check(CreatureSenses.sight_range(0.5) < 12.0 and CreatureSenses.sight_range(0.5) > 8.0, "al anochecer, en medio")

	# A la vista.
	_check(CreatureSenses.can_see(11.0, false, false, 0.0, true), "de día a 11 m y sin muros: te ve")
	_check(not CreatureSenses.can_see(13.0, false, false, 0.0, true), "de día a 13 m: no te ve")
	_check(not CreatureSenses.can_see(9.0, false, false, 1.0, true), "de noche a 9 m: no te ve")
	_check(not CreatureSenses.can_see(5.0, false, false, 0.0, false), "con un muro en medio: no te ve")

	# Escondido: solo pegado; quien ya te persigue, algo más lejos. Pegado da igual el muro.
	_check(CreatureSenses.can_see(1.4, true, false, 0.0, false), "escondido y pasa por encima: te ve")
	_check(not CreatureSenses.can_see(2.0, true, false, 0.0, true), "escondido a 2 m: no te ve")
	_check(CreatureSenses.can_see(3.9, true, true, 1.0, true), "escondido pero te persigue a 3,9 m: te sigue viendo")
	_check(not CreatureSenses.can_see(4.5, true, true, 0.0, true), "escondido y te persigue a 4,5 m: te pierde")

	# Línea de visión en la rejilla (grid[x][y]). Muro en la columna x = 2, y = 1..3; el agua no tapa.
	var grid: Array = []
	for x in 5:
		var col := PackedInt32Array()
		for y in 5:
			col.append(MapBuilder.WALL if x == 2 and y >= 1 and y <= 3 else MapBuilder.FLOOR)
		grid.append(col)
	(grid[2] as PackedInt32Array)[4] = MapBuilder.WATER
	_check(CreatureSenses.los_clear(grid, Vector2i(0, 4), Vector2i(4, 4)), "por encima del agua se ve")
	_check(not CreatureSenses.los_clear(grid, Vector2i(0, 2), Vector2i(4, 2)), "el muro tapa en recto")
	_check(CreatureSenses.los_clear(grid, Vector2i(0, 0), Vector2i(4, 0)), "por encima del muro se ve")
	_check(CreatureSenses.los_clear(grid, Vector2i(1, 2), Vector2i(1, 2)), "la misma celda se ve")

	# El grito: a 30 m, en el plano.
	_check(CreatureSenses.hears(Vector3.ZERO, Vector3(29.0, 0, 0)), "a 29 m oye el grito")
	_check(not CreatureSenses.hears(Vector3.ZERO, Vector3(0, 0, 31.0)), "a 31 m no lo oye")
	_check(CreatureSenses.hears(Vector3.ZERO, Vector3(20.0, 15.0, 20.0)), "la altura no cuenta")
	print("test_creature_senses: %s (%d fallos)" % ["OK" if failures == 0 else "FALLO", failures])
	quit(1 if failures > 0 else 0)
