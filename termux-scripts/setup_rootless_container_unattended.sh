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

pkg update -y >/dev/null || true

# --- Install Daijin first (its install can break rurima binaries) ---
if [ ! -x "$PREFIX/share/daijin/proot_start.sh" ]; then
  tmpdeb="$PREFIX/tmp/daijin-aarch64.deb"
  mkdir -p "$PREFIX/tmp"
  curl -fsSL -o "$tmpdeb" \
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
apt-get install -y curl ca-certificates gnupg wget
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
/usr/bin/install -d -m0700 -o "$U" -g "$U" /home/"$U"/.run
echo 'export TERM=xterm-256color' >> /root/.bashrc
/bin/su - "$U" -c "echo 'export TERM=xterm-256color' >> ~/.bashrc"
SH

# Termux → container wrappers
TP="$PREFIX/tmp/.X11-unix"
mkdir -p "$TP" "$PREFIX/bin"

cat >"$PREFIX/bin/ubuntu-proot" <<'SH'
#!/data/data/com.termux/files/usr/bin/sh
: "${PREFIX:=/data/data/com.termux/files/usr}"
C="$HOME/containers/ubuntu-proot"
TP="$PREFIX/tmp/.X11-unix"; [ -d "$TP" ] || mkdir -p "$TP"

# Parse --user flag
U=""; [ "$1" = "--user" ] && { U="$2"; shift 2; }
[ -z "$U" ] && U="$(cat "$C/etc/ruri/user" 2>/dev/null || echo root)"

# Setup
PROOT="$PREFIX/share/daijin/proot_start.sh"
BIND="-b $TP:/tmp/.X11-unix -b /sdcard:/mnt/sdcard"
HOME_DIR="/root"; [ "$U" != "root" ] && HOME_DIR="/home/$U"
ENV="/usr/bin/env -i HOME=$HOME_DIR TERM=${TERM:-xterm-256color} PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin LANG=${LANG:-en_US.UTF-8}"

# No args → interactive login
[ "$#" -eq 0 ] && exec "$PROOT" -r "$C" -e "$BIND" $ENV /bin/su - "$U"

# Piped/redirected input → run shell reading from stdin
if [ ! -t 0 ]; then
  SHELL="/bin/sh"
  case "$1" in
    /bin/bash|bash) SHELL="/bin/bash"; shift ;;
    /bin/sh|sh|-) shift ;;
  esac
  exec "$PROOT" -r "$C" -e "$BIND" $ENV /bin/su - "$U" <<SUEOF
exec $SHELL
SUEOF
fi

# Run command as user
exec "$PROOT" -r "$C" -e "$BIND" $ENV /bin/su - "$U" -c 'exec "$@"' sh -- "$@"
SH
chmod 0755 "$PREFIX/bin/ubuntu-proot"

cat >"$PREFIX/bin/ubuntu-proot-u" <<'SH'
#!/data/data/com.termux/files/usr/bin/sh
C="$HOME/containers/ubuntu-proot"
pkill -f "proot .*${C}" || true
SH
chmod 0755 "$PREFIX/bin/ubuntu-proot-u"

echo "✅ Rootless container ready. Enter with: ubuntu-proot"
