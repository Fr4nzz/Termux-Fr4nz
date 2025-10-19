#!/usr/bin/env bash
set -euo pipefail

# --- 0) Basics ---------------------------------------------------------------
if [[ $EUID -ne 0 ]]; then
  echo "Please run as root (use: sudo bash setup-r-binaries.sh)"
  exit 1
fi

export DEBIAN_FRONTEND=noninteractive

# Detect the target (non-root) user for writing ~/.Rprofile
TARGET_USER="${SUDO_USER:-$USER}"
TARGET_HOME="$(eval echo "~${TARGET_USER}")"

# Codename for repos (jammy=22.04, noble=24.04, etc.)
. /etc/os-release
CODENAME="${UBUNTU_CODENAME}"

echo "==> Ubuntu codename: ${CODENAME}"
echo "==> Target user: ${TARGET_USER} (${TARGET_HOME})"

# --- 1) Keys & Repos: CRAN (R) + r2u (binary R packages) --------------------
echo "==> Adding keyring for CRAN/r2u…"
install -d -m 0755 /usr/share/keyrings

# Use the r2u-provided keyring (covers both CRAN apt and r2u)
curl -fsSL https://r2u.stat.illinois.edu/ubuntu/cran-archive-keyring.gpg \
  -o /usr/share/keyrings/cran-archive-keyring.gpg

echo "==> Writing apt sources…"
# CRAN apt repo for R itself
cat >/etc/apt/sources.list.d/cranapt.list <<EOF
deb [arch=amd64 signed-by=/usr/share/keyrings/cran-archive-keyring.gpg] https://cloud.r-project.org/bin/linux/ubuntu ${CODENAME}-cran40/
EOF

# r2u: 8k+ CRAN packages as native Ubuntu .deb binaries (auto-built daily)
cat >/etc/apt/sources.list.d/r2u.list <<EOF
deb [arch=amd64 signed-by=/usr/share/keyrings/cran-archive-keyring.gpg] https://r2u.stat.illinois.edu/ubuntu ${CODENAME} main
EOF

echo "==> apt update…"
apt-get update -y

# --- 2) Install R and helpers for bspm --------------------------------------
echo "==> Installing R and helpers…"
apt-get install -y --no-install-recommends \
  r-base r-base-dev \
  python3-gi python3-dbus policykit-1 \
  software-properties-common ca-certificates curl

# --- 3) Install bspm (apt if available; else CRAN) ---------------------------
echo "==> Installing bspm (APT if present, else install.packages)…"
if apt-cache show r-cran-bspm >/dev/null 2>&1; then
  apt-get install -y r-cran-bspm
else
  su - "${TARGET_USER}" -c "Rscript --vanilla -e 'install.packages(\"bspm\", repos=\"https://cran.r-project.org\")'"
fi

# --- 4) Configure ~/.Rprofile to prefer binaries automatically --------------
echo "==> Writing ~/.Rprofile for ${TARGET_USER}…"
install -d -m 0755 "${TARGET_HOME}"
cat >"${TARGET_HOME}/.Rprofile" <<EOF
# Prefer Posit Package Manager (fast mirror; serves Linux binaries when available)
options(repos = c(CRAN = "https://packagemanager.posit.co/cran/__linux__/${CODENAME}/latest"))

# Bridge install.packages() -> system binaries (r2u) via bspm.
# Use sudo helper (works even without D-Bus/polkit, e.g. WSL, servers).
if (requireNamespace("bspm", quietly = TRUE)) {
  try(bspm::enable(), silent = TRUE)
  options(bspm.version.check = TRUE, bspm.sudo = TRUE)
}

# VERY IMPORTANT on Linux:
# Keep pkgType as "source" so base R does not force mac/win logic.
# bspm intercepts install.packages() and installs APT binaries for you.
options(pkgType = "source")
EOF

chown "${TARGET_USER}:${TARGET_USER}" "${TARGET_HOME}/.Rprofile"
chmod 0644 "${TARGET_HOME}/.Rprofile"

# --- 5) Quick smoke test: install a heavy package as binary ------------------
echo "==> Testing a binary install via install.packages(\"units\") …"
su - "${TARGET_USER}" -c "Rscript --vanilla -e 'install.packages(\"units\") ; library(units); cat(\"units \", packageVersion(\"units\"), \" loaded\\n\", sep=\"\")'"

# Suggest a couple more GPU/graphics deps often needed for text shaping/fonts
echo "==> (Optional) Installing common system libs for graphics text rendering…"
apt-get install -y --no-install-recommends libfontconfig1-dev libfreetype6-dev libharfbuzz-dev libfribidi-dev libpng-dev libjpeg-dev

echo "==> All done! You can now use install.packages() and get binaries via r2u + bspm."
echo "Try in R: install.packages(c(\"systemfonts\",\"textshaping\",\"sf\",\"terra\"))"
