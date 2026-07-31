#!/usr/bin/env bash
set -Eeuo pipefail
script=$(dirname "$(realpath -e "${BASH_SOURCE[0]}")")/git-sync.sh
d=$(mktemp -d /dev/shm/vacum-git-sync-test.XXXXXX); trap 'rm -rf "$d"' EXIT
repo=$d/repo; remote=$d/remote.git
mkdir -p "$repo/.source/_env"; git -C "$repo" init -q; git init -q --bare "$remote"
git -C "$repo" config user.name test; git -C "$repo" config user.email test@localhost
git -C "$repo" remote add origin "$remote"
: > "$repo/.source/_env/secrets.age"; git -C "$repo" add .; git -C "$repo" commit -qm initial; git -C "$repo" push -qu origin HEAD
printf 'GIT_URL=%s\nGIT_PAT=test\n' "$remote" > "$d/git.env"
mv "$remote" "$remote.off"; printf changed > "$repo/.source/_env/secrets.age"
if VACUM_SOURCE="$repo" "$script" "$d/git.env" >/dev/null 2>&1; then echo 'push ausente deveria falhar' >&2; exit 1; fi
[[ $(git -C "$repo" show --pretty= --name-only HEAD) == .source/_env/secrets.age ]]
mv "$remote.off" "$remote"
git clone -q "$remote" "$d/other"; git -C "$d/other" config user.name other; git -C "$d/other" config user.email other@localhost
printf remote > "$d/other/README"; git -C "$d/other" add README; git -C "$d/other" commit -qm remote; git -C "$d/other" push -q
VACUM_SOURCE="$repo" "$script" "$d/git.env" >/dev/null
[[ $(git --git-dir="$remote" rev-parse HEAD) == $(git -C "$repo" rev-parse HEAD) ]]
[[ $(cat "$repo/README") == remote ]]
echo 'git sync behavior: OK'
