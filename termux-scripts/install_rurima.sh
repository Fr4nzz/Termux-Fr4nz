#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail

# Installs rurima (which bundles ruri) on Termux using Termux's environment.

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
        CFLAGS="${CFLAGS:-} -fPIE" \
        LDFLAGS="-pie $(pkg-config --libs libseccomp libcap 2>/dev/null || true)" \
        ./configure --prefix="$PREFIX"
        make -j"$(nproc 2>/dev/null || echo 1)"
        install -Dm755 ./rurima "$PREFIX/libexec/rurima.real"
        cat >"$PREFIX/bin/rurima" <<'SH'
#!/data/data/com.termux/files/usr/bin/sh
PREFIX=/data/data/com.termux/files/usr
exec "$PREFIX/libexec/rurima.real" "$@"
SH
        chmod 0755 "$PREFIX/bin/rurima"
        hash -r || true
    )
    echo "[*] rurima installed: wrapper => $PREFIX/bin/rurima, real => $PREFIX/libexec/rurima.real"

    echo "[*] Done."
    exit 0
fi

echo "This installer currently supports Termux (Android) only."
exit 1
