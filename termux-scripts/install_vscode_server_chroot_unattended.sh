#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail
: "${PREFIX:=/data/data/com.termux/files/usr}"

# Ensure ubuntu-chroot wrapper exists (rooted container)
if ! command -v ubuntu-chroot >/dev/null 2>&1; then
  echo "[*] ubuntu-chroot not found. Setting up rooted Ubuntu container (requires sudo/tsu)..."
  curl -fsSL https://raw.githubusercontent.com/Fr4nzz/Termux-Fr4nz/refs/heads/main/termux-scripts/setup_rooted_container_unattended.sh | bash
  echo "[*] Rooted container setup complete."
fi

# Install code-server inside the chroot
curl -fsSL https://raw.githubusercontent.com/Fr4nzz/Termux-Fr4nz/refs/heads/main/container-scripts/install_vscode_server.sh \
  | ubuntu-chroot

mkdir -p "$PREFIX/bin"

cat >"$PREFIX/bin/vscode-server-chroot-start" <<'SH'
#!/data/data/com.termux/files/usr/bin/sh
set -e

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
  if ! ubuntu-chroot test -f /opt/code-server-certs/cert.pem; then
    echo "❌ HTTPS certificates not found."
    echo "Run: cert-server-chroot"
    exit 1
  fi
  
  PROTOCOL="https"
  echo "========================================="
  echo "VS Code Server (chroot) - HTTPS"
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
  echo "VS Code Server (chroot) - HTTP"
  echo "========================================="
  echo ""
  echo "🌐 HTTP mode:"
  echo "   http://127.0.0.1:13338"
  echo "   http://$PHONE_IP:13338"
  echo ""
  echo "💡 For HTTPS on LAN: vscode-server-chroot-start --https"
  echo ""
fi

echo "Press Ctrl+C to stop"
echo "========================================="
echo ""

# Run in foreground
exec ubuntu-chroot code-server-https $([ "$USE_HTTPS" = "true" ] && echo "--https")
SH
chmod 0755 "$PREFIX/bin/vscode-server-chroot-start"

cat >"$PREFIX/bin/cert-server-chroot" <<'SH'
#!/data/data/com.termux/files/usr/bin/sh
exec ubuntu-chroot cert-server 8889
SH
chmod 0755 "$PREFIX/bin/cert-server-chroot"

PHONE_IP="$(phone-ip)"
echo "✅ VS Code Server (chroot) installed"
echo ""
echo "Usage:"
echo "  vscode-server-chroot-start          # HTTP mode (default)"
echo "  vscode-server-chroot-start --https  # HTTPS mode (for LAN access)"
echo ""
echo "Setup HTTPS certificate (one-time):"
echo "  cert-server-chroot"
