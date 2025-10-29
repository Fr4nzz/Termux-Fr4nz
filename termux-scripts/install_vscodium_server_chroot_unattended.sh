#!/data/data/com.termux/files/usr/bin/bash
# Unattended installer for openvscode-server (VSCodium-like web IDE)
# in the rooted container (rurima/ruri chroot).
#
# After running this in Termux:
#   vscodium-server-chroot-start
#   -> open http://127.0.0.1:13337 in mobile browser
#   vscodium-server-chroot-stop
#
# Mirrors rstudio-chroot-start/stop style.

set -euo pipefail
: "${PREFIX:=/data/data/com.termux/files/usr}"

# 1) Run the container-side installer inside the rooted Ubuntu chroot
curl -fsSL https://raw.githubusercontent.com/Fr4nzz/Termux-Fr4nz/refs/heads/main/container-scripts/install_vscodium_server.sh \
  | ubuntu-chroot /bin/bash -s

# 2) Create Termux wrappers
mkdir -p "$PREFIX/bin" "$PREFIX/var/run"

cat >"$PREFIX/bin/vscodium-server-chroot-start" <<'SH'
#!/data/data/com.termux/files/usr/bin/sh
: "${PREFIX:=/data/data/com.termux/files/usr}"
PIDFILE="$PREFIX/var/run/vscodium-chroot.pid"
mkdir -p "$PREFIX/var/run"

if [ -f "$PIDFILE" ] && kill -0 "$(cat "$PIDFILE")" 2>/dev/null; then
  echo "vscodium-server-chroot-start: already running (PID $(cat "$PIDFILE"))."
  exit 0
fi

ubuntu-chroot /bin/bash -lc '
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

# Minimal mounts so Node/Electron bits are happy in chroot.
sudo mountpoint -q /proc || sudo mount -t proc proc /proc
sudo mountpoint -q /sys  || sudo mount -t sysfs sys /sys
sudo mkdir -p /dev/pts /dev/shm /run /tmp/.ICE-unix
sudo mountpoint -q /dev/pts || sudo mount -t devpts devpts /dev/pts
sudo mountpoint -q /dev/shm || sudo mount -t tmpfs -o rw,nosuid,nodev,mode=1777,size=256M tmpfs /dev/shm
sudo chmod 1777 /tmp/.ICE-unix

# Start openvscode-server on localhost:13337 (no token, local browser only)
# and then keep container alive with sleep infinity.
 /opt/openvscode-server/bin/openvscode-server \
   --host 127.0.0.1 \
   --port 13337 \
   --without-connection-token \
   --server-data-dir "$HOME/.ovscode-data" \
   --extensions-dir "$HOME/.ovscode-extensions" || true

sleep infinity
' &

echo $! >"$PIDFILE"

PHONE_IP="$(sudo ip -4 addr show wlan0 2>/dev/null | awk '/inet / {print $2}' | cut -d/ -f1)"

echo "VSCodium Server (chroot) is up."
echo "Open http://127.0.0.1:13337"
if [ -n "$PHONE_IP" ]; then
  echo "(If you expose 13337 on all interfaces later, LAN would be: http://$PHONE_IP:13337 )"
fi
echo
echo "Stop with: vscodium-server-chroot-stop"
SH
chmod 0755 "$PREFIX/bin/vscodium-server-chroot-start"

cat >"$PREFIX/bin/vscodium-server-chroot-stop" <<'SH'
#!/data/data/com.termux/files/usr/bin/sh
: "${PREFIX:=/data/data/com.termux/files/usr}"
PIDFILE="$PREFIX/var/run/vscodium-chroot.pid"

if [ -f "$PIDFILE" ]; then
  PID="$(cat "$PIDFILE")"
  if kill -0 "$PID" 2>/dev/null; then
    kill "$PID" 2>/dev/null || true
    sleep 1
    kill -9 "$PID" 2>/dev/null || true
    echo "VSCodium Server (chroot) stopped."
  else
    echo "Not running (stale pidfile)."
  fi
  rm -f "$PIDFILE"
else
  echo "Not running (no pidfile)."
fi
SH
chmod 0755 "$PREFIX/bin/vscodium-server-chroot-stop"

echo "✅ VSCodium Server (chroot) installed."
echo "Use: vscodium-server-chroot-start / vscodium-server-chroot-stop"
