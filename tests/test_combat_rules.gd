## Prueba de reglas puras de Combat (game/combat.gd), sin escena:
##   godot --headless --path . -s tests/test_combat_rules.gd
## Activación de la Trampa eléctrica y la Baliza Nox: por equipos tardan unos segundos en poder
## saltar (petición del usuario); en la Horda saltan al momento, como en el 2D. Sonidos de los rayos
## y qué zonas tiran un rayo por víctima. Y la toxina del Golpe sagrado del Clérigo.
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
	# Toxina del Clérigo (petición del usuario, 2026-09-17): cada golpe suyo que impacta sigue
	# quitando vida un rato; los golpes seguidos alargan el veneno hasta un tope.
	var tox: Dictionary = LegendData.ABILITIES["clerigo"][0]
	_check(float(tox.get("toxin", 0.0)) > 0.0, "el Golpe sagrado envenena")
	_check(float(tox.get("tdmg", 0.0)) > 0.0, "la toxina hace daño por segundo")
	_check(is_equal_approx(Combat.toxin_time(0.0, 2.0), 2.0), "el primer golpe envenena lo que diga la habilidad")
	_check(is_equal_approx(Combat.toxin_time(2.0, 2.0), 4.0), "el segundo golpe alarga el veneno")
	_check(is_equal_approx(Combat.toxin_time(Combat.TOXIN_MAX - 0.5, 2.0), Combat.TOXIN_MAX), "no pasa del tope")
	_check(Combat.TOXIN_MAX >= 4.0 and Combat.TOXIN_MAX <= 10.0, "el tope son unos segundos (%.1f s)" % Combat.TOXIN_MAX)
	# El veneno tiene que valer la pena sin ser una segunda definitiva: entre un tercio y una vez el
	# golpe que lo pone (vida ×3 en PvP; el Golpe sagrado hace 16).
	var per_hit := float(tox["toxin"]) * float(tox["tdmg"])
	_check(per_hit >= float(tox.get("dmg", 16.0)) * 0.3 and per_hit <= float(tox.get("dmg", 16.0)),
		"un golpe envenenado añade %.0f de daño sobre los %.0f del impacto" % [per_hit, float(tox.get("dmg", 16.0))])
	# Animación según hacia dónde se mueve respecto a donde mira (petición del usuario, 2026-09-17,
	# con la biblioteca Pro: andar de lado, hacia atrás y gatear de verdad).
	var f := Vector3(0, 0, 1)                      # mirando a +Z (Fighter.facing con rotación 0)
	_check(Combat.move_anim(Vector3.ZERO, f, Combat.ANIM_JOG) == "Idle", "quieto: Idle")
	_check(Combat.move_anim(f, f, Combat.ANIM_JOG) == "Jog_Fwd", "hacia donde mira: de frente")
	_check(Combat.move_anim(-f, f, Combat.ANIM_JOG) == "Jog_Bwd", "de espaldas: hacia atrás")
	_check(Combat.move_anim(Vector3(-1, 0, 0), f, Combat.ANIM_JOG) == "Jog_Right", "mirando a +Z, -X es su derecha")
	_check(Combat.move_anim(Vector3(1, 0, 0), f, Combat.ANIM_JOG) == "Jog_Left", "y +X su izquierda")
	# La derecha de la cámara (basis.x) tiene que salir como derecha con cualquier giro.
	for deg in [0.0, 37.0, 90.0, 180.0, 270.0]:
		var b := Basis(Vector3.UP, deg_to_rad(deg))
		var look := -b.z                            # hacia donde mira la cámara
		_check(Combat.move_anim(b.x, look, Combat.ANIM_JOG) == "Jog_Right", "girado %.0f°: su derecha" % deg)
		_check(Combat.move_anim(-b.x, look, Combat.ANIM_JOG) == "Jog_Left", "girado %.0f°: su izquierda" % deg)
		_check(Combat.move_anim(look, look, Combat.ANIM_JOG) == "Jog_Fwd", "girado %.0f°: de frente" % deg)
	# Agachado y derribado usan la misma regla con sus propias animaciones.
	_check(Combat.move_anim(f, f, Combat.ANIM_CROUCH) == "Crouch_Fwd", "agachado de frente")
	_check(Combat.move_anim(Vector3.ZERO, f, Combat.ANIM_CROUCH) == "Crouch_Idle", "agachado quieto")
	_check(Combat.move_anim(-f, f, Combat.ANIM_CRAWL) == "Crawl_Bwd", "derribado hacia atrás")
	_check(Combat.move_anim(Vector3.ZERO, f, Combat.ANIM_CRAWL) == "Crawl_Idle", "derribado quieto")
	_check(Revive.DOWNED_STATE == Combat.ANIM_CRAWL, "el derribo gatea (ya no nada)")
	for n in [Combat.move_anim(f, f, Combat.ANIM_CRAWL), Combat.move_anim(Vector3.ZERO, f, Combat.ANIM_CRAWL)]:
		_check(LegendData.HERO_ANIMS.split(",").has(n), "%s está injertada en las leyendas" % n)
	# Quejarse al recibir un golpe, por donde se lo han dado (petición del usuario, 2026-09-17).
	var f2 := Vector3(0, 0, 1)                     # mirando a +Z
	_check(Combat.hit_anim(f2, f2) == "Hit_Chest", "golpe de frente: al pecho")
	_check(Combat.hit_anim(-f2, f2) == "Hit_Head", "por la espalda: a la cabeza")
	_check(Combat.hit_anim(Vector3(-1, 0, 0), f2) == "Hit_Shoulder_R", "por su derecha: hombro derecho")
	_check(Combat.hit_anim(Vector3(1, 0, 0), f2) == "Hit_Shoulder_L", "por su izquierda: hombro izquierdo")
	_check(Combat.hit_anim(Vector3.ZERO, f2) == "Hit_Chest", "sin saber de dónde viene: al pecho")
	for n in ["Hit_Chest", "Hit_Head", "Hit_Shoulder_L", "Hit_Shoulder_R"]:
		_check(LegendData.HERO_ANIMS.split(",").has(n), "%s está injertada" % n)
	_check(Combat.HIT_ANIM_MIN > 0.0 and Combat.HIT_ANIM_MIN <= 0.1, "solo se queja con un golpe de verdad")
	_check(Combat.HIT_ANIM_EVERY >= 0.5, "y no se queja en cada pinchazo de veneno")

	# Tocada (por debajo de la mitad de la vida) se queda encorvada al pararse.
	_check(Combat.move_anim(Vector3.ZERO, f2, Combat.ANIM_JOG, true) == "Idle_Tired", "malherida y quieta: encorvada")
	_check(Combat.move_anim(Vector3.ZERO, f2, Combat.ANIM_JOG, false) == "Idle", "entera y quieta: normal")
	_check(Combat.move_anim(f2, f2, Combat.ANIM_JOG, true) == "Jog_Fwd", "malherida pero andando: sigue su marcha")
	_check(Combat.move_anim(Vector3.ZERO, f2, Combat.ANIM_CROUCH, true) == "Crouch_Idle", "agachada no cambia")
	_check(is_equal_approx(Combat.LOW_HP, 0.5), "la mitad de la vida es el umbral")
	_check(LegendData.HERO_ANIMS.split(",").has("Idle_Tired"), "Idle_Tired está injertada")
	# Aviso de media vida (petición del usuario, 2026-09-17): en los modos por equipos no ves la vida
	# del rival, así que cuando tu equipo le baja de la mitad suena algo que se quiebra.
	var hp2 := 700.0
	_check(Combat.crossed_half(hp2 * 0.6, hp2 * 0.5, hp2), "justo al 50 %% suena")
	_check(Combat.crossed_half(hp2 * 0.51, hp2 * 0.2, hp2), "al bajar de golpe también")
	_check(not Combat.crossed_half(hp2 * 0.49, hp2 * 0.3, hp2), "si ya estaba por debajo, no vuelve a sonar")
	_check(not Combat.crossed_half(hp2, hp2 * 0.8, hp2), "con más de la mitad no suena")
	_check(not Combat.crossed_half(hp2 * 0.6, 0.0, hp2), "si lo derriban de ese golpe, no suena (ya se ve)")
	_check(ResourceLoader.exists("res://assets/audio/sfx/%s.ogg" % Combat.HALF_SOUND),
		"el sonido %s existe" % Combat.HALF_SOUND)
	print("test_combat_rules: %s (%d fallos)" % ["OK" if failures == 0 else "FALLO", failures])
	quit(1 if failures > 0 else 0)
