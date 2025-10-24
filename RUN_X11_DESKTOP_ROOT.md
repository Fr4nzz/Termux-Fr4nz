# Run an Ubuntu desktop in Termux via Termux:X11 (ROOTED with ruri)

This starts XFCE from a rooted chroot and displays it in the Termux:X11 app.

> TL;DR
> Start ONE Termux:X11 server on :1 (as your Termux user), grant local access with `xhost`, **bind only `/tmp/.X11-unix`** when entering the container, then inside Ubuntu run:
>
> ```bash
> dbus-run-session -- bash -lc 'xfce4-session'
> ```

---

## 0) Prereqs (Termux)

```bash
pkg update -y
pkg install -y x11-repo # Install this first to be able to install the following:
pkg install -y termux-x11-nightly xorg-xhost xorg-xdpyinfo
# optional while testing:
pkg install -y pulseaudio xkeyboard-config
```

---

## 1) Start ONE Termux:X11 server on :1

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
DISPLAY=:1 xhost +SI:localuser:root

ls -l "$PREFIX/tmp/.X11-unix"   # MUST show X1 (socket)
```

---

## 2) Replace the “enter” wrapper for ROOT with X11 bind

```bash
P="$PREFIX/bin"
cat >"$P/ubuntu-root" <<'SH'
#!/data/data/com.termux/files/usr/bin/sh
C="$HOME/containers/ubuntu-root"
TP="/data/data/com.termux/files/usr/tmp/.X11-unix"
exec sudo rurima r \
  -m "$TP" /tmp/.X11-unix \
  -m /sdcard /root/sdcard \
  "$C" "$@"
SH
chmod 0755 "$P/ubuntu-root"

cat >"$P/ubuntu-root-u" <<'SH'
#!/data/data/com.termux/files/usr/bin/sh
C="$HOME/containers/ubuntu-root"
exec sudo rurima r -U "$C"
SH
chmod 0755 "$P/ubuntu-root-u"
hash -r
```

Usage:

```bash
ubuntu-root        # enter with X socket bound (first have to unmount to mount a new directory)
ubuntu-root-u      # unmount/kill
```

---

## 3) Inside Ubuntu (first time): packages

```bash
# Sane env for maintainer scripts
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
export DEBIAN_FRONTEND=noninteractive

# Block service autostarts during package install inside chroot
install -d /usr/sbin
cat >/usr/sbin/policy-rc.d <<'EOF'
#!/bin/sh
exit 101
EOF
chmod +x /usr/sbin/policy-rc.d

apt-get update -y

# Ensure debconf/dpkg helpers exist BEFORE anything else
apt-get install -y --no-install-recommends debconf

# Common helpers many postinsts need
apt-get install -y --reinstall --no-install-recommends \
  debconf-i18n init-system-helpers perl-base adduser dialog locales tzdata

# sgml/xml helpers (provides update-catalog) then settle anything pending
apt-get install -y --reinstall --no-install-recommends sgml-base xml-core
dpkg --configure -a || true
apt-get -o Dpkg::Options::="--force-confnew" -f install

# Desktop bits (CORE) — explicitly include xfce4-session
apt-get install -y --no-install-recommends \
  xfce4 xfce4-session xfce4-terminal \
  dbus dbus-x11 xterm fonts-dejavu-core x11-utils psmisc

# Locale
sed -i 's/^# *en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen
locale-gen en_US.UTF-8

# D-Bus prep (we'll run per-session later)
dbus-uuidgen --ensure
mkdir -p /run/dbus

# Optional unprivileged user
adduser --disabled-password --gecos '' ubuntu || true
adduser ubuntu sudo || true
echo 'ubuntu ALL=(ALL) NOPASSWD: ALL' >/etc/sudoers.d/ubuntu
chmod 0440 /etc/sudoers.d/ubuntu
```

---

## 4) Inside Ubuntu (rooted): runtime & env

If you entered ubuntu container before, first unmount container so when you enter again you will mount with X socket bound otherwise the X socket won't be mounted

```bash
ubuntu-root-u      # unmount/kill
ubuntu-root        # enter with X socket bound
```

```bash
# Verify the X socket bound from Termux:X11
ls -l /tmp/.X11-unix
[ -S /tmp/.X11-unix/X1 ] || { echo "X socket missing (need :1). Exit and re-enter."; exit 1; }

# Minimal chroot mounts (idempotent, single version)
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
mountpoint -q /proc     || mount -t proc   proc   /proc
mountpoint -q /sys      || mount -t sysfs  sys    /sys
mkdir -p /dev/pts /dev/shm /run
mountpoint -q /dev/pts  || mount -t devpts devpts /dev/pts
mountpoint -q /dev/shm  || mount -t tmpfs  -o rw,nosuid,nodev,mode=1777,size=256M tmpfs /dev/shm
mkdir -p /tmp/.ICE-unix && chmod 1777 /tmp/.ICE-unix

# Per-session runtime
mkdir -p /run/user/0 && chmod 700 /run/user/0
export XDG_RUNTIME_DIR=/run/user/0

# Session env
export DISPLAY=:1
export LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8
export GDK_BACKEND=x11
export QT_QPA_PLATFORM=xcb
export LIBGL_ALWAYS_SOFTWARE=1
```

(If using the `ubuntu` user: `su - ubuntu` and set the same env, but use `XDG_RUNTIME_DIR=$HOME/.run`.)

---

## 5) Quieter / stabler (optional) — run this **before** Start XFCE

```bash
cat >>~/.profile <<'EOF'
export DISPLAY=:1
export LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8
export GDK_BACKEND=x11
export QT_QPA_PLATFORM=xcb
export LIBGL_ALWAYS_SOFTWARE=1
export GTK_USE_PORTAL=0
export NO_AT_BRIDGE=1
EOF

xfconf-query -c xfwm4 -p /general/use_compositing -s false
```

---

## 6) Start XFCE

```bash
dbus-run-session -- bash -lc 'xfce4-session'
```

---

## 7) DPI (optional)

```bash
termux-x11 :1 -legacy-drawing -dpi 160 &
```

---

## 8) Restart/stop

```bash
# inside Ubuntu
killall -q xfce4-session xfwm4 xfce4-panel xfdesktop xfsettingsd || true
exit

# Termux
ubuntu-root-u
am broadcast -a com.termux.x11.ACTION_STOP -p com.termux.x11 || true
pkill termux-x11 || true
```

---

## 9) Optional: make UI prettier (install `xfce4-goodies`)

```bash
export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y xfce4 xfce4-goodies dbus-x11 \
                   xterm fonts-dejavu-core x11-utils psmisc locales
locale-gen en_US.UTF-8
```