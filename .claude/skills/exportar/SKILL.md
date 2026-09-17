---
name: exportar
description: Exporta el juego con comprobaciones previas (puerta de calidad, versión, licencias) usando tools/build.sh. Solo lo lanza el usuario. `/exportar android` (APK de depuración), `/exportar android-release` (APK firmado; necesita las variables del keystore), `/exportar web`.
disable-model-invocation: true
allowed-tools: Bash(tools/check.sh:*), Bash(tools/build.sh:*), Bash(ls:*), Bash(du:*), Bash(git status:*), Bash(grep:*), Bash(godot --version)
---

# Exportar

Destino: **$ARGUMENTS** (`android` | `android-release` | `web`; vacío = pregunta).

## Antes de exportar (no te lo saltes)
1. `tools/check.sh` completo. Si `FALLO`, para y explica; no se exporta lo que no parsea.
2. `git status --short`: informa de cambios sin commit (no bloquea, pero el usuario debe saberlo).
3. `grep -E '^version/(code|name)=' export_presets.cfg`: muestra la versión. Para
   `android-release` pregunta si hay que subir `version/code` (Play exige uno mayor en cada
   subida) y recuerda que `package/unique_name` es permanente.
4. Licencias: recuerda en una línea que el repo debe seguir privado (QAL de Bestiary) y que la
   atribución CC-BY-SA de p0ss debe estar visible para el jugador. Si hace tiempo que no corre,
   sugiere `/auditoria seguridad`.
5. Requisitos por destino: `docs/DESPLIEGUE.md` § Exportar. Para `android-release`, las variables
   `GODOT_ANDROID_KEYSTORE_RELEASE_PATH/_USER/_PASSWORD` tienen que estar definidas en la shell
   del usuario (nunca las pidas ni las escribas en ficheros del repo).

## Exportar
- `tools/build.sh $ARGUMENTS` y pega la salida.

## Después
- Tamaños (`ls -lh export/`, `du -sh export/web`) y si crecieron respecto a la referencia
  (APK ≈ 130 MB, web ≈ 80 MB).
- Android: cómo instalar: `~/Library/Android/sdk/platform-tools/adb install -r export/proto3d.apk`.
- Web: `python3 -m http.server -d export/web 8060` para probar; hosting estático para publicar
  (Vercel está conectado por MCP; ver `docs/DESPLIEGUE.md`).
- Recuerda que `export/` está en `.gitignore`: no se sube al repo.
