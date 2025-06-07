# Dockerized GitHub Actions Self-Hosted Runner

A self-contained Docker image that runs a GitHub Actions self-hosted runner inside a container. It automates download, registration, execution and clean deregistration of the runner, so you can spin up as many isolated runners as you need.

---

## 📖 Overview

- **Agent model**: The container runs the official `actions/runner` binary inside Docker.
- **On-demand registration**: Registers itself against your repository or organization using a short-lived registration token.
- **Clean shutdown**: Captures SIGTERM/SIGINT, deregisters the runner automatically before exit.
- **Reproducible**: Everything (OS, dependencies, runner binary) is defined in code, so you can rebuild anytime.
- **Scalable**: Launch multiple containers in parallel for concurrent workflow execution.

---

## 🚀 Features

- ✅ Automatic download of runner binary
- ✅ Unattended configuration & registration
- ✅ Graceful cleanup on stop
- ✅ Customizable name, work directory & runner version
- ✅ Volume-backed `_work` directory for cache persistence
- ✅ Run in any Docker-aware environment (desktop, CI, Kubernetes)

---

## 🛠️ Prerequisites

- Docker installed on your host (Engine ≥ 20.10)
- A **registration token** from GitHub:
  1. Go to your **repo** → Settings → Actions → Runners → **New self-hosted runner**  
  2. Copy the **registration token**

---

## ⚙️ Configuration

| Variable            | Description                                                                                   | Default       |
|---------------------|-----------------------------------------------------------------------------------------------|---------------|
| `GITHUB_URL`        | URL of your repo or org (e.g. `https://github.com/myOrg/myRepo`)                               | **(required)**|
| `RUNNER_TOKEN`      | Short-lived registration token from GitHub                                                     | **(required)**|
| `RUNNER_NAME`       | Name to register this runner under GitHub                                                      | Container hostname |
| `RUNNER_WORKDIR`    | Working directory inside the container (relative to `/home/runner/actions-runner`)            | `_work`       |
| `RUNNER_VERSION`    | GitHub Actions runner version (e.g. `2.300.2`)                                                | Latest stable |

---

## 🏗️ Build the Image

Clone this repo (or place the files in a folder) and build the Docker image:

```bash
docker build -t gh-selfhosted-runner:latest .
```

The image uses `/mnt/extra-addons` as working directory so your Odoo modules
can be cloned there.

This repository also provides a GitHub Actions workflow (`build-image.yml`) that
automatically builds the image on each push.

## 🧪 Example Workflow

The `odoo-test-example.yml` workflow shows how to spin up a PostgreSQL service,
clone your modules into `/mnt/extra-addons` and run Odoo's test suite inside the
container.

```bash
docker run -d \
  --name gh-runner-01 \
  -e GITHUB_URL="https://github.com/myOrg/myRepo" \
  -e RUNNER_TOKEN="YOUR_REGISTRATION_TOKEN" \
  -e RUNNER_NAME="docker-runner-01" \
  -e RUNNER_WORKDIR="_work" \
  -v /var/lib/gh-runner/_work:/home/runner/actions-runner/_work \
  gh-selfhosted-runner:latest
```
