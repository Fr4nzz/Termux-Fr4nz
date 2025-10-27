#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail
: "${PREFIX:=/data/data/com.termux/files/usr}"

# Install RStudio Server inside the rooted container (ensures R if missing)
curl -fsSL https://raw.githubusercontent.com/Fr4nzz/Termux-Fr4nz/refs/heads/main/container-scripts/install_rstudio_server.sh \
  | ubuntu-chroot /bin/bash -s

# Create Termux wrappers for chroot
mkdir -p "$PREFIX/bin" "$PREFIX/var/run"

cat >"$PREFIX/bin/rstudio-chroot-start" <<'SH'
#!/data/data/com.termux/files/usr/bin/sh
: "${PREFIX:=/data/data/com.termux/files/usr}"
PIDFILE="$PREFIX/var/run/rstudio-chroot.pid"
mkdir -p "$PREFIX/var/run"
if [ -f "$PIDFILE" ] && kill -0 "$(cat "$PIDFILE")" 2>/dev/null; then
  echo "rstudio-chroot-start: already running (PID $(cat "$PIDFILE"))."
  exit 0
fi
ubuntu-chroot /bin/bash -lc '
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
sudo mountpoint -q /proc || sudo mount -t proc proc /proc
sudo mountpoint -q /sys  || sudo mount -t sysfs sys /sys
sudo mkdir -p /dev/pts /dev/shm /run /tmp/.ICE-unix
sudo mountpoint -q /dev/pts || sudo mount -t devpts devpts /dev/pts
sudo mountpoint -q /dev/shm || sudo mount -t tmpfs -o rw,nosuid,nodev,mode=1777,size=256M tmpfs /dev/shm
sudo chmod 1777 /tmp/.ICE-unix
sudo rstudio-server start || true
sleep infinity
' &
echo $! >"$PIDFILE"
PHONE_IP="$(sudo ip -4 addr show wlan0 2>/dev/null | awk '/inet / {print $2}' | cut -d/ -f1)"
echo "RStudio Server (chroot) on http://127.0.0.1:8787 (stop: rstudio-chroot-stop)"
[ -n "$PHONE_IP" ] && echo "LAN: http://$PHONE_IP:8787"
SH
chmod 0755 "$PREFIX/bin/rstudio-chroot-start"

cat >"$PREFIX/bin/rstudio-chroot-stop" <<'SH'
#!/data/data/com.termux/files/usr/bin/sh
: "${PREFIX:=/data/data/com.termux/files/usr}"
PIDFILE="$PREFIX/var/run/rstudio-chroot.pid"
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

echo "✅ RStudio Server (chroot) installed. Use: rstudio-chroot-start / rstudio-chroot-stop"
