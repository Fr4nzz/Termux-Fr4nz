#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail
: "${PREFIX:=/data/data/com.termux/files/usr}"

# Install code-server inside the rooted container (adds /usr/local/bin/code-server-local and code-server-stop)
curl -fsSL https://raw.githubusercontent.com/Fr4nzz/Termux-Fr4nz/refs/heads/main/container-scripts/install_vscode_server.sh \
  | ubuntu-chroot /bin/bash -s

mkdir -p "$PREFIX/bin" "$PREFIX/var/run"

cat >"$PREFIX/bin/vscode-server-chroot-start" <<'SH'
#!/data/data/com.termux/files/usr/bin/sh
set -e
: "${PREFIX:=/data/data/com.termux/files/usr}"
PIDFILE="$PREFIX/var/run/vscode-chroot.pid"
mkdir -p "$PREFIX/var/run"

# already running?
if [ -f "$PIDFILE" ] && kill -0 "$(cat "$PIDFILE")" 2>/dev/null; then
  echo "vscode-server-chroot-start: already running (PID $(cat "$PIDFILE"))."
  exit 0
fi

# Simple: call the in-container wrapper
ubuntu-chroot /bin/bash -lc 'code-server-local' >/dev/null 2>&1 &

echo $! >"$PIDFILE"

# Detect phone IP (optional nice-to-have)
PHONE_IP="$(sudo ip -4 addr show wlan0 2>/dev/null | awk '/inet / {print $2}' | cut -d/ -f1 || true)"

echo "VS Code Server (chroot) is up:"
echo "  Local:  http://127.0.0.1:13338"
[ -n "$PHONE_IP" ] && echo "  LAN:    http://$PHONE_IP:13338"
echo "Stop with: vscode-server-chroot-stop"
SH
chmod 0755 "$PREFIX/bin/vscode-server-chroot-start"

cat >"$PREFIX/bin/vscode-server-chroot-stop" <<'SH'
#!/data/data/com.termux/files/usr/bin/sh
set -e
: "${PREFIX:=/data/data/com.termux/files/usr}"
PIDFILE="$PREFIX/var/run/vscode-chroot.pid"

if [ -f "$PIDFILE" ]; then
  PID="$(cat "$PIDFILE")"
  # Simple: ask the container to stop via its wrapper
  ubuntu-chroot /bin/bash -lc 'code-server-stop' 2>/dev/null || true

  # stop the backgrounded launcher if still alive
  if kill -0 "$PID" 2>/dev/null; then
    kill "$PID" 2>/dev/null || true
    sleep 1
    kill -9 "$PID" 2>/dev/null || true
    echo "VS Code Server (chroot) stopped."
  else
    echo "Not running (stale pidfile)."
  fi
  rm -f "$PIDFILE"
else
  echo "Not running (no pidfile)."
fi
SH
chmod 0755 "$PREFIX/bin/vscode-server-chroot-stop"

echo "✅ VS Code Server (chroot) ready: vscode-server-chroot-start / vscode-server-chroot-stop"
