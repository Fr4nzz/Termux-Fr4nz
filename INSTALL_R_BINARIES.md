# Install R binaries on Ubuntu (container, WSL, VM, or PC)

This is container method–agnostic. Works the same whether you entered via `rurima r` (root) or `proot` (no-root), and also on regular Ubuntu/WSL.

**Supported Ubuntu releases:** 22.04 (jammy) and 24.04 (noble).  
**r2u binaries:** amd64 (jammy & noble) and arm64 (noble).

## Steps (run as root inside Ubuntu)

```bash
export DEBIAN_FRONTEND=noninteractive
apt-get update -y
# Base tools so package post-install scripts work in minimal images
apt-get install -y --no-install-recommends debconf debconf-i18n gnupg ca-certificates curl

# Install R + bspm/r2u setup
curl -fsSL https://raw.githubusercontent.com/Fr4nzz/Termux-Fr4nz/refs/heads/main/setup-r-binaries.sh | bash
```

After this:

* `R` is installed from CRAN’s Ubuntu repo.
* `bspm` is enabled so `install.packages()` prefers system binaries (r2u/Ubuntu r-cran-*), falling back to source when needed.

If you’re not root inside Ubuntu, prefix with `sudo`:

```bash
sudo bash -lc 'export DEBIAN_FRONTEND=noninteractive; apt-get update -y; apt-get install -y --no-install-recommends debconf debconf-i18n gnupg ca-certificates curl'
curl -fsSL https://raw.githubusercontent.com/Fr4nzz/Termux-Fr4nz/refs/heads/main/setup-r-binaries.sh | sudo bash
```
