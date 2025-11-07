#!/usr/bin/env bash
# Ubuntu container + Oh My Zsh setup (minimal)

set -euo pipefail
export DEBIAN_FRONTEND=noninteractive

say(){ printf "\n[%s] %s\n" "$1" "$2"; }

say "1/4" "Update & install packages..."
apt-get update -qq
apt-get install -y --no-install-recommends zsh git curl fzf

say "2/4" "Install Oh My Zsh..."
# Get the target user (saved during container setup, or default to root)
TARGET_USER="${1:-$(cat /etc/ruri/user 2>/dev/null || echo root)}"
TARGET_HOME=$(getent passwd "$TARGET_USER" | cut -d: -f6)

export RUNZSH=no CHSH=no

if [ "$TARGET_USER" = "root" ]; then
  sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
else
  sudo -u "$TARGET_USER" -H sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
fi

say "3/4" "Add plugins (autosuggestions + syntax-highlighting)..."
ZSH_CUSTOM="$TARGET_HOME/.oh-my-zsh/custom"

rm -rf "$ZSH_CUSTOM/plugins/zsh-autosuggestions" \
       "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting"

if [ "$TARGET_USER" = "root" ]; then
  git clone --depth=1 https://github.com/zsh-users/zsh-autosuggestions \
    "$ZSH_CUSTOM/plugins/zsh-autosuggestions" >/dev/null
  git clone --depth=1 https://github.com/zsh-users/zsh-syntax-highlighting \
    "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting" >/dev/null
else
  sudo -u "$TARGET_USER" git clone --depth=1 https://github.com/zsh-users/zsh-autosuggestions \
    "$ZSH_CUSTOM/plugins/zsh-autosuggestions" >/dev/null
  sudo -u "$TARGET_USER" git clone --depth=1 https://github.com/zsh-users/zsh-syntax-highlighting \
    "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting" >/dev/null
fi

say "4/4" "Configure and set as default shell..."
cat > "$TARGET_HOME/.zshrc" <<'ZRC'
export ZSH="$HOME/.oh-my-zsh"

plugins=(git z sudo fzf zsh-autosuggestions zsh-syntax-highlighting)
ZSH_THEME="robbyrussell"

source "$ZSH/oh-my-zsh.sh"

# PATH for local binaries
export PATH="$HOME/.local/bin:$PATH"

# Common aliases
alias ll='ls -lah'
alias la='ls -A'
alias l='ls -CF'
ZRC

chown "$TARGET_USER:$TARGET_USER" "$TARGET_HOME/.zshrc"
chsh -s "$(which zsh)" "$TARGET_USER" 2>/dev/null || true

# Also setup for root if we configured a different user
if [ "$TARGET_USER" != "root" ]; then
  export HOME=/root RUNZSH=no CHSH=no
  sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
  
  ZSH_CUSTOM="/root/.oh-my-zsh/custom"
  rm -rf "$ZSH_CUSTOM/plugins/zsh-autosuggestions" \
         "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting"
  git clone --depth=1 https://github.com/zsh-users/zsh-autosuggestions \
    "$ZSH_CUSTOM/plugins/zsh-autosuggestions" >/dev/null
  git clone --depth=1 https://github.com/zsh-users/zsh-syntax-highlighting \
    "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting" >/dev/null
  
  cp "$TARGET_HOME/.zshrc" /root/.zshrc
  chsh -s "$(which zsh)" root 2>/dev/null || true
fi

echo ""
echo "✅ Zsh + Oh My Zsh installed"
echo ""
echo "Plugins: autosuggestions, syntax-highlighting, fzf, git, z, sudo"
echo "To use: exec zsh"