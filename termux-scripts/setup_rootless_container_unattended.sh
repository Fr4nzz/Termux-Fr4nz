#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail
: "${PREFIX:=/data/data/com.termux/files/usr}"
C="${CONTAINER:-$HOME/containers/ubuntu-proot}"
U="${DESKTOP_USER:-}"

if [ -z "$U" ]; then
  read -rp "Desktop username [legend]: " U </dev/tty || true
  U="${U:-legend}"
fi

pkg update -y >/dev/null || true

# Daijin (if missing)
if [ ! -x "$PREFIX/share/daijin/proot_start.sh" ]; then
  tmpdeb="$PREFIX/tmp/daijin-aarch64.deb"
  mkdir -p "$PREFIX/tmp"
  curl -fsSL -o "$tmpdeb" \
    https://github.com/RuriOSS/daijin/releases/download/daijin-v1.5-rc1/daijin-aarch64.deb
  (apt install -y "$tmpdeb" 2>/dev/null) \
    || (dpkg -i "$tmpdeb" || true; apt -f install -y)
  rm -f "$tmpdeb"
fi

# Pull if missing (assumes rurima already installed)
[ -d "$C" ] || rurima lxc pull -o ubuntu -v noble -s "$C"

# Fixup
curl -fsSL https://raw.githubusercontent.com/RuriOSS/daijin/refs/heads/main/src/share/fixup.sh \
  | "$PREFIX/share/daijin/proot_start.sh" -r "$C" \
      /usr/bin/env -i HOME=/root TERM=xterm-256color \
      PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin \
      /bin/sh

# Base tools inside the container (needed by container-scripts)
cat <<'SH' | "$PREFIX/share/daijin/proot_start.sh" -r "$C" \
  /usr/bin/env -i HOME=/root TERM=xterm-256color \
  PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin \
  /bin/sh
set -e
export DEBIAN_FRONTEND=noninteractive
apt-get update -y
apt-get install -y curl ca-certificates gnupg wget
SH

# Base maintainer helpers so adduser & postinsts work
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

# User + sudoers + remember + TERM
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

# Wrappers
TP="$PREFIX/tmp/.X11-unix"
mkdir -p "$TP" "$PREFIX/bin"

cat >"$PREFIX/bin/ubuntu-proot" <<'SH'
#!/data/data/com.termux/files/usr/bin/sh
# Wrapper for entering/running commands inside the ubuntu-proot container.
: "${PREFIX:=/data/data/com.termux/files/usr}"
C="/data/data/com.termux/files/home/containers/ubuntu-proot"
TP="$PREFIX/tmp/.X11-unix"
[ -d "$TP" ] || mkdir -p "$TP"

# Default user is root until we record one
U="root"
[ -f "$C/etc/ruri/user" ] && U="$(cat "$C/etc/ruri/user")"

PROOT="$PREFIX/share/daijin/proot_start.sh"
BIND="-b $TP:/tmp/.X11-unix -b /sdcard:/mnt/sdcard -w /root"

if [ "$#" -eq 0 ]; then
  # Interactive login shell
  exec "$PROOT" -r "$C" -e "$BIND" /bin/su - "$U"
fi

# If stdin is a pipe and caller asked for /bin/sh (or sh), preserve stdin
if [ ! -t 0 ] && { [ "$1" = "/bin/sh" ] || [ "$1" = "sh" ] || [ "$1" = "-" ]; }; then
  exec "$PROOT" -r "$C" -e "$BIND" /bin/su - "$U" -s /bin/sh
fi

# Otherwise run the provided command with args
exec "$PROOT" -r "$C" -e "$BIND" /bin/su - "$U" -s /bin/sh -c 'exec "$@"' sh -- "$@"
SH
chmod 0755 "$PREFIX/bin/ubuntu-proot"

cat >"$PREFIX/bin/ubuntu-proot-u" <<'SH'
#!/data/data/com.termux/files/usr/bin/sh
C="$HOME/containers/ubuntu-proot"
pkill -f "proot .*${C}" || true
SH
chmod 0755 "$PREFIX/bin/ubuntu-proot-u"

echo "✅ Rootless container ready. Enter with: ubuntu-proot"