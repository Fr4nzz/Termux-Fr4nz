#!/usr/bin/env bash
set -euo pipefail
if [[ $EUID -ne 0 ]]; then exec sudo -E bash "$0" "$@"; fi
export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y curl gnupg ca-certificates
install -d -m0755 /etc/apt/keyrings
curl -fsSL https://packages.mozilla.org/apt/repo-signing-key.gpg | gpg --dearmor -o /etc/apt/keyrings/mozilla.gpg
tee /etc/apt/preferences.d/mozilla >/dev/null <<'EOF'
Package: *
Pin: origin packages.mozilla.org
Pin-Priority: 1000
EOF
echo "deb [signed-by=/etc/apt/keyrings/mozilla.gpg] https://packages.mozilla.org/apt mozilla main" \
  | tee /etc/apt/sources.list.d/mozilla.list >/dev/null
apt-get update
apt-get install -y firefox
command -v desktopify >/dev/null 2>&1 || bash -lc 'curl -fsSL https://raw.githubusercontent.com/Fr4nzz/Termux-Fr4nz/refs/heads/main/container-scripts/install_desktopify.sh | bash'
desktopify firefox || true
echo "Firefox installed."
