#!/usr/bin/env bash
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive

# 1. ensure R exists first (RStudio Desktop expects R on PATH)
if ! command -v R >/dev/null 2>&1; then
  curl -fsSL https://raw.githubusercontent.com/Fr4nzz/Termux-Fr4nz/refs/heads/main/container-scripts/install_r_binaries.sh | bash
fi

# 2. pull in Electron/Chromium-style runtime libs that the arm64 build of RStudio uses
#    plus dbus so we can spawn a minimal system bus in the wrapper
sudo apt-get update
sudo apt-get install -y \
    wget gdebi-core \
    dbus dbus-x11 \
    libnspr4 libnss3 libxss1 libgbm1 libasound2 || true

# 3. download & install the arm64 .deb
DEB_URL="https://s3.amazonaws.com/rstudio-ide-build/electron/jammy/arm64/rstudio-2025.11.0-daily-271-arm64.deb"
wget -O /tmp/rstudio-arm64.deb "$DEB_URL"
sudo gdebi -n /tmp/rstudio-arm64.deb || sudo apt-get -f install -y

# 4. install a wrapper that:
#    - sets safe env for Termux:X11
#    - creates ~/.rstudio-root for Chromium profile
#    - forces software rendering / no sandbox
#    - starts a lightweight system D-Bus if needed
sudo install -d -m 0755 /usr/local/bin
sudo tee /usr/local/bin/rstudio-proot >/dev/null <<'SH'
#!/bin/sh
set -e

# 1. Require DISPLAY so we don't try to launch headless
if [ -z "${DISPLAY:-}" ]; then
  echo "DISPLAY is not set. Start Termux:X11 (x11-up) and your desktop (xfce4-chroot-start / xfce4-proot-start), or set DISPLAY=:1."
  exit 1
fi

# 2. Environment tweaks so Electron is happier in a Termux/Android container
export ELECTRON_OZONE_PLATFORM_HINT=x11
export GDK_BACKEND=x11
export QT_QPA_PLATFORM=xcb
export QT_XCB_NO_MITSHM=1
export QT_QPA_PLATFORMTHEME=gtk3
export LIBGL_ALWAYS_SOFTWARE=1
export NO_AT_BRIDGE=1
export GTK_USE_PORTAL=0

# 3. Per-user runtime dir rather than /run/user/... or /dev/shm
[ -d "$HOME/.run" ] || mkdir -p "$HOME/.run"
chmod 700 "$HOME/.run" 2>/dev/null || true
export XDG_RUNTIME_DIR="$HOME/.run"

# 4. Make sure a "system" D-Bus exists so Electron doesn't crash
if [ ! -S /run/dbus/system_bus_socket ]; then
  mkdir -p /run/dbus
  dbus-daemon --system --fork >/dev/null 2>&1 || true
fi

# 5. RStudio profile dir (Chromium hates root using /root without --user-data-dir)
RSTUDIO_USER_DIR="$HOME/.rstudio-root"
[ -d "$RSTUDIO_USER_DIR" ] || mkdir -p "$RSTUDIO_USER_DIR"
chmod 700 "$RSTUDIO_USER_DIR" 2>/dev/null || true

# 6. Actual RStudio binary from the .deb
RSTUDIO_BIN="/usr/lib/rstudio/rstudio"
if [ ! -x "$RSTUDIO_BIN" ]; then
  echo "Could not find $RSTUDIO_BIN. Edit rstudio-proot if RStudio is somewhere else."
  exit 1
fi

# 7. Launch with Chromium flags known to behave in this environment
exec "$RSTUDIO_BIN" \
  --no-sandbox \
  --user-data-dir="$RSTUDIO_USER_DIR" \
  --disable-gpu \
  --disable-dev-shm-usage \
  "$@"
SH
sudo chmod 0755 /usr/local/bin/rstudio-proot

# 5. Drop a desktop file that runs the wrapper instead of raw /usr/lib/rstudio/rstudio
sudo install -d -m 0755 /usr/share/applications
sudo tee /usr/share/applications/rstudio-proot.desktop >/dev/null <<'SH'
[Desktop Entry]
Name=RStudio (proot)
Comment=RStudio Desktop with Termux/chroot-safe flags
Exec=/usr/local/bin/rstudio-proot %U
Icon=rstudio
Type=Application
Categories=Development;Science;IDE;
Terminal=false
StartupNotify=true
SH

# 6. ensure desktopify is around, then put the icon on Desktop
command -v desktopify >/dev/null 2>&1 || bash -lc 'curl -fsSL https://raw.githubusercontent.com/Fr4nzz/Termux-Fr4nz/refs/heads/main/container-scripts/install_desktopify.sh | bash'
desktopify rstudio-proot || true

echo "✅ RStudio Desktop installed."
echo "Launch it with: rstudio-proot"
