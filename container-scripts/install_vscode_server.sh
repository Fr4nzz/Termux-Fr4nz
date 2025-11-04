#!/usr/bin/env bash
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive

apt-get update -qq
apt-get install -y -qq curl ca-certificates tar coreutils openssl jq

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
rm -rf /opt/code-server 2>/dev/null || true
install -d -m 0755 /opt/code-server
tar -xzf "$tmpdir/code-server.tgz" -C /opt/code-server --strip-components=1

# Suppress vsda warnings
mkdir -p /opt/code-server/lib/vscode/node_modules/vsda/rust/web
touch /opt/code-server/lib/vscode/node_modules/vsda/rust/web/vsda_{bg.wasm,js}

# Enable Microsoft marketplace (faster extension downloads)
echo "[*] Enabling Microsoft marketplace..."
PRODUCT_JSON="/opt/code-server/lib/vscode/product.json"
if [ -f "$PRODUCT_JSON" ]; then
  jq '. + {
    "extensionsGallery": {
      "serviceUrl": "https://marketplace.visualstudio.com/_apis/public/gallery",
      "cacheUrl": "https://vscode.blob.core.windows.net/gallery/index",
      "itemUrl": "https://marketplace.visualstudio.com/items",
      "resourceUrlTemplate": "https://marketplace.visualstudio.com/_apis/public/gallery/publishers/{publisher}/vsextensions/{name}/{version}/vspackage"
    }
  }' "$PRODUCT_JSON" > "$tmpdir/product.json" && mv "$tmpdir/product.json" "$PRODUCT_JSON"
fi

# Fix HOME directory for root user
mkdir -p /root
chown -R root:root /root

# Helper scripts
install -d -m 0755 /usr/local/bin /etc/code-server

# Local mode (HTTP on localhost - for webviews to work)
tee /usr/local/bin/code-server-local >/dev/null <<'SCRIPT'
#!/bin/sh
set -e
PORT="${1:-13338}"
export HOME="${HOME:-/root}"
mkdir -p "$HOME/.code-server-data" "$HOME/.code-server-extensions"

echo "========================================"
echo "VS Code Server (LOCAL MODE)"
echo "Local:  http://127.0.0.1:$PORT"
echo "========================================"
echo "✅ Webviews work (ChatGPT, Gemini, etc.)"
echo "❌ Not accessible from other devices"
echo ""

exec /opt/code-server/bin/code-server \
  --bind-addr "127.0.0.1:$PORT" \
  --auth none \
  --user-data-dir "$HOME/.code-server-data" \
  --extensions-dir "$HOME/.code-server-extensions" \
  --disable-telemetry \
  --disable-update-check
SCRIPT
chmod 0755 /usr/local/bin/code-server-local

# LAN mode (HTTPS with certificate - for laptop access)
tee /usr/local/bin/code-server-lan >/dev/null <<'SCRIPT'
#!/bin/sh
set -e
PORT="${1:-13338}"
export HOME="${HOME:-/root}"
mkdir -p "$HOME/.code-server-data" "$HOME/.code-server-extensions"

# Check for certificates
CERT_DIR="/etc/code-server"
if [ ! -f "$CERT_DIR/cert.pem" ] || [ ! -f "$CERT_DIR/key.pem" ]; then
  echo "❌ No certificate found. Run one of:"
  echo "   setup-letsencrypt  (for real trusted cert)"
  echo "   setup-localca      (for local self-signed CA)"
  exit 1
fi

LOCAL_IP=$(hostname -I | awk '{print $1}')
echo "========================================"
echo "VS Code Server (LAN MODE)"
echo "Local:  https://127.0.0.1:$PORT"
echo "LAN:    https://$LOCAL_IP:$PORT"
echo "========================================"
echo "✅ Accessible from laptop/other devices"
echo "⚠️  Requires trusted certificate for webviews"
echo ""

exec /opt/code-server/bin/code-server \
  --bind-addr "0.0.0.0:$PORT" \
  --cert "$CERT_DIR/cert.pem" \
  --cert-key "$CERT_DIR/key.pem" \
  --auth none \
  --user-data-dir "$HOME/.code-server-data" \
  --extensions-dir "$HOME/.code-server-extensions" \
  --disable-telemetry \
  --disable-update-check
SCRIPT
chmod 0755 /usr/local/bin/code-server-lan

# Stop helper
tee /usr/local/bin/code-server-stop >/dev/null <<'SCRIPT'
#!/bin/sh
pkill -f '/opt/code-server/bin/code-server' 2>/dev/null || true
echo "✅ code-server stopped"
SCRIPT
chmod 0755 /usr/local/bin/code-server-stop

# Quick extension installer
tee /usr/local/bin/ext-install >/dev/null <<'SCRIPT'
#!/bin/sh
[ -z "$1" ] && { echo "Usage: ext-install <extension-id>"; exit 1; }
export HOME="${HOME:-/root}"
/opt/code-server/bin/code-server \
  --user-data-dir "$HOME/.code-server-data" \
  --extensions-dir "$HOME/.code-server-extensions" \
  --install-extension "$1"
SCRIPT
chmod 0755 /usr/local/bin/ext-install

echo
echo "✅ code-server installed"
echo "✅ Microsoft marketplace enabled"
echo ""
echo "Modes:"
echo "  code-server-local  # HTTP localhost (webviews work)"
echo "  code-server-lan    # HTTPS LAN access (needs cert)"
echo "  code-server-stop   # Stop server"