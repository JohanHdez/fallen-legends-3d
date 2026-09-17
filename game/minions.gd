## Esqueletos del Rey liche y sus órdenes (petición del usuario, 2026-09-17): con un solo botón,
## tocar alterna Atacar / Reagrupar y arrastrar coloca una Emboscada.
##  - Atacar: cada esqueleto va al enemigo visible más cercano a él, esté donde esté, rodeando
##    obstáculos; si no hay nadie, vuelve con el Rey.
##  - Reagrupar: le siguen en dos anillos (4 a 2 m y 6 a 3,5 m), separados; golpean a quien tengan a
##    2 m, sin perseguir.
##  - Emboscada: van al punto, se reparten en 3 m y se entierran (medio hundidos, translúcidos para su
##    equipo e invisibles para el rival: `Combat.foes_in` y las criaturas no los ven). Si un enemigo
##    entra a 4 m de cualquiera, salen todos y pasan a Atacar.
## Las reglas puras son estáticas (tests/test_minions.gd); la IA de cada esqueleto la llama
## Combat.tick_allies después del empujón y el aturdimiento.
class_name Minions
extends RefCounted

const ORDERS := ["attack", "regroup", "ambush"]
const ORDER_NAMES := {"attack": "Atacar", "regroup": "Reagrupar", "ambush": "Emboscada"}
const RING_IN := 2.0
const RING_OUT := 3.5
const AMBUSH_RADIUS := 3.0
const AMBUSH_RANGE := 12.0
const AMBUSH_TRIGGER := 4.0
const HIT_REACH := 2.0
const HIT_DMG := 18.0
const HIT_EVERY := 1.4
const SPEED := 200.0 * LegendData.PX       # 3,1 m/s, la del esbirro del 2D (enemy_type.speed)
const ATTACK_SEARCH := 80.0                # "esté donde esté": todo el mapa
const BURY_DEPTH := 0.9

var combat: Combat
var main: Main


func _init(p_combat: Combat) -> void:
	combat = p_combat
	main = p_combat.main


# ---------------------------------------------------------------- reglas puras

## Hueco `i` de la formación alrededor del Rey: los 4 primeros en el anillo de RING_IN, los 6
## siguientes en el de RING_OUT, desfasados para que no queden en fila; a partir del 10, se repite.
static func formation_slot(i: int) -> Vector2:
	var k := i % 10
	if k < 4:
		return Vector2.from_angle(TAU * (float(k) + 0.5) / 4.0) * RING_IN
	return Vector2.from_angle(TAU * float(k - 4) / 6.0) * RING_OUT


## Hueco `i` de `n` en la emboscada: espiral de girasol dentro de AMBUSH_RADIUS (repartidos sin
## amontonarse, sean los que sean).
static func ambush_slot(i: int, n: int) -> Vector2:
	var r := AMBUSH_RADIUS * sqrt((float(i) + 0.5) / float(maxi(n, 1)))
	return Vector2.from_angle(float(i) * deg_to_rad(137.508)) * r


## Tocar el botón: Atacar ↔ Reagrupar; desde la emboscada, Atacar.
static func toggle(order: String) -> String:
	return "attack" if order != "attack" else "regroup"


## Dónde queda la emboscada si apuntas a `at` desde `from`: en el suelo y a AMBUSH_RANGE como mucho.
static func ambush_point(from: Vector3, at: Vector3) -> Vector3:
	var d := Vector3(at.x - from.x, 0.0, at.z - from.z).limit_length(AMBUSH_RANGE)
	return Vector3(from.x + d.x, 0.0, from.z + d.z)


# ---------------------------------------------------------------- órdenes

## Esqueletos vivos de una leyenda, en el orden en que salieron.
func of(f: Fighter) -> Array:
	var out: Array = []
	for al in combat.allies:
		if al["kind"] == "minion" and int(al.get("owner", -1)) == f.id and float(al["hp"]) > 0.0:
			out.append(al)
	return out


func set_order(f: Fighter, order: String, at := Vector3.INF) -> void:
	if order == "ambush":
		f.ambush_at = ambush_point(f.pos(), at if at != Vector3.INF else f.pos())
	var changed: bool = f.minion_order != order
	f.minion_order = order
	for al in of(f):
		al["path"] = []
		if order != "ambush" and al.get("hidden", false):
			_rise(al)
	if changed:
		print("[ORDEN] %s manda a sus esqueletos: %s" % [f.display_name, ORDER_NAMES[order]])


# ---------------------------------------------------------------- un esqueleto

func tick(al: Dictionary, body: CharacterBody3D, delta: float) -> void:
	al["swing_t"] = maxf(0.0, float(al["swing_t"]) - delta)
	var owner := combat.fighter_by_id(int(al["owner"]))
	var team := int(al["team"])
	var pos := body.global_position
	var order: String = owner.minion_order if owner != null else "attack"
	var slot := int(al.get("slot_i", 0))
	match order:
		"attack":
			var foes := combat.foes_in(team, pos, ATTACK_SEARCH, 1, true)
			if not foes.is_empty():
				_engage(al, body, foes[0], delta, true)
			elif owner != null:
				_go(al, body, _formation_pos(owner, slot), delta)
			else:
				_idle(al, body, delta)
		"regroup":
			var near := combat.foes_in(team, pos, HIT_REACH, 1, true)
			if not near.is_empty():
				_engage(al, body, near[0], delta, false)
			else:
				_go(al, body, _formation_pos(owner, slot), delta)
		"ambush":
			if al.get("hidden", false):
				# Enterrado: salta con todos en cuanto alguien del otro bando pasa cerca, se vea o no.
				if not combat.foes_in(team, pos, AMBUSH_TRIGGER, 1, false).is_empty():
					set_order(owner, "attack")
					print("[EMBOSCADA] ¡salen los esqueletos de %s!" % owner.display_name)
				_idle(al, body, delta)
				return
			var mine := of(owner)
			var spot2 := ambush_slot(mine.find(al), mine.size())
			var spot: Vector3 = owner.ambush_at + Vector3(spot2.x, 0.0, spot2.y)
			if Horde._flat_dist(pos, spot) < 0.6:
				_bury(al)
				_idle(al, body, delta)
			else:
				_go(al, body, spot, delta)


## Sitio de su hueco en la formación, girada con el Rey.
func _formation_pos(owner: Fighter, slot: int) -> Vector3:
	var s := formation_slot(slot)
	var yaw := owner.model.rotation.y if owner.model != null else 0.0
	return owner.pos() + Vector3(s.x, 0.0, s.y).rotated(Vector3.UP, yaw)


## Pegar si está a su alcance; si no, acercarse (solo si `chase`).
func _engage(al: Dictionary, body: CharacterBody3D, target: Dictionary, delta: float, chase: bool) -> void:
	var tp: Vector3 = (target["node"] as Node3D).global_position
	if Horde._flat_dist(body.global_position, tp) <= HIT_REACH:
		_face(body, tp - body.global_position, delta)
		if float(al["swing_t"]) <= 0.0:
			al["swing_t"] = HIT_EVERY
			combat.hurt(target, HIT_DMG, 0.0, combat.fighter_by_id(int(al["owner"])), int(al.get("slot", -1)))
			main._play_all(al["anims"], "Sword_Attack")
		_idle(al, body, delta, false)
	elif chase:
		_go(al, body, tp, delta)
	else:
		_idle(al, body, delta)


## Andar hacia `goal` por la rejilla (NavGrid si la hay), a SPEED.
func _go(al: Dictionary, body: CharacterBody3D, goal: Vector3, delta: float) -> void:
	var pos := body.global_position
	if Horde._flat_dist(pos, goal) < 0.4:
		_idle(al, body, delta)
		return
	var dir := goal - pos
	if main.nav != null:
		var here: Vector2i = main._cell_of(pos)
		var there: Vector2i = main._cell_of(goal)
		if here != there:
			var path: Array = al.get("path", [])
			if path.is_empty() or al.get("path_goal", Vector2i(-999, -999)) != there:
				path = main.nav.path(here, there)
				al["path"] = path
				al["path_goal"] = there
			while path.size() > 1 and (path[0] == here or Horde._flat_dist(main._cell_pos(path[0].x, path[0].y), pos) < 0.9):
				path.remove_at(0)
			if not path.is_empty():
				dir = main._cell_pos(path[0].x, path[0].y) - pos
	dir.y = 0.0
	if dir.length() < 0.01:
		_idle(al, body, delta)
		return
	dir = dir.normalized()
	body.velocity.x = dir.x * SPEED
	body.velocity.z = dir.z * SPEED
	_face(body, dir, delta)
	var ap: AnimationPlayer = (al["anims"] as Array)[0] if not (al["anims"] as Array).is_empty() else null
	if ap != null and ap.current_animation != "Sword_Attack" and ap.current_animation != "Zombie_Walk_Fwd":
		main._play_all(al["anims"], "Zombie_Walk_Fwd")
	_fall(body, delta)


func _idle(al: Dictionary, body: CharacterBody3D, delta: float, anim := true) -> void:
	body.velocity.x = 0.0
	body.velocity.z = 0.0
	if anim:
		var ap: AnimationPlayer = (al["anims"] as Array)[0] if not (al["anims"] as Array).is_empty() else null
		if ap != null and ap.current_animation != "Sword_Attack" and ap.current_animation != "Zombie_Idle":
			main._play_all(al["anims"], "Zombie_Idle")
	_fall(body, delta)


func _face(body: CharacterBody3D, d: Vector3, delta: float) -> void:
	var m := body.get_child(1) as Node3D
	if m != null and Vector2(d.x, d.z).length() > 0.01:
		m.rotation.y = lerp_angle(m.rotation.y, atan2(d.x, d.z), 8.0 * delta)


func _fall(body: CharacterBody3D, delta: float) -> void:
	body.velocity.y -= Main.GRAVITY * delta
	if body.is_on_floor() and body.velocity.y < 0.0:
		body.velocity.y = -1.0
	body.move_and_slide()


## Enterrarse: medio hundido y sin chocar; translúcido para su equipo, invisible para el otro.
func _bury(al: Dictionary) -> void:
	if al.get("hidden", false):
		return
	al["hidden"] = true
	var body: CharacterBody3D = al["node"]
	body.collision_layer = 0
	var model: Node3D = al.get("model")
	if model != null:
		model.position.y = -BURY_DEPTH
	var mine: bool = main.pf != null and int(al["team"]) == main.pf.team
	_set_look(al, 0.55 if mine else 1.0, mine)
	main.vfx.burst("dirt_02", body.global_position + Vector3(0, 0.2, 0), Color(0.55, 0.47, 0.35, 0.9), 10, 0.6, 2.0, 0.4, -4.0)


## Salir de la tierra.
func _rise(al: Dictionary) -> void:
	al["hidden"] = false
	var body: CharacterBody3D = al["node"]
	body.collision_layer = Main.L_CREATURE
	var model: Node3D = al.get("model")
	if model != null:
		model.position.y = 0.0
	_set_look(al, 0.0, true)
	main.vfx.burst("dirt_02", body.global_position + Vector3(0, 0.4, 0), Color(0.55, 0.47, 0.35, 0.95), 18, 0.8, 3.5, 0.6, -5.0)


func _set_look(al: Dictionary, transparency: float, visible: bool) -> void:
	var model: Node3D = al.get("model")
	if model != null:
		model.visible = visible
		for mi in model.find_children("*", "GeometryInstance3D", true, false):
			(mi as GeometryInstance3D).transparency = transparency
	var bar: Node3D = al.get("bar")
	if bar != null and is_instance_valid(bar):
		bar.visible = visible
