#!/data/data/com.termux/files/usr/bin/bash
# Unattended installer for a browser-accessible VSCodium-like server
# (openvscode-server) in the rootless (proot/daijin) container.
#
# After running this in Termux:
#   vscodium-server-proot-start
#   -> open http://127.0.0.1:13337 in mobile browser
#   vscodium-server-proot-stop
#
# Mirrors the rstudio-proot-start/stop style.

set -euo pipefail
: "${PREFIX:=/data/data/com.termux/files/usr}"

# 1) Run the container-side installer inside the proot container
curl -fsSL https://raw.githubusercontent.com/Fr4nzz/Termux-Fr4nz/refs/heads/main/container-scripts/install_vscodium_server.sh \
  | ubuntu-proot /bin/bash -s

# 2) Create Termux wrappers
mkdir -p "$PREFIX/bin" "$PREFIX/var/run"

cat >"$PREFIX/bin/vscodium-server-proot-start" <<'SH'
#!/data/data/com.termux/files/usr/bin/sh
: "${PREFIX:=/data/data/com.termux/files/usr}"
PIDFILE="$PREFIX/var/run/vscodium-proot.pid"
mkdir -p "$PREFIX/var/run"

if [ -f "$PIDFILE" ] && kill -0 "$(cat "$PIDFILE")" 2>/dev/null; then
  echo "vscodium-server-proot-start: already running (PID $(cat "$PIDFILE"))."
  exit 0
fi

# We launch openvscode-server INSIDE the Ubuntu proot container and then
# keep that proot alive with `sleep infinity`, just like rstudio-proot-start.
ubuntu-proot /bin/sh -c '
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
/opt/openvscode-server/bin/openvscode-server \
  --host 127.0.0.1 \
  --port 13337 \
  --without-connection-token \
  --server-data-dir "$HOME/.ovscode-data" \
  --extensions-dir "$HOME/.ovscode-extensions" || true
sleep infinity
' &

echo $! >"$PIDFILE"
echo "VSCodium Server (proot) is up."
echo "Open http://127.0.0.1:13337"
echo
echo "Stop with: vscodium-server-proot-stop"
SH
chmod 0755 "$PREFIX/bin/vscodium-server-proot-start"

cat >"$PREFIX/bin/vscodium-server-proot-stop" <<'SH'
#!/data/data/com.termux/files/usr/bin/sh
: "${PREFIX:=/data/data/com.termux/files/usr}"
PIDFILE="$PREFIX/var/run/vscodium-proot.pid"

if [ -f "$PIDFILE" ]; then
  PID="$(cat "$PIDFILE")"
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
