#!/usr/bin/env bash
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive

# --- 0) Make sure already-unpacked deps are configured (if prior apt run failed mid-way)
sudo dpkg --configure -a || true
sudo apt-get -f install -y || true

# --- 1) Figure out the right VS Code tarball (default: linux-arm64)
arch="${1:-}"
if [ -z "$arch" ]; then
  case "$(dpkg --print-architecture 2>/dev/null || echo "$(uname -m)")" in
    arm64|aarch64) arch="linux-arm64" ;;
    amd64|x86_64)  arch="linux-x64"   ;;  # just in case someone reuses this on x64
    *)             arch="linux-arm64" ;;
  esac
fi

VSCODE_TARBALL_URL="https://code.visualstudio.com/sha/download?build=stable&os=${arch}"

# --- 2) Download & install to /opt/vscode
tmp_tgz="$(mktemp --suffix=.tar.gz)"
echo "[*] Downloading VS Code (${arch})…"
curl -L "$VSCODE_TARBALL_URL" -o "$tmp_tgz"

echo "[*] Installing to /opt/vscode…"
sudo rm -rf /opt/vscode
sudo install -d -m 0755 /opt/vscode
sudo tar -xzf "$tmp_tgz" -C /opt/vscode --strip-components=1
rm -f "$tmp_tgz"

# --- 3) Proot-/chroot-friendly launcher (root-safe, Termux:X11-safe)
sudo install -d -m 0755 /usr/local/bin
sudo tee /usr/local/bin/code-proot >/dev/null <<'SH'
#!/bin/sh
set -e

# Helpful guard when launched outside X11
if [ -z "${DISPLAY:-}" ]; then
  echo "DISPLAY is not set. Start Termux:X11 (x11-up) and your desktop (xfce4-proot-start / xfce4-chroot-start), or set DISPLAY=:1."
  exit 1
fi

# Electron/X11 + proot-/chroot-friendly env
export ELECTRON_OZONE_PLATFORM_HINT=x11
export QT_QPA_PLATFORM=xcb
export LIBGL_ALWAYS_SOFTWARE=1

# Per-user runtime dir (avoid /dev/shm under proot/chroot)
[ -d "$HOME/.run" ] || mkdir -p "$HOME/.run"
chmod 700 "$HOME/.run" 2>/dev/null || true
export XDG_RUNTIME_DIR="$HOME/.run"

# Dedicated Code profile directory so root won't complain.
# VS Code yells if you run as uid 0 without --user-data-dir.
CODE_USER_DIR="$HOME/.vscode-root"
[ -d "$CODE_USER_DIR" ] || mkdir -p "$CODE_USER_DIR"
chmod 700 "$CODE_USER_DIR" 2>/dev/null || true

exec /opt/vscode/bin/code \
  --no-sandbox \
  --disable-setuid-sandbox \
  --disable-dev-shm-usage \
  --password-store=basic \
  --user-data-dir="$CODE_USER_DIR" \
  "$@"
SH
sudo chmod +x /usr/local/bin/code-proot

# --- 4) Desktop entry
sudo install -d -m 0755 /usr/share/applications
sudo tee /usr/share/applications/code-proot.desktop >/dev/null <<'SH'
[Desktop Entry]
Name=Visual Studio Code (proot)
Comment=VS Code (tarball) with proot/chroot-safe flags
Exec=/usr/local/bin/code-proot %U
Icon=/opt/vscode/resources/app/resources/linux/code.png
Type=Application
Categories=Development;IDE;
Terminal=false
StartupNotify=true
SH

# --- 5) Ensure desktopify exists, then drop a desktop shortcut
if ! command -v desktopify >/dev/null 2>&1; then
  echo "[*] Installing desktopify helper…"
  curl -fsSL https://raw.githubusercontent.com/Fr4nzz/Termux-Fr4nz/refs/heads/main/container-scripts/install_desktopify.sh | bash
fi
desktopify code-proot || true

echo
echo "✅ VS Code installed."
echo "Run it with: code-proot"
