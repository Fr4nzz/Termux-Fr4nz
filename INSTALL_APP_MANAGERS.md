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
apt-get update
apt-get install -y synaptic adwaita-icon-theme librsvg2-common
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
apt-get install -y software-properties-common
add-apt-repository -y universe
add-apt-repository -y multiverse
apt-get update
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
apt-get update
apt-get install -y curl gnupg ca-certificates

install -d -m 0755 /etc/apt/keyrings
curl -fsSL https://packages.mozilla.org/apt/repo-signing-key.gpg \
  | gpg --dearmor -o /etc/apt/keyrings/mozilla.gpg

cat >/etc/apt/preferences.d/mozilla <<'EOF'
Package: *
Pin: origin packages.mozilla.org
Pin-Priority: 1000
EOF

echo "deb [signed-by=/etc/apt/keyrings/mozilla.gpg] https://packages.mozilla.org/apt mozilla main" \
  > /etc/apt/sources.list.d/mozilla.list

apt-get update
apt-get install -y firefox
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
apt-get install -y curl gnupg ca-certificates
install -d -m 0755 /etc/apt/keyrings

# Import Microsoft repo key
curl -fsSL https://packages.microsoft.com/keys/microsoft.asc \
  | gpg --dearmor -o /etc/apt/keyrings/packages.microsoft.gpg

# Add repo (auto-detect architecture)
ARCH="$(dpkg --print-architecture)"
echo "deb [arch=${ARCH} signed-by=/etc/apt/keyrings/packages.microsoft.gpg] https://packages.microsoft.com/repos/code stable main" \
  > /etc/apt/sources.list.d/vscode.list

# Install
apt-get update
apt-get install -y code
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
We’ll add a tiny helper script that copies `.desktop` launchers into the `ubuntu` user’s Desktop.

Run this **once as root inside Ubuntu**:

```bash
cat >/usr/local/bin/desktopify <<'SH'
#!/bin/sh
set -eu
user_home="/home/ubuntu"
desk="$user_home/Desktop"
[ -d "$desk" ] || mkdir -p "$desk"
for name; do
  src="/usr/share/applications/$name.desktop"
  if [ ! -f "$src" ]; then
    echo "No $src"
    continue
  fi
  cp -f "$src" "$desk/"
  chmod +x "$desk/$name.desktop"
  chown ubuntu:ubuntu "$desk/$name.desktop"
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

## 7) Recap / tips

* **Synaptic** is fine in both rooted chroot and rootless proot. It's just APT with a GUI.
* **software-properties-common** gives you `add-apt-repository` so you can enable `universe`, `multiverse`, etc.
  - In chroot/proot, that CLI path is more reliable than “Software & Updates” GUI, which wants polkit/systemd.
* **Firefox** should come from Mozilla’s APT repo in here, not Snap.
* **VS Code** (`code`) comes from Microsoft’s APT repo and runs best under the `ubuntu` desktop user.
* **desktopify** is your “add icon to Desktop” tool. It works for Synaptic, Firefox, Code, etc.
