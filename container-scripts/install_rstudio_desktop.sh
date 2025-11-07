#!/usr/bin/env bash
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive

# ========== 0) Ensure R exists first ==========
if ! command -v R >/dev/null 2>&1; then
  curl -fsSL https://raw.githubusercontent.com/Fr4nzz/Termux-Fr4nz/refs/heads/main/container-scripts/install_r_binaries.sh | bash
fi

# ========== 1) Deps for RStudio Desktop (Electron) ==========
sudo apt-get update -y
# Pick the right ALSA pkg on this Ubuntu (noble → libasound2t64, jammy → libasound2)
ALSA_PKG="libasound2"
if apt-cache show libasound2t64 >/dev/null 2>&1; then
  ALSA_PKG="libasound2t64"
fi
sudo apt-get install -y \
  curl wget ca-certificates gdebi-core \
  dbus dbus-x11 \
  libnspr4 libnss3 libxss1 libgbm1 "$ALSA_PKG" \
  fonts-dejavu-core x11-utils

# ========== 2) Figure out arch + channel and build a "latest" URL ==========
arch="$(dpkg --print-architecture 2>/dev/null || uname -m)"
case "$arch" in
  arm64|aarch64) PLATFORM="arm64" ;;
  amd64|x86_64)  PLATFORM="amd64" ;;
  *) echo "Unsupported architecture: $arch"; exit 1 ;;
esac

# Channel: daily|stable.  Default to daily, and FORCE daily on arm64 (stable arm64 Desktop isn't published).
CHANNEL="${RSTUDIO_CHANNEL:-daily}"
if [ "$PLATFORM" = "arm64" ] && [ "$CHANNEL" = "stable" ]; then
  echo "[info] Stable arm64 Desktop not listed by Posit's redirect links; falling back to daily." 1>&2
  CHANNEL="daily"
fi

# NB: Posit uses the 'jammy' path for both Ubuntu 22 and 24 in redirect links.
# These redirect with HTTP 302 to the current build on S3.
BASE="https://rstudio.org/download/latest/${CHANNEL}/desktop/jammy"
DEB_URL="${BASE}/rstudio-latest-${PLATFORM}.deb"

tmpdeb="$(mktemp /tmp/rstudio-XXXXXX.deb)"
echo "[*] Downloading latest RStudio Desktop (${CHANNEL}, ${PLATFORM}) via redirect: ${DEB_URL}"
curl -fL "$DEB_URL" -o "$tmpdeb"

# Optional: show what we got
echo "[*] Saved to $tmpdeb ($(du -h "$tmpdeb" | awk '{print $1}'))"

# ========== 3) Install the .deb (resolve deps if needed) ==========
if ! sudo gdebi -n "$tmpdeb"; then
  echo "[warn] gdebi failed; trying dpkg + apt -f install"
  sudo dpkg -i "$tmpdeb" || true
  sudo apt-get -f install -y
fi
rm -f "$tmpdeb"

# ========== 4) Install the cross-env wrapper: rstudio-desktop ==========
sudo install -d -m 0755 /usr/local/bin
sudo tee /usr/local/bin/rstudio-desktop >/dev/null <<'SH'
#!/bin/sh
set -e

# Require DISPLAY (user should have started Termux:X11 + desktop)
if [ -z "${DISPLAY:-}" ]; then
  echo "DISPLAY is not set. Start Termux:X11 (x11-up) and your desktop (xfce4-*-start), or set DISPLAY=:1."
  exit 1
fi

# Electron/X11 in Android containers
export ELECTRON_OZONE_PLATFORM_HINT=x11
export GDK_BACKEND=x11
export QT_QPA_PLATFORM=xcb
export QT_XCB_NO_MITSHM=1
export QT_QPA_PLATFORMTHEME=gtk3
export LIBGL_ALWAYS_SOFTWARE=1
export NO_AT_BRIDGE=1
export GTK_USE_PORTAL=0

# Per-user runtime dir instead of /run/user or /dev/shm
[ -d "$HOME/.run" ] || mkdir -p "$HOME/.run"
chmod 700 "$HOME/.run" 2>/dev/null || true
export XDG_RUNTIME_DIR="$HOME/.run"

# Minimal "system" bus if none (helps Electron apps)
if [ ! -S /run/dbus/system_bus_socket ]; then
  mkdir -p /run/dbus
  dbus-daemon --system --fork >/dev/null 2>&1 || true
fi

# Real binary from the .deb
BIN="/usr/lib/rstudio/rstudio"
[ -x "$BIN" ] || { echo "Could not find $BIN"; exit 1; }

# Chromium flags suitable for Termux/Android containers
exec "$BIN" \
  --no-sandbox \
  --user-data-dir="$HOME/.rstudio-root" \
  --disable-gpu \
  --disable-dev-shm-usage \
  "$@"
SH
sudo chmod 0755 /usr/local/bin/rstudio-desktop

# ========== 5) Desktop entry and launcher on Desktop ==========
sudo install -d -m 0755 /usr/share/applications
sudo tee /usr/share/applications/rstudio-desktop.desktop >/dev/null <<'SH'
[Desktop Entry]
Name=RStudio Desktop
Comment=RStudio Desktop with Termux/chroot-safe flags
Exec=/usr/local/bin/rstudio-desktop %U
Icon=rstudio
Type=Application
Categories=Development;Science;IDE;
Terminal=false
StartupNotify=true
SH

# Put a launcher on the user's Desktop (your repo provides desktopify)
command -v desktopify >/dev/null 2>&1 || bash -lc 'curl -fsSL https://raw.githubusercontent.com/Fr4nzz/Termux-Fr4nz/refs/heads/main/container-scripts/install_desktopify.sh | bash'
desktopify rstudio-desktop || true

echo "✅ RStudio Desktop installed."
echo "Run it with: rstudio-desktop"
