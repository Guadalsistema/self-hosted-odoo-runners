# Dockerized GitHub Actions Self-Hosted Python Runner

A self-contained Docker image that runs the official GitHub Actions self-hosted
runner inside a container. The image is a generic Python build environment:
workflows decide what to install and which commands to run.

## Overview

- Downloads, registers, and starts the official `actions/runner` binary.
- Supports repository or organization registration with a short-lived token.
- Reuses an existing registration when `.runner` is present.
- Supports configurable runner name, work directory, version, and labels.
- Can preserve runner files, registration, workspaces, and caches with volumes.
- Captures no application-specific assumptions; workflow commands are arbitrary.

## Image contents

The image is based on `python:3.14-slim`. It provides:

- Python 3.14, `pip`, and the standard-library `venv` module
- The `make` binary, plus common runner utilities such as Bash, Git, curl,
  jq, and tar

No repository Makefile is provided. The `make` binary is available so each
project can provide and invoke its own Makefile, if desired.

Dependencies and virtual environments belong to the workflow. A workflow
should create its own virtual environment and install the project dependencies
it needs rather than relying on dependencies baked into this image.

## Prerequisites

- Docker Engine 20.10 or newer
- A GitHub self-hosted runner registration token

Create a token from **Repository or Organization Settings → Actions →
Runners → New self-hosted runner**. Registration tokens expire shortly after
they are generated.

## Configuration

`entrypoint.sh` accepts command-line options and environment variables.
Command-line options take precedence when both are provided.

| Variable | Required | Description | Default |
|----------|----------|-------------|---------|
| `GITHUB_URL` | Yes | Repository or organization URL, such as `https://github.com/myOrg/myRepo`. | None |
| `RUNNER_TOKEN` | Yes | Short-lived GitHub runner registration token, not a personal access token. | None |
| `RUNNER_NAME` | No | Name displayed for the runner. Existing runners with the same name are replaced during registration. | Container hostname |
| `RUNNER_WORKDIR` | No | Job work directory; relative paths are resolved from `/home/runner/actions-runner`. | `_work` |
| `RUNNER_VERSION` | No | [`actions/runner`](https://github.com/actions/runner/releases) version to download, without `v`. | `2.336.0` |
| `RUNNER_LABELS` | No | Comma-separated custom labels, without spaces. | No custom labels |
| `RUNNER_NO_DEFAULT_LABELS` | No | Set to exactly `true` to omit `self-hosted`, `linux`, and `x64`. | `false` |

Equivalent command-line options are `--url`, `--token`, `--name`, `--workdir`,
`--version`, `--labels`, `--no-default-labels`, `--default-labels`, and
`--help`.

Registration settings are applied only when `.runner` does not exist.
Restarting the same container reuses its registration; changing registration
settings does not reconfigure an already registered runner. `GITHUB_URL` and
`RUNNER_TOKEN` are required on every start, including starts that reuse
`.runner`. `RUNNER_VERSION` is used only when the runner binary has not already
been downloaded.

## Build the image

```bash
docker build -t python-runner:latest .
```

The repository also contains a workflow that builds `python-runner` on pushes
to the `self-hosted-python` branch.

## Start a runner

```bash
docker run -d \
  --restart unless-stopped \
  --name python-runner-01 \
  -e GITHUB_URL="https://github.com/myOrg/myRepo" \
  -e RUNNER_TOKEN="YOUR_REGISTRATION_TOKEN" \
  -e RUNNER_NAME="python-runner-01" \
  -e RUNNER_LABELS="python" \
  -v /var/lib/python-runner/_work:/home/runner/actions-runner/_work \
  python-runner:latest
```

### Environment file

Avoid putting the registration token in shell history by using a restricted
environment file:

```dotenv
GITHUB_URL=https://github.com/myOrg/myRepo
RUNNER_TOKEN=YOUR_REGISTRATION_TOKEN
RUNNER_NAME=python-runner-01
RUNNER_LABELS=python
```

```bash
chmod 600 runner.env
docker run -d --restart unless-stopped --name python-runner-01 \
  --env-file runner.env \
  -v /var/lib/python-runner/_work:/home/runner/actions-runner/_work \
  python-runner:latest
```

Prefer an environment file for long-running containers because command-line
arguments may be visible through process-inspection tools.

## Use the runner in a workflow

The recommended custom label is `python`. A workflow owns its dependency and
virtual-environment setup and may run any project command:

```yaml
jobs:
  test:
    runs-on: [self-hosted, python]
    steps:
      - uses: actions/checkout@v4
      - name: Create environment and install dependencies
        run: |
          python -m venv .venv
          .venv/bin/python -m pip install --upgrade pip
          .venv/bin/python -m pip install -r requirements.txt
      - name: Run project checks
        run: .venv/bin/python -m pytest
      - name: Run an arbitrary project command
        run: make test
```

If `RUNNER_NO_DEFAULT_LABELS=true`, omit `self-hosted`, `linux`, and `x64` and
select the runner using its custom label.

## Command-line invocation

The image passes arguments to `entrypoint.sh`, so registration options can be
provided without environment variables:

```bash
docker run -d --name python-runner-01 python-runner:latest \
  --url "https://github.com/myOrg/myRepo" \
  --token "YOUR_REGISTRATION_TOKEN" \
  --name "python-runner-01" \
  --labels "python"
```

The listener runs in the foreground of the container and is not deregistered
when the container stops. Remove unused runners through GitHub's runner
settings before deleting their persistent registration data.

## Persistence and security

The `_work` volume preserves job workspaces and caches, but not the `.runner`
registration file. Restarting the same container preserves registration;
removing and recreating it performs a new registration and requires a fresh
token.

To preserve registration and downloaded runner files when recreating the
container, use a named volume for the complete runner directory:

```bash
docker volume create python-runner-data
docker run -d --name python-runner-01 --env-file runner.env \
  -v python-runner-data:/home/runner/actions-runner \
  python-runner:latest
```

Do not bind-mount an empty host directory at
`/home/runner/actions-runner`: it hides the image entrypoint and prevents the
container from starting. Treat registration tokens and workflow secrets as
sensitive, grant the runner only the access it needs, and review workflows
before allowing them to run on a self-hosted machine.
