#!/usr/bin/env bash
set -Eeuo pipefail
umask 077
password_file=
genesis_file=
secrets_file=
compose_file=
configure=false
while (($#)); do
  case $1 in
    --password-file) password_file=${2:?}; shift 2;;
    --genesis-file) genesis_file=${2:?}; shift 2;;
    --secrets-file|--config-file) secrets_file=${2:?}; shift 2;;
    --compose-file) compose_file=${2:?}; shift 2;;
    --configure) configure=true; shift;;
    *) echo "opção inválida" >&2; exit 1;;
  esac
done

(( EUID == 0 )) || { echo 'execute como root' >&2; exit 1; }
base=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
source_dir=$(realpath -e "$base/../../..")
secrets_file=${secrets_file:-$base/../../_secrets/secrets.age}
compose_file=${compose_file:-$base/../docker-compose.yml}
backup_dir=$base/../.bkp
for f in genesis_file password_file secrets_file compose_file; do
  [ -z "${!f}" ] && continue
  [[ -e ${!f} ]] || { echo "${f%_file} ausente" >&2; exit 1; }
  printf -v "$f" '%s' "$(realpath -e "${!f}")"
done
. /etc/os-release
[[ ${ID:-} == ubuntu ]] || { echo 'Ubuntu necessário' >&2; exit 1; }

need=()
for pair in \
  docker:docker.io \
  age:age \
  curl:curl \
  git:git \
  sshd:openssh-server \
  expect:expect \
  ufw:ufw \
  fail2ban:fail2ban \
  unattended-upgrade:unattended-upgrades; do
  cmd=${pair%%:*}; pkg=${pair#*:}
  command -v "$cmd" >/dev/null || need+=("$pkg")
done
command -v docker >/dev/null && docker compose version >/dev/null 2>&1 || need+=(docker-compose-v2)
if ((${#need[@]})); then
  apt-get -qq update
  DEBIAN_FRONTEND=noninteractive apt-get -qq -o Dpkg::Use-Pty=0 install -y "${need[@]}"
fi
systemctl enable --now docker >/dev/null
systemctl enable --now fail2ban >/dev/null
systemctl enable --now unattended-upgrades >/dev/null
install -d -m 700 /opt/vaultwarden

ufw default deny incoming >/dev/null
ufw default allow outgoing >/dev/null
ufw allow 22/tcp >/dev/null
ufw --force enable >/dev/null

install -d -m 755 /etc/ssh/sshd_config.d /run/sshd
printf 'Port 22\nPasswordAuthentication no\nPermitRootLogin no\n' \
  > /etc/ssh/sshd_config.d/vacum.conf
sshd -t
systemctl enable ssh >/dev/null
if systemctl is-active --quiet ssh; then systemctl reload ssh >/dev/null; else systemctl start ssh >/dev/null; fi

cd /opt/vaultwarden
d=$(mktemp -d "${TMPDIR:-/dev/shm}/bootstrap.XXXXXX"); trap 'rm -rf "$d" /run/vaultwarden/restore.sh' EXIT
if [[ -n "$genesis_file" ]]; then
  [[ -f "$genesis_file" ]] || { echo "genesis ausente" >&2; exit 1; }
  cp "$genesis_file" "$d/raw"
else
  printf 'Cole o genesis.age completo e termine com Ctrl-D:\n' >&2
  cat > "$d/raw"
fi
install -d -m 700 /run/vaultwarden
awk '
  function trim(s){gsub(/^[[:space:]]+|[[:space:]]+$/, "", s);return s}
  { s=trim($0)
    if(s=="-----BEGIN AGE ENCRYPTED FILE-----"){inside=1;next}
    if(s=="-----END AGE ENCRYPTED FILE-----"){end=1;next}
    if(inside&&!end){gsub(/[[:space:]]/,"",s);body=body s}
  }
  END{
    if(!body||!end) exit 1
    print "-----BEGIN AGE ENCRYPTED FILE-----"
    for(i=1;i<=length(body);i+=64) print substr(body,i,64)
    print "-----END AGE ENCRYPTED FILE-----"
  }
' "$d/raw" > "$d/genesis.age"
if [[ -n "$password_file" ]]; then
  [[ -f "$password_file" ]] || { echo "senha ausente" >&2; exit 1; }
  mode=$(stat -c '%a' "$password_file")
  [[ "$mode" == 600 ]] || { echo "senha deve ter permissão 600" >&2; exit 1; }
  OUTFILE=/run/vaultwarden/restore.sh PWFILE="$password_file" GENESIS="$d/genesis.age" expect <<'EXPECT'
  log_user 0
  spawn age -d -o $env(OUTFILE) $env(GENESIS)
  expect "Enter passphrase:"
  set f [open $env(PWFILE) r]
  set pw [read $f]
  close $f
  send -- "$pw\r"
  expect eof
EXPECT
  bash /run/vaultwarden/restore.sh /opt/vaultwarden/_secrets
  rm -f /run/vaultwarden/restore.sh
else
  age -d -o /run/vaultwarden/restore.sh "$d/genesis.age"
  bash /run/vaultwarden/restore.sh /opt/vaultwarden/_secrets
  rm -f /run/vaultwarden/restore.sh
fi

[[ -f "$secrets_file" ]] || { echo 'secrets.age ausente' >&2; exit 1; }
[[ -f "$compose_file" ]] || { echo 'Compose ausente' >&2; exit 1; }
install -d -m 755 /usr/local/libexec
install -m 755 "$base/runtime-config.sh" /usr/local/libexec/vacum-runtime-config
install -m 755 "$base/secrets-sync.sh" /usr/local/libexec/vacum-secrets-sync
install -m 755 "$base/git-sync.sh" /usr/local/libexec/vacum-git-sync
cat > /etc/systemd/system/vacum-runtime-config.service <<EOF
[Unit]
Description=Materializa configuração runtime do VACUM
After=local-fs.target
Before=docker.service

[Service]
Type=oneshot
Environment="VACUM_SOURCE=$source_dir"
Environment="VACUM_SECRETS=$secrets_file"
ExecStart=/usr/local/libexec/vacum-runtime-config
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF
cat > /etc/systemd/system/vacum-secrets-sync.service <<'EOF'
[Unit]
Description=Sincroniza secrets.age do VACUM
After=network-online.target vacum-runtime-config.service

[Service]
Type=oneshot
ExecStart=/usr/local/libexec/vacum-secrets-sync
EOF
cat > /etc/systemd/system/vacum-secrets-sync.timer <<'EOF'
[Unit]
Description=Sincronização periódica do secrets.age

[Timer]
OnBootSec=5min
OnUnitActiveSec=5min
Persistent=true

[Install]
WantedBy=timers.target
EOF
systemctl daemon-reload
systemctl enable vacum-runtime-config.service vacum-secrets-sync.timer >/dev/null
VACUM_SECRETS="$secrets_file" VACUM_SOURCE="$base/../../.." /usr/local/libexec/vacum-runtime-config
runtime=/run/vaultwarden/secrets
all="$runtime/vaultwarden.env $runtime/cloudflared.env $runtime/backup.env $runtime/git.env"
grep -Eq '=(change-me|CHANGE_ME)$' $all && { echo 'configuração contém placeholder' >&2; exit 1; }
hour=$(sed -n 's/^BACKUP_HOUR=//p' "$runtime/backup.env"); minute=$(sed -n 's/^BACKUP_MINUTE=//p' "$runtime/backup.env")
[[ ${hour:-3} =~ ^[0-9]+$ && ${minute:-33} =~ ^[0-9]+$ && ${hour:-3} -le 23 && ${minute:-33} -le 59 ]] || { echo 'horário de backup inválido' >&2; exit 1; }
grep -Eq '^RESTIC_[0-9]+_ENABLED=true$' "$runtime/backup.env" || { echo 'nenhum nó Restic habilitado' >&2; exit 1; }
if [[ $configure == true ]]; then
  VACUM_RUNTIME="$runtime" "$base/config.sh"
  VACUM_SOURCE="$base/../../.." VACUM_STACK=/nonexistent /usr/local/libexec/vacum-secrets-sync || echo 'aviso: configuração aplicada; push Git pendente' >&2
  grep -Eq '^RESTIC_[0-9]+_ENABLED=true$' "$runtime/backup.env" || { echo 'nenhum nó Restic habilitado' >&2; exit 1; }
fi
stack_dir=/opt/vaultwarden/.vws
install -d -m 700 "$stack_dir"
cp "$compose_file" "$stack_dir/docker-compose.yml"
[ -d "$backup_dir" ] || { echo 'Backup SVC ausente' >&2; exit 1; }
rm -rf "$stack_dir/.bkp"
cp -a "$backup_dir" "$stack_dir/.bkp"
cd "$stack_dir"
docker compose config -q
docker compose up -d
