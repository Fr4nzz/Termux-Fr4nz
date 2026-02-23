#!/usr/bin/env bash
# Install claude-telegram-bot inside an Ubuntu container (chroot or proot).
# https://github.com/linuz90/claude-telegram-bot
# Creates a dedicated 'claude' user (Claude CLI refuses --dangerously-skip-permissions as root).

set -euo pipefail
export DEBIAN_FRONTEND=noninteractive

BOT_USER="claude"
INSTALL_DIR="/opt/claude-telegram-bot"

say(){ printf "\n[%s] %s\n" "$1" "$2"; }

say "1/5" "Install dependencies..."
apt-get update -qq
apt-get install -y -qq curl ca-certificates unzip git nodejs npm sudo

say "2/5" "Create '$BOT_USER' user..."
if id "$BOT_USER" &>/dev/null; then
  echo "  User '$BOT_USER' already exists."
else
  useradd -m -s /bin/bash "$BOT_USER"
  echo "  User '$BOT_USER' created."
fi

say "3/5" "Install Bun runtime (as $BOT_USER)..."
sudo -u "$BOT_USER" bash -c '
  if command -v bun >/dev/null 2>&1; then
    echo "  Bun already installed: $(bun --version)"
  else
    curl -fsSL https://bun.sh/install | bash
    export BUN_INSTALL="$HOME/.bun"
    export PATH="$BUN_INSTALL/bin:$PATH"
    echo "  Bun installed: $(bun --version)"
  fi
'

say "4/5" "Install Claude CLI (as $BOT_USER)..."
sudo -u "$BOT_USER" bash -c '
  export BUN_INSTALL="$HOME/.bun"
  export PATH="$HOME/.npm-global/bin:$HOME/.local/bin:$BUN_INSTALL/bin:/usr/local/bin:/usr/bin:/bin"
  if command -v claude >/dev/null 2>&1; then
    echo "  Claude CLI already installed."
  else
    mkdir -p ~/.npm-global
    npm config set prefix ~/.npm-global
    npm install -g @anthropic-ai/claude-code
    export PATH="$HOME/.npm-global/bin:$PATH"
    claude install 2>/dev/null || true
    echo "  Claude CLI installed."
  fi
'

say "5/5" "Clone and set up claude-telegram-bot..."
if [ -d "$INSTALL_DIR" ]; then
  echo "  Updating existing installation..."
  cd "$INSTALL_DIR"
  git pull --ff-only 2>/dev/null || true
else
  git clone https://github.com/linuz90/claude-telegram-bot.git "$INSTALL_DIR"
fi

chown -R "$BOT_USER":"$BOT_USER" "$INSTALL_DIR"

sudo -u "$BOT_USER" bash -c "
  export BUN_INSTALL=\"\$HOME/.bun\"
  export PATH=\"\$BUN_INSTALL/bin:\$PATH\"
  cd $INSTALL_DIR
  bun install
"

# Ensure bun and claude are on PATH in future shells
# Add to .profile (login shells, including su - claude -c '...')
# and .bashrc (interactive shells)
PATH_BLOCK='
# Bun + Claude
export BUN_INSTALL="$HOME/.bun"
export PATH="$HOME/.npm-global/bin:$HOME/.local/bin:$BUN_INSTALL/bin:$PATH"'

for rc in "/home/$BOT_USER/.profile" "/home/$BOT_USER/.bashrc"; do
  if ! grep -q 'BUN_INSTALL' "$rc" 2>/dev/null; then
    echo "$PATH_BLOCK" >> "$rc"
    chown "$BOT_USER":"$BOT_USER" "$rc"
  fi
done

# Pre-create /tmp/telegram-bot owned by claude (bot writes .keep at startup)
mkdir -p /tmp/telegram-bot
chown "$BOT_USER":"$BOT_USER" /tmp/telegram-bot

# Symlink sdcard into claude's home so Claude Code can access phone files
ln -sfn /mnt/sdcard "/home/$BOT_USER/sdcard"

echo ""
echo "claude-telegram-bot installed at $INSTALL_DIR"
echo "Running as user: $BOT_USER"
echo ""
echo "Next steps:"
echo ""
echo "  1. Authenticate Claude CLI (as $BOT_USER):"
echo "     su - $BOT_USER -c 'claude auth login'"
echo ""
echo "  2. Configure .env (create $INSTALL_DIR/.env):"
echo "     TELEGRAM_BOT_TOKEN=your_bot_token"
echo "     TELEGRAM_ALLOWED_USERS=your_telegram_user_id"
echo "     CLAUDE_MODEL=claude-sonnet-4-5"
echo ""
echo "  3. Start the bot:"
echo "     su - $BOT_USER -c 'cd $INSTALL_DIR && bun run src/index.ts'"
echo ""
