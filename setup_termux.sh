#!/data/data/com.termux/files/usr/bin/bash
# Termux-Fr4nz: minimal Termux bootstrap
# - Installs OpenSSH + zsh
# - Starts sshd (port 8022)
# - Installs basic zsh plugins + writes a minimal zshrc
# - Makes zsh the default shell via chsh + termux-reload-settings

set -euo pipefail

# Sanity check: are we in Termux?
if [[ -z "${PREFIX-}" || ! -d "$PREFIX" ]]; then
  echo "This script must be run inside Termux." >&2
  exit 1
fi

echo "[1/5] Updating packages…"
pkg update -y >/dev/null
pkg upgrade -y || true

echo "[2/5] Installing OpenSSH + zsh…"
pkg install -y openssh zsh git >/dev/null

echo "[3/5] Starting sshd on port 8022…"
# Termux's sshd listens on 8022 by default; idempotent start.
sshd || true

echo "[4/5] Install zsh plugins (no checks/backups) and write ~/.zshrc…"
PLUGDIR="$HOME/.local/share/zsh/plugins"
rm -rf "$PLUGDIR"
mkdir -p "$PLUGDIR"
git clone --depth=1 https://github.com/zsh-users/zsh-autosuggestions "$PLUGDIR/zsh-autosuggestions" >/dev/null
git clone --depth=1 https://github.com/zsh-users/zsh-syntax-highlighting "$PLUGDIR/zsh-syntax-highlighting" >/dev/null

cat > "$HOME/.zshrc" <<'ZRC'
plugdir="$HOME/.local/share/zsh/plugins"
source "$plugdir/zsh-autosuggestions/zsh-autosuggestions.zsh"
source "$plugdir/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"
ZRC

echo "[5/5] Making zsh your default shell…"
chsh -s zsh
termux-reload-settings || true

cat <<'NOTE'

✅ Done!

Next steps:
- Keep this Termux session open (sshd is running).
- From your Windows/macOS/Linux PC:
    ssh -p 8022 <username>@<phone_ip>
- Set a password for SSH logins by running: passwd

Where:
- <username>  = output of 'whoami' in Termux (e.g. u0_a123)
- <phone_ip>  = your phone’s Wi-Fi IP (e.g. 192.168.1.23)

Handy:
- whoami
- ifconfig wlan0 | sed -n 's/.*inet \(addr:\)\?\([0-9.]*\).*/\2/p' | head -n1
- termux-wifi-connectioninfo | jq -r '.ip'   # requires termux-api + jq

TIP: If you connect via USB with ADB:
  adb forward tcp:8022 tcp:8022
  ssh -p 8022 <username>@127.0.0.1

NOTE
zsh