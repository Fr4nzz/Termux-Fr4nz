#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail

# --- Termux prereqs (X11) ---
pkg update -y
pkg install -y x11-repo
pkg install -y termux-x11-nightly xorg-xhost xorg-xdpyinfo tsu >/dev/null
# optional while testing:
# pkg install -y pulseaudio xkeyboard-config

# --- X11 helper wrappers (Termux) ---
PFX="${PREFIX:-/data/data/com.termux/files/usr}"
BIN="$PFX/bin"
XSOCK="$PFX/tmp/.X11-unix"
mkdir -p "$BIN" "$XSOCK"

# x11-up: ensure Termux:X11 :1 is running and access is granted (rooted adds root/ubuntu)
cat >"$BIN/x11-up" <<'SH'
#!/data/data/com.termux/files/usr/bin/sh
set -e
P="$PREFIX"; S="$P/tmp/.X11-unix"
[ -S "$S/X1" ] || {
  am broadcast -a com.termux.x11.ACTION_STOP -p com.termux.x11 >/dev/null 2>&1 || true
  pkill termux-x11 >/dev/null 2>&1 || true
  rm -rf "$S"; mkdir -p "$S"
  TMPDIR="$P/tmp" termux-x11 :1 -legacy-drawing >/dev/null 2>&1 &
  am start -n com.termux.x11/com.termux.x11.MainActivity >/dev/null 2>&1
  sleep 2
}
DISPLAY=:1 xhost +LOCAL: >/dev/null
DISPLAY=:1 xhost +SI:localuser:$(id -un) >/dev/null
DISPLAY=:1 xhost +SI:localuser:root >/dev/null 2>&1 || true
DISPLAY=:1 xhost +SI:localuser:ubuntu >/dev/null 2>&1 || true
ls -l "$S"
SH
chmod 0755 "$BIN/x11-up"

# x11-down: stop Termux:X11
cat >"$BIN/x11-down" <<'SH'
#!/data/data/com.termux/files/usr/bin/sh
am broadcast -a com.termux.x11.ACTION_STOP -p com.termux.x11 >/dev/null 2>&1 || true
pkill termux-x11 >/dev/null 2>&1 || true
SH
chmod 0755 "$BIN/x11-down"

# --- Inside Ubuntu (chroot): desktop packages, no --reinstall ---
ubuntu-chroot /bin/bash -lc '
set -e
export DEBIAN_FRONTEND=noninteractive
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

# Block service autostarts during package install inside chroot
install -d /usr/sbin
tee /usr/sbin/policy-rc.d >/dev/null <<EOF
#!/bin/sh
exit 101
EOF
chmod +x /usr/sbin/policy-rc.d

apt-get update -y
apt-get install -y --no-install-recommends \
  debconf debconf-i18n init-system-helpers perl-base adduser dialog locales tzdata \
  sgml-base xml-core

# Settle anything pending
dpkg --configure -a || true
apt-get -o Dpkg::Options::="--force-confnew" -f install

# Desktop core
apt-get install -y --no-install-recommends \
  xfce4 xfce4-session xfce4-terminal \
  dbus dbus-x11 xterm fonts-dejavu-core x11-utils psmisc

# Locale + dbus prep
sed -i "s/^# *en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/" /etc/locale.gen
locale-gen en_US.UTF-8
dbus-uuidgen --ensure
install -d -m 0755 /run/dbus
'

# --- xfce4 start/stop wrappers for chroot ---
cat >"$BIN/xfce4-chroot-start" <<'SH'
#!/data/data/com.termux/files/usr/bin/sh
set -e
x11-up >/dev/null 2>&1 || true
ubuntu-chroot /bin/bash -lc '
  set -e
  export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
  # Minimal mounts (idempotent)
  mountpoint -q /proc || mount -t proc proc /proc
  mountpoint -q /sys  || mount -t sysfs sys /sys
  mkdir -p /dev/pts /dev/shm /run /tmp/.ICE-unix
  mountpoint -q /dev/pts || mount -t devpts devpts /dev/pts
  mountpoint -q /dev/shm || mount -t tmpfs -o rw,nosuid,nodev,mode=1777,size=256M tmpfs /dev/shm
  chmod 1777 /tmp/.ICE-unix

  export DISPLAY=:1 LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8 GDK_BACKEND=x11 QT_QPA_PLATFORM=xcb LIBGL_ALWAYS_SOFTWARE=1

  # Prefer saved desktop user if present, else current
  U="root"
  [ -f /etc/ruri/user ] && U="$(cat /etc/ruri/user)"
  if [ "$U" != "root" ]; then
    su - "$U" -c "
      mkdir -p \"\$HOME/.run\" && chmod 700 \"\$HOME/.run\"
      export XDG_RUNTIME_DIR=\"\$HOME/.run\"
      command -v xfce4-session >/dev/null || { echo 'xfce4-session not installed.'; exit 1; }
      exec dbus-run-session -- bash -lc 'xfce4-session'
    "
  else
    mkdir -p /run/user/0 && chmod 700 /run/user/0
    export XDG_RUNTIME_DIR=/run/user/0
    command -v xfce4-session >/dev/null || { echo 'xfce4-session not installed.'; exit 1; }
    exec dbus-run-session -- bash -lc "xfce4-session"
  fi
'
SH
chmod 0755 "$BIN/xfce4-chroot-start"

cat >"$BIN/xfce4-chroot-stop" <<'SH'
#!/data/data/com.termux/files/usr/bin/sh
set +e
ubuntu-chroot /bin/bash -lc 'killall -q xfce4-session xfwm4 xfce4-panel xfdesktop xfsettingsd || true'
ubuntu-chroot-u || true
x11-down || true
echo "XFCE (chroot) stopped."
SH
chmod 0755 "$BIN/xfce4-chroot-stop"

echo "✅ XFCE runtime (rooted) ready. Use: xfce4-chroot-start / xfce4-chroot-stop"
