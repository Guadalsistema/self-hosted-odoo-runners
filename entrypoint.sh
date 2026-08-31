#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: entrypoint.sh [OPTIONS]

Start the baked-in x64 GitHub Actions runner. Registration is needed only on
the first start; an existing .runner registration is reused.

  --url URL          Organization or repository URL (GITHUB_URL)
  --token TOKEN      Short-lived registration token (RUNNER_TOKEN)
  --name NAME        Runner name (RUNNER_NAME; default: hostname)
  --labels LABELS    Additional comma-separated labels (RUNNER_LABELS)
  -h, --help         Show this help
EOF
}

require_value() { [[ $# -ge 2 && -n ${2:-} ]] || { echo "Error: $1 requires a value." >&2; exit 2; }; }

GITHUB_URL=${GITHUB_URL:-}
RUNNER_TOKEN=${RUNNER_TOKEN:-}
RUNNER_NAME=${RUNNER_NAME:-$(hostname)}
RUNNER_LABELS=${RUNNER_LABELS:-}

while [[ $# -gt 0 ]]; do
  case $1 in
    --url) require_value "$@"; GITHUB_URL=$2; shift 2;;
    --token) require_value "$@"; RUNNER_TOKEN=$2; shift 2;;
    --name) require_value "$@"; RUNNER_NAME=$2; shift 2;;
    --labels) require_value "$@"; RUNNER_LABELS=$2; shift 2;;
    -h|--help) usage; exit 0;;
    *) echo "Error: unknown option: $1" >&2; usage >&2; exit 2;;
  esac
done

cd /home/runner/actions-runner
if [[ ! -x ./bin/Runner.Listener ]]; then
  echo 'Error: baked Actions runner is missing (startup will not download it).' >&2
  exit 1
fi

if [[ ! -f .runner ]]; then
  if [[ -z $GITHUB_URL || -z $RUNNER_TOKEN ]]; then
    echo 'Error: an unregistered runner requires GITHUB_URL and RUNNER_TOKEN.' >&2
    exit 2
  fi
  labels=ubuntu-24.04
  [[ -n $RUNNER_LABELS ]] && labels+=",$RUNNER_LABELS"
  config=(--unattended --url "$GITHUB_URL" --token "$RUNNER_TOKEN"
          --name "$RUNNER_NAME" --work _work --replace
          --labels "$labels")
  ./config.sh "${config[@]}"
else
  echo 'Runner already configured; registration settings are ignored.'
fi

unset RUNNER_TOKEN
exec ./run.sh
