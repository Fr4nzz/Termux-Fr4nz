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

ls -l "$PREFIX/tmp/.X11-unix"
```

If you see **“Make sure an X server isn’t already running (EE)”**, close Termux, **Force stop** Termux, then try again from step 1.

---

## 2) Replace the “enter” wrapper for NON-ROOT with X11 bind

```bash
P="$PREFIX/bin"
cat >"$P/ubuntu-rootless" <<'SH'
#!/data/data/com.termux/files/usr/bin/sh
C="$HOME/containers/ubuntu-rootless"
TP="/data/data/com.termux/files/usr/tmp/.X11-unix"
if [ "$#" -gt 0 ]; then
  exec "$PREFIX/share/daijin/proot_start.sh" -r "$C" \
    -e "-b $TP:/tmp/.X11-unix -b /sdcard:/mnt/sdcard -w /root" \
    /usr/bin/env -i HOME=/root TERM=xterm-256color \
    PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin \
    /bin/bash -lc "$*"
else
  exec "$PREFIX/share/daijin/proot_start.sh" -r "$C" \
    -e "-b $TP:/tmp/.X11-unix -b /sdcard:/mnt/sdcard -w /root" \
    /usr/bin/env -i HOME=/root TERM=xterm-256color \
    PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin \
    /bin/bash -l
fi
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
ubuntu-rootless          # enter interactively with X socket bound
ubuntu-rootless 'echo hi'  # run a command non-interactively (now supported)
ubuntu-rootless-u        # kill matching proot if needed
```

---

## 3) Inside Ubuntu (first time): packages

```bash
# Sane env for maintainer scripts
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
export DEBIAN_FRONTEND=noninteractive

# Block service autostarts during package install (harmless in proot, prevents noisy postinsts)
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

# D-Bus prep (session uses dbus-run-session)
dbus-uuidgen --ensure
mkdir -p /run/dbus

# Optional unprivileged user
adduser --disabled-password --gecos '' ubuntu || true
adduser ubuntu sudo || true
echo 'ubuntu ALL=(ALL) NOPASSWD: ALL' >/etc/sudoers.d/ubuntu
chmod 0440 /etc/sudoers.d/ubuntu
```

---

## 4) Inside Ubuntu (non-root/proot): runtime & env

```bash
ls -l /tmp/.X11-unix     # must show: X1

# user-scoped runtime (don’t touch /dev/shm in proot)
mkdir -p "$HOME/.run" && chmod 700 "$HOME/.run"
export XDG_RUNTIME_DIR="$HOME/.run"

# Session env
export DISPLAY=:1
export LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8
export GDK_BACKEND=x11
export QT_QPA_PLATFORM=xcb
export LIBGL_ALWAYS_SOFTWARE=1
```

(If you use the `ubuntu` user, `su - ubuntu` and set the same env.)

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
mkdir -p "$HOME/.run" 2>/dev/null && chmod 700 "$HOME/.run"
export XDG_RUNTIME_DIR="$HOME/.run"
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
ubuntu-rootless-u || true
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

---

## 10) Quick wrappers (runtime only)

Create once in Termux; then you’ll use only the `*-start` / `*-stop` commands each time.

```bash
# x11-up: ensure Termux:X11 :1 is running and access is granted
cat >"$PREFIX/bin/x11-up" <<'SH'
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
ls -l "$S"
SH
chmod 0755 "$PREFIX/bin/x11-up"

# x11-down: stop Termux:X11
cat >"$PREFIX/bin/x11-down" <<'SH'
#!/data/data/com.termux/files/usr/bin/sh
am broadcast -a com.termux.x11.ACTION_STOP -p com.termux.x11 >/dev/null 2>&1 || true
pkill termux-x11 >/dev/null 2>&1 || true
SH
chmod 0755 "$PREFIX/bin/x11-down"

# xfce4-rootless-start: start X11, enter proot, prep runtime, launch XFCE
cat >"$PREFIX/bin/xfce4-rootless-start" <<'SH'
#!/data/data/com.termux/files/usr/bin/sh
x11-up >/dev/null 2>&1 || true
ubuntu-rootless '
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
export DISPLAY=:1 LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8 GDK_BACKEND=x11 QT_QPA_PLATFORM=xcb LIBGL_ALWAYS_SOFTWARE=1
mkdir -p /tmp/.ICE-unix && chmod 1777 /tmp/.ICE-unix
mkdir -p "$HOME/.run" && chmod 700 "$HOME/.run"
export XDG_RUNTIME_DIR="$HOME/.run"
command -v xfce4-session >/dev/null || { echo "xfce4-session not installed (run Step 3)."; exit 1; }
exec dbus-run-session -- bash -lc "xfce4-session"
'
SH
chmod 0755 "$PREFIX/bin/xfce4-rootless-start"

# xfce4-rootless-stop: gracefully stop XFCE, stop proot, stop X11
cat >"$PREFIX/bin/xfce4-rootless-stop" <<'SH'
#!/data/data/com.termux/files/usr/bin/sh
ubuntu-rootless 'killall -q xfce4-session xfwm4 xfce4-panel xfdesktop xfsettingsd || true'
ubuntu-rootless-u || true
x11-down || true
SH
chmod 0755 "$PREFIX/bin/xfce4-rootless-stop"
```

### Usage

```bash
xfce4-rootless-start   # start/enter and launch XFCE (proot)
xfce4-rootless-stop    # stop XFCE, stop proot, stop X11
```

If it fails, try force-closing Termux and run `xfce4-rootless-start` again.

---

## 11) App installs, Firefox-without-snap, VS Code, Desktop icons

For things like:
* Synaptic GUI package manager,
* enabling `universe`/`multiverse` so you see more software,
* Firefox from Mozilla’s APT repo instead of Snap (Snap doesn't work in proot either),
* Visual Studio Code from Microsoft’s repo,
* adding launchers to the XFCE Desktop using a helper script (`desktopify`),

see `INSTALL_APP_MANAGERS.md`.

That file is shared by both the rooted and the rootless setups so we don't duplicate steps.
