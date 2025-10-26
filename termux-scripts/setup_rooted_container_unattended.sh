#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail
: "${PREFIX:=/data/data/com.termux/files/usr}"
C="${CONTAINER:-$HOME/containers/ubuntu-chroot}"
U="${DESKTOP_USER:-legend}"

pkg update -y >/dev/null || true
pkg install -y tsu >/dev/null

# rurima (if missing)
if ! command -v rurima >/dev/null 2>&1; then
  curl -fsSL https://raw.githubusercontent.com/Fr4nzz/Termux-Fr4nz/refs/heads/main/termux-scripts/install_rurima.sh | bash
fi

# Pull if missing
[ -d "$C" ] || rurima lxc pull -o ubuntu -v noble -s "$C"

# Fixup
curl -fsSL https://raw.githubusercontent.com/RuriOSS/daijin/refs/heads/main/src/share/fixup.sh \
  | sudo rurima r "$C" /bin/sh

# Base tools inside the container (needed by container-scripts)
sudo rurima r "$C" /bin/bash -lc 'export DEBIAN_FRONTEND=noninteractive
apt-get update -y
apt-get install -y curl ca-certificates gnupg wget'

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
