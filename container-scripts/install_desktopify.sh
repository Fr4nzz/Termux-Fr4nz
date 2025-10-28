#!/usr/bin/env bash
set -euo pipefail

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
SH
sudo chmod 0755 /usr/local/bin/desktopify

echo "desktopify installed."
