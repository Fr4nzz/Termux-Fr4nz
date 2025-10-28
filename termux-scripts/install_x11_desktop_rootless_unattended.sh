#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail

# === Termux prereqs (X11) =====================================================
pkg update -y
pkg install -y x11-repo
pkg install -y termux-x11-nightly xorg-xhost xorg-xdpyinfo >/dev/null
# optional while testing:
# pkg install -y pulseaudio xkeyboard-config

# --- Paths --------------------------------------------------------------------
PFX="${PREFIX:-/data/data/com.termux/files/usr}"
BIN="$PFX/bin"
XSOCK="$PFX/tmp/.X11-unix"
mkdir -p "$BIN" "$XSOCK"

# === x11-up / x11-down helpers (Termux) =======================================

# x11-up: start Termux:X11 (:1, fallback :2), wait for socket, grant access
cat >"$BIN/x11-up" <<'SH'
#!/data/data/com.termux/files/usr/bin/sh
set -e
P="$PREFIX"
S="$P/tmp/.X11-unix"
D=""
# clean and stop first
am broadcast -a com.termux.x11.ACTION_STOP -p com.termux.x11 >/dev/null 2>&1 || true
pkill termux-x11 >/dev/null 2>&1 || true
rm -rf "$S"; mkdir -p "$S"

try_start() {
  local disp="$1" num="${1#:}"
  TMPDIR="$P/tmp" termux-x11 "$disp" -legacy-drawing >/dev/null 2>&1 &
  am start -n com.termux.x11/com.termux.x11.MainActivity >/dev/null 2>&1 || true
  # wait up to ~5s for X socket to appear
  for _ in $(seq 1 50); do
    [ -S "$S/X${num}" ] && { D="$disp"; return 0; }
    sleep 0.1
  done
  pkill termux-x11 >/dev/null 2>&1 || true
  return 1
}

try_start :1 || try_start :2 || {
  echo "x11-up: failed to start Termux:X11 on :1 or :2" >&2
  echo "If it fails, try force-closing Termux and run `xfce4-proot-start` again." >&2
  exit 1
}

# grant access (don’t fail the script if xhost errors)
DISPLAY="$D" xhost +LOCAL: >/dev/null 2>&1 || true
DISPLAY="$D" xhost +SI:localuser:$(id -un) >/dev/null 2>&1 || true
DISPLAY="$D" xhost +SI:localuser:root >/dev/null 2>&1 || true

echo "$D" > "$S/.display"
ls -l "$S"
SH
chmod 0755 "$BIN/x11-up"

# x11-down: stop Termux:X11 and clean socket dir
cat >"$BIN/x11-down" <<'SH'
#!/data/data/com.termux/files/usr/bin/sh
set -e
am broadcast -a com.termux.x11.ACTION_STOP -p com.termux.x11 >/dev/null 2>&1 || true
pkill termux-x11 >/dev/null 2>&1 || true
rm -rf "$PREFIX/tmp/.X11-unix" || true
SH
chmod 0755 "$BIN/x11-down"

# === Desktop packages inside Ubuntu (proot, run as non-root via sudo) =========
# This assumes your setup script already created a desktop user in sudoers
# with NOPASSWD. If not, run that first.
cat <<'SH' | ubuntu-proot /bin/sh
set -e
export DEBIAN_FRONTEND=noninteractive
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

command -v sudo >/dev/null 2>&1 || { echo "sudo missing in container"; exit 1; }

# Block service autostarts during package install (harmless in proot)
sudo install -d /usr/sbin
sudo tee /usr/sbin/policy-rc.d >/dev/null <<'EOF'
#!/bin/sh
exit 101
EOF
sudo chmod +x /usr/sbin/policy-rc.d

sudo apt-get update -y
sudo apt-get install -y --no-install-recommends \
  debconf debconf-i18n init-system-helpers perl-base adduser dialog locales tzdata \
  sgml-base xml-core

# Settle anything pending
sudo dpkg --configure -a || true
sudo apt-get -o Dpkg::Options::="--force-confnew" -f install

# Desktop core (explicitly include xfce4-session)
sudo apt-get install -y --no-install-recommends \
  xfce4 xfce4-session xfce4-terminal \
  dbus dbus-x11 xterm fonts-dejavu-core x11-utils psmisc

# Locale + dbus prep
sudo sed -i 's/^# *en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen
sudo locale-gen en_US.UTF-8
sudo dbus-uuidgen --ensure
sudo install -d -m 0755 /run/dbus
SH

# === XFCE start/stop wrappers (run as your desktop user) ======================

# Start: bring X up, then pipe a script into ubuntu-proot to set env and launch
cat >"$BIN/xfce4-proot-start" <<'SH'
#!/data/data/com.termux/files/usr/bin/sh
set -e
x11-up >/dev/null 2>&1 || true

# pick the display chosen by x11-up (fallback :1)
D=":1"
F="$PREFIX/tmp/.X11-unix/.display"
[ -s "$F" ] && D="$(cat "$F" | head -n1)"

cat <<EOS | ubuntu-proot /bin/sh
set -e
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
export DISPLAY="$D"
export LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8
export GDK_BACKEND=x11
export QT_QPA_PLATFORM=xcb
export LIBGL_ALWAYS_SOFTWARE=1
export GTK_USE_PORTAL=0
export NO_AT_BRIDGE=1

# runtime dirs (user-scoped)
mkdir -p /tmp/.ICE-unix && chmod 1777 /tmp/.ICE-unix
mkdir -p "\$HOME/.run" && chmod 700 "\$HOME/.run"
export XDG_RUNTIME_DIR="\$HOME/.run"

command -v xfce4-session >/dev/null || { echo "xfce4-session not installed. Re-run the installer."; exit 1; }

exec dbus-run-session -- bash -lc 'xfce4-session'
EOS
SH
chmod 0755 "$BIN/xfce4-proot-start"

# Stop: kill XFCE processes, stop proot, bring X down
cat >"$BIN/xfce4-proot-stop" <<'SH'
#!/data/data/com.termux/files/usr/bin/sh
set +e
ubuntu-proot 'killall -q xfce4-session xfwm4 xfce4-panel xfdesktop xfsettingsd || true'
ubuntu-proot-u || true
x11-down || true
echo "XFCE (proot) stopped."
SH
chmod 0755 "$BIN/xfce4-proot-stop"

echo "✅ XFCE runtime (proot) ready. Use: xfce4-proot-start / xfce4-proot-stop"