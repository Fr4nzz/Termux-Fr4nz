# Entering the container (rooted path with `sudo rurima r`)

Uses real Linux namespaces/mounts (fast & feature-complete). Requires root (Magisk/etc).  
If you don’t have root, see [ENTERING_CONTAINER_NO_ROOT.md](./ENTERING_CONTAINER_NO_ROOT.md).

## First run: fix networking & permissions inside Ubuntu

Fetch from Termux and execute **inside** the container (works even if container DNS is broken):

```bash
curl -fsSL https://raw.githubusercontent.com/RuriOSS/daijin/refs/heads/main/src/share/fixup.sh \
  | sudo rurima r "$HOME/containers/ubuntu-noble" /bin/sh
```

This sets PATH, creates Android AID groups, fixes `_apt`, adjusts `/bin/su` perms, creates `/dev` `/proc` `/sys`, and writes `/etc/resolv.conf`.

## Enter the container

Default shell:

```bash
sudo rurima r "$HOME/containers/ubuntu-noble"
```

With `/sdcard` bind-mounted to `~/sdcard`:

```bash
sudo rurima r -m /sdcard /root/sdcard "$HOME/containers/ubuntu-noble"
# For a non-root *user inside Ubuntu*, change /root/sdcard → /home/<user>/sdcard
```

## Set terminal type inside Ubuntu (fix “TERM environment variable not set”)

```bash
# set for this shell
export TERM=xterm-256color
# make it persistent for root
echo 'export TERM=xterm-256color' >> /root/.bashrc
```

### Optional helper: `ubuntu` (quick entry with /sdcard)

```bash
P=/data/data/com.termux/files/usr
cat >"$P/bin/ubuntu" <<'SH'
#!/data/data/com.termux/files/usr/bin/sh
C="/data/data/com.termux/files/home/containers/ubuntu-noble"
exec /data/data/com.termux/files/usr/bin/sudo /data/data/com.termux/files/usr/bin/rurima r \
  -m /sdcard /root/sdcard "$C" "$@"
SH
chmod 0755 "$P/bin/ubuntu"
hash -r
```

Usage:

```bash
ubuntu               # default shell
ubuntu /bin/bash -l  # run specific command
```

## Unmount / cleanup

When you’re done, unmount from Termux (also kills processes inside):

```bash
sudo rurima r -U "$HOME/containers/ubuntu-noble"
```

### Optional helper: `ubuntu-u` (unmount shortcut)

```bash
P=/data/data/com.termux/files/usr
cat >"$P/bin/ubuntu-u" <<'SH'
#!/data/data/com.termux/files/usr/bin/sh
C="/data/data/com.termux/files/home/containers/ubuntu-noble"
exec /data/data/com.termux/files/usr/bin/sudo /data/data/com.termux/files/usr/bin/rurima r -U "$C"
SH
chmod 0755 "$P/bin/ubuntu-u"
hash -r
```

Usage:

```bash
ubuntu-u
```
