#!/usr/bin/env bash
#
# install.sh — JepongDevxyz General Server one-line installer
#
# Usage (fresh Ubuntu 22.04/24.04 VPS, as root):
#   curl -fsSL https://raw.githubusercontent.com/JepongDevxyz/jepong-devxyz-general-server/main/install.sh | sudo bash
#
# Ginagawa:
#   1. Dina-download at pinapatakbo ang vps-bootstrap.sh
#      (system update, 2GB swap, Node.js 22 + PM2, nginx + certbot,
#       Docker + Compose, UFW 22/80/443, fail2ban)
#   2. Ini-install ang add-site bilang global command (/usr/local/bin/add-site)
#
set -euo pipefail

REPO="JepongDevxyz/jepong-devxyz-general-server"
BRANCH="main"
BASE="https://raw.githubusercontent.com/${REPO}/${BRANCH}"

[ "$(id -u)" -eq 0 ] || {
  echo "Patakbuhin as root:"
  echo "  curl -fsSL ${BASE}/install.sh | sudo bash"
  exit 1
}
command -v curl >/dev/null 2>&1 || {
  echo "curl kailangan muna: sudo apt install -y curl"
  exit 1
}

echo "[+] Kinu-download ang vps-bootstrap.sh..."
curl -fsSL "${BASE}/vps-bootstrap.sh" -o /tmp/vps-bootstrap.sh
bash /tmp/vps-bootstrap.sh
rm -f /tmp/vps-bootstrap.sh

echo "[+] Ini-install ang add-site command..."
curl -fsSL "${BASE}/add-site.sh" -o /usr/local/bin/add-site
chmod +x /usr/local/bin/add-site

echo ""
echo "=============================================="
echo "  JepongDevxyz General Server — TAPOS!"
echo ""
echo "  Mag-deploy ng site:"
echo "    sudo add-site <domain> <port>"
echo ""
echo "  Halimbawa:"
echo "    sudo add-site app.jepong-devxyz.website 3000"
echo "=============================================="
