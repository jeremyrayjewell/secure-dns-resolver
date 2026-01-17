#!/bin/sh
set -eu

APP_ROOT="/app"
VAR_DIR="$APP_ROOT/var"

DATA_DIR="/data"
KEY_PATH="$DATA_DIR/server.key"
CERT_PATH="$DATA_DIR/server.pem"
ACL_PATH="$DATA_DIR/access-control.conf"

mkdir -p "$DATA_DIR" "$VAR_DIR"

# Secrets are expected to be injected at runtime (Fly.io secrets):
# - TLS_SERVER_KEY  (PEM private key)
# - TLS_SERVER_CERT (PEM certificate)
#
# NOTE: Do not log these values.

if [ -z "${TLS_SERVER_KEY:-}" ]; then
  echo "Missing required env var: TLS_SERVER_KEY" >&2
  exit 1
fi

if [ -z "${TLS_SERVER_CERT:-}" ]; then
  echo "Missing required env var: TLS_SERVER_CERT" >&2
  exit 1
fi

# Lock down file permissions from the start.
umask 077

printf "%s" "$TLS_SERVER_KEY" > "$KEY_PATH"
printf "%s" "$TLS_SERVER_CERT" > "$CERT_PATH"

chmod 600 "$KEY_PATH" "$CERT_PATH" || true

if [ ! -s "$KEY_PATH" ]; then
  echo "TLS key file missing/empty: $KEY_PATH" >&2
  exit 1
fi

if [ ! -s "$CERT_PATH" ]; then
  echo "TLS cert file missing/empty: $CERT_PATH" >&2
  exit 1
fi

# Generate additional ACLs. Defaults:
# - On Fly.io: allow Fly private 6PN range (fdaa::/8)
# - Local dev: set UNBOUND_ALLOWED_NETS to a comma-separated list (e.g. 172.16.0.0/12,192.168.0.0/16)
{
  echo "# Generated at startup. Do not commit."
  if [ -n "${FLY_APP_NAME:-}" ] || [ -n "${FLY_REGION:-}" ]; then
    echo "access-control: fdaa::/8 allow"
  fi

  if [ -n "${UNBOUND_ALLOWED_NETS:-}" ]; then
    old_ifs="$IFS"
    IFS=','
    for net in $UNBOUND_ALLOWED_NETS; do
      net_trimmed="$(echo "$net" | tr -d '[:space:]')"
      if [ -n "$net_trimmed" ]; then
        echo "access-control: $net_trimmed allow"
      fi
    done
    IFS="$old_ifs"
  fi
} > "$ACL_PATH"

chmod 600 "$ACL_PATH" || true

# Bootstrap trust anchor if missing (required for DNSSEC validation).
if [ ! -f "$VAR_DIR/root.key" ]; then
  if command -v unbound-anchor >/dev/null 2>&1; then
    echo "Bootstrapping DNSSEC trust anchor -> $VAR_DIR/root.key"
    unbound-anchor -a "$VAR_DIR/root.key"
  else
    echo "WARN: unbound-anchor not found; DNSSEC may fail without $VAR_DIR/root.key" >&2
  fi
fi

CONFIG_PATH="$APP_ROOT/configs/unbound/unbound.fly.conf"
if [ ! -f "$CONFIG_PATH" ]; then
  CONFIG_PATH="$APP_ROOT/configs/unbound/unbound.conf"
fi

echo "Starting Unbound with config: $CONFIG_PATH"
exec unbound -d -c "$CONFIG_PATH"
