# Entering the container (rooted path with `sudo rurima r`)

Uses real Linux namespaces/mounts (fast & feature-complete). Requires root (Magisk/etc).  
If you don’t have root, see [ENTERING_CONTAINER_NO_ROOT.md](./ENTERING_CONTAINER_NO_ROOT.md).

## Create/pull a dedicated ROOT container

```bash
CONTAINER="$HOME/containers/ubuntu-root"
rurima lxc list
rurima lxc pull -o ubuntu -v noble -s "$CONTAINER"
```

## First run: fix networking & permissions **inside** Ubuntu

```bash
curl -fsSL https://raw.githubusercontent.com/RuriOSS/daijin/refs/heads/main/src/share/fixup.sh \
  | sudo rurima r "$CONTAINER" /bin/sh
```

## Enter the container

```bash
sudo rurima r "$CONTAINER"
```

Bind `/sdcard` to `~/sdcard`:

```bash
sudo rurima r -m /sdcard /root/sdcard "$CONTAINER"
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
C="$HOME/containers/ubuntu-root"
exec /data/data/com.termux/files/usr/bin/sudo /data/data/com.termux/files/usr/bin/rurima r \
  -m /sdcard /root/sdcard "$C" "$@"
SH
chmod 0755 "$P/bin/ubuntu-root"

cat >"$P/bin/ubuntu-root-u" <<'SH'
#!/data/data/com.termux/files/usr/bin/sh
C="$HOME/containers/ubuntu-root"
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
