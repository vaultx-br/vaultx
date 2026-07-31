#!/bin/sh
set -eu
umask 077
b=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
o=${1:-$b/genesis.age}
secrets_dir=${2:-}
secrets_out=${3:-}
[ ! -e "$o" ] || { echo 'Genesis já existe' >&2; exit 1; }
d=$(mktemp -d "${TMPDIR:-/dev/shm}/g.XXXXXX"); trap 'rm -rf "$d"' EXIT
age-keygen -o "$d/k" 2>/dev/null
k=$(cat "$d/k"); p=$(age-keygen -y "$d/k")
printf '#!/bin/sh\nset -eu;umask 077\nd=${1:-_secrets};[ ! -L "$d" ]||exit 1;mkdir -p "$d";chmod 700 "$d";[ ! -e "$d/age.key" ]&&[ ! -L "$d/age.key" ]&&[ ! -e "$d/age.pub" ]&&[ ! -L "$d/age.pub" ]||exit 1;printf "%%s\\n" "%s" > "$d/age.key";printf "%%s\\n" "%s" > "$d/age.pub"\n' "$k" "$p" > "$d/r"
age -p -a -o "$o" "$d/r"
{ printf '%s\n' 'cat > genesis.age <<'"'"'GENESIS_EOF'"'"''; cat "$o"; printf '%s\n' GENESIS_EOF; } > "$d/q"
[ "$(wc -c < "$d/q")" -le 1273 ] || exit 1
qrencode -l H -8 -o "${o%.age}.png" < "$d/q"
[ -n "$secrets_dir" ] || exit 0
printf 'Criar secrets.age agora? [S/n] ' >/dev/tty
IFS= read -r answer </dev/tty
case ${answer:-s} in [SsYy]*) ;; *) exit 0;; esac
for f in backup.env cloudflared.env git.env vaultwarden.env; do [ -f "$secrets_dir/$f" ] || { echo "secret ausente: $f" >&2; exit 1; }; done
find "$secrets_dir/restic" -maxdepth 1 -type f -name '*.env' -print -quit | grep -q . || { echo 'nenhum nó Restic' >&2; exit 1; }
[ -n "$secrets_out" ] || { echo 'destino de secrets.age ausente' >&2; exit 1; }
tmp=$(mktemp "$secrets_out.XXXXXX")
tar -czf - -C "$secrets_dir" backup.env cloudflared.env git.env vaultwarden.env restic | age -r "$p" -o "$tmp"
chmod 600 "$tmp"; mv -f "$tmp" "$secrets_out"
printf 'Genesis e secrets.age criados\n'
