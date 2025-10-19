#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail

# Installs rurima (which bundles ruri) on Termux and makes it Just Work™ with tsu/root.

if [ -x "${PREFIX:-}/bin/pkg" ]; then
    : "${PREFIX:=/data/data/com.termux/files/usr}"
    echo "[*] Detected Termux. Installing build/runtime dependencies…"
    pkg update -y
    pkg install -y git clang make autoconf automake libtool pkg-config \
        libseccomp libcap binutils tsu \
        xz-utils file coreutils curl jq tar gzip proot

    TMPDIR="$(mktemp -d)"
    cleanup() { rm -rf "$TMPDIR"; }
    trap cleanup EXIT

    echo "[*] Building rurima from source…"
    git clone --depth=1 https://github.com/RuriOSS/rurima.git "$TMPDIR/rurima"
    (
        cd "$TMPDIR/rurima"
        git submodule update --init --recursive
        ./autogen.sh
        CPPFLAGS="$(pkg-config --cflags libseccomp libcap 2>/dev/null || true)" \
        LDFLAGS="$(pkg-config --libs libseccomp libcap 2>/dev/null || true)" \
        ./configure --prefix="$PREFIX"
        make -j"$(nproc 2>/dev/null || echo 1)"

        # Install the real binary and ship a Termux-safe wrapper in bin.
        install -Dm755 ./rurima "$PREFIX/libexec/rurima"
        cat >"$PREFIX/bin/rurima" <<'EOF'
#!/data/data/com.termux/files/usr/bin/sh
# Termux-friendly rurima launcher:
# - Neutralize termux-exec preload (LD_PRELOAD)
# - Keep Termux libs visible (LD_LIBRARY_PATH)
# - Skip ruri's env-wiping re-exec (ruri_rexec=1) for bundled commands
PREFIX="/data/data/com.termux/files/usr"
unset LD_PRELOAD
export LD_LIBRARY_PATH="$PREFIX/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
export ruri_rexec=1
exec "$PREFIX/libexec/rurima" "$@"
EOF
        chmod 0755 "$PREFIX/bin/rurima"
        hash -r || true
    )
    echo "[*] rurima installed to $PREFIX/bin/rurima"

    echo "[*] Done."
    exit 0
fi

echo "This installer currently supports Termux (Android) only."
exit 1
