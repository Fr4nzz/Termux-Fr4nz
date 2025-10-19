#!/data/data/com.termux/files/usr/bin/bash
# Termux-Fr4nz: zsh bootstrap
# - Installs zsh + git
# - Installs basic zsh plugins + writes a minimal zshrc (with tsu->zsh wrapper)
# - Makes zsh the default shell via chsh + termux-reload-settings

set -euo pipefail

echo "[1/5] Updating packages…"
pkg update -y >/dev/null
pkg upgrade -y || true

echo "[2/5] Installing zsh + git…"
pkg install -y zsh git >/dev/null

echo "[3/5] Installing zsh plugins (no checks/backups) and writing ~/.zshrc…"
PLUGDIR="$HOME/.local/share/zsh/plugins"
rm -rf "$PLUGDIR"
mkdir -p "$PLUGDIR"
git clone --depth=1 https://github.com/zsh-users/zsh-autosuggestions "$PLUGDIR/zsh-autosuggestions" >/dev/null
git clone --depth=1 https://github.com/zsh-users/zsh-syntax-highlighting "$PLUGDIR/zsh-syntax-highlighting" >/dev/null

cat > "$HOME/.zshrc" <<'ZRC'
# Prefer $ZDOTDIR (if set), else HOME; fall back to user path if root HOME lacks plugins
plugdir="${ZDOTDIR:-$HOME}/.local/share/zsh/plugins"
[ -d "$plugdir" ] || plugdir="/data/data/com.termux/files/home/.local/share/zsh/plugins"

source "$plugdir/zsh-autosuggestions/zsh-autosuggestions.zsh"
source "$plugdir/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"

# Treat '#' as comments in interactive shells
setopt interactive_comments

# Always start zsh when using tsu (Option 1)
# Uses absolute Termux paths so it works reliably under tsu
tsu () {
  local P=/data/data/com.termux/files/usr
  command "$P/bin/tsu" -s "$P/bin/zsh" "$@"
}
ZRC

echo "[4/5] Let root share your zsh config for tsu sessions…"
mkdir -p "$HOME/.suroot"
ln -sf "$HOME/.zshrc" "$HOME/.suroot/.zshrc"

echo "[5/5] Making zsh your default shell…"
chsh -s zsh
termux-reload-settings || true

cat <<'NOTE'

✅ zsh is ready!

- Open a new Termux session: you’ll land in zsh with autosuggestions + syntax highlighting.
- Run `tsu`: you’ll get **zsh as root**; it loads the same config.
- One-liners: `tsu -s /data/.../zsh -- -lc 'echo hi'` (note the `--` separator).

NOTE

exec zsh
