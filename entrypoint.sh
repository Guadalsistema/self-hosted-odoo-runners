#!/usr/bin/env bash
set -euo pipefail

# === variables obligatorias ============================
: "${GITHUB_URL:?Falta GITHUB_URL}"
: "${RUNNER_TOKEN:?Falta RUNNER_TOKEN}"
# etiqueta(s) opcionales (ej. "docker,gpu,node-20")
RUNNER_LABELS="${RUNNER_LABELS:-}"          # ← nueva
# si quieres quitar self-hosted,linux,x64: RUNNER_NO_DEFAULT_LABELS=true
RUNNER_NO_DEFAULT_LABELS="${RUNNER_NO_DEFAULT_LABELS:-false}"

# === descarga binarios solo la primera vez ============
if [[ ! -f ./bin/Runner.Listener ]]; then
  VERSION="${RUNNER_VERSION:-2.300.2}"
  echo "=> Descargando actions-runner v$VERSION…"
  tmp=$(mktemp -d)
  curl -fsSL -o "$tmp/runner.tgz" \
       "https://github.com/actions/runner/releases/download/v${VERSION}/actions-runner-linux-x64-${VERSION}.tar.gz"
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
    --name  "${RUNNER_NAME:-$(hostname)}"
    --work  "${RUNNER_WORKDIR:-_work}"
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

