---
name: verificar
description: Corre la puerta de calidad tools/check.sh (parseo de todos los .gd con Godot, pruebas de lógica pura, humo headless de 40 fotogramas) e interpreta el resultado. Úsalo antes de dar por terminada cualquier tarea y antes de exportar. `/verificar`, `/verificar parse [fichero]`, `/verificar tests`, `/verificar smoke`.
allowed-tools: Bash(tools/check.sh:*), Bash(./tools/check.sh:*), Bash(godot --headless:*)
---

# Verificar

Modo pedido: **$ARGUMENTS** (vacío = `all`).

1. Corre exactamente: `tools/check.sh $ARGUMENTS` y pega la salida íntegra (recortando solo el
   ruido repetido del renderizador dummy si lo hubiera).
2. Interpreta:
   - `✗` en **parseo** → error de GDScript: fichero y línea están en la salida; arréglalo y repite
     `tools/check.sh parse <fichero>`.
   - `✗` en **tests** → o cambió `map_builder.gd` (deriva con el 2D: `tools/sync_2d.sh`) o cambió
     `MAP_SEED`, o la prueba nueva está mal. Los `AVISO` de `test_map` son deuda conocida
     (índices transpuestos, CLAUDE.md § Deuda) y no bloquean.
   - `✗` en **humo** → el juego no completa `_ready` o hay `SCRIPT ERROR` en los primeros
     fotogramas: reproduce con
     `godot --headless --path . -- --shot=/tmp/x.png --wait=40 --nodecor --nozone --near=5 --zombies=6 --log`
     y lee la traza. El `ERROR: Parameter "t" is null` de `--shot` en headless es conocido y
     está filtrado.
3. Si el cambio es visual, recuerda que el humo no lo cubre: pide o toma una captura con
   ventana, p. ej. `godot --path . --resolution 1280x720 -- --shot=/tmp/a.png --cam=1 --yaw=35 --pitch=-48 --dist=17`.
4. Termina con una línea: `RESULTADO: OK` o `RESULTADO: FALLO — <qué y dónde>`. Nunca digas
   "pasa" sin haber pegado la salida.
