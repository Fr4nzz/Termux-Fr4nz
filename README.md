# Termux-Fr4nz

Quick scripts for preparing Termux and installing the ruri/rurima tooling used to manage Linux distributions on Android.

## Termux bootstrap

```bash
curl -fsSL https://raw.githubusercontent.com/Fr4nzz/Termux-Fr4nz/refs/heads/main/setup_termux.sh | bash
```

## Set SSH password

```bash
passwd
```

Run this inside Termux after the bootstrap finishes so password logins work.

## Install ruri and rurima

```bash
curl -fsSL https://raw.githubusercontent.com/Fr4nzz/Termux-Fr4nz/refs/heads/main/install_ruri_rurima.sh | bash
```

Both scripts assume you are running inside Termux. The installer builds from source and installs the binaries into `$PREFIX/bin` without additional prompts.
