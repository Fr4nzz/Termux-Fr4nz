#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail

echo "[setup] Termux prerequisites for X11…"
pkg update -y
pkg install -y x11-repo
pkg install -y termux-x11-nightly xorg-xhost xorg-xdpyinfo

# --- Paths ---
PFX="${PREFIX:-/data/data/com.termux/files/usr}"
BIN="$PFX/bin"
XSOCK="$PFX/tmp/.X11-unix"
mkdir -p "$BIN" "$XSOCK"

# --- x11-up: Start Termux:X11 on :1 only, show logs, store display ---
cat >"$BIN/x11-up" <<'SH'
#!/data/data/com.termux/files/usr/bin/sh
set -e
echo "[x11-up] stopping any running Termux:X11 and cleaning sockets…"
am broadcast -a com.termux.x11.ACTION_STOP -p com.termux.x11 || true
pkill termux-x11 || true
mkdir -p "$PREFIX/tmp/.X11-unix"

echo "[x11-up] starting Termux:X11 on :1 (legacy drawing)…"
TMPDIR="$PREFIX/tmp" termux-x11 :1 -legacy-drawing &
X_PID=$!
echo "[x11-up] bringing Termux:X11 activity to foreground…"
am start -n com.termux.x11/com.termux.x11.MainActivity || true

# Wait up to 6s for the X1 path socket to appear
echo "[x11-up] waiting for $PREFIX/tmp/.X11-unix/X1 …"
for i in $(seq 1 60); do
  if [ -S "$PREFIX/tmp/.X11-unix/X1" ]; then
    echo "[x11-up] OK: X1 path socket present."
    break
  fi
  sleep 0.1
done
if [ ! -S "$PREFIX/tmp/.X11-unix/X1" ]; then
  echo "[x11-up] ERROR: X1 did not appear. If the app was wedged, force-close 'Termux:X11' from Android Settings and rerun." >&2
  exit 1
fi

echo "[x11-up] granting local access on :1 …"
DISPLAY=:1 xhost +LOCAL:
DISPLAY=:1 xhost +SI:localuser:$(id -un) || true

echo ":1" > "$PREFIX/tmp/.X11-unix/.display"
echo "[x11-up] current sockets:"
ls -l "$PREFIX/tmp/.X11-unix"
SH
chmod 0755 "$BIN/x11-up"

# --- x11-down: stop X11 and clean socket dir ---
cat >"$BIN/x11-down" <<'SH'
#!/data/data/com.termux/files/usr/bin/sh
set -e
echo "[x11-down] stopping Termux:X11 …"
am broadcast -a com.termux.x11.ACTION_STOP -p com.termux.x11 || true
pkill termux-x11 || true
echo "[x11-down] cleaning sockets …"
mkdir -p "$PREFIX/tmp/.X11-unix"
SH
chmod 0755 "$BIN/x11-down"

# --- Minimal base in Ubuntu (proot) to keep postinsts quiet; you already have most bits ---
echo "[setup] Preparing Ubuntu (proot) base packages …"
cat <<'SH' | ubuntu-proot /bin/sh
set -e
export DEBIAN_FRONTEND=noninteractive
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

# Prevent noisy service autostarts in proot
install -d /usr/sbin
cat >/usr/sbin/policy-rc.d <<'EOF'
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

# Desktop core (if already present, this is a no-op)
apt-get install -y --no-install-recommends \
  xfce4 xfce4-session xfce4-terminal \
  dbus dbus-x11 xterm fonts-dejavu-core x11-utils psmisc

# Locale + dbus prep (idempotent)
sed -i 's/^# *en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen || true
locale-gen en_US.UTF-8
dbus-uuidgen --ensure
install -d -m 0755 /run/dbus
SH

# --- xfce4 start/stop wrappers (rootless/proot) ---
cat >"$BIN/xfce4-proot-start" <<'SH'
#!/data/data/com.termux/files/usr/bin/sh
set -e
echo "[xfce4-proot-start] ensuring Termux:X11 :1 is up…"
x11-up

# Use the display chosen by x11-up (always :1 in this script)
D=":1"
F="$PREFIX/tmp/.X11-unix/.display"
[ -s "$F" ] && D="$(head -n1 "$F")"
echo "[xfce4-proot-start] using DISPLAY=$D"

# Run the session *inside* Ubuntu via a here-doc (works reliably with your wrapper)
cat <<EOF | ubuntu-proot /bin/sh
set -e
echo "[xfce4-proot-start] inside Ubuntu as \$(id -un):\$(id -gn)"
echo "[xfce4-proot-start] DISPLAY=$D"

# Runtime env (session-scoped)
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
export DISPLAY=$D
export LANG=en_US.UTF-8
export LC_ALL=en_US.UTF-8
export GDK_BACKEND=x11
export QT_QPA_PLATFORM=xcb
export QT_XCB_NO_MITSHM=1
export LIBGL_ALWAYS_SOFTWARE=1
export GTK_USE_PORTAL=0
export NO_AT_BRIDGE=1

# Ensure ICE dir & a private XDG_RUNTIME_DIR (don’t touch /dev/shm in proot)
mkdir -p /tmp/.ICE-unix && chmod 1777 /tmp/.ICE-unix
mkdir -p "\$HOME/.run" && chmod 700 "\$HOME/.run"
export XDG_RUNTIME_DIR="\$HOME/.run"

echo "[xfce4-proot-start] launching XFCE via dbus-run-session …"
command -v xfce4-session
exec dbus-run-session -- bash -lc 'xfce4-session'
EOF
SH
chmod 0755 "$BIN/xfce4-proot-start"

cat >"$BIN/xfce4-proot-stop" <<'SH'
#!/data/data/com.termux/files/usr/bin/sh
set +e
echo "[xfce4-proot-stop] stopping XFCE in Ubuntu …"
ubuntu-proot 'killall -q xfce4-session xfwm4 xfce4-panel xfdesktop xfsettingsd || true'
echo "[xfce4-proot-stop] stopping proot and Termux:X11 …"
ubuntu-proot-u || true
x11-down || true
echo "[xfce4-proot-stop] done."
SH
chmod 0755 "$BIN/xfce4-proot-stop"

echo "✅ XFCE (proot) runtime ready."
echo "   Start: xfce4-proot-start"
echo "   Stop:  xfce4-proot-stop"
