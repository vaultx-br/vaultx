#!/usr/bin/env bash
set -Eeuo pipefail
backup=$(dirname "$(realpath -e "${BASH_SOURCE[0]}")")/../.bkp/backup
stats=$(grep -n 'restic stats --mode raw-data' "$backup" | head -n1 | cut -d: -f1)
limit=$(grep -n '\[ "$size" -ge "$MAX_BYTES" \]' "$backup" | cut -d: -f1)
upload=$(grep -n 'restic backup /stage' "$backup" | cut -d: -f1)
grep -q 'restic forget --group-by paths,tags' "$backup"
[[ $stats -lt $limit && $limit -lt $upload ]]
