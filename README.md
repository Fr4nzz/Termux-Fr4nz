# Ubuntu in Android via Termux

Scripts for setting up Termux and running Linux containers with development environments on Android.

---

## Table of Contents

- [Initial Termux Setup](#initial-termux-setup)
- [Container Setup](#container-setup)
- [Development Servers (Web IDEs)](#development-servers-web-ides)
- [Desktop Environment (GUI)](#desktop-environment-gui)
- [Desktop Applications](#desktop-applications)
- [Additional Tools](#additional-tools)
- [Troubleshooting](#troubleshooting)

---

## Initial Termux Setup

### SSH Access (Optional)

Enable SSH to run commands from your computer. See [WINDOWS_SSH.md](./Instructions/WINDOWS_SSH.md).

**Install:**
```bash
curl -fsSL https://raw.githubusercontent.com/Fr4nzz/Termux-Fr4nz/refs/heads/main/termux-scripts/setup_ssh.sh | bash
# Set password
passwd
```

### Zsh with Oh My Zsh (Recommended)

Better terminal with autosuggestions and syntax highlighting.

**Install:**
```bash
curl -fsSL https://raw.githubusercontent.com/Fr4nzz/Termux-Fr4nz/refs/heads/main/termux-scripts/install_zsh.sh | bash
```

### Storage Access

Grant Termux access to internal storage:
```bash
termux-setup-storage
```

---

## Container Setup

Choose **one** container type. Default username is `legend` (customize with `export DESKTOP_USER=name` before running).

### Rooted Container (Recommended if rooted)

**Install:**
```bash
curl -fsSL https://raw.githubusercontent.com/Fr4nzz/Termux-Fr4nz/refs/heads/main/termux-scripts/setup_rooted_container_unattended.sh | bash
```

**Enter container:**
```bash
ubuntu-chroot
```

### Rootless Container (No root required)

**Install:**
```bash
curl -fsSL https://raw.githubusercontent.com/Fr4nzz/Termux-Fr4nz/refs/heads/main/termux-scripts/setup_rootless_container_unattended.sh | bash
```

**Enter container:**
```bash
ubuntu-proot
```

> **Note:** Both scripts prompt to install Zsh in the container (default: yes).

---

## Development Servers (Web IDEs)

Access these in your browser. All run from **Termux** (not inside container).

### VS Code Server

Full-featured VS Code in browser with R and Python support.

**Features:**
- ✅ R environment (radian console, httpgd plots, Shiny with F5)
- ✅ Python environment (Ctrl+Enter to run)
- ✅ HTTPS support (clipboard/webviews work over LAN)

#### Rootless (proot)

**Install:**
```bash
curl -fsSL https://raw.githubusercontent.com/Fr4nzz/Termux-Fr4nz/refs/heads/main/termux-scripts/install_vscode_server_proot_unattended.sh | bash
```

**Usage:**
```bash
vscode-server-proot-start  # Start server
vscode-server-proot-stop   # Stop server
```

**Access:**
- 📱 Phone: `http://127.0.0.1:13338`
- 💻 Laptop (ADB): Run `adb forward tcp:13338 tcp:13338`, then open `http://127.0.0.1:13338`
- 💻 Laptop (LAN): `https://YOUR-PHONE-IP:13338` (requires certificate setup)

**HTTPS Setup (one-time, for LAN access with clipboard/webviews):**
```bash
cert-server-proot
# Open http://YOUR-PHONE-IP:8889/setup on laptop and follow instructions
```

#### Rooted (chroot)

**Install:**
```bash
curl -fsSL https://raw.githubusercontent.com/Fr4nzz/Termux-Fr4nz/refs/heads/main/termux-scripts/install_vscode_server_chroot_unattended.sh | bash
```

**Usage:**
```bash
vscode-server-chroot-start  # Start server
vscode-server-chroot-stop   # Stop server
```

**Access:** `http://127.0.0.1:13338`

**HTTPS Setup:**
```bash
cert-server-chroot
```


### RStudio Server

R statistical computing IDE.

#### Rootless

**Install:**
```bash
curl -fsSL https://raw.githubusercontent.com/Fr4nzz/Termux-Fr4nz/refs/heads/main/termux-scripts/install_rstudio_server_proot_unattended.sh | bash
```

**Usage:**
```bash
rstudio-proot-start  # Start server
rstudio-proot-stop   # Stop server
```

**Access:** `http://127.0.0.1:8787`

#### Rooted

**Install:**
```bash
curl -fsSL https://raw.githubusercontent.com/Fr4nzz/Termux-Fr4nz/refs/heads/main/termux-scripts/install_rstudio_server_chroot_unattended.sh | bash
```

**Usage:**
```bash
rstudio-chroot-start  # Start server
rstudio-chroot-stop   # Stop server
```

**Access:** `http://127.0.0.1:8787`

---

## Desktop Environment (GUI)

Full XFCE desktop via Termux:X11.

### Rootless

**Install:**
```bash
curl -fsSL https://raw.githubusercontent.com/Fr4nzz/Termux-Fr4nz/refs/heads/main/termux-scripts/install_x11_desktop_rootless_unattended.sh | bash
```

### Rooted

**Install:**
```bash
curl -fsSL https://raw.githubusercontent.com/Fr4nzz/Termux-Fr4nz/refs/heads/main/termux-scripts/install_x11_desktop_root_unattended.sh | bash
```

---

## Desktop Applications

Run these **inside the container** (`ubuntu-proot` or `ubuntu-chroot`).

### Firefox

**Install:**
```bash
curl -fsSL https://raw.githubusercontent.com/Fr4nzz/Termux-Fr4nz/refs/heads/main/container-scripts/install_firefox.sh | bash
```

### VS Code (Desktop)

**Install:**
```bash
curl -fsSL https://raw.githubusercontent.com/Fr4nzz/Termux-Fr4nz/refs/heads/main/container-scripts/install_vscode.sh | bash
```

**Launch:**
```bash
code-proot
```


### RStudio Desktop

**Install:**
```bash
curl -fsSL https://raw.githubusercontent.com/Fr4nzz/Termux-Fr4nz/refs/heads/main/container-scripts/install_rstudio_desktop.sh | bash
```

**Launch:**
```bash
rstudio-proot
```

### Package Manager (Synaptic)

**Install:**
```bash
curl -fsSL https://raw.githubusercontent.com/Fr4nzz/Termux-Fr4nz/refs/heads/main/container-scripts/install_app_manager.sh | bash
```

### Desktop Icons Helper

**Install:**
```bash
curl -fsSL https://raw.githubusercontent.com/Fr4nzz/Termux-Fr4nz/refs/heads/main/container-scripts/install_desktopify.sh | bash
```

---

## Additional Tools

### R with Binary Packages (bspm + r2u)

**Install (inside container):**
```bash
curl -fsSL https://raw.githubusercontent.com/Fr4nzz/Termux-Fr4nz/refs/heads/main/container-scripts/install_r_binaries.sh | bash
```

### Zsh in Container

**Install (inside container):**
```bash
curl -fsSL https://raw.githubusercontent.com/Fr4nzz/Termux-Fr4nz/refs/heads/main/container-scripts/install_zsh.sh | bash
```

> **Note:** Also prompted during container setup.

---

## Troubleshooting

### Repair APT

**Run inside container:**
```bash
curl -fsSL https://raw.githubusercontent.com/Fr4nzz/Termux-Fr4nz/refs/heads/main/container-scripts/apt_heal.sh | bash
```

### Keep Termux Running

Prevent Android from killing Termux during long tasks.

**Acquire wakelock:**
```bash
termux-wake-lock
```

**Release wakelock:**
```bash
termux-wake-unlock
```

**Whitelist via ADB (from computer):**
```bash
adb shell cmd deviceidle whitelist +com.termux
```

### Browse Available Images

```bash
rurima lxc list
```

---

## Manual Guides

- **Container Setup:** [ENTERING_CONTAINER_ROOT.md](./Instructions/ENTERING_CONTAINER_ROOT.md) / [ENTERING_CONTAINER_NO_ROOT.md](./Instructions/ENTERING_CONTAINER_NO_ROOT.md)
- **Desktop Setup:** [RUN_X11_DESKTOP_ROOT.md](./Instructions/RUN_X11_DESKTOP_ROOT.md) / [RUN_X11_DESKTOP_NO_ROOT.md](./Instructions/RUN_X11_DESKTOP_NO_ROOT.md)
- **R Installation:** [INSTALL_R_BINARIES.md](./Instructions/INSTALL_R_BINARIES.md)
- **RStudio Server:** [INSTALL_RStudio_Server.md](./Instructions/INSTALL_RStudio_Server.md)
- **SSH from Windows:** [WINDOWS_SSH.md](./Instructions/WINDOWS_SSH.md)

---

## Security Notes

- Servers bind to `127.0.0.1` by default (safe for same-device)
- For LAN access with security:
  - **code-server**: Add `--auth password` and set `PASSWORD` env var
  - **openvscode-server**: Remove `--without-connection-token` and use a token
  - **VS Code Server HTTPS**: Use `cert-server` to set up certificates
