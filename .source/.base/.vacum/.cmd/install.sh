#!/usr/bin/env bash
set -Eeuo pipefail
umask 077
repo=${VACUM_REPOSITORY:-https://github.com/vaultx-br/vaultx.git}
target=${VACUM_TARGET:-/opt/vacum-src}

say(){ printf '\033[32m%s\033[0m\n' "$*" >/dev/tty; }
ask(){ printf '%s' "$1" >/dev/tty; IFS= read -r REPLY </dev/tty; }
[[ ${1:-install} == install ]] || { echo 'uso: install.sh [install]' >&2; exit 2; }
[[ -r /etc/os-release ]] || { echo 'Ubuntu necessário' >&2; exit 1; }
. /etc/os-release
[[ ${ID:-} == ubuntu ]] || { echo 'Ubuntu necessário' >&2; exit 1; }
if ((EUID)); then command -v sudo >/dev/null || { echo 'sudo ausente' >&2; exit 1; }; sudo=sudo; else sudo=; fi

say 'VACUM // INSTALL'
ask "Instalar em $target? [S/n] "
[[ ${REPLY:-s} =~ ^[SsYy]?$ ]] || exit 0
command -v git >/dev/null || { $sudo apt-get -qq update; $sudo apt-get -qq install -y git; }
[[ ! -e $target ]] || { echo "$target já existe" >&2; exit 1; }
$sudo git clone --depth 1 "$repo" "$target"
$sudo ln -sfn "$target/.source/.base/.vacum/.cmd/vacum" /usr/local/bin/vacum

ask 'Caminho do genesis.age na VM (vazio para colar): '
args=()
if [[ -n $REPLY ]]; then
  [[ -f $REPLY ]] || { echo 'genesis.age ausente' >&2; exit 1; }
  args+=(--genesis-file "$REPLY")
else
  say 'Cole o genesis.age completo; finalize com Ctrl-D.'
fi
say 'Iniciando bootstrap...'
exec $sudo "$target/.source/.base/.vacum/.cmd/bootstrap.sh" "${args[@]}" </dev/tty
