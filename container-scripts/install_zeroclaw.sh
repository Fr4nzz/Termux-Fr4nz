#!/usr/bin/env bash
# Install ZeroClaw AI agent inside an Ubuntu container (chroot or proot).
# Pre-built aarch64 binary — no Rust toolchain needed.

set -euo pipefail
export DEBIAN_FRONTEND=noninteractive

say(){ printf "\n[%s] %s\n" "$1" "$2"; }

say "1/3" "Install dependencies..."
apt-get update -qq
apt-get install -y -qq curl ca-certificates tar sqlite3

say "2/3" "Download ZeroClaw..."
arch="$(dpkg --print-architecture 2>/dev/null || uname -m)"
case "$arch" in
  arm64|aarch64) target="aarch64-unknown-linux-gnu" ;;
  amd64|x86_64)  target="x86_64-unknown-linux-gnu" ;;
  *)             echo "Unsupported architecture: $arch"; exit 1 ;;
esac

tmpdir="$(mktemp -d)"; trap 'rm -rf "$tmpdir"' EXIT

DL_URL="https://github.com/zeroclaw-labs/zeroclaw/releases/latest/download/zeroclaw-${target}.tar.gz"
echo "  Fetching $DL_URL"
curl -fsSL "$DL_URL" -o "$tmpdir/zeroclaw.tar.gz"

say "3/3" "Install to /usr/local/bin..."
tar -xzf "$tmpdir/zeroclaw.tar.gz" -C "$tmpdir"
install -m 0755 "$tmpdir/zeroclaw" /usr/local/bin/zeroclaw

echo ""
echo "ZeroClaw $(zeroclaw --version 2>/dev/null || echo 'installed')"
echo ""
echo "Next steps (choose one):"
echo ""
echo "  Option A — API key:"
echo "    zeroclaw onboard --api-key sk-... --provider openai"
echo ""
echo "  Option B — ChatGPT OAuth (no API key needed):"
echo "    zeroclaw onboard --provider openai-codex"
echo "    zeroclaw auth login --provider openai-codex"
echo ""
echo "  Start the agent:"
echo "    zeroclaw agent              # interactive chat"
echo "    zeroclaw daemon             # background service + Telegram"
echo ""
