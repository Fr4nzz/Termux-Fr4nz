#!/usr/bin/env bash
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive

apt-get update -qq
apt-get install -y -qq curl ca-certificates tar coreutils jq

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
install -d -m 0755 /usr/local/bin

# Single wrapper with DPI support
tee /usr/local/bin/code-server-local >/dev/null <<'SCRIPT'
#!/bin/sh
set -e

# Parse arguments
PORT="13338"
DPI=""

while [ $# -gt 0 ]; do
  case "$1" in
    --dpi)
      DPI="$2"
      shift 2
      ;;
    --port)
      PORT="$2"
      shift 2
      ;;
    *)
      PORT="$1"
      shift
      ;;
  esac
done

export HOME="${HOME:-/root}"
mkdir -p "$HOME/.code-server-data" "$HOME/.code-server-extensions"

LOCAL_IP=$(hostname -I | awk '{print $1}' 2>/dev/null || echo "N/A")

echo "========================================="
echo "VS Code Server"
echo "========================================="
echo ""
echo "Access options:"
echo "  1. Phone browser:  http://127.0.0.1:$PORT"
echo "  2. Laptop via ADB: adb forward tcp:$PORT tcp:$PORT"
echo "                     then http://127.0.0.1:$PORT"
echo "  3. Laptop via LAN: http://$LOCAL_IP:$PORT"
echo ""
if [ -n "$DPI" ]; then
  echo "📱 DPI override: $DPI (smaller UI for phone)"
  echo ""
fi
echo "ℹ️  For ChatGPT/Gemini to work:"
echo "   - Use http://127.0.0.1:$PORT (options 1 or 2)"
echo "   - Webviews don't work on LAN IP (option 3)"
echo ""
echo "Press Ctrl+C to stop"
echo "========================================="

# Set DPI if specified (higher DPI = smaller UI)
if [ -n "$DPI" ]; then
  export VSCODE_FORCE_DPI="$DPI"
fi

exec /opt/code-server/bin/code-server \
  --bind-addr "0.0.0.0:$PORT" \
  --auth none \
  --user-data-dir "$HOME/.code-server-data" \
  --extensions-dir "$HOME/.code-server-extensions" \
  --disable-telemetry \
  --disable-update-check
SCRIPT
chmod 0755 /usr/local/bin/code-server-local

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
echo "Commands:"
echo "  code-server-local [PORT]           # Start server (default: 13338)"
echo "  code-server-local --dpi DPI        # Start with custom DPI (e.g., 200 for smaller UI)"
echo "  code-server-local --port PORT      # Specify port"
echo "  code-server-stop                   # Stop server"
echo "  ext-install <id>                   # Install extension"
echo ""
echo "DPI examples:"
echo "  - Default (100): Normal size"
echo "  - 150: Slightly smaller"
echo "  - 200: Much smaller (recommended for phones)"
echo "  - 250: Very compact"
echo ""

# Setup R environment
echo "[*] Setting up R environment..."
if curl -fsSL https://raw.githubusercontent.com/Fr4nzz/Termux-Fr4nz/refs/heads/main/container-scripts/install_vscode_r_setup.sh | bash; then
  echo "✅ R environment configured"
else
  echo "⚠️  R setup failed or skipped"
fi

# Setup Python environment
echo "[*] Setting up Python environment..."
if curl -fsSL https://raw.githubusercontent.com/Fr4nzz/Termux-Fr4nz/refs/heads/main/container-scripts/install_vscode_python_setup.sh | bash; then
  echo "✅ Python environment configured"
else
  echo "⚠️  Python setup failed or skipped"
fi

echo ""
echo "========================================="
echo "Setup complete!"
echo "========================================="
echo ""
echo "Access methods:"
echo "  Phone:         http://127.0.0.1:13338"
echo "  Laptop (ADB):  adb forward tcp:13338 tcp:13338"
echo "  Laptop (LAN):  http://<phone-ip>:13338"
echo ""
echo "Start with custom DPI:"
echo "  code-server-local --dpi 200"