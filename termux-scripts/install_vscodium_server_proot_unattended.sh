#!/data/data/com.termux/files/usr/bin/bash
set -eu
( set -o pipefail ) 2>/dev/null && set -o pipefail
: "${PREFIX:=/data/data/com.termux/files/usr}"

# Install inside the container
curl -fsSL https://raw.githubusercontent.com/Fr4nzz/Termux-Fr4nz/refs/heads/main/container-scripts/install_vscodium_server.sh \
  | ubuntu-proot /bin/bash -s

# Termux wrappers (call Ubuntu wrapper)
mkdir -p "$PREFIX/bin" "$PREFIX/var/run"

cat >"$PREFIX/bin/vscodium-server-proot-start" <<'SH'
#!/data/data/com.termux/files/usr/bin/sh
set -e
: "${PREFIX:=/data/data/com.termux/files/usr}"
PIDFILE="$PREFIX/var/run/vscodium-proot.pid"
mkdir -p "$PREFIX/var/run"

if [ -f "$PIDFILE" ] && kill -0 "$(cat "$PIDFILE")" 2>/dev/null; then
  echo "vscodium-server-proot-start: already running (PID $(cat "$PIDFILE"))."
  exit 0
fi

# Call the Ubuntu wrapper directly
ubuntu-proot /bin/bash -lc 'openvscode-server-local' > /dev/null 2>&1 &

echo $! >"$PIDFILE"

# Detect phone IP
PHONE_IP="$(ip -4 addr show wlan0 2>/dev/null | awk '/inet / {print $2}' | cut -d/ -f1 || true)"

echo "VSCodium Server (proot) is up:"
echo "  Local:  http://127.0.0.1:13337"
[ -n "$PHONE_IP" ] && echo "  LAN:    http://$PHONE_IP:13337"
echo "Stop with: vscodium-server-proot-stop"
SH
chmod 0755 "$PREFIX/bin/vscodium-server-proot-start"

cat >"$PREFIX/bin/vscodium-server-proot-stop" <<'SH'
#!/data/data/com.termux/files/usr/bin/sh
set -e
: "${PREFIX:=/data/data/com.termux/files/usr}"
PIDFILE="$PREFIX/var/run/vscodium-proot.pid"

if [ -f "$PIDFILE" ]; then
  PID="$(cat "$PIDFILE")"
  ubuntu-proot /bin/sh -c 'pkill -f "/opt/openvscode-server/bin/openvscode-server"' 2>/dev/null || true
  if kill -0 "$PID" 2>/dev/null; then
    kill "$PID" 2>/dev/null || true
    sleep 1
    kill -9 "$PID" 2>/dev/null || true
    echo "VSCodium Server (proot) stopped."
  else
    echo "Not running (stale pidfile)."
  fi
  rm -f "$PIDFILE"
else
  echo "Not running (no pidfile)."
fi
SH
chmod 0755 "$PREFIX/bin/vscodium-server-proot-stop"

echo "✅ VSCodium Server (proot) ready: vscodium-server-proot-start / vscodium-server-proot-stop"