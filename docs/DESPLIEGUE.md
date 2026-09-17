# Despliegue, herramientas y complementos de terceros

Todo lo que hace falta para **construir, exportar y publicar** Fallen Legends 3D y para que
Claude Code trabaje igual en otra máquina. Lo audita `auditor-despliegue`; lo ejecuta
`tools/build.sh` (`/exportar`). Actualizado el 2026-09-16.

## 1. Cadena de herramientas (estado en el Mac del autor)

| Pieza | Dónde está | Cómo se instala en una máquina nueva |
|---|---|---|
| Godot 4.7.2 stable (editor + CLI `godot`) | `/Applications/Godot.app`, `/usr/local/bin/godot` | `brew install --cask godot` (o el zip de godotengine.org; enlaza `Godot.app/Contents/MacOS/Godot` como `godot` en el PATH) |
| Plantillas de exportación 4.7.2 | `~/Library/Application Support/Godot/export_templates/4.7.2.stable/` | Editor → Editor → Administrar plantillas de exportación → Descargar, o el `.tpz` de https://github.com/godotengine/godot/releases/tag/4.7.2-stable (es un zip: copiar su `templates/` a esa ruta). **La versión debe coincidir con el binario.** |
| JDK 17 | `~/Library/Java/jdk-17` | `brew install --cask temurin@17` y enlazar o copiar; Godot lo lee de `editor_settings-4.tres` → `export/android/java_sdk_path` (`.../jdk-17/Contents/Home`) |
| Android SDK (platform-tools, build-tools, platforms, cmdline-tools) | `~/Library/Android/sdk` | Android Studio → SDK Manager, o `cmdline-tools` + `sdkmanager "platform-tools" "build-tools;34.0.0" "platforms;android-34"`; ruta en `editor_settings-4.tres` → `export/android/android_sdk_path` |
| Keystore de depuración | `~/Library/Application Support/Godot/keystores/debug.keystore` (contraseña `android`) | Godot lo genera; ruta en `editor_settings-4.tres` → `export/android/debug_keystore` |
| Keystore de **release** | **No existe todavía.** Debe vivir fuera del repo (p. ej. `~/Library/Application Support/Godot/keystores/fallen-legends-3d-release.keystore`) | `keytool -genkeypair -v -keystore <ruta> -alias fl3d -keyalg RSA -keysize 2048 -validity 10000` (el `keytool` del JDK 17). **Guardar copia y contraseña fuera del Mac**: sin él no se puede actualizar la app en Play. |
| `perl` (límite de tiempo en scripts; macOS no trae `timeout`) | sistema | — |
| `python3` (los hooks parsean JSON con él; no hay `jq`) | sistema | — |
| `gh` (CLI de GitHub) | `/usr/local/bin/gh`, **sin sesión iniciada** | `gh auth login` si se quieren PR/issues desde Claude Code |

Comprobación rápida de todo: `/director estado` o los primeros puntos de `auditor-despliegue`.

## 2. Exportar

Siempre antes: `tools/check.sh` (parseo + pruebas + humo). La primera vez en una máquina:
`godot --headless --path . --import` (parsea los glTF; sin caché el arranque tarda ~11 s y la
exportación puede fallar).

| Destino | Comando | Salida | Notas |
|---|---|---|---|
| Android, APK de depuración | `tools/build.sh android` | `export/proto3d.apk` (≈130 MB) | Preset "Android": solo `arm64-v8a`, sin Gradle, `internet=false`, firmado con la clave de depuración. Instalar: `~/Library/Android/sdk/platform-tools/adb install -r export/proto3d.apk`. |
| Android, APK de **release** | `GODOT_ANDROID_KEYSTORE_RELEASE_PATH=… GODOT_ANDROID_KEYSTORE_RELEASE_USER=… GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD=… tools/build.sh android-release` | `export/proto3d-release.apk` | Godot lee esas variables cuando el preset no trae keystore (documentado en "Exporting for Android"). Antes: subir `version/code` (entero, siempre mayor) y `version/name` en `export_presets.cfg`. Para Play Store conviene **AAB**: cambiar `gradle_build/export_format=1` exige `use_gradle_build=true` y el Android build template (Editor → Proyecto → Instalar plantilla de compilación de Android). |
| Web | `tools/build.sh web` | `export/web/index.html` + `index.wasm` (38 MB) + `index.pck` (42 MB); zip en `export/fallen-legends-3d-web.zip` | `thread_support=false` y `extensions_support=false`: **no hacen falta cabeceras COOP/COEP**, cualquier hosting estático vale (Vercel está conectado por MCP; GitHub Pages no sirve en un repo privado del plan gratuito). Probar en local: `python3 -m http.server -d export/web 8060`. El `.pck` de 42 MB es por los modelos: si el peso importa, `vram_texture_compression/for_mobile` ya está activo; quitar del preset los modelos que no se usan es la palanca grande. |

`export/` está en `.gitignore`. Los presets viven en `export_presets.cfg` (sí se versiona;
**nunca** rellenar en él `keystore/release*`).

### Identificadores permanentes
- Android `package/unique_name` = **`com.fallenlegends.proto3d`**, nombre "FL Proto 3D".
  **Decidido (2026-09-16): se mantiene.** El juego 2D no se publicará en Android, así que no hay
  conflicto de identificadores. En Google Play no se puede cambiar después de publicar: no tocarlo.
- `launcher_icons/*` están vacíos: sale el icono de Godot. Antes de publicar, PNG 192×192 y
  adaptativos 432×432.

## 3. Lista antes de publicar

1. `tools/check.sh` → `RESULTADO: OK`.
2. `/auditoria seguridad` y `/auditoria despliegue` sin bloqueantes.
3. Repositorio **privado** (Bestiary va con la QAL: no se pueden redistribuir los modelos).
4. Atribución **CC-BY-SA 3.0** de p0ss (sonidos de conjuro) visible para el jugador: pantalla de
   créditos o ficha de la tienda, con enlace a https://opengameart.org/content/spell-sounds-starter-pack.
   `assets/CREDITS.txt` viaja en el paquete (el preset solo excluye `*.md`).
5. `version/code` y `version/name` subidos; APK/AAB firmado con el keystore de release.
6. README actualizado (controles, flags, cifras) y captura reciente para la ficha
   (`godot --path . --resolution 1280x720 -- --shot=/tmp/a.png --cam=1 --yaw=35 --pitch=-48 --dist=17`).

## 4. Complementos de Claude Code instalados (para reproducir el entorno)

Marketplace: `claude-plugins-official` (GitHub `anthropics/claude-plugins-official`). Los plugins
están instalados a nivel de **usuario** (`~/.claude/plugins/installed_plugins.json`); el
`.claude/settings.json` del repo los declara en `enabledPlugins` (y el marketplace en
`extraKnownMarketplaces`) para que otra máquina sepa cuáles activar. Instalación manual:
`claude plugin install <nombre>@claude-plugins-official` o `/plugin install …` en sesión.

| Plugin | Versión (2026-09-16) | Para qué sirve aquí | ¿Necesario? |
|---|---|---|---|
| `superpowers` | 6.3.0 | Flujo de trabajo: brainstorming → spec → plan → ejecución con subagentes, TDD, depuración sistemática, worktrees, verificación antes de terminar. `/director` lo usa. | **Sí** |
| `code-review` | b1aabc22ac99 | `/code-review` del diff o de un PR; `ultra` lanza revisión multiagente en la nube (la lanza el usuario, se factura). | Sí |
| `code-simplifier` | 1.0.0 | Agente que simplifica código recién tocado sin cambiar comportamiento. Útil al partir `main.gd`. | Sí |
| `claude-md-management` | 1.0.0 | `/revise-claude-md` al cerrar sesiones con aprendizajes; auditoría de `CLAUDE.md`. | Sí |
| `claude-code-setup` | 1.0.0 | Recomendador de automatizaciones (hooks, agentes, skills). Se usó para diseñar `.claude/`. | Opcional |
| `skill-creator` | b1aabc22ac99 | Crear y medir skills nuevas (p. ej. una sonda `--probe=` como skill). | Opcional |
| `figma` | 2.2.111 | Diseño de UI/iconos en Figma vía MCP. Solo si se rediseñan iconos táctiles o la ficha. | No para el juego |
| `agent-sdk-dev` | b1aabc22ac99 | Desarrollo con el Agent SDK. No aplica al juego. | No |
| `frontend-design` | (scope de otro proyecto) | Instalado para `~/Desktop/chapamonedero`; no aplica aquí. | No |

Conectores MCP de claude.ai útiles para este juego: **Vercel** (hosting del export web). GitHub
se usa con la CLI `gh` (hace falta `gh auth login`). El resto de conectores de la cuenta (Figma,
Gmail, Drive, Calendar, Linear, Notion, Claude Docs) no intervienen en el juego.

Configuración propia del repo (`.claude/`): `settings.json` (permisos, hooks, plugins),
`hooks/` (`session_start.sh`, `guard_files.sh`, `check_gd.sh`), `agents/` (cinco auditores),
`skills/` (`director`, `auditoria`, `verificar`, `exportar`, `sincronizar-2d`). Lo personal va en
`.claude/settings.local.json` (ignorado por git).

Otras configuraciones de agentes detectadas en la máquina: existe `~/.codex/config.toml`
(OpenAI Codex). Claude Code puede importar de ahí servidores MCP, comandos y skills con
`/import` (o `claude import` en terminal); no se ha hecho.

## 5. Recursos de terceros y licencias (resumen de `assets/CREDITS.txt`)

| Carpeta | Autor / pack | Licencia | Obligación |
|---|---|---|---|
| `models/nature/` (42 glTF) | Quaternius, Stylized Nature MegaKit | CC0 | ninguna |
| `models/chars/UAL*.glb`, `Superhero_*`, `*_Peasant*`, `*_Ranger*`, `Hair_*` | Quaternius, Universal Animation Library 1 y 2, Universal Base Characters, Modular Character Outfits | CC0 | ninguna |
| `models/chars/Skeleton_A|B, Lycan, Puglin, Imp, Hellwarden, Tidebreaker` | Quaternius, Bestiary – Dungeon Monsters Kit | **QAL** | uso comercial sí; **no redistribuir los modelos sueltos** → repo privado; la versión Source es de pago |
| `assets/particles/` (80 PNG) | Kenney, Particle Pack | CC0 | ninguna |
| `assets/audio/sfx/` (130) | Kenney, Impact Sounds | CC0 | ninguna |
| `assets/audio/music/battleThemeA.mp3` | cynicmusic | CC0 | ninguna |
| `assets/audio/music/bossbattle_22k.wav` | Juhani Junkala | CC0 | ninguna |
| `assets/audio/spells/` (16) | p0ss, Spell Sounds Starter Pack | **CC-BY-SA 3.0** | **atribuir** y compartir igual los derivados (son WAV aunque el pack los llame .ogg) |
| `assets/audio/spells/shock.ogg`, `thunder.ogg` | Flare (flare-game, `soundfx/powers`), copiados del 2D | **CC-BY-SA 3.0** | **atribuir**; rayos de la Trampa y la Tormenta eléctricas |
| `assets/ui/kill_rewards/`, `assets/ui/touch/` | el autor (copiados del 2D) | propios | mantener en sincronía con el 2D (`tools/sync_2d.sh`) |

Pesos: `models/chars` 143 MB, `models/nature` 19 MB, `assets/ui/kill_rewards` 19 MB (diez PNG
de 64 px: revisar, algo pesa de más), música 14 MB. El repo tiene 440 ficheros versionados; no
usa Git LFS.

## 6. Integración continua (pendiente, sugerencia)

No hay `.github/workflows`. Cuando se quiera: un job en Ubuntu que instale Godot 4.7.2 (acción
`chickensoft-games/setup-godot` o la imagen `barichello/godot-ci:4.7.2`), corra
`godot --headless --path . --import` y `tools/check.sh`, y suba `export/web` como artefacto. El
checkout pesa ~200 MB por los modelos; conviene `actions/cache` de `.godot/`.
