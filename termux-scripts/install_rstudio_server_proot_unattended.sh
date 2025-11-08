#!/data/data/com.termux/files/usr/bin/bash
# install_rstudio_server_proot_unattended.sh
set -eu
( set -o pipefail ) 2>/dev/null && set -o pipefail
: "${PREFIX:=/data/data/com.termux/files/usr}"

# Ensure ubuntu-proot wrapper exists
if ! command -v ubuntu-proot >/dev/null 2>&1; then
  echo "[*] ubuntu-proot not found. Setting up rootless Ubuntu container..."
  curl -fsSL https://raw.githubusercontent.com/Fr4nzz/Termux-Fr4nz/refs/heads/main/termux-scripts/setup_rootless_container_unattended.sh | bash
  echo "[*] Rootless container setup complete."
fi

# 1) Install RStudio Server inside the rootless container (proot)
curl -fsSL https://raw.githubusercontent.com/Fr4nzz/Termux-Fr4nz/refs/heads/main/container-scripts/install_rstudio_server.sh \
  | ubuntu-proot /bin/bash -s

# 2) Wrappers
mkdir -p "$PREFIX/bin" "$PREFIX/var/run"

cat >"$PREFIX/bin/rstudio-proot-start" <<'SH'
#!/data/data/com.termux/files/usr/bin/sh
set -e
: "${PREFIX:=/data/data/com.termux/files/usr}"
PIDFILE="$PREFIX/var/run/rstudio-proot.pid"
mkdir -p "$PREFIX/var/run"

if [ -f "$PIDFILE" ] && kill -0 "$(cat "$PIDFILE")" 2>/dev/null; then
  echo "rstudio-proot-start: already running (PID $(cat "$PIDFILE"))."
  exit 0
fi

# Start the server inside the proot; keep a tiny tail running so we can stop it later.
ubuntu-proot /bin/sh <<'IN' >/dev/null 2>&1 &
set -e
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
# Start (prefer sudo, but fall back to direct)
sudo rstudio-server start 2>/dev/null || rstudio-server start || true
# Keep process alive (PID tracked by Termux wrapper)
exec tail -f /dev/null
IN

echo $! >"$PIDFILE"

# Host-side URLs
PHONE_IP="$(phone-ip)"
echo "RStudio Server (proot) is up:"
echo "  Local:  http://127.0.0.1:8787"
[ -n "$PHONE_IP" ] && echo "  LAN:    http://$PHONE_IP:8787"
echo "Stop with: rstudio-proot-stop"
SH
chmod 0755 "$PREFIX/bin/rstudio-proot-start"

cat >"$PREFIX/bin/rstudio-proot-stop" <<'SH'
#!/data/data/com.termux/files/usr/bin/sh
set -e
: "${PREFIX:=/data/data/com.termux/files/usr}"
PIDFILE="$PREFIX/var/run/rstudio-proot.pid"

# First, stop the real server inside the proot
ubuntu-proot /bin/sh <<'IN' >/dev/null 2>&1 || true
set -e
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
sudo rstudio-server stop 2>/dev/null || rstudio-server stop || true
# Make sure the daemon is gone (fallback)
pkill -f '/usr/lib/rstudio-server/bin/rserver' 2>/dev/null || true
pkill -f '[r]server' 2>/dev/null || true
IN

# Then clean up our background keeper
if [ -f "$PIDFILE" ]; then
  PID="$(cat "$PIDFILE")"
  if kill -0 "$PID" 2>/dev/null; then
    kill "$PID" 2>/dev/null || true
    sleep 1
    kill -9 "$PID" 2>/dev/null || true
    echo "RStudio (proot) stopped."
  else
    echo "Not running (stale pidfile)."
  fi
  rm -f "$PIDFILE"
else
  echo "Not running (no pidfile)."
fi
SH
chmod 0755 "$PREFIX/bin/rstudio-proot-stop"

echo "✅ RStudio Server (proot) ready: rstudio-proot-start / rstudio-proot-stop"
