#!/usr/bin/env bash
# Ubuntu container + Oh My Zsh setup (minimal)

set -euo pipefail
export DEBIAN_FRONTEND=noninteractive

say(){ printf "\n[%s] %s\n" "$1" "$2"; }

say "1/4" "Update & install packages..."
apt-get update -qq
apt-get install -y --no-install-recommends zsh git curl fzf

say "2/4" "Install Oh My Zsh for root..."
export HOME=/root RUNZSH=no CHSH=no
sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended

say "3/4" "Add plugins (autosuggestions + syntax-highlighting)..."
ZSH_CUSTOM="/root/.oh-my-zsh/custom"

rm -rf "$ZSH_CUSTOM/plugins/zsh-autosuggestions" \
       "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting"

git clone --depth=1 https://github.com/zsh-users/zsh-autosuggestions \
  "$ZSH_CUSTOM/plugins/zsh-autosuggestions" >/dev/null
git clone --depth=1 https://github.com/zsh-users/zsh-syntax-highlighting \
  "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting" >/dev/null

say "4/4" "Configure and set as default shell..."
cat > /root/.zshrc <<'ZRC'
export ZSH="$HOME/.oh-my-zsh"

# Minimal plugins for speed
plugins=(git fzf zsh-autosuggestions zsh-syntax-highlighting)

# Different theme from Termux (agnoster has nice colors)
ZSH_THEME="agnoster"

source "$ZSH/oh-my-zsh.sh"

# PATH for local binaries
export PATH="$HOME/.local/bin:$PATH"

# Common aliases
alias ll='ls -lah'
alias la='ls -A'
alias l='ls -CF'
ZRC

chsh -s "$(which zsh)" root 2>/dev/null || true

# Also setup for desktop user if exists
TARGET_USER="$(cat /etc/ruri/user 2>/dev/null || echo '')"
if [ -n "$TARGET_USER" ] && [ "$TARGET_USER" != "root" ]; then
  say "4.5/4" "Also setting up zsh for user $TARGET_USER..."
  
  TARGET_HOME=$(getent passwd "$TARGET_USER" | cut -d: -f6)
  
  # Install OMZ for user
  sudo -u "$TARGET_USER" -H sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
  
  # Install plugins for user
  ZSH_CUSTOM="$TARGET_HOME/.oh-my-zsh/custom"
  rm -rf "$ZSH_CUSTOM/plugins/zsh-autosuggestions" \
         "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting"
  
  sudo -u "$TARGET_USER" git clone --depth=1 https://github.com/zsh-users/zsh-autosuggestions \
    "$ZSH_CUSTOM/plugins/zsh-autosuggestions" >/dev/null
  sudo -u "$TARGET_USER" git clone --depth=1 https://github.com/zsh-users/zsh-syntax-highlighting \
    "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting" >/dev/null
  
  # Copy zshrc to user (will use same theme)
  cp /root/.zshrc "$TARGET_HOME/.zshrc"
  chown "$TARGET_USER:$TARGET_USER" "$TARGET_HOME/.zshrc"
  chsh -s "$(which zsh)" "$TARGET_USER" 2>/dev/null || true
fi

echo ""
echo "✅ Zsh + Oh My Zsh installed"
echo ""
echo "Theme: agnoster (different from Termux)"
echo "Plugins: autosuggestions, syntax-highlighting, fzf, git"
echo ""
echo "To use: exec zsh"