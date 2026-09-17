## El combate de Fallen Legends 3D para CUALQUIER leyenda: la tuya o la de un bot. Movido desde
## main.gd (2026-09-16), donde todo suponía un único lanzador (el jugador) y un único bando
## enemigo (las criaturas). Aquí cada habilidad sale de un `Fighter` y golpea a los de OTRO equipo.
##
## Objetivos: todo lo que recibe daño es una ficha (Dictionary) con la misma forma:
##   node, kind ("zombie" | "fighter" | "minion" | "decoy"), team, hp, hpmax, dead_t, stun_t,
##   knock, knock_t, slow_t, blind_t, spore_t, spore_by, bar, bar_t, bscale, cap
## Las criaturas de la horda son del equipo 0; tu equipo es el 1 y el rival el 2.
## `foes_in` sustituye a `_nearest_in` y `hurt` a `_damage_zombie` / `_damage_player` / `_hurt_ally`.
##
## Todo lo que queda en el mundo (proyectiles, trampas, zonas, espinas, balizas, esbirros y
## señuelos) lleva `team` y `owner` (id del Fighter): así una baja de la trampa del Tormentero o de
## la plaga del Clérigo se acredita a quien la lanzó.
##
## ORDEN: la Horda se comprueba con trazas deterministas (--fixed-fps 60 --autocast --log) grabadas
## antes de extraer. Cambiar el orden de las operaciones o de las tiradas del rng las descuadra.
class_name Combat
extends RefCounted

const PX := LegendData.PX

# --- esporas del Clérigo, con las constantes de player.gd del juego ---
const SPORE_BASE := 10.0
const SPORE_GROWTH := 1.5           # el daño por segundo crece esto por cada infectado
const SPORE_MAX_TARGETS := 7        # ...contando como mucho estos
const SPORE_DPS_MAX := 60.0
const SPORE_KILL_MULT := 1.25       # y se multiplica cada vez que muere un infectado
const SPORE_SPREAD := 320.0 * PX    # radio de contagio al morir uno (5 m)
const SPORE_CONTAGION := 130.0 * PX # radio de contagio por cercanía en cada tick (2 m)
const SPORE_TIME := 10.0
const SPORE_COL := Color(0.5, 1.0, 0.4)
const SLOW_MULT := 0.5              # el gas Nox deja a la mitad de velocidad (Ability.slow)

# --- Baliza Nox (beacon.gd del juego) ---
const BEACON_HP := 60.0
const BEACON_TRIGGER := 130.0 * PX  # 2 m: a esa distancia un enemigo la despierta
const BEACON_TINT := Color(0.95, 1.35, 0.8)
# Por equipos la Trampa eléctrica y la Baliza Nox tardan en activarse (petición del usuario,
# 2026-09-16; el 2D las activa al momento): se lanzaban encima del rival y saltaban en el acto (340
# de 344 trampas), así que no eran trampas sino un aturdimiento seguro. Mientras se activan se ven,
# pero no saltan; al activarse aparece su aro con un chispazo. En la Horda, como siempre. Medido con
# 28 partidas: con 2 s el Tormentero bajaba del 81 % al 45 % pero Químico y Rompemareas subían al
# 80 % y 72 %; con 3 s todas quedan entre el 30 % y el 56 %.
const PVP_ARM_TIME := 3.0

# --- guardia automática del Caballero (player.GUARD_* del juego) ---
const GUARD_DELAY := 0.4            # segundos quieto antes de cubrirse solo
const GUARD_DAMAGE_MULT := 0.55     # recibe un 45 % menos
const GUARD_COL := Color(0.45, 0.72, 1.0)
const KNOCK_TIME := 0.35            # lo que dura el desplazamiento de un empujón
const PULL_SPEED := 14.0            # m/s a los que el ancla arrastra: el tiempo sale de la distancia

# --- señuelos del Ilusionista (decoy.gd del juego) ---
const DECOY_TINT := Color(0.85, 0.8, 1.35)
const SWAP_COOLDOWN := 1.0          # el intercambio se salta la recarga, pero no es gratis
const SPOTTED_TIME := 3.0           # segundos que te delata atacar desde la maleza

# --- carga del Mandoble del Rompemareas (player.CHARGE_*) ---
const MELEE_ARC := 126.0            # abanico por defecto de un golpe cuerpo a cuerpo, en grados
const CHARGE_MIN := 0.35            # mantener menos de esto es un mandoble normal
const CHARGE_MAX := 1.2             # y más de esto ya no suma
const CHARGE_RAD := 1.9             # radio a tope
const CHARGE_DMG := 2.1             # daño a tope

# --- esbirros del Liche (player.gd del juego) ---
const MINION_HARD_MAX := 10
const ARMY_KEEP := 3

# --- movimiento de una leyenda ---
const CROUCH_MULT := 0.45           # lo que frena ir agachado
const RUN_MULT := 1.6
const TURN_SPEED := 10.0
const TORCH_RANGE := 14.0
const RESPAWN_TIME := 4.0           # Level.DEFAULT_RESPAWN del juego
# Regeneración: tras REGEN_DELAY s sin recibir daño, recupera REGEN_RATE de la vida máxima por
# segundo. El ritmo es el de player.REGEN_RATE del 2D (8 %/s); la espera, 10 s a petición del
# usuario (2026-09-16; el 2D usa 4 s).
const REGEN_DELAY := 10.0
const REGEN_RATE := 0.08
# Por equipos las básicas teledirigidas pueden FALLAR (petición del usuario, 2026-09-16: las rondas
# acababan en ~7 s de pelea porque no fallaba nada). Vuelan recto hacia donde apuntaste y solo
# corrigen en los últimos PVP_HOMING_ACQUIRE metros, girando como mucho PVP_HOMING_TURN grados por
# segundo: de cerca aciertan; de lejos, a quien se mueve de lado se le escapan. Impactan al tocar a
# alguien por el camino y se apagan al llegar a su alcance. En la Horda siguen sin fallar.
const PVP_HOMING_ACQUIRE := 2.0
const PVP_HOMING_TURN := 40.0
const BOLT_HIT_RADIUS := 0.75

var main: Main
var vfx: Vfx
var rng: RandomNumberGenerator
var fighters: Array = []            # Fighter; el índice es su id
var bolts: Array = []               # proyectiles en vuelo
var traps: Array = []               # trampas puestas
var storms: Array = []              # zonas: tormentas, gas, estallidos y sus campos
var spikes: Array = []              # muros de espinas creciendo
var beacons: Array = []             # barriles de gas del Químico
var allies: Array = []              # esbirros del Liche y señuelos del Ilusionista
var cd_cap := 0.0                   # --cd=N: recorta TODAS las recargas, solo para pruebas
var casts := {}                     # tipo de habilidad -> veces lanzada (sondas y --log)
var ult_casts := 0                  # definitivas lanzadas (sondas)
var damage_by := {}                 # "Leyenda ranura" -> daño hecho a leyendas rivales (sondas de balance)
var soft_hits := 0                  # proyectiles teledirigidos por equipos que acertaron...
var soft_misses := 0                # ...y los que se apagaron sin tocar a nadie
var traps_sprung := 0               # trampas eléctricas que alguien pisó después de puestas (sondas: ¿las esquivan?)
var traps_on_top := 0               # ...y las que saltaron nada más poder (alguien ya estaba dentro)
var beacons_popped := 0             # balizas Nox reventadas
var _cast_slot := -1                # ranura que se está lanzando ahora mismo (do_cast)
var _spore_tick := 0.0


func _init(p_main: Main, p_vfx: Vfx) -> void:
	main = p_main
	vfx = p_vfx
	rng = p_main.rng


# =====================================================================
# Leyendas
# =====================================================================

## Crea una leyenda en `at`: cuerpo, modelo con sus animaciones, arma, antorcha y barra.
func spawn_fighter(legend: int, team: int, is_player: bool, at: Vector3) -> Fighter:
	var f := Fighter.new()
	f.id = fighters.size()
	f.team = team
	f.legend = clampi(legend, 0, LegendData.LEGENDS.size() - 1)
	f.is_player = is_player
	f.display_name = String(f.data()["name"])
	f.body = CharacterBody3D.new()
	f.body.collision_layer = Main.L_PLAYER
	f.body.collision_mask = Main.L_WORLD
	f.body.position = at
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.45
	cap.height = 1.8
	cs.shape = cap
	cs.position = Vector3(0, 0.9, 0)
	f.body.add_child(cs)
	# cuerpo base debajo del atuendo: los atuendos no traen cabeza (el peón salía sin cara)
	var made := main._make_character(f.data()["models"])
	f.model = made.get("node")
	if f.model != null:
		main._tint_model(f.model, f.data()["tint"])
		var sc0 := float(f.data().get("scale", 1.0))
		if sc0 != 1.0:
			f.model.scale = Vector3.ONE * sc0
		main._attach_weapon(f.model, String(f.data().get("weapon", "")))
	f.anims = made.get("anims", [])
	f.anim = f.anims[0] if f.anims.size() > 0 else null
	if f.model != null:
		f.body.add_child(f.model)
	f.torch = OmniLight3D.new()
	f.torch.light_color = Color(1.0, 0.82, 0.55)
	f.torch.omni_range = TORCH_RANGE if is_player else TORCH_RANGE * 0.6
	f.torch.light_energy = 0.0
	f.torch.position = Vector3(0, 1.5, 0)
	f.body.add_child(f.torch)
	f.bar = main._make_bar(f.body, bar_height(f), bar_color(team))
	main.add_child(f.body)
	if f.anim != null:
		main._play_all(f.anims, "Idle")
	f.rec = {"node": f.body, "kind": "fighter", "team": team, "fid": f.id, "hp": f.hp_max(),
		"hpmax": f.hp_max(), "dead_t": -1.0, "stun_t": 0.0, "knock": Vector3.ZERO, "knock_t": 0.0,
		"slow_t": 0.0, "blind_t": 0.0, "spore_t": 0.0, "bar": f.bar, "bar_t": 0.0, "bscale": 1.0,
		"cap": 1.8}
	f.prev_pos = at
	f.last_seen = at
	f.reset_abilities()
	fighters.append(f)
	return f


## Cambia de leyenda en caliente: rehace el modelo y aplica vida y velocidad.
func set_legend(f: Fighter, i: int) -> void:
	f.legend = clampi(i, 0, LegendData.LEGENDS.size() - 1)
	f.display_name = String(f.data()["name"])
	if f.model != null:
		f.body.remove_child(f.model)
		f.model.queue_free()
	var made := main._make_character(f.data()["models"])
	f.model = made.get("node")
	f.anims = made.get("anims", [])
	f.anim = f.anims[0] if f.anims.size() > 0 else null
	if f.model != null:
		main._tint_model(f.model, f.data()["tint"])
		# El Cíclope es un duende a ×2,6: la escala va en el modelo, no en la cápsula, que se
		# deja como está a propósito (la leyenda solo choca con el mundo y agrandarla la dejaría
		# atascada entre los árboles).
		var sc := float(f.data().get("scale", 1.0))
		if sc != 1.0:
			f.model.scale = Vector3.ONE * sc
		main._attach_weapon(f.model, String(f.data().get("weapon", "")))
		f.body.add_child(f.model)
	if f.anim != null:
		main._play_all(f.anims, "Idle")
	f.rec["hp"] = f.hp_max()
	f.rec["hpmax"] = f.hp_max()
	# La antorcha y la barra cuelgan del cuerpo, que NO se recrea al cambiar de leyenda: solo hay
	# que rehacer la barra si por lo que sea falta. La altura sí cambia con la leyenda.
	if f.bar == null or not is_instance_valid(f.bar):
		f.bar = main._make_bar(f.body, 2.25, bar_color(f.team))
		f.rec["bar"] = f.bar
	f.bar.position.y = bar_height(f)
	if f.label != null:
		f.label.position.y = f.bar.position.y + 0.32
	f.reset_abilities()
	print("leyenda: %s (%d vida, %.1f m/s, %.2f m de alto, barra a %.2f)" % [
		f.display_name, int(f.hp()), f.speed(),
		main._model_top(f.model) * maxf(f.model.scale.y, 0.01) if f.model != null else 0.0,
		f.bar.position.y if f.bar != null else 0.0])


## Verde los de tu equipo, rojo los demás (el jugador siempre ve su bando en verde).
func bar_color(team: int) -> Color:
	var mine := main.pf.team if main.pf != null else Fighter.TEAM_BLUE
	return Main.BAR_ALLY if team == mine else Main.BAR_ENEMY


## Dónde cuelga la barra de una leyenda: justo encima de la cabeza (o del ancla, o del mazo).
## `"bar"` en LEGENDS lo fuerza si alguna vez hace falta.
func bar_height(f: Fighter) -> float:
	if f.data().has("bar"):
		return float(f.data()["bar"])
	if f.model == null:
		return 2.25
	var top := main._model_top(f.model) * maxf(f.model.scale.y, 0.01)
	return maxf(top, 1.2) + Main.BAR_GAP


func fighter_by_id(fid: int) -> Fighter:
	return fighters[fid] if fid >= 0 and fid < fighters.size() else null


## Nadie puede apuntarle: por la invisibilidad del Ilusionista, o porque está AGACHADA dentro de
## una mancha de hierba alta. Atacar la delata unos segundos (`spotted_t`), así que el camuflaje
## sirve para colarse o escapar, no para disparar desde la maleza sin consecuencias.
func is_hidden(f: Fighter) -> bool:
	if f.marked_t > 0.0:
		return false              # marcado por romper un señuelo: a la vista aunque se agache
	if f.hidden_t > 0.0:
		return true
	return f.crouch and f.spotted_t <= 0.0 and main.in_tall_grass(f.pos())


## Inmóvil por su propia acción: cargando, en preaviso de carga, clavada por el ancla o cargando
## el mandoble.
func is_locked(f: Fighter) -> bool:
	var winding_dash := f.windup >= 0.0 and f.windup_idx >= 0 and String(f.abil(f.windup_idx)["k"]) == "dash"
	return f.dash_left > 0.0 or winding_dash or (f.buff_left > 0.0 and f.buff_root) \
		or f.swing_charge_t >= CHARGE_MIN


## Estado de lanzador de una leyenda, una vez por fotograma de física: paso, ocultación, tope del
## mundo, carga del mandoble, recargas, preaviso, mejora, carga y guardia.
func tick_fighter(f: Fighter, delta: float) -> void:
	f.step = f.pos() - f.prev_pos
	f.step.y = 0.0
	if f.step.length() > 1.0:
		f.step = Vector3.ZERO   # eso no es andar, es un teletransporte
	f.prev_pos = f.pos()
	f.hidden_t = maxf(0.0, f.hidden_t - delta)
	f.spotted_t = maxf(0.0, f.spotted_t - delta)
	f.marked_t = maxf(0.0, f.marked_t - delta)
	# El contorno de la marca solo lo dibuja quien la ve: el equipo del señuelo, si es el tuyo.
	var show_mark := f.marked_t > 0.0 and f.alive() and main.pf != null and f.mark_team == main.pf.team
	if show_mark != f.mark_shown and f.model != null:
		f.mark_shown = show_mark
		MarkFx.apply(f.model, show_mark)
	if not is_hidden(f):
		f.last_seen = f.pos()
	f.swap_t = maxf(0.0, f.swap_t - delta)
	f.invuln_t = maxf(0.0, f.invuln_t - delta)
	if f.ult_by_charge and f.alive() and (main.team_mode == null or main.team_mode.rules.state == "playing"):
		f.ult_charge = minf(f.ult_charge + Fighter.ULT_PASSIVE * delta, 1.0)
	f.since_damage += delta
	if f.alive() and f.since_damage >= REGEN_DELAY and f.hp() < f.hp_max():
		f.rec["hp"] = minf(f.hp() + REGEN_RATE * f.hp_max() * delta, f.hp_max())
	# Red de seguridad: nada debería caerse del mundo, pero si pasa, se recupera en vez de
	# quedarse cayendo eternamente (el suelo es un plano infinito y no frena desde abajo).
	# Tope duro cada frame. Da igual qué lo empuje (depenetración de un muro, un intercambio,
	# gravedad acumulada): la leyenda NO sale del mundo. Antes acababa a 1 km de altura.
	var lx := main.mw * Main.CELL * 0.5 - Main.CELL
	var lz := main.mh * Main.CELL * 0.5 - Main.CELL
	var p := f.pos()
	var fixed := Vector3(clampf(p.x, -lx, lx), clampf(p.y, 0.2, 25.0), clampf(p.z, -lz, lz))
	if not fixed.is_equal_approx(p):
		f.body.global_position = fixed
		f.body.velocity.y = 0.0
		f.prev_pos = fixed
	# Mantener la básica carga el mandoble (solo la leyenda que lo tiene).
	if f.abil(0).get("charge", false) and f.holding_basic and f.alive():
		f.swing_charge_t = minf(f.swing_charge_t + delta, CHARGE_MAX)
	elif f.swing_charge_t > 0.0 and not f.holding_basic:
		f.swing_charge_t = 0.0
	f.charge_mult = 1.0
	if f.swing_charge_t >= CHARGE_MIN:
		f.charge_mult = 1.0 + (f.swing_charge_t - CHARGE_MIN) / (CHARGE_MAX - CHARGE_MIN)
	f.tick_cooldowns(delta)
	if f.windup >= 0.0:
		f.windup -= delta
		if f.windup <= 0.0:
			f.windup = -1.0
			do_cast(f, f.windup_idx, f.windup_at)
			f.windup_idx = -1
	tick_buff(f, delta)
	tick_dash(f, delta)
	tick_guard(f, delta)


## Mueve una leyenda según su `wish` (lo escribe el teclado, el táctil o el bot): empujón y
## aturdimiento primero, luego agacharse, correr, lentitud, giro y animación de andar.
func move_fighter(f: Fighter, delta: float) -> void:
	var r := f.rec
	# El empujón/tirón se resuelve ANTES que el aturdimiento, como en las criaturas: si se mira
	# después, una habilidad que aturda y empuje a la vez deja clavado al objetivo.
	if float(r.get("knock_t", 0.0)) > 0.0:
		r["knock_t"] = float(r["knock_t"]) - delta
		if float(r.get("stun_t", 0.0)) > 0.0:
			r["stun_t"] = float(r["stun_t"]) - delta
		var k: Vector3 = r.get("knock", Vector3.ZERO)
		f.body.velocity.x = k.x
		f.body.velocity.z = k.z
		f.body.velocity.y -= Main.GRAVITY * delta
		f.body.move_and_slide()
		return
	var stunned := false
	if float(r.get("stun_t", 0.0)) > 0.0:
		r["stun_t"] = float(r["stun_t"]) - delta
		stunned = true
	var locked := is_locked(f) or stunned
	var wish := Vector3.ZERO if locked or not f.alive() else Vector3(f.wish.x, 0.0, f.wish.z)
	var moving := wish.length() > 0.01
	if moving:
		wish = wish.normalized()
	f.crouch = f.crouch and not locked and f.alive()
	var spd := f.speed()
	if f.crouch:
		spd *= CROUCH_MULT
	elif f.run:
		spd *= RUN_MULT
	if float(r.get("slow_t", 0.0)) > 0.0:
		r["slow_t"] = float(r["slow_t"]) - delta
		spd *= SLOW_MULT
	f.body.velocity.x = wish.x * spd
	f.body.velocity.z = wish.z * spd
	f.body.velocity.y -= Main.GRAVITY * delta
	if f.body.is_on_floor() and f.body.velocity.y < 0.0:
		f.body.velocity.y = -1.0
	f.body.move_and_slide()

	if moving and f.model != null:
		var target := atan2(wish.x, wish.z)
		f.model.rotation.y = lerp_angle(f.model.rotation.y, target, TURN_SPEED * delta)

	f.cast_anim_t = maxf(0.0, f.cast_anim_t - delta)
	if f.anim != null and f.cast_anim_t <= 0.0 and f.alive():
		var want := ("Crouch_Fwd" if moving else "Crouch_Idle") if f.crouch \
			else ("Jog_Fwd" if moving else "Idle")
		if not f.anim.has_animation(want):
			want = "Jog_Fwd" if moving else "Idle"
		if f.anim.current_animation != want:
			main._play_all(f.anims, want)
		for ap in f.anims:
			ap.speed_scale = (spd / f.speed()) if moving else 1.0


# =====================================================================
# Objetivos y daño
# =====================================================================

## Los `n` objetivos vivos de OTRO equipo que `team` más cercanos a `at` dentro de `radius`:
## criaturas, leyendas, esbirros y señuelos. `visible_only` quita a las leyendas ocultas (lo
## que apunta; lo que estalla en una zona les da igual que se escondan).
func foes_in(team: int, at: Vector3, radius: float, n := 999, visible_only := false) -> Array:
	var found: Array = []
	for z in main.zombies:
		if int(z.get("team", 0)) == team or z["dead_t"] >= 0.0:
			continue
		var d: float = at.distance_to(z["node"].global_position)
		if d <= radius:
			found.append({"z": z, "d": d})
	for f: Fighter in fighters:
		if f.team == team or not f.alive():
			continue
		if visible_only and is_hidden(f):
			continue
		var d := at.distance_to(f.pos())
		if d <= radius:
			found.append({"z": f.rec, "d": d})
	for al in allies:
		if int(al.get("team", 1)) == team or float(al["hp"]) <= 0.0:
			continue
		var d: float = at.distance_to((al["node"] as Node3D).global_position)
		if d <= radius:
			found.append({"z": al, "d": d})
	found.sort_custom(func(a, b): return a["d"] < b["d"])
	var out: Array = []
	for i in mini(n, found.size()):
		out.append(found[i]["z"])
	return out


## Daño (y aturdimiento) a cualquier objetivo. `by` es quien lo causa, para acreditar la baja.
## `slot` es la ranura que lo causó (-1 si no viene de una habilidad): lo que hace la definitiva no
## carga la definitiva.
func hurt(z: Dictionary, dmg: float, stun := 0.0, by: Fighter = null, slot := -1) -> void:
	var dealt := 0.0
	match String(z.get("kind", "zombie")):
		"zombie":
			if z["dead_t"] >= 0.0:
				return
			dealt = minf(dmg, maxf(float(z["hp"]), 0.0))
			z["hp"] -= dmg
			z["bar_t"] = Main.BAR_SHOW
			if stun > 0.0:
				z["stun_t"] = maxf(z.get("stun_t", 0.0), stun * (0.35 if z.get("boss", false) else 1.0))
			if z["hp"] <= 0.0:
				main._kill_zombie(z)
		"fighter":
			dealt = _hurt_fighter(fighter_by_id(int(z["fid"])), dmg, stun, by)
		"decoy":
			# Un solo golpe disipa un señuelo, como en el juego. Un campo que no hace daño no cuenta.
			if dmg <= 0.0 and stun <= 0.0:
				return
			dealt = minf(dmg, float(z["hp"]))
			z["hp"] = 0.0
			# Quien lo rompe (o el dueño de la trampa, zona o esbirro que lo rompió) queda marcado
			# para el equipo del señuelo. Caducar o intercambiarse con él no pasa por aquí.
			if by != null and by.team != int(z.get("team", -1)):
				by.mark(int(z.get("team", -1)))
			var at: Vector3 = (z["node"] as Node3D).global_position + Vector3(0, 0.9, 0)
			vfx.burst("magic_02", at, DECOY_TINT, 22, 0.6, 3.5, 0.7, 0.4)
		_:
			dealt = minf(dmg, maxf(float(z["hp"]), 0.0))
			z["hp"] = float(z["hp"]) - dmg
			if stun > 0.0:
				z["stun_t"] = maxf(float(z.get("stun_t", 0.0)), stun)
	if by != null and dealt > 0.0 and int(z.get("team", -1)) != by.team:
		if slot != 2:
			by.add_ult_damage(dealt)
		if String(z.get("kind", "")) == "fighter":
			var key := "%s %s" % [by.display_name, ["básica", "táctica", "definitiva"][slot] if slot >= 0 and slot <= 2 else "otro"]
			damage_by[key] = float(damage_by.get(key, 0.0)) + dealt


## Devuelve la vida que de verdad le ha quitado.
func _hurt_fighter(f: Fighter, amount: float, stun: float, by: Fighter) -> float:
	if f == null or not f.alive() or f.invuln_t > 0.0:
		return 0.0
	if main.team_mode != null and main.team_mode.rules.state != "playing":
		return 0.0    # entre rondas o partida terminada: lo que quede en el suelo ya no hace daño
	var mult := (1.0 - f.buff_resist) if f.buff_left > 0.0 else 1.0
	if f.guard:
		mult *= GUARD_DAMAGE_MULT
	var dealt := minf(amount * mult, f.hp())
	f.rec["hp"] = f.hp() - amount * mult
	f.rec["bar_t"] = Main.BAR_SHOW
	if amount * mult > 0.0:
		f.since_damage = 0.0
	if stun > 0.0 and not f.guard:
		f.rec["stun_t"] = maxf(float(f.rec.get("stun_t", 0.0)), stun)
	if f.hp() <= 0.0:
		f.rec["hp"] = 0.0
		f.streak = 0
		f.deaths += 1
		f.respawn_t = RESPAWN_TIME
		main._play_all(f.anims, "Death01")
		if main.is_pvp():
			# En PvP la leyenda caída suelta lo que tuviera a medias y sale del juego hasta
			# reaparecer: si no, su preaviso seguía disparando desde el suelo.
			f.windup = -1.0
			f.windup_idx = -1
			f.dash_left = 0.0
			f.buff_left = 0.0
			if f.buff_fx != null:
				f.buff_fx.queue_free()
				f.buff_fx = null
			f.rec["dead_t"] = 0.0
			if float(f.rec.get("spore_t", 0.0)) > 0.0:
				spore_burst(f.rec)
			var cs := f.body.get_child(0) as CollisionShape3D
			if cs != null:
				cs.set_deferred("disabled", true)
		main.on_fighter_down(f, by)
	return dealt


## Empujón suave: el objetivo se desplaza y frena, en vez de teletransportarse.
func knock(z: Dictionary, dir: Vector3, force: float, secs := KNOCK_TIME) -> void:
	z["knock"] = Vector3(dir.x, 0, dir.z).normalized() * force
	z["knock_t"] = secs


## Proyectil teledirigido por equipos: recto, corrige solo al final y poco, impacta al tocar a
## alguien por el camino y se apaga al llegar a su alcance. true si ya ha terminado.
func _tick_soft_bolt(b: Dictionary, owner: Fighter, delta: float) -> bool:
	var node: Node3D = b["node"]
	var dir: Vector3 = b["dir"]
	var tgt = b["target"]
	if tgt != null and is_instance_valid(tgt):
		var to_t: Vector3 = (tgt as Node3D).global_position - node.position
		to_t.y = 0.0
		if to_t.length() <= PVP_HOMING_ACQUIRE and to_t.length() > 0.05:
			var ang := dir.signed_angle_to(to_t.normalized(), Vector3.UP)
			var turn := deg_to_rad(PVP_HOMING_TURN) * delta
			dir = dir.rotated(Vector3.UP, clampf(ang, -turn, turn)).normalized()
			b["dir"] = dir
	var step := float(b["spd"]) * delta
	var from := node.position
	var to := from + dir * step
	b["range_left"] = float(b["range_left"]) - step
	b["life"] = float(b["life"]) - delta
	var hit: Dictionary = {}
	var best := INF
	for z in foes_in(int(b["team"]), from.lerp(to, 0.5), step * 0.5 + BOLT_HIT_RADIUS + 0.6, 6):
		var zp := (z["node"] as Node3D).global_position
		var center := Vector3(zp.x, from.y, zp.z)
		if _seg_dist(center, from, to) <= BOLT_HIT_RADIUS:
			var d := from.distance_to(center)
			if d < best:
				best = d
				hit = z
	node.position = to
	var bc: Color = b.get("col", Vfx.SPARK)
	if not hit.is_empty():
		soft_hits += 1
		hurt(hit, float(b["dmg"]), float(b["stun"]), owner, int(b.get("slot", -1)))
		if b["pull"] and owner != null:
			pull(hit, owner.pos())
		vfx.flash(node.position, Color(bc.r + 0.2, bc.g + 0.2, bc.b + 0.2), 1.4, 0.16)
		vfx.burst("spark_04", node.position, bc, 6, 0.22, 2.5, 0.3, -4.0, 35.0)
	elif float(b["range_left"]) > 0.0 and float(b["life"]) > 0.0:
		return false
	else:
		soft_misses += 1
		vfx.burst("spark_04", node.position, Color(bc.r, bc.g, bc.b, 0.6), 4, 0.2, 1.5, 0.2, -4.0, 60.0)
	node.queue_free()
	return true


## Arrastra al objetivo hacia un punto: es el empujón con el signo cambiado (Ability.pull).
func pull(z: Dictionary, to: Vector3) -> void:
	var body: Node3D = z["node"]
	var d := to - body.global_position
	d.y = 0.0
	var dist := d.length() - 0.9        # se queda a un brazo, no encima
	if dist <= 0.1:
		return
	# Arrastre VISIBLE, no teletransporte: antes saltaba de golpe y encima con un tope de 6 m, así
	# que desde el alcance máximo (8,3 m) ni siquiera llegaba a los pies. Ahora tira a velocidad
	# fija y el tiempo sale de la distancia, o sea que llega venga de donde venga.
	var secs := clampf(dist / PULL_SPEED, 0.12, 0.9)
	knock(z, d.normalized(), dist / secs, secs)
	if main._args.has("meleelog"):
		print("[ENGANCHE] tira de un enemigo %.1f m en %.2f s" % [dist, secs])


# =====================================================================
# Lanzar
# =====================================================================

## ¿Esta ranura está lista para INTERCAMBIAR en vez de lanzar? (player.swap_ready del juego)
func swap_ready(f: Fighter, i: int) -> bool:
	return f.abil(i).get("swap", false) and f.swap_t <= 0.0 and not decoy_alive(f).is_empty()


## El intercambio con el señuelo va antes que cualquier otra cosa. true si lo ha hecho.
func try_swap(f: Fighter, i: int) -> bool:
	if f.abil(i).get("swap", false) and f.swap_t <= 0.0:
		var al := decoy_alive(f)
		if not al.is_empty():
			f.swap_t = SWAP_COOLDOWN   # se salta la recarga, pero no es gratis
			swap_with_decoy(f, al)
			return true
	return false


## Intercambio o lanzamiento hacia `at` (los bots siempre dan el punto).
func try_cast(f: Fighter, i: int, at: Vector3) -> void:
	if try_swap(f, i):
		return
	if not f.ability_ready(i):
		return
	start_cast(f, i, at)


## Cobra la recarga o la carga y arranca el preaviso; el efecto sale al agotarse (player.try_cast).
func start_cast(f: Fighter, i: int, at: Vector3) -> void:
	var ab := f.abil(i)
	var cd := float(ab["cd"])
	if cd_cap > 0.0:
		cd = minf(cd, cd_cap)     # --cd=N: solo para probar sin esperar la recarga real
	if i == 0:
		f.spend_ammo()             # por equipos la básica gasta munición (sin fila, no hace nada)
	if i == 2 and f.ult_by_charge:
		f.ult_charge = 0.0         # por carga: se gasta entera, sin recarga
	elif int(ab.get("chg", 0)) > 0:
		f.chg[i] -= 1
		if f.chg_t[i] <= 0.0:
			f.chg_t[i] = cd
	else:
		f.cd[i] = cd
	f.windup = float(ab.get("cast", 0.25))
	f.windup_idx = i
	f.windup_at = at
	# `adur` alarga SOLO la animación, no el preaviso: el lanzamiento de roca dura 1,33 s y
	# comprimido a los 0,35 s del preaviso salía a 3,8x. El conjuro sale a su hora igual.
	var dur := maxf(float(ab.get("adur", 0.0)), maxf(f.windup, 0.35))
	f.cast_anim_t = dur
	# Cada habilidad puede pedir su propia animación ("anim"): el mazazo del Cíclope y el
	# terremoto del Guerrero usan un tajo corto, la roca OverhandThrow y la Retirada Roll.
	# Si no la pide, o el modelo no la trae, se cae al reparto de siempre.
	var anim: String = String(ab.get("anim", ""))
	if anim == "" or f.anim == null or not f.anim.has_animation(anim):
		anim = "Sword_Attack" if ab["k"] in ["melee", "dash"] else "Spell_Simple_Shoot"
	main._play_all(f.anims, anim)
	if f.anim != null and f.anim.has_animation(anim):
		var alen := f.anim.get_animation(anim).length
		for ap in f.anims:
			ap.speed_scale = alen / dur
	if String(ab["k"]) != "decoy":
		f.hidden_t = 0.0              # disparar te delata; sacar más señuelos no
		f.spotted_t = SPOTTED_TIME    # y el camuflaje de la hierba tampoco aguanta un ataque
	_sound(f, String(ab.get("sfx", "proj_arcane")))
	var face := at - f.pos()
	face.y = 0.0
	if face.length() > 0.1 and f.model != null:
		f.model.rotation.y = atan2(face.x, face.z)


func do_cast(f: Fighter, i: int, at: Vector3) -> void:
	var ab := f.abil(i)
	var rad := f.ability_radius(i)
	casts[String(ab["k"])] = int(casts.get(String(ab["k"]), 0)) + 1
	if i == 2:
		ult_casts += 1
	_cast_slot = i
	match String(ab["k"]):
		"proj":
			cast_projectile(f, ab, at)
		"melee":
			cast_melee(f, ab, at, rad)
		"dash":
			cast_dash(f, ab, at, rad)
		"heal":
			cast_heal(f, ab, rad)
		"buff":
			cast_buff(f, ab)
		"zone":
			cast_zone(f, ab, at, rad, true)
		"gas":
			cast_zone(f, ab, at, rad, false)
		"spores":
			cast_spores(f, ab, at, rad)
		"trap":
			cast_trap(f, ab, at, rad, false)
		"beacon":
			cast_beacon(f, ab, at, rad)
		"spikes":
			cast_spikes(f, ab, at)
		"summon":
			cast_summon(f, ab, at)
		"decoy":
			cast_decoy(f, ab, at)
	_cast_slot = -1


## Sonido de una leyenda: el tuyo a volumen pleno, el de los bots según lo cerca que estén.
func _sound(f: Fighter, name: String, vol := -6.0) -> void:
	if f.is_player or main.pf == null:
		main._sfx(name, vol)
		return
	var d := f.pos().distance_to(main.pf.pos())
	if d > 30.0:
		return
	main._sfx(name, vol - d * 0.6)


# -- proyectil ------------------------------------------------------

func cast_projectile(f: Fighter, ab: Dictionary, at: Vector3) -> void:
	var col: Color = ab.get("col", Vfx.SPARK)
	var b := Node3D.new()
	# Proyectil SÓLIDO (hoy solo el ancla): en vez de la bola de luz de siempre, el objeto que de
	# verdad sale volando, girando y con la cadena tendida hasta la mano.
	if String(ab.get("solid", "")) == "anchor":
		_cast_anchor(f, ab, at, b)
		return
	var core := MeshInstance3D.new()
	var sph := SphereMesh.new()
	sph.radius = 0.20
	sph.height = 0.40
	sph.radial_segments = 10
	sph.rings = 6
	core.mesh = sph
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(col.r + 0.25, col.g + 0.25, col.b + 0.25)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	core.material_override = m
	b.add_child(core)
	# estela corta pegada a la bola, no una rociada en todas direcciones
	var trail := vfx.emitter(b, "spark_04", Color(col.r, col.g, col.b, 0.9), 0.12, 18, 0.28, 0.2, 0.45)
	trail.position = Vector3.ZERO
	b.position = f.pos() + Vector3(0, 1.2, 0)
	main.add_child(b)
	var l := OmniLight3D.new()
	l.light_color = col
	l.light_energy = 3.0
	l.omni_range = 6.0
	b.add_child(l)
	bolts.append({"node": b, "target": homing_target(f.team, at) if ab.get("homing", false) else null,
		"to": at, "life": 3.0, "dmg": float(ab.get("dmg", 10.0)) * (f.basic_dmg_mult if _cast_slot == 0 else 1.0),
		"stun": float(ab.get("stun", 0.0)), "pull": ab.get("pull", false),
		"spd": float(ab.get("spd", 620.0)) * PX, "col": col,
		"catch": float(ab.get("catch", 0.0)) * PX if ab.has("catch") else 1.2,
		"team": f.team, "owner": f.id, "slot": _cast_slot,
		# Por equipos la teledirigida puede fallar (ver PVP_HOMING_*): vuela recto hacia donde
		# apuntaste y se apaga al llegar a su alcance.
		"soft": main.is_pvp() and ab.get("homing", false),
		"dir": _flat_dir(f.pos(), at, f), "range_left": float(ab.get("rng", 600.0)) * PX + 1.0})


## El ancla encadenada. Misma tubería que el resto de proyectiles (vive en `bolts`), pero con
## malla propia, giro y cadena.
func _cast_anchor(f: Fighter, ab: Dictionary, at: Vector3, b: Node3D) -> void:
	b.add_child(main._make_anchor())
	b.position = f.pos() + Vector3(0, 1.3, 0)
	main.add_child(b)
	var l := OmniLight3D.new()      # un punto de luz tenue, para que de noche se siga con la vista
	l.light_color = Color(1.0, 0.86, 0.6)
	l.light_energy = 0.8
	l.omni_range = 4.0
	b.add_child(l)
	var chain := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.035
	cm.bottom_radius = 0.035
	cm.height = 1.0
	cm.radial_segments = 5
	cm.rings = 1
	chain.mesh = cm
	var cmat := StandardMaterial3D.new()
	cmat.albedo_color = Color(0.30, 0.28, 0.25)
	cmat.roughness = 0.9
	chain.material_override = cmat
	main.add_child(chain)
	bolts.append({"node": b, "target": homing_target(f.team, at) if ab.get("homing", false) else null,
		"to": at, "life": 4.0, "dmg": float(ab.get("dmg", 10.0)),
		"stun": float(ab.get("stun", 0.0)), "pull": ab.get("pull", false),
		"spd": float(ab.get("spd", 620.0)) * PX, "col": ab.get("col", Vfx.SPARK), "chain": chain,
		"spin": true, "catch": float(ab.get("catch", 60.0)) * PX, "team": f.team, "owner": f.id,
		"slot": _cast_slot})


## Dirección en el plano de `from` a `to`; si coinciden, hacia donde mira la leyenda.
func _flat_dir(from: Vector3, to: Vector3, f: Fighter) -> Vector3:
	var d := to - from
	d.y = 0.0
	return d.normalized() if d.length() > 0.1 else f.facing()


## Teledirigido: busca el enemigo VISIBLE más cercano al punto apuntado, a 4 m como mucho.
func homing_target(team: int, at: Vector3) -> Node3D:
	var near := foes_in(team, at, 4.0, 1, true)
	return near[0]["node"] if not near.is_empty() else null


func tick_bolts(delta: float) -> void:
	for i in range(bolts.size() - 1, -1, -1):
		var b: Dictionary = bolts[i]
		var node: Node3D = b["node"]
		var owner := fighter_by_id(int(b.get("owner", -1)))
		if b.get("soft", false):
			if _tick_soft_bolt(b, owner, delta):
				bolts.remove_at(i)
			continue
		var goal: Vector3 = b["to"]
		var tgt = b["target"]
		if tgt != null and is_instance_valid(tgt):
			goal = tgt.global_position + Vector3(0, 1.0, 0)
		var to := goal - node.position
		var step: float = float(b["spd"]) * delta
		b["life"] -= delta
		if to.length() <= step or b["life"] <= 0.0:
			for z in foes_in(int(b["team"]), node.position, float(b.get("catch", 1.2)), 1):
				hurt(z, float(b["dmg"]), float(b["stun"]), owner, int(b.get("slot", -1)))
				if b["pull"] and owner != null:
					pull(z, owner.pos())
			var bc: Color = b.get("col", Vfx.SPARK)
			if b.get("spin", false):
				# El ancla es hierro: al clavarse salta tierra, no chispas mágicas.
				vfx.burst("dirt_02", node.position, Color(0.66, 0.56, 0.40, 0.95), 18, 0.7, 3.0, 0.4, -4.0, 60.0, 0.3)
				vfx.burst("smoke_04", node.position, Color(0.78, 0.72, 0.60, 0.5), 10, 0.9, 1.2, 0.7, 0.2, 70.0, 0.4)
			else:
				vfx.flash(node.position, Color(bc.r + 0.2, bc.g + 0.2, bc.b + 0.2), 1.4, 0.16)
				vfx.burst("spark_04", node.position, bc, 6, 0.22, 2.5, 0.3, -4.0, 35.0)
			if b.get("chain") != null and is_instance_valid(b["chain"]):
				(b["chain"] as Node).queue_free()
			node.queue_free()
			bolts.remove_at(i)
			continue
		node.position += to.normalized() * step
		if b.get("spin", false):
			node.rotate_object_local(Vector3.FORWARD, delta * 9.0)   # el ancla vuela girando
		if b.get("chain") != null and is_instance_valid(b["chain"]) and owner != null:
			vfx.span(b["chain"], owner.pos() + Vector3(0, 1.3, 0), node.position)


# -- cuerpo a cuerpo, carga, curación y mejora -----------------------

func cast_melee(f: Fighter, ab: Dictionary, at: Vector3, rad: float) -> void:
	# El giro cargado del Rompemareas: hasta x1,9 de radio y x2,1 de daño, y a 360 grados.
	var full: bool = bool(ab.get("charge", false)) and f.charge_mult > 1.02
	rad *= lerpf(1.0, CHARGE_RAD, f.charge_mult - 1.0) if full else 1.0
	var origin := f.pos()
	var face := at - origin
	face.y = 0.0
	if face.length() < 0.1:
		face = f.facing()
	face = face.normalized()
	var fx := vfx.disc(rad, ab.get("col", Color(1, 0.9, 0.6)), 0.22)
	fx.position = origin + face * rad * 0.5 + Vector3(0, 0.05, 0)
	main.add_child(fx)
	vfx.sparks.append({"node": fx, "life": 0.18})
	vfx.burst("slash_02", origin + face * rad * 0.6 + Vector3(0, 1.0, 0), Color(1, 0.95, 0.8),
		4, 0.25, 1.0, rad * 0.9, 0.0, 20.0)
	if bool(ab.get("dust", false)):
		vfx.swing_dust(origin, face, rad, full, float(ab.get("arc", MELEE_ARC)))
	# Apertura del golpe, en grados de abanico total. El Mandoble de ancla barre 180°: todo lo que
	# tenga delante, de hombro a hombro (petición del usuario). Cargado es la vuelta entera.
	var half := deg_to_rad(float(ab.get("arc", MELEE_ARC))) * 0.5
	var hits := 0
	var widest := 0.0
	for z in foes_in(f.team, origin, rad + 0.6):
		var to: Vector3 = z["node"].global_position - origin
		to.y = 0.0
		var ang := face.angle_to(to.normalized()) if to.length() > 0.1 else 0.0
		if not full and ang > half:
			continue
		widest = maxf(widest, ang)
		hits += 1
		hurt(z, float(ab.get("dmg", 20.0)) * (lerpf(1.0, CHARGE_DMG, f.charge_mult - 1.0) if full else 1.0) * (f.basic_dmg_mult if _cast_slot == 0 else 1.0),
			float(ab.get("stun", 0.0)), f, _cast_slot)
	if main._args.has("meleelog"):
		print("[GOLPE] %s: %.1f m de radio, abanico %.0f°%s, tocó a %d (el más abierto a %.0f°)" % [
			ab["n"], rad, 360.0 if full else rad_to_deg(half * 2.0),
			" CARGADO" if full else "", hits, rad_to_deg(widest)])


func cast_dash(f: Fighter, ab: Dictionary, at: Vector3, rad: float) -> void:
	var d := at - f.pos()
	d.y = 0.0
	if d.length() < 0.3:
		d = f.facing()
	# Retirada del Arquero: la única que se aleja del cursor en vez de ir hacia él. Va a alcance
	# fijo, porque hacia atrás no hay nada que "señalar": d solo marca de qué te separas.
	if bool(ab.get("back", false)):
		d = -d.normalized() * float(ab.get("rng", 190.0)) * PX
	# Llega justo donde señalaste, sin pasarse del alcance de la habilidad.
	f.dash_vec = d.normalized() * minf(d.length(), float(ab.get("rng", 700.0)) * PX)
	f.dash_total = f.dash_vec.length()
	f.dash_done = 0.0
	f.dash_t = 0.0
	f.dash_dur = 1.0
	var danim := String(ab.get("anim", "Sword_Attack"))
	if f.anim == null or not f.anim.has_animation(danim):
		danim = "Sword_Attack"
	var alen := 1.0
	if f.anim != null and f.anim.has_animation(danim):
		alen = f.anim.get_animation(danim).length
	# Dos maneras de cronometrar una carga:
	#   "sync" (el Corte de hacha del Caballero, a petición del usuario) = el desplazamiento dura
	#     lo que la animación, que va a velocidad normal; el golpe termina justo al llegar.
	#   lo normal = manda la velocidad del juego (Ability.dash_speed) y la animación se adapta.
	#     La Embestida son 4,6 m a 700 px/s: 0,31 s. Estirar ahí una animación de 1,1 s a la
	#     inversa daría un paseo en vez de una carga.
	var sp := 1.0
	if bool(ab.get("sync", false)) or float(ab.get("spd", 0.0)) <= 0.0:
		f.dash_dur = alen
	else:
		f.dash_dur = maxf(f.dash_total / (float(ab["spd"]) * PX), 0.08)
		sp = clampf(alen / f.dash_dur, 0.5, 3.0)
	if f.anim != null and f.anim.has_animation(danim):
		main._play_all(f.anims, danim)
		for ap in f.anims:
			ap.speed_scale = sp
	f.dash_left = f.dash_dur
	# La voltereta del Arquero dura más que su salto (0,17 s): el guardián de animación aguanta
	# hasta que acaba, o se cortaría a medio giro.
	f.cast_anim_t = maxf(f.dash_dur, alen / maxf(sp, 0.01))
	f.dash_dmg = float(ab.get("dmg", 20.0))
	f.dash_rad = rad
	f.dash_shove = float(ab.get("shove", 0.0))
	f.dash_slot = _cast_slot
	f.dash_hit.clear()
	if main._args.has("dashlog"):
		f.dash_from = f.pos()
		f.dash_want = f.dash_vec.length()
	_sound(f, "melee")


## Distancia de un punto al segmento recorrido este frame. Sin esto, un tajo a 17 m/s
## deja entre frame y frame huecos de más de medio metro y se salta enemigos.
func _seg_dist(p: Vector3, a: Vector3, b: Vector3) -> float:
	var ab := b - a
	var l2 := ab.length_squared()
	if l2 < 0.0001:
		return p.distance_to(a)
	var t := clampf((p - a).dot(ab) / l2, 0.0, 1.0)
	return p.distance_to(a + ab * t)


func tick_dash(f: Fighter, delta: float) -> void:
	if f.dash_left <= 0.0:
		return
	if f.model != null and f.dash_vec.length() > 0.01:
		f.model.rotation.y = atan2(f.dash_vec.x, f.dash_vec.z)
	# Avanza según lo que lleva de animación, con arranque suave: llega exactamente al acabar.
	f.dash_t = minf(f.dash_t + delta, f.dash_dur)
	var fr := smoothstep(0.0, 1.0, f.dash_t / f.dash_dur)
	var want := f.dash_total * fr
	var len_step := maxf(want - f.dash_done, 0.0)
	f.dash_done = want
	var step := f.dash_vec.normalized() * len_step
	var from := f.pos()
	f.dash_left -= delta
	if f.dash_t >= f.dash_dur:
		f.dash_left = 0.0
		if main._args.has("dashlog"):
			var enemigos := 0
			for z in foes_in(f.team, f.dash_from.lerp(f.pos(), 0.5), f.dash_total):
				if _seg_dist((z["node"] as Node3D).global_position, f.dash_from, f.pos()) <= f.dash_rad:
					enemigos += 1
			print("[EMBESTIDA] quería %.1f m, recorrió %.1f m en %.2f s (animación %.2f s), arrolló %d de %d" % [
				f.dash_total, f.dash_from.distance_to(f.pos()),
				f.dash_t, f.dash_dur, f.dash_hit.size(), enemigos])
	if f.dash_left <= 0.0 and f.anim != null and f.cast_anim_t <= 0.0:
		for ap in f.anims:
			ap.speed_scale = 1.0
	f.body.velocity = Vector3.ZERO
	f.body.move_and_collide(step)
	# Humo continuo a los pies: es lo que hace que no parezca que se desliza.
	vfx.burst("smoke_04", f.pos() + Vector3(0, 0.12, 0),
		Color(0.82, 0.80, 0.72, 0.75), 5, 0.65, 1.1, 0.85, 0.1, 75.0, 0.35)
	vfx.burst("dirt_01", f.pos() + Vector3(0, 0.15, 0),
		Color(0.78, 0.72, 0.58), 5, 0.5, 2.2, 0.45, -3.0, 50.0)
	var fwd := f.dash_vec.normalized()
	var perp := fwd.cross(Vector3.UP).normalized()
	var to := f.pos()
	for z in foes_in(f.team, from.lerp(to, 0.5), from.distance_to(to) * 0.5 + f.dash_rad):
		if f.dash_hit.has(z["node"]):
			continue
		if _seg_dist((z["node"] as Node3D).global_position, from, to) > f.dash_rad:
			continue
		f.dash_hit[z["node"]] = true
		hurt(z, f.dash_dmg, 0.0, f, f.dash_slot)
		if f.dash_shove > 0.0:
			# A un lado o a otro según de qué lado del corte esté: se abre en dos.
			var off: Vector3 = (z["node"] as Node3D).global_position - f.pos()
			var side := signf(off.dot(perp))
			if absf(side) < 0.01:
				side = 1.0 if rng.randf() < 0.5 else -1.0
			knock(z, perp * side, f.dash_shove)
		vfx.burst("slash_03", (z["node"] as Node3D).global_position + Vector3(0, 1.0, 0),
			Color(1, 0.9, 0.85), 3, 0.2, 1.0, 1.4, 0.0, 15.0)


## Sanación del Clérigo: a sí mismo y a las leyendas de su equipo que tenga dentro del radio.
func cast_heal(f: Fighter, ab: Dictionary, rad: float) -> void:
	# Por equipos la vida va ×3: la curación también, o curaría un tercio de lo que cura en el 2D.
	var amount := float(ab.get("heal", 30.0)) * f.hp_mult
	for o: Fighter in fighters:
		if o.team != f.team or not o.alive():
			continue
		if o != f and o.pos().distance_to(f.pos()) > rad:
			continue
		o.rec["hp"] = minf(o.hp() + amount, o.hp_max())
	var fx := vfx.disc(rad, ab.get("col", Color(0.5, 1.0, 0.6)), 0.28)
	fx.position = f.pos() + Vector3(0, 0.06, 0)
	main.add_child(fx)
	vfx.sparks.append({"node": fx, "life": 0.6})
	vfx.burst("star_06", f.pos() + Vector3(0, 0.4, 0), ab.get("col", Color(0.55, 1.0, 0.6)),
		26, 1.1, 2.2, 0.55, 1.6, 30.0, rad * 0.5)


func cast_buff(f: Fighter, ab: Dictionary) -> void:
	f.buff_left = float(ab.get("dur", 5.0))
	f.buff_resist = float(ab.get("resist", 0.3))
	f.buff_root = bool(ab.get("root", false))
	f.buff_dmg = float(ab.get("dmg", 0.0))
	f.buff_rad = float(ab.get("rng", 300.0)) * PX
	f.buff_tick = 0.0
	f.buff_slot = _cast_slot
	var fx := vfx.ring(f.buff_rad, ab.get("col", Color(1.0, 0.8, 0.35)), 0.7)
	fx.position = Vector3(0, 0.06, 0)
	f.body.add_child(fx)
	f.buff_fx = fx


func tick_buff(f: Fighter, delta: float) -> void:
	if f.buff_left <= 0.0:
		return
	f.buff_left -= delta
	f.buff_tick -= delta
	if f.buff_tick <= 0.0:
		f.buff_tick = 0.8
		# El aura del Ancla clavada es otro golpe suyo y también levanta polvo, pero a la mitad:
		# repite cada 0,8 s y con la carga del mandoble entero la nube no se despejaba nunca.
		vfx.swing_dust(f.pos(), Vector3(0, 0, 1), f.buff_rad, true, MELEE_ARC, 0.45)
		for z in foes_in(f.team, f.pos(), f.buff_rad):
			hurt(z, f.buff_dmg, 0.0, f, f.buff_slot)
			pull(z, f.pos())
	if f.buff_left <= 0.0 and f.buff_fx != null:
		f.buff_fx.queue_free()
		f.buff_fx = null


## Guardia automática del Caballero: se cubre solo tras estar quieto, y atacar NO la rompe.
## La rompen moverse, cargar o que le aturdan.
func tick_guard(f: Fighter, delta: float) -> void:
	if not f.data().get("guard", false) or not f.alive():
		f.guard = false
		f.still_t = 0.0
	else:
		var moving := f.step.length() > 0.02 or f.dash_left > 0.0 or float(f.rec.get("stun_t", 0.0)) > 0.0
		if moving:
			f.still_t = 0.0
			f.guard = false
		else:
			f.still_t += delta
			f.guard = f.still_t >= GUARD_DELAY
	if f.guard and f.guard_fx == null:
		f.guard_fx = vfx.bubble(1.05, GUARD_COL)
		f.guard_fx.position = Vector3(0, 0.95, 0)
		f.body.add_child(f.guard_fx)
	elif not f.guard and f.guard_fx != null:
		f.guard_fx.queue_free()
		f.guard_fx = null
	if f.guard_fx != null:
		var pulse := 1.0 + sin(float(Time.get_ticks_msec()) * 0.004) * 0.045
		f.guard_fx.scale = Vector3(pulse, pulse, pulse)


# -- zonas, gas, trampas y balizas -----------------------------------

## `burst` = golpe inicial tras el aviso (Tormenta). Sin él es solo una nube (Gas, Esporas).
func cast_zone(f: Fighter, ab: Dictionary, at: Vector3, rad: float, burst: bool) -> void:
	var col: Color = ab.get("col", Vfx.SPARK)
	var node := Node3D.new()
	node.position = at
	node.add_child(vfx.ring(rad, col, 0.85))
	node.add_child(vfx.disc(rad, col, 0.12))
	main.add_child(node)
	if not burst:
		vfx.gas_cloud(node, rad, col)
		# Estallido: la granada revienta con una bocanada gorda antes de asentarse la nube.
		vfx.burst("smoke_07", at + Vector3(0, 1.0, 0), Color(col.r, col.g, col.b, 0.9),
			70, 1.8, 5.0, rad * 0.30, 0.15, 95.0, rad * 0.35)
		vfx.burst("smoke_02", at + Vector3(0, 0.4, 0), Color(col.r * 0.85, col.g, col.b * 0.6, 0.8),
			55, 2.4, 2.5, rad * 0.24, 0.05, 95.0, rad * 0.55)
	storms.append({"node": node, "delay": float(ab.get("delay", 0.0)) if burst else 0.0,
		"field": float(ab.get("field", 6.0)), "tick": 0.0, "hit": not burst, "rad": rad,
		"dmg": float(ab.get("dmg", 0.0)), "stun": float(ab.get("stun", 0.0)),
		"fdmg": float(ab.get("fdmg", 8.0)), "fstun": float(ab.get("fstun", 0.0)),
		"every": float(ab.get("tick", 2.0)), "slow": float(ab.get("slow", 0.0)),
		"knock": float(ab.get("knock", 0.0)), "fx": String(ab.get("fx", "spark")),
		"col": col, "bolts": 7 if burst else 0, "team": f.team, "owner": f.id, "slot": _cast_slot})


## `beacon` = espera armada y al activarse suelta una nube en vez de descargar rayos.
func cast_trap(f: Fighter, ab: Dictionary, at: Vector3, rad: float, beacon: bool) -> void:
	var col: Color = ab.get("col", Vfx.SPARK)
	var node := Node3D.new()
	node.position = at
	node.add_child(vfx.disc(rad, col, 0.10))
	node.add_child(vfx.ring(rad, col, 0.35))
	var core := vfx.disc(0.5, col, 0.8)
	core.position = Vector3(0, 0.03, 0)
	node.add_child(core)
	main.add_child(node)
	var arming := main.is_pvp()
	if arming:
		(node.get_child(1) as Node3D).visible = false   # sin aro hasta que se active
	traps.append({"node": node, "armed": true, "live": not arming, "left": float(ab.get("dur", 10.0)),
		"tick": 0.0, "rad": rad, "dmg": float(ab.get("dmg", 12.0)),
		"stun": float(ab.get("stun", 0.0)), "every": float(ab.get("tick", 2.0)),
		"tgt": int(ab.get("tgt", 99)), "beacon": beacon, "slow": float(ab.get("slow", 0.0)),
		"team": f.team, "owner": f.id, "slot": _cast_slot, "age": 0.0})
	_cap_owned(traps, f, int(ab.get("act", 5)))


## Tope de cosas puestas POR LEYENDA: se va la más antigua de esa leyenda.
func _cap_owned(list: Array, f: Fighter, cap: int) -> void:
	var mine := 0
	for e in list:
		if int(e.get("owner", -1)) == f.id:
			mine += 1
	while mine > cap:
		for k in list.size():
			if int(list[k].get("owner", -1)) == f.id:
				(list[k]["node"] as Node).queue_free()
				list.remove_at(k)
				mine -= 1
				break


## Barril de gas: bloquea el paso, tiene vida y espera dormido. Lo despierta un enemigo a 2 m
## o cualquier golpe; entonces suelta la nube y se agota.
func cast_beacon(f: Fighter, ab: Dictionary, at: Vector3, rad: float) -> void:
	var body := StaticBody3D.new()
	body.position = at + Vector3(0, 0.0, 0)
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.42
	cyl.bottom_radius = 0.48
	cyl.height = 1.25
	var mi := MeshInstance3D.new()
	mi.mesh = cyl
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(ab["col"]) * BEACON_TINT
	m.emission_enabled = true
	m.emission = Color(ab["col"]) * 0.35
	m.roughness = 0.5
	mi.material_override = m
	mi.position = Vector3(0, 0.63, 0)
	body.add_child(mi)
	var cs := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = 0.45
	shape.height = 1.3
	cs.shape = shape
	cs.position = Vector3(0, 0.65, 0)
	body.add_child(cs)
	main.add_child(body)
	vfx.emitter(body, "smoke_04", Color(ab["col"].r, ab["col"].g, ab["col"].b, 0.25), 0.3, 6, 1.4, 0.5, 0.5)
	beacons.append({"node": body, "hp": BEACON_HP, "rad": rad, "dur": float(ab.get("dur", 10.0)),
		"dmg": float(ab.get("dmg", 8.0)), "every": float(ab.get("tick", 0.5)),
		"slow": float(ab.get("slow", 0.5)), "col": ab["col"], "spent": false,
		"team": f.team, "owner": f.id, "slot": _cast_slot, "age": 0.0, "live": not main.is_pvp()})
	_cap_owned(beacons, f, int(ab.get("act", 5)))


## ¿Puede saltar ya una trampa o baliza puesta hace `age` s? Por equipos, solo tras PVP_ARM_TIME.
static func can_trigger(age: float, pvp: bool) -> bool:
	return not pvp or age >= PVP_ARM_TIME


## La baliza enemiga que tenga a mano alguien de `team`, para que la muela a golpes.
func beacon_in_reach(team: int, from: Vector3, r: float) -> Dictionary:
	for bc in beacons:
		if bc["spent"] or int(bc.get("team", 1)) == team:
			continue
		if from.distance_to((bc["node"] as Node3D).global_position) <= r:
			return bc
	return {}


func tick_beacons(delta: float) -> void:
	for i in range(beacons.size() - 1, -1, -1):
		var bc: Dictionary = beacons[i]
		var node: Node3D = bc["node"]
		if bc["spent"]:
			continue
		bc["age"] = float(bc["age"]) + delta
		var ready := can_trigger(float(bc["age"]), main.is_pvp())
		if ready and not bc["live"]:
			bc["live"] = true
			vfx.flash(node.global_position + Vector3(0, 0.8, 0), bc["col"], 1.6, 0.25)   # ya está activa
		var near := ready and not foes_in(int(bc["team"]), node.global_position, BEACON_TRIGGER, 1).is_empty()
		if near or float(bc["hp"]) <= 0.0:
			bc["spent"] = true
			beacons_popped += 1
			_pop_beacon(bc)
			node.queue_free()
			beacons.remove_at(i)


## Reventar la baliza: suelta la nube de gas donde estaba.
func _pop_beacon(bc: Dictionary) -> void:
	var at: Vector3 = (bc["node"] as Node3D).global_position
	var col: Color = bc["col"]
	vfx.burst("smoke_07", at + Vector3(0, 0.8, 0), Color(col.r, col.g, col.b, 0.8), 26, 1.2, 3.0, 2.0, 0.2, 90.0)
	var owner := fighter_by_id(int(bc.get("owner", -1)))
	if owner != null:
		_sound(owner, "gas")
	else:
		main._sfx("gas")
	var node := Node3D.new()
	node.position = at
	node.add_child(vfx.ring(float(bc["rad"]), col, 0.7))
	node.add_child(vfx.disc(float(bc["rad"]), col, 0.10))
	main.add_child(node)
	vfx.gas_cloud(node, float(bc["rad"]), col)
	storms.append({"node": node, "delay": 0.0, "field": float(bc["dur"]), "tick": 0.0, "hit": true,
		"rad": float(bc["rad"]), "dmg": 0.0, "stun": 0.0, "fdmg": float(bc["dmg"]), "fstun": 0.0,
		"every": float(bc["every"]), "slow": float(bc["slow"]), "bolts": 0,
		"team": int(bc["team"]), "owner": int(bc.get("owner", -1)), "slot": int(bc.get("slot", -1))})


func tick_traps(delta: float) -> void:
	for i in range(traps.size() - 1, -1, -1):
		var t: Dictionary = traps[i]
		var node: Node3D = t["node"]
		var team := int(t["team"])
		if t["armed"]:
			t["age"] = float(t["age"]) + delta
			if not can_trigger(float(t["age"]), main.is_pvp()):
				continue          # por equipos, aún activándose: se ve, pero no salta
			if not t["live"]:
				t["live"] = true
				(node.get_child(1) as Node3D).visible = true
				vfx.spark(node.position + Vector3(0, 0.3, 0))
			if foes_in(team, node.position, float(t["rad"])).is_empty():
				continue          # armada sin caducar, como en el juego
			t["armed"] = false
			t["tick"] = 0.0
			if float(t["age"]) <= (PVP_ARM_TIME if main.is_pvp() else 0.0) + 0.5:
				traps_on_top += 1
			else:
				traps_sprung += 1
		t["left"] -= delta
		t["tick"] -= delta
		if t["tick"] <= 0.0:
			t["tick"] = float(t["every"])
			var owner := fighter_by_id(int(t.get("owner", -1)))
			for z in foes_in(team, node.position, float(t["rad"]), int(t["tgt"])):
				hurt(z, float(t["dmg"]), float(t["stun"]), owner, int(t.get("slot", -1)))
				if float(t["slow"]) > 0.0:
					z["slow_t"] = 2.0
				if not t["beacon"]:
					vfx.spark(z["node"].global_position)
		if t["left"] <= 0.0:
			node.queue_free()
			traps.remove_at(i)


func tick_storms(delta: float) -> void:
	for i in range(storms.size() - 1, -1, -1):
		var st: Dictionary = storms[i]
		var node: Node3D = st["node"]
		var rad := float(st["rad"])
		var team := int(st["team"])
		var owner := fighter_by_id(int(st.get("owner", -1)))
		if not st["hit"]:
			st["delay"] -= delta
			if st["delay"] <= 0.0:
				st["hit"] = true
				vfx.zone_burst(st, node.position, rad)
				for z in foes_in(team, node.position, rad):
					hurt(z, float(st["dmg"]), float(st["stun"]), owner, int(st.get("slot", -1)))
					if float(st["knock"]) > 0.0:
						var away: Vector3 = (z["node"] as Node3D).global_position - node.position
						away.y = 0.0
						if away.length() < 0.05:
							away = Vector3(1, 0, 0)
						knock(z, away.normalized(), float(st["knock"]))
			continue
		st["field"] -= delta
		st["tick"] -= delta
		if st["tick"] <= 0.0 and float(st["fdmg"]) > 0.0:
			st["tick"] = float(st["every"])
			for z in foes_in(team, node.position, rad):
				hurt(z, float(st["fdmg"]), float(st["fstun"]), owner, int(st.get("slot", -1)))
				if float(st["slow"]) > 0.0:
					z["slow_t"] = 2.0
					z["blind_t"] = 2.5     # dentro del humo no ve: deambula
		if st["field"] <= 0.0:
			node.queue_free()
			storms.remove_at(i)


# -- muro de espinas -------------------------------------------------

## Brota desde los pies hacia el punto apuntado; solo daña el tramo ya salido.
func cast_spikes(f: Fighter, ab: Dictionary, at: Vector3) -> void:
	var dir := at - f.pos()
	dir.y = 0.0
	if dir.length() < 0.3:
		dir = f.facing()
	spikes.append({"from": f.pos(), "dir": dir.normalized(),
		"len": f.ability_range(2), "grown": 0.0, "left": float(ab.get("dur", 10.0)),
		"tick": 0.0, "every": float(ab.get("tick", 1.0)), "rad": f.ability_radius(2),
		"dmg": float(ab.get("dmg", 20.0)), "stun": float(ab.get("stun", 2.0)), "nodes": [],
		"team": f.team, "owner": f.id, "slot": _cast_slot})


func tick_spikes(delta: float) -> void:
	for i in range(spikes.size() - 1, -1, -1):
		var sp: Dictionary = spikes[i]
		var full := float(sp["len"])
		if sp["grown"] < full:
			sp["grown"] = minf(full, float(sp["grown"]) + full * delta / 0.6)
			while float(sp["nodes"].size()) * 1.1 < float(sp["grown"]):
				var d := vfx.spike_clump(float(sp["rad"]))
				d.position = sp["from"] + sp["dir"] * (sp["nodes"].size() * 1.1) + Vector3(0, 0.0, 0)
				main.add_child(d)
				vfx.burst("dirt_02", d.position, Color(0.75, 0.68, 0.5), 8, 0.5, 3.0, 0.5, -5.0)
				sp["nodes"].append(d)
		sp["left"] -= delta
		sp["tick"] -= delta
		if sp["tick"] <= 0.0:
			sp["tick"] = float(sp["every"])
			var owner := fighter_by_id(int(sp.get("owner", -1)))
			for n in sp["nodes"]:
				for z in foes_in(int(sp["team"]), (n as Node3D).position, float(sp["rad"])):
					hurt(z, float(sp["dmg"]), float(sp["stun"]), owner, int(sp.get("slot", -1)))
		if sp["left"] <= 0.0:
			for n in sp["nodes"]:
				(n as Node3D).queue_free()
			spikes.remove_at(i)


# -- esbirros y señuelos ---------------------------------------------

func cast_summon(f: Fighter, ab: Dictionary, at: Vector3) -> void:
	var n := int(ab.get("count", 1))
	var rad := f.ability_radius(1)
	var base := at if float(ab.get("rng", 0.0)) > 0.0 else f.pos()
	if n > 1:
		# El ejército: antes de alzarlo caen todos los esqueletos salvo los 3 más recientes.
		var mine: Array = []
		for al in allies:
			if al["kind"] == "minion" and int(al.get("owner", -1)) == f.id:
				mine.append(al)
		while mine.size() > ARMY_KEEP:
			var old: Dictionary = mine.pop_front()
			old["hp"] = 0.0
	f.summon_slot = _cast_slot
	for k in n:
		var a := TAU * k / maxi(1, n)
		f.summon_queue.append(base + Vector3(cos(a), 0, sin(a)) * rad)


func tick_summon_queue(f: Fighter, delta: float) -> void:
	if f.summon_queue.is_empty():
		return
	f.summon_t -= delta
	if f.summon_t > 0.0:
		return
	f.summon_t = 0.5                  # brotan de uno en uno, como en el juego
	var mine := 0
	for al in allies:
		if al["kind"] == "minion" and int(al.get("owner", -1)) == f.id:
			mine += 1
	if mine >= MINION_HARD_MAX:
		f.summon_queue.clear()
		return
	spawn_ally(f, "minion", f.summon_queue.pop_front(), 0.0)


func cast_decoy(f: Fighter, ab: Dictionary, at: Vector3) -> void:
	var n := int(ab.get("n_decoys", 1))
	var rad := f.ability_radius(1)
	var mode := int(ab.get("move", 1))
	# Los giros saltan el 0 para que ningún clon quede pegado a la leyenda copiándola tal cual.
	for k in n:
		var a := TAU * (k + 1) / (n + 1)
		var pos: Vector3
		var dir := Vector3.ZERO
		if mode == 2:                      # FORWARD: sale hacia donde apuntas y sigue de largo
			dir = at - f.pos()
			dir.y = 0.0
			dir = dir.normalized() if dir.length() > 0.1 else f.facing()
			pos = f.pos() + dir * 1.2
		else:                              # SPREAD: corro alrededor, cada uno mirando a un lado
			pos = f.pos() + Vector3(cos(a), 0, sin(a)) * rad
		spawn_ally(f, "decoy", pos, float(ab.get("dur", 20.0)), mode, a, dir)
	if float(ab.get("invis", 0.0)) > 0.0:
		f.hidden_t = float(ab["invis"])


## ¿Hay un señuelo suyo vivo para intercambiarse con él? (Ability.decoy_swap)
func decoy_alive(f: Fighter) -> Dictionary:
	for al in allies:
		if al["kind"] == "decoy" and float(al["hp"]) > 0.0 and int(al.get("owner", -1)) == f.id \
				and absf((al["node"] as Node3D).global_position.y) < 5.0:
			return al
	return {}


## Intercambia sitio con el señuelo: la leyenda aparece donde esté él y él donde estaba ella.
func swap_with_decoy(f: Fighter, al: Dictionary) -> void:
	var body: CharacterBody3D = al["node"]
	var mine := f.pos()
	var to := body.global_position
	var lim_x := main.mw * Main.CELL * 0.5 - Main.CELL
	var lim_z := main.mh * Main.CELL * 0.5 - Main.CELL
	to.x = clampf(to.x, -lim_x, lim_x)
	to.z = clampf(to.z, -lim_z, lim_z)
	to.y = maxf(to.y, 0.3)     # el suelo es un plano infinito que solo frena desde arriba:
	f.body.global_position = to
	f.prev_pos = to            # el salto NO es "paso": si no, los clones lo copian y se dispara
	body.global_position = mine
	vfx.burst("magic_02", mine + Vector3(0, 0.9, 0), DECOY_TINT, 18, 0.5, 3.0, 0.6, 0.3)
	vfx.burst("magic_02", f.pos() + Vector3(0, 0.9, 0), DECOY_TINT, 18, 0.5, 3.0, 0.6, 0.3)
	_sound(f, "decoy")


## Un aliado de `f`: el esbirro pelea, el señuelo solo distrae. Los enemigos los toman por
## objetivo cuando están más cerca que la leyenda.
func spawn_ally(f: Fighter, kind: String, pos: Vector3, life: float, mode := 1, turn := 0.0, dir := Vector3.ZERO) -> void:
	var made: Dictionary
	if kind == "decoy":
		made = main._make_character(f.data()["models"])
	else:
		if main._zombie_proto == null:
			main._proto_of(Main.SPECIES[0])      # fuerza la carga del prototipo del esqueleto
		made = main._make_character([Main.CHARS + "Skeleton_B.glb"], [[Main.UAL1, Main.ZOMBIE_ANIMS_1], [Main.UAL2, Main.ZOMBIE_ANIMS_2]])
	var model: Node3D = made.get("node")
	if model == null:
		return
	if kind == "decoy":
		pass    # SIN tinte a propósito: si se distinguen, no confunden a nadie.
	else:
		main._tint_model(model, Color(0.65, 1.0, 0.8))   # esbirro: verde pálido, para no confundirlo
	var body := CharacterBody3D.new()
	body.collision_layer = Main.L_CREATURE
	body.collision_mask = Main.L_WORLD | Main.L_CREATURE
	body.position = pos + Vector3(0, 0.3, 0)
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.4
	cap.height = 1.7
	cs.shape = cap
	cs.position = Vector3(0, 0.85, 0)
	body.add_child(cs)
	body.add_child(model)
	main.add_child(body)
	if kind == "decoy":
		# Bocanada de humo en vez de estirarlos desde el suelo: así aparecen de golpe, del tamaño
		# correcto, y el humo tapa el instante en que salen.
		vfx.burst("smoke_07", body.position + Vector3(0, 0.8, 0), Color(0.85, 0.85, 0.9, 0.7),
			22, 1.0, 2.2, 1.6, 0.3, 80.0, 0.5)
		vfx.burst("smoke_04", body.position + Vector3(0, 0.4, 0), Color(0.8, 0.8, 0.85, 0.6),
			14, 1.3, 1.2, 2.2, 0.1, 90.0, 0.7)
	else:
		vfx.burst("magic_05", body.position + Vector3(0, 0.9, 0), Color(0.6, 1.0, 0.7), 20, 0.8, 3.0, 0.9, 1.0)
	var anims := main._anims_of(model)
	main._play_all(anims, "Idle" if kind == "decoy" else "Zombie_Walk_Fwd")
	if kind == "decoy" and f.model != null:
		model.rotation.y = (f.model.rotation.y + turn) if mode == 1 else atan2(dir.x, dir.z)
	var abar := main._make_bar(body, 2.2, bar_color(f.team))
	allies.append({"node": body, "anims": anims, "kind": kind, "bar": abar, "hpmax": 60.0, "hp": 60.0,
		"life": life, "swing_t": 0.0, "mode": mode, "turn": turn, "dir": dir,
		"spawn_t": 0.0, "model": model, "team": f.team, "owner": f.id, "dead_t": -1.0,
		"stun_t": 0.0, "knock_t": 0.0, "slot": f.summon_slot if kind == "minion" else _cast_slot})


func tick_allies(delta: float) -> void:
	for i in range(allies.size() - 1, -1, -1):
		var al: Dictionary = allies[i]
		var body: CharacterBody3D = al["node"]
		if al["life"] > 0.0:
			al["life"] -= delta
		if al["hp"] <= 0.0 or (al["life"] < 0.0 and float(al["life"]) > -900.0):
			body.queue_free()
			allies.remove_at(i)
			continue
		if al["kind"] == "decoy":
			_tick_decoy(al, body, delta)
			continue
		# Empujón y aturdimiento (en PvP se los hacen las habilidades rivales).
		if float(al.get("knock_t", 0.0)) > 0.0:
			al["knock_t"] = float(al["knock_t"]) - delta
			var k: Vector3 = al.get("knock", Vector3.ZERO)
			body.velocity = Vector3(k.x, body.velocity.y - Main.GRAVITY * delta, k.z)
			body.move_and_slide()
			continue
		if float(al.get("stun_t", 0.0)) > 0.0:
			al["stun_t"] = float(al["stun_t"]) - delta
			continue
		al["swing_t"] = maxf(0.0, float(al["swing_t"]) - delta)
		var near := foes_in(int(al["team"]), body.global_position, 18.0, 1, true)
		if near.is_empty():
			continue
		var tgt: Node3D = near[0]["node"]
		var d := tgt.global_position - body.global_position
		d.y = 0.0
		if d.length() <= 2.0:
			if al["swing_t"] <= 0.0:
				al["swing_t"] = 1.4
				hurt(near[0], 18.0, 0.0, fighter_by_id(int(al["owner"])), int(al.get("slot", -1)))
				main._play_all(al["anims"], "Sword_Attack")
		else:
			body.velocity.x = d.normalized().x * 3.0
			body.velocity.z = d.normalized().z * 3.0
			var m := body.get_child(1) as Node3D
			if m != null:
				m.rotation.y = lerp_angle(m.rotation.y, atan2(d.x, d.z), 8.0 * delta)
		body.velocity.y -= Main.GRAVITY * delta
		if body.is_on_floor() and body.velocity.y < 0.0:
			body.velocity.y = -1.0
		body.move_and_slide()


## El señuelo NO sigue a su leyenda: repite su desplazamiento girado a su propia orientación
## (SPREAD), o sale de largo hacia donde apuntó (FORWARD). Así, si ella avanza, cada clon avanza
## hacia donde mira él; y si se para, se paran todos.
func _tick_decoy(al: Dictionary, body: CharacterBody3D, delta: float) -> void:
	var model: Node3D = al["model"]
	var owner := fighter_by_id(int(al.get("owner", -1)))
	if owner == null:
		return
	# Orientación: la de la leyenda MÁS su propio giro, recalculada cada frame. Antes se fijaba solo
	# al nacer, así que al girar ella el clon seguía mirando a donde miraba al aparecer: corría bien
	# pero de lado.
	if int(al["mode"]) == 2:
		model.rotation.y = atan2((al["dir"] as Vector3).x, (al["dir"] as Vector3).z)
	elif owner.model != null:
		model.rotation.y = owner.model.rotation.y + float(al["turn"])
	var step := Vector3.ZERO
	if int(al["mode"]) == 2:
		step = (al["dir"] as Vector3) * owner.speed() * delta
	else:
		step = owner.step.rotated(Vector3.UP, float(al["turn"]))
	step.y = 0.0
	if step.length() > 0.0001:
		body.move_and_collide(step)
	body.velocity.y -= Main.GRAVITY * delta
	if body.is_on_floor() and body.velocity.y < 0.0:
		body.velocity.y = -1.0
	body.move_and_slide()
	# Gestos: el clon reproduce EXACTAMENTE lo que hace su leyenda, incluido lanzar.
	# Es lo que de verdad confunde: si ella conjura, los cinco conjuran.
	if owner.anim != null:
		var cur := owner.anim.current_animation
		var anims: Array = al["anims"]
		for ap in anims:
			if cur != "" and ap.current_animation != cur and ap.has_animation(cur):
				ap.play(cur)
			ap.speed_scale = owner.anim.speed_scale


# -- esporas ---------------------------------------------------------

## Infecta al apuntado y a los que tenga cerca. A partir de ahí la plaga se mantiene sola:
## contagia por cercanía, el daño crece con cada infectado y salta al morir uno.
func cast_spores(f: Fighter, _ab: Dictionary, at: Vector3, rad: float) -> void:
	f.spore_dps = SPORE_BASE
	for z in foes_in(f.team, at, rad):
		infect(z, f, _cast_slot)
	vfx.burst("magic_04", at + Vector3(0, 0.8, 0), SPORE_COL, 24, 0.9, 3.0, 0.8, 0.5, 70.0, rad * 0.5)


## Los bultos: cuatro protuberancias pegadas al cuerpo. Solo coge la plaga lo que tiene cuerpo
## propio (criaturas y leyendas): los señuelos y los esbirros NO (petición del usuario).
func infect(z: Dictionary, by: Fighter, slot := -1) -> void:
	var kind := String(z.get("kind", "zombie"))
	if kind != "zombie" and kind != "fighter":
		return
	if z["dead_t"] >= 0.0 or float(z.get("spore_t", 0.0)) > 0.0:
		return
	if kind == "fighter" and float(z.get("hp", 0.0)) <= 0.0:
		return
	if z.get("boss", false):
		return                      # los jefes resisten la plaga, como en el juego
	z["spore_t"] = SPORE_TIME
	z["spore_by"] = by.id if by != null else -1
	z["spore_slot"] = slot
	var body: Node3D = z["node"]
	var lumps := Node3D.new()
	var mat := StandardMaterial3D.new()
	mat.albedo_color = SPORE_COL
	mat.emission_enabled = true
	mat.emission = SPORE_COL * 0.6
	# A la medida del bicho: en un duende de 0,93 m los bultos del esqueleto le flotaban
	# por encima de la cabeza.
	var hs := float(z.get("cap", 1.7)) / 1.7
	for i in 4:
		var sph := SphereMesh.new()
		var r := rng.randf_range(0.10, 0.20) * hs
		sph.radius = r
		sph.height = r * 2.0
		sph.radial_segments = 6
		sph.rings = 4
		var mi := MeshInstance3D.new()
		mi.mesh = sph
		mi.material_override = mat
		var a := TAU * i / 4.0 + rng.randf()
		mi.position = Vector3(cos(a) * 0.22 * hs, rng.randf_range(0.5, 1.5) * hs, sin(a) * 0.22 * hs)
		lumps.add_child(mi)
	vfx.emitter(lumps, "magic_03", Color(SPORE_COL.r, SPORE_COL.g, SPORE_COL.b, 0.5), 0.35, 8, 1.2, 0.35, 0.35)
	body.add_child(lumps)
	z["spore_fx"] = lumps


func cure(z: Dictionary) -> void:
	z["spore_t"] = 0.0
	if z.get("spore_fx") != null and is_instance_valid(z["spore_fx"]):
		z["spore_fx"].queue_free()
	z["spore_fx"] = null


## Todas las fichas que pueden llevar la plaga, en orden estable: criaturas y luego leyendas.
func _infectable() -> Array:
	var out: Array = main.zombies.duplicate()
	for f: Fighter in fighters:
		out.append(f.rec)
	return out


## Al morir un infectado los bultos revientan y la plaga salta a los de alrededor.
func spore_burst(z: Dictionary) -> void:
	var at: Vector3 = (z["node"] as Node3D).global_position + Vector3(0, 0.9, 0)
	vfx.burst("magic_04", at, SPORE_COL, 30, 1.0, 5.0, 0.7, -1.0, 90.0, 0.3)
	vfx.flash(at, SPORE_COL, 1.6, 0.3)
	var owner := fighter_by_id(int(z.get("spore_by", -1)))
	if owner == null:
		cure(z)
		return
	owner.spore_dps = minf(owner.spore_dps * SPORE_KILL_MULT, SPORE_DPS_MAX)
	var before := 0
	for o in _infectable():
		if float(o.get("spore_t", 0.0)) > 0.0: before += 1
	for other in foes_in(owner.team, at, SPORE_SPREAD):
		if other != z:
			infect(other, owner, int(z.get("spore_slot", -1)))
	if main._args.has("sporelog"):
		var after := 0
		for o in _infectable():
			if float(o.get("spore_t", 0.0)) > 0.0: after += 1
		print("[ESPORAS] estalla un infectado: %d -> %d contagiados, daño/s x1.25 = %.1f" % [before - 1, after, owner.spore_dps])
	cure(z)


func tick_spores(delta: float) -> void:
	_spore_tick -= delta
	var do_tick := _spore_tick <= 0.0
	if do_tick:
		_spore_tick = 1.0
	var infected: Array = []
	for z in _infectable():
		if z["dead_t"] >= 0.0 or float(z.get("spore_t", 0.0)) <= 0.0:
			continue
		z["spore_t"] = float(z["spore_t"]) - delta
		if float(z["spore_t"]) <= 0.0:
			cure(z)
			continue
		infected.append(z)
	if not do_tick or infected.is_empty():
		return
	# Cada plaga crece con SUS infectados.
	var per_owner := {}
	for z in infected:
		var oid := int(z.get("spore_by", -1))
		per_owner[oid] = int(per_owner.get(oid, 0)) + 1
	for oid in per_owner:
		var owner := fighter_by_id(int(oid))
		if owner == null:
			continue
		owner.spore_dps = minf(owner.spore_dps + SPORE_GROWTH * mini(int(per_owner[oid]), SPORE_MAX_TARGETS), SPORE_DPS_MAX)
		if main._args.has("sporelog"):
			print("[ESPORAS] infectados=%d  daño/s=%.1f" % [int(per_owner[oid]), owner.spore_dps])
	for z in infected:
		var owner := fighter_by_id(int(z.get("spore_by", -1)))
		if owner == null:
			continue
		var at: Vector3 = (z["node"] as Node3D).global_position
		for other in foes_in(owner.team, at, SPORE_CONTAGION):
			infect(other, owner, int(z.get("spore_slot", -1)))
		hurt(z, owner.spore_dps, 0.0, owner, int(z.get("spore_slot", -1)))


# =====================================================================
# Mundo
# =====================================================================

## Todo lo que queda en el mundo, una vez por fotograma de física, después de las leyendas.
func tick_world(delta: float) -> void:
	for al in allies:
		var ab_node: Node3D = al["node"]
		if ab_node.global_position.y < -5.0:
			al["hp"] = 0.0
	tick_bolts(delta)
	tick_traps(delta)
	tick_beacons(delta)
	tick_storms(delta)
	tick_spikes(delta)
	tick_spores(delta)
	for f: Fighter in fighters:
		tick_summon_queue(f, delta)
	tick_allies(delta)
	vfx.tick(delta)


## Refresca todas las barras: leyendas, criaturas y aliados.
func tick_bars(delta: float) -> void:
	for f: Fighter in fighters:
		main._set_bar(f.bar, f.hp() / maxf(f.hp_max(), 1.0))
		if f.bar != null and is_instance_valid(f.bar):
			f.bar.visible = f.alive()
	for z in main.zombies:
		if z.has("bar"):
			# La escala tiene que ser la MISMA con la que se creó la barra: _set_bar la usa para
			# recolocar el relleno, y con el duende (0,7) o el licántropo (1,2) quedaba descentrado.
			main._set_bar(z["bar"], float(z["hp"]) / maxf(float(z.get("hpmax", Main.ZOMBIE_HP)), 1.0),
				float(z.get("bscale", 1.0)))
			_tick_enemy_bar(z, delta)
	for al in allies:
		if al.has("bar"):
			main._set_bar(al["bar"], float(al["hp"]) / maxf(float(al.get("hpmax", 60.0)), 1.0))


## La vida de una criatura solo se ve cuando la golpeas, y se va sola (petición del usuario): con
## 40 bichos a la vez el claro era una pared de barras rojas y no se veía la pelea. El jefe es la
## excepción: su barra es el objetivo de la oleada y no se esconde.
func _tick_enemy_bar(z: Dictionary, delta: float) -> void:
	var bar: Node3D = z["bar"]
	if bar == null or not is_instance_valid(bar):
		return
	if z.get("boss", false):
		return
	var t := float(z.get("bar_t", 0.0))
	if t <= 0.0:
		if bar.visible:
			bar.visible = false
		return
	t = maxf(t - delta, 0.0)
	z["bar_t"] = t
	bar.visible = t > 0.0
	main._fade_bar(bar, clampf(t / Main.BAR_FADE, 0.0, 1.0))


## Entre rondas: fuera proyectiles, trampas, zonas, espinas, balizas, esbirros y señuelos, y cada
## leyenda suelta lo que tuviera a medias (mejora, carga, guardia, invocaciones en cola).
func clear_world() -> void:
	for list in [bolts, traps, storms, beacons, allies]:
		for e in list:
			if e.get("node") != null and is_instance_valid(e["node"]):
				(e["node"] as Node).queue_free()
			if e.get("chain") != null and is_instance_valid(e["chain"]):
				(e["chain"] as Node).queue_free()
		list.clear()
	for sp in spikes:
		for n in sp["nodes"]:
			(n as Node).queue_free()
	spikes.clear()
	for f: Fighter in fighters:
		f.buff_left = 0.0
		if f.buff_fx != null:
			f.buff_fx.queue_free()
			f.buff_fx = null
		f.dash_left = 0.0
		f.guard = false
		f.still_t = 0.0
		if f.guard_fx != null:
			f.guard_fx.queue_free()
			f.guard_fx = null
		f.summon_queue.clear()
		f.spore_dps = 0.0


## Libera todo lo que el combate ha creado (al salir de la partida).
func clear() -> void:
	for list in [bolts, traps, storms, beacons, allies]:
		for e in list:
			if e.get("node") != null and is_instance_valid(e["node"]):
				(e["node"] as Node).queue_free()
			if e.get("chain") != null and is_instance_valid(e["chain"]):
				(e["chain"] as Node).queue_free()
		list.clear()
	for sp in spikes:
		for n in sp["nodes"]:
			(n as Node).queue_free()
	spikes.clear()
	for f: Fighter in fighters:
		f.brain = null
	fighters.clear()
