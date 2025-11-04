#!/usr/bin/env bash
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive

TARGET_USER="$(id -un)"
TARGET_HOME="$(getent passwd "$TARGET_USER" 2>/dev/null | cut -d: -f6 || echo "$HOME")"

. /etc/os-release
CODENAME="${UBUNTU_CODENAME}"
ARCH="$(dpkg --print-architecture)"

echo "==> Ubuntu: ${CODENAME}  arch: ${ARCH}  user: ${TARGET_USER}"

sudo install -d -m 0755 /usr/share/keyrings
sudo apt-get update
sudo apt-get install -y --no-install-recommends gnupg ca-certificates curl

curl -fsSL https://cloud.r-project.org/bin/linux/ubuntu/marutter_pubkey.asc \
  | sudo gpg --dearmor -o /usr/share/keyrings/cran_ubuntu_key.gpg
printf 'deb [arch=%s signed-by=/usr/share/keyrings/cran_ubuntu_key.gpg] https://cloud.r-project.org/bin/linux/ubuntu %s-cran40/\n' \
  "$ARCH" "$CODENAME" | sudo tee /etc/apt/sources.list.d/cran_r.list >/dev/null

sudo gpg --homedir /tmp --no-default-keyring \
  --keyring /usr/share/keyrings/r2u.gpg \
  --keyserver keyserver.ubuntu.com \
  --recv-keys A1489FE2AB99A21A 67C2D66C4B1D4339 51716619E084DAB9

if { [ "$ARCH" = "amd64" ] || { [ "$ARCH" = "arm64" ] && [ "$CODENAME" = "noble" ]; }; }; then
  printf 'deb [arch=%s signed-by=/usr/share/keyrings/r2u.gpg] https://r2u.stat.illinois.edu/ubuntu %s main\n' \
    "$ARCH" "$CODENAME" | sudo tee /etc/apt/sources.list.d/r2u.list >/dev/null
fi

sudo tee /etc/apt/preferences.d/99-cranapt >/dev/null <<'EOF'
Package: *
Pin: release o=CRAN-Apt Project
Pin: release l=CRAN-Apt Packages
Pin-Priority: 700
EOF

sudo apt-get update -y
sudo apt-get install -y --no-install-recommends r-base r-base-dev python3-apt python3-dbus sudo ca-certificates curl

if apt-cache show r-cran-bspm >/dev/null 2>&1; then
  sudo apt-get install -y r-cran-bspm
else
  sudo -u "$TARGET_USER" -H R --quiet --no-save -e 'install.packages("bspm", repos="https://cran.r-project.org")'
fi

sudo usermod -aG sudo "$TARGET_USER"
echo "$TARGET_USER ALL=(ALL) NOPASSWD:ALL" | sudo tee /etc/sudoers.d/99-${TARGET_USER}-r >/dev/null
sudo chmod 0440 /etc/sudoers.d/99-${TARGET_USER}-r

# User .Rprofile with HTTPUserAgent fix
sudo install -d -m 0755 "$TARGET_HOME"
sudo tee "$TARGET_HOME/.Rprofile" >/dev/null <<'EOF'
# HTTPUserAgent is critical for bspm to work correctly
options(
  repos = c(CRAN = "https://packagemanager.posit.co/cran/__linux__/noble/latest"),
  HTTPUserAgent = sprintf(
    "R; R (%s %s %s %s)",
    getRversion(),
    R.version$platform,
    R.version$arch,
    R.version$os
  ),
  pkgType = "source"
)

if (requireNamespace("bspm", quietly = TRUE)) {
  suppressMessages(try(bspm::enable(), silent = TRUE))
  options(bspm.version.check = TRUE, bspm.sudo = TRUE)
}
EOF
sudo chown "$TARGET_USER:$TARGET_USER" "$TARGET_HOME/.Rprofile"
sudo chmod 0644 "$TARGET_HOME/.Rprofile"

# Site-wide Rprofile with HTTPUserAgent fix
sudo install -d -m 0755 /etc/R
sudo tee /etc/R/Rprofile.site >/dev/null <<'EOF'
local({
  # HTTPUserAgent is critical for bspm to work correctly
  options(
    repos = c(CRAN = "https://packagemanager.posit.co/cran/__linux__/noble/latest"),
    HTTPUserAgent = sprintf(
      "R; R (%s %s %s %s)",
      getRversion(),
      R.version$platform,
      R.version$arch,
      R.version$os
    ),
    pkgType = "source"
  )
  
  if (requireNamespace("bspm", quietly = TRUE)) {
    suppressMessages(try(bspm::enable(), silent = TRUE))
    options(bspm.sudo = TRUE, bspm.version.check = TRUE)
  }
})
EOF
sudo chmod 0644 /etc/R/Rprofile.site

echo "==> Done."
echo "R is configured to install binary packages via bspm + r2u (${ARCH})."
echo "Use install.packages() normally - packages will be installed as .deb files via apt."