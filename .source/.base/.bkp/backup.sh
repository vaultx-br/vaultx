#!/bin/sh
set -eu
: "${NTFY_URL:?NTFY_URL missing}"; : "${NTFY_TOPIC:?NTFY_TOPIC missing}"
notify(){ curl -fsS -X POST "$NTFY_URL/$NTFY_TOPIC" -H 'Title: Vaultwarden backup' -H "Priority: $1" -d "$2" >/dev/null; }
fail(){ notify high "Falha: $*" || true; exit 1; }
trap 'rm -rf /stage/*' EXIT
rm -rf /stage/*
[ -f /data/db.sqlite3 ] || fail 'SQLite ausente'
sqlite3 /data/db.sqlite3 ".backup '/stage/db.sqlite3'" || fail 'SQLite backup'
[ -d /data/attachments ] && cp -a /data/attachments /stage/
for f in /data/rsa_key*; do [ -e "$f" ] && cp -a "$f" /stage/; done

nodes=$(env | sed -n 's/^RESTIC_\([0-9][0-9]*\)_REPOSITORY=.*/\1/p' | sort -n)
[ -n "$nodes" ] || fail 'nenhum nó Restic configurado'
failed=0
for n in $nodes; do
  get(){ printenv "RESTIC_${n}_$1" 2>/dev/null || :; }
  [ "$(get ENABLED)" = false ] && continue
  repo=$(get REPOSITORY); password=$(get PASSWORD)
  access=$(get ACCESS_KEY); secret=$(get SECRET_KEY)
  [ -n "$repo" ] && [ -n "$password" ] && [ -n "$access" ] && [ -n "$secret" ] || { failed=1; continue; }
  export RESTIC_REPOSITORY="$repo" RESTIC_PASSWORD="$password"
  export AWS_ACCESS_KEY_ID="$access" AWS_SECRET_ACCESS_KEY="$secret"
  if ! restic snapshots >/dev/null 2>&1; then restic init >/dev/null 2>&1 || { failed=1; continue; }; fi
  restic backup /stage --tag vaultwarden || { failed=1; continue; }
  restic forget --keep-daily 30 --keep-monthly 12 --prune || { failed=1; continue; }
  size=$(restic stats --mode raw-data --json | jq -r '.total_size // 0')
  [ "$size" -le 4294967296 ] || { failed=1; continue; }
done
[ "$failed" -eq 0 ] || fail 'um ou mais nós falharam'
notify default 'Backup concluído'
