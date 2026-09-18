## Una leyenda en juego: la tuya o la de un bot. Guarda el cuerpo, el modelo, el equipo y todo el
## estado de lanzador (recargas, cargas, preaviso, mejora, carga, mandoble cargado, guardia,
## ocultación). Quién la maneja (teclado, táctil o BotBrain) es aparte: `wish`, `run`, `crouch` y
## `holding_basic` son lo único que el control escribe. Así, el día que haya red, un jugador remoto
## maneja un Fighter sin tocar el combate.
##
## `rec` es su ficha de OBJETIVO, la misma forma que la de una criatura (ver Combat): vida, muerte,
## aturdimiento, empujón, lentitud, esporas y barra. Es lo que el daño y los efectos tocan.
class_name Fighter
extends RefCounted

const TEAM_HORDE := 0
const TEAM_BLUE := 1
const TEAM_RED := 2
## Definitiva por carga (equipos): se llena con el daño que la leyenda hace con lo que NO es su
## definitiva. Hace falta el daño de ULT_SECONDS segundos de su básica sin fallar, así que cada
## leyenda carga al mismo ritmo acierte lo que acierte (el Ilusionista pega poco pero muy seguido).
const ULT_SECONDS := 6.0
const ULT_PASSIVE := 1.0 / 45.0        # y además gotea sola: llena en 45 s sin pegar (curanderos, invocadores)
## Romper un señuelo de la Ilusionista marca a quien lo rompió (idea del usuario): su equipo lo ve
## con un contorno rojo a través de muros y rocas, y no puede esconderse en la hierba.
const MARK_TIME := 5.0

var id := 0
var team := TEAM_BLUE
var legend := 0
var is_player := false
var display_name := ""
var brain: RefCounted = null          # BotBrain, o null si la maneja una persona

var body: CharacterBody3D
var model: Node3D
var anims: Array = []                  # un AnimationPlayer por capa del modelo
var anim: AnimationPlayer              # la primera capa, para consultar el estado
var bar: Node3D
var label: Label3D
var torch: OmniLight3D
var rec: Dictionary = {}

# -- control (lo escribe quien la maneja) ----------------------------
var wish := Vector3.ZERO               # dirección de movimiento deseada, en el plano
var run := false
var crouch := false
var holding_basic := false             # mantener la básica: carga el mandoble del Rompemareas

# -- lanzador --------------------------------------------------------
var cd: Array = [0.0, 0.0, 0.0]        # recarga restante de cada ranura
var chg: Array = [0, 0, 0]             # cargas disponibles (las habilidades que las usan)
var chg_t: Array = [0.0, 0.0, 0.0]
var windup := -1.0                     # preaviso en curso (cast_time), como Caster.windups
var windup_idx := -1
var windup_at := Vector3.ZERO
var cast_anim_t := 0.0                 # mientras corre, la animación de conjuro manda sobre andar
var hit_anim_t := 0.0                  # queja por un golpe: mientras corre, manda sobre andar
var hit_anim_cd := 0.0                 # y no encadena quejas (Combat.HIT_ANIM_EVERY)

var buff_left := 0.0
var buff_resist := 0.0
var buff_root := false
var buff_dmg := 0.0
var buff_rad := 0.0
var buff_tick := 0.0
var buff_fx: Node3D = null
var buff_slot := -1

var dash_vec := Vector3.ZERO
var dash_left := 0.0
var dash_dmg := 0.0
var dash_rad := 0.0
var dash_hit := {}
var dash_shove := 0.0
var dash_done := 0.0
var dash_t := 0.0
var dash_dur := 1.0
var dash_total := 0.0
var dash_from := Vector3.ZERO
var dash_want := 0.0
var dash_slot := -1                    # ranura que lanzó la carga en curso (la definitiva no se recarga a sí misma)

var swing_charge_t := 0.0
var charge_mult := 1.0

var guard := false
var guard_fx: Node3D = null
var still_t := 0.0

var hidden_t := 0.0                    # invisibilidad (Fiesta de clones)
var spotted_t := 0.0                   # atacar te delata unos segundos aunque sigas agachado
var last_seen := Vector3.ZERO          # dónde la vieron por última vez
var swap_t := 0.0
var step := Vector3.ZERO               # lo que se movió este fotograma (lo copian los señuelos)
var prev_pos := Vector3.ZERO
var spore_dps := 0.0                   # fuerza de SU plaga (Esporas del Clérigo)
var summon_queue: Array = []
var summon_t := 0.0
var summon_slot := -1
var minion_order := "attack"           # órdenes de sus esqueletos (Minions): attack, regroup, ambush
var ambush_at := Vector3.ZERO          # dónde emboscan

# -- partida ---------------------------------------------------------
var hp_mult := 1.0                     # por equipos la vida va ×3 (TeamMode.PVP_HP_MULT)
var ult_by_charge := false             # por equipos la definitiva va por carga, no por recarga
var ult_charge := 0.0                  # 0..1
var ammo_max := 0                      # munición de la básica (equipos); 0 = sin límite (Horda, Ilusionista)
var ammo := 0
var ammo_t := 0.0                      # lo que falta para que vuelva el siguiente disparo
var ammo_reload := 0.0
var basic_dmg_mult := 1.0              # daño de la básica por equipos (LegendData.PVP_BASIC_DMG)
var dmg_mult := 1.0                    # todo el daño que hace (el jefe de la Horda, ×1,5)
var regen := true                      # se regenera tras REGEN_DELAY sin daño (el jefe de la Horda, no)
var marked_t := 0.0                    # marcado por romper un señuelo: segundos que quedan
var mark_team := -1                    # equipo que lo ve marcado (el del señuelo)
var mark_shown := false                # ¿lleva puesto el contorno? (solo lo dibuja quien lo ve)
var since_damage := 0.0               # segundos sin recibir daño: a partir de REGEN_DELAY se regenera
var downed := false                    # a 0 de vida: derribada, arrastrándose, hasta que la levanten o muera
var bleed_t := 0.0                     # segundos que le quedan derribada (Revive.BLEED_TIME)
var downed_by := -1                    # id de quien la derribó: suya es la baja si muere
var revive_progress := 0.0             # 0..1 mientras un compañero agachado la levanta
var reviving := false                  # está levantando a alguien este fotograma (se arrodilla)
var invuln_t := 0.0
var invuln_fx: Node3D = null
var kills := 0
var deaths := 0
var streak := 0


func data() -> Dictionary:
	return LegendData.LEGENDS[legend]


func abil(i: int) -> Dictionary:
	var list: Array = LegendData.ABILITIES.get(data()["id"], LegendData.ABILITIES["tormentero"])
	return list[i] if i < list.size() else list[0]


func hp() -> float:
	return float(rec.get("hp", 0.0))


func hp_max() -> float:
	return float(data()["hp"]) * hp_mult


## En pie: con vida (una derribada no ataca ni cuenta para ganar la ronda).
func alive() -> bool:
	return hp() > 0.0


## Muerta de verdad: ni en pie ni derribada.
func dead() -> bool:
	return hp() <= 0.0 and not downed


func speed() -> float:
	return float(data()["speed"]) * LegendData.PX


func pos() -> Vector3:
	return body.global_position


## Hacia dónde mira el modelo, en el plano.
func facing() -> Vector3:
	if model == null:
		return Vector3(0, 0, 1)
	return Vector3(sin(model.rotation.y), 0, cos(model.rotation.y))


func ability_range(i: int) -> float:
	var r := float(abil(i).get("rng", 0.0)) * LegendData.PX
	return r if r > 0.1 else 2.5      # 0 = centrada en uno mismo


func ability_radius(i: int) -> float:
	return float(abil(i).get("rad", 24.0)) * LegendData.PX


func ability_ready(i: int) -> bool:
	if hp() <= 0.0 or windup >= 0.0:
		return false
	if i == 2 and ult_by_charge:
		return ult_charge >= 1.0
	if i == 0 and ammo_max > 0 and ammo <= 0:
		return false
	var ab := abil(i)
	if int(ab.get("chg", 0)) > 0:
		return chg[i] > 0
	return cd[i] <= 0.0


func cooldown_left(i: int) -> float:
	if i == 2 and ult_by_charge:
		return 0.0
	if i == 0 and ammo_max > 0 and ammo <= 0:
		return ammo_t
	var ab := abil(i)
	if int(ab.get("chg", 0)) > 0:
		return chg_t[i] if chg[i] < int(ab["chg"]) else 0.0
	return cd[i]


func cooldown_fraction(i: int) -> float:
	if i == 2 and ult_by_charge:
		return clampf(1.0 - ult_charge, 0.0, 1.0)
	if i == 0 and ammo_max > 0 and ammo <= 0:
		return clampf(ammo_t / maxf(ammo_reload, 0.01), 0.0, 1.0)
	var ab := abil(i)
	var total := float(ab.get("cd", 1.0))
	if int(ab.get("chg", 0)) > 0:
		return clampf(chg_t[i] / total, 0.0, 1.0) if chg[i] < int(ab["chg"]) else 0.0
	return clampf(cd[i] / total, 0.0, 1.0)


## Lo que enseña el botón de una ranura mientras no está lista: "73%" de carga para la definitiva
## por carga, o los segundos de recarga ("4.2"). Vacío si está lista.
func cooldown_text(i: int) -> String:
	if i == 2 and ult_by_charge:
		return "" if ult_charge >= 1.0 else "%d%%" % int(floor(ult_charge * 100.0))
	var left := cooldown_left(i)
	return "%.1f" % left if left > 0.0 else ""


## Daño que llena la definitiva por carga: ULT_SECONDS de daño por segundo de la básica, por el
## multiplicador de vida (con vida ×3 cada baja pide el triple de daño, y la carga también). La
## munición NO la rebaja: contar el ritmo sostenido casi duplicaba las definitivas en 28 partidas
## (201 -> 375, del 15 % al 20 % del daño); con la cuenta de siempre quedan en 310 y el 12 %.
func ult_need() -> float:
	var ab := abil(0)
	var period := maxf(maxf(float(ab.get("cd", 1.0)), float(ab.get("cast", 0.0))), 0.1)
	var dps := float(ab.get("dmg", 0.0)) * basic_dmg_mult / period
	return (ULT_SECONDS * dps if dps > 0.0 else 200.0) * hp_mult


## Suma a la carga de la definitiva el daño hecho (solo si va por carga).
func add_ult_damage(dealt: float) -> void:
	if not ult_by_charge or dealt <= 0.0:
		return
	ult_charge = minf(ult_charge + dealt / ult_need(), 1.0)


## Rellena las cargas y la munición y vacía las recargas (al nacer, al cambiar de leyenda y en cada
## ronda).
func reset_abilities() -> void:
	for i in 3:
		cd[i] = 0.0
		chg[i] = int(abil(i).get("chg", 0))
		chg_t[i] = 0.0
	ammo = ammo_max
	ammo_t = 0.0


## Munición de su leyenda por equipos (LegendData.PVP_AMMO), llena. Sin fila, sin límite.
func enable_ammo() -> void:
	var row: Dictionary = LegendData.PVP_AMMO.get(String(data()["id"]), {})
	ammo_max = int(row.get("n", 0))
	ammo_reload = float(row.get("reload", 0.0))
	ammo = ammo_max
	ammo_t = 0.0


## Daño de la básica de su leyenda por equipos (LegendData.PVP_BASIC_DMG). Sin fila, el de siempre.
func enable_pvp_damage() -> void:
	basic_dmg_mult = float(LegendData.PVP_BASIC_DMG.get(String(data()["id"]), 1.0))


## Marcado por romper un señuelo de `by_team`: vuelve a MARK_TIME, no suma.
func mark(by_team: int) -> void:
	marked_t = MARK_TIME
	mark_team = by_team


func marked_for(team: int) -> bool:
	return marked_t > 0.0 and mark_team == team


## Gasta un disparo de la básica; si no estaba volviendo ninguno, empieza a volver.
func spend_ammo() -> void:
	if ammo_max <= 0 or ammo <= 0:
		return
	ammo -= 1
	if ammo_t <= 0.0:
		ammo_t = ammo_reload


## Munición para la barra: los disparos llenos más lo que lleva el que está volviendo (1,25 = uno
## lleno y el segundo a un cuarto).
func ammo_level() -> float:
	if ammo >= ammo_max:
		return float(ammo_max)
	return float(ammo) + 1.0 - clampf(ammo_t / maxf(ammo_reload, 0.01), 0.0, 1.0)


## Descuenta recargas y repone cargas y munición.
func tick_cooldowns(delta: float) -> void:
	if ammo_max > 0 and ammo < ammo_max:
		ammo_t -= delta
		while ammo_t <= 0.0 and ammo < ammo_max:
			ammo += 1
			ammo_t += ammo_reload      # lo que sobró cuenta para el siguiente
		if ammo >= ammo_max:
			ammo_t = 0.0
	for i in 3:
		cd[i] = maxf(0.0, cd[i] - delta)
		var ab := abil(i)
		var maxc := int(ab.get("chg", 0))
		if maxc > 0 and chg[i] < maxc:
			chg_t[i] -= delta
			if chg_t[i] <= 0.0:
				chg[i] += 1
				chg_t[i] = float(ab["cd"]) if chg[i] < maxc else 0.0
