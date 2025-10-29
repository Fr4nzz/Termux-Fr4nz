#!/usr/bin/env bash
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive

# 1. ensure R exists first (RStudio Desktop expects R on PATH)
if ! command -v R >/dev/null 2>&1; then
  curl -fsSL https://raw.githubusercontent.com/Fr4nzz/Termux-Fr4nz/refs/heads/main/container-scripts/install_r_binaries.sh | bash
fi

# 2. pull in Electron/Chromium-style runtime libs that the arm64 build of RStudio uses
sudo apt-get update
sudo apt-get install -y \
    wget gdebi-core \
    libnspr4 libnss3 libxss1 libgbm1 || true

# 3. download & install the arm64 .deb
DEB_URL="https://s3.amazonaws.com/rstudio-ide-build/electron/jammy/arm64/rstudio-2025.11.0-daily-271-arm64.deb"
wget -O /tmp/rstudio-arm64.deb "$DEB_URL"
sudo gdebi -n /tmp/rstudio-arm64.deb || sudo apt-get -f install -y

# 4. ensure desktopify is around, then drop an icon to Desktop
command -v desktopify >/dev/null 2>&1 || bash -lc 'curl -fsSL https://raw.githubusercontent.com/Fr4nzz/Termux-Fr4nz/refs/heads/main/container-scripts/install_desktopify.sh | bash'
desktopify rstudio || true

echo "✅ RStudio Desktop installed."
echo "Launch it from the XFCE desktop icon (or run 'rstudio' in a DISPLAY-ready shell)."
