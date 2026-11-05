#!/usr/bin/env bash
# Publica el export web en el servicio "web" de Railway (el servidor del juego en línea es otro
# servicio del mismo proyecto y no se toca).
#   tools/deploy_web.sh            # usa export/web tal como esté
#   tools/deploy_web.sh --build    # antes exporta (tools/build.sh web)
# Requisitos: Railway CLI (npm i -g @railway/cli), `railway login` y `railway link` hechos una vez en
# esta carpeta. Servicio: RAILWAY_WEB_SERVICE (por defecto "web").
set -euo pipefail
cd "$(dirname "$0")/.."

SERVICE="${RAILWAY_WEB_SERVICE:-web}"
[ "${1:-}" = "--build" ] && tools/build.sh web
[ -f export/web/index.html ] || { echo "No hay export/web/index.html: corre tools/build.sh web" >&2; exit 1; }

STAGE="export/railway-web"
rm -rf "$STAGE"
mkdir -p "$STAGE/site"
cp tools/web/Dockerfile tools/web/Caddyfile "$STAGE/"
# Solo lo que pide el juego (fuera páginas de prueba como bench_*.html y los .import).
for f in index.html index.js index.wasm index.pck index.png index.audio.worklet.js \
		index.audio.position.worklet.js index.icon.png index.apple-touch-icon.png; do
	[ -f "export/web/$f" ] && cp "export/web/$f" "$STAGE/site/"
done
echo "== Comprimiendo (gzip -9) los ficheros grandes"
for f in index.wasm index.pck index.js; do
	gzip -9 -k "$STAGE/site/$f"
done
ls -lh "$STAGE/site"

echo "== Subiendo a Railway (servicio $SERVICE)"
railway up "$STAGE" --path-as-root --service "$SERVICE" --detach
