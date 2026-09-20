## Prueba pura del catálogo de efectos del combate (game/fx_sink.gd), sin escena:
##   godot --headless --path . -s tests/test_fx_sink.gd
## `FxSink.KINDS` es lo que la fase 2 convertirá en avisos por red, así que aquí se comprueba que el
## catálogo esté sano (sin argumentos repetidos dentro de un mismo efecto) y que `FxSink.check`
## —el guardián que usa `Combat.emit_fx`— detecte un nombre que no existe o un argumento que falta,
## sin reventar. Un sink de mentira (`_RecordingFxSink`) apunta lo que recibiría de verdad.
## Diseño: docs/superpowers/specs/2026-09-18-juego-en-linea-design.md (§ "Separar lógica y efectos
## en el combate"); plan: docs/superpowers/plans/2026-09-20-juego-en-linea-f0-preparacion.md (Task 3).
extends SceneTree

var failures := 0


## Sink de mentira: no pinta nada, solo apunta cada efecto que le llega para poder comprobarlo.
class _RecordingFxSink extends FxSink:
	var received: Array = []

	func emit(kind: String, args: Dictionary) -> Variant:
		received.append({"kind": kind, "args": args})
		return null


func _check(ok: bool, msg: String) -> void:
	if not ok:
		print("FALLO: " + msg)
		failures += 1


func _init() -> void:
	_test_catalog_sano()
	_test_kind_desconocido_falla()
	_test_argumento_que_falta_se_detecta()
	_test_sink_recibe_lo_que_pide_el_catalogo()
	print("test_fx_sink: %s (%d fallos)" % ["OK" if failures == 0 else "FALLO", failures])
	quit(1 if failures > 0 else 0)


## Cada nombre del catálogo trae al menos un argumento y ninguno repetido: un argumento duplicado
## en la lista sería un error de transcripción que nadie notaría (`check` seguiría dando `true`
## aunque el catálogo mintiera sobre lo que hace falta).
func _test_catalog_sano() -> void:
	_check(FxSink.KINDS.size() > 0, "el catálogo no está vacío")
	for kind in FxSink.KINDS:
		var args: Array = FxSink.KINDS[kind]
		_check(args.size() > 0, "'%s' documenta al menos un argumento" % kind)
		var seen := {}
		for a in args:
			_check(not seen.has(a), "'%s' no repite el argumento '%s'" % [kind, a])
			seen[a] = true


## Un nombre que no está en KINDS falla con `push_error` y `false`, sin reventar el proceso: es el
## "no revienta" que pide la tarea (un efecto nuevo sin dar de alta en el catálogo se nota en la
## consola, no tira la partida).
func _test_kind_desconocido_falla() -> void:
	_check(FxSink.check("esto_no_existe", {}) == false, "un efecto desconocido falla check()")
	var sink := _RecordingFxSink.new()
	# Así es como lo usaría Combat.emit_fx: comprobar antes de pasarlo al sink.
	if FxSink.check("esto_no_existe", {}):
		sink.emit("esto_no_existe", {})
	_check(sink.received.is_empty(), "el sink de mentira no recibe un efecto que no pasó check()")


## Si a los argumentos les falta alguno de los que pide el catálogo, `check` lo detecta.
func _test_argumento_que_falta_se_detecta() -> void:
	_check(FxSink.check("flash", {"at": Vector3.ZERO, "color": Color.WHITE}) == false,
		"'flash' sin 'size' ni 'life' falla check()")
	_check(FxSink.check("flash", {"at": Vector3.ZERO, "color": Color.WHITE, "size": 1.0, "life": 0.2}) == true,
		"'flash' con sus 4 argumentos pasa check()")
	# 'burst' es el más largo del catálogo (10 argumentos): probar con uno de menos a propósito.
	var burst_completo := {"tex": "spark_04", "pos": Vector3.ZERO, "color": Color.WHITE, "amount": 6,
		"life": 0.2, "speed": 2.0, "size": 0.3, "grav": -4.0, "spread": 35.0, "from_radius": 0.1}
	_check(FxSink.check("burst", burst_completo) == true, "'burst' con sus 10 argumentos pasa check()")
	var burst_incompleto := burst_completo.duplicate()
	burst_incompleto.erase("from_radius")
	_check(FxSink.check("burst", burst_incompleto) == false, "'burst' sin 'from_radius' falla check()")


## Para cada efecto del catálogo, un sink que pase check() recibe exactamente esos argumentos: es la
## garantía de que `emit_fx` no deja pasar un efecto a medias (lo que la fase 2 mandaría por red
## tiene que traer todo lo que ese efecto necesita para pintarse).
func _test_sink_recibe_lo_que_pide_el_catalogo() -> void:
	var sink := _RecordingFxSink.new()
	for kind in FxSink.KINDS:
		var args := {}
		for arg_name in FxSink.KINDS[kind]:
			args[arg_name] = _valor_de_mentira(arg_name)
		_check(FxSink.check(kind, args), "los argumentos fabricados para '%s' pasan check()" % kind)
		sink.emit(kind, args)
	_check(sink.received.size() == FxSink.KINDS.size(), "el sink recibió un efecto por cada nombre del catálogo (%d de %d)" \
		% [sink.received.size(), FxSink.KINDS.size()])
	for rec in sink.received:
		var kind: String = rec["kind"]
		var args: Dictionary = rec["args"]
		for arg_name in FxSink.KINDS[kind]:
			_check(args.has(arg_name), "el sink recibió '%s' con su argumento '%s'" % [kind, arg_name])


## Un valor cualquiera, del tipo que toque, solo para poder llamar a `check()`/`emit()` sin que
## `push_error` se queje de un tipo raro dentro de `Vfx` si algún día `LocalFx.emit()` se probara
## aquí (hoy esta prueba no toca `Vfx`, así que basta con que la CLAVE esté presente).
func _valor_de_mentira(arg_name: String) -> Variant:
	match arg_name:
		"tex", "fx":
			return "spark_04"
		"pos", "at", "origin", "face", "a", "b", "parent":
			return Vector3.ZERO
		"color", "col":
			return Color.WHITE
		"full", "live":
			return false
		"mi", "node", "root":
			return null
		_:
			return 1.0
