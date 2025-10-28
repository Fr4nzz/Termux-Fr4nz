# Run an Ubuntu desktop in Termux via Termux:X11 (ROOTED with ruri)

This starts XFCE from a rooted chroot and displays it in the Termux:X11 app.

We support two launch modes:

* **Recommended:** run the XFCE session as the unprivileged `ubuntu` user.  
  - Fixes apps that refuse to run as root (VLC, etc).  
  - Avoids a bunch of warnings from desktop apps.
* **Fallback:** run the session as root (works, but some apps complain).

> TL;DR  
> 1. Start ONE Termux:X11 server on `:1` and allow both `root` and `ubuntu`.  
> 2. Enter the container with `/tmp/.X11-unix` bound.  
> 3. Inside Ubuntu, create user `ubuntu` (Step 3).  
> 4. Launch the desktop with `xfce4-chroot-start` (wrapper in Step 11).  
>
> The desktop shows in the Termux:X11 app.

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
mkdir -p "$PREFIX/tmp/.X11-unix"

export TMPDIR="$PREFIX/tmp"
termux-x11 :1 -legacy-drawing &

am start -n com.termux.x11/com.termux.x11.MainActivity >/dev/null 2>&1
sleep 2

DISPLAY=:1 xhost +LOCAL:
DISPLAY=:1 xhost +SI:localuser:$(id -un)
DISPLAY=:1 xhost +SI:localuser:root
DISPLAY=:1 xhost +SI:localuser:ubuntu

ls -l "$PREFIX/tmp/.X11-unix"   # MUST show X1 (socket)
```

If you encounter Make sure an X server isn't already running(EE) error, close Termux, then “Force stop” Termux and try again from step 1

---

## 3) Inside Ubuntu (first time): packages

```bash
# Sane env for maintainer scripts
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
export DEBIAN_FRONTEND=noninteractive

# Block service autostarts during package install inside chroot
sudo install -d /usr/sbin
sudo tee /usr/sbin/policy-rc.d >/dev/null <<'EOF'
#!/bin/sh
exit 101
EOF
sudo chmod +x /usr/sbin/policy-rc.d

sudo apt-get update -y

# Desktop bits (CORE) — explicitly include xfce4-session
sudo apt-get install -y --no-install-recommends \
  xfce4 xfce4-session xfce4-terminal \
  dbus dbus-x11 xterm fonts-dejavu-core x11-utils psmisc

# Locale
sudo sed -i 's/^# *en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen
sudo locale-gen en_US.UTF-8

# D-Bus prep (we'll run per-session later)
sudo dbus-uuidgen --ensure
sudo install -d -m 0755 /run/dbus
```

---

## 5) Inside Ubuntu (rooted): runtime & env (manual fallback)

If you entered ubuntu container before, first unmount container so when you enter again you will mount with X socket bound otherwise the X socket won't be mounted

```bash
ubuntu-chroot-u      # unmount/kill
ubuntu-chroot        # enter with X socket bound
```

```bash
# Verify the X socket bound from Termux:X11
ls -l /tmp/.X11-unix
[ -S /tmp/.X11-unix/X1 ] || echo "X socket missing (need :1). Exit and re-enter."

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

## 6) Quieter / stabler (optional) — run this **before** Start XFCE

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

## 7) Start XFCE

```bash
dbus-run-session -- bash -lc 'xfce4-session'
```

---

## 8) DPI (optional)

```bash
termux-x11 :1 -legacy-drawing -dpi 160 &
```

---

## 10) Optional: make UI prettier (install `xfce4-goodies`)

```bash
export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y xfce4 xfce4-goodies dbus-x11 \
                   xterm fonts-dejavu-core x11-utils psmisc locales
locale-gen en_US.UTF-8
```

---

## 11) Quick wrappers (runtime only)

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
  mkdir -p "$S"
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
chmod 0755 "$PREFIX/bin/x11-up"

# x11-down: stop Termux:X11
cat >"$PREFIX/bin/x11-down" <<'SH'
#!/data/data/com.termux/files/usr/bin/sh
am broadcast -a com.termux.x11.ACTION_STOP -p com.termux.x11 >/dev/null 2>&1 || true
pkill termux-x11 >/dev/null 2>&1 || true
SH
chmod 0755 "$PREFIX/bin/x11-down"

# xfce4-chroot-start: start X11, enter container, then launch XFCE as the saved user
cat >"$PREFIX/bin/xfce4-chroot-start" <<'SH'
#!/data/data/com.termux/files/usr/bin/sh
x11-up >/dev/null 2>&1 || true
ubuntu-chroot /bin/bash -lc '
  export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
  sudo mountpoint -q /proc || sudo mount -t proc proc /proc
  sudo mountpoint -q /sys  || sudo mount -t sysfs sys /sys
  sudo mkdir -p /dev/pts /dev/shm /run /tmp/.ICE-unix
  sudo mountpoint -q /dev/pts || sudo mount -t devpts devpts /dev/pts
  sudo mountpoint -q /dev/shm || sudo mount -t tmpfs -o rw,nosuid,nodev,mode=1777,size=256M tmpfs /dev/shm
  sudo chmod 1777 /tmp/.ICE-unix

  export DISPLAY=:1 LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8 GDK_BACKEND=x11 QT_QPA_PLATFORM=xcb LIBGL_ALWAYS_SOFTWARE=1
  mkdir -p "$HOME/.run" && chmod 700 "$HOME/.run"
  export XDG_RUNTIME_DIR="$HOME/.run"

  command -v xfce4-session >/dev/null || { echo "xfce4-session not installed (see Step 3)."; exit 1; }
  exec dbus-run-session -- bash -lc "xfce4-session"
'
SH
chmod 0755 "$PREFIX/bin/xfce4-chroot-start"

# xfce4-chroot-stop: stop the user session and X11
cat >"$PREFIX/bin/xfce4-chroot-stop" <<'SH'
#!/data/data/com.termux/files/usr/bin/sh
ubuntu-chroot /bin/bash -lc 'killall -q xfce4-session xfwm4 xfce4-panel xfdesktop xfsettingsd || true'
ubuntu-chroot-u || true
x11-down || true
SH
chmod 0755 "$PREFIX/bin/xfce4-chroot-stop"
```

### Usage

```bash
xfce4-chroot-start   # start/enter and launch XFCE as the saved desktop user (recommended)
xfce4-chroot-stop    # stop XFCE (user session), unmount container, stop X11
```

If it fails try force closing Termux and try again running `xfce4-chroot-start`.

---

## 12) Optional apps, desktop shortcuts, Firefox-without-snap, VS Code

All of that (including:
* Synaptic GUI package manager,
* enabling more Ubuntu repos,
* Firefox from Mozilla’s APT repo instead of Snap,
* Visual Studio Code from Microsoft’s repo,
* adding icons for apps like `synaptic`, `firefox`, `code` to the XFCE Desktop via `desktopify`)

has been moved to `INSTALL_APP_MANAGERS.md` to keep this file focused on graphics/X11.

---

## 13) Notes on GUI app managers, snaps, etc.

* **Synaptic**
  - Works well here. It’s just an APT GUI, so it doesn’t need systemd.
  - Install with `apt-get install -y synaptic`.
  - After installing, you can create a desktop icon with `desktopify synaptic` (see `INSTALL_APP_MANAGERS.md`).
* **software-properties-common** (CLI)
  - Gives you tools like `add-apt-repository`; that’s the reliable way to add PPAs / third-party repos in this container.
* **software-properties-gtk** / “Software & Updates” GUI
  - Expects a working system bus + polkit + systemd, and can get cranky in a chroot.
  - You can try to launch it, but expect auth prompts/polkit issues. CLI is safer.
* **Snap**
  - `snap install ...` won’t work here. Snapd needs systemd and a running snap daemon.
  - That’s why Firefox is installed from Mozilla’s APT repo instead of `snap install firefox` (details in `INSTALL_APP_MANAGERS.md`).
* **Flatpak**
  - Flatpak can sometimes work without systemd, but it needs user namespaces/bwrap that may not behave on every Android kernel.
  - You can experiment later, but APT repos + `.deb` packages are the stable path here.
