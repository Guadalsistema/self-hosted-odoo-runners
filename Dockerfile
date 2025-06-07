FROM odoo/odoo:17.0

# 1. Dependencias básicas
RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
      curl jq git ca-certificates sudo procps && \
    rm -rf /var/lib/apt/lists/*

# 2. Crea usuario no-root
RUN groupadd -r runner && useradd --no-log-init -r -g runner runner
WORKDIR /home/runner/actions-runner
RUN chown -R runner:runner /home/runner

# 3. Copia el entrypoint
COPY entrypoint.sh /home/runner/actions-runner/entrypoint.sh
RUN chmod +x /home/runner/actions-runner/entrypoint.sh

USER runner
ENTRYPOINT ["./entrypoint.sh"]
