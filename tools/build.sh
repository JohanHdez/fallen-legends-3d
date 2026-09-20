#!/usr/bin/env bash
# Exporta Fallen Legends 3D. Requisitos y rutas: docs/DESPLIEGUE.md.
#   tools/build.sh android            # APK de depuración (clave debug), export/proto3d.apk
#   tools/build.sh android-release    # APK firmado: necesita GODOT_ANDROID_KEYSTORE_RELEASE_PATH/_USER/_PASSWORD
#   tools/build.sh web                # export/web/index.html (+ export/fallen-legends-3d-web.zip)
#   tools/build.sh all                # android (debug) + web
# Salida en export/ (ignorado por git). Corre antes tools/check.sh: no exportes algo que no parsea.
set -euo pipefail
cd "$(dirname "$0")/.."

GODOT="${GODOT:-godot}"
VERSION="$("$GODOT" --version 2>/dev/null | head -1 | grep -oE '^[0-9]+\.[0-9]+(\.[0-9]+)?' || true)"
if [ -z "$VERSION" ]; then
  echo "No encuentro Godot ('$GODOT'). brew install --cask godot, o exporta GODOT=/ruta/godot." >&2
  exit 1
fi
if [[ "$OSTYPE" == darwin* ]]; then
  TPL_DIR="$HOME/Library/Application Support/Godot/export_templates/$VERSION.stable"
else
  TPL_DIR="$HOME/.local/share/godot/export_templates/$VERSION.stable"
fi
if [ ! -f "$TPL_DIR/version.txt" ]; then
  echo "Faltan las plantillas de exportación de Godot $VERSION en: $TPL_DIR" >&2
  echo "Descarga Godot_v${VERSION}-stable_export_templates.tpz de https://github.com/godotengine/godot/releases/tag/${VERSION}-stable," >&2
  echo "descomprímelo y copia su carpeta templates/ como la ruta anterior (o Editor → Administrar plantillas)." >&2
  exit 1
fi
# export/ está DENTRO del proyecto y el preset exporta todos los recursos (all_resources): sin este
# fichero, Godot importa lo que haya ahí (capturas, el index.png de la web) y lo mete en el APK.
mkdir -p export
touch export/.gdignore
if [ ! -d .godot/imported ]; then
  echo "== Importando recursos por primera vez (los glTF tardan)"
  "$GODOT" --headless --path . --import >/dev/null 2>&1 || true
fi

need_android() {
  local jdk="${JAVA_HOME:-$HOME/Library/Java/jdk-17}" sdk="${ANDROID_HOME:-$HOME/Library/Android/sdk}"
  [ -d "$jdk" ] || { echo "Falta el JDK 17 en $jdk (JAVA_HOME). Ver docs/DESPLIEGUE.md." >&2; exit 1; }
  [ -d "$sdk/platform-tools" ] || { echo "Falta el SDK de Android en $sdk (ANDROID_HOME). Ver docs/DESPLIEGUE.md." >&2; exit 1; }
}

export_android_debug() {
  need_android
  mkdir -p export
  echo "== Android (APK de depuración, firmado con la clave de depuración) -> export/proto3d.apk"
  "$GODOT" --headless --path . --export-debug "Android" export/proto3d.apk
}

export_android_release() {
  need_android
  : "${GODOT_ANDROID_KEYSTORE_RELEASE_PATH:?Define GODOT_ANDROID_KEYSTORE_RELEASE_PATH (ruta al .keystore de release, FUERA del repo)}"
  : "${GODOT_ANDROID_KEYSTORE_RELEASE_USER:?Define GODOT_ANDROID_KEYSTORE_RELEASE_USER}"
  : "${GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD:?Define GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD}"
  [ -f "$GODOT_ANDROID_KEYSTORE_RELEASE_PATH" ] || { echo "No existe el keystore: $GODOT_ANDROID_KEYSTORE_RELEASE_PATH" >&2; exit 1; }
  mkdir -p export
  echo "== Android (APK de RELEASE) -> export/proto3d-release.apk"
  echo "   Recuerda subir version/code y version/name en export_presets.cfg antes de publicar."
  "$GODOT" --headless --path . --export-release "Android" export/proto3d-release.apk
}

export_web() {
  mkdir -p export/web
  echo "== Web -> export/web/index.html"
  "$GODOT" --headless --path . --export-release "Web" export/web/index.html
  (cd export && rm -f fallen-legends-3d-web.zip && zip -qr fallen-legends-3d-web.zip web -x '*.import')
  echo "   Probar en local:  python3 -m http.server -d export/web 8060   (http://localhost:8060)"
  echo "   Sin hilos (thread_support=false), no hace falta COOP/COEP; cualquier hosting estático sirve."
}

case "${1:-all}" in
  android)          export_android_debug ;;
  android-release)  export_android_release ;;
  web)              export_web ;;
  all)              export_android_debug; export_web ;;
  *) echo "Uso: $0 [android|android-release|web|all]" >&2; exit 2 ;;
esac
echo
ls -lh export/ 2>/dev/null || true
