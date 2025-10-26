# RStudio Server (aarch64) quick install

RStudio Server provides the familiar IDE in a browser. These steps target the Ubuntu Noble/Lunar rootfs shipped here and run fine inside Termux (proot via Daijin) or a rooted container.

> Works on 64-bit ARM (aarch64) Ubuntu; needs ~2.5 GB free space and a working `apt`/network connection.

---

## One-shot install script

Copy/paste this inside the container (root shell):

```bash
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive

dpkg --add-architecture arm64 || true
apt update
apt install -y --no-install-recommends \
  gdebi-core gnupg lsb-release ca-certificates wget \
  libssl3 libxml2 libcurl4 libedit2 libuuid1 libpq5 \
  libsqlite3-0 libbz2-1.0 liblzma5 libreadline8

# Pick latest arm64 build from Posit CDN
RSTUDIO_DEB_URL="https://download2.rstudio.org/server/jammy/amd64/rstudio-server-2023.12.1-402-arm64.deb"
RSTUDIO_DEB="$(mktemp --suffix=.deb)"
wget -O "$RSTUDIO_DEB" "$RSTUDIO_DEB_URL"

gdebi -n "$RSTUDIO_DEB"
rm -f "$RSTUDIO_DEB"

systemctl stop rstudio-server || true
rstudio-server verify-installation
rstudio-server start
```

> `rstudio-server` listens on port 8787 by default. Inside Termux/proot expose it with `ssh -L` or `cloudflared` as needed.

---

## Useful admin commands

```bash
rstudio-server start            # launch the service
rstudio-server stop             # stop gracefully
rstudio-server restart          # restart after config changes
rstudio-server status           # check state + log tail
rstudio-server verify-installation
``` 

Default login is any Linux user present on the system.

* **Daijin/proot quick path:** the root account works out of the box; `ubuntu adduser <name>` if you prefer a non-root login.
* **Port:** 8787/tcp. Use `ss -tlnp | grep 8787` to confirm it’s listening.

---

## Preferred flow for rooted containers

Running everything as root is convenient but risky. On a rooted device/container, create a normal user and enable sudo:

```bash
adduser analyst
usermod -aG sudo analyst
passwd analyst
```

Then log in to RStudio with `analyst` and run elevated tasks via `sudo` inside the IDE terminal.

You can adjust RStudio Server config at `/etc/rstudio/rserver.conf`; reload with `rstudio-server restart`.

---

Need tweaks (reverse proxy, PAM tweaks, shared storage binds)? Let me know and I’ll extend this doc.

---

## Termux wrappers: start/stop RStudio Server

Goal: start RStudio Server on port 8787 from Termux with one command, and stop it with another.  
Then you can open it in your mobile browser at `http://127.0.0.1:8787`.

We provide two pairs of wrappers:

- `rstudio-rootless-start` / `rstudio-rootless-stop`
  - for the **rootless** container (`daijin`/`proot`, see `ENTERING_CONTAINER_NO_ROOT.md`)
- `rstudio-root-start` / `rstudio-root-stop`
  - for the **rooted** container (`rurima`/`ruri`, see `ENTERING_CONTAINER_ROOT.md`)

All four wrappers:
- keep the container alive in the background with `sleep infinity`
- write a PID file under `$PREFIX/var/run/`
- refuse to start twice if already running

Because the `ubuntu-rootless` / `ubuntu-root` helpers already bind `/sdcard` and the Termux:X11 socket, the container these wrappers spin up is immediately compatible with later launching XFCE/Termux:X11 without re-entering the container with different mounts.

### 1) Rootless (no root / proot)

Create `rstudio-rootless-start`:

```bash
: "${PREFIX:=/data/data/com.termux/files/usr}"
cat >"$PREFIX/bin/rstudio-rootless-start" <<'SH'
#!/data/data/com.termux/files/usr/bin/sh
# Start RStudio Server (rootless / daijin+proot).
# Exposes http://127.0.0.1:8787 to the phone.
# Keeps the proot session alive in background and stores its PID.

: "${PREFIX:=/data/data/com.termux/files/usr}"
PIDFILE="$PREFIX/var/run/rstudio-rootless.pid"
mkdir -p "$PREFIX/var/run"

if [ -f "$PIDFILE" ] && kill -0 "$(cat "$PIDFILE")" 2>/dev/null; then
  echo "rstudio-rootless-start: already running (PID $(cat "$PIDFILE"))."
  exit 0
fi

ubuntu-rootless 'export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin;
rstudio-server start || true;
sleep infinity' &

echo $! >"$PIDFILE"

echo "RStudio Server (rootless) is up."
echo "Open http://127.0.0.1:8787"
echo
echo "Stop with: rstudio-rootless-stop"
SH
chmod 0755 "$PREFIX/bin/rstudio-rootless-start"
```

Create `rstudio-rootless-stop`:

```bash
: "${PREFIX:=/data/data/com.termux/files/usr}"
cat >"$PREFIX/bin/rstudio-rootless-stop" <<'SH'
#!/data/data/com.termux/files/usr/bin/sh
# Stop the background RStudio Server (rootless) by killing its proot wrapper.

: "${PREFIX:=/data/data/com.termux/files/usr}"
PIDFILE="$PREFIX/var/run/rstudio-rootless.pid"

if [ -f "$PIDFILE" ]; then
  PID="$(cat "$PIDFILE")"
  if kill -0 "$PID" 2>/dev/null; then
    kill "$PID" 2>/dev/null || true
    sleep 1
    kill -9 "$PID" 2>/dev/null || true
    echo "RStudio Server (rootless) stopped."
  else
    echo "Not running (stale pidfile)."
  fi
  rm -f "$PIDFILE"
else
  echo "Not running (no pidfile)."
fi
SH
chmod 0755 "$PREFIX/bin/rstudio-rootless-stop"
```

Usage (rootless):

```bash
rstudio-rootless-start   # start server on 127.0.0.1:8787
rstudio-rootless-stop    # stop it
```

Open on the phone: `http://127.0.0.1:8787`  
Log in as `root` or any user you created in the container.

---

### 2) Rooted (real chroot via rurima/ruri)

Create `rstudio-root-start`:

```bash
: "${PREFIX:=/data/data/com.termux/files/usr}"
cat >"$PREFIX/bin/rstudio-root-start" <<'SH'
#!/data/data/com.termux/files/usr/bin/sh
# Start RStudio Server (rooted / rurima+ruri chroot).
# Also tries to show a LAN URL using the phone's IP so you can connect from another device.

: "${PREFIX:=/data/data/com.termux/files/usr}"
PIDFILE="$PREFIX/var/run/rstudio-root.pid"
mkdir -p "$PREFIX/var/run"

if [ -f "$PIDFILE" ] && kill -0 "$(cat "$PIDFILE")" 2>/dev/null; then
  echo "rstudio-root-start: already running (PID $(cat "$PIDFILE"))."
  exit 0
fi

ubuntu-root /bin/bash -lc '
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
mountpoint -q /proc || mount -t proc proc /proc
mountpoint -q /sys  || mount -t sysfs sys /sys
mkdir -p /dev/pts /dev/shm /run /tmp/.ICE-unix
mountpoint -q /dev/pts || mount -t devpts devpts /dev/pts
mountpoint -q /dev/shm || mount -t tmpfs -o rw,nosuid,nodev,mode=1777,size=256M tmpfs /dev/shm
chmod 1777 /tmp/.ICE-unix
rstudio-server start || true
sleep infinity
' &

echo $! >"$PIDFILE"

# Try to detect the phone's LAN IP (assumes sudo + wlan0 available).
PHONE_IP="$(sudo ip -4 addr show wlan0 2>/dev/null | awk '/inet / {print $2}' | cut -d/ -f1)"

echo "RStudio Server (rooted) is up."
echo "Open http://127.0.0.1:8787"
if [ -n "$PHONE_IP" ]; then
  echo "Or from another device on your Wi-Fi: http://$PHONE_IP:8787"
fi
echo
echo "Stop with: rstudio-root-stop"
SH
chmod 0755 "$PREFIX/bin/rstudio-root-start"
```

Create `rstudio-root-stop`:

```bash
: "${PREFIX:=/data/data/com.termux/files/usr}"
cat >"$PREFIX/bin/rstudio-root-stop" <<'SH'
#!/data/data/com.termux/files/usr/bin/sh
# Stop the background RStudio Server (rooted) by killing its chroot wrapper.

: "${PREFIX:=/data/data/com.termux/files/usr}"
PIDFILE="$PREFIX/var/run/rstudio-root.pid"

if [ -f "$PIDFILE" ]; then
  PID="$(cat "$PIDFILE")"
  if kill -0 "$PID" 2>/dev/null; then
    kill "$PID" 2>/dev/null || true
    sleep 1
    kill -9 "$PID" 2>/dev/null || true
    echo "RStudio Server (rooted) stopped."
  else
    echo "Not running (stale pidfile)."
  fi
  rm -f "$PIDFILE"
else
  echo "Not running (no pidfile)."
fi
SH
chmod 0755 "$PREFIX/bin/rstudio-root-stop"
```

Usage (rooted):

```bash
rstudio-root-start   # start server
rstudio-root-stop    # stop it
```

The script prints two URLs:

* `http://127.0.0.1:8787` → open in the phone’s own browser.
* `http://<phone_ip>:8787` → open from another device on the same Wi-Fi (if we could detect the phone IP).

---

### 3) Notes

* You only need to create these wrappers once.
* After that, just run `rstudio-rootless-start` / `rstudio-root-start` from Termux whenever you want RStudio.
* No need to manually run `rstudio-server stop`. The `*-stop` wrappers kill the background session and clean up the PID file.
