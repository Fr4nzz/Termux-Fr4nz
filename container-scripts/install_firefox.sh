#!/usr/bin/env bash
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive

sudo apt-get update
sudo apt-get install -y curl gnupg ca-certificates

sudo install -d -m0755 /etc/apt/keyrings
curl -fsSL https://packages.mozilla.org/apt/repo-signing-key.gpg \
  | sudo gpg --dearmor -o /etc/apt/keyrings/mozilla.gpg

# Prefer Mozilla's own repo so Firefox stays current
sudo tee /etc/apt/preferences.d/mozilla >/dev/null <<'EOF'
Package: *
Pin: origin packages.mozilla.org
Pin-Priority: 1000
EOF

echo "deb [signed-by=/etc/apt/keyrings/mozilla.gpg] https://packages.mozilla.org/apt mozilla main" \
  | sudo tee /etc/apt/sources.list.d/mozilla.list >/dev/null

sudo apt-get update
sudo apt-get install -y firefox

# proot-friendly wrapper: scope sandbox relaxations to Firefox only
sudo tee /usr/local/bin/firefox-proot >/dev/null <<'SH'
#!/bin/sh
export MOZ_ENABLE_WAYLAND=0
export MOZ_WEBRENDER=0
export MOZ_DISABLE_CONTENT_SANDBOX=1
exec firefox "$@"
SH
sudo chmod +x /usr/local/bin/firefox-proot

# Desktop entry for wrapper
sudo tee /usr/share/applications/firefox-proot.desktop >/dev/null <<'SH'
[Desktop Entry]
Name=Firefox (proot)
Comment=Firefox with proot-safe sandbox settings
Exec=/usr/local/bin/firefox-proot %U
Icon=firefox
Type=Application
Categories=Network;WebBrowser;
Terminal=false
StartupNotify=true
SH

# add desktop icon if helper exists, install it otherwise
command -v desktopify >/dev/null 2>&1 || bash -lc 'curl -fsSL https://raw.githubusercontent.com/Fr4nzz/Termux-Fr4nz/refs/heads/main/container-scripts/install_desktopify.sh | bash'
desktopify firefox-proot || true

echo "Firefox installed."
