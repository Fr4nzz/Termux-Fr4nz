#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail
WRAP=""; command -v ubuntu-chroot >/dev/null 2>&1 && WRAP="ubuntu-chroot"
[ -z "$WRAP" ] && command -v ubuntu-proot >/dev/null 2>&1 && WRAP="ubuntu-proot"
[ -n "$WRAP" ] || { echo "No container wrapper found."; exit 1; }
curl -fsSL https://raw.githubusercontent.com/Fr4nzz/Termux-Fr4nz/refs/heads/main/container-scripts/install_rstudio_desktop.sh | $WRAP /bin/bash -s
echo "✅ RStudio Desktop installed (R ensured; Desktop icon added)."
