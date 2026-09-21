## Prueba pura de la reconciliación del juego en línea (fase 2, tarea 5 de
## docs/superpowers/plans/2026-09-20-juego-en-linea-f2-partida.md):
##   godot --headless --path . -s tests/test_net_predict.gd
## Nada de nodos, `Fighter` ni `Combat` aquí: NetClient.reconcile()/pending_after()/should_snap()/
## is_stale() son funciones puras (net/net_client.gd) y se prueban con un paso de movimiento cualquiera
## (una línea recta a velocidad fija), porque lo que hay que comprobar es que la reconciliación respeta
## el ORDEN y el CONTEO de los controles pendientes -no la física en sí, que ya prueban
## tests/rocks_probe.gd y compañía sobre el mapa de verdad-.
extends SceneTree

var failures := 0


func _check(ok: bool, msg: String) -> void:
	if not ok:
		print("FALLO: " + msg)
		failures += 1


## Paso determinista sencillo: avanza en línea recta según "wish" (ya en el plano del mundo, como
## llega de verdad) a 4 m/s durante "dt" segundos, con un "muro" de juguete en X -sin él, sumar
## vectores es conmutativo y CUALQUIER orden daría el mismo sitio final, así que la prueba de "el
## orden importa" (de abajo) no probaría nada; con el muro, chocar antes o después cambia el
## resultado, como pasaría de verdad con `move_and_slide()` contra el mapa-.
const _WALL_X := 10.2

static func _step(pos: Vector3, input: Dictionary) -> Vector3:
	var w: Vector2 = input["wish"]
	var p := pos + Vector3(w.x, 0.0, w.y) * 4.0 * float(input["dt"])
	p.x = minf(p.x, _WALL_X)
	return p


func _init() -> void:
	var confirmed := Vector3(10.0, 0.0, 0.0)
	var pending := [
		{"seq": 5, "wish": Vector2(1.0, 0.0), "dt": 0.10},
		{"seq": 6, "wish": Vector2(0.0, 1.0), "dt": 0.10},
		{"seq": 7, "wish": Vector2(-1.0, 0.0), "dt": 0.05},
	]
	var step := Callable(self, "_step")

	# --- reconcile(): reproducir en orden da lo mismo que aplicarlos uno a uno según llegaron ---
	var expected := confirmed
	for input in pending:
		expected = _step(expected, input)
	var got: Vector3 = NetClient.reconcile(confirmed, pending, step)
	_check(got.is_equal_approx(expected),
		"la reconciliación reproduce los mismos controles pendientes, en el mismo orden, que aplicarlos uno a uno")
	_check(NetClient.reconcile(confirmed, [], step) == confirmed,
		"sin controles pendientes, la posición confirmada por el servidor es la buena tal cual")

	# El orden importa (si cualquier orden diera lo mismo, la prueba de arriba no probaría nada: aquí
	# el segundo y el tercer control no conmutan, así que invertirlos tiene que dar otro sitio).
	var reversed_pending := pending.duplicate()
	reversed_pending.reverse()
	var got_rev: Vector3 = NetClient.reconcile(confirmed, reversed_pending, step)
	_check(not got_rev.is_equal_approx(got), "el orden de los controles pendientes importa")

	# --- pending_after(): qué controles quedan por confirmar tras un "ack" ---
	var sent := [
		{"seq": 1, "wish": Vector2.ZERO, "dt": 0.0},
		{"seq": 2, "wish": Vector2.ZERO, "dt": 0.0},
		{"seq": 3, "wish": Vector2.ZERO, "dt": 0.0},
	]
	_check(NetClient.pending_after(sent, 0).size() == 3, "ack=0 (nada confirmado todavía): quedan los tres")
	var after1 := NetClient.pending_after(sent, 1)
	_check(after1.size() == 2 and int(after1[0]["seq"]) == 2,
		"ack=1: el 1 ya está confirmado (=), quedan el 2 y el 3, EN ORDEN")
	_check(NetClient.pending_after(sent, 3).is_empty(), "ack=3 (el último mandado): no queda nada pendiente")
	_check(NetClient.pending_after(sent, 99).is_empty(), "un ack más nuevo que todo lo mandado tampoco deja nada pendiente")
	_check(NetClient.pending_after([], 5).is_empty(), "sin controles mandados, no hay nada que reproducir")

	# La reconciliación de verdad encadena las dos: filtrar por ack y LUEGO reproducir. Con ack=1 (el
	# primero de "pending" ya confirmado), reproducir los otros dos tiene que dar lo mismo que
	# reproducir el Array completo saltándose el primero a mano.
	var partial := NetClient.pending_after(pending, 5)   # el 5 ya confirmado, quedan el 6 y el 7
	_check(partial.size() == 2 and int(partial[0]["seq"]) == 6, "ack=5 dentro de 'pending' deja el 6 y el 7")
	var got_partial: Vector3 = NetClient.reconcile(confirmed, partial, step)
	var expected_partial := confirmed
	expected_partial = _step(expected_partial, pending[1])
	expected_partial = _step(expected_partial, pending[2])
	_check(got_partial.is_equal_approx(expected_partial),
		"reconciliar con ack a medio camino reproduce SOLO lo que queda por confirmar, en orden")

	# --- should_snap(): el umbral del spec (más de 1,5 m salta; 1,5 m clavado o menos, se suaviza) ---
	_check(not NetClient.should_snap(0.0), "sin error, no hace falta saltar")
	_check(not NetClient.should_snap(NetClient.RECONCILE_SNAP), "justo en el límite todavía se suaviza")
	_check(NetClient.should_snap(NetClient.RECONCILE_SNAP + 0.01), "un poco más allá del límite, salta")
	_check(NetClient.should_snap(20.0), "un error enorme (p. ej. tras un derribo) salta")

	# --- is_stale(): descartar una foto vieja o repetida por el reloj del SERVIDOR (revisión t4) ---
	_check(NetClient.is_stale(1.0, 1.0), "el mismo instante otra vez es repetida: se descarta")
	_check(NetClient.is_stale(0.9, 1.0), "un instante más viejo que el último aplicado: se descarta")
	_check(not NetClient.is_stale(1.1, 1.0), "un instante más nuevo: no se descarta")
	_check(not NetClient.is_stale(0.0, -INF), "la primera foto de la partida (nada aplicado todavía) nunca es vieja")

	print("test_net_predict: %s (%d fallos)" % ["OK" if failures == 0 else "FALLO", failures])
	quit(1 if failures > 0 else 0)
