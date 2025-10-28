#!/usr/bin/env bash
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive

sudo apt-get update
sudo apt-get install -y synaptic adwaita-icon-theme librsvg2-common software-properties-common
sudo add-apt-repository -y universe
sudo add-apt-repository -y multiverse
sudo apt-get update

echo "App manager ready (Synaptic + universe/multiverse)."
