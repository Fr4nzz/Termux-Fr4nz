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
```bash
curl -fsSL https://raw.githubusercontent.com/Fr4nzz/Termux-Fr4nz/refs/heads/main/termux-scripts/setup_ssh.sh | bash

# Set password
passwd
```

### Zsh with Oh My Zsh (Recommended)

Better terminal with autosuggestions and syntax highlighting.
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
```bash
curl -fsSL https://raw.githubusercontent.com/Fr4nzz/Termux-Fr4nz/refs/heads/main/termux-scripts/setup_rooted_container_unattended.sh | bash
```

Enter with: `ubuntu-chroot`

### Rootless Container (No root required)
```bash
curl -fsSL https://raw.githubusercontent.com/Fr4nzz/Termux-Fr4nz/refs/heads/main/termux-scripts/setup_rootless_container_unattended.sh | bash
```

Enter with: `ubuntu-proot`

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
```bash
curl -fsSL https://raw.githubusercontent.com/Fr4nzz/Termux-Fr4nz/refs/heads/main/termux-scripts/install_vscode_server_proot_unattended.sh | bash

# Start server
vscode-server-proot-start

# Access
📱 Phone: http://127.0.0.1:13338
💻 Laptop (ADB): adb forward tcp:13338 tcp:13338
                 http://127.0.0.1:13338
💻 Laptop (LAN): https://YOUR-PHONE-IP:13338 (requires certificate setup)

# Stop server
vscode-server-proot-stop

# HTTPS setup (one-time, for LAN access with clipboard/webviews)
cert-server-proot
# Open http://YOUR-PHONE-IP:8889/setup on laptop and follow instructions
```

#### Rooted (chroot)
```bash
curl -fsSL https://raw.githubusercontent.com/Fr4nzz/Termux-Fr4nz/refs/heads/main/termux-scripts/install_vscode_server_chroot_unattended.sh | bash

# Commands
vscode-server-chroot-start  # Start (http://127.0.0.1:13338)
vscode-server-chroot-stop   # Stop
cert-server-chroot          # HTTPS certificate setup
```

### VSCodium Server

Open-source VS Code server (telemetry-free). Runs on `http://127.0.0.1:13337`.

#### Rootless
```bash
curl -fsSL https://raw.githubusercontent.com/Fr4nzz/Termux-Fr4nz/refs/heads/main/termux-scripts/install_vscodium_server_proot_unattended.sh | bash

vscodium-server-proot-start  # Start
vscodium-server-proot-stop   # Stop
```

#### Rooted
```bash
curl -fsSL https://raw.githubusercontent.com/Fr4nzz/Termux-Fr4nz/refs/heads/main/termux-scripts/install_vscodium_server_chroot_unattended.sh | bash

vscodium-server-chroot-start  # Start
vscodium-server-chroot-stop   # Stop
```

### RStudio Server

R statistical computing IDE. Runs on `http://127.0.0.1:8787`.

#### Rootless
```bash
curl -fsSL https://raw.githubusercontent.com/Fr4nzz/Termux-Fr4nz/refs/heads/main/termux-scripts/install_rstudio_server_proot_unattended.sh | bash

rstudio-proot-start  # Start
rstudio-proot-stop   # Stop
```

#### Rooted
```bash
curl -fsSL https://raw.githubusercontent.com/Fr4nzz/Termux-Fr4nz/refs/heads/main/termux-scripts/install_rstudio_server_chroot_unattended.sh | bash

rstudio-chroot-start  # Start
rstudio-chroot-stop   # Stop
```

---

## Desktop Environment (GUI)

Full XFCE desktop via Termux:X11.

### Rootless
```bash
curl -fsSL https://raw.githubusercontent.com/Fr4nzz/Termux-Fr4nz/refs/heads/main/termux-scripts/install_x11_desktop_rootless_unattended.sh | bash
```

### Rooted
```bash
curl -fsSL https://raw.githubusercontent.com/Fr4nzz/Termux-Fr4nz/refs/heads/main/termux-scripts/install_x11_desktop_root_unattended.sh | bash
```

---

## Desktop Applications

Run these **inside the container** (`ubuntu-proot` or `ubuntu-chroot`).

### Firefox
```bash
curl -fsSL https://raw.githubusercontent.com/Fr4nzz/Termux-Fr4nz/refs/heads/main/container-scripts/install_firefox.sh | bash
```

### VS Code (Desktop)
```bash
curl -fsSL https://raw.githubusercontent.com/Fr4nzz/Termux-Fr4nz/refs/heads/main/container-scripts/install_vscode.sh | bash
```

Launch: `code-proot`

### VSCodium (Desktop)
```bash
curl -fsSL https://raw.githubusercontent.com/Fr4nzz/Termux-Fr4nz/refs/heads/main/container-scripts/install_vscodium.sh | bash
```

Launch: `codium-proot`

### RStudio Desktop
```bash
curl -fsSL https://raw.githubusercontent.com/Fr4nzz/Termux-Fr4nz/refs/heads/main/container-scripts/install_rstudio_desktop.sh | bash
```

Launch: `rstudio-proot`

### Package Manager (Synaptic)
```bash
curl -fsSL https://raw.githubusercontent.com/Fr4nzz/Termux-Fr4nz/refs/heads/main/container-scripts/install_app_manager.sh | bash
```

### Desktop Icons Helper
```bash
curl -fsSL https://raw.githubusercontent.com/Fr4nzz/Termux-Fr4nz/refs/heads/main/container-scripts/install_desktopify.sh | bash
```

---

## Additional Tools

### R with Binary Packages (bspm + r2u)
```bash
# Inside container
curl -fsSL https://raw.githubusercontent.com/Fr4nzz/Termux-Fr4nz/refs/heads/main/container-scripts/install_r_binaries.sh | bash
```

### Zsh in Container
```bash
# Inside container (also prompted during container setup)
curl -fsSL https://raw.githubusercontent.com/Fr4nzz/Termux-Fr4nz/refs/heads/main/container-scripts/install_zsh.sh | bash
```

---

## Troubleshooting

### Repair APT
```bash
# Inside container
curl -fsSL https://raw.githubusercontent.com/Fr4nzz/Termux-Fr4nz/refs/heads/main/container-scripts/apt_heal.sh | bash
```

### Keep Termux Running

Prevent Android from killing Termux during long tasks:
```bash
# In Termux
termux-wake-lock    # Acquire wakelock
termux-wake-unlock  # Release when done

# Or whitelist via ADB (from computer)
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