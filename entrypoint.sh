#!/usr/bin/env bash
set -e

# Variables que debes pasar al 'docker run':
#   - GITHUB_URL: URL de tu repo u organización (p.ej. https://github.com/miOrg/miRepo)
#   - RUNNER_TOKEN: token de registro que Generas en GitHub
#   - RUNNER_NAME: (opcional) nombre que tendrá este runner
#   - RUNNER_WORKDIR: (opcional) carpeta de trabajo, por defecto _work

: "${GITHUB_URL:?Falta GITHUB_URL}"
: "${RUNNER_TOKEN:?Falta RUNNER_TOKEN}"

# Si no hemos descargado aún el runner, lo bajamos primero en /tmp y luego lo movemos
if [ ! -f ./bin/Runner.Listener ]; then
  echo "=> Descargando actions-runner en /tmp..."
  VERSION="${RUNNER_VERSION:-2.300.2}"
  TMPDIR=$(mktemp -d)
  curl -fsSL -o "$TMPDIR/actions-runner.tar.gz" \
    "https://github.com/actions/runner/releases/download/v${VERSION}/actions-runner-linux-x64-${VERSION}.tar.gz"
  echo "=> Extrayendo en la carpeta del runner…"
  tar -xzf "$TMPDIR/actions-runner.tar.gz" -C .
  rm -rf "$TMPDIR"
fi

# 2. Registra el runner sólo si no lo estaba ya
if [[ ! -f .runner ]]; then
	# Configura el runner (solo la primera vez o si cambian vars)
	./config.sh --unattended \
	  --url "$GITHUB_URL" \
	  --token "$RUNNER_TOKEN" \
	  --name "${RUNNER_NAME:-$(hostname)}" \
	  --work "${RUNNER_WORKDIR:-/mnt/extra-addons}" \
	  --replace
else
  echo "=> Runner ya configurado, saltando «config.sh»"
fi

# Arranca el listener (bloqueante)
exec ./run.sh
