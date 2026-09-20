#!/usr/bin/env bash
# Prueba de la sala en línea con varios procesos (fase 1 del juego en línea,
# docs/superpowers/specs/2026-09-18-juego-en-linea-design.md): un servidor sin pantalla por
# WebSocket y dos clientes sin pantalla que entran por el menú, eligen, se ponen listos y el líder
# inicia un 3v3; y un tercer cliente con otra versión del protocolo, que el servidor tiene que echar.
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
kill_server() {  # señal (TERM o KILL)
  [ -n "${server:-}" ] || return 0
  pkill -"$1" -P "$server" 2>/dev/null
  kill -"$1" "$server" 2>/dev/null
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

with_timeout 240 "$GODOT" --headless --path . -- --server --transport=ws --port="$PORT" \
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
client Beto --want-mode=3v3 --want-legend=3 --want-team=2 &
beto=$!
wait "$ana"; ca=$?
wait "$beto"; cb=$?
client Viejo --protocol=99 --expect-kick
cv=$?
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
