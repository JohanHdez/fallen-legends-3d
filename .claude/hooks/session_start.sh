#!/usr/bin/env bash
# SessionStart: resumen del estado del repo al abrir la sesión (stdout pasa al contexto de Claude).
set -u
root="${CLAUDE_PROJECT_DIR:-$(cd "$(dirname "$0")/../.." && pwd)}"
cd "$root" || exit 0
echo "[Fallen Legends 3D · estado al abrir la sesión]"
if command -v godot >/dev/null 2>&1; then
  echo "- Godot: $(godot --version 2>/dev/null | head -1)"
else
  echo "- Godot: NO está en PATH (brew install --cask godot)"
fi
if [ -d .godot/imported ]; then
  echo "- Caché de importación: presente"
else
  echo "- Caché de importación: FALTA → godot --headless --path . --import (primera vez, ~11 s)"
fi
echo "- main.gd: $(wc -l < main.gd | tr -d ' ') líneas (regla: no crece; tope del hook 3000)"
src="${ARENA2D:-$root/../arena-arpg}"
if [ -f "$src/scripts/map_builder.gd" ]; then
  d=0
  cmp -s "$src/scripts/map_builder.gd" map_builder.gd || d=1
  cmp -s "$src/scripts/dungeon_gen.gd" dungeon_gen.gd || d=1
  if [ $d -eq 0 ]; then echo "- Copias del 2D (map_builder/dungeon_gen): idénticas"; else echo "- Copias del 2D: HAY DERIVA → tools/sync_2d.sh"; fi
else
  echo "- Juego 2D no encontrado en $src (exporta ARENA2D=/ruta): deriva sin comprobar"
fi
name="$(git config user.name 2>/dev/null)"; mail="$(git config user.email 2>/dev/null)"
if [ "$name" = "JohanHdez" ]; then
  echo "- Git: $name <$mail> ✓ · rama $(git branch --show-current 2>/dev/null) · $(git status --porcelain 2>/dev/null | wc -l | tr -d ' ') cambio(s) sin commit"
else
  echo "- Git: identidad INCORRECTA ($name <$mail>); debe ser JohanHdez (CLAUDE.md § Git)"
fi
echo "- Comandos: /director <tarea> · /auditoria [alcance] · /verificar · /exportar <destino> · /sincronizar-2d"
exit 0
