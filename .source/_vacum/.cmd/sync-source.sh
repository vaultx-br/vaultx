#!/usr/bin/env bash
set -Eeuo pipefail
source_dir=${VACUM_SOURCE:-/opt/vacum-src}
stack=${VACUM_STACK_DIR:-/opt/vaultwarden/.vws}
libexec=${VACUM_LIBEXEC:-/usr/local/libexec}
base=$source_dir/.source/_vacum
[[ $EUID -eq 0 || ${VACUM_TESTING:-false} == true ]] || { echo 'execute como root' >&2; exit 1; }
[[ -d $source_dir/.git ]] || { echo 'clone VACUM ausente' >&2; exit 1; }
${VACUM_SECRETS_SYNC:-$libexec/vacum-secrets-sync}
git -C "$source_dir" fetch origin master
git -C "$source_dir" reset --hard origin/master
git -C "$source_dir" clean -fd
install -d -m 755 "$libexec"
install -m 755 "$base/.cmd/runtime-config.sh" "$libexec/vacum-runtime-config"
install -m 755 "$base/.cmd/secrets-sync.sh" "$libexec/vacum-secrets-sync"
install -m 755 "$base/.cmd/git-sync.sh" "$libexec/vacum-git-sync"
install -d -m 700 "$stack"
install -m 600 "$base/docker-compose.yml" "$stack/docker-compose.yml"
rm -rf "$stack/.bkp"; cp -a "$base/.bkp" "$stack/.bkp"
"${VACUM_SYSTEMCTL:-systemctl}" daemon-reload
"${VACUM_SYSTEMCTL:-systemctl}" enable --now vacum-secrets-sync.timer >/dev/null
"${VACUM_DOCKER:-docker}" compose -f "$stack/docker-compose.yml" config -q
"${VACUM_DOCKER:-docker}" compose -f "$stack/docker-compose.yml" up -d --build
printf 'VACUM: SYNC OK (%s)\n' "$(git -C "$source_dir" rev-parse --short HEAD)"
