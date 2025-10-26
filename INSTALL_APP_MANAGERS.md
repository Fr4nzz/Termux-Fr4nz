# App management inside Ubuntu-in-Termux

This guide lives separate from the desktop/X11 docs so we don't repeat ourselves.

Target: Ubuntu **noble/jammy** rootfs inside Termux, whether you're:
* **rooted chroot** via rurima/ruri (`RUN_X11_DESKTOP_ROOT.md`), or
* **rootless proot** via daijin (`RUN_X11_DESKTOP_NO_ROOT.md`).

Assumptions:
* You already have XFCE (or another desktop) working and can see windows in Termux:X11.
* You can become `root` in the Ubuntu container when needed.

All commands below run **inside the Ubuntu container** (not in Termux).

Works on **arm64/aarch64**.

---

## 1) Install Synaptic (GUI package manager)

```bash
export DEBIAN_FRONTEND=noninteractive
sudo apt-get update
sudo apt-get install -y synaptic adwaita-icon-theme librsvg2-common
```

* **Launch** (as root): `synaptic`
* **XFCE menu:** Synaptic usually appears under *System*.
* **Desktop shortcut** (optional; useful if you run as root and want to bypass `pkexec` prompts):

```bash
mkdir -p ~/Desktop
cp /usr/share/applications/synaptic.desktop ~/Desktop/
sed -i 's|^Exec=.*|Exec=synaptic|' ~/Desktop/synaptic.desktop
chmod +x ~/Desktop/synaptic.desktop
```

> If you see a warning about Adwaita assets or empty icons, the `adwaita-icon-theme` + `librsvg2-common` you installed above resolves it.

---

## 2) Extend the list of available packages (enable official components)

Minimal images often ship with only the `main` component enabled. Turn on **universe** and **multiverse** to unlock tons of packages:

```bash
sudo apt-get install -y software-properties-common
sudo add-apt-repository -y universe
sudo add-apt-repository -y multiverse
sudo apt-get update
```

> This alone will make Synaptic show many more results.

---

## 3) Optional CLI helpers (nice in terminals and also visible in Synaptic)

```bash
apt-get install -y nala aptitude
# Optional: pick faster mirrors for nala
nala fetch || true
```

* **`aptitude`** = TUI package manager (arrow keys, search, mark for install/remove).
* **`nala`** = drop-in apt replacement with clearer output & mirror selection.

---

## 4) Firefox from Mozilla’s APT repo (no Snap required)

Snap packages don't work in these containers (no systemd/snapd).  
Ubuntu usually ships Firefox as a Snap, so you need Mozilla’s real APT repo.

**Run as root inside Ubuntu:**

```bash
set -e
sudo apt-get update
sudo apt-get install -y curl gnupg ca-certificates

sudo install -d -m 0755 /etc/apt/keyrings
curl -fsSL https://packages.mozilla.org/apt/repo-signing-key.gpg \
  | sudo gpg --dearmor -o /etc/apt/keyrings/mozilla.gpg

sudo tee /etc/apt/preferences.d/mozilla >/dev/null <<'EOF'
Package: *
Pin: origin packages.mozilla.org
Pin-Priority: 1000
EOF

echo "deb [signed-by=/etc/apt/keyrings/mozilla.gpg] https://packages.mozilla.org/apt mozilla main" \
  | sudo tee /etc/apt/sources.list.d/mozilla.list >/dev/null

sudo apt-get update
sudo apt-get install -y firefox
```

Then when you're logged in graphically as the unprivileged desktop user (usually `ubuntu`), you can run:

```bash
firefox &
```

---

## 5) Microsoft VS Code (package name: `code`)

Ubuntu does not ship VS Code by default. Add Microsoft’s repo and install.

```bash
# Tools & keydir
sudo apt-get install -y curl gnupg ca-certificates
sudo install -d -m 0755 /etc/apt/keyrings

# Import Microsoft repo key
curl -fsSL https://packages.microsoft.com/keys/microsoft.asc \
  | sudo gpg --dearmor -o /etc/apt/keyrings/packages.microsoft.gpg

# Add repo (auto-detect architecture)
ARCH="$(dpkg --print-architecture)"
echo "deb [arch=${ARCH} signed-by=/etc/apt/keyrings/packages.microsoft.gpg] https://packages.microsoft.com/repos/code stable main" \
  | sudo tee /etc/apt/sources.list.d/vscode.list >/dev/null

# Install
sudo apt-get update
sudo apt-get install -y code
```

### Running VS Code

* **Recommended:** create/use an unprivileged user (e.g., `ubuntu`) and simply run `code`.
* **If you run as root in the container**, add Electron flags:

```bash
code --no-sandbox --user-data-dir=/root/.vscode
```

You can also launch Code with `--disable-gpu` if rendering glitches:

```bash
code --disable-gpu &
```

---

## 6) Desktop icons for apps (desktopify helper)

XFCE won’t automatically drop icons to the Desktop for new apps.  
We’ll add a tiny helper script that copies `.desktop` launchers into your saved desktop user’s `~/Desktop`.

Run this **once as root inside Ubuntu**:

```bash
# Run once as root inside Ubuntu
cat >/usr/local/bin/desktopify <<'SH'
#!/bin/sh
set -eu
RU="$(cat /etc/ruri/user)"
user_home="/home/$RU"
desk="$user_home/Desktop"
[ -d "$desk" ] || mkdir -p "$desk"
for name in "$@"; do
  src="/usr/share/applications/$name.desktop"
  [ -f "$src" ] || { echo "No $src"; continue; }
  cp -f "$src" "$desk/"
  chmod +x "$desk/$name.desktop"
  chown "$RU:$RU" "$desk/$name.desktop"
done
SH
chmod 0755 /usr/local/bin/desktopify
```

Now you can safely add icons (it will just skip missing apps):

```bash
desktopify synaptic     # Synaptic Package Manager shortcut
desktopify firefox      # Firefox shortcut
desktopify code         # VS Code shortcut
```

You only need to run the `desktopify` command again after you install a new app you want on the Desktop.

---
## 8) RStudio Desktop (experimental arm64 GUI)

RStudio Desktop is the full IDE window (not the web server). This is optional and still experimental on ARM64, but it can run inside the XFCE session you already launch with `xfce4-user-start` (rooted) or `xfce4-rootless-start` (proot).

### Install (inside the Ubuntu container, as root)

```bash
set -e
export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y wget gdebi-core

DEB_URL="https://s3.amazonaws.com/rstudio-ide-build/electron/jammy/arm64/rstudio-2025.11.0-daily-271-arm64.deb"
wget -O /tmp/rstudio-arm64.deb "$DEB_URL"
gdebi -n /tmp/rstudio-arm64.deb || apt-get -f install -y

desktopify rstudio # Add icon to desktop
```
