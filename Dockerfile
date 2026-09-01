FROM python:3.14-slim

###############################################################################
# 1. Basic utilities for the GitHub Actions runner
###############################################################################
USER root
RUN set -eux; \
    export DEBIAN_FRONTEND=noninteractive; \
    apt-get update && \
    apt-get install -y --no-install-recommends \
        bash ca-certificates curl git gzip jq make procps sudo tar \
        libgssapi-krb5-2 libicu76 liblttng-ust1t64 libssl3t64 libunwind8 \
        libgcc-s1 libstdc++6 zlib1g && \
    rm -rf /var/lib/apt/lists/*



###############################################################################
# 2. Usuario y carpetas del runner
###############################################################################
RUN groupadd -r runner && \
    useradd --no-log-init -r -g runner runner

WORKDIR /home/runner/actions-runner
RUN chown -R runner:runner /home/runner

###############################################################################
# 3. Entrypoint del runner
###############################################################################
COPY entrypoint.sh /home/runner/actions-runner/entrypoint.sh
RUN chmod +x /home/runner/actions-runner/entrypoint.sh

###############################################################################
# 4. Usuario de ejecución
###############################################################################
USER runner

WORKDIR /home/runner/actions-runner
ENTRYPOINT ["/home/runner/actions-runner/entrypoint.sh"]
