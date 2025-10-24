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
CONTAINER="$HOME/containers/ubuntu-rootless"
rurima lxc list
rurima lxc pull -o ubuntu -v noble -s "$CONTAINER"
```

Register with Daijin:

```bash
/data/data/com.termux/files/usr/share/daijin/register.sh  # or run `daijin` and choose [4] register
# Path:    /data/data/com.termux/files/home/containers/ubuntu-rootless
# Backend: proot
# Name:    ubuntu-rootless
```

The script asks for a name, defaults to **proot** for non-root usage, and writes a config in `$PREFIX/var/daijin/containers/<name>.conf`.

---

## 3) One-time container fixups (before first login)

Fix networking and a few permissions **inside** Ubuntu by piping Daijin’s `fixup.sh` into a minimal shell:

```bash
curl -fsSL https://raw.githubusercontent.com/RuriOSS/daijin/refs/heads/main/src/share/fixup.sh \
  | "$PREFIX/share/daijin/proot_start.sh" -r "$CONTAINER" \
    /usr/bin/env -i HOME=/root TERM=xterm-256color \
    PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin \
    /bin/sh
```

Why this matters:

* Adjusts `_apt` and related groups so apt works without warnings.
* Rewrites `/etc/resolv.conf` so DNS works immediately.
* Uses Daijin’s starter, which already mounts `/dev`, `/proc`, `/sys`, sets `-w /root`, and applies the usual proot shims.

---

## 4) Start the container

### Option A — `ubuntu-rootless` helper (binds `/sdcard`, sane env)

```bash
P=/data/data/com.termux/files/usr
cat >"$P/bin/ubuntu-rootless" <<'SH'
#!/data/data/com.termux/files/usr/bin/sh
C="/data/data/com.termux/files/home/containers/ubuntu-rootless"
E="/usr/bin/env -i HOME=/root TERM=xterm-256color \
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
exec "$PREFIX/share/daijin/proot_start.sh" \
  -r "$C" \
  -e "-b /sdcard:/root/sdcard -w /root" \
  $E /bin/su - root -l "$@"
SH
chmod 0755 "$P/bin/ubuntu-rootless"
hash -r
```

Usage:

```bash
ubuntu-rootless               # default login shell in the container
ubuntu-rootless /bin/bash -lc 'uname -a'  # run a one-off command
```

### Option B — via Daijin’s TUI

```bash
daijin
# Choose “[2] run”, then pick `ubuntu-rootless`
```

---

## 5) Accessing phone storage

If you haven’t yet:

```bash
termux-setup-storage
```

With the helper above, your phone’s `/sdcard` appears as `~/sdcard` in Ubuntu. (We pass this via the `-e` “extra args” hook to Daijin’s starter, which appends them to its proot command line.)

---

## 6) Cleanup / stop

There’s no “unmount” step for proot. **Exiting** the shell ends the proot process and all children. If you background tasks and need to nuke them from another Termux session:

```bash
pgrep -fa 'proot .*containers/ubuntu-rootless'   # inspect
pkill -f  'proot .*containers/ubuntu-rootless'   # kill
```

---

## 7) Tips

* If you ever see “TERM environment variable not set”, inside Ubuntu:

  ```bash
  export TERM=xterm-256color
  echo 'export TERM=xterm-256color' >> /root/.bashrc
  ```

* To run one command non-interactively:

  ```bash
  ubuntu-rootless apt-get update
  ```

* Want the sdcard bind permanently from the config? Add to the container’s Daijin `.conf`:

  ```
  extra_args="-b /sdcard:/root/sdcard -w /root"
  ```
