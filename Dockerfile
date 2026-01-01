FROM odoo:17.0

###############################################################################
# 1. Paquetes básicos + PGDG + PostgreSQL 16 (solo binarios, sin servicio)
###############################################################################
USER root
RUN set -eux; \
    export DEBIAN_FRONTEND=noninteractive; \
	curl -fsSL https://deb.nodesource.com/setup_20.x | bash - && \
	apt-get remove -y nodejs libnode-dev libnode72 && \
	apt-get autoremove -y && \
	\
    apt-get update && \
    apt-get install -y --no-install-recommends \
        curl gnupg lsb-release jq git ca-certificates sudo procps nodejs && \
    \
    curl -fsSL https://www.postgresql.org/media/keys/ACCC4CF8.asc | \
        gpg --dearmor -o /usr/share/keyrings/postgresql.gpg && \
    \
    echo "deb [signed-by=/usr/share/keyrings/postgresql.gpg] \
        http://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" | \
        tee /etc/apt/sources.list.d/pgdg.list > /dev/null && \
    \
    apt-get update && \
    apt-get install -y --no-install-recommends \
        postgresql-16 postgresql-client-16 && \
    \
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
# 4. Carpeta para add-ons externos
###############################################################################
RUN mkdir -p /mnt/extra-addons && \
    chown -R runner:runner /mnt/extra-addons

###############################################################################
# 5. Usuario de ejecución
###############################################################################
USER runner

RUN pip install --no-cache-dir 'pypdf'

WORKDIR /home/runner/actions-runner
ENTRYPOINT ["/home/runner/actions-runner/entrypoint.sh"]

