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
	# ...pero una básica cualquiera tiene que hacer que se queje una leyenda de las normales: con el
	# 4 % de antes, en un duelo Tormentero-Ilusionista no se quejaba NADIE en toda la partida (la
	# pistola quita 14 de 600 y la esfera 22 de 630), y la sonda lo cazó (2026-09-18). Referencia: el
	# Tormentero por equipos, 210 de vida ×3.
	var soft := 210.0 * 3.0 * Combat.HIT_ANIM_MIN
	for legend in LegendData.ABILITIES:
		var ab0: Dictionary = LegendData.ABILITIES[legend][0]
		if String(ab0["k"]) != "proj":
			continue
		var dmg := float(ab0["dmg"]) * float(LegendData.PVP_BASIC_DMG.get(legend, 1.0))
		_check(dmg >= soft, "la básica de %s (%.0f) hace que se queje una leyenda de 630 de vida (hace falta %.0f)" % [
			legend, dmg, soft])
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
	# Máscara antigás del Trasgo Nox (petición del usuario, 2026-09-18): el gas que cierra el mapa no
	# le hace nada ni a él ni a su equipo. Las nubes de las habilidades ya respetaban a los aliados.
	_check(Combat.masks_gas("quimico"), "el Trasgo Nox lleva la máscara")
	for other in ["clerigo", "tormentero", "rompemareas", "liche", "caballero", "ilusionista"]:
		_check(not Combat.masks_gas(other), "%s no lleva máscara" % other)
	_check(Combat.team_masks_gas(["clerigo", "quimico"]), "con un Trasgo Nox en el equipo, todos a salvo")
	_check(not Combat.team_masks_gas(["clerigo", "liche"]), "sin él, el gas quema")
	_check(not Combat.team_masks_gas([]), "un equipo vacío no lleva máscara")
	_check(Combat.GAS_MASK_LEGEND == LegendData.LEGENDS[6]["id"], "la máscara es la del Trasgo Nox de LEGENDS")

	# Apuntado asistido: las Esporas se pegan al enemigo más cercano al punto señalado.
	_check(LegendData.ABILITIES["clerigo"][2].get("snap", false), "las Esporas apuntan solas")
	_check(Combat.SNAP_R >= 2.0 and Combat.SNAP_R <= 6.0, "el imán del apuntado es de unos metros")
	_check(float(LegendData.ABILITIES["clerigo"][2]["rad"]) >= 300.0, "y la nube es más ancha que antes (190 px)")

	# El Caballero esqueleto (petición del usuario, 2026-09-20: es la leyenda más floja en duelos,
	# 33 %): aguante al cuerpo a cuerpo, básica más rápida, Corte de hacha con tres cargas y combo
	# automático al tercer golpe.
	_check(LegendData.LEGENDS[3]["id"] == "caballero", "la leyenda 3 sigue siendo el Caballero")
	var armor := float(LegendData.LEGENDS[3].get("melee_armor", 0.0))
	_check(is_equal_approx(armor, 0.25), "el aguante empieza en 25%% (si se baja al medir, se actualiza aquí)")
	_check(is_equal_approx(Combat.melee_armor_mult(armor, "melee"), 0.75), "un golpe cuerpo a cuerpo hace un 25%% menos")
	_check(is_equal_approx(Combat.melee_armor_mult(armor, "dash"), 0.75), "una carga también es cuerpo a cuerpo")
	_check(is_equal_approx(Combat.melee_armor_mult(armor, "proj"), 1.0), "uno a distancia no se reduce")
	_check(is_equal_approx(Combat.melee_armor_mult(armor, "zone"), 1.0), "ni una zona")
	_check(is_equal_approx(Combat.GUARD_DAMAGE_MULT * Combat.melee_armor_mult(armor, "melee"), 0.4125),
		"se acumula con la Guardia: quieto y cubriéndose, un hachazo le hace 0,55 × 0,75 = 41 %% del daño")

	var lanzada: Dictionary = LegendData.ABILITIES["caballero"][0]
	_check(is_equal_approx(float(lanzada["cd"]), 0.65), "la básica sale cada 0,65 s (antes 0,8)")
	_check(int(LegendData.ABILITIES["caballero"][1].get("chg", 0)) == 3, "Corte de hacha guarda tres cargas")

	# Combo automático (petición del usuario, 2026-09-20): dos golpes básicos que ACIERTAN en menos
	# de COMBO_WINDOW s hacen que el tercero sea el de combo, con más arco; fallar o pasar el tiempo
	# reinicia la cuenta.
	var needed := int(lanzada.get("combo_hits", 0))
	_check(needed == 2, "hacen falta dos aciertos antes del combo")
	_check(float(lanzada.get("combo_rad", 0.0)) > float(lanzada["rad"]), "el golpe de combo abre más que el normal (115 -> 150 px)")
	_check(String(lanzada.get("combo_anim", "")) == "Sword_Regular_Combo", "usa el mismo combo que el Rompemareas al cargar")
	_check(LegendData.HERO_ANIMS_2.split(",").has("Sword_Regular_Combo"), "y está injertado")
	_check(not Combat.combo_ready(0, needed), "sin golpes, no hay combo")
	_check(not Combat.combo_ready(1, needed), "con uno tampoco")
	_check(Combat.combo_ready(2, needed), "con dos seguidos, el que viene es el de combo")
	_check(Combat.combo_ready(3, needed), "y si por lo que sea pasa de dos, sigue listo")
	_check(Combat.combo_next_streak(0, needed, true) == 1, "el primer acierto cuenta uno")
	_check(Combat.combo_next_streak(1, needed, true) == 2, "el segundo llega a dos: el siguiente es el combo")
	_check(Combat.combo_next_streak(1, needed, false) == 0, "fallar reinicia la cuenta")
	_check(Combat.combo_next_streak(2, needed, true) == 0, "el golpe de combo se consume al acertar")
	_check(Combat.combo_next_streak(2, needed, false) == 0, "...y también si falla")
	_check(is_equal_approx(Combat.COMBO_WINDOW, 2.0), "la ventana del combo son los 2 s que pidió el usuario")
	_check(is_equal_approx(Combat.combo_tick(Combat.COMBO_WINDOW, Combat.COMBO_WINDOW + 0.1), 0.0),
		"pasado de sobra el tiempo, no queda ventana")
	_check(Combat.combo_tick(Combat.COMBO_WINDOW, 0.1) > 0.0, "un instante después todavía queda")
	# Fuera de alcance (diseño 2026-09-20): el combo automático es solo del Caballero.
	for legend in LegendData.ABILITIES:
		if legend == "caballero":
			continue
		for other_ab in LegendData.ABILITIES[legend]:
			_check(int(other_ab.get("combo_hits", 0)) == 0, "%s no tiene combo automático: es solo del Caballero" % legend)

	print("test_combat_rules: %s (%d fallos)" % ["OK" if failures == 0 else "FALLO", failures])
	quit(1 if failures > 0 else 0)
