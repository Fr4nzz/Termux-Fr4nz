# Entering the container (rooted path with `sudo rurima r`)

Uses real Linux namespaces/mounts (fast & feature-complete). Requires root (Magisk/etc).  
If you don’t have root, see [ENTERING_CONTAINER_NO_ROOT.md](./ENTERING_CONTAINER_NO_ROOT.md).

## Install `tsu` so `sudo` is available inside Termux:

```bash
pkg install -y tsu
```

## Get an Ubuntu rootfs (separate path for ROOT testing)

```bash
CONTAINER="$HOME/containers/ubuntu-chroot"
rurima lxc pull -o ubuntu -v noble -s "$CONTAINER"
```

## First run (inside Ubuntu): networking fix + set TERM + create desktop user

```bash
# Set your ROOTED container path (matches your earlier step)
CONTAINER="$HOME/containers/ubuntu-chroot"

# Ask for a desktop username (default: legend)
read -rp "Desktop username [legend]: " U; U="${U:-legend}"

# 1) Fix networking/permissions in a minimal image
curl -fsSL https://raw.githubusercontent.com/RuriOSS/daijin/refs/heads/main/src/share/fixup.sh \
  | sudo rurima r "$CONTAINER" /bin/sh

# 2) Create user, grant NOPASSWD sudo, remember the name, set TERM for root + user
sudo rurima r "$CONTAINER" /bin/bash -lc "
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

  # TERM defaults for future logins
  echo 'export TERM=xterm-256color' >> /root/.bashrc
  su - '$U' -c \"echo 'export TERM=xterm-256color' >> ~/.bashrc\"
"

echo
echo "✅ Created user '$U' with passwordless sudo."
echo "👉 For RStudio Server logins, set a password later:"
echo "   sudo rurima r \"$CONTAINER\" /usr/bin/passwd '$U'"
```

## Enter the container

````md
You can enter as **root** (maintenance) or as **your desktop user** (daily use).

**Root shell:**
```bash
sudo rurima r "$HOME/containers/ubuntu-chroot"
```

**Login directly as your desktop user (recommended):**

```bash
U="$(cat "$HOME/containers/ubuntu-chroot/etc/ruri/user")"
sudo rurima r -E "$U" "$HOME/containers/ubuntu-chroot"
```

**Bind /sdcard example (root shell):**

```bash
sudo rurima r -m /sdcard /mnt/sdcard "$HOME/containers/ubuntu-chroot"
```

````

## Optional helpers (recommended wrappers with desktop-friendly mounts)

We install two Termux commands into `$PREFIX/bin`:

- `ubuntu-chroot`: enter the rooted Ubuntu container.
- `ubuntu-chroot-u`: unmount/kill it.

These wrappers always:
- bind `/sdcard` into the container,
- bind the Termux:X11 socket into `/tmp/.X11-unix`.

That means you can run CLI stuff, RStudio Server, or later launch XFCE/X11, all under the same session layout. No “unmount and re-enter with different -m args” just because you decided to start a desktop.

```bash
P=/data/data/com.termux/files/usr
cat >"$P/bin/ubuntu-chroot" <<'SH'
#!/data/data/com.termux/files/usr/bin/sh
# Enter the rooted Ubuntu container as the saved desktop user.
C="$HOME/containers/ubuntu-chroot"
TP="/data/data/com.termux/files/usr/tmp/.X11-unix"
U="$(cat "$C/etc/ruri/user")"

exec sudo rurima r \
  -m "$TP" /tmp/.X11-unix \
  -m /sdcard /mnt/sdcard \
  -E "$U" \
  "$C" "$@"
SH
chmod 0755 "$P/bin/ubuntu-chroot"

cat >"$P/bin/ubuntu-chroot-u" <<'SH'
#!/data/data/com.termux/files/usr/bin/sh
C="$HOME/containers/ubuntu-chroot"
exec /data/data/com.termux/files/usr/bin/sudo /data/data/com.termux/files/usr/bin/rurima r -U "$C"
SH
chmod 0755 "$P/bin/ubuntu-chroot-u"
hash -r
```

Usage:

```bash
ubuntu-chroot
ubuntu-chroot /bin/bash -l
ubuntu-chroot-u
```
