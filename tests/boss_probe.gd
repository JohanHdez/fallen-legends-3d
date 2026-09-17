## Sonda: el jefe de la Horda es una leyenda Rompemareas llevada por un bot, del bando de la horda, y
## usa sus poderes contra el equipo (petición del usuario, 2026-09-17: "nunca usó sus poderes contra mí").
##   godot --headless --fixed-fps 60 --path . -- --team=2 --autoplay --near=4 --zombies=0 --boss --probe=boss_probe [--secs=120]
## Comprueba: hay un Fighter del equipo de la horda con la leyenda Rompemareas y vida de jefe; lanza
## alguna habilidad que no sea su básica (Enganche o Ancla clavada); hace daño a leyendas del equipo; y
## si cae, deja de contar como jefe vivo.
extends Node

var main: Node
var _t := 0.0
var _secs := 120.0
var _boss: Fighter = null
var _slots := {}          # ranuras que ha empezado a lanzar
var _min_hp := INF        # la vida más baja que tuvo: ¿le pegan?
var _problems: Array = []


func _ready() -> void:
	main = get_parent()
	_secs = float(main._args.get("secs", "120"))
	if main.horde == null:
		print("boss_probe: FALLO (hace falta la Horda con --boss)")
		main.get_tree().quit(1)
		return
	for f: Fighter in main.combat.fighters:
		if f.team == Fighter.TEAM_HORDE:
			_boss = f
	if _boss == null:
		_problems.append("no hay ninguna leyenda del bando de la horda: el jefe sigue siendo un zombi")
	elif String(_boss.data()["id"]) != "rompemareas":
		_problems.append("el jefe es %s y debería ser el Rompemareas" % _boss.display_name)
	elif _boss.hp_max() < float(_boss.data()["hp"]) * 2.0:
		_problems.append("el jefe tiene %.0f de vida: no es vida de jefe" % _boss.hp_max())
	if _boss != null and _boss.brain == null:
		_problems.append("el jefe no lleva cerebro de bot")


func _physics_process(delta: float) -> void:
	_t += delta
	if _boss != null:
		_min_hp = minf(_min_hp, _boss.hp())
	if _boss != null and _boss.windup >= 0.0 and _boss.windup_idx >= 0:
		_slots[_boss.windup_idx] = true
	var wiped: bool = main.horde_mode != null and main.horde_mode.over
	if not _problems.is_empty() or _t >= _secs or wiped or (_boss != null and _boss.dead()):
		_finish()


func _finish() -> void:
	set_physics_process(false)
	var dealt := 0.0
	if _boss != null:
		for k in main.combat.damage_by:
			if String(k).begins_with(_boss.display_name):
				dealt += float(main.combat.damage_by[k])
		if not (_slots.has(1) or _slots.has(2)):
			_problems.append("en %.0f s el jefe solo usó %s: ni Enganche ni Ancla clavada" % [_t, str(_slots.keys())])
		if dealt <= 0.0:
			_problems.append("el jefe no hizo daño a ninguna leyenda")
		if _min_hp >= _boss.hp_max():
			_problems.append("nadie le quitó vida al jefe en %.0f s" % _t)
		if _boss.dead() and main.horde.boss_alive:
			_problems.append("el jefe cayó pero la Horda lo sigue contando vivo")
		print("[SONDA] jefe %s · vida %.0f/%.0f (mínima %.0f) · ranuras usadas %s · daño a leyendas %.0f · %.0f s · %s" % [
			_boss.display_name, _boss.hp(), _boss.hp_max(), _min_hp, str(_slots.keys()), dealt, _t,
			"el equipo cayó" if main.horde_mode != null and main.horde_mode.over else ("jefe abatido" if _boss.dead() else "sigue la pelea")])
	for p in _problems:
		print("[SONDA] problema: %s" % p)
	print("boss_probe: %s" % ("OK" if _problems.is_empty() else "FALLO"))
	main.get_tree().quit(0 if _problems.is_empty() else 1)
