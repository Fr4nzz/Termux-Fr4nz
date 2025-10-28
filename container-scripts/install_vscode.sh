#!/usr/bin/env bash
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive

sudo apt-get update
sudo apt-get install -y curl gnupg ca-certificates
sudo install -d -m0755 /etc/apt/keyrings

curl -fsSL https://packages.microsoft.com/keys/microsoft.asc \
  | sudo gpg --dearmor -o /etc/apt/keyrings/packages.microsoft.gpg

ARCH="$(dpkg --print-architecture)"
echo "deb [arch=${ARCH} signed-by=/etc/apt/keyrings/packages.microsoft.gpg] https://packages.microsoft.com/repos/code stable main" \
  | sudo tee /etc/apt/sources.list.d/vscode.list >/dev/null

sudo apt-get update
sudo apt-get install -y code

command -v desktopify >/dev/null 2>&1 || bash -lc 'curl -fsSL https://raw.githubusercontent.com/Fr4nzz/Termux-Fr4nz/refs/heads/main/container-scripts/install_desktopify.sh | bash'
desktopify code || true

echo "VS Code installed."
