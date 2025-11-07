#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail
: "${PREFIX:=/data/data/com.termux/files/usr}"
C="${CONTAINER:-$HOME/containers/ubuntu-chroot}"
U="${DESKTOP_USER:-}"

# Ask for desktop username (works even when piped: curl ... | bash)
if [ -z "$U" ]; then
  read -rp "Desktop username [legend]: " U </dev/tty || true
  U="${U:-legend}"
fi

# Ask about Zsh installation immediately after username
INSTALL_ZSH="${INSTALL_ZSH:-}"
if [ -z "$INSTALL_ZSH" ]; then
  read -rp "Install Zsh + Oh My Zsh in container? [Y/n]: " INSTALL_ZSH </dev/tty || true
  INSTALL_ZSH="${INSTALL_ZSH:-Y}"
fi

pkg update -y >/dev/null || true
pkg install -y tsu >/dev/null

# Ensure rurima is present (rooted uses rurima, but daijin is not needed here)
if ! command -v rurima >/dev/null 2>&1; then
  echo "[rooted] Installing rurima (required for pull)..."
  curl -fsSL https://raw.githubusercontent.com/Fr4nzz/Termux-Fr4nz/refs/heads/main/termux-scripts/install_rurima.sh | bash
fi

# Pull if missing (requires rurima)
mkdir -p "$(dirname "$C")"
[ -d "$C" ] || sudo rurima lxc pull -o ubuntu -v noble -s "$C"

# Fixup from daijin repo
curl -fsSL https://raw.githubusercontent.com/RuriOSS/daijin/refs/heads/main/src/share/fixup.sh \
  | sudo rurima r "$C" /bin/sh

# Base tools for container-scripts
sudo rurima r "$C" /bin/bash -lc '
  set -e
  export DEBIAN_FRONTEND=noninteractive
  apt-get update -y
  apt-get install -y curl ca-certificates gnupg wget
'

# Maintainer helpers (no --reinstall; just ensure present)
sudo rurima r "$C" /bin/bash -lc '
  set -e
  export DEBIAN_FRONTEND=noninteractive
  apt-get update -y
  apt-get install -y --no-install-recommends debconf
  apt-get install -y --no-install-recommends \
    debconf-i18n init-system-helpers perl-base adduser dialog locales tzdata \
    sgml-base xml-core
  dpkg --configure -a || true
  apt-get -o Dpkg::Options::="--force-confnew" -f install
'

# User + sudoers + remember + XDG runtime
sudo rurima r "$C" /bin/bash -lc "
  set -e

  # create the user inside the container
  /usr/sbin/adduser --disabled-password --gecos '' '$U' || true
  /usr/sbin/adduser '$U' sudo || true

  # passwordless sudo for that user
  /usr/bin/install -d -m0755 /etc/sudoers.d
  echo '$U ALL=(ALL) NOPASSWD: ALL' > /etc/sudoers.d/99-$U
  /bin/chmod 0440 /etc/sudoers.d/99-$U

  # remember the chosen desktop user
  /usr/bin/install -d -m0755 /etc/ruri
  printf '%s\n' '$U' > /etc/ruri/user

  # per-user runtime dir for XDG_RUNTIME_DIR, Termux:X11, etc
  /usr/bin/install -d -m0700 -o '$U' -g '$U' /home/'$U'/.run

  # set TERM defaults for root and that user
  echo 'export TERM=xterm-256color' >> /root/.bashrc
  /bin/su - '$U' -c \"echo 'export TERM=xterm-256color' >> ~/.bashrc\"
"

# Termux → chroot wrappers
TP="$PREFIX/tmp/.X11-unix"
mkdir -p "$TP" "$PREFIX/bin"

cat >"$PREFIX/bin/ubuntu-chroot" <<'SH'
#!/data/data/com.termux/files/usr/bin/sh
PREFIX="${PREFIX:-/data/data/com.termux/files/usr}"
C="${CONTAINER:-$HOME/containers/ubuntu-chroot}"
TP="$PREFIX/tmp/.X11-unix"
[ -d "$TP" ] || mkdir -p "$TP"

# Parse --user flag
U="root"  # default to root
if [ "$1" = "--user" ]; then
  U="$2"
  shift 2
fi

# No args → interactive login shell as user
if [ "$#" -eq 0 ]; then
  exec sudo rurima r \
    -m "$TP" /tmp/.X11-unix \
    -m /sdcard /mnt/sdcard \
    "$C" /bin/su - "$U"
fi

# Piped/redirected input → use default shell
if [ ! -t 0 ]; then
  # Allow user to specify shell, otherwise get default from /etc/passwd
  SHELL_BIN=""
  
  # Check if first argument is a shell specification
  case "$1" in
    /bin/sh|sh|/bin/bash|bash|/bin/zsh|zsh)
      case "$1" in
        /bin/sh|sh) SHELL_BIN="/bin/sh" ;;
        /bin/bash|bash) SHELL_BIN="/bin/bash" ;;
        /bin/zsh|zsh) SHELL_BIN="/bin/zsh" ;;
      esac
      shift
      ;;
  esac
  
  # If no shell specified, get default shell for user from container
  if [ -z "$SHELL_BIN" ]; then
    SHELL_BIN=$(sudo rurima r "$C" /bin/sh -c "getent passwd '$U' | cut -d: -f7")
    # Fallback to /bin/sh if empty or invalid
    [ -z "$SHELL_BIN" ] && SHELL_BIN="/bin/sh"
  fi
  
  # Handle -s flag (read from stdin) - consume it if present
  if [ "$1" = "-s" ]; then
    shift
  fi
  
  exec sudo rurima r \
    -m "$TP" /tmp/.X11-unix \
    -m /sdcard /mnt/sdcard \
    "$C" "$SHELL_BIN"
fi

# Run command as login shell
exec sudo rurima r \
  -m "$TP" /tmp/.X11-unix \
  -m /sdcard /mnt/sdcard \
  "$C" /bin/bash -lc "$*"
SH
chmod 0755 "$PREFIX/bin/ubuntu-chroot"

cat >"$PREFIX/bin/ubuntu-chroot-u" <<'SH'
#!/data/data/com.termux/files/usr/bin/sh
C="$HOME/containers/ubuntu-chroot"
exec sudo rurima r -U "$C"
SH
chmod 0755 "$PREFIX/bin/ubuntu-chroot-u"

echo "✅ Rooted container ready. Enter with: ubuntu-chroot"
echo ""

# Install Zsh based on earlier answer
case "$INSTALL_ZSH" in
  [Yy]*|"")
    echo "[*] Installing Zsh in container..."
    if curl -fsSL https://raw.githubusercontent.com/Fr4nzz/Termux-Fr4nz/refs/heads/main/container-scripts/install_zsh.sh \
      | ubuntu-chroot; then
      echo "✅ Zsh installed in container"
    else
      echo "⚠️  Zsh installation failed or skipped"
    fi
    ;;
  *)
    echo "Skipping Zsh installation"
    ;;
esac