#!/usr/bin/env bash
set -euo pipefail

# Run INSIDE the Ubuntu container.
# Usage:
#   bash apt_heal.sh                 # just repair apt/dpkg
#   bash apt_heal.sh pkg1 pkg2 ...   # repair + then install listed packages

# keep it quiet-ish but predictable in non-interactive shells
export DEBIAN_FRONTEND=noninteractive
export APT_LISTCHANGES_FRONTEND=none
# zstd sometimes trips in proot; keep it single-threaded to reduce flakiness
export ZSTD_NBTHREADS=1

log(){ printf '\n==> %s\n' "$*"; }

log "Killing stray apt/dpkg if any…"
sudo killall -q apt apt-get dpkg 2>/dev/null || true

log "Removing apt/dpkg lock files…"
for f in \
  /var/lib/dpkg/lock-frontend /var/lib/dpkg/lock \
  /var/lib/apt/lists/lock /var/cache/apt/archives/lock
do
  sudo rm -f "$f" || true
done

log "Finishing any half-configured packages…"
sudo dpkg --configure -a || true
sudo apt-get -f install -y || true

log "Cleaning apt caches and partials…"
sudo apt-get clean
sudo rm -rf /var/cache/apt/archives/partial/* /var/lib/apt/lists/partial/* || true
sudo rm -rf /var/lib/apt/lists/* || true

# Prefer gz for package lists (lighter for proot); harmless on real systems, too
if [ ! -f /etc/apt/apt.conf.d/99compress-gz ]; then
  log "Tuning apt to prefer gz lists (faster/more reliable on proot)…"
  echo 'Acquire::CompressionTypes::Order:: "gz";' \
  | sudo tee /etc/apt/apt.conf.d/99compress-gz >/dev/null
fi

log "apt-get update…"
sudo apt-get update -y

log "Reinstalling core tools used during .deb unpack…"
sudo apt-get install -y --reinstall \
  dpkg apt libzstd1 tar xz-utils gzip zstd || true

# Try one more time to settle anything
sudo dpkg --configure -a || true
sudo apt-get -f install -y || true

log "All done. apt/dpkg look good."
