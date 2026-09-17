---
name: auditoria
description: Lanza en paralelo los auditores del proyecto (calidad, rendimiento, seguridad y licencias, sincronía con el 2D, despliegue) sobre un alcance y consolida un informe priorizado sin tocar código. `/auditoria` (todo), `/auditoria diff` (solo cambios sin commit), `/auditoria main.gd` o una función, `/auditoria seguridad|rendimiento|calidad|sincronia|despliegue` (uno solo).
---

# Auditoría coordinada

Alcance pedido: **$ARGUMENTS** (vacío = proyecto entero).

## 1. Fija el alcance
- `diff` → `git diff` + `git diff --cached` (si está vacío, dilo y para).
- Un fichero, función o rango → ese alcance para todos.
- Nombre de un auditor (`seguridad`, `rendimiento`, `calidad`, `sincronia`, `despliegue`) →
  solo ese.
- Vacío → proyecto entero, con `main.gd` por secciones (CLAUDE.md § Arquitectura → mapa de
  `main.gd`) para que ningún auditor se quede sin contexto.

## 2. Lanza los auditores en paralelo (un mensaje, varias llamadas a Agent)
- `auditor-calidad`, `auditor-rendimiento`, `auditor-seguridad-licencias`,
  `auditor-sincronia-2d`, `auditor-despliegue`.
- A cada uno: el alcance exacto, qué ya sabes (para que no lo repitan) y "usa tu formato de
  salida". No trabajes sobre los mismos ficheros mientras corren.

## 3. Consolida
- Junta los hallazgos, **quita duplicados** (el mismo `fichero:línea` visto por dos auditores es
  un hallazgo con dos ángulos) y ordena por severidad: Bloqueante > Alta > Media > Baja.
- Verifica tú cualquier hallazgo Bloqueante o Alta leyendo el código antes de publicarlo.

## 4. Informe (en español)
```
# Auditoría — <alcance> — <fecha>
Comprobaciones corridas: <lista corta con resultado>

## Bloqueantes
## Altas
## Medias
## Bajas
(cada una: título · dónde (fichero:línea) · evidencia · propuesta · esfuerzo estimado)

## Lo que está bien
## Qué haría primero (3 pasos)
```
No arregles nada por tu cuenta: propón y, si el usuario dice "arréglalo", pasa por `/director`.
