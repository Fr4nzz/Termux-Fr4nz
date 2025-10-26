#!/usr/bin/env bash
set -euo pipefail

# --- 0) Basics ---------------------------------------------------------------
if [[ $EUID -ne 0 ]]; then
  if command -v sudo >/dev/null 2>&1; then
    exec sudo -E bash "$0" "$@"
  else
    echo "Please run as root (use: sudo bash setup-r-binaries.sh)"
    exit 1
  fi
fi

export DEBIAN_FRONTEND=noninteractive

# Detect the target user for writing ~/.Rprofile.
# Prefer SUDO_USER, then USER, fall back to root (e.g., sanitized envs).
TARGET_USER="${SUDO_USER:-${USER:-root}}"
# Resolve home dir using passwd first, then shell expansion, else /root.
TARGET_HOME="$(getent passwd "${TARGET_USER}" 2>/dev/null | cut -d: -f6 || true)"
if [[ -z "${TARGET_HOME}" ]]; then
  TARGET_HOME="$(eval echo "~${TARGET_USER}" 2>/dev/null || echo "/root")"
fi

# Codename for repos (jammy=22.04, noble=24.04, etc.)
. /etc/os-release
CODENAME="${UBUNTU_CODENAME}"
ARCH="$(dpkg --print-architecture)"

echo "==> Ubuntu: ${CODENAME}  arch: ${ARCH}  user: ${TARGET_USER}"

# --- 1) Keys & Repos: CRAN (R) + r2u (binary R packages) --------------------
echo "==> Adding keyrings for CRAN and r2u…"
install -d -m 0755 /usr/share/keyrings

# Ensure crypto tools are present for key imports
apt-get install -y --no-install-recommends gnupg ca-certificates curl

# 1a) CRAN apt repo for R itself (maintained key + Signed-By)
curl -fsSL https://cloud.r-project.org/bin/linux/ubuntu/marutter_pubkey.asc \
  | gpg --dearmor -o /usr/share/keyrings/cran_ubuntu_key.gpg

cat >/etc/apt/sources.list.d/cran_r.list <<EOF
deb [arch=${ARCH} signed-by=/usr/share/keyrings/cran_ubuntu_key.gpg] https://cloud.r-project.org/bin/linux/ubuntu ${CODENAME}-cran40/
EOF

# 1b) r2u repo (CRAN packages as native Ubuntu binaries)
gpg --homedir /tmp --no-default-keyring \
    --keyring /usr/share/keyrings/r2u.gpg \
    --keyserver keyserver.ubuntu.com \
    --recv-keys A1489FE2AB99A21A 67C2D66C4B1D4339 51716619E084DAB9

if [[ "${ARCH}" == "amd64" ]] || { [[ "${ARCH}" == "arm64" ]] && [[ "${CODENAME}" == "noble" ]]; }; then
  cat >/etc/apt/sources.list.d/r2u.list <<EOF
deb [arch=${ARCH} signed-by=/usr/share/keyrings/r2u.gpg] https://r2u.stat.illinois.edu/ubuntu ${CODENAME} main
EOF
else
  echo "==> Skipping r2u repo: no published builds for ${ARCH} on ${CODENAME}"
  rm -f /etc/apt/sources.list.d/r2u.list
fi

# Optional: pin CRAN apt higher than Ubuntu’s own r-cran-* packages
cat >/etc/apt/preferences.d/99-cranapt <<'EOF'
Package: *
Pin: release o=CRAN-Apt Project
Pin: release l=CRAN-Apt Packages
Pin-Priority: 700
EOF

echo "==> apt update…"
apt-get update -y

# --- 2) Install R and helpers for bspm --------------------------------------
echo "==> Installing R and helpers…"
apt-get install -y --no-install-recommends \
  r-base r-base-dev \
  python3-apt \
  sudo ca-certificates curl

# --- 3) Install bspm (apt if available; else CRAN) ---------------------------
echo "==> Installing bspm (APT if present, else install.packages)…"
if apt-cache show r-cran-bspm >/dev/null 2>&1; then
  apt-get install -y r-cran-bspm
else
  if [[ "${TARGET_USER}" == "root" ]]; then
    R --quiet --no-save -e 'install.packages("bspm", repos="https://cran.r-project.org")'
  else
    su - "${TARGET_USER}" -c 'R --quiet --no-save -e '\''install.packages("bspm", repos="https://cran.r-project.org")'\'''
  fi
fi

# --- 4) Ensure passwordless sudo for bspm when needed ------------------------
if [[ "${TARGET_USER}" != "root" ]]; then
  if ! id -nG "${TARGET_USER}" | grep -qw sudo; then
    usermod -aG sudo "${TARGET_USER}"
  fi
  echo "${TARGET_USER} ALL=(ALL) NOPASSWD:ALL" >/etc/sudoers.d/99-${TARGET_USER}-r
  chmod 0440 /etc/sudoers.d/99-${TARGET_USER}-r
fi

# --- 5) Configure ~/.Rprofile to prefer binaries automatically --------------
echo "==> Writing ~/.Rprofile for ${TARGET_USER}…"
install -d -m 0755 "${TARGET_HOME}"
cat >"${TARGET_HOME}/.Rprofile" <<EOF
# Prefer Posit Package Manager (fast mirror; serves Linux binaries when available)
options(repos = c(CRAN = "https://packagemanager.posit.co/cran/__linux__/${CODENAME}/latest"))

# Bridge install.packages() -> system binaries (r2u/Ubuntu r-cran-*) via bspm.
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

if [[ "${TARGET_USER}" != "root" ]]; then
  chown "${TARGET_USER}:${TARGET_USER}" "${TARGET_HOME}/.Rprofile"
fi
chmod 0644 "${TARGET_HOME}/.Rprofile"

# Ensure future users get sane defaults by wiring bspm globally too.
install -d -m 0755 /etc/R
cat >/etc/R/Rprofile.site <<EOF
local({
  options(repos = c(CRAN = "https://packagemanager.posit.co/cran/__linux__/${CODENAME}/latest"))
  if (requireNamespace("bspm", quietly = TRUE)) {
    try(bspm::enable(), silent = TRUE)
    options(bspm.sudo = TRUE, bspm.version.check = TRUE)
  }
})
EOF
chmod 0644 /etc/R/Rprofile.site

echo "==> Done."
echo "Use install.packages() normally. On amd64 you'll get r2u binaries; on ${ARCH} you'll get Ubuntu r-cran-* binaries when available, else source."
