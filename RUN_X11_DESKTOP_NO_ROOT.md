# Run an Ubuntu desktop in Termux via Termux:X11 (NON-ROOT with daijin/proot)

This starts XFCE from a proot container and displays it in Termux:X11.

> TL;DR  
> Start ONE Termux:X11 server on :1 (Termux user), `xhost +LOCAL:`, **bind only `/tmp/.X11-unix`** in your proot args, then inside Ubuntu:
>
> ```bash
> dbus-run-session -- bash -lc 'xfce4-session'
> ```

---

## 0) Prereqs (Termux)

```bash
pkg update -y
pkg install -y x11-repo termux-x11-nightly xorg-xhost xorg-xdpyinfo
# optional while testing:
pkg install -y pulseaudio xkeyboard-config
```

---

## 1) Pull/create the NON-ROOT container (separate path) + register

```bash
CONTAINER="$HOME/containers/ubuntu-rootless"
rurima lxc list      # browse images
rurima lxc pull -o ubuntu -v noble -s "$CONTAINER"

# register with daijin (TUI) OR via script:
daijin     # choose: [4] register
# Path:    /data/data/com.termux/files/home/containers/ubuntu-rootless
# Backend: 2) proot
# Name:    ubuntu-rootless
```

One-time Daijin fixups (recommended):

```bash
curl -fsSL https://raw.githubusercontent.com/RuriOSS/daijin/refs/heads/main/src/share/fixup.sh \
  | "$PREFIX/share/daijin/proot_start.sh" -r "$CONTAINER" \
    /usr/bin/env -i HOME=/root TERM=xterm-256color \
    PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin \
    /bin/sh
```

---

## 2) Start ONE Termux:X11 server on :1

```bash
am broadcast -a com.termux.x11.ACTION_STOP -p com.termux.x11 || true
pkill termux-x11 || true
rm -rf "$PREFIX/tmp/.X11-unix"; mkdir -p "$PREFIX/tmp/.X11-unix"

export TMPDIR="$PREFIX/tmp"
termux-x11 :1 -legacy-drawing &

am start -n com.termux.x11/com.termux.x11.MainActivity >/dev/null 2>&1
sleep 2

DISPLAY=:1 xhost +LOCAL:
DISPLAY=:1 xhost +SI:localuser:$(id -un)

ls -l "$PREFIX/tmp/.X11-unix"
```

---

## 3) Replace the “enter” wrapper for NON-ROOT with X11 bind

```bash
P="$PREFIX/bin"
cat >"$P/ubuntu-rootless" <<'SH'
#!/data/data/com.termux/files/usr/bin/sh
C="$HOME/containers/ubuntu-rootless"
TP="/data/data/com.termux/files/usr/tmp/.X11-unix"
exec "$PREFIX/share/daijin/proot_start.sh" -r "$C" \
  -e "-b $TP:/tmp/.X11-unix -b /sdcard:/mnt/sdcard -w /root" \
  /usr/bin/env -i HOME=/root TERM=xterm-256color \
  PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin \
  /bin/bash -l
SH
chmod 0755 "$P/ubuntu-rootless"

cat >"$P/ubuntu-rootless-u" <<'SH'
#!/data/data/com.termux/files/usr/bin/sh
# Best-effort stop for matching proot session
C="$HOME/containers/ubuntu-rootless"
pkill -f "proot .*${C}" || true
SH
chmod 0755 "$P/ubuntu-rootless-u"
hash -r
```

Usage:

```bash
ubuntu-rootless     # enter with X socket bound
ubuntu-rootless-u   # kill matching proot if needed
```

---

## 4) Inside Ubuntu (first time): packages

```bash
## 4) Inside Ubuntu (first time): packages (proot, no service starts)

# Sane env for maintainer scripts
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
export DEBIAN_FRONTEND=noninteractive

apt-get update -y

# Ensure debconf exists first so /usr/sbin/dpkg-preconfigure is present
apt-get install -y --no-install-recommends debconf

# Pre-install helpers that many maintainer scripts expect
apt-get install -y --no-install-recommends \
  debconf-i18n init-system-helpers perl-base adduser dialog \
  locales tzdata sgml-base xml-core emacsen-common

# Desktop bits
apt-get install -y --no-install-recommends \
  xfce4 xfce4-goodies dbus dbus-x11 \
  xterm fonts-dejavu-core x11-utils psmisc locales

# Locale
sed -i 's/^# *en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen
locale-gen en_US.UTF-8

# Prepare D-Bus (proot-friendly; actual session uses dbus-run-session)
dbus-uuidgen --ensure
mkdir -p /run/dbus

# optional unprivileged user:
adduser --disabled-password --gecos '' ubuntu || true
adduser ubuntu sudo || true
echo 'ubuntu ALL=(ALL) NOPASSWD: ALL' >/etc/sudoers.d/ubuntu
chmod 0440 /etc/sudoers.d/ubuntu
```

---

## 5) Inside Ubuntu (non-root/proot): runtime & env

```bash
ls -l /tmp/.X11-unix     # must show: X1

# user-scoped runtime (don’t touch /dev/shm in proot)
mkdir -p "$HOME/.run" && chmod 700 "$HOME/.run"
export XDG_RUNTIME_DIR="$HOME/.run"

export DISPLAY=:1
export LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8
export GDK_BACKEND=x11
export QT_QPA_PLATFORM=xcb
export LIBGL_ALWAYS_SOFTWARE=1
```

---

## 6) Start XFCE

Preferred:

```bash
dbus-run-session -- bash -lc 'xfce4-session'
```

Minimal fallback (no compositor):

```bash
dbus-run-session sh -lc '
  xfsettingsd &
  xfwm4 --compositor=off --vblank=off --sm-client-disable &
  sleep 1
  xfce4-panel --disable-wm-check --sm-client-disable &
  xfdesktop --sm-client-disable &
  xterm -fa "DejaVu Sans Mono" -fs 12 &
  wait
'
```

---

## 7) Quieter / stabler (optional)

```bash
cat >>~/.profile <<'EOF'
export DISPLAY=:1
export LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8
export GDK_BACKEND=x11
export QT_QPA_PLATFORM=xcb
export LIBGL_ALWAYS_SOFTWARE=1
export GTK_USE_PORTAL=0
export NO_AT_BRIDGE=1
mkdir -p "$HOME/.run" 2>/dev/null && chmod 700 "$HOME/.run"
export XDG_RUNTIME_DIR="$HOME/.run"
EOF

xfconf-query -c xfwm4 -p /general/use_compositing -s false
```

---

## 8) DPI (optional)

```bash
termux-x11 :1 -legacy-drawing -dpi 160 &
```

---

## 9) Restart/stop

```bash
# inside Ubuntu
killall -q xfce4-session xfwm4 xfce4-panel xfdesktop xfsettingsd || true
exit

# Termux
ubuntu-rootless-u || true
am broadcast -a com.termux.x11.ACTION_STOP -p com.termux.x11 || true
pkill termux-x11 || true
```
