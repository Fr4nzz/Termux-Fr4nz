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

# Wait up to 6s for X1 to appear
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
# IMPORTANT: run xhost with the same TMPDIR the server used
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

# Prevent service autostarts in chroot (quiet postinsts)
install -d /usr/sbin
cat >/usr/sbin/policy-rc.d <<EOF
#!/bin/sh
exit 101
EOF
chmod +x /usr/sbin/policy-rc.d

apt-get update -y
apt-get install -y --no-install-recommends \
  debconf debconf-i18n init-system-helpers perl-base adduser dialog locales tzdata \
  sgml-base xml-core

dpkg --configure -a || true
apt-get -o Dpkg::Options::="--force-confnew" -f install

# Desktop core
apt-get install -y --no-install-recommends \
  xfce4 xfce4-session xfce4-terminal \
  dbus dbus-x11 xterm fonts-dejavu-core x11-utils psmisc

# Locale + dbus prep
sed -i "s/^# *en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/" /etc/locale.gen || true
locale-gen en_US.UTF-8
dbus-uuidgen --ensure
install -d -m 0755 /run/dbus
'

# --- xfce4 start/stop wrappers for chroot (non-root user only) ---
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
echo '[xfce4-chroot-start] inside Ubuntu (root). Preparing mounts & runtime…'
# Minimal mounts (idempotent)
mountpoint -q /proc || mount -t proc proc /proc
mountpoint -q /sys  || mount -t sysfs sys /sys
mkdir -p /dev/pts /dev/shm /run /tmp/.ICE-unix
mountpoint -q /dev/pts || mount -t devpts devpts /dev/pts
mountpoint -q /dev/shm || mount -t tmpfs -o rw,nosuid,nodev,mode=1777,size=256M tmpfs /dev/shm
chmod 1777 /tmp/.ICE-unix

# Require a non-root desktop user
if [ ! -s /etc/ruri/user ]; then
  echo '[xfce4-chroot-start] ERROR: /etc/ruri/user not found. Create your desktop user and record it:' >&2
  echo '  adduser <name> && adduser <name> sudo && printf %s <name> | tee /etc/ruri/user' >&2
  exit 1
fi
U=\"\$(cat /etc/ruri/user)\"
if [ \"\$U\" = 'root' ]; then
  echo '[xfce4-chroot-start] ERROR: Desktop user is root; set a non-root user in /etc/ruri/user.' >&2
  exit 1
fi
if ! id \"\$U\" >/dev/null 2>&1; then
  echo \"[xfce4-chroot-start] ERROR: user '\$U' does not exist. Create it: adduser \$U && adduser \$U sudo\" >&2
  exit 1
fi
echo \"[xfce4-chroot-start] target desktop user: \$U\"

echo '[xfce4-chroot-start] starting XFCE as non-root user…'
su - \"\$U\" -s /bin/bash -c '
  set -e
  echo \"[xfce4-chroot-start] user is \$(id -un):\$(id -gn)\"
  # ===== Session env (propagates to apps launched from the menu) =====
  export DISPLAY=\"'$D'\" 
  export LANG=en_US.UTF-8
  export LC_ALL=en_US.UTF-8
  export GDK_BACKEND=x11
  export QT_QPA_PLATFORM=xcb
  export QT_XCB_NO_MITSHM=1
  export LIBGL_ALWAYS_SOFTWARE=1
  export GTK_USE_PORTAL=0
  export NO_AT_BRIDGE=1
  # Keep sandbox on in chroot by default; browsers run fine here.
  export MOZ_ENABLE_WAYLAND=0
  export MOZ_WEBRENDER=0
  : \"\${MOZ_DISABLE_CONTENT_SANDBOX:=0}\"; export MOZ_DISABLE_CONTENT_SANDBOX
  export ELECTRON_OZONE_PLATFORM_HINT=x11

  mkdir -p \"\$HOME/.run\" && chmod 700 \"\$HOME/.run\"
  export XDG_RUNTIME_DIR=\"\$HOME/.run\"
  command -v xfce4-session
  echo \"[xfce4-chroot-start] launching xfce4-session via dbus-run-session (DISPLAY=\$DISPLAY)…\"
  exec dbus-run-session -- bash -lc \"xfce4-session\"
'
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
