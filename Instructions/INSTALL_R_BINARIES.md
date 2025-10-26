# Install R binaries on Ubuntu (container, WSL, VM, or PC)

This is container method–agnostic. Works the same whether you entered via `rurima r` (root) or `proot` (no-root), and also on regular Ubuntu/WSL.

**Supported Ubuntu releases:** 22.04 (jammy) and 24.04 (noble).  
**r2u binaries:** amd64 (jammy & noble) and arm64 (noble).

## Steps (run as your desktop user; uses sudo)

```bash
export DEBIAN_FRONTEND=noninteractive
sudo apt-get update -y

# Base tools so package post-install scripts work in minimal images
sudo apt-get install -y --no-install-recommends debconf debconf-i18n gnupg ca-certificates curl

# Install R + bspm/r2u setup (script will sudo itself if needed)
curl -fsSL https://raw.githubusercontent.com/Fr4nzz/Termux-Fr4nz/refs/heads/main/container-scripts/install_r_binaries.sh | sudo bash
```

After this:

* `R` is installed from CRAN’s Ubuntu repo.
* `bspm` is enabled so `install.packages()` prefers system binaries (r2u/Ubuntu r-cran-*), falling back to source when needed.

> *Note:* The installer script auto-elevates with `sudo` if needed—no manual root shell required.
