# Termux-Fr4nz

Tiny scripts for setting up Termux and installing the ruri/rurima tooling to manage Linux distros on Android.

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