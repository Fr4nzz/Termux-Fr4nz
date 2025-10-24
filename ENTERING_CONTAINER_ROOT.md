# Entering the container (rooted path with `sudo rurima r`)

Uses real Linux namespaces/mounts (fast & feature-complete). Requires root (Magisk/etc).  
If you don’t have root, see [ENTERING_CONTAINER_NO_ROOT.md](./ENTERING_CONTAINER_NO_ROOT.md).

## Get an Ubuntu rootfs (separate path for ROOT testing)

```bash
CONTAINER="$HOME/containers/ubuntu-root"
rurima lxc pull -o ubuntu -v noble -s "$CONTAINER"
```

## First run: fix networking & permissions **inside** Ubuntu

```bash
curl -fsSL https://raw.githubusercontent.com/RuriOSS/daijin/refs/heads/main/src/share/fixup.sh \
  | sudo rurima r "$HOME/containers/ubuntu-root" /bin/sh
```

## Enter the container

```bash
sudo rurima r "$HOME/containers/ubuntu-root"
```

Bind `/sdcard` to `~/sdcard`:

```bash
sudo rurima r -m /sdcard /root/sdcard "$HOME/containers/ubuntu-root"
```

## Set terminal type inside Ubuntu (fix “TERM not set”)

```bash
export TERM=xterm-256color
echo 'export TERM=xterm-256color' >> /root/.bashrc
```

## Optional helpers (renamed)

```bash
P=/data/data/com.termux/files/usr
cat >"$P/bin/ubuntu-root" <<'SH'
#!/data/data/com.termux/files/usr/bin/sh
C="/data/data/com.termux/files/home/containers/ubuntu-root"
exec /data/data/com.termux/files/usr/bin/sudo /data/data/com.termux/files/usr/bin/rurima r \
  -m /sdcard /root/sdcard "$C" "$@"
SH
chmod 0755 "$P/bin/ubuntu-root"

cat >"$P/bin/ubuntu-root-u" <<'SH'
#!/data/data/com.termux/files/usr/bin/sh
C="/data/data/com.termux/files/home/containers/ubuntu-root"
exec /data/data/com.termux/files/usr/bin/sudo /data/data/com.termux/files/usr/bin/rurima r -U "$C"
SH
chmod 0755 "$P/bin/ubuntu-root-u"
hash -r
```

Usage:

```bash
ubuntu-root
ubuntu-root /bin/bash -l
ubuntu-root-u
```
