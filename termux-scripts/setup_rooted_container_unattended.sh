#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail
: "${PREFIX:=/data/data/com.termux/files/usr}"

RUNTIME="chroot"
C="${CONTAINER:-$HOME/containers/ubuntu-chroot}"
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
pkg install -y tsu python >/dev/null

# Pre-create tsu state dir so it's owned by the Termux user, not root
mkdir -p "$HOME/.suroot" 2>/dev/null || true

# Container runner for chroot (via rurima/ruri)
crun() {
  sudo rurima r "$C" \
    /usr/bin/env -i HOME=/root TERM=xterm-256color \
    PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin \
    "$@"
}

ensure_rurima

# Pull Ubuntu rootfs
mkdir -p "$(dirname "$C")"
[ -d "$C" ] || sudo rurima lxc pull -o ubuntu -v noble -s "$C"

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

cat >"$PREFIX/bin/ubuntu-chroot" <<'SH'
#!/data/data/com.termux/files/usr/bin/sh
: "${PREFIX:=/data/data/com.termux/files/usr}"
C="$HOME/containers/ubuntu-chroot"
TP="$PREFIX/tmp/.X11-unix"; [ -d "$TP" ] || mkdir -p "$TP"

# Bind-mount sdcard into container rootfs (persists on host, survives chroot re-entry).
# /sdcard is FUSE which rurima can't bind-mount; use the f2fs pass-through path.
SDMNT="$C/mnt/sdcard"
sudo mkdir -p "$SDMNT" 2>/dev/null
sudo mountpoint -q "$SDMNT" 2>/dev/null || \
  sudo mount --bind /mnt/pass_through/0/emulated/0 "$SDMNT" 2>/dev/null || true

# Parse --user flag
U="root"
if [ "$1" = "--user" ]; then
  U="$2"
  shift 2
  [ "$#" -gt 0 ] && echo "Warning: --user only works for interactive mode" >&2 && U="root"
fi

# Clear problematic environment variables
unset SHELL ZDOTDIR ZSH OH_MY_ZSH

# Piped input check FIRST
if [ ! -t 0 ]; then
  exec sudo rurima r \
    -m "$TP" /tmp/.X11-unix \
    "$C" /usr/bin/env -i \
      HOME=/root \
      TERM="${TERM:-xterm-256color}" \
      PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin \
      "${@:-/bin/bash}"
fi

# No args -> interactive (bash, .bashrc auto-launches zsh)
[ "$#" -eq 0 ] && exec sudo rurima r \
  -m "$TP" /tmp/.X11-unix \
  "$C" /bin/su - "$U" -s /bin/bash

# Command - use simple env approach
exec sudo rurima r \
  -m "$TP" /tmp/.X11-unix \
  "$C" /usr/bin/env PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin HOME=/root \
  "$@"
SH
chmod 0755 "$PREFIX/bin/ubuntu-chroot"

cat >"$PREFIX/bin/ubuntu-chroot-u" <<'SH'
#!/data/data/com.termux/files/usr/bin/sh
C="$HOME/containers/ubuntu-chroot"
exec sudo rurima r -U "$C"
SH
chmod 0755 "$PREFIX/bin/ubuntu-chroot-u"

install_zsh_in_container ubuntu-chroot

echo ""
echo "Rooted container ready. Enter with: ubuntu-chroot"
echo ""
