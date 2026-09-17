## Sonda: órdenes de los esqueletos del Rey liche (petición del usuario, 2026-09-17).
##   godot --headless --fixed-fps 60 --path . -- --legend=5 --nozone --zombies=0 --probe=minion_probe
## En la Horda, sin oleadas: alza el ejército y comprueba por fases
##  1. Atacar: van a por una diana quieta a ~20 m y le quitan vida.
##  2. Reagrupar: tu leyenda anda ~20 m y ellos la siguen (de media a menos de 4,5 m al llegar).
##  3. Emboscada: se entierran donde se manda, nadie del otro bando los ve (`foes_in`), y una diana que
##     aparece a su lado los hace salir a Atacar.
extends Node

var main: Node
var _t := 0.0
var _phase := "summon"
var _phase_t := 0.0
var _diana: Dictionary = {}
var _diana_hp := 0.0
var _walk: Array = []
var _problems: Array = []
var _report: Array = []


func _ready() -> void:
	main = get_parent()
	if main.horde == null or String(main.pf.data()["id"]) != "liche":
		print("minion_probe: FALLO (hace falta la Horda con --legend=5, el Rey liche)")
		main.get_tree().quit(1)
		return


func _physics_process(delta: float) -> void:
	_t += delta
	_phase_t += delta
	var h: Horde = main.horde
	h.left_to_spawn = 0
	h._break_t = 0.0                  # sin oleadas: solo las dianas de la sonda
	var pf: Fighter = main.pf
	var mins: Array = main.combat.minions.of(pf)
	match _phase:
		"summon":
			if _phase_t > 0.5 and _phase_t < 0.6:
				main.combat.do_cast(pf, 2, pf.pos())          # Alzar ejército
			if _phase_t > 5.0:
				if mins.size() < 5:
					_fail("el ejército sacó %d esqueletos" % mins.size())
					return
				main.combat.minions.set_order(pf, "attack")
				_diana = _spawn_diana(_walkable_near(pf.pos(), 20.0))
				_diana_hp = float(_diana.get("hp", 0.0))
				_next("attack")
		"attack":
			if float(_diana["hp"]) < _diana_hp:
				_report.append("Atacar: llegaron a la diana a %.0f m en %.1f s" % [
					Horde._flat_dist(pf.pos(), (_diana["node"] as Node3D).global_position), _phase_t])
				main.combat.hurt(_diana, 1e6)
				main.combat.minions.set_order(pf, "regroup")
				var goal := _walkable_near(pf.pos(), 20.0)
				_walk = main.nav.path(main._cell_of(pf.pos()), main._cell_of(goal))
				_next("regroup")
			elif _phase_t > 25.0:
				_fail("en 25 s ningún esqueleto le quitó vida a la diana")
		"regroup":
			# Tu leyenda anda por la ruta a 4 m/s (la sonda la mueve; nadie la maneja).
			if not _walk.is_empty():
				var c: Vector2i = _walk[0]
				var target: Vector3 = main._cell_pos(c.x, c.y)
				var step := Vector3(target.x - pf.pos().x, 0.0, target.z - pf.pos().z)
				if step.length() < 0.2:
					_walk.remove_at(0)
				else:
					var p := pf.pos() + step.limit_length(4.0 * delta)
					pf.body.global_position = p
					pf.prev_pos = p
				_phase_t = 0.0
			elif _phase_t > 5.0:
				var total := 0.0
				for al in mins:
					total += Horde._flat_dist(pf.pos(), (al["node"] as Node3D).global_position)
				var mean := total / maxf(mins.size(), 1.0)
				_report.append("Reagrupar: tras andar, a %.1f m de media" % mean)
				if mean > 4.5:
					_fail("reagrupados quedan a %.1f m de media (máximo 4,5)" % mean)
					return
				main.combat.minions.set_order(pf, "ambush", _walkable_near(pf.pos(), 7.0))
				_next("ambush")
		"ambush":
			var hidden := 0
			for al in mins:
				if al.get("hidden", false):
					hidden += 1
			if hidden == mins.size() and mins.size() > 0:
				var seen: Array = main.combat.foes_in(Fighter.TEAM_HORDE, pf.ambush_at, 8.0, 99, false)
				for s in seen:
					if s.get("kind", "") == "minion":
						_fail("un esqueleto enterrado sigue siendo visible para el otro bando")
						return
				_report.append("Emboscada: %d enterrados en %.1f s, invisibles" % [hidden, _phase_t])
				_diana = _spawn_diana(pf.ambush_at + Vector3(1.0, 0.0, 0.5))
				_next("trigger")
			elif _phase_t > 20.0:
				_fail("en 20 s solo se enterraron %d de %d" % [hidden, mins.size()])
		"trigger":
			var up := 0
			for al in mins:
				if not al.get("hidden", false):
					up += 1
			if pf.minion_order == "attack" and up == mins.size():
				_report.append("Emboscada: salieron todos a Atacar en %.2f s" % _phase_t)
				_finish()
			elif _phase_t > 2.0:
				_fail("la diana a su lado no los hizo salir (orden %s, fuera %d de %d)" % [pf.minion_order, up, mins.size()])


func _next(phase: String) -> void:
	_phase = phase
	_phase_t = 0.0


## Una criatura quieta en `at` (como las dianas de --dianas).
func _spawn_diana(at: Vector3) -> Dictionary:
	var h: Horde = main.horde
	h.spawn_zombie(at)
	var z: Dictionary = h.zombies[h.zombies.size() - 1]
	z["stun_t"] = 900.0
	return z


## Una celda transitable a unos `dist` metros de `from`.
func _walkable_near(from: Vector3, dist: float) -> Vector3:
	var c0: Vector2i = main._cell_of(from)
	var best := from
	var best_err := INF
	var r := int(ceil(dist / Main.CELL)) + 1
	for c: Vector2i in main._cells_around(c0, r):
		var p: Vector3 = main._cell_pos(c.x, c.y)
		var err := absf(Horde._flat_dist(from, p) - dist)
		if err < best_err:
			best_err = err
			best = p
	return best


func _fail(msg: String) -> void:
	_problems.append(msg)
	_finish()


func _finish() -> void:
	set_physics_process(false)
	for r in _report:
		print("[SONDA] %s" % r)
	for p in _problems:
		print("[SONDA] problema: %s" % p)
	print("minion_probe: %s" % ("OK" if _problems.is_empty() else "FALLO"))
	main.get_tree().quit(0 if _problems.is_empty() else 1)
