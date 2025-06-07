FROM odoo:17.0

user root

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

# Crear carpeta de trabajo final donde se clonarán los módulos
RUN mkdir -p /mnt/extra-addons && chown -R runner:runner /mnt/extra-addons
WORKDIR /mnt/extra-addons

USER runner
ENTRYPOINT ["/home/runner/actions-runner/entrypoint.sh"]
