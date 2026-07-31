#!/usr/bin/env bash
set -Eeuo pipefail
root=$(CDPATH= cd -- "$(dirname -- "$0")/../../.." && pwd)
out=${1:-$root/vacum-bootstrap.zip}
command -v zip >/dev/null || { echo 'zip ausente' >&2; exit 1; }
[ ! -e "$out" ] || { echo 'arquivo já existe' >&2; exit 1; }
[ -f "$root/.source/_env/secrets.age" ] || { echo 'secrets.age ausente' >&2; exit 1; }
cd "$root"
zip -q -r "$out" .source/_vacum .source/_main .source/_env/secrets.age .source/_env/_sample .docs \
  -x '.source/_vacum/.bkp/*.age' \
  -x '*.png' \
  -x 'genesis.age' \
  -x '.source/_env/genesis.age' \
  -x '.source/_test/*'
printf '%s\n' "$out"
