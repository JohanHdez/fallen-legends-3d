## Cerebro de un bot: maneja un Fighter como lo haría una persona, escribiendo `wish` y lanzando
## habilidades con Combat.try_cast. Adaptado de scripts/bot_brain.gd del juego 2D, con sus mismas
## cifras (THINK, distancias por leyenda en píxeles, huida al 35 % y vuelta al 65 %):
##  - piensa cada THINK s (escalonado por id para que no piensen todos en el mismo fotograma);
##  - si el gas le pilla o está a punto, lo primero es volver al área limpia;
##  - con poca vida huye del rival más cercano lanzando lo que le sirva para escapar;
##  - si no, busca al rival VISIBLE más cercano (agacharse en la hierba y la invisibilidad le
##    despistan, y los señuelos del Ilusionista le engañan) y se pone a la distancia de su leyenda;
##  - camina por la rejilla con NavGrid y se aparta de sus compañeros para no apelotonarse;
##  - rodea lo que el rival dejó puesto y se ve (trampas, balizas, nubes, tormentas, espinas) y sale
##    si le pilla dentro, como haría una persona (antes las pisaba a ciegas: 36 % del daño);
##  - con munición guarda el último disparo para cuando el rival está cerca;
##  - si un compañero ha caído y no tiene un rival encima, va a levantarlo agachándose a su lado.
class_name BotBrain
extends RefCounted

const PX := LegendData.PX
const THINK := 0.2
const SEARCH_RANGE := 1500.0 * PX       # 23 m
const STICKY_RANGE := 1800.0 * PX       # 28 m: sigue con su objetivo aunque haya otro más cerca
const FLEE_HP := 0.35
const RECOVER_HP := 0.65
const SKIP_CHANCE := 0.2                # a veces no hace nada: parece más humano
const AIM_ERROR := 25.0 * PX            # ±0,4 m de error al apuntar
const REPATH := 0.5
const ZONE_MARGIN := 4.0                # metros de holgura con el borde del gas
const DANGER_MARGIN := 1.2              # metros de holgura con el borde de una zona rival
const LAST_SHOT_REACH := 0.7            # el último disparo, solo con el rival a este tanto del alcance
const REVIVE_SAFE := 8.0                # va a levantar a un caído si no tiene un rival más cerca que esto
const CRAWL_STOP := 0.8                 # derribado, deja de arrastrarse a este tanto de Revive.RANGE (1,1 m)
const CRAWL_GO := 1.0                   # y no vuelve a arrancar hasta que el compañero sale del alcance
## Distancia a la que quiere pelear cada leyenda (px del juego 2D; las que no están, 70 px).
const DESIRED_RANGE := {"arquero": 380.0, "clerigo": 300.0, "liche": 340.0, "quimico": 340.0,
	"tormentero": 340.0, "ilusionista": 360.0, "ciclope": 85.0, "caballero": 90.0, "rompemareas": 110.0}
## ...pero esa tabla es del 2D y aquí dejaba a las de distancia peleando encima del rival: el Clérigo
## se plantaba a 4,7 m con un golpe que llega a 10,6 y se comía todos los cuerpo a cuerpo (era el
## arreglo pendiente de CLAUDE.md, "Clérigo flojo por el cerebro, no por el daño"). Si su básica es de
## distancia, quiere pelear a KEEP_RANGE de SU alcance, y nunca más cerca de lo que decía la tabla.
const KEEP_RANGE := 0.75

var f: Fighter
var combat: Combat
var main: Main
var target: Dictionary = {}
var fleeing := false
var _t := 0.0
var _goal := Vector3.ZERO
var _has_goal := false
var _path: Array[Vector2i] = []
var _path_goal := Vector2i(-999, -999)
var _path_t := 0.0
var _strafe := 1.0
var _strafe_t := 0.0
var _stuck_t := 0.0
var _nudge := Vector3.ZERO
var _nudge_t := 0.0
var _crawl_near := false


func _init(p_f: Fighter, p_combat: Combat, p_main: Main) -> void:
	f = p_f
	combat = p_combat
	main = p_main
	_t = THINK * float(p_f.id % 5) / 5.0


## Una vuelta de física: piensa cuando toca y siempre conduce hacia su meta.
func tick(delta: float) -> void:
	if not f.alive():
		target = {}
		_path.clear()
		f.wish = _crawl_to_help() if f.downed else Vector3.ZERO
		return
	_t -= delta
	if _t <= 0.0:
		_t = THINK
		_think()
	_steer(delta)


func _rng() -> RandomNumberGenerator:
	return combat.rng


func _hp_frac() -> float:
	return f.hp() / maxf(f.hp_max(), 1.0)


# ---------------------------------------------------------------- decisión

func _think() -> void:
	f.crouch = false                     # solo se agacha para levantar a alguien (abajo)
	target = _pick_target()
	_order_minions()
	var hp := _hp_frac()
	if fleeing and hp >= RECOVER_HP:
		fleeing = false
	elif not fleeing and hp < FLEE_HP:
		fleeing = true
	var d := INF
	if not target.is_empty():
		d = f.pos().distance_to((target["node"] as Node3D).global_position)

	# 1. El gas manda: fuera o casi en el borde, de vuelta al área limpia.
	if main.zone_active():
		var to_c := main._zone_c - f.pos()
		to_c.y = 0.0
		var margin := main._zone_r - to_c.length()
		if margin < ZONE_MARGIN:
			f.run = true              # del gas se sale corriendo
			_go(main._zone_c + (-to_c).normalized() * minf(main._zone_r * 0.5, 6.0))
			if not target.is_empty():
				_use_abilities(d, fleeing)
			return

	# 1b. Un compañero caído y nadie encima: ir a su lado y agacharse para levantarlo (el bot
	#     cooperativo del 2D; agacharse es el gesto que pidió el usuario).
	var fallen := _fallen_ally()
	if fallen != null and d > REVIVE_SAFE:
		var gap := Vector2(fallen.pos().x - f.pos().x, fallen.pos().z - f.pos().z).length()
		if gap > Revive.RANGE * 0.7:
			f.run = true              # a un compañero en el suelo se va corriendo
			_go(fallen.pos())
		else:
			f.run = false
			_stop()
			f.crouch = true
		return

	# 2. Con poca vida, huye del más cercano y lanza lo que le sirva para escapar.
	if fleeing and not target.is_empty():
		f.run = true                  # con poca vida, a la carrera
		var away := f.pos() - (target["node"] as Node3D).global_position
		away.y = 0.0
		var dest := f.pos() + away.normalized() * 8.0
		if main.zone_active():
			dest = dest.lerp(main._zone_c, 0.35)
		_go(dest)
		_use_abilities(d, true)
		return

	# 3. Sin nadie a la vista: hacia el centro del área limpia, que es donde acaba la pelea.
	if target.is_empty():
		var goal := main._zone_c if main.zone_active() else Vector3.ZERO
		if f.pos().distance_to(goal) < 4.0:
			_stop()
		else:
			f.run = false             # sin nadie a la vista no hay prisa
			_go(goal)
		return

	# 4. Pelea a su distancia: se acerca, se aleja (a distancia) o se mueve de lado.
	var want := desired_range(String(f.data()["id"]), f.ability_range(0),
		String(f.abil(0)["k"]) == "melee")
	var tpos: Vector3 = (target["node"] as Node3D).global_position
	var to := tpos - f.pos()
	to.y = 0.0
	if d > want:
		# El que persigue CORRE (petición del usuario, 2026-09-18: "revisa cómo balancear más"). Los
		# bots nunca usaban `run` y, desde que los de distancia pelean a su alcance, un cuerpo a cuerpo
		# andando detrás de uno que retrocede no lo alcanzaba jamás: el Rompemareas se desplomó del
		# 85 % al 23 % de duelos ganados. Correr es del que va a por alguien, no del que se aparta: si
		# corrieran los dos, no se alcanzarían igual.
		f.run = true
		_go(tpos)
	elif d < want * 0.5 and want > 3.0:
		f.run = false
		_go(f.pos() - to.normalized() * 3.5)
	else:
		f.run = false
		_strafe_t -= THINK
		if _strafe_t <= 0.0:
			_strafe_t = _rng().randf_range(1.0, 2.2)
			_strafe = -_strafe
		var perp := to.normalized().cross(Vector3.UP)
		_go(f.pos() + perp * _strafe * 2.5)
		if f.model != null and to.length() > 0.1:
			f.model.rotation.y = atan2(to.x, to.z)
	if _rng().randf() < SKIP_CHANCE:
		return
	_use_abilities(d, false)


## Metros a los que quiere pelear: los de la tabla del 2D si pega de cerca, y si no, lo que más le
## convenga entre esa distancia y KEEP_RANGE de su propio alcance.
static func desired_range(id: String, basic_range: float, melee: bool) -> float:
	var table := float(DESIRED_RANGE.get(id, 70.0)) * PX
	return table if melee else maxf(table, basic_range * KEEP_RANGE)


## Rey liche: sus esqueletos atacan mientras pelea y se reagrupan cuando huye. No emboscan.
func _order_minions() -> void:
	if f.minion_order == "ambush" or combat.minions.of(f).is_empty():
		return
	var want := "regroup" if fleeing else "attack"
	if f.minion_order != want:
		combat.minions.set_order(f, want)


## El compañero caído más cercano, o null.
func _fallen_ally() -> Fighter:
	if f.team == Fighter.TEAM_HORDE:
		return null                      # el jefe de la Horda no levanta a jefes de oleadas pasadas
	var best: Fighter = null
	var best_d := INF
	for o: Fighter in combat.fighters:
		if o != f and o.team == f.team and o.downed:
			var od := o.pos().distance_to(f.pos())
			if od < best_d:
				best_d = od
				best = o
	return best


## El rival visible más cercano; se queda con el de antes mientras siga vivo, a la vista y a tiro.
## Un rival marcado por romper un señuelo de su equipo va antes que nadie.
func _pick_target() -> Dictionary:
	var marked: Fighter = null
	var marked_d := SEARCH_RANGE
	for o: Fighter in combat.fighters:
		if o.team != f.team and o.alive() and o.marked_for(f.team):
			var md := o.pos().distance_to(f.pos())
			if md <= marked_d:
				marked_d = md
				marked = o
	if marked != null:
		return marked.rec
	if not target.is_empty() and _still_valid(target):
		var d := f.pos().distance_to((target["node"] as Node3D).global_position)
		if d <= STICKY_RANGE:
			return target
	# Primero a quien está en pie; a un derribado solo si no hay nadie más (rematar le quita tiempo).
	var near := combat.foes_in(f.team, f.pos(), SEARCH_RANGE, 6, true)
	for z in near:
		if String(z.get("kind", "")) != "fighter" or float(z.get("hp", 0.0)) > 0.0:
			return z
	return near[0] if not near.is_empty() else {}


## Derribado: se arrastra hacia el compañero en pie más cercano para que lo levante.
func _crawl_to_help() -> Vector3:
	var best: Fighter = null
	var best_d := INF
	for o: Fighter in combat.fighters:
		if o != f and o.team == f.team and o.alive():
			var od := o.pos().distance_to(f.pos())
			if od < best_d:
				best_d = od
				best = o
	_crawl_near = best != null and crawl_close(_crawl_near, best_d)
	if best == null or _crawl_near:
		return Vector3.ZERO
	var to := best.pos() - f.pos()
	to.y = 0.0
	return to.normalized()


func _still_valid(z: Dictionary) -> bool:
	if not is_instance_valid(z.get("node")):
		return false
	if float(z.get("hp", 0.0)) <= 0.0 or float(z.get("dead_t", -1.0)) >= 0.0:
		return false
	if String(z.get("kind", "")) == "fighter":
		var o := combat.fighter_by_id(int(z["fid"]))
		if o == null or combat.is_hidden(o):
			return false
	return true


## Qué lanzar, por tipo de habilidad (como bot_brain._use_abilities del 2D). Prueba la definitiva y
## la táctica antes que la básica: con la básica casi siempre lista, si fuera primero no lanzaría
## nunca lo demás.
func _use_abilities(d: float, escaping: bool) -> void:
	if f.windup >= 0.0 or f.dash_left > 0.0:
		return
	var tpos := f.pos() + f.facing() * 3.0
	if not target.is_empty():
		tpos = (target["node"] as Node3D).global_position
	var low := _hp_frac() < 0.4
	for i in [2, 1, 0]:
		var ab := f.abil(i)
		# Intercambio con el señuelo: solo para escapar (si no, se teletransportaría sin parar).
		if ab.get("swap", false) and not combat.decoy_alive(f).is_empty():
			if escaping:
				combat.try_cast(f, i, tpos)
				if f.swap_t > 0.0:
					# Se ha teletransportado al señuelo: lo que tenía cerca ya no es lo mismo.
					target = _pick_target()
					return
			continue
		if not f.ability_ready(i):
			continue
		var rng_m := f.ability_range(i)
		var rad := f.ability_radius(i)
		var use := false
		var at := _aim(tpos, rng_m)
		match String(ab["k"]):
			"melee":
				use = not target.is_empty() and d < rad + 0.6
			"proj":
				use = not target.is_empty() and (should_shoot(f.ammo, f.ammo_max, d, rng_m) if i == 0 else d < rng_m)
			"dash":
				if bool(ab.get("back", false)):
					use = not target.is_empty() and d < 2.3
				else:
					use = not escaping and not target.is_empty() and d > 2.3 and d < rng_m + 1.2
			"heal":
				use = low or (_hp_frac() < 0.7 and _rng().randf() < 0.3) or _ally_hurt(rad)
			"buff":
				# Ancla clavada: ahora se planta donde apunta (no a sus pies), así que la usa en cuanto
				# tiene al objetivo dentro del alcance (usuario, 2026-09-18).
				use = not escaping and not target.is_empty() and d < rng_m \
					and (low or _rng().randf() < 0.3)
			"zone":
				var reach := rng_m if float(ab.get("rng", 0.0)) > 0.0 else rad
				use = not target.is_empty() and d < reach
				if float(ab.get("rng", 0.0)) <= 0.0:
					at = f.pos()
			"gas", "spores", "trap":
				use = not target.is_empty() and d < rng_m
			"beacon":
				use = not target.is_empty() and d < 7.0
				at = f.pos() + (tpos - f.pos()).limit_length(3.0)
			"spikes":
				use = not escaping and not target.is_empty() and d < rng_m * 0.8
			"summon":
				use = not target.is_empty() and d < 15.0
			"decoy":
				use = not target.is_empty() and d < 11.0
		if use:
			combat.try_cast(f, i, at)
			if f.windup >= 0.0:
				return


## Punto al que apunta: el objetivo con un poco de error, sin pasarse del alcance.
func _aim(tpos: Vector3, reach: float) -> Vector3:
	var err := Vector3(_rng().randf_range(-AIM_ERROR, AIM_ERROR), 0.0, _rng().randf_range(-AIM_ERROR, AIM_ERROR))
	var off := tpos + err - f.pos()
	off.y = 0.0
	var at := f.pos() + off.limit_length(reach)
	at.y = 0.0
	return at


func _ally_hurt(rad: float) -> bool:
	for o: Fighter in combat.fighters:
		if o != f and o.team == f.team and o.alive() and o.hp() < o.hp_max() * 0.5 \
				and o.pos().distance_to(f.pos()) <= rad:
			return true
	return false


# ---------------------------------------------------------------- conducción

func _go(to: Vector3) -> void:
	_goal = Vector3(to.x, 0.0, to.z)
	_has_goal = true


func _stop() -> void:
	_has_goal = false
	f.run = false


func _steer(delta: float) -> void:
	if not _has_goal:
		f.wish = _avoid_danger(f.pos(), Vector3.ZERO).normalized()   # quieto, pero no dentro de una zona
		return
	var pos := f.pos()
	var flat := Vector3(pos.x, 0.0, pos.z)
	if flat.distance_to(_goal) < 0.6:
		f.wish = _avoid_danger(pos, Vector3.ZERO).normalized()
		return
	var dir := _goal - flat
	var here := main._cell_of(pos)
	var there := main._cell_of(_goal)
	if here != there and main.nav != null:
		_path_t -= delta
		if there != _path_goal or _path_t <= 0.0 or _path.is_empty():
			_path = main.nav.path(here, there)
			_path_goal = there
			_path_t = REPATH
		# Siguiente celda del camino que no sea la actual (y que no esté ya a un paso).
		while _path.size() > 1 and (_path[0] == here or \
				Vector3(main._cell_pos(_path[0].x, _path[0].y)).distance_to(flat) < 0.9):
			_path.remove_at(0)
		if not _path.is_empty():
			dir = main._cell_pos(_path[0].x, _path[0].y) - flat
	dir.y = 0.0
	# Apartarse de los compañeros: pegados se pisan las habilidades y parecen uno solo.
	for o: Fighter in combat.fighters:
		if o == f or o.team != f.team or not o.alive():
			continue
		var away := flat - Vector3(o.pos().x, 0.0, o.pos().z)
		var l := away.length()
		if l > 0.01 and l < 1.6:
			dir += away / l * (1.6 - l) * 2.0
	# Atascado contra algo: un empujón de lado un momento.
	if _nudge_t > 0.0:
		_nudge_t -= delta
		dir += _nudge * 2.0
	elif f.step.length() < 0.01 and f.wish.length() > 0.1 and not combat.is_locked(f):
		_stuck_t += delta
		if _stuck_t > 0.8:
			_stuck_t = 0.0
			_nudge = dir.normalized().cross(Vector3.UP) * (1.0 if _rng().randf() < 0.5 else -1.0)
			_nudge_t = 0.5
			_path_t = 0.0
	else:
		_stuck_t = 0.0
	dir = _avoid_danger(pos, dir.normalized() if dir.length() > 0.01 else Vector3.ZERO)
	f.wish = dir.normalized() if dir.length() > 0.01 else Vector3.ZERO


## Rodea (o abandona) lo que dejó puesto el equipo rival. En el gas no: salir del gas manda.
func _avoid_danger(pos: Vector3, dir: Vector3) -> Vector3:
	if main.zone_active():
		var to_c := main._zone_c - pos
		to_c.y = 0.0
		if to_c.length() > main._zone_r:
			return dir
	for t in combat.traps:
		if int(t["team"]) != f.team:
			dir = steer_around(pos, dir, (t["node"] as Node3D).position, float(t["rad"]))
	for bc in combat.beacons:
		if int(bc["team"]) != f.team and not bc["spent"]:
			dir = steer_around(pos, dir, (bc["node"] as Node3D).global_position, Combat.BEACON_TRIGGER)
	for st in combat.storms:
		if int(st["team"]) != f.team:
			dir = steer_around(pos, dir, (st["node"] as Node3D).position, float(st["rad"]))
	for sp in combat.spikes:
		if int(sp["team"]) != f.team:
			for n in sp["nodes"]:
				dir = steer_around(pos, dir, (n as Node3D).position, float(sp["rad"]))
	return dir


## Derribado junto a un compañero: ¿ya está lo bastante cerca para quedarse quieto? Con margen: para a
## CRAWL_STOP del alcance y no arranca hasta CRAWL_GO. Antes paraba a 0,84 m y los cuerpos, que chocan
## a 0,8, lo empujaban fuera del umbral: paraba y arrancaba en cada fotograma (la animación parpadeaba).
static func crawl_close(was_close: bool, d: float) -> bool:
	return d <= Revive.RANGE * (CRAWL_GO if was_close else CRAWL_STOP)


## ¿Dispara la básica? A tiro, y si le queda un solo disparo, solo con el rival bastante cerca: así
## no vacía la munición en tiros que casi seguro fallan. `ammo_max` 0 = sin límite.
static func should_shoot(ammo: int, ammo_max: int, d: float, reach: float) -> bool:
	if d >= reach:
		return false
	if ammo_max <= 0 or ammo >= 2:
		return true
	return ammo == 1 and d < reach * LAST_SHOT_REACH


## Dirección `dir` corregida para no meterse en una zona redonda (centro, radio): dentro, sale; al
## borde y yendo hacia dentro, sigue de lado rodeándola; si no le estorba, la deja igual.
static func steer_around(pos: Vector3, dir: Vector3, center: Vector3, radius: float) -> Vector3:
	var out := Vector3(pos.x - center.x, 0.0, pos.z - center.z)
	var l := out.length()
	if l >= radius + DANGER_MARGIN:
		return dir
	var away := out / l if l > 0.01 else Vector3(1, 0, 0)
	if l < radius:
		return dir * 0.3 + away * 2.0           # dentro: salir manda
	var inward := -dir.dot(away)
	if inward <= 0.0:
		return dir                               # se aleja o va de lado
	var side := dir + away * inward              # quita lo que entra: sigue de lado
	if side.length() < 0.2:
		side = away.cross(Vector3.UP)            # de frente al centro: un lado fijo
	return side + away * 0.2
