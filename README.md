# VPS Scripts — JepongDevxyz

## One-line installer (pinakamadali)

Sa fresh Ubuntu 22.04/24.04 VPS, as root:

```bash
curl -fsSL https://raw.githubusercontent.com/JepongDevxyz/jepong-devxyz-general-server/main/install.sh | sudo bash
```

Ito ang gagawin: full server bootstrap (system update, 2GB swap, Node.js 22 + PM2,
nginx + certbot, Docker + Compose, UFW 22/80/443, fail2ban) tapos i-install ang
`add-site` bilang global command. Pagkatapos:

```bash
sudo add-site app.jepong-devxyz.website 3000
```

## Mga files
- **install.sh** — one-line installer (bootstrap + add-site command)
- **vps-bootstrap.sh** — one-shot setup para sa fresh Ubuntu 22.04/24.04 VPS
- **add-site.sh** — magdagdag ng site (nginx reverse proxy + libreng SSL)

## Gamit (manual, kung ayaw ng one-liner)

### 1. Bootstrap (isang beses lang, as root)
```bash
sudo bash vps-bootstrap.sh
```

Ini-install nito:
1. System update + essential tools (curl, git, htop, unzip)
2. 2GB swap (kung wala pa — tulong sa maliliit na VPS)
3. Node.js 22 LTS + PM2
4. nginx + certbot (Let's Encrypt)
5. Docker Engine + Compose plugin (official Docker repo)
6. UFW firewall — bukas lang ang 22 (SSH), 80, 443
7. fail2ban (proteksyon laban sa brute-force SSH)

### 2. Mag-deploy ng site
```bash
# App na tumatakbo sa port 3000, may libreng SSL:
sudo bash add-site.sh app.jepong-devxyz.website 3000

# Kung wala pang DNS o test lang (walang SSL):
sudo bash add-site.sh app.jepong-devxyz.website 3000 --skip-ssl
```

### 3. PM2 (para manatiling buhay ang Node app)
```bash
pm2 start server.js --name app
pm2 save
```

## Na-test
- `bash -n` syntax check — pasado
- Full logic simulation (isolated mount namespace, stubbed apt/nginx/docker):
  lahat ng 8 steps ng bootstrap (exit 0), nginx config generation,
  SSL path, at usage errors — pasado
- Dalawang tunay na bug ang nahuli at naayos ng test:
  1. node-naka-install-pero-walang-npm edge case
  2. maling "swapfile nilikha" message kapag pumalya ang setup
- 2026-10-16 re-review: idinagdag ang port validation sa add-site.sh
  (numero 1–65535 lang; dati tahimik na gumagawa ng sirang config
  kapag typo ang port) — tested: `abc` at `99999` → die, `3000` → OK

## Paalala
- Patakbuhin lang sa **fresh VPS** (Hetzner/Contabo Ubuntu image).
- Huwag patakbuhin nang dalawang beses nang walang dahilan — idempotent
  naman ang karamihan, pero sayang sa oras ang full apt upgrade.
- Ang unang `apt-get upgrade` ay maaaring magtagal ng 5–15 minuto.
