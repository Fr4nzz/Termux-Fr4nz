#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail
: "${PREFIX:=/data/data/com.termux/files/usr}"

# Ensure ubuntu-chroot wrapper exists
if ! command -v ubuntu-chroot >/dev/null 2>&1; then
  echo "[*] ubuntu-chroot not found. Setting up rooted Ubuntu container (requires sudo/tsu)..."
  curl -fsSL https://raw.githubusercontent.com/Fr4nzz/Termux-Fr4nz/refs/heads/main/termux-scripts/setup_rooted_container_unattended.sh | bash
  echo "[*] Rooted container setup complete."
fi

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
set -e
: "${PREFIX:=/data/data/com.termux/files/usr}"
PIDFILE="$PREFIX/var/run/rstudio-chroot.pid"
ubuntu-chroot /bin/bash -lc '
/usr/sbin/rstudio-server stop || true
pkill -x rserver  2>/dev/null || true
pkill -x rsession 2>/dev/null || true
' >/dev/null 2>&1 || true
if [ -f "$PIDFILE" ]; then
  PID="$(cat "$PIDFILE")"
  if kill -0 "$PID" 2>/dev/null; then
    kill "$PID" 2>/dev/null || true
    kill -9 "$PID" 2>/dev/null || true
    echo "Stopped launcher (PID $PID)."
  else
    echo "Not running (stale pidfile)."
  fi
  rm -f "$PIDFILE"
else
  echo "Not running (no pidfile)."
fi
echo "RStudio (chroot) stopped."
SH
chmod 0755 "$PREFIX/bin/rstudio-chroot-stop"

echo "✅ RStudio Server (chroot) ready: rstudio-chroot-start / rstudio-chroot-stop"
