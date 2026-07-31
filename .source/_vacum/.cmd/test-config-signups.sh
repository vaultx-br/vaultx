#!/usr/bin/env bash
set -Eeuo pipefail
base=$(dirname "$(realpath -e "${BASH_SOURCE[0]}")")
d=$(mktemp -d /dev/shm/vacum-signups-test.XXXXXX); trap 'rm -rf "$d"' EXIT
mkdir -p "$d/runtime" "$d/stack" "$d/.source/_env" "$d/bin"
printf 'SIGNUPS_ALLOWED=false\n' > "$d/runtime/vaultwarden.env"; : > "$d/stack/docker-compose.yml"
printf '#!/bin/sh\nprintf "%%s\\n" "$*" >> "$LOG"\n' > "$d/bin/docker"
printf '#!/bin/sh\nexit 1\n' > "$d/bin/systemctl"
printf '#!/bin/sh\nprintf "%%s\\n" "$*" >> "$LOG"\n' > "$d/bin/systemd-run"
chmod +x "$d/bin/"*
D="$d" SCRIPT="$base/config.sh" expect <<'EXPECT'
log_user 0
spawn env VACUM_SOURCE=$env(D) VACUM_RUNTIME=$env(D)/runtime VACUM_STACK=$env(D)/stack VACUM_DOCKER=$env(D)/bin/docker VACUM_SYSTEMCTL=$env(D)/bin/systemctl VACUM_SYSTEMD_RUN=$env(D)/bin/systemd-run LOG=$env(D)/log bash $env(SCRIPT)
expect "VACUM // CONFIG"; send -- "8\r"
expect "cadastro aberto; fechamento automático em 3 minutos"
expect "VACUM // CONFIG"; send -- "0\r"
expect eof
catch wait result; exit [lindex $result 3]
EXPECT
grep -qx 'SIGNUPS_ALLOWED=true' "$d/runtime/vaultwarden.env"
grep -q -- '--on-active=3m' "$d/log"
env VACUM_SOURCE="$d" VACUM_RUNTIME="$d/runtime" VACUM_STACK="$d/stack" VACUM_DOCKER="$d/bin/docker" LOG="$d/log" bash "$base/config.sh" --close-signups >/dev/null
grep -qx 'SIGNUPS_ALLOWED=false' "$d/runtime/vaultwarden.env"
echo 'signup session behavior: OK'
