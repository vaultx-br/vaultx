#!/bin/sh
set -eu;umask 077
b=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd);o=${1:-$b/genesis.age};[ ! -e "$o" ]||exit 1
d=$(mktemp -d "${TMPDIR:-/dev/shm}/g.XXXXXX");trap 'rm -rf "$d"' EXIT
age-keygen -o "$d/k" 2>/dev/null
k=$(cat "$d/k");p=$(age-keygen -y "$d/k")
printf '#!/bin/sh\nset -eu;umask 077\nd=${1:-_secrets};[ ! -L "$d" ]||exit 1;mkdir -p "$d";chmod 700 "$d";[ ! -e "$d/age.key" ]&&[ ! -L "$d/age.key" ]&&[ ! -e "$d/age.pub" ]&&[ ! -L "$d/age.pub" ]||exit 1;printf "%%s\\n" "%s" > "$d/age.key";printf "%%s\\n" "%s" > "$d/age.pub"\n' "$k" "$p" > "$d/r"
age -p -a -o "$o" "$d/r"
{ printf '%s\n' 'cat > genesis.age <<'"'"'GENESIS_EOF'"'"''; cat "$o"; printf '%s\n' GENESIS_EOF; } > "$d/q"
n=$(wc -c < "$d/q");[ "$n" -le 1273 ]||exit 1
qrencode -l H -8 -o "${o%.age}.png" < "$d/q"