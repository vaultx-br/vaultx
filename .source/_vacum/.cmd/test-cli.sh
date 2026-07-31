#!/usr/bin/env bash
set -Eeuo pipefail
cli=$(dirname "$(realpath -e "${BASH_SOURCE[0]}")")/cli
grep -Fq 'backup) need_stack; compose exec -T backup-svc /usr/local/bin/backup ;;' "$cli"
! sed -n '/doctor(){/,/^}/p' "$cli" | grep -Fq 'exec -T backup-svc /usr/local/bin/backup'
