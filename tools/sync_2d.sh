#!/usr/bin/env bash
# Comprueba que lo que este juego COPIA del 2D (Fallen Legends, repo arena-arpg) no ha derivado.
# No sincroniza nada por su cuenta:
#   tools/sync_2d.sh          # diff de map_builder.gd, dungeon_gen.gd e iconos táctiles; avisa si el
#                             # balance (data/abilities, data/classes) cambió después que main.gd
#   tools/sync_2d.sh --copy   # copia del 2D a aquí las copias literales (tras revisar el diff)
# El repo 2D se busca en $ARENA2D o en ../arena-arpg. Código de salida 1 si hay deriva.
set -uo pipefail
cd "$(dirname "$0")/.."
SRC="${ARENA2D:-../arena-arpg}"
if [ ! -f "$SRC/project.godot" ]; then
  echo "No encuentro el juego 2D en '$SRC'. Exporta ARENA2D=/ruta/arena-arpg." >&2
  exit 1
fi
copy=0; [ "${1:-}" = "--copy" ] && copy=1
drift=0

# Copias literales: origen en el 2D -> destino aquí.
PAIRS=(
  "scripts/map_builder.gd:map_builder.gd"
  "scripts/dungeon_gen.gd:dungeon_gen.gd"
)
for svg in "$SRC"/assets/ui/touch/*.svg; do
  [ -f "$svg" ] || continue
  PAIRS+=("assets/ui/touch/$(basename "$svg"):assets/ui/touch/$(basename "$svg")")
done
for png in "$SRC"/assets/ui/kill_rewards/*.png; do
  [ -f "$png" ] || continue
  PAIRS+=("assets/ui/kill_rewards/$(basename "$png"):assets/ui/kill_rewards/$(basename "$png")")
done

echo "== Copias literales del 2D ($SRC)"
for pair in "${PAIRS[@]}"; do
  from="$SRC/${pair%%:*}"; to="${pair##*:}"
  if [ ! -f "$from" ]; then echo "?  $to (no existe en el 2D: ${pair%%:*})"; continue; fi
  if [ ! -f "$to" ]; then echo "?  $to (no existe aquí)"; continue; fi
  if cmp -s "$from" "$to"; then
    echo "✓ $to"
  else
    echo "✗ $to DIFIERE del 2D ($(diff "$from" "$to" | grep -c '^[<>]') líneas)"
    drift=1
    if [ $copy -eq 1 ]; then cp "$from" "$to" && echo "   copiado desde el 2D"; fi
  fi
done

echo "== Balance: cifras de data/*.tres del 2D frente a main.gd"
newer=0
for f in "$SRC"/data/abilities/*.tres "$SRC"/data/classes/*.tres; do
  [ -f "$f" ] || continue
  if [ "$f" -nt main.gd ]; then echo "   más nuevo que main.gd: ${f#$SRC/}"; newer=$((newer+1)); fi
done
if [ $newer -gt 0 ]; then
  echo "   $newer fichero(s) de balance cambiaron después de main.gd: revisa ABILITIES/LEGENDS/SPECIES."
  echo "   (Desviaciones a propósito: README § Rompemareas y comentarios junto a cada cifra.)"
else
  echo "   ninguno más nuevo que main.gd"
fi

if [ $drift -ne 0 ] && [ $copy -eq 0 ]; then
  echo "RESULTADO: DERIVA (revisa el diff; tools/sync_2d.sh --copy trae la versión del 2D)"
  exit 1
fi
echo "RESULTADO: OK"
