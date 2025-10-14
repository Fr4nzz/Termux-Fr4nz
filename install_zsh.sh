#!/data/data/com.termux/files/usr/bin/bash
# Termux-Fr4nz: zsh bootstrap
# - Installs zsh + git
# - Installs basic zsh plugins + writes a minimal zshrc
# - Makes zsh the default shell via chsh + termux-reload-settings

set -euo pipefail

echo "[1/4] Updating packages…"
pkg update -y >/dev/null
pkg upgrade -y || true

echo "[2/4] Installing zsh + git…"
pkg install -y zsh git >/dev/null

echo "[3/4] Installing zsh plugins (no checks/backups) and writing ~/.zshrc…"
PLUGDIR="$HOME/.local/share/zsh/plugins"
rm -rf "$PLUGDIR"
mkdir -p "$PLUGDIR"
git clone --depth=1 https://github.com/zsh-users/zsh-autosuggestions "$PLUGDIR/zsh-autosuggestions" >/dev/null
git clone --depth=1 https://github.com/zsh-users/zsh-syntax-highlighting "$PLUGDIR/zsh-syntax-highlighting" >/dev/null

cat > "$HOME/.zshrc" <<'ZRC'
plugdir="$HOME/.local/share/zsh/plugins"
source "$plugdir/zsh-autosuggestions/zsh-autosuggestions.zsh"
source "$plugdir/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"
ZRC

echo "[4/4] Making zsh your default shell…"
chsh -s zsh
termux-reload-settings || true

cat <<'NOTE'

✅ zsh is ready!

Open a new Termux session and you should land in zsh with autosuggestions + syntax highlighting.

NOTE
exec zsh