# Local Agent Development Environment

This repository uses **Podman** for local image build and run verification, rather than Docker.

## Build Commands

All Docker-oriented build commands must be translated to their Podman equivalents:

- `docker build -t ghcr.io/owner/repo:tag .` → `podman build -t ghcr.io/owner/repo:tag .`

## Run Commands

For local smoke testing, use Podman with `--network=none` and `--read-only` flags:

```bash
podman run --network=none --read-only ghcr.io/owner/repo:tag
```

## Infrastructure Notes

- The absence of Docker is not an infrastructure blocker when Podman is available
- These instructions apply only to the agent development environment
- GitHub Actions and repository CI continue to use the container engine specified in `.github/workflows/build-image.yml`