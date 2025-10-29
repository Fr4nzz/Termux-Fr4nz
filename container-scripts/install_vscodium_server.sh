#!/usr/bin/env bash
# Install openvscode-server to /opt/openvscode-server,
# force Open VSX marketplace, and add CLI helpers to install extensions.
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive

sudo apt-get update
sudo apt-get install -y curl ca-certificates tar coreutils jq

# --- 1) Detect arch -> pick correct openvscode-server build name ---
arch="$(dpkg --print-architecture 2>/dev/null || uname -m)"
case "$arch" in
  arm64|aarch64) OVS_ARCH="linux-arm64" ;;
  amd64|x86_64)  OVS_ARCH="linux-x64" ;;
  *)             OVS_ARCH="linux-arm64" ;;
esac

# --- 2) Find latest release tarball via GitHub API and install ---
tmpdir="$(mktemp -d)"; trap 'rm -rf "$tmpdir"' EXIT
echo "[*] Fetching latest openvscode-server release URL for $OVS_ARCH…"
LATEST_URL="$(curl -fsSL https://api.github.com/repos/gitpod-io/openvscode-server/releases/latest \
  | grep browser_download_url | grep "$OVS_ARCH.tar.gz" | head -n1 | cut -d '"' -f4)"

[ -n "$LATEST_URL" ] || { echo "Could not detect download URL for openvscode-server ($OVS_ARCH)." >&2; exit 1; }

echo "[*] Downloading: $LATEST_URL"
curl -L "$LATEST_URL" -o "$tmpdir/openvscode-server.tar.gz"

echo "[*] Installing to /opt/openvscode-server …"
sudo rm -rf /opt/openvscode-server
sudo install -d -m 0755 /opt/openvscode-server
sudo tar -xzf "$tmpdir/openvscode-server.tar.gz" -C /opt/openvscode-server --strip-components=1

# --- 3) Force Open VSX marketplace in openvscode-server's product.json ---
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

# --- 4) Helper: run locally on 127.0.0.1:13337 (unchanged) ---
sudo install -d -m 0755 /usr/local/bin
sudo tee /usr/local/bin/openvscode-server-local >/dev/null <<'SH'
#!/bin/sh
set -e
PORT="${1:-13337}"
[ -d "$HOME/.ovscode-data" ] || mkdir -p "$HOME/.ovscode-data"
[ -d "$HOME/.ovscode-extensions" ] || mkdir -p "$HOME/.ovscode-extensions"

exec /opt/openvscode-server/bin/openvscode-server \
  --host 127.0.0.1 \
  --port "$PORT" \
  --without-connection-token \
  --server-data-dir "$HOME/.ovscode-data" \
  --extensions-dir "$HOME/.ovscode-extensions" \
  "$@"
SH
sudo chmod 0755 /usr/local/bin/openvscode-server-local

# --- 5) Helper: install extensions into the server's extensions dir ---
sudo tee /usr/local/bin/openvscode-server-install-extensions >/dev/null <<'SH'
#!/bin/sh
set -e
# Usage:
#   openvscode-server-install-extensions ms-python.python esbenp.prettier-vscode
# or:
#   OPENVSCODE_EXTENSIONS="ms-python.python esbenp.prettier-vscode" openvscode-server-install-extensions
# or:
#   echo -e "ms-python.python\nesbenp.prettier-vscode" > ~/.ovscode-extensions.txt
#   openvscode-server-install-extensions
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
echo "Start locally:  openvscode-server-local"
echo "Install extensions now (Open VSX IDs), e.g.:"
echo "  openvscode-server-install-extensions ms-python.python ms-toolsai.jupyter esbenp.prettier-vscode"
# optional one-shot via env at install time:
if [ -n "${OPENVSCODE_EXTENSIONS:-}" ]; then
  echo "[*] Installing OPENVSCODE_EXTENSIONS from env…"
  openvscode-server-install-extensions >/dev/null || true
fi
