#!/usr/bin/env bash
# Ephemeral Jitsi on Vultr, one command each way.
#   jitsi-vultr create [--url https://bitvero.mbotyha.com] [--name "Foo bar"] [--duration 5h] [--provider vultr] [--region nl]
#       server + DNS, Jitsi installs itself via cloud-init (~5 min); --duration destroys it after that time
#   jitsi-vultr destroy [--url ...]   snapshot (optional, SNAPSHOT=1), destroy server, remove DNS
# Keys: VULTR_API_KEY, CLOUDFLARE_API_TOKEN (Zone Read + DNS Edit) from env or ~/.config/mbotyha/secrets.env
# Other defaults from env, e.g. REGION=mil PLAN=vhp-2c-4gb jitsi-vultr create
set -euo pipefail

SELF=$(readlink -f "$0")
usage() { sed -n 2,7p "$SELF" | sed "s/^# \{0,1\}//"; }
cmd=${1:-}; shift || true
case "$cmd" in up) cmd=create ;; down) cmd=destroy ;; create|destroy) ;; -h|--help|help) usage; exit ;; *) usage >&2; exit 1 ;; esac
URL="" NAME="" DURATION="" PROVIDER=vultr
while [ $# -gt 0 ]; do
  case "$1" in
    --url) URL=$2; shift 2 ;;
    --name) NAME=$2; shift 2 ;;
    --duration) DURATION=$2; shift 2 ;;
    --provider) PROVIDER=$2; shift 2 ;;
    --region) REGION=$2; shift 2 ;;
    -h|--help) usage; exit ;;
    *) echo "unknown option $1" >&2; usage >&2; exit 1 ;;
  esac
done

# ponytail: one provider for now; others become a case on $PROVIDER around vultr()/up()/down()
[ "$PROVIDER" = vultr ] || { echo "provider '$PROVIDER' not supported yet (only vultr)" >&2; exit 1; }

SECRETS=${SECRETS:-$HOME/.config/mbotyha/secrets.env}
# shellcheck disable=SC1090
[ -n "${VULTR_API_KEY:-}" ] || [ ! -f "$SECRETS" ] || . "$SECRETS"
: "${VULTR_API_KEY:?missing, set it or put it in $SECRETS}" "${CLOUDFLARE_API_TOKEN:?missing, set it or put it in $SECRETS}"

# --url https://sub.zone.tld wins over SUBDOMAIN/ZONE
if [ -n "$URL" ]; then host=${URL#*://}; host=${host%%/*}; SUBDOMAIN=${host%%.*}; ZONE=${host#*.}; fi
ZONE=${ZONE:-mbotyha.com}
SUBDOMAIN=${SUBDOMAIN:-bitvero}
REGION=${REGION:-nl}
# Short country codes, any other value is passed as a Vultr region id (ams, fra, mil, sao ...)
case "$REGION" in nl) REGION=ams ;; br) REGION=sao ;; it) REGION=mil ;; de) REGION=fra ;; esac
PLAN=${PLAN:-vhp-4c-8gb}        # vhp-2c-4gb up to ~10 people, vhp-4c-8gb up to ~30
LE_EMAIL=${LE_EMAIL:-letsencrypt@agent.mbotyha.com}
SSH_KEY_FILE=${SSH_KEY_FILE:-$HOME/.ssh/id_rsa.pub}
INSTALL=${INSTALL:-$(dirname "$(readlink -f "$0")")/jitsi-install.sh}
LABEL="$SUBDOMAIN-jitsi"
FQDN="$SUBDOMAIN.$ZONE"
# Both end up in root shell code on the server: allow only plain characters
[[ $FQDN =~ ^[a-z0-9.-]+$ && $LE_EMAIL =~ ^[A-Za-z0-9._+-]+@[a-z0-9.-]+$ ]] || { echo "invalid SUBDOMAIN/ZONE/LE_EMAIL" >&2; exit 1; }

vultr() { curl -fsS -H "Authorization: Bearer $VULTR_API_KEY" -H 'Content-Type: application/json' "https://api.vultr.com/v2$1" "${@:2}"; }
cf() { curl -fsS -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN" -H 'Content-Type: application/json' "https://api.cloudflare.com/client/v4$1" "${@:2}"; }
zone_id() { local z; z=$(cf "/zones?name=$ZONE" | jq -r '.result[0].id // empty'); [ -n "$z" ] || { echo "zone $ZONE not found" >&2; exit 1; }; echo "$z"; }
instance_id() {
  local ids; ids=$(vultr "/instances?label=$LABEL" | jq -r '.instances[].id')
  [ "$(grep -c . <<<"$ids")" -le 1 ] || { echo "more than one $LABEL instance, delete by hand" >&2; exit 1; }
  echo "$ids"
}
dns_rec() { cf "/zones/$1/dns_records?type=A&name=$FQDN" | jq -r '.result[0] // empty | "\(.id) \(.content)"'; }
is_ipv4() { [[ $1 =~ ^[0-9]{1,3}(\.[0-9]{1,3}){3}$ && $1 != 0.0.0.0 ]]; }

up() {
  [ -z "$(instance_id)" ] || { echo "$LABEL already exists" >&2; exit 1; }
  # Check DNS before paying for a server
  z=$(zone_id); read -r d old < <(dns_rec "$z") || true
  [ -z "${d:-}" ] || [ "${REPLACE_DNS:-0}" = 1 ] || { echo "$FQDN already points at $old; REPLACE_DNS=1 to overwrite" >&2; exit 1; }
  os_id=$(vultr /os | jq -r '.os[] | select(.name=="Ubuntu 24.04 LTS x64") | .id')
  # cloud-init: SSH key, install script, run it once DNS resolves to this server
  # ponytail: no deadline on the DNS wait, check /root/jitsi-install.log if it never starts
  user_data=$(cat <<EOF
#cloud-config
ssh_authorized_keys:
  - $(jq -Rs 'rtrimstr("\n")' "$SSH_KEY_FILE")
write_files:
  - path: /root/jitsi-install.sh
    permissions: '0755'
    encoding: b64
    content: $(base64 -w0 "$INSTALL")
runcmd:
  - [bash, -c, "until ip=\$(curl -fsS https://api.ipify.org) && getent ahostsv4 $FQDN | awk '{print \$1}' | grep -qxF \"\$ip\"; do sleep 10; done; DOMAIN=$FQDN LE_EMAIL=$LE_EMAIL /root/jitsi-install.sh > /root/jitsi-install.log 2>&1"]
EOF
)
  body=$(jq -n --arg r "$REGION" --arg p "$PLAN" --argjson o "$os_id" --arg l "$LABEL" --arg h "$SUBDOMAIN" --arg u "$(base64 -w0 <<<"$user_data")" \
    '{region:$r, plan:$p, os_id:$o, label:$l, hostname:$h, user_data:$u, backups:"disabled", enable_ipv6:false}')
  id=$(vultr /instances -X POST -d "$body" | jq -r .instance.id)
  echo "instance $id: waiting for IP (if this fails, the server exists: jitsi-vultr down)"
  until ip=$(vultr "/instances/$id" | jq -r '.instance.main_ip // empty') && is_ipv4 "$ip"; do sleep 5; done
  rec=$(jq -n --arg n "$SUBDOMAIN" --arg ip "$ip" '{type:"A", name:$n, content:$ip, ttl:60, proxied:false, comment:"ephemeral Jitsi on Vultr"}')
  if [ -n "${d:-}" ]; then cf "/zones/$z/dns_records/$d" -X PUT -d "$rec" >/dev/null; else cf "/zones/$z/dns_records" -X POST -d "$rec" >/dev/null; fi
  room=$(tr '[:upper:]' '[:lower:]' <<<"$NAME" | sed -E 's/[^a-z0-9]+/-/g; s/^-|-$//g')
  echo "$FQDN -> $ip. Jitsi installs by itself in ~5 min; host password: ssh root@$ip cat /root/jitsi-host-pass"
  echo "Link: https://$FQDN/$room"
  if [ -n "$DURATION" ]; then
    # ponytail: user timer on this PC, it fires only if the PC is on; a Cloudflare Worker cron when that is not enough
    systemd-run --user --unit="jitsi-destroy-$SUBDOMAIN" --on-active="$DURATION" --timer-property=AccuracySec=1min \
      "$SELF" destroy --url "https://$FQDN" >/dev/null
    echo "Destroyed in $DURATION (PC must be on). Cancel: systemctl --user stop jitsi-destroy-$SUBDOMAIN.timer"
  fi
}

down() {
  id=$(instance_id); [ -n "$id" ] || { echo "no $LABEL instance" >&2; exit 1; }
  ip=$(vultr "/instances/$id" | jq -r .instance.main_ip)
  z=$(zone_id)   # before destroying, so a bad token stops here
  if [ "${SNAPSHOT:-0}" = 1 ]; then
    snap=$(vultr /snapshots -X POST -d "$(jq -n --arg i "$id" --arg d "$LABEL $(date +%F)" '{instance_id:$i, description:$d}')" | jq -r .snapshot.id)
    echo "snapshot $snap: waiting"
    until [ "$(vultr "/snapshots/$snap" | jq -r .snapshot.status)" = complete ]; do sleep 15; done
  fi
  vultr "/instances/$id" -X DELETE
  # Delete the record only if it still points at this server
  read -r d cur < <(dns_rec "$z") || true
  if [ -n "${d:-}" ] && [ "$cur" = "$ip" ]; then cf "/zones/$z/dns_records/$d" -X DELETE >/dev/null; echo "$LABEL destroyed, $FQDN removed"
  else echo "$LABEL destroyed; $FQDN not removed (points at ${cur:-nothing}, not $ip)"; fi
}

case "$cmd" in create) up ;; destroy) down ;; esac
