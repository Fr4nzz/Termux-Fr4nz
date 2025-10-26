#!/usr/bin/env bash
set -euo pipefail
if [[ $EUID -ne 0 ]]; then exec sudo -E bash "$0" "$@"; fi
export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y synaptic adwaita-icon-theme librsvg2-common software-properties-common
add-apt-repository -y universe
add-apt-repository -y multiverse
apt-get update
echo "App manager ready (Synaptic + universe/multiverse)."
