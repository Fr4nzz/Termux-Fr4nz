# Install Synaptic (GUI APT) on Ubuntu inside Termux containers + more repos + optional VS Code

This guide targets your Ubuntu **noble/jammy** rootfs running inside Termux (both **proot/rootless** and **rooted chroot** via ruri/rurima). It assumes you already have X11 (Termux:X11) and a desktop (e.g., XFCE) working per your repo docs.

> Works on **arm64/aarch64**. Commands are meant to be run **inside the Ubuntu container**.

## 0) Quick recap: environment

Make sure your desktop/X11 env is set when you launch GUI apps (Synaptic, VS Code):

```bash
export DISPLAY=:1
export GDK_BACKEND=x11
export QT_QPA_PLATFORM=xcb
export LIBGL_ALWAYS_SOFTWARE=1
```

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

## 4) Optional: Microsoft VS Code (package name: `code`)

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
