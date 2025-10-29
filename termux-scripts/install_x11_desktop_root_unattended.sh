#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail

echo "[setup] Termux prerequisites for X11 (rooted/chroot)…"
pkg update -y
pkg install -y x11-repo
pkg install -y termux-x11-nightly xorg-xhost xorg-xdpyinfo tsu

# --- Paths ---
PFX="${PREFIX:-/data/data/com.termux/files/usr}"
BIN="$PFX/bin"
XSOCK="$PFX/tmp/.X11-unix"
mkdir -p "$BIN" "$XSOCK"

# --- x11-up: Start Termux:X11 on :1 only, with logs and readiness check ---
cat >"$BIN/x11-up" <<'SH'
#!/data/data/com.termux/files/usr/bin/sh
set -e
T="$PREFIX/tmp"              # Termux:X11 places its socket here
S="$T/.X11-unix"

echo "[x11-up] stopping any running Termux:X11 and cleaning sockets…"
am broadcast -a com.termux.x11.ACTION_STOP -p com.termux.x11 || true
pkill termux-x11 || true
mkdir -p "$S"

echo "[x11-up] starting Termux:X11 on :1 (legacy drawing)…"
TMPDIR="$T" termux-x11 :1 -legacy-drawing &
echo "[x11-up] bringing Termux:X11 activity to foreground…"
am start -n com.termux.x11/com.termux.x11.MainActivity || true

# Wait up to ~6s for the :1 socket to exist
echo "[x11-up] waiting for $S/X1 …"
for i in $(seq 1 60); do
  [ -S "$S/X1" ] && { echo "[x11-up] OK: X1 path socket present."; break; }
  sleep 0.1
done
if [ ! -S "$S/X1" ]; then
  echo "[x11-up] ERROR: X1 did not appear. Force-close Termux:X11 in Android settings and rerun." >&2
  exit 1
fi

echo "[x11-up] granting local access on :1 …"
for i in $(seq 1 20); do
  if TMPDIR="$T" DISPLAY=:1 xhost +LOCAL: >/dev/null 2>&1; then
    TMPDIR="$T" DISPLAY=:1 xhost +SI:localuser:$(id -un) >/dev/null 2>&1 || true
    echo "[x11-up] access granted."
    break
  fi
  sleep 0.2
  [ "$i" -eq 20 ] && echo "[x11-up] WARNING: xhost could not open :1 yet, continuing anyway."
done

echo ":1" > "$S/.display"
echo "[x11-up] current sockets:"
ls -l "$S"
SH
chmod 0755 "$BIN/x11-up"

# --- x11-down: stop X11 and clean socket dir ---
cat >"$BIN/x11-down" <<'SH'
#!/data/data/com.termux/files/usr/bin/sh
set -e
T="$PREFIX/tmp"; S="$T/.X11-unix"
echo "[x11-down] stopping Termux:X11 …"
am broadcast -a com.termux.x11.ACTION_STOP -p com.termux.x11 || true
pkill termux-x11 || true
echo "[x11-down] cleaning sockets …"
mkdir -p "$S"
SH
chmod 0755 "$BIN/x11-down"

# --- Inside Ubuntu (chroot): desktop packages (idempotent) ---
echo "[setup] Preparing Ubuntu (chroot) base packages & XFCE …"
ubuntu-chroot /bin/bash -lc '
set -e
export DEBIAN_FRONTEND=noninteractive
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

# Prevent service autostarts in chroot (quiet postinst scripts)
sudo install -d /usr/sbin
sudo tee /usr/sbin/policy-rc.d >/dev/null <<EOF
#!/bin/sh
exit 101
EOF
sudo chmod +x /usr/sbin/policy-rc.d

sudo apt-get update -y

# Make sure base maintainer tools exist (some minimal images miss pieces)
sudo apt-get install -y --no-install-recommends \
  debconf debconf-i18n init-system-helpers perl-base adduser dialog locales tzdata \
  sgml-base xml-core

# Repair half-configured packages if apt died earlier
sudo dpkg --configure -a || true
sudo apt-get -o Dpkg::Options::="--force-confnew" -f install

# Desktop core
sudo apt-get install -y --no-install-recommends \
  xfce4 xfce4-session xfce4-terminal \
  dbus dbus-x11 xterm fonts-dejavu-core x11-utils psmisc

# Locale + dbus prep
sudo sed -i "s/^# *en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/" /etc/locale.gen || true
sudo locale-gen en_US.UTF-8
sudo dbus-uuidgen --ensure
sudo install -d -m 0755 /run/dbus
'

# --- NEW: unify Desktop for root and the saved desktop user ---
ubuntu-chroot /bin/bash -lc '
set -e
RU="$(cat /etc/ruri/user 2>/dev/null || echo ubuntu)"
USER_DESK="/home/$RU/Desktop"
ROOT_DESK="/root/Desktop"

# Ensure the real desktop user has a Desktop dir
sudo install -d -m 0755 "$USER_DESK"
sudo chown "$RU:$RU" "$USER_DESK" || true

# Make root/Desktop a symlink to that Desktop,
# so when XFCE runs as root you see/click the same launchers
# (code-proot, firefox-proot, etc.).
if [ -d /root ]; then
    if [ -L "$ROOT_DESK" ]; then
        :
    elif [ -e "$ROOT_DESK" ]; then
        echo "[setup] /root/Desktop already exists and is not a symlink; leaving it alone."
    else
        sudo ln -s "$USER_DESK" "$ROOT_DESK"
    fi
fi
'

# --- xfce4 start/stop wrappers (runtime) ---
cat >"$BIN/xfce4-chroot-start" <<'SH'
#!/data/data/com.termux/files/usr/bin/sh
set -e
echo "[xfce4-chroot-start] ensuring Termux:X11 :1 is up…"
x11-up

# Read display (:1) recorded by x11-up
D=":1"
F="$PREFIX/tmp/.X11-unix/.display"
[ -s "$F" ] && D="$(head -n1 "$F")"
echo "[xfce4-chroot-start] using DISPLAY=$D"

ubuntu-chroot /bin/bash -lc "
set -e
echo \"[xfce4-chroot-start] inside Ubuntu. Preparing mounts & runtime…\"

# Mount /proc, /sys, /dev/pts, tmpfs /dev/shm, etc. Needs root.
sudo mountpoint -q /proc || sudo mount -t proc proc /proc
sudo mountpoint -q /sys  || sudo mount -t sysfs sys /sys
sudo mkdir -p /dev/pts /dev/shm /run /tmp/.ICE-unix
sudo mountpoint -q /dev/pts || sudo mount -t devpts devpts /dev/pts
sudo mountpoint -q /dev/shm || sudo mount -t tmpfs -o rw,nosuid,nodev,mode=1777,size=256M tmpfs /dev/shm
sudo chmod 1777 /tmp/.ICE-unix

U_SAVED=\"\$(cat /etc/ruri/user 2>/dev/null || echo '')\"
U_CURR=\"\$(id -un)\"

if [ -n \"\$U_SAVED\" ] && [ \"\$U_SAVED\" != \"\$U_CURR\" ]; then
  echo \"[xfce4-chroot-start] WARNING: current user '\$U_CURR' != saved desktop user '\$U_SAVED'.\"
  echo \"[xfce4-chroot-start] Continuing anyway as '\$U_CURR'.\"
fi

echo \"[xfce4-chroot-start] launching XFCE as '\$U_CURR' …\"

# Session env (propagates to launched apps)
export DISPLAY=$D
export LANG=en_US.UTF-8
export LC_ALL=en_US.UTF-8
export GDK_BACKEND=x11
export QT_QPA_PLATFORM=xcb
export QT_XCB_NO_MITSHM=1
export LIBGL_ALWAYS_SOFTWARE=1
export GTK_USE_PORTAL=0
export NO_AT_BRIDGE=1
export ELECTRON_OZONE_PLATFORM_HINT=x11

# Per-user runtime dir (needed for a lot of desktop apps)
mkdir -p \"\$HOME/.run\" && chmod 700 \"\$HOME/.run\"
export XDG_RUNTIME_DIR=\"\$HOME/.run\"

command -v xfce4-session >/dev/null || { echo \"xfce4-session not installed (run install_x11_desktop_root_unattended.sh first).\"; exit 1; }

echo \"[xfce4-chroot-start] starting xfce4-session via dbus-run-session (DISPLAY=\$DISPLAY)…\"
exec dbus-run-session -- bash -lc \"xfce4-session\"
"
SH
chmod 0755 "$BIN/xfce4-chroot-start"

cat >"$BIN/xfce4-chroot-stop" <<'SH'
#!/data/data/com.termux/files/usr/bin/sh
set +e
echo "[xfce4-chroot-stop] stopping XFCE in Ubuntu …"
ubuntu-chroot /bin/bash -lc 'killall -q xfce4-session xfwm4 xfce4-panel xfdesktop xfsettingsd || true'
echo "[xfce4-chroot-stop] unmount/cleanup chroot and stop X11 …"
ubuntu-chroot-u || true
x11-down || true
echo "[xfce4-chroot-stop] done."
SH
chmod 0755 "$BIN/xfce4-chroot-stop"

echo "✅ XFCE runtime (rooted/chroot) ready."
echo "   Start: xfce4-chroot-start"
echo "   Stop:  xfce4-chroot-stop"
