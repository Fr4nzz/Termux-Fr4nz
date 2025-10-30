#!/data/data/com.termux/files/usr/bin/bash
# Unattended installer for a code-server (VSCodium-like web IDE) entrypoint
# in the rooted container (rurima/ruri chroot).
#
# After running this in Termux:
#   vscodium-server-chroot-start   # attaches to terminal; Ctrl+C to stop
#   vscodium-server-chroot-stop    # graceful stop if needed
#
# Uses the wrappers created by container-scripts/install_vscode_server.sh

set -euo pipefail
: "${PREFIX:=/data/data/com.termux/files/usr}"

# 1) Ensure code-server + wrappers exist inside the rooted Ubuntu chroot
curl -fsSL https://raw.githubusercontent.com/Fr4nzz/Termux-Fr4nz/refs/heads/main/container-scripts/install_vscode_server.sh \
  | ubuntu-chroot /bin/bash -s

# 2) Create Termux wrappers
mkdir -p "$PREFIX/bin"

cat >"$PREFIX/bin/vscodium-server-chroot-start" <<'SH'
#!/data/data/com.termux/files/usr/bin/sh
set -e
: "${PREFIX:=/data/data/com.termux/files/usr}"

# Run in FOREGROUND so Ctrl+C stops it. Also prep minimal mounts first.
exec ubuntu-chroot /bin/bash -lc '
set -e
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

# Minimal mounts for a healthy chroot runtime
sudo mountpoint -q /proc || sudo mount -t proc proc /proc
sudo mountpoint -q /sys  || sudo mount -t sysfs sys /sys
sudo mkdir -p /dev/pts /dev/shm /run /tmp/.ICE-unix
sudo mountpoint -q /dev/pts || sudo mount -t devpts devpts /dev/pts
sudo mountpoint -q /dev/shm || sudo mount -t tmpfs -o rw,nosuid,nodev,mode=1777,size=256M tmpfs /dev/shm
sudo chmod 1777 /tmp/.ICE-unix

echo "VSCodium(code-server) listening at http://127.0.0.1:13337"
echo "Press Ctrl+C to stop."

# IMPORTANT: exec keeps this attached to your Termux terminal
exec code-server-local 13337
'
SH
chmod 0755 "$PREFIX/bin/vscodium-server-chroot-start"

cat >"$PREFIX/bin/vscodium-server-chroot-stop" <<'SH'
#!/data/data/com.termux/files/usr/bin/sh
set -e
# Gracefully stop via the in-container wrapper
ubuntu-chroot /bin/bash -lc 'code-server-stop' || true
echo "VSCodium(code-server) stopped."
SH
chmod 0755 "$PREFIX/bin/vscodium-server-chroot-stop"

echo "✅ VSCodium(code-server) entrypoints installed."
echo "Start (FG): vscodium-server-chroot-start   # Ctrl+C to stop"
echo "Stop:       vscodium-server-chroot-stop"
