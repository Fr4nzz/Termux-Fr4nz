#!/data/data/com.termux/files/usr/bin/bash
set -eu
( set -o pipefail ) 2>/dev/null && set -o pipefail
: "${PREFIX:=/data/data/com.termux/files/usr}"

# Ensure ubuntu-proot wrapper exists (bootstraps container on demand)
if ! command -v ubuntu-proot >/dev/null 2>&1; then
  echo "[*] ubuntu-proot not found. Setting up rootless Ubuntu container..."
  curl -fsSL https://raw.githubusercontent.com/Fr4nzz/Termux-Fr4nz/refs/heads/main/termux-scripts/setup_rootless_container_unattended.sh | bash
  echo "[*] Rootless container setup complete."
fi

# Install code-server inside the container
curl -fsSL https://raw.githubusercontent.com/Fr4nzz/Termux-Fr4nz/refs/heads/main/container-scripts/install_vscode_server.sh \
  | ubuntu-proot

mkdir -p "$PREFIX/bin"

cat >"$PREFIX/bin/vscode-server-proot-start" <<'SH'
#!/data/data/com.termux/files/usr/bin/sh
set -e
: "${PREFIX:=/data/data/com.termux/files/usr}"
CONTAINER="${CONTAINER:-$HOME/containers/ubuntu-proot}"
PROOT="$PREFIX/share/daijin/proot_start.sh"
TP="$PREFIX/tmp/.X11-unix"; [ -d "$TP" ] || mkdir -p "$TP"
PROOT_TMP="$PREFIX/tmp/proot"; [ -d "$PROOT_TMP" ] || mkdir -p "$PROOT_TMP"
BIND="-b $TP:/tmp/.X11-unix -b /sdcard:/mnt/sdcard"

run_container() {
  exec env \
    PROOT_NO_SECCOMP=1 \
    PROOT_TMP_DIR="$PROOT_TMP" \
    "$PROOT" -r "$CONTAINER" -e "$BIND" \
    /usr/bin/env -i \
      HOME=/root \
      TERM="${TERM:-xterm-256color}" \
      LANG="${LANG:-en_US.UTF-8}" \
      PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin \
      LD_PRELOAD= \
      "$@"
}

# Parse flags
USE_HTTPS=false

while [ $# -gt 0 ]; do
  case "$1" in
    --https) USE_HTTPS=true; shift ;;
    *) shift ;;
  esac
done

PHONE_IP="$(phone-ip 2>/dev/null || echo '(unknown)')"

if [ "$USE_HTTPS" = "true" ]; then
  # Check if HTTPS certs exist
  if ! ubuntu-proot test -f /opt/code-server-certs/cert.pem; then
    echo "❌ HTTPS certificates not found."
    echo "Run: cert-server-proot"
    exit 1
  fi
  
  PROTOCOL="https"
  echo "========================================="
  echo "VS Code Server (proot) - HTTPS"
  echo "========================================="
  echo ""
  echo "🔒 HTTPS enabled:"
  echo "   $PROTOCOL://$PHONE_IP:13338"
  echo ""
  echo "📥 First time? Install certificate:"
  echo "   http://$PHONE_IP:8889/setup"
  echo ""
else
  PROTOCOL="http"
  echo "========================================="
  echo "VS Code Server (proot) - HTTP"
  echo "========================================="
  echo ""
  echo "🌐 HTTP mode:"
  echo "   http://127.0.0.1:13338"
  echo "   http://$PHONE_IP:13338"
  echo ""
  echo "💡 For HTTPS on LAN: vscode-server-proot-start --https"
  echo ""
fi

echo "Press Ctrl+C to stop"
echo "========================================="
echo ""

# Run in foreground
if [ "$USE_HTTPS" = "true" ]; then
  run_container code-server-https --https
else
  run_container code-server-https
fi
SH
chmod 0755 "$PREFIX/bin/vscode-server-proot-start"

cat >"$PREFIX/bin/cert-server-proot" <<'SH'
#!/data/data/com.termux/files/usr/bin/sh
: "${PREFIX:=/data/data/com.termux/files/usr}"
CONTAINER="${CONTAINER:-$HOME/containers/ubuntu-proot}"
PROOT="$PREFIX/share/daijin/proot_start.sh"
TP="$PREFIX/tmp/.X11-unix"; [ -d "$TP" ] || mkdir -p "$TP"
PROOT_TMP="$PREFIX/tmp/proot"; [ -d "$PROOT_TMP" ] || mkdir -p "$PROOT_TMP"
BIND="-b $TP:/tmp/.X11-unix -b /sdcard:/mnt/sdcard"

exec env \
  PROOT_NO_SECCOMP=1 \
  PROOT_TMP_DIR="$PROOT_TMP" \
  "$PROOT" -r "$CONTAINER" -e "$BIND" \
  /usr/bin/env -i \
    HOME=/root \
    TERM="${TERM:-xterm-256color}" \
    LANG="${LANG:-en_US.UTF-8}" \
    PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin \
    LD_PRELOAD= \
    cert-server 8889
SH
chmod 0755 "$PREFIX/bin/cert-server-proot"

PHONE_IP="$(phone-ip)"
echo "✅ VS Code Server (proot) installed"
echo ""
echo "Usage:"
echo "  vscode-server-proot-start          # HTTP mode (default)"
echo "  vscode-server-proot-start --https  # HTTPS mode (for LAN access)"
echo ""
echo "Setup HTTPS certificate (one-time):"
echo "  cert-server-proot"
