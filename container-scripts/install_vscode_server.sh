#!/usr/bin/env bash
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive

sudo apt-get update
sudo apt-get install -y curl ca-certificates tar coreutils

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
sudo rm -rf /opt/code-server
sudo install -d -m 0755 /opt/code-server
# release tarballs are like code-server-<ver>-<arch>/*
sudo tar -xzf "$tmpdir/code-server.tgz" -C /opt/code-server --strip-components=1

# Helper: run locally on 127.0.0.1:13338, no auth (safe for local phone browser)
sudo install -d -m 0755 /usr/local/bin
sudo tee /usr/local/bin/code-server-local >/dev/null <<'SH'
#!/bin/sh
set -e
PORT="${1:-13338}"
[ -d "$HOME/.code-server-data" ] || mkdir -p "$HOME/.code-server-data"
[ -d "$HOME/.code-server-extensions" ] || mkdir -p "$HOME/.code-server-extensions"

exec /opt/code-server/bin/code-server \
  --bind-addr 127.0.0.1:"$PORT" \
  --auth none \
  --user-data-dir "$HOME/.code-server-data" \
  --extensions-dir "$HOME/.code-server-extensions" \
  "$@"
SH
sudo chmod 0755 /usr/local/bin/code-server-local

echo
echo "✅ code-server installed in /opt/code-server"
echo "Run inside the container:  code-server-local"
echo "Open on phone: http://127.0.0.1:13338"
