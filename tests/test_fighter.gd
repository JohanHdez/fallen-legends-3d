## Prueba de lógica pura de Fighter (game/fighter.gd), sin escena:
##   godot --headless --path . -s tests/test_fighter.gd
## Vida multiplicada por equipos, definitiva por carga (lista solo al 100 %, lo que falta se ve en el
## botón como porcentaje) y la carga que pide cada leyenda según el daño por segundo de su básica.
extends SceneTree

var failures := 0


func _check(ok: bool, msg: String) -> void:
	if not ok:
		print("FALLO: " + msg)
		failures += 1


func _fighter(legend: int) -> Fighter:
	var f := Fighter.new()
	f.legend = legend
	f.rec = {"hp": f.hp_max()}
	f.reset_abilities()
	return f


func _init() -> void:
	# Vida: por defecto la del 2D; con hp_mult, multiplicada.
	var f := _fighter(0)
	_check(is_equal_approx(f.hp_max(), 210.0), "vida del Tormentero sin multiplicar: %.0f" % f.hp_max())
	f.hp_mult = 3.0
	_check(is_equal_approx(f.hp_max(), 630.0), "vida del Tormentero ×3: %.0f" % f.hp_max())

	# Sin carga (Horda): la definitiva va por recarga, como siempre.
	var h := _fighter(0)
	_check(h.ability_ready(2), "en la Horda la definitiva empieza lista")
	h.cd[2] = 15.0
	_check(not h.ability_ready(2) and is_equal_approx(h.cooldown_fraction(2), 0.5), "en la Horda manda la recarga")

	# Con carga (equipos): lista solo al 100 %, y la recarga no cuenta.
	var p := _fighter(0)
	p.ult_by_charge = true
	p.ult_charge = 0.0
	_check(not p.ability_ready(2), "con la carga vacía la definitiva no está lista")
	_check(is_equal_approx(p.cooldown_fraction(2), 1.0), "con la carga vacía el botón está entero en sombra")
	p.ult_charge = 0.73
	_check(not p.ability_ready(2) and is_equal_approx(p.cooldown_fraction(2), 0.27), "al 73 %% falta el 27 %%")
	_check(p.cooldown_text(2) == "73%", "texto del botón al 73 %%: %s" % p.cooldown_text(2))
	p.ult_charge = 1.0
	p.cd[2] = 30.0
	_check(p.ability_ready(2), "al 100 %% está lista aunque haya recarga apuntada")
	_check(p.ability_ready(0) and p.ability_ready(1), "la carga solo afecta a la definitiva")
	_check(p.cooldown_text(0) == "", "una ranura lista no enseña texto")
	p.cd[0] = 0.44
	_check(p.cooldown_text(0) == "0.4", "texto de recarga normal: %s" % p.cooldown_text(0))

	# Carga necesaria: ULT_SECONDS de su básica sin fallar, según su daño por segundo.
	for legend in LegendData.PLAYABLE:
		var l := _fighter(legend)
		var ab := l.abil(0)
		var dps := float(ab["dmg"]) / maxf(maxf(float(ab["cd"]), float(ab.get("cast", 0.0))), 0.1)
		_check(is_equal_approx(l.ult_need(), Fighter.ULT_SECONDS * dps),
			"%s: carga necesaria %.0f (esperada %.0f)" % [l.data()["name"], l.ult_need(), Fighter.ULT_SECONDS * dps])
		_check(l.ult_need() > 100.0 and l.ult_need() < 500.0, "%s: carga necesaria fuera de rango (%.0f)" % [l.data()["name"], l.ult_need()])

	# Con vida ×3 la carga pide el triple.
	var tri := _fighter(0)
	var base_need := tri.ult_need()
	tri.hp_mult = 3.0
	_check(is_equal_approx(tri.ult_need(), base_need * 3.0), "con vida ×3 la carga pide el triple")

	# add_ult_damage: suma hasta 1 y no pasa de ahí.
	var c := _fighter(4)
	c.ult_by_charge = true
	c.add_ult_damage(c.ult_need() * 0.5)
	_check(is_equal_approx(c.ult_charge, 0.5), "media carga con la mitad del daño: %.2f" % c.ult_charge)
	c.add_ult_damage(c.ult_need() * 5.0)
	_check(is_equal_approx(c.ult_charge, 1.0), "la carga no pasa del 100 %%")
	var n := _fighter(4)
	n.add_ult_damage(9999.0)
	_check(is_equal_approx(n.ult_charge, 0.0), "sin carga activada (Horda) no se acumula")

	_test_ammo()
	_test_mark_and_damage()

	print("test_fighter: %s (%d fallos)" % ["OK" if failures == 0 else "FALLO", failures])
	quit(1 if failures > 0 else 0)


## Munición de la básica por equipos: 3 disparos que vuelven de uno en uno. La Ilusionista no tiene
## (su ventaja es la cantidad de disparos) y en la Horda nadie la tiene.
func _test_ammo() -> void:
	# Horda: sin munición, la básica solo depende de su recarga.
	var h := _fighter(0)
	_check(h.ammo_max == 0, "en la Horda no hay munición")
	h.spend_ammo()
	_check(h.ability_ready(0), "en la Horda gastar munición no hace nada")

	# Tabla: todas las de la rotación menos la Ilusionista, y la recarga limita de verdad.
	for legend in LegendData.PLAYABLE:
		var l := _fighter(legend)
		var id := String(l.data()["id"])
		l.enable_ammo()
		if id == "ilusionista":
			_check(l.ammo_max == 0, "la Ilusionista dispara sin límite")
			continue
		# Cada leyenda lleva los suyos (LegendData.PVP_AMMO): 3 casi todas, 4 el Rey liche desde que
		# el usuario lo vio flojo de lejos (2026-09-18).
		var want := int(LegendData.PVP_AMMO[id]["n"])
		_check(l.ammo_max == want and l.ammo == want, "%s: %d disparos llenos (%d/%d)" % [id, want, l.ammo, l.ammo_max])
		var ab := l.abil(0)
		_check(l.ammo_reload > maxf(float(ab["cd"]), float(ab.get("cast", 0.0))),
			"%s: la recarga de munición (%.2f) tiene que ser más lenta que la básica" % [id, l.ammo_reload])

	# Gastar los 3: sin munición no está lista aunque la recarga de la básica esté a 0.
	var t := _fighter(0)
	t.ult_by_charge = true
	t.enable_ammo()
	var reload := t.ammo_reload
	_check(is_equal_approx(reload, 1.0), "Tormentero: un disparo vuelve cada 1 s (%.2f)" % reload)
	t.spend_ammo()
	_check(t.ammo == 2 and is_equal_approx(t.ammo_t, reload), "al gastar uno empieza a volver")
	t.tick_cooldowns(0.4)
	t.spend_ammo()
	_check(t.ammo == 1 and is_equal_approx(t.ammo_t, reload - 0.4), "gastar otro no reinicia la vuelta en curso")
	t.spend_ammo()
	t.cd[0] = 0.0
	_check(t.ammo == 0 and not t.ability_ready(0), "sin munición la básica no está lista")
	_check(is_equal_approx(t.cooldown_fraction(0), (reload - 0.4) / reload), "el botón enseña lo que falta para el siguiente disparo")
	_check(t.cooldown_text(0) == "0.6", "texto del botón sin munición: %s" % t.cooldown_text(0))
	t.spend_ammo()
	_check(t.ammo == 0, "la munición no baja de 0")
	t.tick_cooldowns(0.6)
	_check(t.ammo == 1 and t.ability_ready(0), "vuelve un disparo y está lista")
	_check(is_equal_approx(t.ammo_t, reload), "sigue volviendo el siguiente")
	_check(is_equal_approx(t.ammo_level(), 1.0), "nivel de la barra con 1 y el siguiente sin empezar: %.2f" % t.ammo_level())
	t.tick_cooldowns(0.25)
	_check(is_equal_approx(t.ammo_level(), 1.25), "nivel de la barra a un cuarto del segundo: %.2f" % t.ammo_level())
	t.tick_cooldowns(0.75 + reload)
	_check(t.ammo == 3 and is_equal_approx(t.ammo_t, 0.0) and is_equal_approx(t.ammo_level(), 3.0), "llena del todo se para")
	# Con munición manda también la recarga de la básica.
	t.cd[0] = 0.3
	_check(not t.ability_ready(0), "con munición pero en recarga no está lista")
	# Al reiniciar (nueva ronda) vuelve llena.
	t.spend_ammo()
	t.spend_ammo()
	t.reset_abilities()
	_check(t.ammo == 3 and is_equal_approx(t.ammo_t, 0.0), "reiniciar rellena la munición")
	# La carga de la definitiva NO baja con la munición: medido con 28 partidas, bajarla (6 s de
	# ritmo sostenido) casi duplicaba las definitivas (201 -> 375) y su parte del daño (15 % -> 20 %).
	_check(is_equal_approx(t.ult_need(), Fighter.ULT_SECONDS * 22.0 / 0.6), "carga de la definitiva con munición: %.0f" % t.ult_need())


## Marca de quien rompe un señuelo de la Ilusionista (5 s, la ve el equipo del señuelo) y daño de la
## básica por equipos (solo la pistola de la Ilusionista sube).
func _test_mark_and_damage() -> void:
	var f := _fighter(0)
	_check(not f.marked_for(1) and not f.marked_for(2), "sin marcar al empezar")
	f.mark(1)
	_check(f.marked_for(1) and not f.marked_for(2), "marcado para el equipo del señuelo, no para otro")
	_check(is_equal_approx(Fighter.MARK_TIME, 5.0) and is_equal_approx(f.marked_t, 5.0), "la marca dura 5 s")
	f.marked_t = 1.0
	f.mark(1)
	_check(is_equal_approx(f.marked_t, 5.0), "romper otro señuelo vuelve a 5 s, no suma")
	f.marked_t = 0.0
	_check(not f.marked_for(1), "sin tiempo ya no está marcado")

	for legend in LegendData.PLAYABLE:
		var l := _fighter(legend)
		var need := l.ult_need()
		_check(is_equal_approx(l.basic_dmg_mult, 1.0), "sin reglas por equipos la básica no cambia")
		l.enable_pvp_damage()
		var id := String(l.data()["id"])
		if id == "ilusionista":
			_check(l.basic_dmg_mult > 1.0, "por equipos la pistola de la Ilusionista pega más")
			_check(is_equal_approx(l.ult_need(), need * l.basic_dmg_mult), "su definitiva pide su daño de verdad")
		else:
			_check(is_equal_approx(l.basic_dmg_mult, 1.0), "%s: su básica no cambia por equipos" % id)
