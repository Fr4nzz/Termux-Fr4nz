#!/data/data/com.termux/files/usr/bin/bash
# Unattended installer for code-server (official VS Code web IDE)
# in the rooted container (rurima/ruri chroot).
#
# After running this in Termux:
#   vscode-server-chroot-start   # attaches to terminal; Ctrl+C to stop
#   vscode-server-chroot-stop    # graceful stop if needed
#
# Uses the wrappers created by container-scripts/install_vscode_server.sh

set -euo pipefail
: "${PREFIX:=/data/data/com.termux/files/usr}"

# 1) Ensure code-server + wrappers exist inside the rooted Ubuntu chroot
curl -fsSL https://raw.githubusercontent.com/Fr4nzz/Termux-Fr4nz/refs/heads/main/container-scripts/install_vscode_server.sh \
  | ubuntu-chroot /bin/bash -s

# 2) Create Termux wrappers
mkdir -p "$PREFIX/bin"

cat >"$PREFIX/bin/vscode-server-chroot-start" <<'SH'
#!/data/data/com.termux/files/usr/bin/sh
set -e
: "${PREFIX:=/data/data/com.termux/files/usr}"

# Run in FOREGROUND so Ctrl+C stops it. Also prep minimal mounts first.
exec ubuntu-chroot '
set -e
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
export HOME=/root

# Minimal mounts for a healthy chroot runtime
sudo mountpoint -q /proc || sudo mount -t proc proc /proc
sudo mountpoint -q /sys  || sudo mount -t sysfs sys /sys
sudo mkdir -p /dev/pts /dev/shm /run /tmp/.ICE-unix
sudo mountpoint -q /dev/pts || sudo mount -t devpts devpts /dev/pts
sudo mountpoint -q /dev/shm || sudo mount -t tmpfs -o rw,nosuid,nodev,mode=1777,size=256M tmpfs /dev/shm
sudo chmod 1777 /tmp/.ICE-unix

# Ensure HOME directory exists
[ -d "$HOME" ] || mkdir -p "$HOME"
[ -d "$HOME/.config" ] || mkdir -p "$HOME/.config"

echo "========================================="
echo "VS Code Server (code-server) starting..."
echo "HTTPS: https://127.0.0.1:13338"
echo "LAN:   https://$(hostname -I | cut -d" " -f1):13338"
echo "Press Ctrl+C to stop"
echo "========================================="

# IMPORTANT: exec keeps this attached to your Termux terminal
exec code-server-local 13338
'
SH
chmod 0755 "$PREFIX/bin/vscode-server-chroot-start"

cat >"$PREFIX/bin/vscode-server-chroot-stop" <<'SH'
#!/data/data/com.termux/files/usr/bin/sh
set -e
# Gracefully stop via the in-container wrapper
ubuntu-chroot 'code-server-stop' || true
echo "VS Code Server stopped."
SH
chmod 0755 "$PREFIX/bin/vscode-server-chroot-stop"

echo "✅ VS Code Server (code-server) entrypoints installed."
echo "Start (FG): vscode-server-chroot-start   # Ctrl+C to stop"
echo "Stop:       vscode-server-chroot-stop"
echo ""
echo "Note: Browser will warn about self-signed certificate."
echo "      Click 'Advanced' > 'Proceed to site' to continue."