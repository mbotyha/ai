#!/usr/bin/env bash
# Jitsi Meet (docker-jitsi-meet) on a fresh Ubuntu 24.04 VPS.
# Hosts log in (internal auth), guests join without an account once a host is in.
# Usage: DOMAIN=bitvero.mbotyha.com LE_EMAIL=letsencrypt@agent.mbotyha.com bash jitsi-install.sh
set -euo pipefail

: "${DOMAIN:?set DOMAIN}"
: "${LE_EMAIL:?set LE_EMAIL}"
DIR=/opt/jitsi
CFG=/opt/jitsi-cfg

# Firewall: SSH, HTTP (Let's Encrypt), HTTPS, media
apt-get update -q
apt-get install -yq ufw curl unzip
ufw allow 22/tcp && ufw allow 80/tcp && ufw allow 443/tcp && ufw allow 10000/udp
ufw --force enable

# Docker
command -v docker >/dev/null || curl -fsSL https://get.docker.com | sh

# Latest stable docker-jitsi-meet release
mkdir -p "$DIR" && cd "$DIR"
url=$(curl -fsSL https://api.github.com/repos/jitsi/docker-jitsi-meet/releases/latest | grep -o '"zipball_url": *"[^"]*"' | cut -d'"' -f4)
curl -fsSL "$url" -o release.zip
unzip -qo release.zip && rm release.zip
cd "$(ls -d jitsi-docker-jitsi-meet-*/ | head -1)"

cp -n env.example .env
./gen-passwords.sh
public_ip=$(curl -fsS https://api.ipify.org)
set_env() { grep -q "^#\?$1=" .env && sed -i "s|^#\?$1=.*|$1=$2|" .env || echo "$1=$2" >> .env; }
set_env CONFIG "$CFG"
set_env HTTP_PORT 80
set_env HTTPS_PORT 443
set_env TZ Europe/Rome
set_env PUBLIC_URL "https://$DOMAIN"
set_env ENABLE_LETSENCRYPT 1
set_env LETSENCRYPT_DOMAIN "$DOMAIN"
set_env LETSENCRYPT_EMAIL "$LE_EMAIL"
set_env ENABLE_HTTP_REDIRECT 1
set_env JVB_ADVERTISE_IPS "$public_ip"
set_env ENABLE_AUTH 1
set_env AUTH_TYPE internal
set_env ENABLE_GUESTS 1
set_env ENABLE_LOBBY 1
set_env ENABLE_PREJOIN_PAGE 1

mkdir -p "$CFG"/{web,jicofo,jvb,prosody/config,prosody/prosody-plugins-custom,storage/{web,prosody,transcripts}}
# Containers run as uid 1000 since the 2026 releases
chown -R 1000:1000 "$CFG"
docker compose up -d

# One host account; password kept root-only on the server, copy it to the password manager
until docker compose exec -T prosody test -f /run/prosody/config/prosody.cfg.lua 2>/dev/null; do sleep 5; done
(umask 077 && openssl rand -base64 18 > /root/jitsi-host-pass)
docker compose exec -T prosody prosodyctl --config /run/prosody/config/prosody.cfg.lua register host meet.jitsi "$(cat /root/jitsi-host-pass)"
echo "Jitsi ready: https://$DOMAIN  host login: host, password in /root/jitsi-host-pass"
