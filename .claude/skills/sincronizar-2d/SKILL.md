---
name: sincronizar-2d
description: Comprueba la deriva entre este juego y el 2D (arena-arpg): copias literales (map_builder.gd, dungeon_gen.gd, iconos táctiles, insignias) y cifras de balance de data/*.tres. Explica cada diferencia y propone qué traer. `/sincronizar-2d` (solo diff), `/sincronizar-2d copiar` (trae las copias literales tras confirmar con el usuario).
allowed-tools: Bash(tools/sync_2d.sh:*), Bash(./tools/sync_2d.sh:*), Bash(diff:*), Bash(cmp:*), Bash(cat:*), Bash(grep:*), Bash(ls:*), Bash(tools/check.sh:*)
---

# Sincronizar con el 2D

Modo: **$ARGUMENTS** (vacío = solo comprobar; `copiar` = traer las copias literales).

1. `tools/sync_2d.sh` y pega la salida. Si no encuentra el 2D, pide la ruta (`ARENA2D=/ruta`).
2. Por cada `✗`, muestra el `diff` (2D → aquí) y explica **qué cambió y qué efecto tiene en el
   3D**: `map_builder.gd` decide el mapa de la semilla 1234 (42×42, 1.302 suelo, 462 bloqueadas,
   6 tumbas); si cambian esas cifras, `tests/test_map.gd` y el README hay que actualizarlos.
3. Balance: si hay `.tres` más nuevos que `main.gd`, lanza `auditor-sincronia-2d` con esos
   ficheros como alcance y resume su tabla.
4. Con `copiar`: **confirma con el usuario** antes de `tools/sync_2d.sh --copy`; después
   `tools/check.sh tests` y pega el resultado.
5. Nunca edites `map_builder.gd` o `dungeon_gen.gd` a mano aquí (el hook lo bloquea): si hace
   falta un cambio, se hace en el 2D.
