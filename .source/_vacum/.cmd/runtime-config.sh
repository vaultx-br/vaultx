#!/usr/bin/env bash
set -Eeuo pipefail
umask 077
source_dir=${VACUM_SOURCE:-/opt/vacum-src}
state_dir=${VACUM_STATE:-/opt/vaultwarden}
runtime=${VACUM_RUNTIME:-/run/vaultwarden/secrets}
secrets=${VACUM_SECRETS:-$source_dir/.source/_secrets/secrets.age}
d=$(mktemp -d "${TMPDIR:-/dev/shm}/vacum-secrets.XXXXXX"); trap 'rm -rf "$d"' EXIT
age -d -i "$state_dir/_secrets/age.key" "$secrets" | tar -xzf - -C "$d"
for f in backup.env cloudflared.env git.env vaultwarden.env; do [[ -f $d/$f ]] || { echo "secret ausente: $f" >&2; exit 1; }; done
mapfile -t nodes < <(find "$d/restic" -maxdepth 1 -type f -name '*.env' -printf '%f\n' 2>/dev/null | LC_ALL=C sort)
((${#nodes[@]})) || { echo 'nenhum nó Restic no pacote' >&2; exit 1; }
install -d -o root -g root -m 700 "$runtime" "$runtime/restic"
find "$runtime" -mindepth 1 -maxdepth 1 -type f -delete
find "$runtime/restic" -mindepth 1 -maxdepth 1 -type f -delete
for f in backup.env cloudflared.env git.env vaultwarden.env; do install -o root -g root -m 600 "$d/$f" "$runtime/$f"; done
sed -i 's/^CF_TUNNEL_TOKEN=/TUNNEL_TOKEN=/' "$runtime/cloudflared.env"
n=0
for file in "${nodes[@]}"; do
  name=${file%.env}; [[ $name =~ ^[a-zA-Z0-9_-]+$ ]] || { echo 'nome de nó Restic inválido' >&2; exit 1; }
  n=$((n + 1))
  install -o root -g root -m 600 "$d/restic/$file" "$runtime/restic/$file"
  printf 'RESTIC_%s_NAME=%s\n' "$n" "$name"
  awk -F= -v n="$n" '/^(ENABLED|REPOSITORY|ACCESS_KEY|SECRET_KEY|PASSWORD)=/{print "RESTIC_" n "_" $0}' "$d/restic/$file"
done >> "$runtime/backup.env"
chmod 600 "$runtime/backup.env"
