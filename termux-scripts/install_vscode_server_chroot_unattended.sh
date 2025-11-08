#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail
: "${PREFIX:=/data/data/com.termux/files/usr}"

# Install code-server inside the chroot
curl -fsSL https://raw.githubusercontent.com/Fr4nzz/Termux-Fr4nz/refs/heads/main/container-scripts/install_vscode_server.sh \
  | ubuntu-chroot

mkdir -p "$PREFIX/bin"

cat >"$PREFIX/bin/vscode-server-chroot-start" <<'SH'
#!/data/data/com.termux/files/usr/bin/sh
set -e

# Check if HTTPS certs exist
if ubuntu-chroot test -f /opt/code-server-certs/cert.pem; then
  LAUNCHER="code-server-https"
  PROTOCOL="https"
else
  LAUNCHER="code-server-local"
  PROTOCOL="http"
fi

PHONE_IP="$(phone-ip 2>/dev/null || echo '(unknown)')"

echo "========================================="
echo "VS Code Server (chroot)"
echo "========================================="
echo ""
echo "Local:  $PROTOCOL://127.0.0.1:13338"
echo "LAN:    $PROTOCOL://$PHONE_IP:13338"
echo ""
if [ "$PROTOCOL" = "https" ]; then
  echo "✅ HTTPS enabled"
else
  echo "⚠️  HTTP mode - for HTTPS: cert-server-chroot"
fi
echo ""
echo "Press Ctrl+C to stop"
echo "========================================="
echo ""

# Run in foreground
exec ubuntu-chroot "$LAUNCHER"
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
echo "Start: vscode-server-chroot-start"
echo "Stop:  Ctrl+C"
echo ""
echo "Access: http://127.0.0.1:13338 or http://$PHONE_IP:13338"
echo "HTTPS:  cert-server-chroot (one-time setup)"