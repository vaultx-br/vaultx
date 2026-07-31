#!/usr/bin/env bash
set -Eeuo pipefail
base=$(dirname "$(realpath -e "${BASH_SOURCE[0]}")")
d=$(mktemp -d /dev/shm/vacum-genesis-test.XXXXXX); trap 'rm -rf "$d"' EXIT
mkdir -p "$d/secrets/restic"; for f in backup cloudflared git vaultwarden; do : > "$d/secrets/$f.env"; done; : > "$d/secrets/restic/r2.env"
GENESIS="$d/genesis.age" SECRETS="$d/secrets" OUT="$d/secrets.age" SCRIPT="$base/genesis.sh" expect <<'EXPECT'
log_user 0
spawn $env(SCRIPT) $env(GENESIS) $env(SECRETS) $env(OUT)
expect "Enter passphrase"; send -- "test-passphrase\r"
expect "Confirm passphrase"; send -- "test-passphrase\r"
expect "Criar secrets.age agora?"; send -- "s\r"
expect eof
catch wait result; exit [lindex $result 3]
EXPECT
test -s "$d/genesis.age" -a -s "$d/genesis.png" -a -s "$d/secrets.age"
test -z "$(find "$d" -iname '*password*' -print -quit)"
RESTORE="$d/restore.sh" GENESIS="$d/genesis.age" expect <<'EXPECT'
log_user 0
spawn age -d -o $env(RESTORE) $env(GENESIS)
expect "Enter passphrase"; send -- "test-passphrase\r"
expect eof
catch wait result; exit [lindex $result 3]
EXPECT
sh "$d/restore.sh" "$d/key"
age -d -i "$d/key/age.key" "$d/secrets.age" | tar -tzf - | grep -qx 'restic/r2.env'
echo 'genesis behavior: OK'
