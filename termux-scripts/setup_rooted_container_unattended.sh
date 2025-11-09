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
pkg install -y tsu python >/dev/null

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
  apt-get install -y curl ca-certificates gnupg wget python3
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

# myip helper inside the chroot container (no root needed)
sudo rurima r "$C" /bin/bash -lc '
set -e
cat >/usr/local/bin/myip <<'"'"'PYSH'"'"'
#!/bin/sh
python3 - <<'PY'
import socket
s=socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
s.connect(("1.1.1.1",80))
print(s.getsockname()[0])
s.close()
PY
PYSH
chmod 0755 /usr/local/bin/myip
'

# User + sudoers + remember + XDG runtime + runtime tag
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
  printf '%s\n' chroot > /etc/ruri/runtime

  # per-user runtime dir for XDG_RUNTIME_DIR, Termux:X11, etc
  /usr/bin/install -d -m0700 -o '$U' -g '$U' /home/'$U'/.run

  # set TERM defaults for root and that user
  echo 'export TERM=xterm-256color' >> /root/.bashrc
  /bin/su - '$U' -c \"echo 'export TERM=xterm-256color' >> ~/.bashrc\"
"

# Auto-launch zsh workaround for chroot TTY issues (works for both zsh and non-zsh users)
sudo rurima r "$C" /bin/bash -lc '
  # Add auto-launcher for root
  cat >> /root/.bashrc <<'"'"'ZSHFIX'"'"'

# Chroot workaround: auto-launch zsh if it'"'"'s the login shell
if [ -z "$ZSH_LAUNCHED" ] && [ -t 0 ]; then
  REAL_SHELL=$(getent passwd "$(whoami)" | cut -d: -f7)
  if echo "$REAL_SHELL" | grep -q zsh && [ -x "$REAL_SHELL" ]; then
    export ZSH_LAUNCHED=1
    exec "$REAL_SHELL" -l
  fi
fi
ZSHFIX
'

sudo rurima r "$C" /bin/bash -lc "
  # Add auto-launcher for desktop user
  su - '$U' -c 'cat >> ~/.bashrc <<ZSHFIX

# Chroot workaround: auto-launch zsh if it\047s the login shell
if [ -z \"\\\$ZSH_LAUNCHED\" ] && [ -t 0 ]; then
  REAL_SHELL=\\\$(getent passwd \"\\\$(whoami)\" | cut -d: -f7)
  if echo \"\\\$REAL_SHELL\" | grep -q zsh && [ -x \"\\\$REAL_SHELL\" ]; then
    export ZSH_LAUNCHED=1
    exec \"\\\$REAL_SHELL\" -l
  fi
fi
ZSHFIX
'
"

# Termux → chroot wrappers
TP="$PREFIX/tmp/.X11-unix"
mkdir -p "$TP" "$PREFIX/bin"

# Host-side helper: phone-ip (no root needed)
cat >"$PREFIX/bin/phone-ip" <<'SH'
#!/data/data/com.termux/files/usr/bin/sh
python3 - <<'PY'
import socket
s=socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
s.connect(("1.1.1.1",80))
print(s.getsockname()[0])
s.close()
PY
SH
chmod 0755 "$PREFIX/bin/phone-ip"

cat >"$PREFIX/bin/ubuntu-chroot" <<'SH'
#!/data/data/com.termux/files/usr/bin/sh
: "${PREFIX:=/data/data/com.termux/files/usr}"
C="$HOME/containers/ubuntu-chroot"
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

# Piped input check FIRST
if [ ! -t 0 ]; then
  exec sudo rurima r \
    -m "$TP" /tmp/.X11-unix \
    -m /sdcard /mnt/sdcard \
    "$C" /usr/bin/env -i \
      HOME=/root \
      TERM="${TERM:-xterm-256color}" \
      PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin \
      "${@:-/bin/bash}"
fi

# No args → interactive - always use bash, .bashrc will auto-launch zsh
[ "$#" -eq 0 ] && exec sudo rurima r \
  -m "$TP" /tmp/.X11-unix \
  -m /sdcard /mnt/sdcard \
  "$C" /bin/su - "$U" -s /bin/bash

# Command - use simple env approach
exec sudo rurima r \
  -m "$TP" /tmp/.X11-unix \
  -m /sdcard /mnt/sdcard \
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

echo "✅ Rooted container ready. Enter with: ubuntu-chroot"
echo ""