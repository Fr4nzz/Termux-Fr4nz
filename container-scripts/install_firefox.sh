#!/usr/bin/env bash
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive

sudo apt-get update
sudo apt-get install -y curl gnupg ca-certificates

sudo install -d -m0755 /etc/apt/keyrings
curl -fsSL https://packages.mozilla.org/apt/repo-signing-key.gpg \
  | sudo gpg --dearmor -o /etc/apt/keyrings/mozilla.gpg

sudo tee /etc/apt/preferences.d/mozilla >/dev/null <<'EOF'
Package: *
Pin: origin packages.mozilla.org
Pin-Priority: 1000
EOF

echo "deb [signed-by=/etc/apt/keyrings/mozilla.gpg] https://packages.mozilla.org/apt mozilla main" \
  | sudo tee /etc/apt/sources.list.d/mozilla.list >/dev/null

sudo apt-get update
sudo apt-get install -y firefox

# add desktop icon if helper exists, install it otherwise
command -v desktopify >/dev/null 2>&1 || bash -lc 'curl -fsSL https://raw.githubusercontent.com/Fr4nzz/Termux-Fr4nz/refs/heads/main/container-scripts/install_desktopify.sh | bash'
desktopify firefox || true

echo "Firefox installed."
