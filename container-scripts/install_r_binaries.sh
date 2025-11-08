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

# CRAN apt repo
curl -fsSL https://cloud.r-project.org/bin/linux/ubuntu/marutter_pubkey.asc \
  | sudo gpg --dearmor -o /usr/share/keyrings/cran_ubuntu_key.gpg
printf 'deb [arch=%s signed-by=/usr/share/keyrings/cran_ubuntu_key.gpg] https://cloud.r-project.org/bin/linux/ubuntu %s-cran40/\n' \
  "$ARCH" "$CODENAME" | sudo tee /etc/apt/sources.list.d/cran_r.list >/dev/null

# r2u repo (amd64, and arm64 on noble)
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

# bspm (OK to be present; smart installer only uses it when apt is responsive)
if apt-cache show r-cran-bspm >/dev/null 2>&1; then
  sudo apt-get install -y r-cran-bspm
else
  sudo -u "$TARGET_USER" -H R --quiet --no-save -e 'install.packages("bspm", repos="https://cran.r-project.org")'
fi

# Passwordless sudo for the invoking user (keeps bspm happy)
sudo usermod -aG sudo "$TARGET_USER" || true
echo "$TARGET_USER ALL=(ALL) NOPASSWD:ALL" | sudo tee /etc/sudoers.d/99-${TARGET_USER}-r >/dev/null
sudo chmod 0440 /etc/sudoers.d/99-${TARGET_USER}-r

# Make apt noninteractive for future bspm calls
grep -q 'DEBIAN_FRONTEND=noninteractive' /etc/environment 2>/dev/null || \
  echo 'DEBIAN_FRONTEND=noninteractive' | sudo tee -a /etc/environment >/dev/null
grep -q 'DEBIAN_FRONTEND=noninteractive' /etc/bash.bashrc 2>/dev/null || \
  echo 'export DEBIAN_FRONTEND=noninteractive' | sudo tee -a /etc/bash.bashrc >/dev/null

# Base R profiles
sudo install -d -m 0755 "$TARGET_HOME" /etc/R /etc/R/Rprofile.d
sudo tee "$TARGET_HOME/.Rprofile" >/dev/null <<EOF
# Keep repos on PPM; smart installer will prefer PPM binaries automatically.
options(
  repos = c(CRAN = "https://packagemanager.posit.co/cran/__linux__/${CODENAME}/latest"),
  pkgType = "source"
)
EOF
sudo chown "$TARGET_USER:$TARGET_USER" "$TARGET_HOME/.Rprofile"
sudo chmod 0644 "$TARGET_HOME/.Rprofile"

# Rprofile.site: set repos + source /etc/R/Rprofile.d/*.R + enable bspm gently
sudo tee /etc/R/Rprofile.site >/dev/null <<'EOF'
local({
  # Use PPM as the CRAN mirror
  codename <- tryCatch(system("lsb_release -cs", intern = TRUE), error = function(e) "noble")
  options(repos = c(CRAN = sprintf("https://packagemanager.posit.co/cran/__linux__/%s/latest", codename)))
  options(pkgType = "source")  # allows bspm interception when used

  # Load any site snippets
  d <- "/etc/R/Rprofile.d"
  if (dir.exists(d)) {
    fs <- sort(list.files(d, pattern = "\\.[Rr]$", full.names = TRUE))
    for (f in fs) {
      try(source(f, local = TRUE), silent = TRUE)
    }
  }

  # Make bspm available if installed; smart installer will decide when to use it
  if (requireNamespace("bspm", quietly = TRUE)) {
    try({
      bspm::enable()
      options(bspm.sudo = TRUE, bspm.version.check = TRUE)
    }, silent = TRUE)
  }
})
EOF
sudo chmod 0644 /etc/R/Rprofile.site

# --- Install the smart installer into /etc/R/Rprofile.d ---
sudo tee /etc/R/Rprofile.d/000-smart-install.R >/dev/null <<'EOF'
# (installed from repo) Smart PPM -> bspm -> source helper
smart_install <- function(pkgs,
                          ppm_codename = tryCatch(system("lsb_release -cs", intern = TRUE),
                                                  error = function(e) "noble"),
                          ppm_base = NULL,
                          timeout_ppm  = 120,
                          timeout_bspm = 90,
                          ...) {
  stopifnot(length(pkgs) >= 1)
  pkgs <- unique(pkgs)
  if (is.null(ppm_base) || is.na(ppm_base)) {
    ppm_base <- sprintf("https://packagemanager.posit.co/cran/__linux__/%s/latest", ppm_codename)
  }
  ppm_bin_contrib <- sprintf("%s/bin/linux/ubuntu/%s", ppm_base, ppm_codename)
  with_tl <- function(sec, expr) { on.exit(setTimeLimit(cpu=Inf,elapsed=Inf,transient=FALSE),add=TRUE); setTimeLimit(elapsed=sec,transient=TRUE); force(expr) }

  message("smart_install: trying PPM binaries…")
  ap <- tryCatch(utils::available.packages(contriburl = ppm_bin_contrib), error = function(e) NULL)
  if (!is.null(ap)) {
    have_bin <- pkgs[pkgs %in% rownames(ap)]
    if (length(have_bin)) {
      ok_ppm <- tryCatch(with_tl(timeout_ppm, {
        utils::install.packages(have_bin, repos=NULL, contriburl=ppm_bin_contrib, type="source", ...)
        TRUE
      }), error = function(e) { message("PPM binary failed: ", conditionMessage(e)); FALSE })
      if (isTRUE(ok_ppm) && length(have_bin) == length(pkgs)) return(invisible(TRUE))
      pkgs <- setdiff(pkgs, have_bin)
    } else message("No PPM binaries in index for requested pkgs; continuing…")
  } else message("PPM binary index unavailable; continuing…")
  if (!length(pkgs)) return(invisible(TRUE))

  use_bspm <- requireNamespace("bspm", quietly = TRUE)
  if (use_bspm) {
    apt_alive <- (system("timeout 10s bash -lc 'apt-get -qq update'", ignore.stdout=TRUE, ignore.stderr=TRUE) == 0)
    if (apt_alive) {
      message("smart_install: trying bspm/apt…")
      try(bspm::enable(), silent = TRUE)
      ok_bspm <- tryCatch(with_tl(timeout_bspm, { utils::install.packages(pkgs, type="source", ...); TRUE }),
                          error = function(e) { message("bspm/apt failed: ", conditionMessage(e)); FALSE })
      if (isTRUE(ok_bspm)) return(invisible(TRUE))
    } else message("smart_install: apt not responsive; skipping bspm.")
  } else message("smart_install: bspm not installed; skipping.")

  message("smart_install: falling back to source…")
  repos <- getOption("repos"); if (is.null(repos) || identical(repos, c(CRAN="@CRAN@")))
    options(repos = c(CRAN = ppm_base))
  dots <- list(...); if (is.null(dots$Ncpus)) dots$Ncpus <- max(1L, as.integer(parallel::detectCores(TRUE) - 1L))
  do.call(utils::install.packages, c(list(pkgs = pkgs, type = "source"), dots))
  invisible(TRUE)
}

if (identical(tolower(Sys.getenv("SMART_IP_PATCH", "1")), "1")) {
  install.packages <- function(pkgs, ...) smart_install(pkgs, ...)
}
EOF

echo "==> Done."
echo "R is configured to prefer PPM binaries, then bspm (if apt is responsive), then source."
