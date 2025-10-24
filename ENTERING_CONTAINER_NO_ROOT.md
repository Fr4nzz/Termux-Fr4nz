# Entering the container (no-root path with **Daijin**)

Daijin runs Ubuntu rootfs containers on Termux without root by wrapping **proot**.

---

## 1) Install Daijin on Termux

```bash
pkg update -y
curl -LO https://github.com/RuriOSS/daijin/releases/download/daijin-v1.5-rc1/daijin-aarch64.deb
apt install -y ./daijin-aarch64.deb
```

---

## 2) Pull/register a dedicated NON-ROOT container

```bash
CONTAINER="$HOME/containers/ubuntu-rootless"
rurima lxc list
rurima lxc pull -o ubuntu -v noble -s "$CONTAINER"

# register
daijin    # choose [4] register
# Path: /data/data/com.termux/files/home/containers/ubuntu-rootless
# Backend: proot
# Name: ubuntu-rootless
```

---

## 3) One-time fixups

```bash
curl -fsSL https://raw.githubusercontent.com/RuriOSS/daijin/refs/heads/main/src/share/fixup.sh \
  | "$PREFIX/share/daijin/proot_start.sh" -r "$CONTAINER" \
    /usr/bin/env -i HOME=/root TERM=xterm-256color \
    PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin \
    /bin/sh
```

---

## 4) Start the container (helper)

```bash
P=/data/data/com.termux/files/usr
cat >"$P/bin/ubuntu-rootless" <<'SH'
#!/data/data/com.termux/files/usr/bin/sh
C="$HOME/containers/ubuntu-rootless"
exec "$PREFIX/share/daijin/proot_start.sh" -r "$C" \
  -e "-b /sdcard:/root/sdcard -w /root" \
  /usr/bin/env -i HOME=/root TERM=xterm-256color \
  PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin \
  /bin/bash -l
SH
chmod 0755 "$P/bin/ubuntu-rootless"

cat >"$P/bin/ubuntu-rootless-u" <<'SH'
#!/data/data/com.termux/files/usr/bin/sh
C="$HOME/containers/ubuntu-rootless"
pkill -f "proot .*${C}" || true
SH
chmod 0755 "$P/bin/ubuntu-rootless-u"
hash -r
```

Usage:

```bash
ubuntu-rootless
ubuntu-rootless /bin/bash -lc 'uname -a'
ubuntu-rootless-u
```

---

## 5) Storage & tips

* Run `termux-setup-storage` once in Termux to enable `/sdcard`.
* If `TERM` is unset inside Ubuntu: `export TERM=xterm-256color`.
