#!/usr/bin/env bash
set -Eeuo pipefail
script=$(dirname "$(realpath -e "${BASH_SOURCE[0]}")")/git-sync.sh
d=$(mktemp -d /dev/shm/vacum-git-sync-test.XXXXXX); trap 'rm -rf "$d"' EXIT
repo=$d/repo; remote=$d/remote.git
mkdir -p "$repo/.source/_secrets"; git -C "$repo" init -q; git init -q --bare "$remote"
git -C "$repo" config user.name test; git -C "$repo" config user.email test@localhost
git -C "$repo" remote add origin "$remote"
: > "$repo/.source/_secrets/secrets.age"; git -C "$repo" add .; git -C "$repo" commit -qm initial; git -C "$repo" push -qu origin HEAD
printf 'GIT_URL=%s\nGIT_PAT=test\n' "$remote" > "$d/git.env"
mv "$remote" "$remote.off"; printf changed > "$repo/.source/_secrets/secrets.age"
if VACUM_SOURCE="$repo" "$script" "$d/git.env" >/dev/null 2>&1; then echo 'push ausente deveria falhar' >&2; exit 1; fi
[[ $(git -C "$repo" show --pretty= --name-only HEAD) == .source/_secrets/secrets.age ]]
mv "$remote.off" "$remote"
VACUM_SOURCE="$repo" "$script" "$d/git.env" >/dev/null
[[ $(git --git-dir="$remote" rev-parse HEAD) == $(git -C "$repo" rev-parse HEAD) ]]
echo 'git sync behavior: OK'
