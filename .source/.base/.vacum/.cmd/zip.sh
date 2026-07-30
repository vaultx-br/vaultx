#!/usr/bin/env bash
set -Eeuo pipefail
root=$(CDPATH= cd -- "$(dirname -- "$0")/../../../.." && pwd)
out=${1:-$root/vacum-bootstrap.zip}
command -v zip >/dev/null || { echo 'zip ausente' >&2; exit 1; }
[ ! -e "$out" ] || { echo 'arquivo já existe' >&2; exit 1; }
[ -f "$root/.source/.base/.secrets/config.age" ] || { echo 'config.age ausente' >&2; exit 1; }
cd "$root"
zip -q -r "$out" .source/.base/.vacum/.cmd/genesis.sh .source/.base .docs \
  -x '.source/.base/.vacum/.bkp/*.age' \
  -x '*.png' \
  -x 'genesis.age' \
  -x '.source/.base/.secrets/genesis.age' \
  -x '.source/.base/_test/*'
printf '%s\n' "$out"
