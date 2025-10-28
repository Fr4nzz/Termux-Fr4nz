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

### Desktop Apps

**Enter your container** first:

```bash
# choose one:
ubuntu-proot        # rootless (proot+daijin)
ubuntu-chroot       # rooted
```

Then run inside the **container** the installer you want:

**Firefox**

```bash
curl -fsSL https://raw.githubusercontent.com/Fr4nzz/Termux-Fr4nz/refs/heads/main/container-scripts/install_firefox.sh | bash
```

**VS Code**

```bash
curl -fsSL https://raw.githubusercontent.com/Fr4nzz/Termux-Fr4nz/refs/heads/main/container-scripts/install_vscode.sh | bash
```

**App manager (Synaptic + universe/multiverse)**

```bash
curl -fsSL https://raw.githubusercontent.com/Fr4nzz/Termux-Fr4nz/refs/heads/main/container-scripts/install_app_manager.sh | bash
```

**Desktopify helper (adds desktop icons)**

```bash
curl -fsSL https://raw.githubusercontent.com/Fr4nzz/Termux-Fr4nz/refs/heads/main/container-scripts/install_desktopify.sh | bash
```

**R (CRAN + r2u where available) and bspm**

```bash
curl -fsSL https://raw.githubusercontent.com/Fr4nzz/Termux-Fr4nz/refs/heads/main/container-scripts/install_r_binaries.sh | bash
```

**RStudio Desktop (installs R first if missing)**

```bash
curl -fsSL https://raw.githubusercontent.com/Fr4nzz/Termux-Fr4nz/refs/heads/main/container-scripts/install_rstudio_desktop.sh | bash
```

### Where to run which scripts

- `termux-scripts/` → **Termux-side bootstrap only** (containers + X11 wrappers).
- `container-scripts/` → **Run these inside Ubuntu** (via `ubuntu-proot` or `ubuntu-chroot`).

> During container setup you’ll be prompted for a desktop username (`legend` by default).  
> To skip the prompt, set an env var first: `export DESKTOP_USER=<name>`.

> The setup scripts also install base tools (`curl`, `ca-certificates`, `gnupg`, `wget`) inside Ubuntu so every `container-scripts/*` helper works immediately.

## Repair apt

Run this
```bash
curl -fsSL https://raw.githubusercontent.com/Fr4nzz/Termux-Fr4nz/refs/heads/main/container-scripts/apt_heal.sh | bash
```

```

## Access internal storage

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
```

```bash
# Release when you’re done
termux-wake-unlock
```

On a computer with ADB:

```bash
adb shell cmd deviceidle whitelist +com.termux
# Verify:
adb shell dumpsys deviceidle whitelist
```
