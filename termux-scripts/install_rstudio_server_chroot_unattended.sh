#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail
: "${PREFIX:=/data/data/com.termux/files/usr}"

# Install inside rooted container
curl -fsSL https://raw.githubusercontent.com/Fr4nzz/Termux-Fr4nz/refs/heads/main/container-scripts/install_rstudio_server.sh \
  | ubuntu-chroot /bin/bash -s

# Wrappers
mkdir -p "$PREFIX/bin" "$PREFIX/var/run"

cat >"$PREFIX/bin/rstudio-chroot-start" <<'SH'
#!/data/data/com.termux/files/usr/bin/sh
: "${PREFIX:=/data/data/com.termux/files/usr}"
PIDFILE="$PREFIX/var/run/rstudio-chroot.pid"
mkdir -p "$PREFIX/var/run"

if [ -f "$PIDFILE" ] && kill -0 "$(cat "$PIDFILE")" 2>/dev/null; then
  echo "rstudio-chroot-start: already running (PID $(cat "$PIDFILE"))."; exit 0
fi

ubuntu-chroot /bin/bash -s <<'INNER' &
set -e
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
# mounts for chroot runtime
sudo mountpoint -q /proc || sudo mount -t proc proc /proc
sudo mountpoint -q /sys  || sudo mount -t sysfs sys /sys
sudo mkdir -p /dev/pts /dev/shm /run /tmp/.ICE-unix
sudo mountpoint -q /dev/pts || sudo mount -t devpts devpts /dev/pts
sudo mountpoint -q /dev/shm || sudo mount -t tmpfs -o rw,nosuid,nodev,mode=1777,size=256M tmpfs /dev/shm
sudo chmod 1777 /tmp/.ICE-unix
# start server
sudo rstudio-server start || true
# keep the launcher alive
sleep infinity
INNER

echo $! >"$PIDFILE"

PHONE_IP="$(phone-ip)"
echo "RStudio Server (chroot) on http://127.0.0.1:8787"
[ -n "$PHONE_IP" ] && echo "LAN: http://$PHONE_IP:8787"
echo "Stop with: rstudio-chroot-stop"
SH
chmod 0755 "$PREFIX/bin/rstudio-chroot-start"

cat >"$PREFIX/bin/rstudio-chroot-stop" <<'SH'
#!/data/data/com.termux/files/usr/bin/sh
: "${PREFIX:=/data/data/com.termux/files/usr}"
PIDFILE="$PREFIX/var/run/rstudio-chroot.pid"

# Stop the actual server first
ubuntu-chroot /bin/bash -lc 'rstudio-server stop' 2>/dev/null || true

# Then clean up the background launcher
if [ -f "$PIDFILE" ]; then
  PID="$(cat "$PIDFILE")"
  if kill -0 "$PID" 2>/dev/null; then
    kill "$PID" 2>/dev/null || true
    sleep 1
    kill -9 "$PID" 2>/dev/null || true
    echo "RStudio (chroot) stopped."
  else
    echo "Not running (stale pidfile)."
  fi
  rm -f "$PIDFILE"
else
  echo "Not running (no pidfile)."
fi
SH
chmod 0755 "$PREFIX/bin/rstudio-chroot-stop"

echo "✅ RStudio Server (chroot) ready: rstudio-chroot-start / rstudio-chroot-stop"
