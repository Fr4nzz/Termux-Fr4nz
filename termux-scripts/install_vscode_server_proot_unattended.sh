#!/data/data/com.termux/files/usr/bin/bash
set -eu
( set -o pipefail ) 2>/dev/null && set -o pipefail
: "${PREFIX:=/data/data/com.termux/files/usr}"

# Install code-server inside the container
curl -fsSL https://raw.githubusercontent.com/Fr4nzz/Termux-Fr4nz/refs/heads/main/container-scripts/install_vscode_server.sh \
  | ubuntu-proot

mkdir -p "$PREFIX/bin"

cat >"$PREFIX/bin/vscode-server-proot-start" <<'SH'
#!/data/data/com.termux/files/usr/bin/sh
set -e

# Check if HTTPS certs exist
if ubuntu-proot test -f /opt/code-server-certs/cert.pem; then
  LAUNCHER="code-server-https"
  PROTOCOL="https"
else
  LAUNCHER="code-server-local"
  PROTOCOL="http"
fi

PHONE_IP="$(phone-ip 2>/dev/null || echo '(unknown)')"

echo "========================================="
echo "VS Code Server (proot)"
echo "========================================="
echo ""
echo "Local:  $PROTOCOL://127.0.0.1:13338"
echo "LAN:    $PROTOCOL://$PHONE_IP:13338"
echo ""
if [ "$PROTOCOL" = "https" ]; then
  echo "✅ HTTPS enabled"
else
  echo "⚠️  HTTP mode - for HTTPS: cert-server-proot"
fi
echo ""
echo "Press Ctrl+C to stop"
echo "========================================="
echo ""

# Run in foreground
exec ubuntu-proot "$LAUNCHER"
SH
chmod 0755 "$PREFIX/bin/vscode-server-proot-start"

cat >"$PREFIX/bin/cert-server-proot" <<'SH'
#!/data/data/com.termux/files/usr/bin/sh
exec ubuntu-proot cert-server 8889
SH
chmod 0755 "$PREFIX/bin/cert-server-proot"

PHONE_IP="$(phone-ip)"
echo "✅ VS Code Server (proot) installed"
echo ""
echo "Start: vscode-server-proot-start"
echo "Stop:  Ctrl+C"
echo ""
echo "Access: http://127.0.0.1:13338 or http://$PHONE_IP:13338"
echo "HTTPS:  cert-server-proot (one-time setup)"