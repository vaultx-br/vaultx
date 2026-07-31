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
owner=${SUDO_USER:-$(id -un)}
group=$(id -gn "$owner")

tmp_genesis=
created=false
cleanup(){
  [ -z "$tmp_genesis" ] || rm -f "$tmp_genesis"
  if [[ $created == true && ${bootstrap_ok:-false} != true ]]; then
    $sudo rm -f /usr/local/bin/vacum
    $sudo rm -rf -- "$target"
  fi
}
trap cleanup EXIT HUP INT TERM

say 'VACUM // INSTALL'
ask "Instalar em $target? [S/n] "
[[ ${REPLY:-s} =~ ^[SsYy]?$ ]] || exit 0
command -v git >/dev/null || { $sudo apt-get -qq update; $sudo apt-get -qq install -y git; }
[[ ! -e $target ]] || { echo "$target já existe" >&2; exit 1; }
$sudo git clone --depth 1 "$repo" "$target"
created=true
$sudo chown -R "$owner:$group" "$target"
$sudo ln -sfn "$target/.source/_main/.bin/vacum" /usr/local/bin/vacum

ask 'Caminho do genesis.age na VM (vazio para colar): '
args=()
if [[ -n $REPLY ]]; then
  [[ -f $REPLY ]] || { echo 'genesis.age ausente' >&2; exit 1; }
  args+=(--genesis-file "$REPLY")
else
  say 'Cole o genesis.age completo; finalize com Ctrl-D.'
  tmp_genesis=$(mktemp "${TMPDIR:-/dev/shm}/vacum-genesis.XXXXXX")
  chmod 600 "$tmp_genesis"
  cat </dev/tty > "$tmp_genesis"
  args+=(--genesis-file "$tmp_genesis")
fi
ask 'Abrir menu de configuração antes de iniciar os serviços? [S/n] '
[[ ${REPLY:-s} =~ ^[SsYy]?$ ]] && args+=(--configure)
say 'Iniciando bootstrap...'
$sudo "$target/.source/_vacum/.cmd/bootstrap.sh" "${args[@]}" </dev/tty
bootstrap_ok=true
