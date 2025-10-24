# Run an Ubuntu desktop in Termux via Termux:X11 (rooted **or** non-root)

This wires an Ubuntu userland to the **Termux:X11** app and starts an XFCE desktop.

> **TL;DR**
> Start **one** Termux:X11 server as your **Termux user**, grant local access with `xhost`, **bind `/tmp/.X11-unix`** into the container, then inside Ubuntu:
>
> ```bash
> dbus-run-session -- bash -lc 'xfce4-session'
> ```
>
> Use **ruri** (rooted chroot) or **daijin/proot** (non-root) — both flows are below.

---

## 0) Prereqs (Termux)

```bash
pkg update -y
pkg install -y x11-repo termux-x11-nightly xorg-xhost xorg-xdpyinfo
# optional while testing:
pkg install -y pulseaudio xkeyboard-config
```

Set your container paths (adjust if you use different names):

```bash
CON_ROOT="$HOME/containers/ubuntu-noble"
CON_NONROOT="$HOME/containers/ubuntu-non-root"
```

---

## 1) Download Ubuntu rootfs (your Termux-Fr4nz style)

Use your existing flow:

```bash
# Rooted or non-root: pull a Noble rootfs into the chosen directory
rurima lxc pull -o ubuntu -v noble -s "$CON_ROOT"
# For the non-root one:
rurima lxc pull -o ubuntu -v noble -s "$CON_NONROOT"
```

### (Non-root only) Register the container with **daijin**

```bash
daijin    # choose: 4) register
# Path: /data/data/com.termux/files/home/containers/ubuntu-non-root
# Backend: 2) proot
# Name: ubuntu-non-root
```

> Tip: you can keep using `$PREFIX/share/daijin/proot_start.sh` to run it (shown below).

---

## 2) Start **one** Termux:X11 server on `:1` (Termux user)

> Keep the Termux:X11 app in the foreground while testing.

```bash
# Stop any old server, prep socket dir
am broadcast -a com.termux.x11.ACTION_STOP -p com.termux.x11 || true
pkill termux-x11 || true
rm -rf "$PREFIX/tmp/.X11-unix"; mkdir -p "$PREFIX/tmp/.X11-unix"

# Start the server
export TMPDIR="$PREFIX/tmp"
termux-x11 :1 -legacy-drawing &

# Bring the app to foreground so the server finishes init
am start -n com.termux.x11/com.termux.x11.MainActivity >/dev/null 2>&1
sleep 2

# Allow local unix-socket clients (covers proot & chroot)
DISPLAY=:1 xhost +LOCAL:
# Also explicitly allow your Termux app user (nice to have)
DISPLAY=:1 xhost +SI:localuser:$(id -un)

# Sanity: MUST show an 'X1' socket (type 's')
ls -l "$PREFIX/tmp/.X11-unix"
```

---

## 3) Enter the container

### A) **Rooted (ruri)** — bind **only** the X socket dir

```bash
sudo rurima r \
  -m "$PREFIX/tmp/.X11-unix" /tmp/.X11-unix \
  -m /sdcard /root/sdcard \
  "$CON_ROOT"
```

You’re now **inside** Ubuntu (as root).

### B) **Non-root (daijin/proot)** — also bind **only** the X socket dir

```bash
"$PREFIX/share/daijin/proot_start.sh" -r "$CON_NONROOT" \
  -e "-b $PREFIX/tmp/.X11-unix:/tmp/.X11-unix -b /sdcard:/mnt/sdcard -w /root" \
  /usr/bin/env -i HOME=/root TERM=xterm-256color \
  PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin \
  /bin/bash -l
```

You’re now **inside** Ubuntu (proot, as root).

---

## 4) Inside Ubuntu: install packages (once)

> You asked to **run these inside the container**, not from Termux.

```bash
export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y xfce4 xfce4-goodies dbus-x11 \
                   xterm fonts-dejavu-core x11-utils psmisc locales
locale-gen en_US.UTF-8
```

(Optional) Create an unprivileged user:

```bash
adduser --disabled-password --gecos '' ubuntu || true
adduser ubuntu sudo || true
echo 'ubuntu ALL=(ALL) NOPASSWD: ALL' > /etc/sudoers.d/ubuntu
chmod 0440 /etc/sudoers.d/ubuntu
```

---

## 5) Inside Ubuntu: environment & runtime dirs

This part differs slightly between **rooted** and **non-root**.

### A) Rooted (ruri) — you **can** use real shared memory & system runtimes

```bash
# Verify the X socket exists
ls -l /tmp/.X11-unix   # must show: X1

# Common runtime dirs many desktops expect
mkdir -p /tmp/.ICE-unix && chmod 1777 /tmp/.ICE-unix
mkdir -p /dev/shm && chmod 1777 /dev/shm
mount | grep ' /dev/shm ' >/dev/null || mount -t tmpfs -o size=256M tmpfs /dev/shm

# Minimal user runtime dir (no systemd --user here)
mkdir -p /run/user/0 && chmod 700 /run/user/0
export XDG_RUNTIME_DIR=/run/user/0

# X/locale env
export DISPLAY=:1
export LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8
export GDK_BACKEND=x11
export QT_QPA_PLATFORM=xcb
export LIBGL_ALWAYS_SOFTWARE=1
```

If you created the `ubuntu` user and want to run the session as that user:

```bash
su - ubuntu
```

### B) Non-root (daijin/proot) — **don’t** touch `/dev/shm`; use a user runtime

As **ubuntu** (recommended) or root:

```bash
# If you created the user:
su - ubuntu

# Verify the X socket exists
ls -l /tmp/.X11-unix   # must show: X1

# proot-friendly runtime dir (no /dev/shm mounts)
mkdir -p "$HOME/.run" && chmod 700 "$HOME/.run"
export XDG_RUNTIME_DIR="$HOME/.run"

# X/locale env
export DISPLAY=:1
export LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8
export GDK_BACKEND=x11
export QT_QPA_PLATFORM=xcb
export LIBGL_ALWAYS_SOFTWARE=1
```

---

## 6) Start XFCE

Preferred (full session):

```bash
dbus-run-session -- bash -lc 'xfce4-session'
```

If you hit compositor/portal quirks, try the **minimal fallback** (no session manager):

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

## 7) (Optional) Make it quieter / stabler

Append to your **user’s** `~/.profile` (rooted or non-root):

```bash
cat >>~/.profile <<'EOF'
# X11 defaults for Termux:X11 sessions
export DISPLAY=:1
export LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8
export GDK_BACKEND=x11
export QT_QPA_PLATFORM=xcb
export LIBGL_ALWAYS_SOFTWARE=1
# Reduce portal/AT-SPI noise in proot/chroot
export GTK_USE_PORTAL=0
export NO_AT_BRIDGE=1
# proot-friendly runtime
mkdir -p "$HOME/.run" 2>/dev/null && chmod 700 "$HOME/.run"
export XDG_RUNTIME_DIR="$HOME/.run"
EOF
```

Disable compositor (helps on many phones):

```bash
xfconf-query -c xfwm4 -p /general/use_compositing -s false
```

Optionally mask noisy autostarts:

```bash
mkdir -p ~/.config/autostart
for f in xfce4-power-manager.desktop polkit-gnome-authentication-agent-1.desktop \
         xiccd.desktop xdg-desktop-portal.desktop xdg-desktop-portal-gtk.desktop
do
  [ -f /etc/xdg/autostart/$f ] || continue
  cp /etc/xdg/autostart/$f ~/.config/autostart/
  echo 'Hidden=true' >> ~/.config/autostart/$f
done
```

---

## 8) DPI / scaling (optional)

* In XFCE: *Applications → Settings → Appearance → Fonts → DPI*
* Or set it at server launch (Termux side):

```bash
termux-x11 :1 -legacy-drawing -dpi 160 &
```

---

## 9) Common problems & fixes

**Inside Ubuntu, `xdpyinfo: unable to open display ":1"`**  
Check binding & access:

```bash
ls -l /tmp/.X11-unix   # must show X1
echo "$DISPLAY"        # must be :1

# Termux side:
DISPLAY=:1 xhost       # ensure +LOCAL: (and your Termux user) are listed
```

**Black screen / odd colors**  
Keep `-legacy-drawing`; if colors invert, relaunch with `-force-bgra`:

```bash
termux-x11 :1 -legacy-drawing -force-bgra &
```

**“Tiny clock but no desktop”**  
Use the **minimal fallback** (no compositor).

**Stopping the container doesn’t kill GUI apps**  
Kill whoever still holds the socket:

```bash
# Termux:
sudo fuser -k "$PREFIX/tmp/.X11-unix/X1"

# Or inside Ubuntu:
fuser -k /tmp/.X11-unix/X1
```

---

## 10) Cleanly stopping / restarting

```bash
# Inside Ubuntu (any method)
killall -q xfce4-session xfwm4 xfce4-panel xfdesktop xfsettingsd || true
exit
```

**Rooted (ruri):**

```bash
sudo rurima r -U "$CON_ROOT"
```

**Non-root (daijin/proot):**

* Just `exit` the shell (no special stop needed).

**Termux:**

```bash
am broadcast -a com.termux.x11.ACTION_STOP -p com.termux.x11 || true
pkill termux-x11 || true
```

Then re-start from **Step 2**.

---

## 11) Handy helpers (optional)

**Termux: `x11-start`**

```bash
P=$PREFIX/bin
cat >"$P/x11-start" <<'SH'
#!/data/data/com.termux/files/usr/bin/sh
rm -rf "$PREFIX/tmp/.X11-unix"; mkdir -p "$PREFIX/tmp/.X11-unix"
export TMPDIR="$PREFIX/tmp"
termux-x11 :1 -legacy-drawing &
am start -n com.termux.x11/com.termux.x11.MainActivity >/dev/null 2>&1
sleep 2
DISPLAY=:1 xhost +LOCAL:
DISPLAY=:1 xhost +SI:localuser:$(id -un)
SH
chmod +x "$P/x11-start"
```

**Non-root launcher (uses daijin’s proot runner):**

```bash
cat >"$P/ubuntu-non-root" <<'SH'
#!/data/data/com.termux/files/usr/bin/sh
C="$HOME/containers/ubuntu-non-root"
exec "$PREFIX/share/daijin/proot_start.sh" -r "$C" \
  -e "-b $PREFIX/tmp/.X11-unix:/tmp/.X11-unix -b /sdcard:/mnt/sdcard -w /root" \
  /usr/bin/env -i HOME=/root TERM=xterm-256color \
  PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin \
  /bin/bash -l
SH
chmod +x "$P/ubuntu-non-root"
```

**Rooted quick-enter with socket bind:**

```bash
cat >"$P/ubuntu-rooted" <<'SH'
#!/data/data/com.termux/files/usr/bin/sh
C="$HOME/containers/ubuntu-noble"
exec sudo rurima r -m "$PREFIX/tmp/.X11-unix" /tmp/.X11-unix -m /sdcard /root/sdcard "$C"
SH
chmod +x "$P/ubuntu-rooted"
```

Usage:

```bash
# Termux
x11-start

# Rooted flow:
ubuntu-rooted
# then inside Ubuntu:
dbus-run-session -- bash -lc 'xfce4-session'

# Non-root flow:
ubuntu-non-root
# then inside Ubuntu (optionally su - ubuntu):
dbus-run-session -- bash -lc 'xfce4-session'
```

---

### Notes

* We **do** use `xhost +LOCAL:` (local-only). No TCP access is opened.
* Binding **only** `/tmp/.X11-unix` works consistently for both rooted and non-root.
* In non-root (proot), prefer a user runtime at `$HOME/.run` instead of touching `/dev/shm`.
* Expect warnings about systemd, UPower, portals, AT-SPI — they’re harmless in this environment; the “Quiet” section shows how to silence most of them.
