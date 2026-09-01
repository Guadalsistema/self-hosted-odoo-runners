FROM ubuntu:24.04 AS cleanup-helper-build

RUN apt-get update && apt-get install -y --no-install-recommends gcc libc6-dev \
    && rm -rf /var/lib/apt/lists/*
COPY cleanup-workspace.c /tmp/cleanup-workspace.c
RUN gcc -std=c11 -O2 -Wall -Wextra -Werror -o /cleanup-workspace-helper /tmp/cleanup-workspace.c

FROM ubuntu:24.04

ARG RUNNER_VERSION=2.337.0
ARG RUNNER_SHA256=70920811a4f8ad4328818682bca5c6469c1c942fab52448868071d0063816613

ENV DEBIAN_FRONTEND=noninteractive \
    ACTIONS_RUNNER_HOOK_JOB_COMPLETED=/usr/local/bin/cleanup-workspace.sh

RUN test "$(dpkg --print-architecture)" = amd64

RUN apt-get update && apt-get install -y --no-install-recommends \
    bash ca-certificates curl git gzip jq make procps sudo tar \
    libgssapi-krb5-2 libicu74 liblttng-ust1t64 libssl3 libunwind8 \
    libcap2-bin libgcc-s1 libstdc++6 uidmap zlib1g \
    && rm -rf /var/lib/apt/lists/*

RUN groupadd --system --gid 999 runner \
    && useradd --system --uid 999 --gid runner --create-home runner \
    && echo 'runner ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/runner \
    && chmod 0440 /etc/sudoers.d/runner \
    && mkdir -p /home/runner/actions-runner \
    && printf 'runner:1:998\nrunner:1000:64536\n' > /etc/subuid \
    && printf 'runner:1:998\nrunner:1000:64536\n' > /etc/subgid \
    && chmod u-s /usr/bin/newuidmap /usr/bin/newgidmap \
    && setcap cap_setuid=ep /usr/bin/newuidmap \
    && setcap cap_setgid=ep /usr/bin/newgidmap \
    && chown -R runner:runner /home/runner

WORKDIR /home/runner/actions-runner
RUN set -eux; \
    archive="actions-runner-linux-x64-${RUNNER_VERSION}.tar.gz"; \
    curl -fsSL -o "/tmp/${archive}" \
      "https://github.com/actions/runner/releases/download/v${RUNNER_VERSION}/${archive}"; \
    echo "${RUNNER_SHA256}  /tmp/${archive}" | sha256sum -c -; \
    tar -xzf "/tmp/${archive}" -C /home/runner/actions-runner; \
    rm "/tmp/${archive}"; \
    test -x /home/runner/actions-runner/bin/Runner.Listener; \
    chown -R runner:runner /home/runner/actions-runner

COPY cleanup-workspace.sh /usr/local/bin/cleanup-workspace.sh
COPY --from=cleanup-helper-build /cleanup-workspace-helper /usr/local/libexec/cleanup-workspace-helper
RUN chmod 0755 /usr/local/bin/cleanup-workspace.sh /usr/local/libexec/cleanup-workspace-helper \
    && chown root:root /usr/local/bin/cleanup-workspace.sh /usr/local/libexec/cleanup-workspace-helper
COPY entrypoint.sh /home/runner/actions-runner/entrypoint.sh
RUN chmod 0755 /home/runner/actions-runner/entrypoint.sh \
    && chown runner:runner /home/runner/actions-runner/entrypoint.sh

USER runner
ENTRYPOINT ["/home/runner/actions-runner/entrypoint.sh"]
