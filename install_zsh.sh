#!/data/data/com.termux/files/usr/bin/bash
# Termux + Oh My Zsh (robust under tsu; unattended; Termux/SSH-friendly)

set -euo pipefail
say(){ printf "\n[%s] %s\n" "$1" "$2"; }

say "1/5" "Update & install base packages…"
pkg update -y >/dev/null
pkg upgrade -y || true
pkg install -y zsh git curl fzf tsu >/dev/null

say "2/5" "Install Oh My Zsh (unattended)…"
export RUNZSH=no CHSH=no
sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended

say "3/5" "Add OMZ custom plugins (autosuggestions + syntax-highlighting)…"
ZSH_CUSTOM="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"
rm -rf "$ZSH_CUSTOM/plugins/zsh-autosuggestions" \
       "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting"
git clone --depth=1 https://github.com/zsh-users/zsh-autosuggestions \
  "$ZSH_CUSTOM/plugins/zsh-autosuggestions" >/dev/null
git clone --depth=1 https://github.com/zsh-users/zsh-syntax-highlighting \
  "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting" >/dev/null

say "4/5" "Write ~/.zshrc (robust OMZ path + keybindings)…"
cat > "$HOME/.zshrc" <<'ZRC'
# ----- Oh My Zsh base (robust under tsu) -----
# Prefer $HOME/.oh-my-zsh; if not present (e.g., HOME=.suroot under tsu),
# fall back to the *real* Termux home derived from $PREFIX (/data/.../files/home).
# This avoids /data/.../.suroot/.oh-my-zsh lookups.
_termux_home="${PREFIX%/usr}/home"
if [[ -d "$HOME/.oh-my-zsh" ]]; then
  export ZSH="$HOME/.oh-my-zsh"
elif [[ -d "$_termux_home/.oh-my-zsh" ]]; then
  export ZSH="$_termux_home/.oh-my-zsh"
fi

plugins=(git z sudo history-substring-search fzf zsh-autosuggestions zsh-syntax-highlighting)
ZSH_THEME="robbyrussell"
source "$ZSH/oh-my-zsh.sh"

# ----- Editing, completion, history -----
bindkey -e
autoload -Uz compinit && compinit -i
autoload -U select-word-style; select-word-style bash
HISTFILE=$HOME/.zsh_history; HISTSIZE=50000; SAVEHIST=50000
setopt interactive_comments hist_ignore_dups share_history

# ----- Termux/SSH-friendly keybindings (no prompts) -----
# 1) Prefer terminfo
[[ -n ${terminfo[khome]} ]] && { bindkey -M emacs "${terminfo[khome]}" beginning-of-line; bindkey -M viins "${terminfo[khome]}" beginning-of-line; }
[[ -n ${terminfo[kend]}  ]] && { bindkey -M emacs "${terminfo[kend]}"  end-of-line;      bindkey -M viins "${terminfo[kend]}"  end-of-line; }

# ----- tsu wrapper: root zsh with same config -----
# Always use absolute path so it works even if PATH differs under tsu.
tsu(){ command /data/data/com.termux/files/usr/bin/tsu -s zsh "$@"; }
ZRC

say "5/5" "Make zsh default, share config with root, finalize…"
mkdir -p "$HOME/.suroot"
ln -sf "$HOME/.zshrc" "$HOME/.suroot/.zshrc"
chsh -s zsh
termux-reload-settings || true

cat <<'NOTE'

✅ Done: OMZ + plugins + robust tsu setup
- Root (`tsu`) now sources OMZ from the *real* Termux home if HOME=.suroot.
- Keys fixed non-interactively (Home/End, Ctrl←/→).
- Change theme/plugins: edit ~/.zshrc; then `exec zsh`.

NOTE

exec zsh
