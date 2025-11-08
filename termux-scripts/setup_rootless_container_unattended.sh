#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail
: "${PREFIX:=/data/data/com.termux/files/usr}"
C="${CONTAINER:-$HOME/containers/ubuntu-proot}"
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

# --- Install Daijin first (its install can break rurima binaries) ---
if [ ! -x "$PREFIX/share/daijin/proot_start.sh" ]; then
  tmpdeb="$PREFIX/tmp/daijin-aarch64.deb"
  mkdir -p "$PREFIX/tmp"
  curl -fL -o "$tmpdeb" \
    https://github.com/RuriOSS/daijin/releases/download/daijin-v1.5-rc1/daijin-aarch64.deb
  (apt install -y "$tmpdeb" 2>/dev/null) || (dpkg -i "$tmpdeb" || true; apt -f install -y)
  rm -f "$tmpdeb"
fi

# --- (Re)install rurima AFTER daijin to avoid "unexpected e_type: 2" ---
if ! command -v rurima >/dev/null 2>&1; then
  echo "[rootless] Installing rurima..."
  curl -fsSL https://raw.githubusercontent.com/Fr4nzz/Termux-Fr4nz/refs/heads/main/termux-scripts/install_rurima.sh | bash
else
  if ! rurima -v >/dev/null 2>&1; then
    echo "[rootless] Repairing rurima (post-daijin)..."
    curl -fsSL https://raw.githubusercontent.com/Fr4nzz/Termux-Fr4nz/refs/heads/main/termux-scripts/install_rurima.sh | bash
  fi
fi

# Pull Ubuntu (requires rurima)
[ -d "$C" ] || rurima lxc pull -o ubuntu -v noble -s "$C"

# Fixup inside the container (from daijin repo)
curl -fsSL https://raw.githubusercontent.com/RuriOSS/daijin/refs/heads/main/src/share/fixup.sh \
  | "$PREFIX/share/daijin/proot_start.sh" -r "$C" \
      /usr/bin/env -i HOME=/root TERM=xterm-256color \
      PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin \
      /bin/sh

# Base tools used by your container-scripts
cat <<'SH' | "$PREFIX/share/daijin/proot_start.sh" -r "$C" \
  /usr/bin/env -i HOME=/root TERM=xterm-256color \
  PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin \
  /bin/sh
set -e
export DEBIAN_FRONTEND=noninteractive
apt-get update -y
apt-get install -y curl ca-certificates gnupg wget python3
SH

# Maintainer helpers so adduser & postinsts work smoothly
cat <<'SH' | "$PREFIX/share/daijin/proot_start.sh" -r "$C" \
  /usr/bin/env -i HOME=/root TERM=xterm-256color \
  PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin \
  /bin/sh
set -e
export DEBIAN_FRONTEND=noninteractive
apt-get update -y
apt-get install -y --no-install-recommends \
  debconf debconf-i18n init-system-helpers perl-base adduser dialog locales tzdata \
  sgml-base xml-core
dpkg --configure -a || true
apt-get -o Dpkg::Options::="--force-confnew" -f install
SH

# myip helper inside the proot container (no root needed)
cat <<'SH' | "$PREFIX/share/daijin/proot_start.sh" -r "$C" \
  /usr/bin/env -i HOME=/root TERM=xterm-256color \
  PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin \
  /bin/sh
set -e
cat >/usr/local/bin/myip <<'PYSH'
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
SH

# Create desktop user + sudo NOPASSWD + remember it + XDG runtime
cat <<SH | "$PREFIX/share/daijin/proot_start.sh" -r "$C" \
  /usr/bin/env -i HOME=/root TERM=xterm-256color \
  PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin \
  /bin/sh
set -e
U="$U"
if [ -z "$U" ] || printf '%s' "$U" | grep -Eq '^-'; then
  echo "Invalid username: $U"; exit 1
fi
if ! printf '%s' "$U" | grep -Eq '^[A-Za-z0-9_.@-]+$'; then
  echo "Invalid username: $U"; exit 1
fi
/usr/sbin/adduser --disabled-password --gecos '' "$U" || true
/usr/sbin/adduser "$U" sudo || true
/usr/bin/install -d -m0755 /etc/sudoers.d
echo "$U ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/99-$U
/bin/chmod 0440 /etc/sudoers.d/99-$U
/usr/bin/install -d -m0755 /etc/ruri
printf '%s\n' "$U" > /etc/ruri/user
# Mark runtime so R setup can pick proot path
printf '%s\n' proot > /etc/ruri/runtime
/usr/bin/install -d -m0700 -o "$U" -g "$U" /home/"$U"/.run
echo 'export TERM=xterm-256color' >> /root/.bashrc
/bin/su - "$U" -c "echo 'export TERM=xterm-256color' >> ~/.bashrc"
SH

# Termux → container wrappers
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

PROOT="$PREFIX/share/daijin/proot_start.sh"
BIND="-b $TP:/tmp/.X11-unix -b /sdcard:/mnt/sdcard"

# Piped input check FIRST
if [ ! -t 0 ]; then
  exec "$PROOT" -r "$C" -e "$BIND" \
    /usr/bin/env -i \
      HOME=/root \
      TERM="${TERM:-xterm-256color}" \
      PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin \
      "${@:-/bin/bash}"
fi

# No args → interactive
[ "$#" -eq 0 ] && exec "$PROOT" -r "$C" -e "$BIND" /bin/su - "$U"

# Command - use simple env approach
exec "$PROOT" -r "$C" -e "$BIND" \
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

# Install Zsh based on earlier answer
case "$INSTALL_ZSH" in
  [Yy]*|"")
    echo "[*] Installing Zsh in container..."
    if curl -fsSL https://raw.githubusercontent.com/Fr4nzz/Termux-Fr4nz/refs/heads/main/container-scripts/install_zsh.sh \
      | ubuntu-proot; then
      echo "✅ Zsh installed in container"
    else
      echo "⚠️  Zsh installation failed or skipped"
    fi
    ;;
  *)
    echo "Skipping Zsh installation"
    ;;
esac

echo "✅ Rootless container ready. Enter with: ubuntu-proot"
echo ""
