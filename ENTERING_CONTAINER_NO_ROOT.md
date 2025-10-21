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

## 2) Register your existing Ubuntu rootfs with Daijin

If you followed the repo’s steps, your rootfs is here:

```bash
CONTAINER="$HOME/containers/ubuntu-noble"
```

Run Daijin’s register helper and answer the prompts:

```bash
/data/data/com.termux/files/usr/share/daijin/register.sh  # or run `daijin` and choose [4] register
# Path:    /data/data/com.termux/files/home/containers/ubuntu-noble
# Backend: proot  (default for no-root)
# Name:    ubuntu-noble
```

The script asks for a name and defaults to **proot** for non-root usage; it writes a config in `$PREFIX/var/daijin/containers/<name>.conf`.

---

## 3) One-time container fixups (before first login)

Fix networking and a few permissions **inside** Ubuntu by piping Daijin’s `fixup.sh` into a minimal shell. We call Daijin’s proot starter directly and **inject a sane PATH** so this works even on a pristine rootfs:

```bash
CONTAINER="$HOME/containers/ubuntu-noble"
curl -fsSL https://raw.githubusercontent.com/RuriOSS/daijin/refs/heads/main/src/share/fixup.sh \
  | "$PREFIX/share/daijin/proot_start.sh" -r "$CONTAINER" \
    /usr/bin/env -i HOME=/root TERM=xterm-256color \
    PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin \
    /bin/sh
```

Why this matters:

* Daijin’s fixup adjusts `_apt` (and `portage`) group membership, which prevents apt/gentoo quirks later.
* It also rewrites `resolv.conf` so name resolution works right away.
* Daijin’s proot starter already mounts `/dev`, `/sys`, `/proc`, sets `-w /root`, and adds safe `/proc/*` shims for proot containers.

---

## 4) Start the container

### Option A — `ubuntu` helper (binds `/sdcard`, sets a sane env)

Create a tiny wrapper that calls Daijin’s starter with a **login shell** and a clean environment (so `ls`, `id`, etc. work):

```bash
P=/data/data/com.termux/files/usr
cat >"$P/bin/ubuntu" <<'SH'
#!/data/data/com.termux/files/usr/bin/sh
C="$HOME/containers/ubuntu-noble"

# Minimal, known-good environment so core tools work in pristine rootfs
E="/usr/bin/env -i HOME=/root TERM=xterm-256color \
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"

# Use a proper *login* shell through su (same vibe as Daijin's [run])
exec "$PREFIX/share/daijin/proot_start.sh" \
  -r "$C" \
  -e "-b /sdcard:/root/sdcard -w /root" \
  $E /bin/su - root -l "$@"
SH
chmod 0755 "$P/bin/ubuntu"
hash -r
```

Usage:

```bash
ubuntu               # default login shell in the container
ubuntu /bin/bash -lc 'uname -a'  # run a one-off command
```

> Notes: Daijin’s `proot_start.sh` takes `-r <rootfs>` and optional `-e "<extra proot args>"`, then the command; if no command is given it defaults to `/bin/su - root` or `/bin/sh`.

### Option B — via Daijin’s TUI

```bash
daijin
# Choose “[2] run”, then pick `ubuntu-noble`
```

---

## 5) Accessing phone storage

If you haven’t yet:

```bash
termux-setup-storage
```

With the helper above, your phone’s `/sdcard` appears as `~/sdcard` in Ubuntu. (We pass this via the `-e` “extra args” hook to Daijin’s starter, which appends them to its proot command line.)

---

## 6) Cleanup / unmount

There’s no “unmount” step for proot. **Exiting** the shell ends the proot process and all children. If you backgrounded tasks and need to nuke them from another Termux session:

```bash
pgrep -fa 'proot .*containers/ubuntu-noble'   # inspect
pkill -f  'proot .*containers/ubuntu-noble'   # kill
```

---

## 7) Tips

* If you ever see “TERM environment variable not set”, inside Ubuntu:

  ```bash
  export TERM=xterm-256color
  echo 'export TERM=xterm-256color' >> /root/.bashrc
  ```

* Groups like “cannot find name for group ID …” on first entry are normal before fixup; running step **3** addresses network-related groups for `_apt` etc.

* To run one command non-interactively:

  ```bash
  ubuntu apt-get update
  ```

* Want the sdcard bind permanently from the config? Add to the container’s Daijin `.conf`:

  ```
  extra_args="-b /sdcard:/root/sdcard -w /root"
  ```

---

### Why your first `ubuntu` wrapper broke

Your wrapper didn’t export a container-friendly `PATH`, so `/bin` and `/usr/bin` weren’t on `PATH` and common tools like `id` and `ls` weren’t found. Daijin’s proot starter does not set `PATH` for you; it only mounts and then either runs the command you supplied, or defaults to `/bin/su`/`/bin/sh`. The helper above forces a known-good environment and a **login shell**, which also sources `/etc/profile` on Ubuntu and keeps things predictable.

If you want, I can also tweak **README.md** to link to this new flow and drop the old raw-proot block.
