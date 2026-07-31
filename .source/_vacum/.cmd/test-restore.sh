#!/usr/bin/env bash
set -Eeuo pipefail
script=$(dirname "$(realpath -e "${BASH_SOURCE[0]}")")/../.bkp/restore
d=$(mktemp -d /dev/shm/vacum-restore-test.XXXXXX); trap 'rm -rf "$d"' EXIT
mkdir -p "$d"/{bin,target}
cat > "$d/bin/restic" <<'EOF'
#!/bin/sh
mkdir -p "$4/stage"; : > "$4/stage/db.sqlite3"; : > "$4/stage/rsa_key.pem"
EOF
printf '#!/bin/sh\nprintf "ok\\n"\n' > "$d/bin/sqlite3"; chmod +x "$d/bin"/*
sed "s#/restore#$d/target#g;s#/tmp/vacum-restore#$d/tmp#g" "$script" > "$d/restore"; chmod +x "$d/restore"
envs=(RESTIC_1_NAME=r2 RESTIC_1_ENABLED=true RESTIC_1_REPOSITORY=x RESTIC_1_PASSWORD=x RESTIC_1_ACCESS_KEY=x RESTIC_1_SECRET_KEY=x)
env PATH="$d/bin:$PATH" "${envs[@]}" "$d/restore" r2 latest >/dev/null
[[ -f $d/target/db.sqlite3 && -f $d/target/rsa_key.pem ]]
if env PATH="$d/bin:$PATH" "${envs[@]}" "$d/restore" r2 latest >/dev/null 2>&1; then
  echo 'destino não vazio deveria falhar' >&2; exit 1
fi
rm -rf "$d/target"; mkdir "$d/target"
if env PATH="$d/bin:$PATH" "${envs[@]}" "$d/restore" missing latest >/dev/null 2>&1; then
  echo 'nome inexistente deveria falhar' >&2; exit 1
fi
if env PATH="$d/bin:$PATH" "${envs[@]}" RESTIC_2_NAME=r2 "$d/restore" r2 latest >/dev/null 2>&1; then
  echo 'nome duplicado deveria falhar' >&2; exit 1
fi
printf '%s\n' 'restore behavior: OK'
