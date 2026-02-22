#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail
: "${PREFIX:=/data/data/com.termux/files/usr}"

RUNTIME="proot"
C="${CONTAINER:-$HOME/containers/ubuntu-proot}"
REPO_RAW="https://raw.githubusercontent.com/Fr4nzz/Termux-Fr4nz/refs/heads/main"

# Source shared library (local checkout or remote)
_dir="$(cd "$(dirname "$0")" 2>/dev/null && pwd)" || _dir=""
if [ -f "$_dir/container_setup_common.sh" ]; then
  . "$_dir/container_setup_common.sh"
else
  _common=$(mktemp)
  curl -fsSL "$REPO_RAW/termux-scripts/container_setup_common.sh" -o "$_common"
  . "$_common"; rm -f "$_common"
fi

ask_prompts

pkg update -y >/dev/null || true
pkg install -y proot python >/dev/null

# Container runner for proot (no X11/sdcard binds needed during setup)
crun() {
  proot-run -r "$C" \
    /usr/bin/env -i HOME=/root TERM=xterm-256color \
    PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin \
    "$@"
}

# Install proot-run wrapper (replaces deprecated daijin)
if ! command -v proot-run >/dev/null 2>&1; then
  echo "[rootless] Installing proot-run wrapper..."
  curl -fsSL "$REPO_RAW/termux-scripts/proot_run.sh" -o "$PREFIX/bin/proot-run"
  chmod 0755 "$PREFIX/bin/proot-run"
fi

ensure_rurima

# Pull Ubuntu rootfs
mkdir -p "$(dirname "$C")"
[ -d "$C" ] || rurima lxc pull -o ubuntu -v noble -s "$C"

# ── Container provisioning (shared) ─────────────────────────────────────────
android_fixup
install_base_tools
install_maintainer_helpers
install_myip
create_desktop_user
install_zsh_autolaunch

# ── Termux wrapper scripts ──────────────────────────────────────────────────
TP="$PREFIX/tmp/.X11-unix"
mkdir -p "$TP" "$PREFIX/bin"

install_phone_ip

cat >"$PREFIX/bin/ubuntu-proot" <<'SH'
#!/data/data/com.termux/files/usr/bin/sh
: "${PREFIX:=/data/data/com.termux/files/usr}"
C="$HOME/containers/ubuntu-proot"
TP="$PREFIX/tmp/.X11-unix"; [ -d "$TP" ] || mkdir -p "$TP"

# Parse --user flag
U="root"
if [ "$1" = "--user" ]; then
  U="$2"
  shift 2
  [ "$#" -gt 0 ] && echo "Warning: --user only works for interactive mode" >&2 && U="root"
fi

# Clear problematic environment variables
unset SHELL ZDOTDIR ZSH OH_MY_ZSH

BIND="-b $TP:/tmp/.X11-unix -b /sdcard:/mnt/sdcard"

# Piped input check FIRST
if [ ! -t 0 ]; then
  exec proot-run -r "$C" -e "$BIND" \
    /usr/bin/env -i \
      HOME=/root \
      TERM="${TERM:-xterm-256color}" \
      PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin \
      "${@:-/bin/bash}"
fi

# No args -> interactive
[ "$#" -eq 0 ] && exec proot-run -r "$C" -e "$BIND" /bin/su - "$U"

# Command - use simple env approach
exec proot-run -r "$C" -e "$BIND" \
  /usr/bin/env PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin HOME=/root \
  "$@"
SH
chmod 0755 "$PREFIX/bin/ubuntu-proot"

cat >"$PREFIX/bin/ubuntu-proot-u" <<'SH'
#!/data/data/com.termux/files/usr/bin/sh
C="$HOME/containers/ubuntu-proot"
pkill -f "proot .*${C}" || true
SH
chmod 0755 "$PREFIX/bin/ubuntu-proot-u"

install_zsh_in_container ubuntu-proot

echo ""
echo "Rootless container ready. Enter with: ubuntu-proot"
echo ""
