#!/usr/bin/env bash
set -euo pipefail
if [[ $EUID -ne 0 ]]; then exec sudo -E bash "$0" "$@"; fi
export DEBIAN_FRONTEND=noninteractive
if ! command -v R >/dev/null 2>&1; then
  curl -fsSL https://raw.githubusercontent.com/Fr4nzz/Termux-Fr4nz/refs/heads/main/container-scripts/install_r_binaries.sh | bash
fi
apt-get update
apt-get install -y wget gdebi-core
DEB_URL="https://s3.amazonaws.com/rstudio-ide-build/electron/jammy/arm64/rstudio-2025.11.0-daily-271-arm64.deb"
wget -O /tmp/rstudio-arm64.deb "$DEB_URL"
gdebi -n /tmp/rstudio-arm64.deb || apt-get -f install -y
command -v desktopify >/dev/null 2>&1 || bash -lc 'curl -fsSL https://raw.githubusercontent.com/Fr4nzz/Termux-Fr4nz/refs/heads/main/container-scripts/install_desktopify.sh | bash'
desktopify rstudio || true
echo "RStudio Desktop installed."
