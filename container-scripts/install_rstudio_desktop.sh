#!/usr/bin/env bash
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive

# ensure R exists
if ! command -v R >/dev/null 2>&1; then
  curl -fsSL https://raw.githubusercontent.com/Fr4nzz/Termux-Fr4nz/refs/heads/main/container-scripts/install_r_binaries.sh | bash
fi

sudo apt-get update
sudo apt-get install -y wget gdebi-core
DEB_URL="https://s3.amazonaws.com/rstudio-ide-build/electron/jammy/arm64/rstudio-2025.11.0-daily-271-arm64.deb"
wget -O /tmp/rstudio-arm64.deb "$DEB_URL"
sudo gdebi -n /tmp/rstudio-arm64.deb || sudo apt-get -f install -y

command -v desktopify >/dev/null 2>&1 || bash -lc 'curl -fsSL https://raw.githubusercontent.com/Fr4nzz/Termux-Fr4nz/refs/heads/main/container-scripts/install_desktopify.sh | bash'
desktopify rstudio || true

echo "RStudio Desktop installed."
