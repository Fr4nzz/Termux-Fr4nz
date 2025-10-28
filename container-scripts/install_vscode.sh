#!/usr/bin/env bash
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive

sudo apt-get update
sudo apt-get install -y curl gnupg ca-certificates
sudo install -d -m0755 /etc/apt/keyrings

curl -fsSL https://packages.microsoft.com/keys/microsoft.asc \
  | sudo gpg --dearmor -o /etc/apt/keyrings/packages.microsoft.gpg

ARCH="$(dpkg --print-architecture)"
echo "deb [arch=${ARCH} signed-by=/etc/apt/keyrings/packages.microsoft.gpg] https://packages.microsoft.com/repos/code stable main" \
  | sudo tee /etc/apt/sources.list.d/vscode.list >/dev/null

sudo apt-get update
sudo apt-get install -y code

# proot-friendly launcher (no setuid sandbox)
sudo tee /usr/local/bin/code-proot >/dev/null <<'SH'
#!/bin/sh
export ELECTRON_OZONE_PLATFORM_HINT=x11
export QT_QPA_PLATFORM=xcb
export LIBGL_ALWAYS_SOFTWARE=1
exec /usr/share/code/code --no-sandbox --password-store=basic "$@"
SH
sudo chmod +x /usr/local/bin/code-proot

# Desktop entry for the wrapper
sudo tee /usr/share/applications/code-proot.desktop >/dev/null <<'SH'
[Desktop Entry]
Name=Visual Studio Code (proot)
Comment=VS Code with proot-safe flags
Exec=/usr/local/bin/code-proot %U
Icon=code
Type=Application
Categories=Development;IDE;
Terminal=false
StartupNotify=true
SH

command -v desktopify >/dev/null 2>&1 || bash -lc 'curl -fsSL https://raw.githubusercontent.com/Fr4nzz/Termux-Fr4nz/refs/heads/main/container-scripts/install_desktopify.sh | bash'
desktopify code-proot || true

echo "VS Code installed."
