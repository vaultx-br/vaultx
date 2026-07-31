#!/usr/bin/env bash
set -Eeuo pipefail
umask 077
source_dir=${VACUM_SOURCE:-/opt/vacum-src}
state_dir=${VACUM_STATE:-/opt/vaultwarden}
runtime=${VACUM_RUNTIME:-/run/vaultwarden/secrets}
out=$source_dir/.source/_secrets/secrets.age
for f in backup.env cloudflared.env git.env vaultwarden.env; do [[ -f $runtime/$f ]] || { echo "secret ausente: $f" >&2; exit 1; }; done
find "$runtime/restic" -maxdepth 1 -type f -name '*.env' -print -quit | grep -q . || { echo 'nenhum nó Restic' >&2; exit 1; }
pkg=$(mktemp -d "${TMPDIR:-/dev/shm}/vacum-secrets-new.XXXXXX"); old=$(mktemp -d "${TMPDIR:-/dev/shm}/vacum-secrets-old.XXXXXX"); tmp=$(mktemp "$source_dir/.source/_secrets/secrets.age.XXXXXX"); trap 'rm -rf "$pkg" "$old"; rm -f "$tmp"' EXIT
install -d -m 700 "$pkg/restic"
for f in cloudflared.env git.env vaultwarden.env; do cp "$runtime/$f" "$pkg/$f"; done
grep -v '^RESTIC_[0-9][0-9]*_' "$runtime/backup.env" > "$pkg/backup.env"
cp "$runtime/restic/"*.env "$pkg/restic/"
if [[ -f $out ]] && age -d -i "$state_dir/_secrets/age.key" "$out" | tar -xzf - -C "$old" && diff -qr "$pkg" "$old" >/dev/null; then
  ${VACUM_GIT_SYNC:-/usr/local/libexec/vacum-git-sync} "$runtime/git.env"
  exit 0
fi
tar -czf - -C "$pkg" backup.env cloudflared.env git.env vaultwarden.env restic | age -r "$(cat "$state_dir/_secrets/age.pub")" -o "$tmp"
chmod 600 "$tmp"; mv -f "$tmp" "$out"
${VACUM_MATERIALIZE:-/usr/local/libexec/vacum-runtime-config}
stack=${VACUM_STACK:-/opt/vaultwarden/.vws/docker-compose.yml}
[[ ! -f $stack ]] || docker compose -f "$stack" up -d --force-recreate vaultwarden cloudflared backup-svc
${VACUM_GIT_SYNC:-/usr/local/libexec/vacum-git-sync} "$runtime/git.env"
