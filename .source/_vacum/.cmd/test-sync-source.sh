#!/usr/bin/env bash
set -Eeuo pipefail
script=$(dirname "$(realpath -e "${BASH_SOURCE[0]}")")/sync-source.sh
d=$(mktemp -d /dev/shm/vacum-source-sync-test.XXXXXX); trap 'rm -rf "$d"' EXIT
git init -q --bare "$d/remote.git"; git clone -q "$d/remote.git" "$d/seed"
git -C "$d/seed" config user.name test; git -C "$d/seed" config user.email test@localhost
mkdir -p "$d/seed/.source/_vacum/"{.cmd,.bkp}; touch "$d/seed/.source/_vacum/docker-compose.yml" "$d/seed/.source/_vacum/.bkp/entrypoint.sh"
for f in runtime-config secrets-sync git-sync; do printf '#!/bin/sh\n' > "$d/seed/.source/_vacum/.cmd/$f.sh"; done
printf '*.local\n' > "$d/seed/.gitignore"; git -C "$d/seed" add .; git -C "$d/seed" commit -qm initial; git -C "$d/seed" push -q origin master
git clone -q "$d/remote.git" "$d/node"; printf junk > "$d/node/junk"; printf keep > "$d/node/keep.local"
printf updated > "$d/seed/version"; git -C "$d/seed" add version; git -C "$d/seed" commit -qm update; git -C "$d/seed" push -q
mkdir "$d/bin"; for f in secrets-sync systemctl docker; do printf '#!/bin/sh\nexit 0\n' > "$d/bin/$f"; chmod +x "$d/bin/$f"; done
VACUM_TESTING=true VACUM_SOURCE="$d/node" VACUM_STACK_DIR="$d/stack" VACUM_LIBEXEC="$d/libexec" VACUM_SECRETS_SYNC="$d/bin/secrets-sync" VACUM_SYSTEMCTL="$d/bin/systemctl" VACUM_DOCKER="$d/bin/docker" "$script" >/dev/null
test -f "$d/node/version"; test ! -e "$d/node/junk"; test -f "$d/node/keep.local"
[[ $(git -C "$d/node" rev-parse HEAD) == $(git --git-dir="$d/remote.git" rev-parse HEAD) ]]
echo 'source sync behavior: OK'
