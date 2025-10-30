#!/usr/bin/env bash
set -euo pipefail
if [[ $EUID -ne 0 ]]; then exec sudo -E bash "$0" "$@"; fi
export DEBIAN_FRONTEND=noninteractive

# Ensure R if missing
if ! command -v R >/dev/null 2>&1; then
  curl -fsSL https://raw.githubusercontent.com/Fr4nzz/Termux-Fr4nz/refs/heads/main/container-scripts/install_r_binaries.sh | bash
fi

apt-get update
apt-get install -y --no-install-recommends \
  gdebi-core gnupg lsb-release ca-certificates wget \
  libssl3 libxml2 libcurl4 libedit2 libuuid1 \
  libpq5 libsqlite3-0 libbz2-1.0 liblzma5 libreadline8

RSTUDIO_DEB_URL="https://download2.rstudio.org/server/jammy/arm64/rstudio-server-2023.12.1-402-arm64.deb"
TMP_DEB="$(mktemp --suffix=.deb)"
wget -O "$TMP_DEB" "$RSTUDIO_DEB_URL"
gdebi -n "$TMP_DEB" || apt-get -f install -y
rm -f "$TMP_DEB"

rstudio-server verify-installation || true
rstudio-server stop || true
echo "RStudio Server installed."
