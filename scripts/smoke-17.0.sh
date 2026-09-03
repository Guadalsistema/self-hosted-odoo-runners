#!/usr/bin/env bash
set -Eeuo pipefail

tmpdir=""
pg_pid=""
odoo_pid=""
nginx_pid=""

cleanup() {
    status=$?
    set +e
    [[ -n "$nginx_pid" ]] && kill -QUIT "$nginx_pid" 2>/dev/null
    [[ -n "$odoo_pid" ]] && kill "$odoo_pid" 2>/dev/null
    [[ -n "$pg_pid" ]] && pg_ctl -D "${PGDATA:-}" stop -m fast >/dev/null 2>&1
    [[ -n "$nginx_pid" ]] && wait "$nginx_pid" 2>/dev/null
    [[ -n "$odoo_pid" ]] && wait "$odoo_pid" 2>/dev/null
    [[ -n "$tmpdir" ]] && rm -rf "$tmpdir"
    exit "$status"
}
trap cleanup EXIT

[[ "$(id -un)" == runner ]] || { echo "smoke: not running as runner" >&2; exit 1; }

for command_name in initdb pg_ctl pg_isready createdb psql odoo python3 pip nginx bash curl mktemp ps pgrep pkill kill sleep grep node; do
    command -v "$command_name" >/dev/null || {
        echo "smoke: missing command: $command_name" >&2
        exit 1
    }
done

[[ "$(dpkg-query -W -f='${Version}' nginx 2>/dev/null)" == '1.30.4-1~jammy' ]] || {
    echo "smoke: unexpected nginx package version" >&2
    exit 1
}

tmpdir=$(mktemp -d)
chmod 700 "$tmpdir"
PGDATA="$tmpdir/postgres"
PGSOCK="$tmpdir/socket"
PGPORT=55432
mkdir -p "$PGSOCK"
initdb -D "$PGDATA" --auth=trust >/dev/null
pg_ctl -D "$PGDATA" -o "-k $PGSOCK -p $PGPORT" -l "$tmpdir/postgres.log" start >/dev/null
pg_pid=1
pg_isready -h "$PGSOCK" -p "$PGPORT" >/dev/null
createdb -h "$PGSOCK" -p "$PGPORT" smoke_odoo
psql -X -h "$PGSOCK" -p "$PGPORT" -d smoke_odoo -c 'SELECT 1' >/dev/null

ODOO_HOME="$tmpdir/odoo-home"
ODOO_DATA="$tmpdir/odoo-data"
mkdir -p "$ODOO_HOME" "$ODOO_DATA"
ODOO_CONF="$ODOO_HOME/odoo.conf"
cat >"$ODOO_CONF" <<EOF
[options]
admin_passwd = smoke-admin
db_host = $PGSOCK
db_port = $PGPORT
db_user = $(id -un)
db_password =
data_dir = $ODOO_DATA
addons_path = /usr/lib/python3/dist-packages/odoo/addons
logfile = $ODOO_HOME/odoo.log
http_port = 18069
EOF
unset ODOO_RC
odoo -c "$ODOO_CONF" -d smoke_odoo --init=base --stop-after-init --no-http >/dev/null
odoo shell -c "$ODOO_CONF" -d smoke_odoo --no-http <<'PY'
module = env['ir.module.module'].search([('name', '=', 'base')], limit=1)
assert module and module.state == 'installed', 'base module is not installed'
print('smoke: Odoo ORM lookup passed')
PY

NGINX_ROOT="$tmpdir/nginx"
mkdir -p "$NGINX_ROOT"/{logs,run,client_body,temp,html,fastcgi,uwsgi,scgi}
printf 'odoo-runner-smoke\n' > "$NGINX_ROOT/html/index.html"
NGINX_CONF="$NGINX_ROOT/nginx.conf"
cat >"$NGINX_CONF" <<EOF
pid $NGINX_ROOT/run/nginx.pid;
error_log $NGINX_ROOT/logs/error.log info;
events {}
http {
  access_log $NGINX_ROOT/logs/access.log;
  client_body_temp_path $NGINX_ROOT/client_body;
  proxy_temp_path $NGINX_ROOT/temp;
  fastcgi_temp_path $NGINX_ROOT/fastcgi;
  uwsgi_temp_path $NGINX_ROOT/uwsgi;
  scgi_temp_path $NGINX_ROOT/scgi;
  server {
    listen 127.0.0.1:18080;
    root $NGINX_ROOT/html;
  }
}
EOF
# Start NGINX in the foreground with the configured error_log setting
nginx -c "$NGINX_CONF" -p "$NGINX_ROOT" -e "$NGINX_ROOT/logs/error.log" -g 'daemon off;' &
nginx_pid=$!
for _ in {1..20}; do
    curl --fail --silent http://127.0.0.1:18080/ >/dev/null && break
    sleep 0.2
done
curl --fail --silent http://127.0.0.1:18080/ | grep -F 'odoo-runner-smoke' >/dev/null
kill -QUIT "$nginx_pid"
wait "$nginx_pid" || true
nginx_pid=""

node - <<'NODE'
const packageJson = require('/opt/playwright/node_modules/playwright/package.json');
if (packageJson.version !== '1.62.1') throw new Error(`unexpected Playwright ${packageJson.version}`);
const { chromium } = require('/opt/playwright/node_modules/playwright');
const executable = chromium.executablePath();
if (!executable.startsWith('/opt/ms-playwright/')) throw new Error(`unexpected Chromium path: ${executable}`);
(async () => {
  const browser = await chromium.launch({ headless: true, args: ['--no-sandbox'] });
  const page = await browser.newPage();
  await page.setContent('<title>offline smoke</title><p>ready</p>');
  if (await page.title() !== 'offline smoke') throw new Error('Chromium page assertion failed');
  await browser.close();
  console.log('smoke: Playwright 1.62.1 Chromium launch passed');
})().catch((error) => { console.error(error); process.exit(1); });
NODE

echo 'smoke: all Odoo 17 runner checks passed'
