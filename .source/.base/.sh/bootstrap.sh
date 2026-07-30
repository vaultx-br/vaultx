#!/usr/bin/env bash
set -Eeuo pipefail
umask 077
password_file=
genesis_file=
config_file=
compose_file=
while (($#)); do
  case $1 in
    --password-file) password_file=${2:?}; shift 2;;
    --genesis-file) genesis_file=${2:?}; shift 2;;
    --config-file) config_file=${2:?}; shift 2;;
    --compose-file) compose_file=${2:?}; shift 2;;
    *) echo "opção inválida" >&2; exit 1;;
  esac
done

(( EUID == 0 )) || { echo 'execute como root' >&2; exit 1; }
base=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
config_file=${config_file:-$base/../.secrets/config.age}
compose_file=${compose_file:-$base/../.vws/docker-compose.yml}
bkp_dir=${base%/.sh}/.bkp
. /etc/os-release
[[ ${ID:-} == ubuntu ]] || { echo 'Ubuntu necessário' >&2; exit 1; }

need=()
for pair in \
  docker:docker.io \
  age:age \
  restic:restic \
  curl:curl \
  git:git \
  jq:jq \
  openssl:openssl \
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

install -d -m 755 /etc/ssh/sshd_config.d
printf 'Port 22\nPasswordAuthentication no\nPermitRootLogin no\n' \
  > /etc/ssh/sshd_config.d/vacum.conf
sshd -t
systemctl reload ssh >/dev/null

cd /opt/vaultwarden
d=$(mktemp -d "${TMPDIR:-/dev/shm}/bootstrap.XXXXXX"); trap 'rm -rf "$d" /run/vaultwarden/restore.sh' EXIT
[[ ! -e genesis.age ]] || { echo 'genesis.age já existe' >&2; exit 1; }
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
' "$d/raw" > genesis.age
if [[ -n "$password_file" ]]; then
  [[ -f "$password_file" ]] || { echo "senha ausente" >&2; exit 1; }
  mode=$(stat -c '%a' "$password_file")
  [[ "$mode" == 600 ]] || { echo "senha deve ter permissão 600" >&2; exit 1; }
  OUTFILE=/run/vaultwarden/restore.sh PWFILE="$password_file" expect <<'EXPECT'
  log_user 0
  spawn age -d -o $env(OUTFILE) genesis.age
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
  age -d -o /run/vaultwarden/restore.sh genesis.age
  bash /run/vaultwarden/restore.sh /opt/vaultwarden/_secrets
  rm -f /run/vaultwarden/restore.sh
fi

[[ -f "$config_file" ]] || { echo 'config.age ausente' >&2; exit 1; }
[[ -f "$compose_file" ]] || { echo 'Compose ausente' >&2; exit 1; }
age -d -i /opt/vaultwarden/_secrets/age.key -o "$d/config.env" "$config_file"
install -o root -g root -m 600 "$d/config.env" /run/vaultwarden/config.env.tmp
mv -f /run/vaultwarden/config.env.tmp /run/vaultwarden/config.env
stack_dir=/opt/vaultwarden/.vws
install -d -m 700 "$stack_dir"
cp "$compose_file" "$stack_dir/docker-compose.yml"
[ -d "$bkp_dir" ] || { echo 'Backup SVC ausente' >&2; exit 1; }
rm -rf /opt/vaultwarden/.bkp
cp -a "$bkp_dir" /opt/vaultwarden/.bkp
cd "$stack_dir"
docker compose config -q
docker compose up -d
