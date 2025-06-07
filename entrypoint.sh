#!/usr/bin/env bash
set -e

# Variables que debes pasar al 'docker run':
#   - GITHUB_URL: URL de tu repo u organización (p.ej. https://github.com/miOrg/miRepo)
#   - RUNNER_TOKEN: token de registro que Generas en GitHub
#   - RUNNER_NAME: (opcional) nombre que tendrá este runner
#   - RUNNER_WORKDIR: (opcional) carpeta de trabajo, por defecto _work

: "${GITHUB_URL:?Falta GITHUB_URL}"
: "${RUNNER_TOKEN:?Falta RUNNER_TOKEN}"

# Si no hemos descargado aún el runner, lo bajamos y extraemos
if [ ! -f ./bin/Runner.Listener ]; then
  echo "=> Descargando actions-runner..."
  VERSION="${RUNNER_VERSION:-2.300.2}"  # ajusta a la última versión estable
  curl -fsSL -o actions-runner.tar.gz \
    "https://github.com/actions/runner/releases/download/v${VERSION}/actions-runner-linux-x64-${VERSION}.tar.gz"
  tar -xzf actions-runner.tar.gz
  rm actions-runner.tar.gz
fi

# Configura el runner (solo la primera vez o si cambian vars)
./config.sh --unattended \
  --url "$GITHUB_URL" \
  --token "$RUNNER_TOKEN" \
  --name "${RUNNER_NAME:-$(hostname)}" \
  --work "${RUNNER_WORKDIR:-_work}" \
  --replace

# Función para limpieza al recibir SIGTERM
cleanup() {
  echo "=> Desregistrando runner…"
  ./config.sh remove --unattended --token "$RUNNER_TOKEN"
  exit 0
}

trap 'cleanup' SIGINT SIGTERM

# Arranca el listener (bloqueante)
exec ./run.sh
