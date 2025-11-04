#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail
: "${PREFIX:=/data/data/com.termux/files/usr}"

# Install code-server inside the chroot (includes R and Python setup)
curl -fsSL https://raw.githubusercontent.com/Fr4nzz/Termux-Fr4nz/refs/heads/main/container-scripts/install_vscode_server.sh \
  | ubuntu-chroot /bin/bash -s

# Create Termux wrappers
mkdir -p "$PREFIX/bin"

cat >"$PREFIX/bin/vscode-server-chroot-start" <<'SH'
#!/data/data/com.termux/files/usr/bin/sh
set -e

# Parse DPI argument
DPI_ARG=""
if [ "$1" = "--dpi" ] && [ -n "$2" ]; then
  DPI_ARG="--dpi $2"
fi

exec ubuntu-chroot "
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
export HOME=/root

# Ensure mounts
sudo mountpoint -q /proc || sudo mount -t proc proc /proc
sudo mountpoint -q /sys || sudo mount -t sysfs sys /sys

mkdir -p /dev/pts /dev/shm /run
sudo mountpoint -q /dev/pts || sudo mount -t devpts devpts /dev/pts
sudo mountpoint -q /dev/shm || sudo mount -t tmpfs -o size=256M tmpfs /dev/shm

exec code-server-local $DPI_ARG 13338
"
SH
chmod 0755 "$PREFIX/bin/vscode-server-chroot-start"

cat >"$PREFIX/bin/vscode-server-chroot-stop" <<'SH'
#!/data/data/com.termux/files/usr/bin/sh
ubuntu-chroot 'code-server-stop'
SH
chmod 0755 "$PREFIX/bin/vscode-server-chroot-stop"

echo "✅ VS Code Server installed with R and Python support"
echo ""
echo "Start: vscode-server-chroot-start [--dpi DPI]"
echo "Stop:  vscode-server-chroot-stop"
echo ""
echo "========================================="
echo "Access from:"
echo "========================================="
echo ""
echo "📱 Phone browser:"
echo "   http://127.0.0.1:13338"
echo ""
echo "💻 Laptop via ADB (recommended):"
echo "   adb forward tcp:13338 tcp:13338"
echo "   Then open: http://127.0.0.1:13338"
echo "   ✅ ChatGPT/Gemini/Clipboard work!"
echo ""
echo "💻 Laptop via LAN:"
echo "   http://$(termux-wifi-connectioninfo | grep -oP '(?<="ip":")[^"]*'):13338"
echo "   ⚠️  Basic editing works, webviews/clipboard don't"
echo ""
echo "========================================="
echo "DPI customization (for smaller UI on phone):"
echo "========================================="
echo ""
echo "  vscode-server-chroot-start --dpi 150  # Slightly smaller"
echo "  vscode-server-chroot-start --dpi 200  # Recommended for phones"
echo "  vscode-server-chroot-start --dpi 250  # Very compact"
echo ""
echo "Languages configured:"
echo "  - R (radian console, httpgd plots, Shiny apps with F5)"
echo "  - Python (Ctrl+Enter to run code)"