# Servicio "web" de Railway: sirve el export web del juego (no confundir con el Dockerfile de la raíz,
# que es el servidor del juego en línea). Lo monta y lo sube tools/deploy_web.sh; no se construye desde
# el repo porque export/ no se versiona.
FROM caddy:2.8.4-alpine
COPY Caddyfile /etc/caddy/Caddyfile
COPY site/ /srv/
