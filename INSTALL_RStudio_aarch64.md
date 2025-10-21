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
