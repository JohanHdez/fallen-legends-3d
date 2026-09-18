## Reglas puras del derribo y la reanimación, en la Horda y en PvP (peticiones del usuario,
## 2026-09-17). A 0 de vida una leyenda queda DERRIBADA: se arrastra despacio, no ataca y tiene
## BLEED_TIME para que un compañero AGACHADO a su lado la levante (TIME, con HP de vida). Si nadie lo
## hace, muere y la baja es de quien la derribó; muerta ya no se levanta. Los golpes a un derribado le
## quitan tiempo: el daño de FINISH_HP veces su vida máxima se lo quita todo. Con media vida (lo primero
## que se probó) los bots lo remataban de refilón en 4-8 s, sin querer: las básicas que iban a otro, el
## mandoble en abanico y el ancla le quitaban 2-8 s cada una. Ahora un golpe normal quita ~1 s y los
## proyectiles pasan por encima de un derribado salvo que vayan a por él (Combat._tick_soft_bolt). Antes volvía sola a los
## 15/30/60 s; eso se quitó. Alcance, tiempo de levantar, vida e inmunidad son las cifras del 2D
## (player.gd REVIVE_*, SPAWN_INVULN). Quién las aplica cada fotograma es ReviveSystem.
class_name Revive
extends RefCounted

const RANGE := 90.0 * LegendData.PX     # 1,4 m
const TIME := 3.0                       # segundos agachado a su lado
const HP := 0.5                         # se levanta con media vida
const INVULN := 3.0                     # y sin recibir daño un rato
const BLEED_TIME := 45.0                # derribado: lo que tardan en levantarlo antes de que muera
const FINISH_HP := 1.5                  # rematar: este tanto de su vida máxima en daño lo mata
const CRAWL_SPEED := 0.25               # se arrastra a este tanto de su velocidad
# Animaciones (Universal Animation Library Pro de Quaternius, 2026-09-17): el derribado GATEA de
# verdad (Crawl_*, en las cuatro direcciones) y quien lo levanta se arrodilla. Antes, sin la Pro, se
# usaba la de nadar pegada al suelo como apaño y el usuario lo notó enseguida.
const DOWNED_STATE := Combat.ANIM_CRAWL   # Crawl_Fwd / _Bwd / _Left / _Right / _Idle, según se arrastre
const DOWNED_IDLE := DOWNED_STATE + "_Idle"
const HELPER_ANIM := "Fixing_Kneeling"


## Segundos de derribo que le quedan tras recibir `dmg` con `hp_max` de vida máxima.
static func bleed_after_hit(bleed: float, dmg: float, hp_max: float) -> float:
	return maxf(0.0, bleed - BLEED_TIME * dmg / maxf(hp_max * FINISH_HP, 1.0))


## Progreso de la reanimación: sube con ayuda y baja al mismo ritmo si el que ayudaba se va.
static func progress(p: float, helped: bool, delta: float) -> float:
	return clampf(p + (delta if helped else -delta) / TIME, 0.0, 1.0)


## ¿Puede levantar a un derribado alguien vivo, agachado o no, a esta distancia?
static func can_help(helper_alive: bool, helper_crouch: bool, dist: float) -> bool:
	return helper_alive and helper_crouch and dist <= RANGE
