#!/usr/bin/env bash
#
# StakeTechLab container installer — https://staketechlab.com
# Repo: https://github.com/staketechlab/staketechlab-containers
#
# Usage:
#   ./install.sh <app> [install-dir] [port]     # from a clone
#   bash <(curl -fsSL https://raw.githubusercontent.com/staketechlab/staketechlab-containers/main/install.sh) homepage
#
# Examples:
#   ./install.sh homepage
#   ./install.sh homepage ~/docker/homepage 8080
#
# What it does:
#   1. Verifies docker + compose plugin are installed and the port is free
#   2. Creates <install-dir> (default ~/docker/<app>) with compose + config
#   3. Starts the container with docker compose
#   4. Waits for it to answer HTTP, then prints your URLs + next steps
#
# Everything is readable: read the whole file before you run it.
set -euo pipefail

APP="${1:-}"
if [[ -z "$APP" ]]; then
    echo "Usage: $0 <app> [install-dir] [port]" >&2
    echo "Available apps: homepage" >&2
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd)"

# --- app payload resolution ------------------------------------------------
# Local (git clone): apps/ lives next to install.sh. Remote (bash <(curl)):
# the script is a stream with no apps/ beside it, so fetch the payload
# from the repo tarball into a temp dir (cleaned up on exit).
REPO="staketechlab/staketechlab-containers"
TMP_DIR=""
if [[ -d "$SCRIPT_DIR/apps/$APP" ]]; then
    APP_DIR="$SCRIPT_DIR/apps/$APP"
elif command -v curl >/dev/null 2>&1 && command -v tar >/dev/null 2>&1; then
    TMP_DIR="$(mktemp -d)"
    trap 'rm -rf "$TMP_DIR"' EXIT
    echo "==> Fetching $APP installer payload from GitHub..."
    if ! curl -fsSL "https://codeload.github.com/$REPO/tar.gz/refs/heads/main" 2>/dev/null | tar -xz -C "$TMP_DIR"; then
        echo "ERROR: could not fetch the app payload from $REPO." >&2
        exit 1
    fi
    APP_DIR="$(echo "$TMP_DIR"/*/apps/"$APP" 2>/dev/null || true)"
fi

if [[ ! -d "${APP_DIR:-}" ]]; then
    echo "Unknown app '$APP'. Available apps:" >&2
    ls "$SCRIPT_DIR/apps" 2>/dev/null || true
    exit 1
fi

# --- defaults ---------------------------------------------------------------
INSTALL_DIR="${2:-$HOME/docker/$APP}"
PORT="${3:-3000}"

# --- checks -----------------------------------------------------------------
if ! command -v docker >/dev/null 2>&1; then
    echo "ERROR: docker is not installed (or not on PATH)." >&2
    echo "Install it first: https://docs.docker.com/engine/install/" >&2
    exit 1
fi

if ! docker compose version >/dev/null 2>&1; then
    echo "ERROR: the docker compose plugin is missing." >&2
    echo "Install it: https://docs.docker.com/compose/install/" >&2
    exit 1
fi

if ! command -v curl >/dev/null 2>&1; then
    echo "ERROR: curl is required for the health check." >&2
    exit 1
fi

if ss -tln 2>/dev/null | grep -q ":${PORT}[[:space:]]"; then
    echo "ERROR: port $PORT is already in use. Pick another:" >&2
    echo "  $0 $APP '$INSTALL_DIR' 8081" >&2
    exit 1
fi

# --- install ----------------------------------------------------------------
mkdir -p "$INSTALL_DIR/config"

echo "==> Installing $APP into $INSTALL_DIR (port $PORT)"

# Compose file with the requested port (interpolated from the .env).
cp "$APP_DIR/docker-compose.yml" "$INSTALL_DIR/docker-compose.yml"

if [[ -f "$INSTALL_DIR/.env" ]]; then
    echo "    .env already exists — leaving it alone."
    echo "    (edit HOMEPAGE_PORT / HOMEPAGE_ALLOWED_HOSTS there if you change things)"
else
    cp "$APP_DIR/.env.example" "$INSTALL_DIR/.env"
    # bake the chosen port into the new .env
    sed -i "s/^HOMEPAGE_PORT=.*/HOMEPAGE_PORT=$PORT/" "$INSTALL_DIR/.env"
    # Homepage rejects any host not in HOMEPAGE_ALLOWED_HOSTS (HTTP 400) —
    # pre-allow localhost + the LAN IP so it works on first click.
    LAN_IP="$(hostname -I 2>/dev/null | awk '{print $1}')"
    if [[ -n "$LAN_IP" ]]; then
        sed -i "s|^HOMEPAGE_ALLOWED_HOSTS=.*|HOMEPAGE_ALLOWED_HOSTS=localhost:$PORT,127.0.0.1:$PORT,$LAN_IP:$PORT|" "$INSTALL_DIR/.env"
    else
        sed -i "s|^HOMEPAGE_ALLOWED_HOSTS=.*|HOMEPAGE_ALLOWED_HOSTS=localhost:$PORT,127.0.0.1:$PORT|" "$INSTALL_DIR/.env"
    fi
fi

# Starter config — only copied when the config dir is empty so upgrades
# never clobber your own services.yaml / widgets.yaml / settings.yaml.
if [[ -z "$(ls -A "$INSTALL_DIR/config" 2>/dev/null)" ]]; then
    cp -r "$APP_DIR"/config/. "$INSTALL_DIR/config/"
    echo "    starter config written to $INSTALL_DIR/config/"
else
    echo "    config/ not empty — keeping your existing config."
fi

echo "==> Starting with docker compose"
(cd "$INSTALL_DIR" && docker compose up -d)

# --- wait for HTTP ----------------------------------------------------------
echo "==> Waiting for $APP to answer on port $PORT..."
for i in $(seq 1 30); do
    if curl -fsS -o /dev/null "http://127.0.0.1:$PORT/" 2>/dev/null; then
        break
    fi
    sleep 1
    if [[ "$i" == 30 ]]; then
        echo "WARNING: container started but did not answer HTTP on port $PORT yet." >&2
        echo "Check: docker compose -f $INSTALL_DIR/docker-compose.yml logs" >&2
    fi
done

# --- done -------------------------------------------------------------------
IP="$(hostname -I 2>/dev/null | awk '{print $1}')"
cat <<EOF

✔ $APP is running!

  Local:      http://localhost:$PORT
  On your LAN: http://${IP:-<this-host>}:$PORT

Manage it:
  Update:     cd $INSTALL_DIR && docker compose pull && docker compose up -d
  Logs:       cd $INSTALL_DIR && docker compose logs -f
  Stop/start: cd $INSTALL_DIR && docker compose stop && docker compose start

Next steps:
  1. Open http://localhost:$PORT and check the starter dashboard.
  2. Edit $INSTALL_DIR/config/services.yaml to add YOUR services.
     Full docs: https://gethomepage.dev/configs/services
  3. localhost + this machine's LAN IP are already allowed. When you put it
     behind a reverse proxy (Nginx Proxy Manager etc.) or give it a
     hostname, add it to HOMEPAGE_ALLOWED_HOSTS in $INSTALL_DIR/.env or the
     dashboard answers HTTP 400 to that name:
       HOMEPAGE_ALLOWED_HOSTS=localhost:$PORT,127.0.0.1:$PORT,home.example.com
     then recreate: cd $INSTALL_DIR && docker compose up -d
EOF
