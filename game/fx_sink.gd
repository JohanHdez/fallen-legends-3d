## Único punto de salida de los efectos visuales del combate (game/combat.gd). Antes `Combat` llamaba
## a `Vfx` directamente desde la lógica (57 sitios): imposible separar quién SIMULA la partida de
## quién la PINTA. Sale de combat.gd el 2026-09-20 para la fase 0 del juego en línea
## (docs/superpowers/specs/2026-09-18-juego-en-linea-design.md, "Separar lógica y efectos en el
## combate"): ahora todo efecto pasa por `Combat.emit_fx(kind, args)` y quién lo recibe se decide
## fuera. Hoy solo existe `LocalFx`, que pinta con `Vfx` exactamente lo mismo que hacía `Combat`
## antes: NO cambia ni un píxel. En la fase 2, el servidor tendrá un sink que convierte cada efecto
## en un aviso por red, y el cliente uno que pinta al recibirlo; ninguno de los dos se hace aquí.
class_name FxSink
extends RefCounted

## kind -> lista de argumentos que necesita, con los mismos nombres que usan las funciones de `Vfx`
## (o "at"/"col" donde `Vfx.spark` los llama así). Es el catálogo que `tests/test_fx_sink.gd`
## comprueba y el que la fase 2 usará para saber qué mandar por la red.
const KINDS: Dictionary = {
	"burst": ["tex", "pos", "color", "amount", "life", "speed", "size", "grav", "spread", "from_radius"],
	"flash": ["at", "color", "size", "life"],
	"spark": ["at", "col"],
	"emitter": ["parent", "tex", "color", "radius", "amount", "life", "rise", "size"],
	"disc": ["radius", "color", "alpha"],
	"ring": ["radius", "color", "alpha"],
	"gas_cloud": ["node", "rad", "col"],
	"swing_dust": ["origin", "face", "rad", "full", "arc", "amount"],
	"zone_burst": ["at", "rad", "col", "fx", "bolts"],
	"spike_clump": ["rad"],
	"bubble": ["radius", "color"],
	"span": ["mi", "a", "b"],
	"electric_orb": ["color"],
	"nox_orb": ["color"],
	"tick_orb": ["root", "t", "live"],
	"tick": ["delta"],
	"spore_lumps": ["color", "scale"],
	# No es un efecto de Vfx: registra un nodo YA creado (el disco de un golpe, el aura de curación)
	# para que `Vfx.tick` lo libere solo tras `life` segundos. Antes era `vfx.sparks.append(...)`.
	"register_temp": ["node", "life"],
}


## ¿`kind` está en el catálogo y `args` trae TODOS sus argumentos? Si no, `push_error` y `false`: así
## un nombre mal escrito o un argumento que falta se ve en la consola en vez de reventar la partida.
static func check(kind: String, args: Dictionary) -> bool:
	if not KINDS.has(kind):
		push_error("FxSink: efecto desconocido '%s'" % kind)
		return false
	for arg_name in KINDS[kind]:
		if not args.has(arg_name):
			push_error("FxSink: al efecto '%s' le falta el argumento '%s'" % [kind, arg_name])
			return false
	return true


## Recibe un efecto ya validado. La base no pinta nada: cada sink decide qué hacer (pintarlo,
## ignorarlo, convertirlo en aviso). Devuelve lo que combat.gd necesite guardar después (el nodo de
## la esfera de una trampa, para poder ir apagándolo con `tick_orb`); los efectos que no crean nada
## que guardar devuelven null.
func emit(_kind: String, _args: Dictionary) -> Variant:
	return null


## Implementación de hoy, sin conexión: pinta con `Vfx` exactamente lo que pintaba `Combat` antes de
## esta tarea. `main.gd` sigue creando el `Vfx` de siempre (`main.vfx`); `Combat` construye este sink
## con esa misma instancia, así que `game/horde.gd`, `game/minions.gd`, `game/revive_system.gd` y
## `game/player_input.gd` (que pintan con `main.vfx` directamente y no forman parte de esta tarea)
## siguen viendo el mismo objeto.
class LocalFx extends FxSink:
	var vfx: Vfx

	func _init(p_vfx: Vfx) -> void:
		vfx = p_vfx

	func emit(kind: String, args: Dictionary) -> Variant:
		match kind:
			"burst":
				vfx.burst(args["tex"], args["pos"], args["color"], args["amount"], args["life"],
					args["speed"], args["size"], args["grav"], args["spread"], args["from_radius"])
				return null
			"flash":
				vfx.flash(args["at"], args["color"], args["size"], args["life"])
				return null
			"spark":
				vfx.spark(args["at"], args["col"])
				return null
			"spore_lumps":
				return vfx.spore_lumps(args["color"], args["scale"])
			"emitter":
				return vfx.emitter(args["parent"], args["tex"], args["color"], args["radius"],
					args["amount"], args["life"], args["rise"], args["size"])
			"disc":
				return vfx.disc(args["radius"], args["color"], args["alpha"])
			"ring":
				return vfx.ring(args["radius"], args["color"], args["alpha"])
			"gas_cloud":
				vfx.gas_cloud(args["node"], args["rad"], args["col"])
				return null
			"swing_dust":
				vfx.swing_dust(args["origin"], args["face"], args["rad"], args["full"], args["arc"], args["amount"])
				return null
			"zone_burst":
				# `Vfx.zone_burst` lee col/fx/bolts de un Dictionary (era el propio `st` de la zona):
				# aquí se reconstruye con solo esos tres, para no pasar por `emit_fx` el `st` entero
				# (que trae daño, radio, dueño... nada de eso lo necesita el dibujo).
				vfx.zone_burst({"col": args["col"], "fx": args["fx"], "bolts": args["bolts"]}, args["at"], args["rad"])
				return null
			"spike_clump":
				return vfx.spike_clump(args["rad"])
			"bubble":
				return vfx.bubble(args["radius"], args["color"])
			"span":
				vfx.span(args["mi"], args["a"], args["b"])
				return null
			"electric_orb":
				return vfx.electric_orb(args["color"])
			"nox_orb":
				return vfx.nox_orb(args["color"])
			"tick_orb":
				vfx.tick_orb(args["root"], args["t"], args["live"])
				return null
			"tick":
				vfx.tick(args["delta"])
				return null
			"register_temp":
				vfx.sparks.append({"node": args["node"], "life": args["life"]})
				return null
			_:
				push_error("FxSink.LocalFx: efecto sin pintar '%s'" % kind)
				return null
