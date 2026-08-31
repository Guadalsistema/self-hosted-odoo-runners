# Ubuntu 24.04 organization self-hosted runner

This repository builds one persistent, trusted, x64 organization runner. It
has no hosted VM tool cache and does not install Podman by default. Select it
explicitly:

```yaml
runs-on: [self-hosted, linux, x64, ubuntu-24.04]
```

Register exactly one runner in the `Default` runner group. The `runner` user
has passwordless `sudo`; only reviewed trusted workflows may use it.

## Registration and persistence

The baked runner application is in `/home/runner/actions-runner`. Do **not**
mount a volume over that directory: doing so hides the application and
entrypoint baked into the image. Only `_work` may be persisted separately.
The cleanup hook always uses the fixed trusted root
`/home/runner/actions-runner/_work`; `RUNNER_WORKDIR`, arbitrary hook roots, and
symlinked workspaces are not supported. Cleanup uses descriptor-relative,
no-follow deletion and removes only an exact `<repository>/<workspace>` leaf,
never the work root, structural parents, or `_actions`, `_temp`, `_tool`, and
`_PipelineMapping`. Linux mount crossings, including mounted descendants such
as exposed `/dev/fuse` filesystems, are rejected by `openat2`; unsupported
kernels and resolution failures remain fail-closed. Unsafe or missing paths
fail nonzero and are left for investigation.

On first registration, create `runner.env` (mode 600) containing:

```dotenv
GITHUB_URL=https://github.com/ORG
RUNNER_TOKEN=ONE_TIME_ORGANIZATION_REGISTRATION_TOKEN
RUNNER_NAME=guadalbackup
```

After the first successful registration, remove `RUNNER_TOKEN` from
`runner.env`. The bootstrap token is short-lived and must never be passed to
jobs. A restart of this same long-lived container reuses `.runner` and does
not require a token.

## guadalbackup deployment

The host uses rootless Podman. Log in with a dedicated GitHub PAT scoped only
to `read:packages`, then run one persistent container. Replace the placeholder
with the digest printed by the manual publication workflow:

```bash
printf '%s' "$GHCR_READ_PACKAGES_PAT" | podman login ghcr.io \
  --username YOUR_GITHUB_USERNAME --password-stdin
podman volume create guadalbackup-runner-work
# No extra command; registration options come from runner.env.
podman run -d --name guadalbackup --restart=unless-stopped \
  --device /dev/fuse \
  --env-file ./runner.env \
  --volume guadalbackup-runner-work:/home/runner/actions-runner/_work \
  ghcr.io/Guadalsistema/self-hosted-odoo-runners@sha256:...
```

There is no `--privileged`, socket mount, or seccomp relaxation. `/dev/fuse`
is the only special runtime requirement for a trusted workflow that installs
and tests rootless nested Podman; Podman is not installed in this image.

## Manual digest rollout and rollback

Publication is manual (`workflow_dispatch`) and publishes only `linux/amd64`.
Record the resulting immutable digest. A rollout is a new registration, not a
restart: first stop and remove the old container, delete its old registration
in the GitHub organization’s **Settings → Actions → Runners** page, obtain a
fresh registration token, update `runner.env`, and recreate the same name:

```bash
podman stop guadalbackup || true
podman rm guadalbackup || true
# In GitHub: delete the old guadalbackup registration (and any legacy entry).
# Put a fresh RUNNER_TOKEN in runner.env, then remove it after registration.
podman run -d --replace --name guadalbackup --restart=unless-stopped \
  --device /dev/fuse --env-file ./runner.env \
  --volume guadalbackup-runner-work:/home/runner/actions-runner/_work \
  ghcr.io/Guadalsistema/self-hosted-odoo-runners@sha256:NEW_DIGEST
```

To roll back, repeat the same stop/remove, GitHub registration deletion, and
fresh-token registration process with the previously recorded image digest.
Do not assume an existing legacy registration gains labels automatically.

If migrating the old Python runner, explicitly remove that Python runner in
GitHub first, then re-register `guadalbackup` with the fresh token and no
`python` label. Verify the old `python` label is gone and `ubuntu-24.04`
exists before enabling jobs; labels are not added automatically to the legacy
registration.

## Image and CI

The official x64 Actions runner archive is pinned and checksum-verified in the
image. The Dockerfile rejects non-amd64 bases. CI builds and verifies
`linux/amd64`; only the manual workflow dispatch publishes to GHCR, and only
that publish job has `packages: write` permission. The image contains the
subordinate UID/GID ranges needed if a trusted workflow installs rootless
Podman inside the runner.
