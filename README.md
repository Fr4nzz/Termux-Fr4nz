# Termux-Fr4nz

Quick scripts for preparing Termux and installing the ruri/rurima tooling used to manage Linux distributions on Android.

## SSH setup

```bash
curl -fsSL https://raw.githubusercontent.com/Fr4nzz/Termux-Fr4nz/refs/heads/main/setup_ssh.sh | bash
```

## zsh setup

```bash
curl -fsSL https://raw.githubusercontent.com/Fr4nzz/Termux-Fr4nz/refs/heads/main/install_zsh.sh | bash
```

## Set SSH password

```bash
passwd
```

Run this inside Termux after `setup_ssh.sh` finishes so password logins work.

## Install rurima (bundled ruri)

```bash
curl -fsSL https://raw.githubusercontent.com/Fr4nzz/Termux-Fr4nz/refs/heads/main/install_rurima.sh | bash
```

Both scripts assume you are running inside Termux. The installer builds from source and installs the binaries into `$PREFIX/bin` without additional prompts.

### Usage

```bash
# Create/pull the container as your normal Termux user
CONTAINER="$HOME/containers/ubuntu-noble"
rurima lxc pull -o ubuntu -v noble -s "$CONTAINER"
```

#### First run: fix networking & permissions inside Ubuntu

Run the daijin `fixup.sh` **inside** the container. We fetch it from Termux and pipe it into `/bin/sh` **in the container**, so this works even if the container's DNS is broken.

```bash
curl -fsSL https://raw.githubusercontent.com/RuriOSS/daijin/refs/heads/main/src/share/fixup.sh \
  | sudo rurima r "$HOME/containers/ubuntu-noble" /bin/sh
```

This sets PATH, creates Android AID groups, adds `root` to them, fixes `_apt` and `portage`, adjusts `/bin/su` perms, creates `/dev` `/proc` `/sys` mountpoints, and writes `/etc/resolv.conf` to fix internet.

#### Preferred: single-command entry (no interactive `tsu`)

Enter the container as root in one shot (default shell):

```bash
sudo rurima r "$HOME/containers/ubuntu-noble"
```

#### Mount Android storage into Ubuntu home

Make sure you’ve run `termux-setup-storage` first, then create the mountpoint inside the container rootfs (one-time):

```bash
mkdir -p "$HOME/containers/ubuntu-noble/root/sdcard"
```

To expose `/sdcard` (i.e. `/storage/emulated/0`) inside Ubuntu at `~/sdcard`, include `-m /sdcard /root/sdcard` when launching (the helper below does this automatically):

```bash
sudo rurima r -m /sdcard /root/sdcard "$HOME/containers/ubuntu-noble"
```

If you use a non-root user inside Ubuntu, swap `/root/sdcard` for `/home/<user>/sdcard`. Re-run the same command in sessions where you launch rurima directly.

#### Optional: interactive `tsu` then run `rurima r`

> **Note:** After `tsu`, `$HOME` becomes `/data/data/com.termux/files/home/.suroot`.
> Don’t use `$HOME` for the container path while root; use the absolute path below.

```bash
tsu
/data/data/com.termux/files/usr/bin/rurima r "/data/data/com.termux/files/home/containers/ubuntu-noble"
```

#### Unmount / cleanup

When you’re done, unmount the container from Termux (this also kills any processes inside it):

```bash
sudo rurima r -U "$HOME/containers/ubuntu-noble"
```

#### Create a shortcut command `ubuntu` (bind-mount `/sdcard` → `/root/sdcard`)

If you prefer typing just `ubuntu` to enter the container (with optional args):

```bash
P=/data/data/com.termux/files/usr
cat >"$P/bin/ubuntu" <<'SH'
#!/data/data/com.termux/files/usr/bin/sh
C="/data/data/com.termux/files/home/containers/ubuntu-noble"
R="/data/data/com.termux/files/usr/bin/rurima"
SRC='/sdcard'  # requires `termux-setup-storage`
if [ "$#" -gt 0 ]; then
    exec sudo "$R" r -m "$SRC" /root/sdcard "$C" "$@"
else
    exec sudo "$R" r -m "$SRC" /root/sdcard "$C"
fi
SH
chmod 0755 "$P/bin/ubuntu"
hash -r
```

Now run:

```bash
ubuntu               # enter container (default shell, /sdcard mounted at ~/sdcard)
ubuntu /bin/bash -l  # run specific command
# Inside Ubuntu the bind mount appears at /root/sdcard
```

#### Optional: unmount helper if something is stuck

For a quick teardown command when mounts persist:

```bash
P=/data/data/com.termux/files/usr
cat >"$P/bin/ubuntu-u" <<'SH'
#!/data/data/com.termux/files/usr/bin/sh
C="/data/data/com.termux/files/home/containers/ubuntu-noble"
exec sudo /data/data/com.termux/files/usr/bin/rurima r -U "$C"
SH
chmod 0755 "$P/bin/ubuntu-u"
hash -r
```

Use it whenever you need to unmount:

```bash
ubuntu-u
```

## Install R binaries on Ubuntu

This installs the latest R and configures `install.packages()` to grab binaries instead of compiling. **Run it inside Ubuntu**:

If you use the `ubuntu` helper:

```bash
curl -fsSL https://raw.githubusercontent.com/Fr4nzz/Termux-Fr4nz/refs/heads/main/setup-r-binaries.sh \
  | ubuntu /bin/bash -s
```

Or without the helper:

```bash
curl -fsSL https://raw.githubusercontent.com/Fr4nzz/Termux-Fr4nz/refs/heads/main/setup-r-binaries.sh \
  | sudo rurima r "$HOME/containers/ubuntu-noble" /bin/bash -s
```
