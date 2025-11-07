#!/data/data/com.termux/files/usr/bin/bash
set -eu
( set -o pipefail ) 2>/dev/null && set -o pipefail
: "${PREFIX:=/data/data/com.termux/files/usr}"

# Install code-server inside the container (includes R, Python, and HTTPS setup)
curl -fsSL https://raw.githubusercontent.com/Fr4nzz/Termux-Fr4nz/refs/heads/main/container-scripts/install_vscode_server.sh \
  | ubuntu-proot /bin/bash -s

# Termux wrappers
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

# Check if HTTPS certs exist, use HTTPS if available
HTTPS_CHECK=$(ubuntu-proot /bin/sh -c '[ -f /opt/code-server-certs/cert.pem ] && echo "yes" || echo "no"')

if [ "$HTTPS_CHECK" = "yes" ]; then
  LAUNCHER="code-server-https"
  PROTOCOL="https"
else
  LAUNCHER="code-server-local"
  PROTOCOL="http"
fi

# Start server in background
ubuntu-proot /bin/bash -lc "$LAUNCHER" > /dev/null 2>&1 &

echo $! >"$PIDFILE"

# Detect phone IP
PHONE_IP="$(ip -4 addr show wlan0 2>/dev/null | awk '/inet / {print $2}' | cut -d/ -f1 || echo "YOUR-PHONE-IP")"

echo "========================================="
echo "VS Code Server (proot)"
echo "========================================="
echo ""
echo "Local:  $PROTOCOL://127.0.0.1:13338"
echo "LAN:    $PROTOCOL://$PHONE_IP:13338"
echo ""
if [ "$PROTOCOL" = "https" ]; then
  echo "✅ HTTPS enabled - all features work!"
else
  echo "⚠️  HTTP mode - for HTTPS setup run:"
  echo "   cert-server-proot"
fi
echo ""
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
  ubuntu-proot /bin/sh -c 'pkill -f "/opt/code-server/bin/code-server"' 2>/dev/null || true
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

cat >"$PREFIX/bin/cert-server-proot" <<'SH'
#!/data/data/com.termux/files/usr/bin/sh
set -e

exec ubuntu-proot /bin/bash -lc 'cert-server 8889'
SH
chmod 0755 "$PREFIX/bin/cert-server-proot"

# Get phone IP for display
PHONE_IP=$(ip -4 addr show wlan0 2>/dev/null | awk '/inet / {print $2}' | cut -d/ -f1 || echo "YOUR-PHONE-IP")

echo "✅ VS Code Server (proot) installed with R, Python, and HTTPS support"
echo ""
echo "========================================="
echo "Quick Start:"
echo "========================================="
echo ""
echo "Start server:"
echo "  vscode-server-proot-start"
echo ""
echo "Stop server:"
echo "  vscode-server-proot-stop"
echo ""
echo "========================================="
echo "Access Methods:"
echo "========================================="
echo ""
echo "📱 Phone / Laptop (ADB):"
echo "   http://127.0.0.1:13338"
echo "   (Run: adb forward tcp:13338 tcp:13338)"
echo "   ✅ All features work via localhost"
echo ""
echo "💻 Laptop (LAN) - HTTP:"
echo "   http://$PHONE_IP:13338"
echo "   ⚠️  Limited: webviews/clipboard don't work"
echo ""
echo "💻 Laptop (LAN) - HTTPS:"
echo "   https://$PHONE_IP:13338"
echo "   ✅ Full features! (requires certificate setup)"
echo ""
echo "========================================="
echo "First Time HTTPS Setup (one-time):"
echo "========================================="
echo ""
echo "1. Run: cert-server-proot"
echo "2. Open on laptop: http://$PHONE_IP:8889/setup"
echo "3. Follow installation instructions"
echo "4. Restart vscode-server-proot-start"
echo "5. Access: https://$PHONE_IP:13338"
echo ""
echo "========================================="
echo "Languages configured:"
echo "========================================="
echo ""
echo "  - R (radian console, httpgd plots, Shiny with F5)"
echo "  - Python (Ctrl+Enter to run code)"
echo ""
echo "💡 Tips:"
echo "  - Browser zoom: Ctrl+/- or pinch gesture"
echo "  - Python terminal: Open .py → Ctrl+Enter"
echo "  - R terminal: Ctrl+Shift+P → 'R: Create R Terminal'"