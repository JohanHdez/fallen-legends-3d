#!/usr/bin/env bash
# Puerta de calidad de Fallen Legends 3D. La corren los hooks de Claude Code, /verificar y
# cualquiera antes de dar por terminada una tarea:
#   tools/check.sh                 # todo: parseo de scripts + pruebas puras + humo headless
#   tools/check.sh parse           # solo parseo (godot --check-only, ~1 s por script)
#   tools/check.sh parse main.gd   # parseo de uno o varios scripts concretos
#   tools/check.sh tests           # solo pruebas de lógica pura (tests/test_*.gd)
#   tools/check.sh smoke           # solo humo headless (40 fotogramas, sin ventana)
#   tools/check.sh probes          # solo sondas de partida (tests/*_probe.gd con --fixed-fps 60)
#   tools/check.sh net             # solo la sala en línea (servidor y clientes, tools/net_check.sh)
# Código de salida 1 si algo falla. El ruido del renderizador dummy al salir ("leaked at exit",
# "Pages in use", "resources still in use", "Leaked instance dependency") y el ERROR conocido de `--shot` en headless
# (`Parameter "t" is null`, README § Trampa del --shot) NO cuentan como fallo.
set -uo pipefail
cd "$(dirname "$0")/.."
GODOT="${GODOT:-godot}"
if ! command -v "$GODOT" >/dev/null 2>&1; then
  echo "No encuentro Godot ('$GODOT'). brew install --cask godot, o exporta GODOT=/ruta/godot." >&2
  exit 1
fi
# Siempre se refresca la caché de clases (class_name nuevas) antes de parsear: sin ella, un script
# que usa una clase recién creada da "Could not find type". Límite de tiempo: el import a veces no
# sale solo en macOS.
echo "== Refrescando la caché de clases e importaciones (godot --import)"
perl -e 'alarm 180; exec @ARGV' "$GODOT" --headless --path . --import >/dev/null 2>&1 || true
NOISE='leaked at exit|resources still in use at exit|Pages in use exist at exit|Leaked instance dependency|instance_notify_deleted|^[[:space:]]*$|^Godot Engine v'
KNOWN='Parameter "t" is null|texture_2d_get|GDScript backtrace|\[0\] _process \(res://main.gd'
fail=0

# macOS no trae `timeout`: perl hace de límite de tiempo (como en el juego 2D).
with_timeout() { perl -e 'alarm shift; exec @ARGV' "$@"; }

parse_one() {
  local f="$1" out
  out="$(with_timeout 60 "$GODOT" --headless --path . --script "res://$f" --check-only 2>&1 | grep -vE "$NOISE" || true)"
  if echo "$out" | grep -qE 'SCRIPT ERROR|Parse Error|Failed to load script'; then
    echo "✗ $f"; echo "$out" | sed 's/^/    /'; return 1
  fi
  echo "✓ $f"
}

do_parse() {
  local files=("$@")
  if [ ${#files[@]} -eq 0 ]; then
    while IFS= read -r f; do files+=("$f"); done < <(find . -name '*.gd' -not -path './.godot/*' -not -path './export/*' | sed 's|^\./||' | sort)
  fi
  echo "== Parseo (godot --check-only) de ${#files[@]} script(s)"
  for f in "${files[@]}"; do parse_one "$f" || fail=1; done
}

do_tests() {
  echo "== Pruebas de lógica pura (tests/test_*.gd)"
  local any=0 log code
  for t in tests/test_*.gd; do
    [ -f "$t" ] || continue
    any=1
    log="$(mktemp)"
    with_timeout 240 "$GODOT" --headless --path . -s "res://$t" >"$log" 2>&1
    code=$?
    grep -vE "$NOISE" "$log" | grep -E 'FALLO|AVISO|SCRIPT ERROR|^test_' | sed 's/^/    /'
    if [ $code -ne 0 ] || grep -qE 'SCRIPT ERROR|^FALLO' "$log"; then
      echo "✗ $t (salida $code)"; fail=1
    else
      echo "✓ $t"
    fi
    rm -f "$log"
  done
  [ $any -eq 1 ] || echo "   (no hay pruebas)"
}

do_smoke() {
  echo "== Humo headless: 40 fotogramas, sin decoración ni gas, 6 criaturas a 5 celdas"
  local log code shot
  log="$(mktemp)"; shot="$(mktemp -u).png"
  with_timeout 240 "$GODOT" --headless --path . -- --shot="$shot" --wait=40 --nodecor --nozone --near=5 --zombies=6 --log >"$log" 2>&1
  code=$?
  rm -f "$shot"
  grep -E 'mapa |construido en|horda lista|fotogramas' "$log" | sed 's/^/    /'
  local errors
  errors="$(grep -E '^(SCRIPT ERROR|ERROR):' "$log" | grep -vE "$NOISE" | grep -vE "$KNOWN" || true)"
  if [ $code -ne 0 ] || ! grep -q 'construido en' "$log" || ! grep -q 'fotogramas' "$log" || [ -n "$errors" ]; then
    echo "✗ humo (salida $code)"
    [ -n "$errors" ] && echo "$errors" | sed 's/^/    /'
    grep -A3 'SCRIPT ERROR' "$log" | sed 's/^/    /' | head -40
    fail=1
  else
    echo "✓ humo"
  fi
  rm -f "$log"
}

# Sondas: enganchadas a la partida con --probe=nombre. Cada una sale con 0 (bien) o 1 (fallo).
PROBES=(
  "rocks_probe --secs=30"
  "hud_keys_probe --mode=2v2 --autoplay --touch --secs=12"
  "hud_keys_probe --mode=2v2 --autoplay --secs=12"
  "seed_map_probe --seed=4242 --touch"
  "seed_map_probe --seed=4242 --mode=2v2"
  "seed_map_probe --seed=31337 --mode=4v4"
  "match_probe --mode=1v1 --autoplay --secs=600"
  "match_probe --mode=4v4 --autoplay --secs=600"
  "decoy_probe --mode=2v2 --legend=2 --autoplay --secs=400"
  "decoy_probe --mode=2v2 --legend=2 --autoplay --down-decoys --secs=90"
  "minimap_probe --mode=2v2 --autoplay --touch --secs=60"
  "minimap_probe --team=2 --autoplay --near=8 --zombies=20 --secs=45"
  "horde_probe --team=4 --autoplay --down-one=20 --secs=120"
  "horde_probe --team=1 --autoplay --down-player=15 --expect-defeat --secs=40"
  "horde_probe --team=4 --wave=5 --autoplay --near=6 --secs=90"
  "boss_probe --team=4 --autoplay --near=4 --zombies=0 --boss --secs=120"
  "senses_probe --team=2 --autoplay --near=8 --zombies=20 --secs=90"
  "senses_probe --team=1 --near=6 --zombies=14 --nozone --hide --secs=60"
  "minion_probe --legend=5 --nozone --zombies=0"
)
do_probes() {
  echo "== Sondas de partida (headless, --fixed-fps 60)"
  local log code spec name
  for spec in "${PROBES[@]}"; do
    name="${spec%% *}"
    log="$(mktemp)"
    # shellcheck disable=SC2086
    with_timeout 300 "$GODOT" --headless --fixed-fps 60 --path . -- --probe=$spec >"$log" 2>&1
    code=$?
    grep -E "^\[|^${name}:" "$log" | grep -vE '^\[(HORDA|BENCH|ANIM)\]' | tail -4 | sed 's/^/    /'
    if [ $code -ne 0 ] || grep -q 'SCRIPT ERROR' "$log" || ! grep -q "^${name}: OK" "$log"; then
      echo "✗ $name (salida $code)"
      grep -A3 'SCRIPT ERROR' "$log" | sed 's/^/    /' | head -20
      fail=1
    else
      echo "✓ $name"
    fi
    rm -f "$log"
  done
}

do_net() {
  echo "== Red: la sala en línea (servidor y clientes sin pantalla, tools/net_check.sh)"
  tools/net_check.sh || fail=1
}

case "${1:-all}" in
  parse) shift; do_parse "$@" ;;
  tests) do_tests ;;
  smoke) do_smoke ;;
  probes) do_probes ;;
  net) do_net ;;
  all)   do_parse; do_tests; do_smoke; do_probes; do_net ;;
  *) echo "Uso: $0 [all|parse [script...]|tests|smoke|probes|net]" >&2; exit 2 ;;
esac
if [ $fail -ne 0 ]; then echo "RESULTADO: FALLO"; exit 1; fi
echo "RESULTADO: OK"
