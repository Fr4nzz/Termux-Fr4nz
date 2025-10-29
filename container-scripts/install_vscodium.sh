#!/usr/bin/env bash
# Install VSCodium and set it up for Termux/Ubuntu containers,
# force Open VSX marketplace, and add CLI helpers to install extensions.
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive

# --- 0) Heal half-configured apt, then base deps (adds jq for JSON patch) ---
sudo dpkg --configure -a || true
sudo apt-get -f install -y || true
sudo apt-get update
sudo apt-get install -y curl gnupg ca-certificates jq

# --- 1) Decide the right tarball arch (default: linux-arm64) ---
arch="${1:-}"
if [ -z "$arch" ]; then
  case "$(dpkg --print-architecture 2>/dev/null || echo "$(uname -m)")" in
    arm64|aarch64) arch="linux-arm64" ;;
    amd64|x86_64)  arch="linux-x64"   ;;
    *)             arch="linux-arm64" ;;
  case esac
fi

VSCODE_TARBALL_URL="https://code.visualstudio.com/sha/download?build=stable&os=${arch}"

# --- 2) Download & install to /opt/vscodium (tarball) ---
tmp_tgz="$(mktemp --suffix=.tar.gz)"
echo "[*] Downloading VSCodium (${arch})…"
curl -L "$VSCODE_TARBALL_URL" -o "$tmp_tgz"

echo "[*] Installing to /opt/vscodium…"
sudo rm -rf /opt/vscodium
sudo install -d -m 0755 /opt/vscodium
sudo tar -xzf "$tmp_tgz" -C /opt/vscodium --strip-components=1
rm -f "$tmp_tgz"

# --- 3) Proot-/chroot-friendly launcher (root-safe, Termux:X11-safe) ---
sudo install -d -m 0755 /usr/local/bin
sudo tee /usr/local/bin/codium-proot >/dev/null <<'SH'
#!/bin/sh
set -e

# Guard when launched outside X11
if [ -z "${DISPLAY:-}" ]; then
  echo "DISPLAY is not set. Start Termux:X11 (x11-up) and desktop (xfce4-*-start), or set DISPLAY=:1."
  exit 1
fi

# Electron/X11 + proot-/chroot-friendly env
export ELECTRON_OZONE_PLATFORM_HINT=x11
export GDK_BACKEND=x11
export QT_QPA_PLATFORM=xcb
export QT_XCB_NO_MITSHM=1
export QT_QPA_PLATFORMTHEME=gtk3
export LIBGL_ALWAYS_SOFTWARE=1

# Per-user runtime dir (avoid /dev/shm in proot/chroot)
[ -d "$HOME/.run" ] || mkdir -p "$HOME/.run"
chmod 700 "$HOME/.run" 2>/dev/null || true
export XDG_RUNTIME_DIR="$HOME/.run"

# Dedicated profile + extensions dir (works even if you're effectively root)
CODE_USER_DIR="$HOME/.vscodium-root"
EXT_DIR="$HOME/.vscodium-extensions"
mkdir -p "$CODE_USER_DIR" "$EXT_DIR"
chmod 700 "$CODE_USER_DIR" "$EXT_DIR" 2>/dev/null || true

exec /opt/vscodium/bin/codium \
  --no-sandbox \
  --disable-setuid-sandbox \
  --disable-dev-shm-usage \
  --disable-gpu \
  --password-store=basic \
  --user-data-dir="$CODE_USER_DIR" \
  --extensions-dir="$EXT_DIR" \
  "$@"
SH
sudo chmod 0755 /usr/local/bin/codium-proot

# --- 4) Desktop entry pointing to the wrapper ---
sudo install -d -m 0755 /usr/share/applications
sudo tee /usr/share/applications/codium-proot.desktop >/dev/null <<'SH'
[Desktop Entry]
Name=VSCodium (proot)
Comment=Telemetry-free VS Code build with Termux/chroot-safe flags
Exec=/usr/local/bin/codium-proot %U
Icon=/opt/vscodium/resources/app/resources/linux/code.png
Type=Application
Categories=Development;IDE;
Terminal=false
StartupNotify=true
SH

# --- 5) Force Open VSX marketplace in product.json ---
# Try common product.json locations used by tarballs and distro packages.
# (We installed to /opt/vscodium via tarball, but keep others for safety.)
PRODUCT_CANDIDATES="
/opt/vscodium/resources/app/product.json
/usr/share/codium/resources/app/product.json
/usr/lib/codium/resources/app/product.json
"

patch_product_json() {
  local f="$1"
  [ -f "$f" ] || return 1
  echo "[*] Patching Open VSX marketplace in: $f"
  sudo cp "$f" "$f.bak.$(date +%s)" || true
  sudo jq '
    .extensionsGallery = {
      serviceUrl: "https://open-vsx.org/vscode/gallery",
      itemUrl:    "https://open-vsx.org/vscode/item"
    }
    | .linkProtectionTrustedDomains =
        ((.linkProtectionTrustedDomains // []) + ["https://open-vsx.org"] | unique)
  ' "$f" | sudo tee "$f.tmp" >/dev/null
  sudo mv "$f.tmp" "$f"
}

for p in $PRODUCT_CANDIDATES; do
  patch_product_json "$p" 2>/dev/null || true
done

# --- 6) Helper to install extensions from CLI (Open VSX IDs) ---
sudo tee /usr/local/bin/codium-install-extensions >/dev/null <<'SH'
#!/bin/sh
set -e
# Usage:
#   codium-install-extensions ms-python.python esbenp.prettier-vscode
# or:
#   CODIUM_EXTENSIONS="ms-python.python esbenp.prettier-vscode" codium-install-extensions
# or:
#   echo -e "ms-python.python\nesbenp.prettier-vscode" > ~/.vscodium-extensions.txt
#   codium-install-extensions
LIST="$@"
[ -z "$LIST" ] && [ -n "${CODIUM_EXTENSIONS:-}" ] && LIST="$CODIUM_EXTENSIONS"
if [ -z "$LIST" ] && [ -f "$HOME/.vscodium-extensions.txt" ]; then
  LIST="$(grep -vE '^\s*(#|$)' "$HOME/.vscodium-extensions.txt" || true)"
fi
if [ -z "$LIST" ]; then
  echo "No extensions specified. Pass IDs as args, set CODIUM_EXTENSIONS, or create ~/.vscodium-extensions.txt"
  exit 0
fi
# Ensure consistent dirs (match codium-proot defaults)
EXT_DIR="$HOME/.vscodium-extensions"
mkdir -p "$EXT_DIR"
for ext in $LIST; do
  echo "Installing/updating: $ext"
  /opt/vscodium/bin/codium --install-extension "$ext" --force --extensions-dir "$EXT_DIR" >/dev/null
done
echo "Done."
SH
sudo chmod 0755 /usr/local/bin/codium-install-extensions

# --- 7) desktop icon to Desktop (if helper exists) ---
if ! command -v desktopify >/dev/null 2>&1; then
  echo "[*] Installing desktopify helper…"
  curl -fsSL https://raw.githubusercontent.com/Fr4nzz/Termux-Fr4nz/refs/heads/main/container-scripts/install_desktopify.sh | bash
fi
desktopify codium-proot || true

echo
echo "✅ VSCodium installed (Open VSX enabled)."
echo "Run GUI: codium-proot"
echo "Install extensions now (Open VSX IDs), e.g.:"
echo "  codium-install-extensions ms-python.python ms-toolsai.jupyter esbenp.prettier-vscode"
# optional one-shot via env at install time:
if [ -n "${CODIUM_EXTENSIONS:-}" ]; then
  echo "[*] Installing CODIUM_EXTENSIONS from env…"
  codium-install-extensions >/dev/null || true
fi
