#!/data/data/com.termux/files/usr/bin/bash
# Termux-Fr4nz: minimal Termux bootstrap
# - Installs OpenSSH + zsh
# - Sets password non-interactively if TERMUX_PASSWORD or --password is provided
# - Starts sshd (port 8022)
# - Makes zsh the default shell via chsh + termux-reload-settings

set -euo pipefail

# -------- args/env --------
TERMUX_PASSWORD="${TERMUX_PASSWORD:-}"
if [[ "${1:-}" == "--password" ]]; then
  TERMUX_PASSWORD="${2:-}"
  shift 2 || true
fi

# Sanity check: are we in Termux?
if [[ -z "${PREFIX-}" || ! -d "$PREFIX" ]]; then
  echo "This script must be run inside Termux." >&2
  exit 1
fi

echo "[1/5] Updating packages…"
pkg update -y >/dev/null
pkg upgrade -y || true

echo "[2/5] Installing OpenSSH + zsh…"
pkg install -y openssh zsh >/dev/null

echo "[3/5] Setting password for $(whoami)…"
if [[ -n "$TERMUX_PASSWORD" ]]; then
  if [[ ${#TERMUX_PASSWORD} -lt 1 ]]; then
    echo "Provided password is empty; refusing." >&2
    exit 1
  fi
  if printf '%s\n%s\n' "$TERMUX_PASSWORD" "$TERMUX_PASSWORD" | passwd >/dev/null; then
    echo " - Password set non-interactively."
  else
    echo " - Non-interactive password set failed; falling back to interactive…"
    passwd
  fi
else
  echo " - No password provided. You’ll be prompted now (interactive)."
  echo "   Tip: run with env var TERMUX_PASSWORD='yourpass' to auto-set."
  passwd
fi

echo "[4/5] Starting sshd on port 8022…"
# Termux's sshd listens on 8022 by default; idempotent start.
sshd || true

echo "[5/5] Making zsh your default shell…"
# Use absolute path; chsh works on Termux >= 0.118
ZSH_PATH="/data/data/com.termux/files/usr/bin/zsh"
if [[ ! -x "$ZSH_PATH" ]]; then
  echo "zsh not found at $ZSH_PATH (unexpected). Aborting." >&2
  exit 1
fi
chsh -s "$ZSH_PATH" || {
  echo "chsh failed; you can manually run: chsh -s $ZSH_PATH" >&2
}
termux-reload-settings || true

cat <<'NOTE'

✅ Done!

Next steps:
- Keep this Termux session open (sshd is running).
- From your Windows/macOS/Linux PC:
    ssh -p 8022 <username>@<phone_ip>

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

You can also run non-interactively:
  TERMUX_PASSWORD='myp@ss' bash setup_termux.sh
  # or:
  bash setup_termux.sh --password 'myp@ss'
NOTE
