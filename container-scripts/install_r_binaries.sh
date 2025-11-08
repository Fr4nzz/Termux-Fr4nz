#!/usr/bin/env bash
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive

TARGET_USER="$(id -un)"
TARGET_HOME="$(getent passwd "$TARGET_USER" 2>/dev/null | cut -d: -f6 || echo "$HOME")"

. /etc/os-release
CODENAME="${UBUNTU_CODENAME}"
ARCH="$(dpkg --print-architecture)"
RUNTIME="$(cat /etc/ruri/runtime 2>/dev/null || echo unknown)"

echo "==> Ubuntu: ${CODENAME}  arch: ${ARCH}  user: ${TARGET_USER}  runtime: ${RUNTIME}"

sudo install -d -m 0755 /usr/share/keyrings
sudo apt-get update
sudo apt-get install -y --no-install-recommends gnupg ca-certificates curl

# --- CRAN apt repo key + entry ---
curl -fsSL https://cloud.r-project.org/bin/linux/ubuntu/marutter_pubkey.asc \
  | sudo gpg --dearmor -o /usr/share/keyrings/cran_ubuntu_key.gpg
printf 'deb [arch=%s signed-by=/usr/share/keyrings/cran_ubuntu_key.gpg] https://cloud.r-project.org/bin/linux/ubuntu %s-cran40/\n' \
  "$ARCH" "$CODENAME" | sudo tee /etc/apt/sources.list.d/cran_r.list >/dev/null

# --- r2u repo (amd64, and arm64 on noble) ---
sudo gpg --homedir /tmp --no-default-keyring \
  --keyring /usr/share/keyrings/r2u.gpg \
  --keyserver keyserver.ubuntu.com \
  --recv-keys A1489FE2AB99A21A 67C2D66C4B1D4339 51716619E084DAB9
if { [ "$ARCH" = "amd64" ] || { [ "$ARCH" = "arm64" ] && [ "$CODENAME" = "noble" ]; }; }; then
  printf 'deb [arch=%s signed-by=/usr/share/keyrings/r2u.gpg] https://r2u.stat.illinois.edu/ubuntu %s main\n' \
    "$ARCH" "$CODENAME" | sudo tee /etc/apt/sources.list.d/r2u.list >/dev/null
fi

# Prefer CRAN-Apt when available
sudo tee /etc/apt/preferences.d/99-cranapt >/dev/null <<'EOF'
Package: *
Pin: release o=CRAN-Apt Project
Pin: release l=CRAN-Apt Packages
Pin-Priority: 700
EOF

sudo apt-get update -y
sudo apt-get install -y --no-install-recommends \
  r-base r-base-dev python3-apt python3-dbus sudo ca-certificates curl

# Passwordless sudo for invoking user (bspm likes this in non-proot)
sudo usermod -aG sudo "$TARGET_USER" || true
echo "$TARGET_USER ALL=(ALL) NOPASSWD:ALL" | sudo tee /etc/sudoers.d/99-${TARGET_USER}-r >/dev/null
sudo chmod 0440 /etc/sudoers.d/99-${TARGET_USER}-r

# Make apt noninteractive for future sessions
grep -q 'DEBIAN_FRONTEND=noninteractive' /etc/environment 2>/dev/null || \
  echo 'DEBIAN_FRONTEND=noninteractive' | sudo tee -a /etc/environment >/dev/null
grep -q 'DEBIAN_FRONTEND=noninteractive' /etc/bash.bashrc 2>/dev/null || \
  echo 'export DEBIAN_FRONTEND=noninteractive' | sudo tee -a /etc/bash.bashrc >/dev/null

# Common R config dirs
sudo install -d -m 0755 "$TARGET_HOME" /etc/R /etc/R/Rprofile.d
sudo chown "$TARGET_USER:$TARGET_USER" "$TARGET_HOME"

# --------------------------
# Runtime-specific behavior:
# --------------------------
if [ "$RUNTIME" = "proot" ]; then
  echo "[proot] Configure PPM-only (binary tarballs if available), fallback to source; no bspm."

  # Do NOT install bspm in proot (avoid apt hangs inside R sessions)
  # If it was installed, leave it alone but do not enable it.

  # Single site profile:
  sudo tee /etc/R/Rprofile.site >/dev/null <<'EOF'
local({
  codename <- tryCatch(system("lsb_release -cs", intern = TRUE), error = function(e) "noble")
  options(
    repos = c(
      PPM  = sprintf("https://packagemanager.posit.co/cran/__linux__/%s/latest", codename),
      CRAN = "https://cloud.r-project.org"
    ),
    # Keep 'source': PPM may serve precompiled Linux tarballs keyed off UA.
    # If not available, R will build from source automatically.
    pkgType = "source",
    # Hint to PPM so it may return precompiled tarballs via src/contrib.
    HTTPUserAgent = sprintf(
      "R; R (%s %s %s %s)",
      getRversion(), R.version$platform, R.version$arch, R.version$os
    )
  )
})
EOF

else
  echo "[non-proot] Enable bspm + r2u / CRAN-Apt; fallback to source when apt cannot satisfy."

  # Install bspm if available from apt
  if apt-cache show r-cran-bspm >/dev/null 2>&1; then
    sudo apt-get install -y r-cran-bspm
  else
    # Very rare on some arches; install from CRAN as a fallback
    sudo -u "$TARGET_USER" -H R --quiet --no-save -e 'install.packages("bspm", repos="https://cran.r-project.org")'
  fi

  # Site profile: PPM repo + enable bspm if present
  sudo tee /etc/R/Rprofile.site >/dev/null <<'EOF'
local({
  codename <- tryCatch(system("lsb_release -cs", intern = TRUE), error = function(e) "noble")
  options(
    repos   = c(CRAN = sprintf("https://packagemanager.posit.co/cran/__linux__/%s/latest", codename)),
    pkgType = "source"  # lets bspm intercept and use apt binaries
  )

  if (requireNamespace("bspm", quietly = TRUE)) {
    try({
      bspm::enable()
      options(bspm.sudo = TRUE, bspm.version.check = TRUE)
    }, silent = TRUE)
  }
})
EOF
fi

# Optional per-user .Rprofile (kept minimal/portable)
sudo tee "$TARGET_HOME/.Rprofile" >/dev/null <<EOF
# Use site-wide defaults; customize user options below if desired.
invisible(TRUE)
EOF
sudo chown "$TARGET_USER:$TARGET_USER" "$TARGET_HOME/.Rprofile"
sudo chmod 0644 "$TARGET_HOME/.Rprofile"

echo "==> Done."
if [ "$RUNTIME" = "proot" ]; then
  echo "R is configured to use Posit Package Manager (PPM) first; if no precompiled tarball, it builds from source."
  echo "No bspm, no apt calls from inside R (proot-safe)."
else
  echo "R is configured to use bspm (apt binaries via r2u/CRAN-Apt) and transparently fall back to source when needed."
fi
