#!/usr/bin/env bash
set -euo pipefail
# escalate if needed
if [ "${EUID:-$(id -u)}" -ne 0 ]; then exec sudo -E bash "$0" "$@"; fi
export DEBIAN_FRONTEND=noninteractive

# 0) Ensure R exists (your repo script)
if ! command -v R >/dev/null 2>&1; then
  curl -fsSL https://raw.githubusercontent.com/Fr4nzz/Termux-Fr4nz/refs/heads/main/container-scripts/install_r_binaries.sh | bash
fi

apt-get update -y

# 1) Noble’s t64 transition: pick the right sonames if present
pick() { apt-cache show "$1" >/dev/null 2>&1 && echo "$1" || echo "$2"; }
SSL_PKG="$(pick libssl3t64 libssl3)"
CURL_PKG="$(pick libcurl4t64 libcurl4)"
READLINE_PKG="$(pick libreadline8t64 libreadline8)"

apt-get install -y --no-install-recommends \
  gdebi-core gnupg lsb-release ca-certificates wget \
  "$SSL_PKG" libxml2 "$CURL_PKG" libedit2 libuuid1 \
  libpq5 libsqlite3-0 libbz2-1.0 liblzma5 "$READLINE_PKG"

# 2) Build a redirect URL to the latest RStudio Server
arch="$(dpkg --print-architecture 2>/dev/null || uname -m)"
case "$arch" in
  arm64|aarch64) PLATFORM="arm64" ; CHANNEL="${RSTUDIO_CHANNEL:-daily}" ;;  # arm64 is daily/experimental
  amd64|x86_64)  PLATFORM="amd64" ; CHANNEL="${RSTUDIO_CHANNEL:-stable}" ;;
  *) echo "Unsupported architecture: $arch"; exit 1 ;;
esac

BASE="https://rstudio.org/download/latest/${CHANNEL}/server/jammy"
DEB_URL="${BASE}/rstudio-server-latest-${PLATFORM}.deb"  # 302 → current .deb on S3
TMP_DEB="$(mktemp --suffix=.deb)"

echo "[*] Downloading ${DEB_URL}"
curl -fsSL -L "$DEB_URL" -o "$TMP_DEB"

# 3) Install with gdebi, fallback to dpkg + apt -f
if ! gdebi -n "$TMP_DEB"; then
  echo "[warn] gdebi failed; trying dpkg + apt -f install"
  dpkg -i "$TMP_DEB" || true
  apt-get -f install -y
fi
rm -f "$TMP_DEB"

# 4) Smoke checks
rstudio-server verify-installation || true
rstudio-server stop || true

echo "✅ RStudio Server installed."
echo "Start it with:  rstudio-server start   (listens on :8787)"
