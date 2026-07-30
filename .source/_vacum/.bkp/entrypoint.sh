#!/bin/sh
set -eu
: "${TZ:=America/Fortaleza}"
: "${BACKUP_MINUTE:=33}"
: "${BACKUP_HOUR:=3}"
printf '%s %s * * * /usr/local/bin/backup\n' "$BACKUP_MINUTE" "$BACKUP_HOUR" > /etc/crontabs/root
exec crond -f -l 2
