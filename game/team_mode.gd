## Una partida por equipos (1v1 a 4v4) sobre el mapa de la Horda y sin criaturas, AL MEJOR DE 3
## RONDAS: coloca a cada equipo en su zona de salida, crea los bots con su cerebro, lleva las reglas
## (TeamMatch), y entre rondas limpia el mundo, reinicia el gas y devuelve a todos a su sitio.
## Dentro de una ronda no se reaparece: quien cae mira hasta que acaba. main.gd solo lo crea y le da
## cuerda cada fotograma.
## Reglas y motivos: docs/superpowers/specs/2026-09-16-modos-por-equipos-design.md
class_name TeamMode
extends RefCounted

const TEAM_COLORS := {1: Color(0.45, 0.72, 1.0), 2: Color(1.0, 0.42, 0.36)}
const TEAM_NAMES := {1: "Azul", 2: "Rojo"}
# Ritmo de las peleas por equipos (petición del usuario, 2026-09-16, tras medir rondas de ~17 s con
# ~7 s de pelea y ~10 s andando): vida ×3, definitiva por carga (Fighter.ULT_*), básicas que pueden
# fallar (Combat.PVP_HOMING_*) y un mapa más corto: el área limpia arranca al 65 % del mapa, así
# que las zonas de salida quedan más cerca, cuevas y esquinas son gas desde el principio, y el gas
# espera 25 s y cierra ×1,5. El daño del gas va ×3 como la vida, para que siga apretando igual.
const PVP_HP_MULT := 3.0
const PVP_ZONE_SCALE := 0.65
const ROUND_ZONE_WAIT := 25.0
const ROUND_ZONE_FAST := 1.5

var main: Main
var combat: Combat
var mode := ""
var size := 1
var rules: TeamMatch
var areas := {}
var autoplay := false
var hud: MatchHud
var ammo_bar: AmmoBar = null         # tu munición (null si tu leyenda dispara sin límite)
var revive: ReviveSystem             # levantar a los caídos y vuelta sola (Revive), por ronda
var over_t := -1.0                   # segundos desde el final (-1 = en juego)


func _init(p_main: Main) -> void:
	main = p_main
	combat = p_main.combat


func setup(p_mode: String) -> void:
	mode = p_mode
	size = GameModes.team_size(mode)
	main.nav = NavGrid.new()
	main.nav.build(main.grid)
	if main.zone_active():
		main._zone_r0 *= PVP_ZONE_SCALE
		if not main._args.has("zonewait"):
			main._zone_wait = ROUND_ZONE_WAIT
		if not main._args.has("zonefast"):
			main._zone_fast = ROUND_ZONE_FAST
		main.reset_zone()
	var radius := main._zone_r0 / Main.CELL if main.zone_active() else minf(main.mw, main.mh) * 0.5
	areas = GameModes.spawn_areas(main.grid, main.zones, radius)
	var pf := main.pf
	var legend := pf.legend
	if main._args.has("legend"):
		legend = int(main._args["legend"])
	elif Engine.has_meta("fl_legend"):
		legend = int(Engine.get_meta("fl_legend"))
	if legend != pf.legend:
		combat.set_legend(pf, legend)
	var picks := GameModes.pick_legends(pf.legend, size, Main.PLAYABLE, main.rng)
	# --foe=N: fija la leyenda del equipo rival (todas, si son varias). Solo para MEDIR: un torneo
	# por parejas necesita elegir el emparejamiento, y sin esto el rival salía del sorteo y unas
	# parejas se repetían y otras no salían nunca (2026-09-18).
	if main._args.has("foe"):
		var foe := clampi(int(main._args["foe"]), 0, LegendData.LEGENDS.size() - 1)
		for i in (picks[2] as Array).size():
			picks[2][i] = foe
	rules = TeamMatch.new()
	rules.setup(int(main._args.get("rounds", str(TeamMatch.ROUNDS_TO_WIN))),
		float(main._args.get("roundtime", str(TeamMatch.ROUND_TIME))))
	autoplay = main._args.has("autoplay")
	revive = ReviveSystem.new(main, _respawn_point)
	_apply_pvp_rules(pf)
	if pf.ammo_max > 0:
		ammo_bar = AmmoBar.new()
		pf.body.add_child(ammo_bar)
		# Pegada por debajo a la barra de vida, del mismo ancho.
		ammo_bar.setup(pf, combat.bar_height(pf) - Main.BAR_H * 0.5 - 0.03 - AmmoBar.HEIGHT * 0.5, Main.BAR_W)
	_place(pf, _area_cell(1, 0))
	pf.label = _label(pf, "Tú")
	rules.add_fighter(pf.id, "Tú (%s)" % pf.display_name, 1, pf.legend, true)
	if autoplay:
		pf.brain = BotBrain.new(pf, combat, main)
	for slot in range(1, size):
		_spawn_bot(int(picks[1][slot]), 1, slot)
	for slot in size:
		_spawn_bot(int(picks[2][slot]), 2, slot)
	var layer := CanvasLayer.new()
	layer.layer = 15
	main.add_child(layer)
	hud = MatchHud.new()
	layer.add_child(hud)
	hud.setup(self)
	var names := []
	for f: Fighter in combat.fighters:
		names.append("%s(%d)" % [f.display_name, f.team])
	print("[EQUIPOS] %s: %s · al mejor de %d rondas" % [mode, ", ".join(names), rules.rounds_to_win * 2 - 1])
	hud.banner("RONDA 1")


## Celda de salida para el hueco `slot` de un equipo: repartidas por la zona, no apiladas.
func _area_cell(team: int, slot: int) -> Vector2i:
	var cells: Array = areas.get(team, [])
	if cells.is_empty():
		return main._spawn_cell()
	return cells[(slot * 3) % cells.size()]


func _spawn_bot(legend: int, team: int, slot: int) -> Fighter:
	var c := _area_cell(team, slot)
	var f := combat.spawn_fighter(legend, team, false, main._cell_pos(c.x, c.y) + Vector3(0, 0.2, 0))
	_apply_pvp_rules(f)
	f.brain = BotBrain.new(f, combat, main)
	f.label = _label(f, f.display_name)
	rules.add_fighter(f.id, f.display_name, team, legend)
	_place(f, c)
	return f


## Reglas por equipos en una leyenda: vida ×3 (entera) y definitiva por carga, vacía.
func _apply_pvp_rules(f: Fighter) -> void:
	f.hp_mult = PVP_HP_MULT
	f.rec["hpmax"] = f.hp_max()
	f.rec["hp"] = f.hp_max()
	f.ult_by_charge = true
	f.ult_charge = 0.0
	f.enable_ammo()               # básica con munición (LegendData.PVP_AMMO; la Ilusionista, sin límite)
	f.enable_pvp_damage()         # daño de la básica por equipos (LegendData.PVP_BASIC_DMG)


## Dónde vuelve solo un caído: una celda de la zona de salida de su equipo, repartida por su id.
func _respawn_point(f: Fighter) -> Vector3:
	var c := _area_cell(f.team, f.id % maxi(size, 1))
	return main._cell_pos(c.x, c.y) + Vector3(0, 0.2, 0)


## Tu básica sin munición: la barra parpadea y suena a hueco.
func dry_fire() -> void:
	if ammo_bar != null:
		ammo_bar.dry_fire()


## Pone una leyenda en una celda mirando hacia el centro del mapa.
func _place(f: Fighter, c: Vector2i) -> void:
	var p := main._cell_pos(c.x, c.y) + Vector3(0, 0.2, 0)
	f.body.global_position = p
	f.body.velocity = Vector3.ZERO
	f.prev_pos = p
	f.last_seen = p
	var to := -p
	to.y = 0.0
	if f.model != null and to.length() > 0.1:
		f.model.rotation.y = atan2(to.x, to.z)
	if f.is_player:
		# La cámara detrás de la leyenda, mirando hacia donde mira ella.
		main._yaw = atan2(-to.x, -to.z)


## Nombre encima de la barra, del color de su equipo. Se lee a través de la hierba.
func _label(f: Fighter, text: String) -> Label3D:
	return make_label(f, text)


## Nombre sobre la barra de vida, del color de su equipo y visible a través de todo. Lo usa también
## la Horda en equipo.
static func make_label(f: Fighter, text: String) -> Label3D:
	var lbl := Label3D.new()
	lbl.text = text
	lbl.font_size = 44
	lbl.pixel_size = 0.004
	lbl.outline_size = 12
	lbl.modulate = TEAM_COLORS.get(f.team, Color.WHITE)
	lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lbl.no_depth_test = true
	lbl.render_priority = 10
	lbl.position = Vector3(0, f.bar.position.y + 0.32 if f.bar != null else 2.6, 0)
	f.body.add_child(lbl)
	return lbl


## Los cerebros piensan y deciden (antes de que el mundo avance).
func tick_brains(delta: float) -> void:
	var playing := rules.state == "playing"
	for f: Fighter in combat.fighters:
		if f.brain == null:
			continue
		if playing:
			(f.brain as BotBrain).tick(delta)
		else:
			f.wish = Vector3.ZERO


## Mueve a las leyendas que lleva un cerebro (tu leyenda solo con --autoplay).
func move_bots(delta: float) -> void:
	for f: Fighter in combat.fighters:
		if f.brain != null:
			combat.move_fighter(f, delta)


var _log_t := 0.0

## Relojes y eventos de ronda.
func tick(delta: float) -> void:
	if main._args.has("log") and rules.state == "playing":
		_log_t -= delta
		if _log_t <= 0.0:
			_log_t = 5.0
			_print_state()
	if rules.state == "playing":
		revive.tick(delta)
	var counts := _alive()
	rules.tick(delta, counts[0], counts[1])
	var ev := rules.take_event()
	while ev != "":
		match ev:
			"round_end":
				_on_round_end()
			"round_start":
				_reset_round()
			"over":
				_on_over()
		ev = rules.take_event()


## [{equipo: en pie}, {equipo: vida sumada en fracciones}]
func _alive() -> Array:
	var alive := {1: 0, 2: 0}
	var hp := {1: 0.0, 2: 0.0}
	for f: Fighter in combat.fighters:
		if f.alive():
			alive[f.team] = int(alive[f.team]) + 1
			hp[f.team] = float(hp[f.team]) + f.hp() / maxf(f.hp_max(), 1.0)
	return [alive, hp]


## --log: cada 5 s, ronda y cómo está cada leyenda (vida, a quién persigue y a qué distancia).
func _print_state() -> void:
	var parts := []
	for f: Fighter in combat.fighters:
		var what := "caído" if not f.alive() else "%d%%" % int(100.0 * f.hp() / f.hp_max())
		if f.brain != null and f.alive():
			var b := f.brain as BotBrain
			if b.fleeing:
				what += " huye"
			elif not b.target.is_empty() and is_instance_valid(b.target.get("node")):
				what += " a %.0fm" % f.pos().distance_to((b.target["node"] as Node3D).global_position)
			else:
				what += " busca"
		parts.append("%s(%d) %s" % [f.display_name, f.team, what])
	print("[PARTIDA] ronda %d %.0fs rondas %d-%d · %s" % [rules.round, rules.round_time - rules.round_time_left,
		int(rules.round_wins[1]), int(rules.round_wins[2]), " | ".join(parts)])


func _on_round_end() -> void:
	var lr := rules.last_round
	var w := int(lr.get("winner", 0))
	print("[RONDA] %d para %s (%s) · rondas %d-%d" % [int(lr.get("round", 0)),
		TEAM_NAMES.get(w, "nadie"), String(lr.get("reason", "")), int(rules.round_wins[1]), int(rules.round_wins[2])])
	for f: Fighter in combat.fighters:
		f.wish = Vector3.ZERO
	if hud != null and rules.state != "over":
		if w == 0:
			hud.banner("Ronda sin ganador")
		else:
			hud.banner("Ronda para %s" % TEAM_NAMES[w].to_upper(), TEAM_COLORS[w])


## Entre rondas: fuera todo lo que quedó en el suelo, gas nuevo y cada leyenda a su sitio, entera.
func _reset_round() -> void:
	combat.clear_world()
	main.reset_zone()
	var slots := {1: 0, 2: 0}
	for f: Fighter in combat.fighters:
		_revive(f, _area_cell(f.team, int(slots[f.team])))
		slots[f.team] = int(slots[f.team]) + 1
	print("[RONDA] empieza la %d" % rules.round)
	if hud != null:
		hud.banner("RONDA %d" % rules.round)


func _revive(f: Fighter, c: Vector2i) -> void:
	_place(f, c)
	f.downed = false              # derribados y muertos vuelven enteros en la ronda nueva
	f.bleed_t = 0.0
	f.downed_by = -1
	f.revive_progress = 0.0
	revive.restore_label(f)
	f.rec["hp"] = f.hp_max()
	f.rec["dead_t"] = -1.0
	for k in ["stun_t", "knock_t", "slow_t", "blind_t"]:
		f.rec[k] = 0.0
	f.rec["bar_t"] = 0.0
	f.since_damage = 0.0
	f.ult_charge = 0.0            # la definitiva empieza vacía en cada ronda
	combat.cure(f.rec)
	f.reset_abilities()
	f.windup = -1.0
	f.windup_idx = -1
	f.cast_anim_t = 0.0
	f.swing_charge_t = 0.0
	f.hidden_t = 0.0
	f.spotted_t = 0.0
	f.marked_t = 0.0             # la marca no pasa de una ronda a otra (el contorno se quita solo)
	f.streak = 0
	var cs := f.body.get_child(0) as CollisionShape3D
	if cs != null:
		cs.set_deferred("disabled", false)
	main._play_all(f.anims, "Idle")
	if f.brain != null:
		var b := f.brain as BotBrain
		b.fleeing = false
		b.target = {}


## Una leyenda ha sido derribada: aún no es baja (tiene 45 s para que la levanten).
func on_fighter_down(f: Fighter, by: Fighter) -> void:
	revive.on_down(f)
	rules.on_down(f.id)
	print("[DERRIBO] %s derriba a %s" % [by.display_name if by != null else "el gas", f.display_name])


## Una leyenda ha muerto (nadie la levantó): la baja es de quien la derribó. Marcador, racha e
## insignias (las tuyas), registro de bajas y, si su equipo se queda sin nadie en pie, fin de ronda.
func on_fighter_death(f: Fighter, by: Fighter) -> void:
	var ev := rules.on_kill(by.id if by != null else -1, f.id)
	if ev.get("counted", false) and by != null:
		by.kills += 1
		by.streak += 1
		if by.is_player:
			main._kills = by.kills
			main._show_badge(main._badge_for())
	var counts := _alive()
	print("[BAJA] %s muere%s · en pie %d-%d" % [f.display_name,
		(" a manos de " + by.display_name) if by != null else " (gas)",
		int(counts[0][1]), int(counts[0][2])])
	rules.check_elimination(counts[0])


func _on_over() -> void:
	var r := rules.result
	print("[FIN] ganador=%d rondas %d-%d en %d rondas · bajas %d-%d" % [int(r["winner"]),
		int(r["rounds"][1]), int(r["rounds"][2]), rules.round, rules.team_kills(1), rules.team_kills(2)])
	for f: Fighter in combat.fighters:
		f.wish = Vector3.ZERO
	if hud != null:
		hud.show_end()
	if main._shot == "" and main._args.get("probe", "") == "":
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


## Otra partida igual (mismo modo y misma leyenda).
func restart() -> void:
	Engine.set_meta("fl_seed", Main.new_seed())   # la revancha no repite el mismo sorteo
	Engine.set_meta("fl_mode", mode)
	Engine.set_meta("fl_legend", main.pf.legend)
	main.get_tree().reload_current_scene()


## Al menú de inicio.
func to_menu() -> void:
	if Engine.has_meta("fl_mode"):
		Engine.remove_meta("fl_mode")
	Engine.set_meta("fl_legend", main.pf.legend)
	main.get_tree().reload_current_scene()
