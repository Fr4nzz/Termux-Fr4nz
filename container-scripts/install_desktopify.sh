#!/usr/bin/env bash
set -euo pipefail

sudo apt-get install -y libsecret-1-0 xdg-utils

sudo tee /usr/local/bin/desktopify >/dev/null <<'SH'
#!/bin/sh
set -eu
RU="$(cat /etc/ruri/user 2>/dev/null || echo ubuntu)"
desk="/home/$RU/Desktop"
[ -d "$desk" ] || mkdir -p "$desk"
for name in "$@"; do
  src="/usr/share/applications/$name.desktop"
  [ -f "$src" ] || { echo "No $src"; continue; }
  cp -f "$src" "$desk/$name.desktop"
  chmod +x "$desk/$name.desktop"
  chown "$RU:$RU" "$desk/$name.desktop"
done
sudo update-desktop-database /usr/share/applications 2>/dev/null || true
sudo gtk-update-icon-cache -f /usr/share/icons/hicolor 2>/dev/null || true
SH
sudo chmod 0755 /usr/local/bin/desktopify

echo "desktopify installed."
