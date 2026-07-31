#!/usr/bin/env bash
set -Eeuo pipefail
umask 077
root=${VACUM_SOURCE:-/opt/vacum-src}
git_env=${1:-/run/vaultwarden/secrets/git.env}
[[ -r $git_env ]] || { echo 'git.env ausente' >&2; exit 1; }
get(){ sed -n "s/^$1=//p" "$git_env" | tail -1; }
pat=$(get GIT_PAT); url=$(get GIT_URL)
[[ -n $pat && -n $url ]] || { echo 'Git URL/PAT ausente' >&2; exit 1; }
cd "$root"
git -c safe.directory="$root" rev-parse --is-inside-work-tree >/dev/null
git -c safe.directory="$root" remote set-url origin "$url"
staged=$(git -c safe.directory="$root" diff --cached --name-only)
[[ -z $staged || $staged == .source/_env/secrets.age ]] || { echo 'há outros arquivos staged; sync recusado' >&2; exit 1; }
git -c safe.directory="$root" add .source/_env/secrets.age
if ! git -c safe.directory="$root" diff --cached --quiet; then
  git -c safe.directory="$root" diff --cached --check
  GIT_AUTHOR_NAME=${GIT_AUTHOR_NAME:-vacum} GIT_AUTHOR_EMAIL=${GIT_AUTHOR_EMAIL:-vacum@localhost} \
  GIT_COMMITTER_NAME=${GIT_COMMITTER_NAME:-vacum} GIT_COMMITTER_EMAIL=${GIT_COMMITTER_EMAIL:-vacum@localhost} \
  git -c safe.directory="$root" commit -m 'chore: sync encrypted secrets' >/dev/null
fi
ask=$(mktemp /dev/shm/git-askpass.XXXXXX); patfile=$(mktemp /dev/shm/git-pat.XXXXXX); trap 'rm -f "$ask" "$patfile"' EXIT
printf %s "$pat" > "$patfile"; chmod 600 "$patfile"
printf '#!/bin/sh\ncase $1 in *Username*) printf "%%s\\n" x-access-token;; *) cat %q;; esac\n' "$patfile" > "$ask"; chmod 700 "$ask"
GIT_ASKPASS="$ask" GIT_TERMINAL_PROMPT=0 git -c safe.directory="$root" push
