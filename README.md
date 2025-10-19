# Termux-Fr4nz

Quick scripts for preparing Termux and installing the ruri/rurima tooling used to manage Linux distributions on Android.

## SSH setup

```bash
curl -fsSL https://raw.githubusercontent.com/Fr4nzz/Termux-Fr4nz/refs/heads/main/setup_ssh.sh | bash
```

## zsh setup

```bash
curl -fsSL https://raw.githubusercontent.com/Fr4nzz/Termux-Fr4nz/refs/heads/main/install_zsh.sh | bash
```

## Set SSH password

```bash
passwd
```

Run this inside Termux after `setup_ssh.sh` finishes so password logins work.

## Install ruri and rurima

```bash
curl -fsSL https://raw.githubusercontent.com/Fr4nzz/Termux-Fr4nz/refs/heads/main/install_ruri_rurima.sh | bash
```

Both scripts assume you are running inside Termux. The installer builds from source and installs the binaries into `$PREFIX/bin` without additional prompts.

## Install R binaries on Ubuntu

This scripts install latest R version and sets install.packages to download binaries instead of the slow option of compiling from source (This script should work for any ubuntu version not only in termux)

```bash
sudo bash setup-r-binaries.sh
```
