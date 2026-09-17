## Prueba de reglas puras de Combat (game/combat.gd), sin escena:
##   godot --headless --path . -s tests/test_combat_rules.gd
## Activación de la Trampa eléctrica y la Baliza Nox: por equipos tardan unos segundos en poder
## saltar (petición del usuario); en la Horda saltan al momento, como en el 2D. Sonidos de los rayos
## y qué zonas tiran un rayo por víctima.
extends SceneTree

var failures := 0


func _check(ok: bool, msg: String) -> void:
	if not ok:
		print("FALLO: " + msg)
		failures += 1


func _init() -> void:
	var arm := Combat.PVP_ARM_TIME
	_check(arm >= 1.5 and arm <= 3.0, "tarda unos segundos en activarse (%.1f s)" % arm)
	# Horda: al momento.
	_check(Combat.can_trigger(0.0, false), "en la Horda salta nada más caer")
	# Por equipos: no antes de activarse, sí después.
	_check(not Combat.can_trigger(0.0, true), "por equipos no salta nada más caer")
	_check(not Combat.can_trigger(arm - 0.01, true), "por equipos no salta un instante antes de activarse")
	_check(Combat.can_trigger(arm, true), "por equipos salta en cuanto se activa")
	_check(Combat.can_trigger(arm + 5.0, true), "activada sigue pudiendo saltar")
	# Sonidos de los rayos (Trampa y Tormenta eléctricas): existen con el nombre que carga Main._sfx.
	for s in [Combat.STRIKE_SOUND, Combat.THUNDER_SOUND]:
		_check(ResourceLoader.exists("res://assets/audio/spells/%s.ogg" % s), "falta el sonido %s" % s)
	# Solo la Tormenta eléctrica tira rayos por víctima; el gas Nox y la nube de la baliza, no.
	_check(Combat.is_storm({"fstun": 1.2, "fx": "spark"}), "la Tormenta eléctrica tira rayos")
	_check(not Combat.is_storm({"fstun": 0.0, "fx": "spark", "slow": 0.5}), "el gas Nox no tira rayos")
	_check(not Combat.is_storm({"fstun": 0.0, "fx": "dust"}), "un estallido de polvo no tira rayos")
	print("test_combat_rules: %s (%d fallos)" % ["OK" if failures == 0 else "FALLO", failures])
	quit(1 if failures > 0 else 0)
