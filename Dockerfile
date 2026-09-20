# Servidor dedicado sin pantalla de Fallen Legends 3D (fase 1 del juego en línea: la sala).
# Copiado del Dockerfile del 2D (arena-arpg) el 2026-09-20 y adaptado.
#   docker build -t fallen-legends-3d-server .
#   docker run --rm -p 7777:7777 -e PORT=7777 fallen-legends-3d-server
# En Railway manda railway.json: construye con este fichero y arranca el startCommand de allí.
FROM debian:bookworm-slim

ARG GODOT_VERSION=4.7.2
RUN apt-get update \
 && apt-get install -y --no-install-recommends ca-certificates curl unzip libfontconfig1 \
 && rm -rf /var/lib/apt/lists/* \
 && curl -fsSL -o /tmp/godot.zip \
      "https://github.com/godotengine/godot/releases/download/${GODOT_VERSION}-stable/Godot_v${GODOT_VERSION}-stable_linux.x86_64.zip" \
 && unzip -q /tmp/godot.zip -d /tmp \
 && mv "/tmp/Godot_v${GODOT_VERSION}-stable_linux.x86_64" /usr/local/bin/godot \
 && chmod +x /usr/local/bin/godot \
 && rm -f /tmp/godot.zip

WORKDIR /app
COPY . .
# Importa una vez, en la construcción, para no pagar el escaneo en cada arranque (Railway mata el
# contenedor si tarda en responder). Ojo: `models/` NO entra en la imagen (ver .dockerignore), así
# que aquí solo se importan la UI y los sonidos, que es cosa de segundos.
RUN godot --headless --path /app --import >/dev/null 2>&1 || true

# Railway solo enruta TCP y da el puerto en PORT: Net arranca el WebSocket solo al verla.
EXPOSE 7777
# Sin ENTRYPOINT a propósito: así cualquier plataforma que sustituya el comando (el startCommand de
# Railway, el `command:` de compose) lo hace limpiamente, sin argumentos antepuestos.
CMD ["godot", "--headless", "--path", "/app", "--", "--server", "--transport=ws"]
