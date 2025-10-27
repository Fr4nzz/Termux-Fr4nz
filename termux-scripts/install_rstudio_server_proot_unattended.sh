#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail
: "${PREFIX:=/data/data/com.termux/files/usr}"

# Install RStudio Server inside the rootless container (ensures R if missing)
curl -fsSL https://raw.githubusercontent.com/Fr4nzz/Termux-Fr4nz/refs/heads/main/container-scripts/install_rstudio_server.sh \
  | ubuntu-proot /bin/bash -s

# Create Termux wrappers for proot
mkdir -p "$PREFIX/bin" "$PREFIX/var/run"

cat >"$PREFIX/bin/rstudio-proot-start" <<'SH'
#!/data/data/com.termux/files/usr/bin/sh
: "${PREFIX:=/data/data/com.termux/files/usr}"
PIDFILE="$PREFIX/var/run/rstudio-proot.pid"
mkdir -p "$PREFIX/var/run"
if [ -f "$PIDFILE" ] && kill -0 "$(cat "$PIDFILE")" 2>/dev/null; then
  echo "rstudio-proot-start: already running (PID $(cat "$PIDFILE"))."
  exit 0
fi
ubuntu-proot /bin/sh -c '
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
sudo rstudio-server start || true
sleep infinity
' &
echo $! >"$PIDFILE"
echo "RStudio Server (proot) on http://127.0.0.1:8787 (stop: rstudio-proot-stop)"
SH
chmod 0755 "$PREFIX/bin/rstudio-proot-start"

cat >"$PREFIX/bin/rstudio-proot-stop" <<'SH'
#!/data/data/com.termux/files/usr/bin/sh
: "${PREFIX:=/data/data/com.termux/files/usr}"
PIDFILE="$PREFIX/var/run/rstudio-proot.pid"
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

echo "✅ RStudio Server (proot) installed. Use: rstudio-proot-start / rstudio-proot-stop"
