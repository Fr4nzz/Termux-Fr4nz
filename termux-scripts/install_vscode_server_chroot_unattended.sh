#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail
: "${PREFIX:=/data/data/com.termux/files/usr}"

# Install code-server inside the chroot (includes R, Python, and HTTPS setup)
# Now uses default shell (zsh if installed, bash otherwise)
curl -fsSL https://raw.githubusercontent.com/Fr4nzz/Termux-Fr4nz/refs/heads/main/container-scripts/install_vscode_server.sh \
  | ubuntu-chroot

# Create Termux wrappers
mkdir -p "$PREFIX/bin"

cat >"$PREFIX/bin/vscode-server-chroot-start" <<'SH'
#!/data/data/com.termux/files/usr/bin/sh
set -e

# Get default shell for root
DEFAULT_SHELL=$(ubuntu-chroot /bin/sh -c "getent passwd root | cut -d: -f7")
[ -z "$DEFAULT_SHELL" ] && DEFAULT_SHELL="/bin/bash"

exec ubuntu-chroot "$DEFAULT_SHELL" -lc '
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
export HOME=/root

# Ensure mounts
sudo mountpoint -q /proc || sudo mount -t proc proc /proc
sudo mountpoint -q /sys || sudo mount -t sysfs sys /sys

mkdir -p /dev/pts /dev/shm /run
sudo mountpoint -q /dev/pts || sudo mount -t devpts devpts /dev/pts
sudo mountpoint -q /dev/shm || sudo mount -t tmpfs -o size=256M tmpfs /dev/shm

# Check if HTTPS certificates exist
if [ -f /opt/code-server-certs/cert.pem ]; then
  exec code-server-https 13338
else
  echo "⚠️  HTTPS certificates not found, starting HTTP only"
  echo "Run cert-server-chroot to set up HTTPS"
  exec code-server-local 13338
fi
'
SH
chmod 0755 "$PREFIX/bin/vscode-server-chroot-start"

cat >"$PREFIX/bin/vscode-server-chroot-stop" <<'SH'
#!/data/data/com.termux/files/usr/bin/sh
ubuntu-chroot 'code-server-stop'
SH
chmod 0755 "$PREFIX/bin/vscode-server-chroot-stop"

cat >"$PREFIX/bin/cert-server-chroot" <<'SH'
#!/data/data/com.termux/files/usr/bin/sh
set -e

# Get default shell for root
DEFAULT_SHELL=$(ubuntu-chroot /bin/sh -c "getent passwd root | cut -d: -f7")
[ -z "$DEFAULT_SHELL" ] && DEFAULT_SHELL="/bin/bash"

exec ubuntu-chroot "$DEFAULT_SHELL" -lc '
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
export HOME=/root

exec cert-server 8889
'
SH
chmod 0755 "$PREFIX/bin/cert-server-chroot"

# Get phone IP for display
PHONE_IP="$(phone-ip)"

echo "✅ VS Code Server installed with R, Python, and HTTPS support"
echo ""
echo "========================================="
echo "Quick Start:"
echo "========================================="
echo ""
echo "Start server:"
echo "  vscode-server-chroot-start"
echo ""
echo "Stop server:"
echo "  vscode-server-chroot-stop"
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
echo "1. Run: cert-server-chroot"
echo "2. Open on laptop: http://$PHONE_IP:8889/setup"
echo "3. Follow installation instructions"
echo "4. Restart vscode-server-chroot-start"
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
