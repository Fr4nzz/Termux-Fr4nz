#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail
: "${PREFIX:=/data/data/com.termux/files/usr}"

# Ensure ubuntu-chroot wrapper exists (rooted container)
if ! command -v ubuntu-chroot >/dev/null 2>&1; then
  echo "[*] ubuntu-chroot not found. Setting up rooted Ubuntu container..."
  curl -fsSL https://raw.githubusercontent.com/Fr4nzz/Termux-Fr4nz/refs/heads/main/termux-scripts/setup_rooted_container_unattended.sh | bash
  echo "[*] Rooted container setup complete."
fi

# Install ZeroClaw inside the chroot
curl -fsSL https://raw.githubusercontent.com/Fr4nzz/Termux-Fr4nz/refs/heads/main/container-scripts/install_zeroclaw.sh \
  | ubuntu-chroot

mkdir -p "$PREFIX/bin"

# Convenience wrapper: run any zeroclaw command inside chroot
cat >"$PREFIX/bin/zeroclaw-chroot" <<'SH'
#!/data/data/com.termux/files/usr/bin/sh
exec ubuntu-chroot zeroclaw "$@"
SH
chmod 0755 "$PREFIX/bin/zeroclaw-chroot"

# Daemon wrapper: start ZeroClaw as foreground service (Telegram, heartbeat, etc.)
cat >"$PREFIX/bin/zeroclaw-chroot-daemon" <<'SH'
#!/data/data/com.termux/files/usr/bin/sh
PHONE_IP="$(phone-ip 2>/dev/null || echo '(unknown)')"
echo "========================================="
echo "ZeroClaw daemon (chroot)"
echo "========================================="
echo ""
echo "Gateway: http://$PHONE_IP:42617"
echo "Press Ctrl+C to stop"
echo "========================================="
echo ""
exec ubuntu-chroot zeroclaw daemon
SH
chmod 0755 "$PREFIX/bin/zeroclaw-chroot-daemon"

PHONE_IP="$(phone-ip 2>/dev/null || echo '(unknown)')"
echo ""
echo "ZeroClaw installed in chroot container."
echo ""
echo "Quick start (choose one):"
echo ""
echo "  Option A — API key:"
echo "    zeroclaw-chroot onboard --api-key sk-... --provider openai"
echo ""
echo "  Option B — ChatGPT OAuth (no API key needed):"
echo "    zeroclaw-chroot onboard --provider openai-codex"
echo "    zeroclaw-chroot auth login --provider openai-codex"
echo "    # Open the URL in a browser, log in, then paste the redirect URL:"
echo "    zeroclaw-chroot auth paste-redirect --provider openai-codex --input 'REDIRECT_URL'"
echo ""
echo "Telegram bot (optional):"
echo "  1. Get a bot token from @BotFather on Telegram"
echo "  2. zeroclaw-chroot channel add telegram '{\"bot_token\":\"YOUR_TOKEN\",\"name\":\"my-bot\"}'"
echo "  3. zeroclaw-chroot-daemon   # start daemon, note the bind code"
echo "  4. Send /bind <code> to your bot in Telegram"
echo ""
echo "Run:"
echo "  zeroclaw-chroot agent              # interactive chat"
echo "  zeroclaw-chroot-daemon             # background service"
echo ""
