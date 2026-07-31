#!/usr/bin/env bash
set -Eeuo pipefail
umask 077
runtime=${VACUM_RUNTIME:-/run/vaultwarden/secrets}
[[ -d $runtime ]] || { echo 'secrets runtime ausentes' >&2; exit 1; }
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
  ask 'Git URL HTTPS: '; [[ $REPLY == https://* ]] || { echo 'URL Git deve usar HTTPS' >&2; return 1; }; local url=$REPLY
  secret 'Git PAT fine-grained: '; [[ -n $REPLY ]] || return 1; local pat=$REPLY
  setkey "$runtime/git.env" GIT_URL "$url"; setkey "$runtime/git.env" GIT_PAT "$pat"
}
add_s3(){
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
  ask 'ntfy URL: '; setkey "$runtime/backup.env" NTFY_URL "$REPLY"
  ask 'ntfy tópico: '; setkey "$runtime/backup.env" NTFY_TOPIC "$REPLY"
  secret 'ntfy token (vazio = sem autenticação): '; setkey "$runtime/backup.env" NTFY_TOKEN "$REPLY"
}
remove_s3(){
  printf 'Nós: ' >/dev/tty; find "$runtime/restic" -maxdepth 1 -type f -name '*.env' -printf '%f ' | sed 's/\.env//g' >/dev/tty; printf '\n' >/dev/tty
  ask 'Nome para remover: '; [[ $REPLY =~ ^[A-Za-z0-9_-]+$ && -f $runtime/restic/$REPLY.env ]] || { echo 'nó ausente' >&2; return 1; }; local name=$REPLY
  ask "Confirmar remoção de $name? [y/N] "; [[ $REPLY =~ ^[Yy]$ ]] || return 0
  rm -f "$runtime/restic/${name}.env"
}
while :; do
  cat >/dev/tty <<'EOF'

VACUM // CONFIG
[1] Git  [2] Adicionar S3  [3] Política de backup  [4] ntfy  [5] Remover S3  [0] Salvar
EOF
  ask '> '
  case $REPLY in 0) exit;; 1) configure_git;; 2) add_s3;; 3) backup_policy;; 4) configure_ntfy;; 5) remove_s3;; *) echo 'opção inválida' >&2;; esac || true
done
