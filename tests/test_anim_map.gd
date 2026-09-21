## Prueba del reparto de animaciones por habilidad (LegendData.ABILITIES · "anim", "anim_charged",
## "combo_anim"): godot --headless --path . -s tests/test_anim_map.gd
## Carga las dos bibliotecas de verdad (UAL1 Pro y UAL2) y comprueba, habilidad por habilidad:
##  - que la animación que pide existe en la biblioteca y está injertada en HERO_ANIMS*;
##  - que sale a una velocidad razonable. Combat estira o comprime la animación hasta
##    `dur = max(adur*, max(preaviso, 0.35))`: la lección de Sword_Heavy_Combo (4,33 s comprimidos al
##    preaviso salían a 12×, un temblor) es que hay que mirar la DURACIÓN, no el nombre. Cada
##    animación mira SU propio campo de duración: "anim" con "adur", "anim_charged" con
##    "adur_charged" (el mandoble cargado del Rompemareas) y "combo_anim" con "combo_adur" (el combo
##    automático del Caballero, 2026-09-20): antes esta prueba medía "anim_charged" con "adur" por
##    error y le colaba a Sword_Regular_Combo (3,0 s) un 3,0× pelado con el mandoble.
## Petición del usuario (2026-09-17): repartir las animaciones nuevas entre las habilidades.
extends SceneTree

const MIN_SPEED := 0.4
const MAX_SPEED := 3.0

var failures := 0
var _lens := {}


func _check(ok: bool, msg: String) -> void:
	if not ok:
		print("FALLO: " + msg)
		failures += 1


func _init() -> void:
	_load_lengths(LegendData.UAL1)
	_load_lengths(LegendData.UAL2)
	_check(not _lens.is_empty(), "se cargan las bibliotecas de animación")
	var grafted := (LegendData.HERO_ANIMS + "," + LegendData.HERO_ANIMS_2).split(",")
	var used := 0
	for legend in LegendData.ABILITIES:
		var abilities: Array = LegendData.ABILITIES[legend]
		for i in abilities.size():
			var ab: Dictionary = abilities[i]
			# Cada nombre de animación mira SU PROPIO campo de duración (ver cabecera): así el
			# mandoble cargado del Rompemareas y el combo automático del Caballero no se miden con la
			# duración de su golpe normal.
			for pair in [["anim", "adur"], ["anim_charged", "adur_charged"], ["combo_anim", "combo_adur"]]:
				var key: String = pair[0]
				var dur_key: String = pair[1]
				var name := String(ab.get(key, ""))
				if name == "":
					continue
				used += 1
				var what := "%s · %s (%s)" % [legend, String(ab["n"]), key]
				if not _lens.has(name):
					_check(false, "%s pide %s y no está en ninguna biblioteca" % [what, name])
					continue
				_check(grafted.has(name), "%s pide %s y no está injertada (HERO_ANIMS*)" % [what, name])
				# Las cargas (k = dash) se cronometran aparte: con "sync" el desplazamiento dura lo que
				# la animación, y si no, Combat recorta la velocidad a 0,5-3× por su cuenta.
				if String(ab["k"]) == "dash":
					var alen: float = float(_lens[name])
					if bool(ab.get("sync", false)):
						_check(alen >= 0.4 and alen <= 2.0,
							"%s: con \"sync\" la carga dura lo que %s (%.2f s): fuera de 0,4-2 s" % [what, name, alen])
					continue
				var windup := float(ab.get("cast", 0.25))
				var dur: float = maxf(float(ab.get(dur_key, 0.0)), maxf(windup, 0.35))
				var speed: float = float(_lens[name]) / dur
				_check(speed >= MIN_SPEED and speed <= MAX_SPEED,
					"%s: %s dura %.2f s y sale a %.1f× (fuera de %.1f-%.1f; ajusta \"%s\")" % [
						what, name, float(_lens[name]), speed, MIN_SPEED, MAX_SPEED, dur_key])
	_check(used >= 15, "las leyendas jugables reparten sus animaciones (%d habilidades con animación)" % used)
	# Las que el juego usa por su cuenta, fuera de las habilidades.
	for name in ["Sword_Attack", "Spell_Simple_Shoot", "Idle_Rail_Call", Revive.HELPER_ANIM]:
		_check(_lens.has(name) and grafted.has(name), "%s tiene que estar injertada" % name)
	print("test_anim_map: %s (%d fallos)" % ["OK" if failures == 0 else "FALLO", failures])
	quit(1 if failures > 0 else 0)


func _load_lengths(path: String) -> void:
	var scn := load(path) as PackedScene
	if scn == null:
		return
	var node := scn.instantiate()
	for c in node.find_children("*", "AnimationPlayer", true, false):
		var ap := c as AnimationPlayer
		for name in ap.get_animation_list():
			_lens[name] = ap.get_animation(name).length
		break
	node.queue_free()
