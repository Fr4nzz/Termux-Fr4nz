#!/usr/bin/env bash
# Install VSCodium (the telemetry-free VS Code build) in the Ubuntu container
# and create a proot/chroot-safe launcher ("codium-proot") that:
#   - forces software rendering
#   - disables the Chromium sandbox complaints under proot/chroot
#   - stores user data in ~/.vscodium-root if you're effectively root
#
# Also creates a .desktop entry and drops a Desktop icon via `desktopify`
# (same pattern as install_vscode.sh).
#
# Works for both rooted (rurima/ruri) and rootless (daijin/proot) containers.

set -euo pipefail
export DEBIAN_FRONTEND=noninteractive

# --- 0) Make sure previous half-configured apt stuff is healed
sudo dpkg --configure -a || true
sudo apt-get -f install -y || true

# --- 1) Base deps for repo setup
sudo apt-get update
sudo apt-get install -y curl gnupg ca-certificates

# --- 2) Add VSCodium apt repo
# Key + repo live at download.vscodium.com. We put the key in /etc/apt/keyrings
sudo install -d -m 0755 /etc/apt/keyrings
curl -fsSL https://gitlab.com/paulcarroty/vscodium-deb-rpm-repo/-/raw/master/pub.gpg \
  | sudo gpg --dearmor -o /etc/apt/keyrings/vscodium.gpg

echo "deb [signed-by=/etc/apt/keyrings/vscodium.gpg] https://download.vscodium.com/debs vscodium main" \
  | sudo tee /etc/apt/sources.list.d/vscodium.list >/dev/null

# --- 3) Install codium itself
sudo apt-get update
sudo apt-get install -y codium

# --- 4) Create a Termux/X11 friendly launcher:
# codium (Electron/Chromium) doesn't like running as root in a chroot/proot,
# and also expects /dev/shm, GPU, sandbox, etc. We'll mirror code-proot style.
sudo install -d -m 0755 /usr/local/bin
sudo tee /usr/local/bin/codium-proot >/dev/null <<'SH'
#!/bin/sh
set -e

# Helpful guard when launched outside X11:
if [ -z "${DISPLAY:-}" ]; then
  echo "DISPLAY is not set. Start Termux:X11 (x11-up) and your desktop (xfce4-proot-start / xfce4-chroot-start), or set DISPLAY=:1."
  exit 1
fi

# Make Electron/Chromium happy in proot/chroot:
export ELECTRON_OZONE_PLATFORM_HINT=x11
export GDK_BACKEND=x11
export QT_QPA_PLATFORM=xcb
export QT_XCB_NO_MITSHM=1
export QT_QPA_PLATFORMTHEME=gtk3
export LIBGL_ALWAYS_SOFTWARE=1

# Avoid /dev/shm issues in proot/chroot:
[ -d "$HOME/.run" ] || mkdir -p "$HOME/.run"
chmod 700 "$HOME/.run" 2>/dev/null || true
export XDG_RUNTIME_DIR="$HOME/.run"

# Dedicated profile dir so "running as root" doesn't explode:
CODIUM_USER_DIR="$HOME/.vscodium-root"
[ -d "$CODIUM_USER_DIR" ] || mkdir -p "$CODIUM_USER_DIR"
chmod 700 "$CODIUM_USER_DIR" 2>/dev/null || true

exec /usr/bin/codium \
  --no-sandbox \
  --disable-setuid-sandbox \
  --disable-dev-shm-usage \
  --disable-gpu \
  --password-store=basic \
  --user-data-dir="$CODIUM_USER_DIR" \
  "$@"
SH
sudo chmod 0755 /usr/local/bin/codium-proot

# --- 5) Desktop entry that points to codium-proot instead of raw /usr/bin/codium
sudo install -d -m 0755 /usr/share/applications
sudo tee /usr/share/applications/codium-proot.desktop >/dev/null <<'SH'
[Desktop Entry]
Name=VSCodium (proot)
Comment=Telemetry-free VS Code build with Termux/chroot-safe flags
Exec=/usr/local/bin/codium-proot %U
Icon=codium
Type=Application
Categories=Development;IDE;
Terminal=false
StartupNotify=true
SH

# --- 6) Drop a desktop icon via desktopify (same flow as install_vscode.sh)
if ! command -v desktopify >/dev/null 2>&1; then
  echo "[*] Installing desktopify helper…"
  curl -fsSL https://raw.githubusercontent.com/Fr4nzz/Termux-Fr4nz/refs/heads/main/container-scripts/install_desktopify.sh | bash
fi
desktopify codium-proot || true

echo
echo "✅ VSCodium installed."
echo "Run it in XFCE with: codium-proot"
