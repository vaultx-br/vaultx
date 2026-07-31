#!/usr/bin/env bash
set -Eeuo pipefail
umask 077
runtime=${VACUM_RUNTIME:-/run/vaultwarden/secrets}
base=$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
source_dir=${VACUM_SOURCE:-$(realpath -e "$base/../../..")}
env_dir=$source_dir/.source/_env
local_secrets=$env_dir/_secrets
stack=${VACUM_STACK:-/opt/vaultwarden/.vws}
need_runtime(){ [[ -d $runtime ]] || { echo 'secrets runtime ausentes' >&2; return 1; }; }
ask(){ printf '%s' "$1" >/dev/tty; IFS= read -r REPLY </dev/tty; [[ $REPLY != *$'\n'* ]]; }
secret(){ printf '%s' "$1" >/dev/tty; IFS= read -rs REPLY </dev/tty; printf '\n' >/dev/tty; }
setkey(){
  local file=$1 key=$2 value=$3 tmp found=false line
  tmp=$(mktemp "$file.XXXXXX")
  while IFS= read -r line || [[ -n $line ]]; do
    if [[ $line == "$key="* ]]; then printf '%s=%s\n' "$key" "$value" >> "$tmp"; found=true; else printf '%s\n' "$line" >> "$tmp"; fi
  done < "$file"
  [[ $found == true ]] || printf '%s=%s\n' "$key" "$value" >> "$tmp"
  chmod 600 "$tmp"; mv -f "$tmp" "$file"
}
configure_git(){
  need_runtime || return
  ask 'Git URL HTTPS: '; [[ $REPLY == https://* ]] || { echo 'URL Git deve usar HTTPS' >&2; return 1; }; local url=$REPLY
  secret 'Git PAT fine-grained: '; [[ -n $REPLY ]] || return 1; local pat=$REPLY
  setkey "$runtime/git.env" GIT_URL "$url"; setkey "$runtime/git.env" GIT_PAT "$pat"
}
add_s3(){
  need_runtime || return
  ask 'Nome do nó (ex.: r2, oracle): '; [[ $REPLY =~ ^[A-Za-z0-9_-]+$ ]] || { echo 'nome inválido' >&2; return 1; }; local name=$REPLY file=$runtime/restic/$REPLY.env
  [[ ! -e $file ]] || { echo 'nó já existe' >&2; return 1; }
  ask 'Restic repository (s3:https://...): '; [[ $REPLY == s3:https://* ]] || { echo 'repositório deve usar s3:https://' >&2; return 1; }; local repo=$REPLY
  secret 'Access key: '; local access=$REPLY; secret 'Secret key: '; local secret_key=$REPLY; secret 'Senha Restic: '; local password=$REPLY
  [[ -n $access && -n $secret_key && -n $password ]] || { echo 'credencial vazia' >&2; return 1; }
  install -d -m 700 "$runtime/restic"
  printf 'ENABLED=true\nREPOSITORY=%s\nACCESS_KEY=%s\nSECRET_KEY=%s\nPASSWORD=%s\n' "$repo" "$access" "$secret_key" "$password" > "$file"
  chmod 600 "$file"
}
backup_policy(){
  need_runtime || return
  local key label default
  while IFS='|' read -r key label default; do
    ask "$label [$default]: "; value=${REPLY:-$default}
    [[ $value =~ ^[0-9]+$ ]] || { echo 'valor deve ser inteiro' >&2; return 1; }
    [[ $key != BACKUP_HOUR || $value -le 23 ]] || { echo 'hora inválida' >&2; return 1; }
    [[ $key != BACKUP_MINUTE || $value -le 59 ]] || { echo 'minuto inválido' >&2; return 1; }
    [[ $key == BACKUP_HOUR || $key == BACKUP_MINUTE || $value -gt 0 ]] || { echo 'valor deve ser maior que zero' >&2; return 1; }
    setkey "$runtime/backup.env" "$key" "$value"
  done <<'EOF'
BACKUP_HOUR|Hora (0-23)|3
BACKUP_MINUTE|Minuto (0-59)|33
BACKUP_KEEP_DAILY|Retenção diária|30
BACKUP_KEEP_MONTHLY|Retenção mensal|12
BACKUP_MAX_GB|Limite GB|4
EOF
}
configure_ntfy(){
  need_runtime || return
  ask 'ntfy URL: '; setkey "$runtime/backup.env" NTFY_URL "$REPLY"
  ask 'ntfy tópico: '; setkey "$runtime/backup.env" NTFY_TOPIC "$REPLY"
  secret 'ntfy token (vazio = sem autenticação): '; setkey "$runtime/backup.env" NTFY_TOKEN "$REPLY"
}
remove_s3(){
  need_runtime || return
  printf 'Nós: ' >/dev/tty; find "$runtime/restic" -maxdepth 1 -type f -name '*.env' -printf '%f ' | sed 's/\.env//g' >/dev/tty; printf '\n' >/dev/tty
  ask 'Nome para remover: '; [[ $REPLY =~ ^[A-Za-z0-9_-]+$ && -f $runtime/restic/$REPLY.env ]] || { echo 'nó ausente' >&2; return 1; }; local name=$REPLY
  ask "Confirmar remoção de $name? [y/N] "; [[ $REPLY =~ ^[Yy]$ ]] || return 0
  rm -f "$runtime/restic/${name}.env"
}
validate_local_secrets(){
  local f
  for f in backup.env cloudflared.env git.env vaultwarden.env; do [[ -f $local_secrets/$f ]] || { echo "secret ausente: $f" >&2; return 1; }; done
  find "$local_secrets/restic" -maxdepth 1 -type f -name '*.env' -print -quit 2>/dev/null | grep -q . || { echo 'nenhum nó Restic' >&2; return 1; }
}
create_genesis(){
  validate_local_secrets || return
  install -d -m 700 "$env_dir"
  "$base/genesis.sh" "$env_dir/genesis.age" "$local_secrets" "$env_dir/secrets.age"
}
close_signups(){
  need_runtime || return
  setkey "$runtime/vaultwarden.env" SIGNUPS_ALLOWED false
  "${VACUM_DOCKER:-docker}" compose -f "$stack/docker-compose.yml" up -d --force-recreate vaultwarden
  echo 'cadastros fechados'
}
signup_session(){
  need_runtime || return
  command -v "${VACUM_SYSTEMD_RUN:-systemd-run}" >/dev/null || { echo 'systemd-run ausente' >&2; return 1; }
  "${VACUM_SYSTEMCTL:-systemctl}" is-active --quiet vacum-signups-close.timer && { echo 'sessão de cadastro já está ativa' >&2; return 1; }
  setkey "$runtime/vaultwarden.env" SIGNUPS_ALLOWED true
  if ! "${VACUM_DOCKER:-docker}" compose -f "$stack/docker-compose.yml" up -d --force-recreate vaultwarden; then setkey "$runtime/vaultwarden.env" SIGNUPS_ALLOWED false; return 1; fi
  if ! "${VACUM_SYSTEMD_RUN:-systemd-run}" --quiet --unit=vacum-signups-close --on-active=3m --setenv="VACUM_RUNTIME=$runtime" --setenv="VACUM_STACK=$stack" "$base/config.sh" --close-signups; then close_signups; return 1; fi
  echo 'cadastros liberados por 3 minutos'
}
[[ ${1:-} != --close-signups ]] || { close_signups; exit; }
create_secrets(){
  local d tmp
  validate_local_secrets || return
  [[ -f $env_dir/genesis.age ]] || { echo 'Genesis ausente; crie-o primeiro' >&2; return 1; }
  d=$(mktemp -d "${TMPDIR:-/dev/shm}/vacum-seal.XXXXXX")
  if ! age -d -o "$d/restore.sh" "$env_dir/genesis.age"; then rm -rf "$d"; return 1; fi
  sh "$d/restore.sh" "$d/key"
  tmp=$(mktemp "$env_dir/secrets.age.XXXXXX")
  if ! tar -czf - -C "$local_secrets" backup.env cloudflared.env git.env vaultwarden.env restic | age -r "$(cat "$d/key/age.pub")" -o "$tmp"; then rm -rf "$d" "$tmp"; return 1; fi
  chmod 600 "$tmp"; mv -f "$tmp" "$env_dir/secrets.age"; rm -rf "$d"
  echo 'secrets.age criado'
}
while :; do
  cat >/dev/tty <<'EOF'

VACUM // CONFIG
[1] Git              [4] ntfy          [7] Criar secrets.age
[2] Adicionar S3     [5] Remover S3    [8] Cadastro por 3 min
[3] Política backup  [6] Criar Genesis [0] Salvar
EOF
  ask '> '
  case $REPLY in 0) exit;; 1) configure_git;; 2) add_s3;; 3) backup_policy;; 4) configure_ntfy;; 5) remove_s3;; 6) create_genesis;; 7) create_secrets;; 8) signup_session;; *) echo 'opção inválida' >&2;; esac || true
done
