#!/usr/bin/env bash
#
# vps-bootstrap.sh — JepongDevxyz VPS one-shot setup
# Target: fresh Ubuntu 22.04 / 24.04 LTS. Run as root:
#   sudo bash vps-bootstrap.sh
#
# Installs:
#   - essentials (curl, git, htop, unzip, ...)
#   - 2 GB swap (kung wala pa)
#   - Node.js 22 LTS + PM2
#   - nginx + certbot (python3-certbot-nginx)
#   - Docker Engine + Compose plugin (official Docker repo)
#   - UFW firewall (22/80/443) + fail2ban
#
set -euo pipefail

log()  { echo -e "\033[1;32m[+]\033[0m $*"; }
warn() { echo -e "\033[1;33m[!]\033[0m $*" >&2; }
die()  { echo -e "\033[1;31m[x]\033[0m $*" >&2; exit 1; }

[ "$(id -u)" -eq 0 ] || die "Patakbuhin as root: sudo bash vps-bootstrap.sh"

if [ -f /etc/os-release ]; then
  # shellcheck disable=SC1091
  . /etc/os-release
else
  die "/etc/os-release hindi mahanap — Ubuntu VPS ba ito?"
fi
[ "${ID:-}" = "ubuntu" ] || die "Ubuntu lang ang supported (nakita: ${ID:-unknown})."
case "${VERSION_ID:-}" in
  22.04|24.04) log "Ubuntu ${VERSION_ID} detected." ;;
  *) warn "Hindi pa tested sa Ubuntu ${VERSION_ID:-unknown} — tutuloy pa rin." ;;
esac

export DEBIAN_FRONTEND=noninteractive

# May systemd ba? (wala sa docker container test)
HAS_SYSTEMD=0
if command -v systemctl >/dev/null 2>&1 && [ -d /run/systemd/system ]; then
  HAS_SYSTEMD=1
fi

svc() { # svc <action> <service> — safe sa walang systemd
  if [ "$HAS_SYSTEMD" -eq 1 ]; then
    systemctl "$1" "$2" || warn "systemctl $1 $2 pumalya"
  else
    warn "walang systemd — skip: systemctl $1 $2"
  fi
}

log "Step 1/8: system update..."
apt-get update -qq
apt-get upgrade -y -qq

log "Step 2/8: essential packages..."
apt-get install -y -qq ca-certificates curl gnupg lsb-release git \
  ufw fail2ban htop unzip software-properties-common apt-transport-https

log "Step 3/8: swap (2G kung wala pa)..."
if [ "$(swapon --show=SIZE --noheadings 2>/dev/null | wc -l)" -eq 0 ] && [ ! -f /swapfile ]; then
  if fallocate -l 2G /swapfile 2>/dev/null || dd if=/dev/zero of=/swapfile bs=1M count=2048 status=none; then
    if chmod 600 /swapfile && mkswap /swapfile >/dev/null 2>&1; then
      (swapon /swapfile || warn "swapon pumalya (normal sa container test)")
      grep -q '^/swapfile' /etc/fstab 2>/dev/null || echo '/swapfile none swap sw 0 0' >> /etc/fstab
      log "swapfile nilikha."
    else
      warn "swap setup pumalya — tinatanggal ang /swapfile."
      rm -f /swapfile
    fi
  else
    warn "hindi makagawa ng swapfile — skip."
  fi
else
  log "may swap na — skip."
fi

log "Step 4/8: Node.js 22 LTS + PM2..."
if ! command -v node >/dev/null 2>&1 || ! command -v npm >/dev/null 2>&1; then
  log "(node/npm hindi kumpleto — i-install ang Node.js 22...)"
  mkdir -p /etc/apt/keyrings
  curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key \
    | gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg
  echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_22.x nodistro main" \
    > /etc/apt/sources.list.d/nodesource.list
  apt-get update -qq
  apt-get install -y -qq nodejs
fi
npm install -g pm2 >/dev/null 2>&1 || npm install -g pm2
log "node $(node --version), pm2 $(pm2 --version)"

log "Step 5/8: nginx + certbot..."
apt-get install -y -qq nginx certbot python3-certbot-nginx
nginx -t
svc enable nginx
svc start nginx

log "Step 6/8: Docker Engine + Compose..."
if ! command -v docker >/dev/null 2>&1; then
  install -m 0755 -d /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
    | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
  chmod a+r /etc/apt/keyrings/docker.gpg
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
https://download.docker.com/linux/ubuntu ${VERSION_CODENAME} stable" \
    > /etc/apt/sources.list.d/docker.list
  apt-get update -qq
  apt-get install -y -qq docker-ce docker-ce-cli containerd.io \
    docker-buildx-plugin docker-compose-plugin
fi
svc enable docker
svc start docker
log "docker $(docker --version | cut -d' ' -f3 | tr -d ',')"

log "Step 7/8: UFW firewall (22/80/443)..."
if ufw --force reset >/dev/null 2>&1; then
  ufw default deny incoming >/dev/null
  ufw default allow outgoing >/dev/null
  ufw allow 22/tcp >/dev/null
  ufw allow 80/tcp >/dev/null
  ufw allow 443/tcp >/dev/null
  if ufw --force enable; then
    log "UFW active."
  else
    warn "UFW enable pumalya."
  fi
else
  warn "UFW hindi gumana dito (normal sa container test) — sa totoong VPS dapat gumana."
fi

log "Step 8/8: fail2ban..."
svc enable fail2ban
svc start fail2ban

echo ""
echo "=============================================="
echo "  VPS bootstrap TAPOS. Summary:"
echo "  - node:   $(node --version)"
echo "  - pm2:    $(pm2 --version)"
echo "  - nginx:  $(nginx -v 2>&1 | cut -d' ' -f3)"
echo "  - docker: $(docker --version | cut -d' ' -f3 | tr -d ',')"
echo "  - ufw:    $(ufw status 2>/dev/null | head -1)"
echo "=============================================="
echo "  Next steps:"
echo "  1. Para mag-deploy ng site:  bash add-site.sh <domain> <port>"
echo "     (gagawa ng nginx reverse-proxy + certbot SSL)"
echo "  2. PM2 app:  pm2 start server.js --name app && pm2 save"
echo "=============================================="
