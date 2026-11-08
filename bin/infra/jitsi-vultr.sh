#!/usr/bin/env bash
# Ephemeral Jitsi on Vultr, one command each way.
#   jitsi-vultr.sh up     create server + DNS, Jitsi installs itself via cloud-init (~5 min)
#   jitsi-vultr.sh down   snapshot (optional, SNAPSHOT=1), destroy server, remove DNS
# Env: VULTR_API_KEY, CLOUDFLARE_API_TOKEN (Zone DNS edit on the zone)
# Defaults below can be overridden from env, e.g. REGION=mil SUBDOMAIN=call ./jitsi-vultr.sh up
set -euo pipefail

[[ "${1:-}" =~ ^(-h|--help)$ ]] || : "${VULTR_API_KEY:?}" "${CLOUDFLARE_API_TOKEN:?}"
ZONE=${ZONE:-mbotyha.com}
SUBDOMAIN=${SUBDOMAIN:-bitvero}
REGION=${REGION:-ams}           # ams, fra, mil, sao ...
PLAN=${PLAN:-vhp-4c-8gb}        # vhp-2c-4gb up to ~10 people, vhp-4c-8gb up to ~30
LE_EMAIL=${LE_EMAIL:-letsencrypt@agent.mbotyha.com}
SSH_KEY_FILE=${SSH_KEY_FILE:-$HOME/.ssh/id_rsa.pub}
INSTALL=${INSTALL:-$(dirname "$(readlink -f "$0")")/jitsi-install.sh}
LABEL="$SUBDOMAIN-jitsi"
FQDN="$SUBDOMAIN.$ZONE"

vultr() { curl -fsS -H "Authorization: Bearer $VULTR_API_KEY" -H 'Content-Type: application/json' "https://api.vultr.com/v2$1" "${@:2}"; }
cf() { curl -fsS -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN" -H 'Content-Type: application/json' "https://api.cloudflare.com/client/v4$1" "${@:2}"; }
zone_id() { cf "/zones?name=$ZONE" | jq -r '.result[0].id'; }
instance_id() { vultr "/instances?label=$LABEL" | jq -r '.instances[0].id // empty'; }
dns_id() { cf "/zones/$1/dns_records?type=A&name=$FQDN" | jq -r '.result[0].id // empty'; }

up() {
  [ -z "$(instance_id)" ] || { echo "$LABEL already exists" >&2; exit 1; }
  os_id=$(vultr /os | jq -r '.os[] | select(.name=="Ubuntu 24.04 LTS x64") | .id')
  # cloud-init: SSH key, install script, run it with the domain
  user_data=$(cat <<EOF
#cloud-config
ssh_authorized_keys:
  - $(cat "$SSH_KEY_FILE")
write_files:
  - path: /root/jitsi-install.sh
    permissions: '0755'
    encoding: b64
    content: $(base64 -w0 "$INSTALL")
runcmd:
  - [bash, -c, "until getent hosts $FQDN | grep -q \$(curl -fsS https://api.ipify.org); do sleep 10; done; DOMAIN=$FQDN LE_EMAIL=$LE_EMAIL /root/jitsi-install.sh > /root/jitsi-install.log 2>&1"]
EOF
)
  body=$(jq -n --arg r "$REGION" --arg p "$PLAN" --argjson o "$os_id" --arg l "$LABEL" --arg h "$SUBDOMAIN" --arg u "$(base64 -w0 <<<"$user_data")" \
    '{region:$r, plan:$p, os_id:$o, label:$l, hostname:$h, user_data:$u, backups:"disabled", enable_ipv6:false}')
  id=$(vultr /instances -X POST -d "$body" | jq -r .instance.id)
  echo "instance $id: waiting for IP"
  until ip=$(vultr "/instances/$id" | jq -r '.instance.main_ip') && [ "$ip" != "0.0.0.0" ]; do sleep 5; done
  z=$(zone_id); rec=$(jq -n --arg n "$SUBDOMAIN" --arg ip "$ip" '{type:"A", name:$n, content:$ip, ttl:60, proxied:false, comment:"ephemeral Jitsi on Vultr"}')
  d=$(dns_id "$z")
  if [ -n "$d" ]; then cf "/zones/$z/dns_records/$d" -X PUT -d "$rec" >/dev/null; else cf "/zones/$z/dns_records" -X POST -d "$rec" >/dev/null; fi
  echo "$FQDN -> $ip. Jitsi installs by itself; host password: ssh root@$ip cat /root/jitsi-host-pass"
}

down() {
  id=$(instance_id); [ -n "$id" ] || { echo "no $LABEL instance" >&2; exit 1; }
  if [ "${SNAPSHOT:-0}" = 1 ]; then
    snap=$(vultr /snapshots -X POST -d "$(jq -n --arg i "$id" --arg d "$LABEL $(date +%F)" '{instance_id:$i, description:$d}')" | jq -r .snapshot.id)
    echo "snapshot $snap: waiting"
    until [ "$(vultr "/snapshots/$snap" | jq -r .snapshot.status)" = complete ]; do sleep 15; done
  fi
  vultr "/instances/$id" -X DELETE
  z=$(zone_id); d=$(dns_id "$z"); [ -z "$d" ] || cf "/zones/$z/dns_records/$d" -X DELETE >/dev/null
  echo "$LABEL destroyed, $FQDN removed"
}

case "${1:-}" in up) up ;; down) down ;; -h|--help) sed -n 2,6p "$0" | sed "s/^# \{0,1\}//" ;; *) echo "usage: $0 up|down" >&2; exit 1 ;; esac
