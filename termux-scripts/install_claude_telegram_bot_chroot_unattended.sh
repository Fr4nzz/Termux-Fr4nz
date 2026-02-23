#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail
: "${PREFIX:=/data/data/com.termux/files/usr}"

# Ensure ubuntu-chroot wrapper exists (rooted container)
if ! command -v ubuntu-chroot >/dev/null 2>&1; then
  echo "[*] ubuntu-chroot not found. Setting up rooted Ubuntu container..."
  curl -fsSL https://raw.githubusercontent.com/Fr4nzz/Termux-Fr4nz/refs/heads/main/termux-scripts/setup_rooted_container_unattended.sh | bash
  echo "[*] Rooted container setup complete."
fi

# Install claude-telegram-bot inside the chroot
curl -fsSL https://raw.githubusercontent.com/Fr4nzz/Termux-Fr4nz/refs/heads/main/container-scripts/install_claude_telegram_bot.sh \
  | ubuntu-chroot

# Write .env with user's Telegram config
ubuntu-chroot bash -c 'cat > /opt/claude-telegram-bot/.env && chown claude:claude /opt/claude-telegram-bot/.env' <<'ENV'
TELEGRAM_BOT_TOKEN=your_bot_token_here
TELEGRAM_ALLOWED_USERS=your_telegram_user_id
CLAUDE_MODEL=claude-sonnet-4-5
ENV

mkdir -p "$PREFIX/bin" "$PREFIX/var/run" "$PREFIX/var/log"

# claude-bot: start the Telegram bot as a background daemon
cat >"$PREFIX/bin/claude-bot" <<'SH'
#!/data/data/com.termux/files/usr/bin/sh
: "${PREFIX:=/data/data/com.termux/files/usr}"
PIDFILE="$PREFIX/var/run/claude-bot.pid"
LOGFILE="$PREFIX/var/log/claude-bot.log"

case "${1:-start}" in
  --off|stop)
    if [ -f "$PIDFILE" ]; then
      PID="$(cat "$PIDFILE")"
      if kill -0 "$PID" 2>/dev/null; then
        kill "$PID" 2>/dev/null || true
        sleep 1
        kill -9 "$PID" 2>/dev/null || true
        echo "Claude bot stopped (PID $PID)."
      else
        echo "Not running (stale pidfile)."
      fi
      rm -f "$PIDFILE"
    else
      echo "Claude bot is not running."
    fi
    ;;
  --status|status)
    if [ -f "$PIDFILE" ] && kill -0 "$(cat "$PIDFILE")" 2>/dev/null; then
      echo "Claude bot is running (PID $(cat "$PIDFILE"))."
    else
      rm -f "$PIDFILE" 2>/dev/null
      echo "Claude bot is not running."
    fi
    ;;
  --log|log|logs)
    if [ -f "$LOGFILE" ]; then
      tail -f "$LOGFILE"
    else
      echo "No log file yet."
    fi
    ;;
  *|start)
    if [ -f "$PIDFILE" ] && kill -0 "$(cat "$PIDFILE")" 2>/dev/null; then
      echo "Claude bot is already running (PID $(cat "$PIDFILE"))."
      exit 0
    fi
    mkdir -p "$(dirname "$PIDFILE")" "$(dirname "$LOGFILE")"
    ubuntu-chroot su - claude -c '
      export BUN_INSTALL="$HOME/.bun"
      export PATH="$HOME/.local/bin:$BUN_INSTALL/bin:/usr/local/bin:/usr/bin:/bin"
      cd /opt/claude-telegram-bot
      exec bun run src/index.ts
    ' >"$LOGFILE" 2>&1 &
    echo "$!" >"$PIDFILE"
    echo "Claude bot started (PID $!)."
    echo "Logs: $LOGFILE"
    echo "Stop with: claude-bot --off"
    ;;
esac
SH
chmod 0755 "$PREFIX/bin/claude-bot"

echo ""
echo "claude-telegram-bot installed in chroot container."
echo ""
echo "Before first use, authenticate Claude CLI (as 'claude' user):"
echo "  ubuntu-chroot su - claude -c 'claude auth login'"
echo ""
echo "Commands:"
echo "  claude-bot            # start bot daemon"
echo "  claude-bot --off      # stop bot daemon"
echo "  claude-bot --status   # check if running"
echo "  claude-bot --log      # tail the log"
echo ""
