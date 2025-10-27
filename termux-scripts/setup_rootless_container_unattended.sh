#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail
: "${PREFIX:=/data/data/com.termux/files/usr}"
C="${CONTAINER:-$HOME/containers/ubuntu-proot}"

if [ -z "$U" ]; then
  read -rp "Desktop username [legend]: " U </dev/tty || true
  U="${U:-legend}"
fi

pkg update -y >/dev/null || true

# Daijin (if missing)
if [ ! -x "$PREFIX/share/daijin/proot_start.sh" ]; then
  curl -LO https://github.com/RuriOSS/daijin/releases/download/daijin-v1.5-rc1/daijin-aarch64.deb
  apt install -y ./daijin-aarch64.deb
  rm -f daijin-aarch64.deb
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
"$PREFIX/share/daijin/proot_start.sh" -r "$C" /bin/sh -lc '
  export DEBIAN_FRONTEND=noninteractive
  apt-get update -y
  apt-get install -y curl ca-certificates gnupg wget'

# Base maintainer helpers so adduser & postinsts work
"$PREFIX/share/daijin/proot_start.sh" -r "$C" /bin/sh -lc '
  export DEBIAN_FRONTEND=noninteractive
  apt-get update -y
  apt-get install -y --no-install-recommends debconf
  apt-get install -y --reinstall --no-install-recommends \
    debconf-i18n init-system-helpers perl-base adduser dialog locales tzdata
  apt-get install -y --reinstall --no-install-recommends sgml-base xml-core
  dpkg --configure -a || true
  apt-get -o Dpkg::Options::="--force-confnew" -f install
'

# User + sudoers + remember + TERM
"$PREFIX/share/daijin/proot_start.sh" -r "$C" /bin/sh -lc "
set -e
adduser --disabled-password --gecos '' '$U' || true
adduser '$U' sudo || true
echo '$U ALL=(ALL) NOPASSWD: ALL' > /etc/sudoers.d/99-$U
chmod 0440 /etc/sudoers.d/99-$U
install -d -m0755 /etc/ruri
printf '%s\n' '$U' > /etc/ruri/user
install -d -m0700 -o '$U' -g '$U' /home/'$U'/.run
echo 'export TERM=xterm-256color' >> /root/.bashrc
su - '$U' -c \"echo 'export TERM=xterm-256color' >> ~/.bashrc\"
"

# Wrappers
TP="$PREFIX/tmp/.X11-unix"
mkdir -p "$PREFIX/bin"
cat >"$PREFIX/bin/ubuntu-proot" <<'SH'
#!/data/data/com.termux/files/usr/bin/sh
: "${PREFIX:=/data/data/com.termux/files/usr}"
C="/data/data/com.termux/files/home/containers/ubuntu-proot"
TP="/data/data/com.termux/files/usr/tmp/.X11-unix"
U="$(cat "$C/etc/ruri/user")"
if [ "$#" -gt 0 ]; then
  exec "$PREFIX/share/daijin/proot_start.sh" -r "$C" -e "-b $TP:/tmp/.X11-unix -b /sdcard:/mnt/sdcard -w /root" /bin/su - "$U" -c "$*"
else
  exec "$PREFIX/share/daijin/proot_start.sh" -r "$C" -e "-b $TP:/tmp/.X11-unix -b /sdcard:/mnt/sdcard -w /root" /bin/su - "$U"
fi
SH
chmod 0755 "$PREFIX/bin/ubuntu-proot"

cat >"$PREFIX/bin/ubuntu-proot-u" <<'SH'
#!/data/data/com.termux/files/usr/bin/sh
C="$HOME/containers/ubuntu-proot"
pkill -f "proot .*${C}" || true
SH
chmod 0755 "$PREFIX/bin/ubuntu-proot-u"

echo "✅ Rootless container ready. Enter with: ubuntu-proot"
