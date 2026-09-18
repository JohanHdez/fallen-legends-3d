## La Horda en equipo (petición del usuario, 2026-09-17): tú solo o con 1, 2 o 3 compañeros bot con
## leyendas distintas. Un caído se levanta si un compañero se agacha a su lado, o vuelve solo al centro
## del área limpia a los 15/30/60 s mientras quede alguien en pie (ReviveSystem). Si cae todo el
## equipo —o tú, si vas solo—, se acaba la partida. Las criaturas y las oleadas siguen en Horde.
class_name HordeMode
extends RefCounted

const MAX_TEAM := 4
const END_DELAY := 2.0                 # s desde la última caída hasta la pantalla final
# Dónde salen los compañeros, alrededor de ti (donde estaban las estatuas de compañeros).
const TEAM_SPOTS := [Vector3(3.0, 0, 1.5), Vector3(-3.0, 0, 1.5), Vector3(0, 0, 3.5)]

var main: Main
var combat: Combat
var size := 1
var autoplay := false
var revive: ReviveSystem
var hud: HordeHud
var over := false
var won := false                       # la Horda se superó (10 oleadas)
var time := 0.0                        # segundos de partida (pantalla final)
var _wipe_t := -1.0


func _init(p_main: Main) -> void:
	main = p_main
	combat = p_main.combat


func setup(p_size: int) -> void:
	size = clampi(p_size, 1, MAX_TEAM)
	autoplay = main._args.has("autoplay")
	main.nav = NavGrid.new()               # los cerebros de bot caminan con A*
	main.nav.build(main.grid)
	revive = ReviveSystem.new(main, _respawn_point)
	var pf := main.pf
	# La leyenda elegida en el menú (antes la Horda la ignoraba y salías siempre con el Tormentero).
	# Solo con --legend la aplica main.gd, y con compañeros hay que tenerla ANTES del reparto.
	var legend := pf.legend
	if main._args.has("legend"):
		if size > 1:
			legend = int(main._args["legend"])
	elif Engine.has_meta("fl_legend"):
		legend = clampi(int(Engine.get_meta("fl_legend")), 0, Main.PLAYABLE - 1)
	if legend != pf.legend:
		main.set_legend(legend)
	if autoplay:
		pf.brain = BotBrain.new(pf, combat, main)
	if size > 1:
		pf.label = TeamMode.make_label(pf, "Tú")
		# Solo con compañeros se sortea: jugando solo no se toca el rng (las trazas siguen iguales).
		var picks := GameModes.pick_legends(pf.legend, size, Main.PLAYABLE, main.rng)
		for slot in range(1, size):
			var at: Vector3 = pf.pos() + TEAM_SPOTS[slot - 1]
			var f := combat.spawn_fighter(int(picks[1][slot]), Fighter.TEAM_BLUE, false, at)
			f.brain = BotBrain.new(f, combat, main)
			f.label = TeamMode.make_label(f, f.display_name)
	var layer := CanvasLayer.new()
	layer.layer = 15
	main.add_child(layer)
	hud = HordeHud.new()
	layer.add_child(hud)
	hud.setup(self)
	if size > 1:
		print("[HORDA] equipo de %d: %s" % [size, ", ".join(team().map(func(f: Fighter) -> String: return f.display_name))])


## Las leyendas del equipo (la tuya la primera).
func team() -> Array:
	return combat.fighters.filter(func(f: Fighter) -> bool: return f.team == Fighter.TEAM_BLUE)


func team_alive() -> int:
	var n := 0
	for f: Fighter in team():
		if f.alive():
			n += 1
	return n


## Cerebros de los compañeros (y el tuyo con --autoplay), antes de que el mundo avance.
func tick_brains(delta: float) -> void:
	if over:
		return
	for f: Fighter in combat.fighters:
		if f.brain != null:
			(f.brain as BotBrain).tick(delta)


func move_bots(delta: float) -> void:
	for f: Fighter in combat.fighters:
		if f.brain != null:
			if over:
				f.wish = Vector3.ZERO
			combat.move_fighter(f, delta)


## Reanimaciones y derrota.
func tick(delta: float) -> void:
	if over:
		return
	time += delta
	revive.tick(delta)
	if team_alive() > 0:
		_wipe_t = -1.0
		return
	if _wipe_t < 0.0:
		_wipe_t = 0.0
	_wipe_t += delta
	if _wipe_t >= END_DELAY:
		_finish()


## Derribada: 45 s para que la levanten (el jefe no tiene quien lo levante y muere al momento).
func on_fighter_down(f: Fighter, by: Fighter) -> void:
	revive.on_down(f)
	if f.team == Fighter.TEAM_BLUE:
		print("[DERRIBO] %s derribada%s · en pie %d de %d" % [f.display_name,
			(" por " + by.display_name) if by != null else "", team_alive(), size])


## Muerta: el jefe cuenta como abatido; una del equipo vuelve al empezar la oleada siguiente.
func on_fighter_death(f: Fighter, by: Fighter) -> void:
	if f.team == Fighter.TEAM_HORDE:
		main.horde.on_boss_down(f, by)
		return
	print("[BAJA] %s muere · vuelve en la oleada siguiente · en pie %d de %d" % [f.display_name, team_alive(), size])


## Oleada nueva: las muertas del equipo vuelven enteras al centro del área limpia (decisión del
## usuario: muerta no se levanta, pero no se queda fuera de la partida).
func on_wave_start() -> void:
	if over:
		return
	# Ahora la partida tiene final (10 oleadas): se anuncia cuál toca y si trae jefes.
	if hud != null and main.horde != null:
		var n := Horde.boss_count(main.horde.wave)
		var txt := "Oleada %d de %d" % [main.horde.wave, Horde.WAVES]
		if n == 1:
			txt += " · ¡ROMPEMAREAS!"
		elif n > 1:
			txt += " · ¡%d ROMPEMAREAS!" % n
		hud.banner(txt)
	for f: Fighter in team():
		if f.dead():
			revive.stand_up(f, _respawn_point(f), 1.0)
			print("[VUELVE] %s vuelve con la oleada %d" % [f.display_name, main.horde.wave])


## Dónde vuelve solo un caído: la celda transitable más cercana al centro del área limpia.
func _respawn_point(_f: Fighter) -> Vector3:
	var center := main._zone_c if main.zone_active() else main.player.global_position
	var c := main._cell_of(center)
	if main._in_map(c) and MapBuilder.walkable(main.grid[c.x][c.y]):
		return main._cell_pos(c.x, c.y) + Vector3(0, 0.2, 0)
	var best := main._spawn_cell()
	var best_d := INF
	for cell: Vector2i in main._cells_around(c, 6):
		var d := Vector2(cell - c).length()
		if d < best_d:
			best_d = d
			best = cell
	return main._cell_pos(best.x, best.y) + Vector3(0, 0.2, 0)


## Oleada 10 superada: la Horda se gana (esquema del usuario, 2026-09-17; antes no acababa nunca).
func on_victory() -> void:
	if over:
		return
	won = true
	_finish()


func _finish() -> void:
	over = true
	for f: Fighter in combat.fighters:
		f.wish = Vector3.ZERO
	print("[FIN] horda: %s en la oleada %d tras %.0f s · bajas/caídas/muertes %s" % [
		"SUPERADA" if won else "el equipo cae", main.horde.wave, time,
		", ".join(team().map(func(f: Fighter) -> String: return "%s %d/%d/%d" % [
			f.display_name, _kills_of(f), f.downs, f.deaths]))])
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	# La insignia de racha que estuviera en pantalla taparía los botones de la pantalla final.
	if main._badge_tween != null:
		main._badge_tween.kill()
	for n in [main._badge_img, main._badge_cap]:
		if n != null:
			(n as CanvasItem).hide()
	if hud != null:
		hud.show_end()


## Bajas de una leyenda: las tuyas las lleva main (insignias), las de los bots su Fighter.
func _kills_of(f: Fighter) -> int:
	return main._kills if f.is_player else f.kills


func kills_of(f: Fighter) -> int:
	return _kills_of(f)


func restart() -> void:
	Engine.set_meta("fl_seed", Main.new_seed())   # la revancha no repite el mismo sorteo
	Engine.set_meta("fl_mode", "horda")
	Engine.set_meta("fl_horde_team", size)
	Engine.set_meta("fl_legend", main.pf.legend)
	main.get_tree().reload_current_scene()


func to_menu() -> void:
	if Engine.has_meta("fl_mode"):
		Engine.remove_meta("fl_mode")
	Engine.set_meta("fl_legend", main.pf.legend)
	main.get_tree().reload_current_scene()
