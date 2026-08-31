#!/usr/bin/env bash
set -euo pipefail

root=/home/runner/actions-runner/_work
workspace=${GITHUB_WORKSPACE:-}
helper=/usr/local/libexec/cleanup-workspace-helper

reject() { echo "cleanup-workspace: refusing workspace ($1)" >&2; exit 1; }
[[ $# -eq 0 ]] || reject 'unexpected arguments'
[[ -n $workspace && $workspace == /* && $workspace != *$'\n'* && $workspace != *$'\r'* ]] || reject 'not an absolute, unambiguous path'
[[ -d $root && -d $workspace ]] || reject 'path is missing'

canonical_root=$(realpath -e -- "$root") || reject 'work root cannot be resolved'
canonical_workspace=$(realpath -e -- "$workspace") || reject 'workspace cannot be resolved'
[[ $canonical_root == "$root" && $canonical_workspace == "$workspace" ]] || reject 'path contains a symlink or is not canonical'

case "$canonical_workspace/" in
  "$canonical_root/"*) relative=${canonical_workspace:$((${#canonical_root} + 1))};;
  *) reject 'workspace is outside the work root';;
esac
[[ $relative == */* && $relative != */*/* ]] || reject 'workspace must be exactly two components below work root'
repository=${relative%%/*}
workspace_name=${relative#*/}
[[ -n $repository && -n $workspace_name && $repository != */* && $workspace_name != */* ]] || reject 'workspace must be exactly two simple components'
case "$relative" in
  _actions/*|_temp/*|_tool/*|_PipelineMapping/*) reject 'runner-managed path';;
esac

[[ -x $helper ]] || reject 'cleanup helper is unavailable'
"$helper" "$repository" "$workspace_name" || reject 'descriptor-relative cleanup failed'
echo "cleanup-workspace: removed verified workspace"
