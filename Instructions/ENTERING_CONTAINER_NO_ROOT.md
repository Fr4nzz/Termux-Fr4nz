# Entering the container (no-root path with **Daijin**)

Daijin runs Ubuntu rootfs containers on Termux without root by wrapping **proot**. It can “register” an existing rootfs dir and start it.

> If you have root, prefer the rooted path in [ENTERING_CONTAINER_ROOT.md](./ENTERING_CONTAINER_ROOT.md).

---

## 1) Install Daijin on Termux

```bash
pkg update -y
curl -LO https://github.com/RuriOSS/daijin/releases/download/daijin-v1.5-rc1/daijin-aarch64.deb
# Use apt so dependencies are resolved automatically:
apt install -y ./daijin-aarch64.deb
```

Daijin provides helpers like `register.sh` and a proot starter `proot_start.sh` under `$PREFIX/share/daijin`.

---

## 2) Pull & register your NON-ROOT Ubuntu rootfs with Daijin

Use a separate path for rootless testing:

```bash
CONTAINER="$HOME/containers/ubuntu-proot"
rurima lxc list
rurima lxc pull -o ubuntu -v noble -s "$CONTAINER"
```

Register with Daijin:

```bash
/data/data/com.termux/files/usr/share/daijin/register.sh  # or run `daijin` and choose [4] register
# Path:    /data/data/com.termux/files/home/containers/ubuntu-proot
# Backend: proot
# Name:    ubuntu-proot
```

The script asks for a name, defaults to **proot** for non-root usage, and writes a config in `$PREFIX/var/daijin/containers/<name>.conf`.

---

## One-time setup (inside Ubuntu): networking fix + set TERM + create desktop user

```bash
# Set your ROOTLESS container path (matches your earlier step)
CONTAINER="$HOME/containers/ubuntu-proot"

# Ask for a desktop username (default: legend)
read -rp "Desktop username [legend]: " U; U="${U:-legend}"

# 1) Fix networking/permissions in a minimal image
curl -fsSL https://raw.githubusercontent.com/RuriOSS/daijin/refs/heads/main/src/share/fixup.sh \
  | "$PREFIX/share/daijin/proot_start.sh" -r "$CONTAINER" \
    /usr/bin/env -i HOME=/root TERM=xterm-256color \
    PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin \
    /bin/sh

# 2) Create user, grant NOPASSWD sudo, remember the name, set TERM for root + user
"$PREFIX/share/daijin/proot_start.sh" -r "$CONTAINER" \
  /bin/sh -lc "
  set -e
  adduser --disabled-password --gecos '' '$U' || true
  adduser '$U' sudo || true
  echo '$U ALL=(ALL) NOPASSWD: ALL' > /etc/sudoers.d/99-$U
  chmod 0440 /etc/sudoers.d/99-$U

  # Remember the chosen user for wrappers
  install -d -m 0755 /etc/ruri
  printf '%s\n' '$U' > /etc/ruri/user

  # Per-user runtime dir
  install -d -m 0700 -o '$U' -g '$U' /home/'$U'/.run

  # TERM defaults
  echo 'export TERM=xterm-256color' >> /root/.bashrc
  su - '$U' -c \"echo 'export TERM=xterm-256color' >> ~/.bashrc\"
"

echo
echo "✅ Created user '$U' with passwordless sudo."
echo "👉 For RStudio Server logins, set a password later:"
echo "   $PREFIX/share/daijin/proot_start.sh -r \"$CONTAINER\" /usr/bin/passwd '$U'"
```

---

## 4) Start the container

### Option A — `ubuntu-proot` helper (X11-ready + storage bind)

This wrapper does three things up front:
- binds `/sdcard` into the container,
- binds the Termux:X11 socket into `/tmp/.X11-unix`,
- logs you in as the saved desktop user.

We always include those mounts even if you’re just doing CLI or R/RStudio and not using a desktop yet.  
Result: you can later launch XFCE/X11 without having to “unmount and re-enter with different args.”

It supports both interactive shells and one-off commands.

```bash
P=/data/data/com.termux/files/usr
cat >"$P/bin/ubuntu-proot" <<'SH'
#!/data/data/com.termux/files/usr/bin/sh
# Enter the rootless Ubuntu container (daijin/proot) as the saved desktop user.
: "${PREFIX:=/data/data/com.termux/files/usr}"
C="/data/data/com.termux/files/home/containers/ubuntu-proot"
TP="/data/data/com.termux/files/usr/tmp/.X11-unix"
U="$(cat "$C/etc/ruri/user")"

if [ "$#" -gt 0 ]; then
  exec "$PREFIX/share/daijin/proot_start.sh" \
    -r "$C" \
    -e "-b $TP:/tmp/.X11-unix -b /sdcard:/mnt/sdcard -w /root" \
    /bin/su - "$U" -c "$*"
else
  exec "$PREFIX/share/daijin/proot_start.sh" \
    -r "$C" \
    -e "-b $TP:/tmp/.X11-unix -b /sdcard:/mnt/sdcard -w /root" \
    /bin/su - "$U"
fi
SH
chmod 0755 "$P/bin/ubuntu-proot"
hash -r
```

Usage:

```bash
ubuntu-proot               # default login shell in the container
ubuntu-proot /bin/bash -lc 'uname -a'  # run a one-off command
```

### Option B — via Daijin’s TUI

```bash
daijin
# Choose “[2] run”, then pick `ubuntu-proot`
```

---

## 5) Accessing phone storage

If you haven’t yet:

```bash
termux-setup-storage
```

With the helper above, your phone’s `/sdcard` is available at `/mnt/sdcard` in Ubuntu. (We pass this via the `-e` “extra args” hook to Daijin’s starter, which appends them to its proot command line.)

---

## 6) Cleanup / stop

There’s no “unmount” step for proot. **Exiting** the shell ends the proot process and all children. If you background tasks and need to nuke them from another Termux session:

```bash
pgrep -fa 'proot .*containers/ubuntu-proot'   # inspect
pkill -f  'proot .*containers/ubuntu-proot'   # kill
```

---

## 7) Tips

* If you ever see “TERM environment variable not set”, run this from Termux once to persist the fix:

  ```bash
  ubuntu-proot /bin/sh -c "echo 'export TERM=xterm-256color' >> /root/.bashrc"
  ```

* To run one command non-interactively:

  ```bash
  ubuntu-proot apt-get update
  ```

* Want the sdcard bind permanently from the config? Add to the container’s Daijin `.conf`:

  ```
  extra_args="-b /sdcard:/mnt/sdcard -w /root"
  ```
