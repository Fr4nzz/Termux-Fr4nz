#!/usr/bin/env bash
set -euo pipefail
# escalate if needed
if [ "${EUID:-$(id -u)}" -ne 0 ]; then exec sudo -E bash "$0" "$@"; fi
export DEBIAN_FRONTEND=noninteractive

# -------------------------
# 0) Ensure R is present
# -------------------------
if ! command -v R >/dev/null 2>&1; then
  curl -fsSL https://raw.githubusercontent.com/Fr4nzz/Termux-Fr4nz/refs/heads/main/container-scripts/install_r_binaries.sh | bash
fi

apt-get update -y

# ----------------------------------------------
# 1) Noble t64 libs: choose correct package names
# ----------------------------------------------
pick() { apt-cache show "$1" >/dev/null 2>&1 && echo "$1" || echo "$2"; }
SSL_PKG="$(pick libssl3t64 libssl3)"
CURL_PKG="$(pick libcurl4t64 libcurl4)"
READLINE_PKG="$(pick libreadline8t64 libreadline8)"

apt-get install -y --no-install-recommends \
  gdebi-core gnupg lsb-release ca-certificates wget \
  "$SSL_PKG" libxml2 "$CURL_PKG" libedit2 libuuid1 \
  libpq5 libsqlite3-0 libbz2-1.0 liblzma5 "$READLINE_PKG"

# ----------------------------------------------
# 2) Fetch latest RStudio Server (Posit redirect)
# ----------------------------------------------
arch="$(dpkg --print-architecture 2>/dev/null || uname -m)"
case "$arch" in
  arm64|aarch64) PLATFORM="arm64" ; CHANNEL="${RSTUDIO_CHANNEL:-daily}" ;;  # arm64 builds are daily/experimental
  amd64|x86_64)  PLATFORM="amd64" ; CHANNEL="${RSTUDIO_CHANNEL:-stable}" ;;
  *) echo "Unsupported architecture: $arch"; exit 1 ;;
esac

BASE="https://rstudio.org/download/latest/${CHANNEL}/server/jammy"
DEB_URL="${BASE}/rstudio-server-latest-${PLATFORM}.deb"  # 302 → current build
TMP_DEB="$(mktemp --suffix=.deb)"

echo "[*] Downloading ${DEB_URL}"
curl -fsSL -L "$DEB_URL" -o "$TMP_DEB"

# ----------------------------------------------
# 3) Install server (gdebi with fallback)
# ----------------------------------------------
if ! gdebi -n "$TMP_DEB"; then
  echo "[warn] gdebi failed; trying dpkg + apt -f install"
  dpkg -i "$TMP_DEB" || true
  apt-get -f install -y
fi
rm -f "$TMP_DEB"

# ----------------------------------------------
# 4) Optional: allow root login to RStudio Server
#     (set RSTUDIO_ALLOW_ROOT=1 to enable)
# ----------------------------------------------
RSTUDIO_ALLOW_ROOT=1
if [ "${RSTUDIO_ALLOW_ROOT:-}" = "1" ] || [ "${RSTUDIO_ALLOW_ROOT:-}" = "true" ]; then
  install -d -m 0755 /etc/rstudio
  # update/insert auth-minimum-user-id=0
  if [ -f /etc/rstudio/rserver.conf ]; then
    if grep -q '^auth-minimum-user-id=' /etc/rstudio/rserver.conf; then
      sed -i 's/^auth-minimum-user-id=.*/auth-minimum-user-id=0/' /etc/rstudio/rserver.conf
    else
      echo 'auth-minimum-user-id=0' >> /etc/rstudio/rserver.conf
    fi
  else
    echo 'auth-minimum-user-id=0' > /etc/rstudio/rserver.conf
  fi
  echo "[info] RStudio Server: root login enabled (auth-minimum-user-id=0)."
fi

# ----------------------------------------------
# 5) Set passwords (root and saved desktop user)
#     Non-interactive: ROOT_PASSWORD / RSTUDIO_USER_PASSWORD
#     Interactive (if /dev/tty available): prompt
# ----------------------------------------------
have_tty=0
[ -r /dev/tty ] && have_tty=1

set_pw() {
  # $1=user  $2=envvar-name (optional)
  local user="$1" var="${2:-}" pw=""
  id "$user" >/dev/null 2>&1 || { echo "[info] user '$user' not found; skipping password."; return 0; }

  # env var takes precedence
  if [ -n "${var}" ] && [ -n "${!var:-}" ]; then
    pw="${!var}"
  elif [ $have_tty -eq 1 ]; then
    # prompt on /dev/tty (doesn't echo; works even when script is piped)
    printf "Set password for %s (leave blank to skip): " "$user" > /dev/tty
    IFS= read -r -s pw < /dev/tty || true
    printf "\n" > /dev/tty
    if [ -n "$pw" ]; then
      printf "Confirm password for %s: " "$user" > /dev/tty
      IFS= read -r -s pw2 < /dev/tty || true
      printf "\n" > /dev/tty
      [ "$pw" = "${pw2:-}" ] || { echo "[warn] passwords do not match for $user; skipping."; pw=""; }
    fi
  fi

  if [ -n "$pw" ]; then
    echo "$user:$pw" | chpasswd
    echo "[info] password updated for $user."
  else
    echo "[info] password for $user left unchanged."
  fi
}

# root password
set_pw root ROOT_PASSWORD

# password for saved desktop user (if any)
RU="$(cat /etc/ruri/user 2>/dev/null || true)"
if [ -n "$RU" ]; then
  set_pw "$RU" RSTUDIO_USER_PASSWORD
fi

echo "✅ RStudio Server installed."
echo "Start with:  rstudio-server start   (listens on http://127.0.0.1:8787)"
if [ "${RSTUDIO_ALLOW_ROOT:-}" = "1" ] || [ "${RSTUDIO_ALLOW_ROOT:-}" = "true" ]; then
  echo "Root login is ENABLED. Consider disabling later by removing 'auth-minimum-user-id=0' in /etc/rstudio/rserver.conf."
fi
