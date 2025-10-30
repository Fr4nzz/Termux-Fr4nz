#!/data/data/com.termux/files/usr/bin/bash
# Unattended installer for openvscode-server in the rootless container.
set -eu
( set -o pipefail ) 2>/dev/null && set -o pipefail
: "${PREFIX:=/data/data/com.termux/files/usr}"

# Install inside the container (bash reads stdin)
curl -fsSL https://raw.githubusercontent.com/Fr4nzz/Termux-Fr4nz/refs/heads/main/container-scripts/install_vscodium_server.sh \
  | ubuntu-proot

# Wrappers
mkdir -p "$PREFIX/bin" "$PREFIX/var/run"

# termux-scripts/install_vscodium_server_proot_unattended.sh
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

ubuntu-proot /bin/sh > /dev/null 2>&1 <<'INNER' &
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
/opt/openvscode-server/bin/openvscode-server \
  --host 127.0.0.1 \
  --port 13337 \
  --without-connection-token \
  --server-data-dir "$HOME/.ovscode-data" \
  --extensions-dir "$HOME/.ovscode-extensions" &
exec sleep infinity
INNER

echo $! >"$PIDFILE"
echo "VSCodium Server (proot) is up at http://127.0.0.1:13337"
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

  # optional graceful stop
  ubuntu-proot /bin/sh <<'IN' >/dev/null 2>&1 || true
set -e
pkill -f '/opt/openvscode-server/bin/openvscode-server' || true
IN

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

echo "✅ VSCodium Server (proot) installed."
echo "Use: vscodium-server-proot-start / vscodium-server-proot-stop"
