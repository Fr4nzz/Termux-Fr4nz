# Termux-Fr4nz

Quick scripts for preparing Termux and installing the ruri/rurima tooling used to manage Linux distributions on Android.

## SSH setup
I use this to run commands from my computer. See [WINDOWS_SSH.md](./WINDOWS_SSH.md).

```bash
curl -fsSL https://raw.githubusercontent.com/Fr4nzz/Termux-Fr4nz/refs/heads/main/setup_ssh.sh | bash
```

## Set SSH password

```bash
passwd
```

## zsh setup

This makes Termux predict commands and look nicer.

```bash
curl -fsSL https://raw.githubusercontent.com/Fr4nzz/Termux-Fr4nz/refs/heads/main/install_zsh.sh | bash
```

## Install rurima (bundled ruri)

```bash
curl -fsSL https://raw.githubusercontent.com/Fr4nzz/Termux-Fr4nz/refs/heads/main/install_rurima.sh | bash
```

## Usage (common steps)

```bash
# Browse images and pull two separate containers for testing
CON_ROOT="$HOME/containers/ubuntu-root"
CON_NONROOT="$HOME/containers/ubuntu-rootless"
rurima lxc list
rurima lxc pull -o ubuntu -v noble -s "$CON_ROOT"
rurima lxc pull -o ubuntu -v noble -s "$CON_NONROOT"
```

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

## Entering the container

* **Rooted (recommended if your device is rooted):** [ENTERING_CONTAINER_ROOT.md](./ENTERING_CONTAINER_ROOT.md)
* **No root (works everywhere, proot):** [ENTERING_CONTAINER_NO_ROOT.md](./ENTERING_CONTAINER_NO_ROOT.md)

## Run a desktop via Termux:X11

* **Rooted (ruri):** [RUN_X11_DESKTOP_ROOT.md](./RUN_X11_DESKTOP_ROOT.md)
* **No root (daijin/proot):** [RUN_X11_DESKTOP_NO_ROOT.md](./RUN_X11_DESKTOP_NO_ROOT.md)

## Install R binaries (inside Ubuntu)

See [INSTALL_R_BINARIES.md](./INSTALL_R_BINARIES.md)

## RStudio Server (optional)

See [INSTALL_RStudio_aarch64.md](./INSTALL_RStudio_aarch64.md)

## SSH setup

See [WINDOWS_SSH.md](./WINDOWS_SSH.md)

## Keep Termux alive while testing

```bash
adb shell cmd deviceidle whitelist +com.termux
```
