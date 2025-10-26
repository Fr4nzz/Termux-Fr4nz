#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail
: "${PREFIX:=/data/data/com.termux/files/usr}"
C="${CONTAINER:-$HOME/containers/ubuntu-chroot}"
# Prompt for username unless DESKTOP_USER is set
if [ -n "${DESKTOP_USER:-}" ]; then
  U="$DESKTOP_USER"
else
  read -rp "Desktop username [legend]: " U; U="${U:-legend}"
fi

pkg update -y >/dev/null || true
pkg install -y tsu >/dev/null

# Pull if missing (assumes rurima already installed)
[ -d "$C" ] || rurima lxc pull -o ubuntu -v noble -s "$C"

# Fixup
curl -fsSL https://raw.githubusercontent.com/RuriOSS/daijin/refs/heads/main/src/share/fixup.sh \
  | sudo rurima r "$C" /bin/sh

# Base tools inside the container (needed by container-scripts)
sudo rurima r "$C" /bin/bash -lc 'export DEBIAN_FRONTEND=noninteractive
apt-get update -y
apt-get install -y curl ca-certificates gnupg wget'

# Base maintainer helpers so adduser & postinsts work
sudo rurima r "$C" /bin/bash -lc 'export DEBIAN_FRONTEND=noninteractive
apt-get update -y
# dpkg/apt helpers first
apt-get install -y --no-install-recommends debconf
# common helpers (adduser needs perl; many postinsts need these)
apt-get install -y --reinstall --no-install-recommends \
  debconf-i18n init-system-helpers perl-base adduser dialog locales tzdata
# sgml/xml helper (provides update-catalog) used by various postinsts
apt-get install -y --reinstall --no-install-recommends sgml-base xml-core
# settle anything pending
dpkg --configure -a || true
apt-get -o Dpkg::Options::="--force-confnew" -f install
'

# User + sudoers + remember + TERM
sudo rurima r "$C" /bin/bash -lc "
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
cat >"$PREFIX/bin/ubuntu-chroot" <<'SH'
#!/data/data/com.termux/files/usr/bin/sh
C="$HOME/containers/ubuntu-chroot"
TP="/data/data/com.termux/files/usr/tmp/.X11-unix"
U="$(cat "$C/etc/ruri/user")"
exec sudo rurima r -m "$TP" /tmp/.X11-unix -m /sdcard /mnt/sdcard -E "$U" "$C" "$@"
SH
chmod 0755 "$PREFIX/bin/ubuntu-chroot"

cat >"$PREFIX/bin/ubuntu-chroot-u" <<'SH'
#!/data/data/com.termux/files/usr/bin/sh
C="$HOME/containers/ubuntu-chroot"
exec sudo rurima r -U "$C"
SH
chmod 0755 "$PREFIX/bin/ubuntu-chroot-u"

echo "✅ Rooted container ready. Enter with: ubuntu-chroot"
