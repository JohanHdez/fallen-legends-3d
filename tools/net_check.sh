#!/usr/bin/env bash
# Prueba de la sala y la partida en línea con varios procesos (juego en línea,
# docs/superpowers/specs/2026-09-18-juego-en-linea-design.md): un servidor sin pantalla por
# WebSocket y dos clientes sin pantalla que entran por el menú, eligen, se ponen listos y el líder
# inicia un 3v3; un tercer cliente con otra versión del protocolo, que el servidor tiene que echar; y
# un cuarto (fase 2, tarea 3) que arranca un 1v1 él solo y manda controles de verdad -RemoteControl-
# para comprobar que el servidor mueve su leyenda, no solo que el reloj de ronda avanza; ese mismo
# cliente (tarea 4) ahora también lee sus propias fotos (NetClient) y dice cuánto vio moverse su
# leyenda, para comparar con lo que tiene el servidor y comprobar que el cliente pinta lo mismo; y un
# quinto (tarea 5) que hace lo mismo que el cuarto pero con --lag=150 (fotos retrasadas a propósito)
# para comprobar que la predicción y la reconciliación de su propia leyenda no dan tirones hacia atrás;
# y un sexto (tarea 5b, el dedo y las habilidades en línea) que en vez de teclado usa --touch: joystick
# y botón de la básica de verdad (game/player_input.gd, creado ahora también para un cliente en línea),
# para comprobar que el servidor confirma tanto el movimiento como el lanzamiento (recarga consumida)
# y que la munición que enseña el HUD es la del servidor, no una cuenta propia; y un séptimo
# (2026-09-20) que sale de la partida por el menú de pausa, que hasta esa fecha no existía en línea.
#   tools/net_check.sh            # sale con 0 si todo va bien (lo llama tools/check.sh)
set -uo pipefail
cd "$(dirname "$0")/.."
GODOT="${GODOT:-godot}"
PORT="${NET_PORT:-17777}"
with_timeout() { perl -e 'alarm shift; exec @ARGV' "$@"; }
tmp="$(mktemp -d)"
fail=0

# "with_timeout ... &" deja en "$server" el subshell que bash crea para el trabajo en segundo
# plano, NO el perl/godot que hace "exec" dentro de él (bash no lo colapsa aunque sea su único
# comando): matar solo "$server" mata ese subshell y deja al Godot real huérfano, sin nadie que lo
# pare, todavía escuchando el puerto. Hay que matar también a su hijo real, con "pkill -P" antes de
# que "$server" muera y ese hijo se quede sin padre que lo identifique.
kill_one() {  # señal (TERM o KILL) y pid del trabajo
  [ -n "${2:-}" ] || return 0
  pkill -"$1" -P "$2" 2>/dev/null
  kill -"$1" "$2" 2>/dev/null
}
# Hay DOS servidores: el de siempre y el de rondas cortas de la tarea 7 (partida entera), que solo
# vive el rato de su prueba. Los dos se matan igual.
kill_server() {  # señal (TERM o KILL)
  kill_one "$1" "${server:-}"
  kill_one "$1" "${server2:-}"
}

# Que no quede un servidor ocupando el puerto aunque se corte la prueba: el siguiente arranque lo
# vería ocupado y los clientes probarían contra el viejo (2026-09-18).
cleanup() {
  kill_server TERM
  sleep 0.5
  kill_server KILL
  rm -rf "$tmp"
}
# Tres trampas separadas, no una sola con varias señales: con "trap cleanup EXIT INT TERM" a
# secas, bash ejecuta "cleanup" al recibir Ctrl-C/TERM y LUEGO SIGUE el script (el trap no corta
# el flujo por sí solo) — seguiría con un "$tmp" que "cleanup" ya borró y saldría por la salida
# normal (con sus propios "No existe el fichero o directorio"). INT/TERM cortan de verdad con su
# "exit"; EXIT sigue cubriendo la salida normal y los "exit 1" tempranos (que no repiten cleanup:
# ya se ejecutó vía el trap de salida).
trap 'cleanup; exit 130' INT
trap 'cleanup; exit 143' TERM
trap cleanup EXIT

if lsof -nP -iTCP:"$PORT" -sTCP:LISTEN >/dev/null 2>&1; then
  echo "✗ el puerto $PORT ya está ocupado (¿un servidor de una prueba anterior?): los clientes probarían contra él"
  lsof -nP -iTCP:"$PORT" -sTCP:LISTEN | sed 's/^/    /'
  exit 1
fi

# --log: sin él, TeamMode._print_state() no suelta el "[PARTIDA] ronda …" que comprueba la tarea 2
# de la fase 2 (el servidor lee sus PROPIOS argumentos de arranque, no los de quien pide la partida).
with_timeout 240 "$GODOT" --headless --path . -- --server --transport=ws --port="$PORT" --log \
  --identity="$tmp/servidor.json" >"$tmp/servidor.log" 2>&1 &
server=$!
# La línea de error ("… (ws) · ERROR 22") también casa con "servidor escuchando en el puerto $PORT":
# hay que exigir esa línea SIN "ERROR", si no, un fallo de bind cuela como arranque correcto.
listening() { grep "servidor escuchando en el puerto $PORT" "$tmp/servidor.log" 2>/dev/null | grep -qv "ERROR"; }
for _ in $(seq 1 60); do listening && break; sleep 0.5; done
if ! listening; then
  echo "✗ el servidor no arrancó"; tail -20 "$tmp/servidor.log" | sed 's/^/    /'
  exit 1
fi

client() {  # nombre y flags de la sonda
  local name="$1"; shift
  with_timeout 150 "$GODOT" --headless --path . -- --mode=menu --nodecor --client="ws://127.0.0.1:$PORT" \
    --name="$name" --identity="$tmp/$name.json" --netprobe=lobby_probe "$@" >"$tmp/$name.log" 2>&1
}

client Ana --want-mode=3v3 --want-legend=0 --want-team=1 --expect=2 &
ana=$!
# Ana llega primero, así que es la líder: Beto entra cuando ella ya está en la sala.
for _ in $(seq 1 120); do grep -q "\[RED\] en la sala" "$tmp/Ana.log" 2>/dev/null && break; sleep 0.5; done
# Beto no pide leyenda: entra con la que eligió en el menú (--menu-legend). Así se vigila que la
# elección del menú llega a la sala (bug del 2026-09-20: entrabas con otra).
client Beto --want-mode=3v3 --menu-legend=3 --want-team=2 &
beto=$!
wait "$ana"; ca=$?
wait "$beto"; cb=$?
client Viejo --protocol=99 --expect-kick
cv=$?

# Fase 2, tarea 2: con la sala ya vacía (Ana y Beto se fueron, Viejo nunca llegó a entrar), un
# cliente solo se hace líder, pide un 1v1 y arranca en cuanto está listo (nadie más a quien esperar).
# Tarea 3 (docs/superpowers/plans/2026-09-20-juego-en-linea-f2-partida.md): ya no basta con que el
# servidor monte la partida y el reloj de ronda avance solo (eso pasa igual aunque tick_brains y
# move_bots estén rotos, revisión de la tarea 2, hallazgo 4) — match_net_probe manda "avanzar" de
# verdad por RemoteControl (--netprobe=lobby_probe sobra aquí: match_net_probe hace lo mismo de
# entrar/liderar/pedir/iniciar y además prueba el control). Se desconecta al acabar de mandar: el
# servidor, al notar la caída del peer, dice con --log cuánto llegó a moverse la leyenda
# (net/net_server.gd, on_disconnect) — la única "foto" que hay hasta la tarea 4.
client Cara --netprobe=match_net_probe --want-mode=1v1 --secs=25 &
cara=$!
wait "$cara"; cc=$?
grep -E "^\[RED\]|^match_net_probe" "$tmp/Cara.log" | tail -5 | sed 's/^/    Cara: /'
if [ "$cc" -ne 0 ] || ! grep -q "^match_net_probe: OK" "$tmp/Cara.log" || grep -q "SCRIPT ERROR" "$tmp/Cara.log"; then
  echo "✗ cliente Cara (salida $cc)"
  fail=1
else
  echo "✓ cliente Cara"
fi

# Cuánto dijo el servidor que se movió Cara antes de irse (RemoteControl de verdad, no solo el reloj
# de ronda): puede tardar un instante en aparecer tras la desconexión, así que se espera un poco.
moved=""
for _ in $(seq 1 20); do
  moved="$(grep -oE 'Cara se movió [0-9.]+ m' "$tmp/servidor.log" 2>/dev/null | tail -1 | grep -oE '[0-9.]+')"
  [ -n "$moved" ] && break
  sleep 0.5
done
if [ -z "$moved" ]; then
  echo "✗ el servidor nunca dijo cuánto se movió Cara (¿RemoteControl no aplicó los controles?)"
  fail=1
elif ! awk -v n="$moved" 'BEGIN{exit !(n>3)}'; then
  echo "✗ Cara solo se movió $moved m (hacían falta más de 3): RemoteControl no la movió de verdad"
  fail=1
else
  echo "✓ servidor: RemoteControl movió de verdad la leyenda de Cara ($moved m)"
fi

# Lo que VIO el cliente en sus propias fotos (tarea 4: net/net_client.gd, my_pos) frente a lo que
# TIENE el servidor: no pueden separarse más de 1,5 m (spec, "Cliente: pintar lo que manda el
# servidor") — antes de la tarea 4 el cliente no tenía mundo ni fotos que leer.
client_moved="$(grep -oE 'cliente vio moverse su leyenda [0-9.]+ m' "$tmp/Cara.log" 2>/dev/null | tail -1 | grep -oE '[0-9.]+')"
if [ -z "$client_moved" ]; then
  echo "✗ el cliente nunca vio moverse su leyenda (¿NetClient sin fotos, o sin mundo que pintar?)"
  fail=1
elif [ -n "$moved" ] && ! awk -v a="$moved" -v b="$client_moved" 'BEGIN{d=a-b; if(d<0)d=-d; exit !(d<=1.5)}'; then
  echo "✗ servidor $moved m frente a cliente $client_moved m: se separan más de 1,5 m"
  fail=1
else
  echo "✓ cliente: vio moverse su leyenda $client_moved m (servidor $moved m, dentro de 1,5 m)"
fi

# Tarea 5 (predicción y reconciliación): lo mismo que Cara, pero con --lag=150 -retraso artificial de
# las FOTOS que llegan, leído por net/net_client.gd, no un proxy de verdad-, para comprobar el punto
# del plan que Cara sola no ejercita (con el bucle local casi no hay retardo que reconciliar): "con
# 150 ms de retardo simulado, tu leyenda no da tirones". match_net_probe ya lleva la comprobación
# integrada (muestrea predicted_visual_pos() mientras empuja "avanzar" y exige que ningún fotograma
# retroceda más de 0,3 m); aquí solo hace falta pasarle el flag y leer lo que midió.
client Dana --netprobe=match_net_probe --want-mode=1v1 --secs=25 --lag=150 &
dana=$!
wait "$dana"; cd=$?
grep -E "^\[RED\]|^match_net_probe" "$tmp/Dana.log" | tail -6 | sed 's/^/    Dana: /'
if [ "$cd" -ne 0 ] || ! grep -q "^match_net_probe: OK" "$tmp/Dana.log" || grep -q "SCRIPT ERROR" "$tmp/Dana.log"; then
  echo "✗ cliente Dana con --lag=150 (salida $cd)"
  fail=1
else
  echo "✓ cliente Dana: predicción sin tirones con 150 ms de retardo simulado"
fi
backstep="$(grep -oE 'peor retroceso en un fotograma: [0-9.]+' "$tmp/Dana.log" 2>/dev/null | tail -1 | grep -oE '[0-9.]+$')"
if [ -z "$backstep" ]; then
  echo "✗ Dana nunca midió el retroceso de la predicción (¿nunca llegó a empujar 'avanzar'?)"
  fail=1
else
  echo "    Dana: peor retroceso con --lag=150 ms: ${backstep} m (tope 0,3 m, spec de la tarea 5)"
fi
# El retroceso entre fotogramas es CIEGO a un error constante: si la reconciliación repone menos
# distancia de la que el servidor recorrió, la leyenda no da tirones, simplemente va por detrás de
# donde el servidor la tiene (revisión de la tarea 5, 2026-09-20). Lo que lo delata es el ADELANTO de
# la predicción sobre lo confirmado, que a 150 ms debe rondar los 0,36 m (retardo x velocidad):
# reproduciendo mal se queda en 0,13; reproduciendo bien, 0,38. Banda 0,20-0,80 m.
lead="$(grep -oE 'adelanto sobre lo confirmado: [0-9.]+' "$tmp/Dana.log" 2>/dev/null | tail -1 | grep -oE '[0-9.]+$')"
if [ -z "$lead" ]; then
  echo "✗ Dana nunca midió el adelanto de la predicción"
  fail=1
elif awk -v v="$lead" 'BEGIN{exit !(v < 0.20)}'; then
  echo "✗ la predicción solo va ${lead} m por delante de lo confirmado con --lag=150 (mínimo 0,20): la reproducción de los controles no repone la distancia que toca"
  fail=1
else
  echo "    Dana: la predicción va ${lead} m por delante de lo confirmado (mínimo 0,20 m; a 150 ms lo teórico son ~0,36)"
fi
# Ojo al margen: reproduciendo mal se midió 0,181 y reproduciendo bien 0,25-0,38. Distingue, pero no
# de sobra. El cociente "velocidad reproducida/viva" que también imprime la sonda parecía una medida
# más limpia y NO lo es: una embestida mueve 23 m/s y lo dispara (5,25 en el cliente táctil), así que
# se deja impreso como diagnóstico pero no se usa como puerta (2026-09-20).

# Tarea 5b (el dedo y las habilidades en línea): un cliente TÁCTIL (--touch, lo mismo que fuerza
# main.touch) empuja el joystick de verdad (game/player_input.gd, creado ahora también para un
# cliente en línea: antes de esta tarea `main.input` ni existía aquí) y toca el botón de la básica
# (match_net_probe._touch_push/_tap_ability). Comprueba que el servidor confirma AMBAS cosas: que se
# movió (RemoteControl, el mismo camino que Cara) y que la habilidad salió de verdad (NetServer.on_cast
# -> combat.try_cast, con recarga consumida) - nunca al revés: el cliente solo pide, el servidor decide.
client Elsa --netprobe=match_net_probe --want-mode=1v1 --secs=25 --touch &
elsa=$!
wait "$elsa"; ce=$?
grep -E "^\[RED\]|^match_net_probe" "$tmp/Elsa.log" | tail -6 | sed 's/^/    Elsa: /'
if [ "$ce" -ne 0 ] || ! grep -q "^match_net_probe: OK" "$tmp/Elsa.log" || grep -q "SCRIPT ERROR" "$tmp/Elsa.log"; then
  echo "✗ cliente Elsa (táctil)"
  fail=1
else
  echo "✓ cliente Elsa (táctil): joystick y botón de verdad"
fi
elsa_moved="$(grep -oE 'Elsa se movió [0-9.]+ m' "$tmp/servidor.log" 2>/dev/null | tail -1 | grep -oE '[0-9.]+')"
if [ -z "$elsa_moved" ] || ! awk -v n="${elsa_moved:-0}" 'BEGIN{exit !(n>3)}'; then
  echo "✗ el joystick táctil no movió de verdad a Elsa en el servidor (${elsa_moved:-nada})"
  fail=1
else
  echo "✓ servidor: el joystick táctil movió de verdad a Elsa ($elsa_moved m)"
fi
# Munición de verdad en el cliente (arreglo del 2026-09-20): el cliente NO descuenta disparos por su
# cuenta, así que la única forma de que su barra baje es que la foto del servidor traiga la munición
# (NetCodec, encabezado). Antes se quedaba llena para siempre: el botón pintaba su ciclo de recarga
# mientras el servidor ya no disparaba nada, sin aviso ni sonido.
ammo_line="$(grep -oE 'munición: [0-9]+ de [0-9]+' "$tmp/Elsa.log" 2>/dev/null | tail -1)"
ammo_min="$(printf '%s' "$ammo_line" | grep -oE '[0-9]+' | head -1)"
ammo_max="$(printf '%s' "$ammo_line" | grep -oE '[0-9]+' | tail -1)"
if [ -z "$ammo_min" ]; then
  echo "✗ Elsa nunca midió su munición (¿nunca llegó a tocar la básica?)"
  fail=1
elif [ "$ammo_min" -ge "$ammo_max" ]; then
  echo "✗ la munición de Elsa se quedó en $ammo_min de $ammo_max: la foto no la trae (HUD mintiendo)"
  fail=1
else
  echo "✓ cliente: la munición bajó a $ammo_min de $ammo_max con la foto del servidor"
fi

if ! grep -q "lanza la ranura" "$tmp/servidor.log"; then
  echo "✗ el servidor nunca confirmó una habilidad lanzada con el dedo (NetServer.on_cast)"
  fail=1
else
  grep "lanza la ranura" "$tmp/servidor.log" | tail -1 | sed 's/^/    servidor: /'
  echo "✓ servidor: la habilidad tocada con el dedo salió de verdad (recarga consumida)"
fi

# La SALIDA de una partida en línea (2026-09-20). Hasta esta fecha main.gd creaba el menú de pausa
# bajo el mismo `net_client == null` que el minimapa: en una partida en red no existía ni el botón ☰
# ni la tecla P, así que un jugador de móvil no tenía NINGUNA forma de salir salvo matar la
# aplicación. Este cliente pulsa "Salir de la partida" de verdad (ui/pause_menu.gd._to_menu) y
# comprueba las tres cosas que tienen que pasar: se suelta la conexión, el cliente deja de tener
# partida y la escena vuelve al menú de inicio.
client Sale --netprobe=match_net_probe --want-mode=1v1 --secs=30 --push-secs=3 --touch --leave-test &
sale=$!
wait "$sale"; cs=$?
grep -E "^\[RED\]|^match_net_probe" "$tmp/Sale.log" | tail -4 | sed 's/^/    Sale: /'
if [ "$cs" -ne 0 ] || ! grep -q "^match_net_probe: OK" "$tmp/Sale.log" || grep -q "SCRIPT ERROR" "$tmp/Sale.log"; then
  echo "✗ cliente Sale: no se pudo salir de la partida en línea desde la pausa"
  fail=1
else
  echo "✓ cliente Sale: ☰ → 'Salir de la partida' suelta la conexión y vuelve al menú"
fi

# Una partida EN LÍNEA de principio a fin (tarea 7). Necesita un servidor propio, con rondas de 6 s:
# el de arriba juega rondas de 150 s y no termina nunca dentro de una prueba. Con seis rondas sin
# ganador la partida se acaba sola (TeamMatch.MAX_ROUNDS), así que no hay que fabricar una muerte.
# Lo que se comprueba es que el CLIENTE se entera de todo: descansos, cambios de ronda, final y
# pantalla de resultados. Antes de esta tarea la partida se acababa solo en el servidor y el jugador
# se quedaba corriendo por un mapa donde ya no pasaba nada.
PORT2="$((PORT + 1))"
if lsof -nP -iTCP:"$PORT2" -sTCP:LISTEN >/dev/null 2>&1; then
  echo "✗ el puerto $PORT2 (partida entera) ya está ocupado"
  fail=1
else
  with_timeout 180 "$GODOT" --headless --path . -- --server --transport=ws --port="$PORT2" --log \
    --rounds=2 --roundtime=6 --identity="$tmp/servidor2.json" >"$tmp/servidor2.log" 2>&1 &
  server2=$!
  listening2() { grep "servidor escuchando en el puerto $PORT2" "$tmp/servidor2.log" 2>/dev/null | grep -qv "ERROR"; }
  for _ in $(seq 1 60); do listening2 && break; sleep 0.5; done
  if ! listening2; then
    echo "✗ el servidor de rondas cortas no arrancó"; tail -10 "$tmp/servidor2.log" | sed 's/^/    /'
    fail=1
  else
    with_timeout 150 "$GODOT" --headless --path . -- --mode=menu --nodecor --client="ws://127.0.0.1:$PORT2" \
      --name=Fin --identity="$tmp/Fin.json" --netprobe=match_net_probe --want-mode=1v1 \
      --secs=110 --push-secs=3 --touch --match-test >"$tmp/Fin.log" 2>&1
    cf=$?
    grep -E "^\[RED\] (la partida pasa a 'over'|partida terminada)|^match_net_probe" "$tmp/Fin.log" | tail -3 | sed 's/^/    Fin: /'
    if [ "$cf" -ne 0 ] || ! grep -q "^match_net_probe: OK" "$tmp/Fin.log" || grep -q "SCRIPT ERROR" "$tmp/Fin.log"; then
      echo "✗ cliente Fin: la partida en línea no termina de cara al jugador"
      grep "problema:" "$tmp/Fin.log" | sed 's/^/    /'
      fail=1
    else
      echo "✓ cliente Fin: descansos, cambios de ronda, final y pantalla de resultados"
    fi
    # Tarea 7: quien se va a mitad deja su leyenda a un bot, y la partida sigue para los demás.
    if ! grep -q "un bot recoge la leyenda" "$tmp/servidor2.log"; then
      echo "✗ nadie recogió la leyenda del jugador que se fue: se queda plantada en medio del mapa"
      fail=1
    else
      grep "un bot recoge la leyenda" "$tmp/servidor2.log" | tail -1 | sed 's/^/    servidor: /'
      echo "✓ servidor: un bot recoge la leyenda de quien se desconecta"
    fi
  fi
  kill_one TERM "${server2:-}"
  server2=""
fi

sleep 5   # el servidor, a solas, tras el 1v1 que dejó el último cliente: no debe reventar ni colgarse
if ! kill -0 "$server" 2>/dev/null; then
  echo "✗ el servidor murió simulando el 1v1 a solas"
  fail=1
elif ! grep -q "\[PARTIDA\] ronda 1" "$tmp/servidor.log"; then
  echo "✗ el servidor no llegó a montar la ronda 1 del 1v1"
  fail=1
elif grep -q "SCRIPT ERROR" "$tmp/servidor.log"; then
  echo "✗ el servidor tuvo errores simulando el 1v1 a solas"
  fail=1
else
  echo "✓ servidor: 1v1 montado y simulando el resto a solas"
fi

# Un servidor que sí pudo escuchar no se cierra solo (net/net.gd solo sale por error de bind): sin
# este "kill_server" explícito aquí, el "wait" se queda colgado hasta que salte la alarma de
# "with_timeout 240" en CADA ejecución que pasa, aunque el guion ya tenga todo lo que necesita.
# "cleanup" (trap EXIT) es solo la red de seguridad para cuando no se llega hasta aquí.
kill_server TERM
wait "$server" 2>/dev/null

for who in "Ana:$ca" "Beto:$cb" "Viejo:$cv"; do
  n="${who%%:*}"; code="${who##*:}"
  grep -E "^\[RED\]|^lobby_probe" "$tmp/$n.log" | tail -4 | sed "s/^/    $n: /"
  if [ "$code" -ne 0 ] || ! grep -q "^lobby_probe: OK" "$tmp/$n.log" || grep -q "SCRIPT ERROR" "$tmp/$n.log"; then
    echo "✗ cliente $n (salida $code)"
    grep -A3 "SCRIPT ERROR" "$tmp/$n.log" | head -20 | sed 's/^/    /'
    fail=1
  else
    echo "✓ cliente $n"
  fi
done
grep -E "^\[RED\]" "$tmp/servidor.log" | tail -8 | sed 's/^/    servidor: /'
if grep -q "SCRIPT ERROR" "$tmp/servidor.log"; then
  echo "✗ servidor con errores"; grep -A3 "SCRIPT ERROR" "$tmp/servidor.log" | head -20 | sed 's/^/    /'; fail=1
fi
exit $fail
