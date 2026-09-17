#!/usr/bin/env bash
# PostToolUse (Edit|Write|MultiEdit): tras editar un .gd lo parsea con Godot (--check-only, ~1 s;
# si aparece una clase nueva, refresca la caché de clases y repite).
# Si hay errores de parseo los devuelve a Claude (salida 2 + stderr) para que los arregle en el acto.
# También avisa si main.gd supera el tope de líneas (regla: el monolito no crece; CLAUDE.md § Deuda).
set -u
MAIN_MAX=3000
input="$(cat)"
file="$(printf '%s' "$input" | python3 -c 'import json,sys
try:
    d = json.load(sys.stdin); print(d.get("tool_input", {}).get("file_path", "") or "")
except Exception:
    print("")')"
case "$file" in *.gd) ;; *) exit 0 ;; esac
root="${CLAUDE_PROJECT_DIR:-$(cd "$(dirname "$0")/../.." && pwd)}"
case "$file" in
  "$root"/*) rel="${file#"$root"/}" ;;
  /*) exit 0 ;;
  *) rel="$file" ;;
esac
[ -f "$root/$rel" ] || exit 0
command -v godot >/dev/null 2>&1 || exit 0
NOISE='leaked at exit|resources still in use at exit|Pages in use exist at exit|Leaked instance dependency|instance_notify_deleted|^[[:space:]]*$|^Godot Engine v'
out="$(cd "$root" && perl -e 'alarm 60; exec @ARGV' godot --headless --path . --script "res://$rel" --check-only 2>&1 | grep -vE "$NOISE" || true)"
# Una clase nueva (class_name) no existe para Godot hasta que se refresca la caché de clases: si el
# error huele a eso, se importa una vez y se repite antes de dar el fallo por bueno.
if printf '%s' "$out" | grep -qE 'Could not find type|not declared in the current scope|Could not resolve'; then
  (cd "$root" && perl -e 'alarm 120; exec @ARGV' godot --headless --path . --import >/dev/null 2>&1 || true)
  out="$(cd "$root" && perl -e 'alarm 60; exec @ARGV' godot --headless --path . --script "res://$rel" --check-only 2>&1 | grep -vE "$NOISE" || true)"
fi
if printf '%s' "$out" | grep -qE 'SCRIPT ERROR|Parse Error|Failed to load script'; then
  {
    echo "Godot NO parsea $rel tras la edición:"
    printf '%s\n' "$out"
    echo "Arréglalo antes de seguir (tools/check.sh parse $rel para repetir la comprobación)."
  } >&2
  exit 2
fi
if [ "$rel" = "main.gd" ]; then
  n="$(wc -l < "$root/main.gd" | tr -d ' ')"
  if [ "$n" -gt "$MAIN_MAX" ]; then
    echo "AVISO: main.gd tiene $n líneas (tope $MAIN_MAX). La regla es que el monolito no crezca: extrae el sistema que estás tocando a su propio script (CLAUDE.md § Deuda y trampas conocidas → módulos propuestos). El tope se ajusta en .claude/hooks/check_gd.sh (MAIN_MAX)." >&2
    exit 2
  fi
fi
exit 0
