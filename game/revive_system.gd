## Aplica las reglas de Revive cada fotograma, en la Horda en equipo y en PvP: una leyenda derribada se
## levanta si un compañero en pie se agacha 3 s a su lado (él se arrodilla); si pasan los 45 s, o no
## queda nadie de su equipo en pie, muere (Combat.kill_downed) y la baja es de quien la derribó. Muerta
## no se levanta: en PvP vuelve en la ronda siguiente y en la Horda al empezar la oleada siguiente
## (`stand_up` en `respawn_at`, que pone cada modo). Peticiones del usuario, 2026-09-17.
class_name ReviveSystem
extends RefCounted

const DOWN_COLOR := Color(1.0, 0.55, 0.25)
const DEAD_COLOR := Color(0.6, 0.6, 0.65)
const INVULN_COLOR := Color(1.0, 0.75, 0.3, 0.35)

var main: Main
var combat: Combat
var respawn_at: Callable          # func(f: Fighter) -> Vector3: dónde vuelve una muerta
var revives := 0                  # levantados por un compañero (sondas)
var bled_out := 0                 # muertos porque nadie los levantó a tiempo (sondas)


func _init(p_main: Main, p_respawn_at: Callable) -> void:
	main = p_main
	combat = p_main.combat
	respawn_at = p_respawn_at


## Una leyenda acaba de ser derribada (Combat ya le puso los 45 s).
func on_down(f: Fighter) -> void:
	f.revive_progress = 0.0
	_show_label(f)


func tick(delta: float) -> void:
	for f: Fighter in combat.fighters:
		f.reviving = false
	for f: Fighter in combat.fighters:
		_tick_invuln(f)
		if not f.downed:
			continue
		if not _teammate_standing(f):
			combat.kill_downed(f)         # nadie puede levantarla: muere ya
			_show_label(f)
			continue
		var helper := helper_of(f)
		f.revive_progress = Revive.progress(f.revive_progress, helper != null, delta)
		if helper != null:
			helper.reviving = true
		if f.revive_progress >= 1.0:
			stand_up(f, f.pos(), Revive.HP)
			revives += 1
			print("[REANIMA] %s levanta a %s" % [helper.display_name, f.display_name])
			continue
		if helper == null:
			f.bleed_t -= delta             # mientras la levantan, el tiempo no corre
		if f.bleed_t <= 0.0:
			bled_out += 1
			combat.kill_downed(f)
		_show_label(f)


## El compañero de su equipo que la está levantando (en pie, agachado y a su lado), o null.
func helper_of(f: Fighter) -> Fighter:
	for o: Fighter in combat.fighters:
		if o == f or o.team != f.team:
			continue
		var d := Vector2(o.pos().x - f.pos().x, o.pos().z - f.pos().z).length()
		if Revive.can_help(o.alive(), o.crouch, d):
			return o
	return null


## La leyenda derribada a la que `helper` está levantando, o null.
func helping(helper: Fighter) -> Fighter:
	for f: Fighter in combat.fighters:
		if f.downed and f.team == helper.team and helper_of(f) == helper:
			return f
	return null


## De pie en `at` con `hp_frac` de su vida, inmune un rato y sin nada a medias.
func stand_up(f: Fighter, at: Vector3, hp_frac: float) -> void:
	var p := Vector3(at.x, maxf(at.y, 0.2), at.z)
	f.body.global_position = p
	f.body.velocity = Vector3.ZERO
	f.prev_pos = p
	f.last_seen = p
	f.downed = false
	f.bleed_t = 0.0
	f.downed_by = -1
	f.rec["hp"] = f.hp_max() * hp_frac
	f.rec["dead_t"] = -1.0
	for k in ["stun_t", "knock_t", "slow_t", "blind_t"]:
		f.rec[k] = 0.0
	f.rec["bar_t"] = 0.0
	f.since_damage = 0.0
	f.revive_progress = 0.0
	f.invuln_t = Revive.INVULN
	f.windup = -1.0
	f.windup_idx = -1
	f.cast_anim_t = 0.0
	f.swing_charge_t = 0.0
	f.marked_t = 0.0
	var cs := f.body.get_child(0) as CollisionShape3D
	if cs != null:
		cs.set_deferred("disabled", false)
	main._play_all(f.anims, "Idle")
	if f.brain != null:
		var b := f.brain as BotBrain
		b.fleeing = false
		b.target = {}
		b._t = 0.0                 # que piense ya: si no, pasa hasta 0,2 s sin objetivo
	restore_label(f)


## Burbuja dorada mientras no recibe daño.
func _tick_invuln(f: Fighter) -> void:
	if f.invuln_t > 0.0 and f.alive():
		if f.invuln_fx == null:
			f.invuln_fx = main.vfx.bubble(0.95, INVULN_COLOR)
			f.invuln_fx.position = Vector3(0, 1.0, 0)
			f.body.add_child(f.invuln_fx)
	elif f.invuln_fx != null:
		f.invuln_fx.queue_free()
		f.invuln_fx = null


func _teammate_standing(f: Fighter) -> bool:
	for o: Fighter in combat.fighters:
		if o != f and o.team == f.team and o.alive():
			return true
	return false


## Sobre la leyenda: "¡DERRIBADO! 32 s" (o el progreso si la levantan) o "MUERTO", a través de todo.
func _show_label(f: Fighter) -> void:
	if f.label == null:
		return
	if not f.label.has_meta("name_text"):
		f.label.set_meta("name_text", f.label.text)
		f.label.set_meta("name_color", f.label.modulate)
	if f.downed:
		if f.revive_progress > 0.0:
			f.label.text = "¡DERRIBADO! levantando %d %%" % int(f.revive_progress * 100.0)
		else:
			f.label.text = "¡DERRIBADO! %d s" % int(ceil(f.bleed_t))
		f.label.modulate = DOWN_COLOR
	elif f.dead():
		f.label.text = "MUERTO"
		f.label.modulate = DEAD_COLOR
	# Sus señuelos, en el mismo fotograma: el porcentaje cambia en cada uno y si van por detrás se
	# sabe cuál es la de verdad (petición vieja del usuario, fallo cazado el 2026-09-18).
	combat.sync_decoy_labels(f)


func restore_label(f: Fighter) -> void:
	if f.label != null and f.label.has_meta("name_text"):
		f.label.text = String(f.label.get_meta("name_text"))
		f.label.modulate = f.label.get_meta("name_color")
		f.label.remove_meta("name_text")
		f.label.remove_meta("name_color")
		combat.sync_decoy_labels(f)
