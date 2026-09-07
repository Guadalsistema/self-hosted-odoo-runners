FROM docker.io/library/odoo:17.0

###############################################################################
# 1. Paquetes básicos + PGDG + PostgreSQL 16 + Redis (solo binarios)
###############################################################################
USER root
RUN set -eux; \
    export DEBIAN_FRONTEND=noninteractive; \
    apt-get update && \
    apt-get install -y --no-install-recommends \
        locales && \
    locale-gen C.UTF-8 && \
    update-locale LANG=C.UTF-8 && \
    \
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
      base_codename="$(. /etc/os-release && printf '%s' "$VERSION_CODENAME")" && \
      [ "$base_codename" = jammy ] && \
      [ "$(uname -m)" = x86_64 ] && \
      [ "$(dpkg --print-architecture)" = amd64 ] && \
       nginx_keyring=/usr/share/keyrings/nginx-archive-keyring.gpg && \
       nginx_sources=/etc/apt/sources.list.d/nginx.list && \
       nginx_download="$(mktemp)" && \
       nginx_metadata="$(mktemp)" && \
       nginx_gnupghome="$(mktemp -d)" && \
       trap 'rm -f "$nginx_download" "$nginx_metadata" "$nginx_sources" "$nginx_keyring"; rm -rf "$nginx_gnupghome"' EXIT && \
       curl -fsSL --output "$nginx_download" https://nginx.org/keys/nginx_signing.key && \
       gpg --batch --no-options --homedir "$nginx_gnupghome" --show-keys --with-colons "$nginx_download" > "$nginx_metadata" && \
       nginx_primary_fingerprints="$(awk -F: '$1 == "pub" { primary=1; next } primary && $1 == "fpr" { print $10; primary=0 }' "$nginx_metadata" | sort)" && \
       nginx_expected_fingerprints="$(printf '%s\n' \
           573BFD6B3D8FBC641079A6ABABF5BD827BD9BF62 \
           8540A6F18833A80E9C1653A42FD21310B49F6B46 \
           9E9BE90EACBCDE69FE9B204CBCDCD8A38D88A2B3 | sort)" && \
       [ "$nginx_primary_fingerprints" = "$nginx_expected_fingerprints" ] && \
       gpg --batch --yes --no-options --homedir "$nginx_gnupghome" --dearmor --output "$nginx_keyring" "$nginx_download" && \
       echo "deb [signed-by=$nginx_keyring] https://nginx.org/packages/ubuntu jammy nginx" | \
          tee "$nginx_sources" > /dev/null && \
     \
     apt-get update && \
     apt-get install -y --no-install-recommends \
         postgresql-16 postgresql-client-16 zip unzip \
         redis-server redis-tools nginx=1.30.4-1~jammy && \
     [ "$(dpkg-query -W -f='${Version}' nginx)" = 1.30.4-1~jammy ] && \
     rm -f "$nginx_sources" "$nginx_keyring" && \
     \
     rm -rf /var/lib/apt/lists/*

ENV LANG=C.UTF-8
ENV PATH="/usr/lib/postgresql/16/bin:${PATH}"
ENV PLAYWRIGHT_BROWSERS_PATH=/opt/ms-playwright

RUN mkdir -p /opt/playwright /opt/ms-playwright && \
    PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD=1 npm install --prefix /opt/playwright \
        --no-save playwright@1.62.1 && \
    PLAYWRIGHT_BROWSERS_PATH=/opt/ms-playwright \
        /opt/playwright/node_modules/.bin/playwright install --with-deps chromium && \
    chmod -R a+rX /opt/ms-playwright

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

RUN pip install --no-cache-dir 'pypdf' 'pycups'

WORKDIR /home/runner/actions-runner
ENTRYPOINT ["/home/runner/actions-runner/entrypoint.sh"]
