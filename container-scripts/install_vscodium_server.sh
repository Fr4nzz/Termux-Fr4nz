#!/usr/bin/env bash
# Install openvscode-server (VS Code in the browser, MIT-licensed,
# basically "VSCodium Server" vibes) into /opt/openvscode-server
# and add a helper launcher.
#
# After this:
#   openvscode-server-local
#
# ...will start a server bound to 127.0.0.1:13337 with no auth token,
# intended for local-on-phone access. You'll open it from mobile Chrome/Firefox.
#
# The Termux-side wrappers (see install_vscodium_server_*_unattended.sh)
# will automate starting/stopping this from Termux with one command.

set -euo pipefail
export DEBIAN_FRONTEND=noninteractive

sudo apt-get update
sudo apt-get install -y curl ca-certificates tar coreutils

# --- 1) Detect arch -> pick correct openvscode-server build name
arch="$(dpkg --print-architecture 2>/dev/null || uname -m)"
case "$arch" in
  arm64|aarch64) OVS_ARCH="linux-arm64" ;;
  amd64|x86_64)  OVS_ARCH="linux-x64" ;;
  *)
    # Fallback; most Android phones in 2025 are arm64
    OVS_ARCH="linux-arm64"
    ;;
esac

# --- 2) Find latest release tarball via GitHub API and install
tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

echo "[*] Fetching latest openvscode-server release URL for $OVS_ARCH …"
LATEST_URL="$(curl -fsSL https://api.github.com/repos/gitpod-io/openvscode-server/releases/latest \
  | grep browser_download_url \
  | grep "$OVS_ARCH.tar.gz" \
  | head -n1 \
  | cut -d '"' -f4)"

if [ -z "$LATEST_URL" ]; then
  echo "Could not detect download URL for openvscode-server ($OVS_ARCH)." >&2
  exit 1
fi

echo "[*] Downloading: $LATEST_URL"
curl -L "$LATEST_URL" -o "$tmpdir/openvscode-server.tar.gz"

echo "[*] Installing to /opt/openvscode-server …"
sudo rm -rf /opt/openvscode-server
sudo install -d -m 0755 /opt/openvscode-server
sudo tar -xzf "$tmpdir/openvscode-server.tar.gz" -C /opt/openvscode-server --strip-components=1

# --- 3) Add a helper to run it locally (foreground)
# This is handy for manual testing INSIDE the container.
# Termux wrappers will run something very similar in the background.
sudo install -d -m 0755 /usr/local/bin
sudo tee /usr/local/bin/openvscode-server-local >/dev/null <<'SH'
#!/bin/sh
set -e

PORT="${1:-13337}"

# Data dirs (extensions, settings) will live in $HOME instead of /root/.config/something-weird.
[ -d "$HOME/.ovscode-data" ] || mkdir -p "$HOME/.ovscode-data"
[ -d "$HOME/.ovscode-extensions" ] || mkdir -p "$HOME/.ovscode-extensions"

exec /opt/openvscode-server/bin/openvscode-server \
  --host 127.0.0.1 \
  --port "$PORT" \
  --without-connection-token \
  --server-data-dir "$HOME/.ovscode-data" \
  --extensions-dir "$HOME/.ovscode-extensions"
SH
sudo chmod 0755 /usr/local/bin/openvscode-server-local

echo
echo "✅ openvscode-server installed in /opt/openvscode-server"
echo "Try it inside the container:"
echo "    openvscode-server-local"
echo "Then, on the phone browser, open: http://127.0.0.1:13337"
