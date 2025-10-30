#!/usr/bin/env bash
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive

sudo apt-get update
sudo apt-get install -y curl ca-certificates tar coreutils jq

# Detect arch
arch="$(dpkg --print-architecture 2>/dev/null || uname -m)"
case "$arch" in
  arm64|aarch64) OVS_ARCH="linux-arm64" ;;
  amd64|x86_64)  OVS_ARCH="linux-x64" ;;
  *)             OVS_ARCH="linux-arm64" ;;
esac

# Find latest release tarball
tmpdir="$(mktemp -d)"; trap 'rm -rf "$tmpdir"' EXIT
echo "[*] Fetching latest openvscode-server release URL for $OVS_ARCH…"
LATEST_URL="$(curl -fsSL https://api.github.com/repos/gitpod-io/openvscode-server/releases/latest \
  | grep browser_download_url | grep "$OVS_ARCH.tar.gz" | head -n1 | cut -d '"' -f4)"

[ -n "$LATEST_URL" ] || { echo "Could not detect download URL for openvscode-server ($OVS_ARCH)." >&2; exit 1; }

echo "[*] Downloading: $LATEST_URL"
curl -L "$LATEST_URL" -o "$tmpdir/openvscode-server.tar.gz"

echo "[*] Installing to /opt/openvscode-server …"
if [ -d /opt/openvscode-server ]; then
  sudo find /opt/openvscode-server -type f -delete 2>/dev/null || true
  sudo find /opt/openvscode-server -depth -type d -delete 2>/dev/null || true
  sudo rm -rf /opt/openvscode-server 2>/dev/null || true
fi
sudo install -d -m 0755 /opt/openvscode-server
sudo tar -xzf "$tmpdir/openvscode-server.tar.gz" -C /opt/openvscode-server --strip-components=1

# Force Open VSX marketplace
if [ -f /opt/openvscode-server/product.json ]; then
  echo "[*] Patching Open VSX marketplace in: /opt/openvscode-server/product.json"
  sudo cp /opt/openvscode-server/product.json /opt/openvscode-server/product.json.bak.$(date +%s) || true
  sudo jq '
    .extensionsGallery = {
      serviceUrl: "https://open-vsx.org/vscode/gallery",
      itemUrl:    "https://open-vsx.org/vscode/item"
    }
    | .linkProtectionTrustedDomains =
        ((.linkProtectionTrustedDomains // []) + ["https://open-vsx.org"] | unique)
  ' /opt/openvscode-server/product.json | sudo tee /opt/openvscode-server/product.json.tmp >/dev/null
  sudo mv /opt/openvscode-server/product.json.tmp /opt/openvscode-server/product.json
fi

# Helper: LAN-accessible on 0.0.0.0:13337
sudo install -d -m 0755 /usr/local/bin
sudo tee /usr/local/bin/openvscode-server-local >/dev/null <<'SH'
#!/bin/sh
set -e
PORT="${1:-13337}"
[ -d "$HOME/.ovscode-data" ] || mkdir -p "$HOME/.ovscode-data"
[ -d "$HOME/.ovscode-extensions" ] || mkdir -p "$HOME/.ovscode-extensions"

exec /opt/openvscode-server/bin/openvscode-server \
  --host 0.0.0.0 \
  --port "$PORT" \
  --without-connection-token \
  --server-data-dir "$HOME/.ovscode-data" \
  --extensions-dir "$HOME/.ovscode-extensions" \
  "$@"
SH
sudo chmod 0755 /usr/local/bin/openvscode-server-local

# Extension installer helper
sudo tee /usr/local/bin/openvscode-server-install-extensions >/dev/null <<'SH'
#!/bin/sh
set -e
LIST="$@"
[ -z "$LIST" ] && [ -n "${OPENVSCODE_EXTENSIONS:-}" ] && LIST="$OPENVSCODE_EXTENSIONS"
if [ -z "$LIST" ] && [ -f "$HOME/.ovscode-extensions.txt" ]; then
  LIST="$(grep -vE '^\s*(#|$)' "$HOME/.ovscode-extensions.txt" || true)"
fi
if [ -z "$LIST" ]; then
  echo "No extensions specified. Pass IDs as args, set OPENVSCODE_EXTENSIONS, or create ~/.ovscode-extensions.txt"
  exit 0
fi

EXT_DIR="$HOME/.ovscode-extensions"
mkdir -p "$EXT_DIR"
for ext in $LIST; do
  echo "Installing/updating: $ext"
  /opt/openvscode-server/bin/openvscode-server \
    --install-extension "$ext" \
    --force \
    --extensions-dir "$EXT_DIR" >/dev/null
done
echo "Done."
SH
sudo chmod 0755 /usr/local/bin/openvscode-server-install-extensions

echo
echo "✅ openvscode-server installed in /opt/openvscode-server (Open VSX enabled)."
echo "Start:  openvscode-server-local"
echo "LAN access: http://<your-phone-ip>:13337"
if [ -n "${OPENVSCODE_EXTENSIONS:-}" ]; then
  echo "[*] Installing OPENVSCODE_EXTENSIONS from env…"
  openvscode-server-install-extensions >/dev/null || true
fi