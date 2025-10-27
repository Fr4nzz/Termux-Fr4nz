# Termux-Fr4nz

Tiny scripts for setting up Termux and installing the ruri/rurima tooling to manage Linux distros on Android.

## SSH setup
I use this to run commands from my computer. See [WINDOWS_SSH.md](./Instructions/WINDOWS_SSH.md).

```bash
curl -fsSL https://raw.githubusercontent.com/Fr4nzz/Termux-Fr4nz/refs/heads/main/termux-scripts/setup_ssh.sh | bash
```

## Set SSH password

```bash
passwd
```

## zsh setup

This makes Termux predict commands and look nicer.

```bash
curl -fsSL https://raw.githubusercontent.com/Fr4nzz/Termux-Fr4nz/refs/heads/main/termux-scripts/install_zsh.sh | bash
```

## Install rurima (bundled ruri)

```bash
curl -fsSL https://raw.githubusercontent.com/Fr4nzz/Termux-Fr4nz/refs/heads/main/termux-scripts/install_rurima.sh | bash
```

## Quick start (UNATTENDED)

> Run these in **Termux**. Default desktop user is `legend`.  
> To change it: `export DESKTOP_USER=<name>` before running.

**A) Containers**
- Rooted container:  
  ```bash
  curl -fsSL https://raw.githubusercontent.com/Fr4nzz/Termux-Fr4nz/refs/heads/main/termux-scripts/setup_rooted_container_unattended.sh | bash
  ```
- Rootless container (proot + Daijin):  
  ```bash
  curl -fsSL https://raw.githubusercontent.com/Fr4nzz/Termux-Fr4nz/refs/heads/main/termux-scripts/setup_rootless_container_unattended.sh | bash
  ```

**B) Desktop (Termux:X11 + XFCE)**
- Rooted:  
  ```bash
  curl -fsSL https://raw.githubusercontent.com/Fr4nzz/Termux-Fr4nz/refs/heads/main/termux-scripts/install_x11_desktop_root_unattended.sh | bash
  ```
- Rootless:  
  ```bash
  curl -fsSL https://raw.githubusercontent.com/Fr4nzz/Termux-Fr4nz/refs/heads/main/termux-scripts/install_x11_desktop_rootless_unattended.sh | bash
  ```

**C) R / RStudio / Apps**
- Install R binaries:  
  ```bash
  curl -fsSL https://raw.githubusercontent.com/Fr4nzz/Termux-Fr4nz/refs/heads/main/termux-scripts/install_r_binaries_unattended.sh | bash
  ```
- RStudio Server (installs server + Termux wrappers; installs R first if missing):  
  - Rootless (proot + Daijin):
    ```bash
    curl -fsSL https://raw.githubusercontent.com/Fr4nzz/Termux-Fr4nz/refs/heads/main/termux-scripts/install_rstudio_server_proot_unattended.sh | bash
    ```
  - Rooted (rurima/ruri chroot):
    ```bash
    curl -fsSL https://raw.githubusercontent.com/Fr4nzz/Termux-Fr4nz/refs/heads/main/termux-scripts/install_rstudio_server_chroot_unattended.sh | bash
    ```
- App manager (Synaptic + enable universe/multiverse):  
  ```bash
  curl -fsSL https://raw.githubusercontent.com/Fr4nzz/Termux-Fr4nz/refs/heads/main/termux-scripts/install_app_manager_unattended.sh | bash
  ```
- Desktopify helper:  
  ```bash
  curl -fsSL https://raw.githubusercontent.com/Fr4nzz/Termux-Fr4nz/refs/heads/main/termux-scripts/install_desktopify_unattended.sh | bash
  ```
- Firefox (adds Desktop icon):  
  ```bash
  curl -fsSL https://raw.githubusercontent.com/Fr4nzz/Termux-Fr4nz/refs/heads/main/termux-scripts/install_firefox_unattended.sh | bash
  ```
- VS Code (adds Desktop icon):  
  ```bash
  curl -fsSL https://raw.githubusercontent.com/Fr4nzz/Termux-Fr4nz/refs/heads/main/termux-scripts/install_vscode_unattended.sh | bash
  ```
- RStudio Desktop (installs R if missing; adds Desktop icon):  
  ```bash
  curl -fsSL https://raw.githubusercontent.com/Fr4nzz/Termux-Fr4nz/refs/heads/main/termux-scripts/install_rstudio_desktop_unattended.sh | bash
  ```

### Where to run which scripts

- `termux-scripts/` → run from **Termux**. These thin wrappers enter the Ubuntu container and call the real installers.
- `container-scripts/` → run **inside** the Ubuntu container (manually or via the wrappers above).

> During container setup you’ll be prompted for a desktop username (`legend` by default).  
> To skip the prompt, set an env var first: `export DESKTOP_USER=<name>`.

> The setup scripts also install base tools (`curl`, `ca-certificates`, `gnupg`, `wget`) inside Ubuntu so every `container-scripts/*` helper works immediately.
```

## Usage (common steps)

Run `termux-setup-storage` once in Termux so the app can mount internal storage.  
This grants access to `/sdcard`, letting the container see your phone's files when you bind it.

```bash
termux-setup-storage
```

## Browse available rootfs images

```bash
rurima lxc list
```

> Pull/create containers in the “Entering container” guides below (root/non-root use **different directories** so you can test both on one device).

## Entering the container (manual guides)
* **Rooted (recommended if your device is rooted):** [ENTERING_CONTAINER_ROOT.md](./Instructions/ENTERING_CONTAINER_ROOT.md)
* **No root (works everywhere, proot):** [ENTERING_CONTAINER_NO_ROOT.md](./Instructions/ENTERING_CONTAINER_NO_ROOT.md)

## Run a desktop via Termux:X11 (manual guides)
* **Rooted (ruri):** [RUN_X11_DESKTOP_ROOT.md](./Instructions/RUN_X11_DESKTOP_ROOT.md)
* **No root (daijin/proot):** [RUN_X11_DESKTOP_NO_ROOT.md](./Instructions/RUN_X11_DESKTOP_NO_ROOT.md)

## Install R binaries (manual guide)
[INSTALL_R_BINARIES.md](./Instructions/INSTALL_R_BINARIES.md)

## RStudio Server (manual guide)
[INSTALL_RStudio_Server.md](./Instructions/INSTALL_RStudio_Server.md)

## Keep Termux from being killed

Android’s Doze/battery optimization can suspend or kill background apps—including Termux. Do the following so long-running tasks (servers, containers, builds) don’t die.

From Termux:

```bash
# Hold a wakelock while your job runs
termux-wake-lock

# Release when you’re done
termux-wake-unlock
```

On a computer with ADB:

```bash
adb shell cmd deviceidle whitelist +com.termux
# Verify:
adb shell dumpsys deviceidle whitelist
```
