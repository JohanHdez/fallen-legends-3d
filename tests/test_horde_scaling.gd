## Prueba de la dificultad de la Horda (game/horde.gd), sin escena:
##   godot --headless --path . -s tests/test_horde_scaling.gd
## Petición del usuario (2026-09-17): "fue muy fácil", "los zombis y los perros muy dóciles" y "mientras
## avancen las zonas podríamos hacerlos un poco más difíciles". Daño de base más alto, +10 % de vida por
## oleada (el HP_PER_WAVE del 2D) y, por cada tramo que cierra el gas (4), más vida, daño y velocidad.
extends SceneTree

var failures := 0


func _check(ok: bool, msg: String) -> void:
	if not ok:
		print("FALLO: " + msg)
		failures += 1


func _init() -> void:
	# Tramo del gas: 0 mientras espera; al empezar a cerrar, 1; y uno más por cada cuarto del cierre.
	var r0 := 63.0
	var stop := 37.8
	_check(Horde.gas_stage(r0, r0, stop, false) == 0, "esperando: tramo 0")
	_check(Horde.gas_stage(r0, r0, stop, true) == 1, "al empezar a cerrar: tramo 1")
	_check(Horde.gas_stage(r0, r0 - (r0 - stop) * 0.3, stop, true) == 2, "al 30 %% del cierre: tramo 2")
	_check(Horde.gas_stage(r0, r0 - (r0 - stop) * 0.6, stop, true) == 3, "al 60 %% del cierre: tramo 3")
	_check(Horde.gas_stage(r0, stop, stop, true) == 4, "cerrado del todo: tramo 4")
	_check(Horde.GAS_STAGES == 4, "cuatro tramos")

	# Vida: +10 % por oleada y +STAGE_HP por tramo.
	_check(is_equal_approx(Horde.hp_mult(1, 0), 1.0), "oleada 1 sin gas: vida normal")
	_check(is_equal_approx(Horde.hp_mult(3, 0), 1.2), "oleada 3: +20 %%")
	_check(is_equal_approx(Horde.hp_mult(1, 2), 1.0 + 2.0 * Horde.STAGE_HP), "tramo 2: +2 tramos de vida")
	_check(is_equal_approx(Horde.hp_mult(3, 2), 1.2 * (1.0 + 2.0 * Horde.STAGE_HP)), "oleada y tramo se multiplican")

	# Daño y velocidad: base más alta y crecen por tramo.
	_check(Horde.CREATURE_DMG > 1.0, "las criaturas pegan más que en el 2D (%.2f)" % Horde.CREATURE_DMG)
	_check(is_equal_approx(Horde.dmg_mult(0), Horde.CREATURE_DMG), "sin gas: el daño de base")
	_check(is_equal_approx(Horde.dmg_mult(4), Horde.CREATURE_DMG * (1.0 + 4.0 * Horde.STAGE_DMG)), "tramo 4: daño de base por 4 tramos")
	_check(is_equal_approx(Horde.speed_mult(0), 1.0), "sin gas: velocidad normal")
	_check(is_equal_approx(Horde.speed_mult(4), 1.0 + 4.0 * Horde.STAGE_SPD), "tramo 4: más rápidas")
	# Tamaño de las oleadas y tope de vivas: crecen con el equipo (petición del usuario, 2026-09-17:
	# "más cantidad dependiendo siempre si hay más personas").
	_check(Horde.wave_size(1, 1) == 10, "oleada 1 en solitario: 10 criaturas")
	_check(Horde.wave_size(1, 4) > Horde.wave_size(1, 1), "con equipo salen más")
	_check(Horde.wave_size(1, 4) - Horde.wave_size(1, 1) == Horde.PER_PLAYER_SPAWN * 3, "tres compañeros, tres tandas más")
	_check(Horde.wave_size(5, 1) > Horde.wave_size(1, 1), "las oleadas crecen con el número")
	_check(Horde.alive_cap(1) == Main.MAX_ALIVE, "en solitario, el tope de siempre")
	_check(Horde.alive_cap(4) == Main.MAX_ALIVE + Horde.PER_PLAYER_ALIVE * 3, "con equipo caben más a la vez")
	_check(Horde.PER_PLAYER_SPAWN >= 6 and Horde.PER_PLAYER_ALIVE >= 10, "el usuario pidió bastantes más por persona")

	# La Horda dura 10 oleadas y los Rompemareas salen del 5 en adelante: 1, 2, 3, 4 y 4 hasta el
	# final (esquema del usuario, 2026-09-17).
	_check(Horde.WAVES == 10, "la horda son 10 oleadas")
	for w in range(1, 5):
		_check(Horde.boss_count(w) == 0, "oleada %d: sin jefe" % w)
	_check(Horde.boss_count(5) == 1, "oleada 5: un Rompemareas")
	_check(Horde.boss_count(6) == 2, "oleada 6: dos")
	_check(Horde.boss_count(7) == 3, "oleada 7: tres")
	_check(Horde.boss_count(8) == 4, "oleada 8: cuatro")
	_check(Horde.boss_count(9) == 4, "oleada 9: siguen siendo cuatro")
	_check(Horde.boss_count(10) == 4, "oleada 10: cuatro")

	# Superar la última oleada es ganar: no queda nada vivo, ni jefes, ni por salir.
	_check(Horde.run_over(Horde.WAVES, 0, false, 0), "oleada 10 limpia: victoria")
	_check(not Horde.run_over(Horde.WAVES, 3, false, 0), "con criaturas vivas, todavía no")
	_check(not Horde.run_over(Horde.WAVES, 0, true, 0), "con un jefe en pie, todavía no")
	_check(not Horde.run_over(Horde.WAVES, 0, false, 5), "con criaturas por salir, todavía no")
	_check(not Horde.run_over(Horde.WAVES - 1, 0, false, 0), "la oleada 9 limpia solo trae la 10")
	print("test_horde_scaling: %s (%d fallos)" % ["OK" if failures == 0 else "FALLO", failures])
	quit(1 if failures > 0 else 0)
