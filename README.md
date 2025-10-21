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

The installer builds from source into `$PREFIX/bin` and also installs `proot` so you can run containers without root.

---

## Usage (common steps)

```bash
# Create/pull the container as your normal Termux user
CONTAINER="$HOME/containers/ubuntu-noble"
rurima lxc list                     # optional: view available images
rurima lxc pull -o ubuntu -v noble -s "$CONTAINER"
```

Run `termux-setup-storage` once in Termux so the app can mount internal storage.  
This grants access to `/sdcard`, letting the container see your phone's files when you bind it.

```bash
termux-setup-storage
```

---

## Next steps: choose how to enter the container

* **Rooted (recommended if your device is rooted):** [ENTERING_CONTAINER_ROOT.md](./ENTERING_CONTAINER_ROOT.md)
* **No root (works everywhere, a bit slower with proot):** [ENTERING_CONTAINER_NO_ROOT.md](./ENTERING_CONTAINER_NO_ROOT.md)

---

## Install R binaries (inside Ubuntu, any environment)

This works the same in containers, WSL, VMs, or regular PCs. See [INSTALL_R_BINARIES.md](./INSTALL_R_BINARIES.md).
