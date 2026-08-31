#!/usr/bin/env bash
set -euo pipefail

hook=${1:-./cleanup-workspace.sh}
helper=${2:-/usr/local/libexec/cleanup-workspace-helper}
root=/home/runner/actions-runner/_work
tmp=$(mktemp -d)
if [[ -e $root ]]; then
  echo "cleanup test requires an unused $root" >&2
  exit 1
fi
mounted=0
cleanup_test() {
  if (( mounted )); then
    umount "$root/repo/mounted" 2>/dev/null || true
  fi
  rm -rf "$root" "$tmp"
}
trap cleanup_test EXIT
mkdir -p "$root"/{_actions,_temp,_tool,_PipelineMapping,repo/project}
printf keep > "$root/_actions/sentinel"
printf keep > "$root/_temp/sentinel"
printf keep > "$root/_tool/sentinel"
printf keep > "$root/_PipelineMapping/sentinel"
mkdir -p "$tmp/outside"
printf outside > "$tmp/outside/sentinel"
printf content > "$tmp/outside/content"
ln -s "$tmp/outside/content" "$root/repo/project/content-link"

if "$helper" repo project/extra 2>/dev/null; then
  echo 'cleanup helper unexpectedly accepted extra-depth components' >&2
  exit 1
fi
ln -s "$tmp/outside" "$root/symlink-repo"
if "$helper" symlink-repo project 2>/dev/null; then
  echo 'cleanup helper unexpectedly followed a symlinked repository' >&2
  exit 1
fi
ln -s "$tmp/outside" "$root/repo/symlink-workspace"
if "$helper" repo symlink-workspace 2>/dev/null; then
  echo 'cleanup helper unexpectedly followed a symlinked workspace' >&2
  exit 1
fi

# Exercise the mount boundary check when the test environment grants mount
# privileges.  The test remains useful (and safe) in ordinary containers,
# where this optional setup is skipped.
mkdir "$root/repo/mounted"
if mount --bind "$tmp/outside" "$root/repo/mounted" 2>/dev/null; then
  mounted=1
  if "$helper" repo mounted 2>/dev/null; then
    echo 'cleanup helper unexpectedly crossed a mounted workspace' >&2
    exit 1
  fi
  umount "$root/repo/mounted"
  mounted=0
fi

GITHUB_WORKSPACE="$root/repo/project" bash "$hook"
test ! -e "$root/repo/project"
test -e "$tmp/outside/content" && test -e "$tmp/outside/sentinel"

assert_refused() {
  local value=$1
  if GITHUB_WORKSPACE="$value" bash "$hook"; then
    echo "cleanup unexpectedly accepted: $value" >&2
    return 1
  fi
}

mkdir -p "$root/job" "$root/repo/project"
assert_refused "$root/job"                 # direct child / work root leaf
assert_refused "$root"                     # work root
assert_refused ''                           # empty
assert_refused relative/path                # relative
assert_refused /                            # filesystem root
assert_refused "$root/repo"                # structural parent
mkdir -p "$root/repo/project/subdir"
printf preserve > "$root/repo/project/subdir/sentinel"
assert_refused "$root/repo/project/subdir" # descendant of exact workspace
test -e "$root/repo/project/subdir/sentinel"
for managed in _actions _temp _tool _PipelineMapping; do
  assert_refused "$root/$managed"
done
assert_refused "$tmp/outside"              # outside target
ln -s "$tmp/outside" "$root/repo/escape"
assert_refused "$root/repo/escape"         # symlinked workspace
assert_refused "$root/missing"             # missing workspace

test -e "$root/_actions/sentinel"
test -e "$root/_temp/sentinel"
test -e "$root/_tool/sentinel"
test -e "$root/_PipelineMapping/sentinel"
test -e "$tmp/outside/sentinel"

mkdir -p "$root/retry/project"
GITHUB_WORKSPACE="$root/retry/project" bash "$hook"
assert_refused "$root/retry/project"       # idempotent absent retry is observable

echo 'cleanup hook tests passed'
