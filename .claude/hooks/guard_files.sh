#!/usr/bin/env bash
# PreToolUse (Edit|Write|MultiEdit): protege ficheros que no deben editarse en este repo.
# Salida 2 = bloquea la herramienta y le explica a Claude por qué (stderr). Salida 0 = deja pasar.
set -u
input="$(cat)"
file="$(printf '%s' "$input" | python3 -c 'import json,sys
try:
    d = json.load(sys.stdin); print(d.get("tool_input", {}).get("file_path", "") or "")
except Exception:
    print("")')"
[ -n "$file" ] || exit 0
root="${CLAUDE_PROJECT_DIR:-$(cd "$(dirname "$0")/../.." && pwd)}"
case "$file" in
  "$root"/*) rel="${file#"$root"/}" ;;
  /*) exit 0 ;;          # fuera del proyecto: no es asunto de este hook
  *) rel="$file" ;;
esac
base="$(basename "$rel")"
if [ "$base" = "map_builder.gd" ] || [ "$base" = "dungeon_gen.gd" ]; then
  cat >&2 <<MSG
BLOQUEADO: $rel es una COPIA LITERAL del juego 2D (arena-arpg/scripts/$base). Editarla aquí crea
deriva silenciosa entre los dos juegos (CLAUDE.md § Reglas, punto 4). Haz el cambio en el 2D y
tráelo con:  tools/sync_2d.sh --copy
Si la divergencia es deliberada, explícaselo al usuario: que la edite él o desactive este hook en
.claude/settings.json (PreToolUse → guard_files.sh).
MSG
  exit 2
fi
case "$rel" in
  .godot/*|export/*|*.import)
    echo "BLOQUEADO: $rel es caché de importación o binario exportado (se regenera y está en .gitignore). No se edita a mano." >&2
    exit 2 ;;
esac
exit 0
