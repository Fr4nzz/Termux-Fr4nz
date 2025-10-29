#!/data/data/com.termux/files/usr/bin/bash
set -eu
( set -o pipefail ) 2>/dev/null && set -o pipefail
: "${PREFIX:=/data/data/com.termux/files/usr}"

# Install inside the container (bash reads stdin)
curl -fsSL https://raw.githubusercontent.com/Fr4nzz/Termux-Fr4nz/refs/heads/main/container-scripts/install_vscode_server.sh \
  | ubuntu-proot /bin/bash -s

# Wrappers
mkdir -p "$PREFIX/bin" "$PREFIX/var/run"

cat >"$PREFIX/bin/vscode-server-proot-start" <<'SH'
#!/data/data/com.termux/files/usr/bin/sh
set -e
: "${PREFIX:=/data/data/com.termux/files/usr}"
PIDFILE="$PREFIX/var/run/vscode-proot.pid"
mkdir -p "$PREFIX/var/run"

if [ -f "$PIDFILE" ] && kill -0 "$(cat "$PIDFILE")" 2>/dev/null; then
  echo "vscode-server-proot-start: already running (PID $(cat "$PIDFILE"))."
  exit 0
fi

ubuntu-proot /bin/sh <<'IN' >/dev/null 2>&1 &
set -e
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
nohup /opt/code-server/bin/code-server \
  --bind-addr 127.0.0.1:13338 \
  --auth none \
  --user-data-dir "$HOME/.code-server-data" \
  --extensions-dir "$HOME/.code-server-extensions" >/dev/null 2>&1 &
exec tail -f /dev/null
IN

echo $! >"$PIDFILE"
echo "VS Code Server (proot) is up on http://127.0.0.1:13338"
echo "Stop with: vscode-server-proot-stop"
SH
chmod 0755 "$PREFIX/bin/vscode-server-proot-start"

cat >"$PREFIX/bin/vscode-server-proot-stop" <<'SH'
#!/data/data/com.termux/files/usr/bin/sh
set -e
: "${PREFIX:=/data/data/com.termux/files/usr}"
PIDFILE="$PREFIX/var/run/vscode-proot.pid"

if [ -f "$PIDFILE" ]; then
  PID="$(cat "$PIDFILE")"

  # optional graceful stop inside the container
  ubuntu-proot /bin/sh <<'IN' >/dev/null 2>&1 || true
set -e
pkill -f '/opt/code-server/bin/code-server' || true
IN

  if kill -0 "$PID" 2>/dev/null; then
    kill "$PID" 2>/dev/null || true
    sleep 1
    kill -9 "$PID" 2>/dev/null || true
    echo "VS Code Server (proot) stopped."
  else
    echo "Not running (stale pidfile)."
  fi
  rm -f "$PIDFILE"
else
  echo "Not running (no pidfile)."
fi
SH
chmod 0755 "$PREFIX/bin/vscode-server-proot-stop"

echo "✅ VS Code Server (proot) ready: vscode-server-proot-start / vscode-server-proot-stop"
