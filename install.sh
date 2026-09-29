#!/bin/bash
# Builds cosmic-term with the right-to-left patch and installs it for the current user.
# Nothing outside the home folder is touched. Remove ~/.local/bin/cosmic-term to undo.
set -euo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
build="$here/build"
src="$build/cosmic-term"
libs="$build/libs"
out="${PREFIX:-$HOME/.local}/bin/cosmic-term"
pinned=9129277

for tool in git cargo pkg-config; do
    command -v "$tool" >/dev/null || { echo "missing: $tool" >&2; exit 1; }
done

# Build the version the system already has, when the package manager can tell us.
# Set COSMIC_TERM_REF to a commit or tag to pick one by hand.
ref="${COSMIC_TERM_REF:-}"
if [ -z "$ref" ] && command -v dpkg-query >/dev/null; then
    ver="$(dpkg-query -W -f='${Version}' cosmic-term 2>/dev/null || true)"
    case "$ver" in
        *~*) ref="${ver##*~}" ;;
    esac
fi
ref="${ref:-$pinned}"
echo "building cosmic-term at $ref"

mkdir -p "$build"
if [ ! -d "$src/.git" ]; then
    git clone --quiet https://github.com/pop-os/cosmic-term.git "$src"
fi
cd "$src"
git fetch --quiet origin
git reset --quiet --hard
git clean --quiet -fd -- src
git checkout --quiet "$ref"
git apply "$here/cosmic-term-rtl.patch"

# The build only needs libxkbcommon to link against. If the development package is
# not installed, point the build at the library that is already on the system.
if ! pkg-config --exists xkbcommon 2>/dev/null; then
    lib="$(ldconfig -p | awk '$1 == "libxkbcommon.so.0" && !seen { print $NF; seen = 1 }')"
    if [ -z "$lib" ]; then
        echo "libxkbcommon is not installed" >&2
        exit 1
    fi
    mkdir -p "$libs/pkgconfig"
    ln -sfn "$lib" "$libs/libxkbcommon.so"
    cat > "$libs/pkgconfig/xkbcommon.pc" <<PC
libdir=$libs

Name: xkbcommon
Description: local stand-in for the xkbcommon development files
Version: 1.0.0
Libs: -L\${libdir} -lxkbcommon
Cflags:
PC
    export PKG_CONFIG_PATH="$libs/pkgconfig${PKG_CONFIG_PATH:+:$PKG_CONFIG_PATH}"
    export RUSTFLAGS="-L native=$libs"
fi

nice -n 15 cargo build --release -j "${JOBS:-$(nproc)}"

install -D -m755 -s target/release/cosmic-term "$out.new"
mv -f "$out.new" "$out"
echo "installed: $out"

found="$(command -v cosmic-term || true)"
if [ "$found" != "$out" ]; then
    echo "note: 'cosmic-term' still starts ${found:-nothing}."
    echo "      Put $(dirname "$out") before /usr/bin in PATH, then log out and in."
fi
echo "open a new terminal window to use it"
