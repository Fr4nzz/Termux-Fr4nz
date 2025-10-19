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

### Usage tips

```bash
# As your normal Termux user
CONTAINER="$HOME/containers/ubuntu-noble"
rurima lxc pull -o ubuntu -v noble -s "$CONTAINER"
ruri "$CONTAINER" /bin/bash -l

# As root via tsu — pre-expand paths and use -- so args go to ruri
P=/data/data/com.termux/files/usr
CONTAINER="$HOME/containers/ubuntu-noble"
command "$P/bin/tsu" -s "$P/bin/ruri" -- "$CONTAINER" /bin/bash -l

# Optional: example minimal config (values must be quoted for libk2v)
cat >/sdcard/ub-noble.k2v <<'EOF'
container_dir = "/data/data/com.termux/files/home/containers/ubuntu-noble"
no_warnings   = "true"
use_rurienv   = "false"
EOF
ruri -c /sdcard/ub-noble.k2v /bin/bash -l
```

### Post-install retrofit (if you installed earlier)

```bash
P=/data/data/com.termux/files/usr
cat >"$P/bin/ruri" <<'EOF'
#!/data/data/com.termux/files/usr/bin/sh
PREFIX="/data/data/com.termux/files/usr"
unset LD_PRELOAD
export LD_LIBRARY_PATH="$PREFIX/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
export ruri_rexec=1
exec "$PREFIX/libexec/ruri" "$@"
EOF
chmod 0755 "$P/bin/ruri"; hash -r
```

### Root one-liners (important: `--` so flags go to zsh)

```bash
P=/data/data/com.termux/files/usr
command "$P/bin/tsu" -s "$P/bin/zsh" -- -lc 'echo ok # comment works if you add -o interactive_comments'
```

## Install R binaries on Ubuntu

This scripts install latest R version and sets install.packages to download binaries instead of the slow option of compiling from source (This script should work for any ubuntu version not only in termux)

```bash
sudo bash setup-r-binaries.sh
```
