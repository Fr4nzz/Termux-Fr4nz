#!/usr/bin/env bash
set -euo pipefail

# Installs both ruri and rurima on Termux without user prompts.

if [ -x "${PREFIX:-}/bin/pkg" ]; then
    echo "[*] Detected Termux environment. Installing dependencies and building from source."
    : "${PREFIX:=/data/data/com.termux/files/usr}"
    pkg update -y
    echo "[*] Installing build dependencies…"
    pkg install -y git clang make autoconf automake libtool pkg-config libseccomp libcap binutils
    echo "[*] Installing runtime dependencies…"
    pkg install -y xz file coreutils curl jq tar gzip proot

    TMPDIR="$(mktemp -d)"
    cleanup() {
        rm -rf "$TMPDIR"
    }
    trap cleanup EXIT

    echo "[*] Building ruri from source…"
    git clone --depth=1 https://github.com/RuriOSS/ruri.git "$TMPDIR/ruri"
    (
        cd "$TMPDIR/ruri"
        ./autogen.sh
        CPPFLAGS="$(pkg-config --cflags libseccomp)" \
        LDFLAGS="$(pkg-config --libs libseccomp)" \
        ./configure --prefix="$PREFIX"
        make -j"$(nproc 2>/dev/null || echo 1)"
        install -m 755 ./ruri "$PREFIX/bin/ruri"
    )
    echo "[*] ruri installed to $PREFIX/bin/ruri"

    echo "[*] Building rurima from source…"
    git clone --depth=1 https://github.com/RuriOSS/rurima.git "$TMPDIR/rurima"
    (
        cd "$TMPDIR/rurima"
        git submodule update --init --recursive
        ./autogen.sh
        CPPFLAGS="$(pkg-config --cflags libseccomp)" \
        LDFLAGS="$(pkg-config --libs libseccomp)" \
        ./configure --prefix="$PREFIX"
        make -j"$(nproc 2>/dev/null || echo 1)"
        install -m 755 ./rurima "$PREFIX/bin/rurima"
    )
    echo "[*] rurima installed to $PREFIX/bin/rurima"

    echo "[*] Done. You can now use ruri and rurima from Termux."
    exit 0
fi

echo "This installer currently supports Termux (Android) only."
exit 1
