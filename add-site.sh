#!/usr/bin/env bash
#
# add-site.sh — magdagdag ng site sa VPS (nginx reverse proxy + SSL)
#
# Usage:
#   sudo bash add-site.sh <domain> <local-port> [--skip-ssl]
#
# Halimbawa:
#   sudo bash add-site.sh app.jepong-devxyz.website 3000
#
# Ginagawa:
#   1. nginx site config na nagpo-proxy sa http://127.0.0.1:<port>
#   2. certbot SSL (Let's Encrypt) — laktawan gamit --skip-ssl kung
#      wala pang DNS o test lang
#
set -euo pipefail

log()  { echo -e "\033[1;32m[+]\033[0m $*"; }
warn() { echo -e "\033[1;33m[!]\033[0m $*" >&2; }
die()  { echo -e "\033[1;31m[x]\033[0m $*" >&2; exit 1; }

[ "$(id -u)" -eq 0 ] || die "Patakbuhin as root: sudo bash add-site.sh <domain> <port>"
DOMAIN="${1:-}"; PORT="${2:-}"; SKIP_SSL=0
[ "${3:-}" = "--skip-ssl" ] && SKIP_SSL=1
[ -n "$DOMAIN" ] && [ -n "$PORT" ] || die "Usage: sudo bash add-site.sh <domain> <local-port> [--skip-ssl]"
case "$PORT" in
  ''|*[!0-9]*) die "PORT dapat numero 1-65535, hindi '${PORT}'." ;;
esac
[ "$PORT" -ge 1 ] && [ "$PORT" -le 65535 ] || die "PORT dapat 1-65535, hindi '${PORT}'."
command -v nginx >/dev/null 2>&1 || die "nginx hindi naka-install. Patakbuhin muna ang vps-bootstrap.sh."

CONF="/etc/nginx/sites-available/${DOMAIN}"

log "Gumagawa ng nginx config para sa ${DOMAIN} -> 127.0.0.1:${PORT}..."
cat > "$CONF" <<'NGINX_EOF'
server {
    listen 80;
    server_name DOMAIN_PLACEHOLDER www.DOMAIN_PLACEHOLDER;

    location / {
        proxy_pass http://127.0.0.1:PORT_PLACEHOLDER;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_cache_bypass $http_upgrade;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
NGINX_EOF
sed -i "s/DOMAIN_PLACEHOLDER/${DOMAIN}/g; s/PORT_PLACEHOLDER/${PORT}/g" "$CONF"
ln -sf "$CONF" "/etc/nginx/sites-enabled/${DOMAIN}"

nginx -t || die "nginx config may mali."
if [ -d /run/systemd/system ]; then
  systemctl reload nginx || systemctl restart nginx
elif ! nginx -s reload 2>/dev/null; then
  service nginx reload 2>/dev/null || nginx \
    || warn "hindi ma-reload ang nginx — i-restart manual."
fi
log "nginx OK: http://${DOMAIN} -> port ${PORT}"

if [ "$SKIP_SSL" -eq 1 ]; then
  log "SSL nilaktawan (--skip-ssl). Balikan: sudo certbot --nginx -d ${DOMAIN} -d www.${DOMAIN}"
  exit 0
fi

log "Kumukuha ng SSL via certbot..."
certbot --nginx -d "$DOMAIN" -d "www.$DOMAIN" \
  --non-interactive --agree-tos --register-unsafely-without-email --redirect \
  || die "certbot pumalya — siguraduhing nakaturo ang DNS ng ${DOMAIN} sa VPS IP."

log "Tapos! https://${DOMAIN} live na."
