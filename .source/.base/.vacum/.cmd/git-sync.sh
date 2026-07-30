#!/usr/bin/env bash
set -Eeuo pipefail
umask 077
root=$(CDPATH= cd -- "$(dirname -- "$0")/../../../.." && pwd)
pat=${1:-/run/vaultwarden/git-pat}
cd "$root"
git rev-parse --is-inside-work-tree >/dev/null

git add -A
if git diff --cached --quiet; then exit 0; fi
files=$(git diff --cached --name-only)
if printf '%s\n' "$files" | grep -E '(^|/)(\.env|.*\.key|.*\.pem|genesis\.(age|png)|password\.txt)$' >/dev/null; then
  git reset >/dev/null
  echo 'arquivo sensível no commit' >&2
  exit 1
fi
git diff --cached --check
[ -r "$pat" ] || { git reset >/dev/null; echo 'PAT ausente' >&2; exit 1; }
GIT_AUTHOR_NAME=${GIT_AUTHOR_NAME:-vacum} \
GIT_AUTHOR_EMAIL=${GIT_AUTHOR_EMAIL:-vacum@localhost} \
GIT_COMMITTER_NAME=${GIT_COMMITTER_NAME:-vacum} \
GIT_COMMITTER_EMAIL=${GIT_COMMITTER_EMAIL:-vacum@localhost} \
git commit -m 'chore: sync configuration' >/dev/null
ask=$(mktemp /dev/shm/git-askpass.XXXXXX); trap 'rm -f "$ask"' EXIT
printf '#!/bin/sh\ncat %q\n' "$pat" > "$ask"; chmod 700 "$ask"
if git rev-parse --abbrev-ref --symbolic-full-name '@{u}' >/dev/null 2>&1; then
  GIT_ASKPASS="$ask" GIT_TERMINAL_PROMPT=0 git push
else
  GIT_ASKPASS="$ask" GIT_TERMINAL_PROMPT=0 git push -u origin HEAD
fi
