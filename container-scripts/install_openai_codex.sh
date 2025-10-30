#!/usr/bin/env bash
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive

echo "[*] Installing Node.js and npm..."
# Install Node.js via NodeSource (official Node.js repository)
# This ensures we get a recent version of npm
sudo apt-get update
sudo apt-get install -y curl ca-certificates gnupg

# Add NodeSource repository for Node.js LTS
sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key \
  | sudo gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg

# Use Node.js 20.x LTS
NODE_MAJOR=20
echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_$NODE_MAJOR.x nodistro main" \
  | sudo tee /etc/apt/sources.list.d/nodesource.list

sudo apt-get update
sudo apt-get install -y nodejs

# Verify installation
echo "[*] Verifying Node.js and npm versions..."
node --version
npm --version

echo "[*] Installing OpenAI Codex CLI globally..."
# Install @openai/codex globally so it's available as 'codex' command
sudo npm install -g @openai/codex

# Verify codex is available
echo "[*] Verifying Codex installation..."
command -v codex || { echo "ERROR: codex command not found after install"; exit 1; }

echo
echo "✅ OpenAI Codex CLI installed successfully!"
echo
echo "Usage:"
echo "  1. Run 'codex' to get started"
echo "  2. You'll need an OpenAI API key - set it with:"
echo "     export OPENAI_API_KEY='your-api-key-here'"
echo "  3. Or configure it when prompted by the CLI"
