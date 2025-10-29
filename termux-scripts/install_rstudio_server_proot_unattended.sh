#!/data/data/com.termux/files/usr/bin/bash
# install_rstudio_server_proot_unattended.sh
set -eu
( set -o pipefail ) 2>/dev/null && set -o pipefail
: "${PREFIX:=/data/data/com.termux/files/usr}"

# Install inside the rootless container (bash reads stdin)
curl -fsSL https://raw.githubusercontent.com/Fr4nzz/Termux-Fr4nz/refs/heads/main/container-scripts/install_rstudio_server.sh \
  | ubuntu-proot /bin/bash -s

# Wrappers
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

ubuntu-proot /bin/sh <<'IN' >/dev/null 2>&1 &
set -e
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
sudo rstudio-server start || true
exec tail -f /dev/null
IN

echo $! >"$PIDFILE"
echo "RStudio Server (proot) on http://127.0.0.1:8787"
echo "Stop with: rstudio-proot-stop"
SH
chmod 0755 "$PREFIX/bin/rstudio-proot-start"

cat >"$PREFIX/bin/rstudio-proot-stop" <<'SH'
#!/data/data/com.termux/files/usr/bin/sh
set -e
: "${PREFIX:=/data/data/com.termux/files/usr}"
PIDFILE="$PREFIX/var/run/rstudio-proot.pid"

if [ -f "$PIDFILE" ]; then
  PID="$(cat "$PIDFILE")"

  ubuntu-proot /bin/sh <<'IN' >/dev/null 2>&1 || true
set -e
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
sudo rstudio-server stop || true
IN

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
