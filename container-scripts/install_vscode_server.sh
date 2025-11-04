#!/usr/bin/env bash
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive

apt-get update
apt-get install -y curl ca-certificates tar coreutils openssl

# Detect arch
arch="$(dpkg --print-architecture 2>/dev/null || uname -m)"
case "$arch" in
  arm64|aarch64) CS_ARCH="linux-arm64" ;;
  amd64|x86_64)  CS_ARCH="linux-amd64" ;;
  *)             CS_ARCH="linux-arm64" ;;
esac

# Fetch latest release tarball URL
tmpdir="$(mktemp -d)"; trap 'rm -rf "$tmpdir"' EXIT
DL_URL="$(curl -fsSL https://api.github.com/repos/coder/code-server/releases/latest \
  | grep browser_download_url \
  | grep "${CS_ARCH}.tar.gz" \
  | head -n1 | cut -d '"' -f4)"
[ -n "$DL_URL" ] || { echo "Could not find code-server for $CS_ARCH"; exit 1; }

echo "[*] Downloading $DL_URL"
curl -L "$DL_URL" -o "$tmpdir/code-server.tgz"

echo "[*] Installing to /opt/code-server…"
if [ -d /opt/code-server ]; then
  find /opt/code-server -type f -delete 2>/dev/null || true
  find /opt/code-server -depth -type d -delete 2>/dev/null || true
  rm -rf /opt/code-server 2>/dev/null || true
fi
install -d -m 0755 /opt/code-server
tar -xzf "$tmpdir/code-server.tgz" -C /opt/code-server --strip-components=1

# Generate self-signed certificate if not exists
install -d -m 0755 /etc/code-server
if [ ! -f /etc/code-server/cert.pem ]; then
  echo "[*] Generating self-signed certificate for HTTPS..."
  openssl req -x509 -newkey rsa:4096 -nodes \
    -keyout /etc/code-server/key.pem \
    -out /etc/code-server/cert.pem \
    -days 365 -subj "/CN=localhost"
  chmod 600 /etc/code-server/key.pem
  chmod 644 /etc/code-server/cert.pem
fi

# Fix HOME directory for root user
if [ ! -d /root ]; then
  mkdir -p /root
fi
chown -R root:root /root
echo "export HOME=/root" >> /root/.bashrc 2>/dev/null || true

# Helper scripts
install -d -m 0755 /usr/local/bin

# Start helper with HTTPS support
tee /usr/local/bin/code-server-local >/dev/null <<'SCRIPT'
#!/bin/sh
set -e
PORT="${1:-13338}"

# Ensure HOME is set
export HOME="${HOME:-/root}"
[ -d "$HOME" ] || mkdir -p "$HOME"

[ -d "$HOME/.code-server-data" ] || mkdir -p "$HOME/.code-server-data"
[ -d "$HOME/.code-server-extensions" ] || mkdir -p "$HOME/.code-server-extensions"

# Check if we should use HTTPS
if [ -f /etc/code-server/cert.pem ] && [ -f /etc/code-server/key.pem ]; then
  echo "Starting code-server with HTTPS on port $PORT"
  echo "Access at: https://127.0.0.1:$PORT or https://<your-ip>:$PORT"
  echo "Note: Browser will warn about self-signed certificate - this is normal"
  exec /opt/code-server/bin/code-server \
    --bind-addr 0.0.0.0:"$PORT" \
    --auth none \
    --cert /etc/code-server/cert.pem \
    --cert-key /etc/code-server/key.pem \
    --user-data-dir "$HOME/.code-server-data" \
    --extensions-dir "$HOME/.code-server-extensions" \
    "$@"
else
  echo "Starting code-server with HTTP on port $PORT"
  echo "Warning: Web views may not work over HTTP on non-localhost addresses"
  exec /opt/code-server/bin/code-server \
    --bind-addr 0.0.0.0:"$PORT" \
    --auth none \
    --user-data-dir "$HOME/.code-server-data" \
    --extensions-dir "$HOME/.code-server-extensions" \
    "$@"
fi
SCRIPT
chmod 0755 /usr/local/bin/code-server-local

# Stop helper
tee /usr/local/bin/code-server-stop >/dev/null <<'SCRIPT'
#!/bin/sh
set -e
pkill -9 -f '/opt/code-server/bin/code-server' 2>/dev/null || true
echo "✅ code-server stopped"
SCRIPT
chmod 0755 /usr/local/bin/code-server-stop

echo
echo "✅ code-server installed in /opt/code-server"
echo "✅ HTTPS enabled with self-signed certificate"
echo "Start:  code-server-local [port]"
echo "Stop:   code-server-stop"
echo "Default: https://127.0.0.1:13338"
echo "LAN:     https://<your-phone-ip>:13338"