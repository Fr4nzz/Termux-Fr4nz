#!/data/data/com.termux/files/usr/bin/bash
# Termux-Fr4nz: SSH bootstrap
# - Installs OpenSSH
# - Starts sshd (port 8022)

set -euo pipefail

echo "[1/3] Updating packages…"
pkg update -y >/dev/null
pkg upgrade -y || true

echo "[2/3] Installing OpenSSH…"
pkg install -y openssh >/dev/null

echo "[3/3] Starting sshd on port 8022…"
# Termux's sshd listens on 8022 by default; idempotent start.
sshd || true

ME="$(whoami)"

cat <<NOTE

✅ SSH is ready!

Connect from Windows/macOS/Linux:
  ssh -p 8022 ${ME}@127.0.0.1

Run 'passwd' now to set your SSH password.

NOTE
