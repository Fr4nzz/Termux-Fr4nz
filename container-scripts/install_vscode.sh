#!/usr/bin/env bash
set -euo pipefail
if [[ $EUID -ne 0 ]]; then exec sudo -E bash "$0" "$@"; fi
export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y curl gnupg ca-certificates
install -d -m0755 /etc/apt/keyrings
curl -fsSL https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor -o /etc/apt/keyrings/packages.microsoft.gpg
ARCH="$(dpkg --print-architecture)"
echo "deb [arch=${ARCH} signed-by=/etc/apt/keyrings/packages.microsoft.gpg] https://packages.microsoft.com/repos/code stable main" \
  | tee /etc/apt/sources.list.d/vscode.list >/dev/null
apt-get update
apt-get install -y code
command -v desktopify >/dev/null 2>&1 || bash -lc 'curl -fsSL https://raw.githubusercontent.com/Fr4nzz/Termux-Fr4nz/refs/heads/main/container-scripts/install_desktopify.sh | bash'
desktopify code || true
echo "VS Code installed."
