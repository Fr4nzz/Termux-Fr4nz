# container-scripts/Rprofile.d/000-smart-install.R
# Smart package installer:
#   PPM binary tarballs -> bspm/apt -> source
# Works in chroot/WSL and proot (skips apt if not responsive).

smart_install <- function(pkgs,
                          ppm_codename = tryCatch(system("lsb_release -cs", intern = TRUE),
                                                  error = function(e) "noble"),
                          ppm_base = NULL,
                          timeout_ppm  = 120,   # seconds for PPM attempt
                          timeout_bspm = 90,    # seconds for bspm/apt attempt
                          ...) {
  stopifnot(length(pkgs) >= 1)
  pkgs <- unique(pkgs)

  # PPM base and 'binary contrib' URL (no special UA needed)
  if (is.null(ppm_base) || is.na(ppm_base)) {
    ppm_base <- sprintf("https://packagemanager.posit.co/cran/__linux__/%s/latest", ppm_codename)
  }
  ppm_bin_contrib <- sprintf("%s/bin/linux/ubuntu/%s", ppm_base, ppm_codename)

  with_tl <- function(sec, expr) {
    on.exit(setTimeLimit(cpu = Inf, elapsed = Inf, transient = FALSE), add = TRUE)
    setTimeLimit(elapsed = sec, transient = TRUE)
    force(expr)
  }

  # ---- Try 1: PPM binary tarballs (fastest, works in proot) ----
  message("smart_install: trying PPM binaries…")
  ap <- tryCatch(utils::available.packages(contriburl = ppm_bin_contrib),
                 error = function(e) NULL)

  if (!is.null(ap)) {
    have_bin <- pkgs[pkgs %in% rownames(ap)]
    if (length(have_bin)) {
      ok_ppm <- tryCatch(
        with_tl(timeout_ppm, {
          utils::install.packages(have_bin,
                                  repos      = NULL,
                                  contriburl = ppm_bin_contrib,
                                  type       = "source",  # use binary index via contriburl
                                  ...)
          TRUE
        }),
        error = function(e) { message("PPM binary failed: ", conditionMessage(e)); FALSE }
      )
      if (isTRUE(ok_ppm) && length(have_bin) == length(pkgs)) return(invisible(TRUE))
      pkgs <- setdiff(pkgs, have_bin)
    } else {
      message("No PPM binaries in index for requested pkgs; continuing…")
    }
  } else {
    message("PPM binary index unavailable; continuing…")
  }

  # All done by PPM?
  if (!length(pkgs)) return(invisible(TRUE))

  # ---- Try 2: bspm/apt (skip quickly if apt not responsive; avoids proot hang) ----
  use_bspm <- requireNamespace("bspm", quietly = TRUE)
  if (use_bspm) {
    # Quick liveness probe (10s) so we don't stall in proot
    apt_alive <- (system("timeout 10s bash -lc 'apt-get -qq update'",
                         ignore.stdout = TRUE, ignore.stderr = TRUE) == 0)
    if (apt_alive) {
      message("smart_install: trying bspm/apt…")
      try(bspm::enable(), silent = TRUE)
      ok_bspm <- tryCatch(
        with_tl(timeout_bspm, {
          utils::install.packages(pkgs, type = "source", ...)
          TRUE
        }),
        error = function(e) { message("bspm/apt failed: ", conditionMessage(e)); FALSE }
      )
      if (isTRUE(ok_bspm)) return(invisible(TRUE))
    } else {
      message("smart_install: apt not responsive; skipping bspm.")
    }
  } else {
    message("smart_install: bspm not installed; skipping.")
  }

  # ---- Try 3: source fallback (guaranteed path) ----
  message("smart_install: falling back to source…")
  repos <- getOption("repos")
  if (is.null(repos) || identical(repos, c(CRAN = "@CRAN@"))) {
    options(repos = c(CRAN = ppm_base))
  }

  dots <- list(...)
  if (is.null(dots$Ncpus)) dots$Ncpus <- max(1L, as.integer(parallel::detectCores(TRUE) - 1L))
  do.call(utils::install.packages, c(list(pkgs = pkgs, type = "source"), dots))
  invisible(TRUE)
}

# Optional: transparently replace install.packages() (default ON).
# Disable by setting SMART_IP_PATCH=0 in the environment.
if (identical(tolower(Sys.getenv("SMART_IP_PATCH", "1")), "1")) {
  install.packages <- function(pkgs, ...) smart_install(pkgs, ...)
}
