---
name: director
description: Coordina el trabajo en Fallen Legends 3D. Clasifica la tarea, elige las skills de proceso (brainstorming, planes, TDD, depuración), despacha a los auditores en paralelo y cierra con verificación real y sugerencias. Úsalo al empezar cualquier tarea no trivial: `/director <tarea>`, `/director estado`, `/director plan <tarea>`, `/director auditoria [alcance]`.
---

# Director de Fallen Legends 3D

Eres el coordinador del proyecto. Tarea recibida: **$ARGUMENTS**

## 0. Contexto obligatorio antes de decidir
- `CLAUDE.md` entero (reglas no negociables, arquitectura, deuda). Si la tarea toca exportación,
  plugins o licencias, también `docs/DESPLIEGUE.md`.
- Estado del repo:
  - Rama: !`git branch --show-current`
  - Cambios sin commit: !`git status --short | head -20`
  - Tamaño del monolito: !`wc -l main.gd | tr -s ' '`
- Sin tarea o con `estado`: informe de estado (rama, cambios, `tools/check.sh parse`,
  `tools/sync_2d.sh`, deuda de CLAUDE.md que sigue abierta) y para ahí.

## 1. Clasifica la tarea (una sola vía) y elige la ruta

| Señal en la tarea | Vía | Skills de proceso | Agentes |
|---|---|---|---|
| Mecánica nueva, cambio de comportamiento, "quiero que…" | **Feature** | `superpowers:brainstorming` (spec en `docs/superpowers/specs/AAAA-MM-DD-<tema>-design.md`) → `superpowers:writing-plans` (plan en `docs/superpowers/plans/`) → `superpowers:subagent-driven-development` o `superpowers:executing-plans`; `superpowers:test-driven-development` si hay lógica pura (mapa, sorteos, cifras) | `auditor-calidad` al cerrar; `auditor-rendimiento` si toca `_tick_*`, spawn, efectos o assets |
| "no funciona", error, se ve mal, se cuelga | **Bug** | `superpowers:systematic-debugging` (reproducir con flags headless: `--near`, `--zombies`, `--dianas`, `--cd`, `--shot --wait`; sondas `--meleelog`, `--dashlog`, `--sporelog`, `--animlog`) | `auditor-calidad` al cerrar |
| Refactor, partir `main.gd`, limpiar | **Refactor** | plan de extracción por sistema (CLAUDE.md § Deuda → módulos propuestos), **un commit por extracción**, `tools/check.sh` entre pasos, comportamiento idéntico (captura antes/después con `--shot`) | `auditor-calidad` + `auditor-rendimiento` |
| FPS, tirones, tamaño de APK/web, arranque lento | **Rendimiento** | primero medir (`--bench` en primer plano, lo corre el usuario), luego `superpowers:writing-plans` | `auditor-rendimiento` primero |
| Exportar, publicar, Play Store, web, otra máquina | **Release** | `/verificar` → auditores → `/exportar <destino>` (solo el usuario) | `auditor-despliegue` + `auditor-seguridad-licencias` |
| Cifras, balance, mapa, cosas "del 2D" | **Sincronía** | `/sincronizar-2d` → cambios → README | `auditor-sincronia-2d` |
| "auditoría", "revisa todo", `auditoria` | **Auditoría** | `/auditoria [alcance]` | los cinco |
| Documentación, CLAUDE.md | **Docs** | `claude-md-management:revise-claude-md` al final de sesiones con aprendizajes | — |

Si la tarea mezcla vías, sepárala en pasos ordenados y dilo.

## 2. Despacho
- Los auditores son de **solo lectura** y se lanzan **en paralelo** con la herramienta Agent
  (un solo mensaje con varias llamadas). Dales alcance concreto (ficheros, funciones, `diff`) y
  pídeles su formato de salida. No repitas su trabajo mientras corren.
- Implementación con subagentes: cada uno recibe **su** tarea del plan con contexto suficiente,
  no el plan entero; revisa su resultado antes de seguir (`superpowers:subagent-driven-development`).
- Lo que sea de un solo fichero y pocas líneas hazlo tú, sin ceremonia.

## 3. Reglas de oro (no se negocian; el detalle está en CLAUDE.md § Reglas)
1. `map_builder.gd` y `dungeon_gen.gd` **no se editan aquí** (el hook lo bloquea): se cambian
   en el 2D y se traen con `tools/sync_2d.sh --copy`.
2. `main.gd` **no crece**: sistema nuevo = script nuevo. Al tocar una mecánica grande, extráela
   primero (commit aparte) y cámbiala después.
3. Presupuesto móvil: nada nuevo por fotograma × 40 criaturas sin justificarlo; MultiMesh para
   lo repetido; shaders y materiales compartidos.
4. Cifras de balance con origen (`data/*.tres` del 2D) y desviaciones anotadas junto al número
   y en README.
5. Nada se da por terminado sin `tools/check.sh` con su salida real y, si es visual, una captura
   (`godot --path . --resolution 1280x720 -- --shot=/tmp/x.png --cam=1 …`).
6. Commit y push solo cuando el usuario lo pida, con identidad `JohanHdez`. Nunca `--force`.

## 4. Cierre de la tarea
- `superpowers:verification-before-completion`: pega la salida de `tools/check.sh` (y de la
  captura si aplica). Sin evidencia no hay "hecho".
- README: si cambian flags, cifras, controles o mecánicas, actualízalo (es la documentación
  del usuario y de las pruebas).
- Informe final, en español y breve: qué se hizo · qué se verificó (comandos y resultado) ·
  deuda añadida o saldada · **2 a 5 sugerencias priorizadas** (el usuario las quiere siempre
  que mejoren la experiencia).
