#!/usr/bin/env bash
set -euo pipefail

# Configure this entrypoint with command-line options or environment variables.
# Command-line options take precedence over environment variables.
#
# Options:
#   --url URL             Repository or organization URL (GITHUB_URL).
#   --token TOKEN         Short-lived registration token (RUNNER_TOKEN).
#   --name NAME           Registered runner name (RUNNER_NAME).
#   --workdir DIR         Runner work directory (RUNNER_WORKDIR).
#   --version VERSION     actions/runner version (RUNNER_VERSION).
#   --labels LABELS       Comma-separated custom labels (RUNNER_LABELS).
#   --no-default-labels   Omit the self-hosted, linux and x64 labels.
#   --default-labels      Use default labels, overriding the environment.
#   -h, --help            Show usage information and exit.
#
# Registration options are only applied when .runner does not exist. Remove the
# existing runner registration before changing its name, workdir or labels.

usage() {
  cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Download, register and start a GitHub Actions self-hosted runner.

Options:
  --url URL             Repository or organization URL (required; GITHUB_URL)
  --token TOKEN         Runner registration token (required; RUNNER_TOKEN)
  --name NAME           Runner name (default: hostname; RUNNER_NAME)
  --workdir DIR         Work directory (default: _work; RUNNER_WORKDIR)
  --version VERSION     Runner version (default: 2.336.0; RUNNER_VERSION)
  --labels LABELS       Comma-separated custom labels (RUNNER_LABELS)
  --no-default-labels   Omit the self-hosted, linux and x64 labels
  --default-labels      Use default labels, overriding RUNNER_NO_DEFAULT_LABELS
  -h, --help            Show this help and exit

Command-line options take precedence over environment variables.
EOF
}

require_value() {
  if [[ $# -lt 2 || -z "$2" ]]; then
    echo "Error: $1 requires a value." >&2
    usage >&2
    exit 2
  fi
}

# === defaults and command-line options =================
GITHUB_URL="${GITHUB_URL:-}"
RUNNER_TOKEN="${RUNNER_TOKEN:-}"
RUNNER_NAME="${RUNNER_NAME:-$(hostname)}"
RUNNER_WORKDIR="${RUNNER_WORKDIR:-_work}"
RUNNER_VERSION="${RUNNER_VERSION:-2.336.0}"
RUNNER_LABELS="${RUNNER_LABELS:-}"
RUNNER_NO_DEFAULT_LABELS="${RUNNER_NO_DEFAULT_LABELS:-false}"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --url)
      require_value "$@"
      GITHUB_URL="$2"
      shift 2
      ;;
    --token)
      require_value "$@"
      RUNNER_TOKEN="$2"
      shift 2
      ;;
    --name)
      require_value "$@"
      RUNNER_NAME="$2"
      shift 2
      ;;
    --workdir)
      require_value "$@"
      RUNNER_WORKDIR="$2"
      shift 2
      ;;
    --version)
      require_value "$@"
      RUNNER_VERSION="$2"
      shift 2
      ;;
    --labels)
      require_value "$@"
      RUNNER_LABELS="$2"
      shift 2
      ;;
    --no-default-labels)
      RUNNER_NO_DEFAULT_LABELS=true
      shift
      ;;
    --default-labels)
      RUNNER_NO_DEFAULT_LABELS=false
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Error: unknown option: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

if [[ -z "$GITHUB_URL" ]]; then
  echo "Error: --url or GITHUB_URL is required." >&2
  exit 2
fi
if [[ -z "$RUNNER_TOKEN" ]]; then
  echo "Error: --token or RUNNER_TOKEN is required." >&2
  exit 2
fi

# === descarga binarios solo la primera vez ============
if [[ ! -f ./bin/Runner.Listener ]]; then
  echo "=> Descargando actions-runner v$RUNNER_VERSION…"
  tmp=$(mktemp -d)
  curl -fsSL -o "$tmp/runner.tgz" \
       "https://github.com/actions/runner/releases/download/v${RUNNER_VERSION}/actions-runner-linux-x64-${RUNNER_VERSION}.tar.gz"
  tar -xzf "$tmp/runner.tgz" -C .
  rm -rf "$tmp"
fi

# === registro SOLO si .runner no existe ===============
if [[ ! -f .runner ]]; then
  echo "=> Registrando runner…"
  cfg=(
    --unattended
    --url   "$GITHUB_URL"
    --token "$RUNNER_TOKEN"
    --name  "$RUNNER_NAME"
    --work  "$RUNNER_WORKDIR"
    --replace
  )
  [[ -n "$RUNNER_LABELS"            ]] && cfg+=( --labels "$RUNNER_LABELS" )
  [[ "$RUNNER_NO_DEFAULT_LABELS" == true ]] && cfg+=( --no-default-labels )

  ./config.sh "${cfg[@]}"
else
  echo "=> Runner ya configurado; saltando registro."
fi

# === listener bloqueante ===============================
exec ./run.sh
