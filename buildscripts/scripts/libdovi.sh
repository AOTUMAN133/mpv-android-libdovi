#!/bin/bash -e

# libdovi — Dolby Vision RPU decoder (Rust crate from quietvoid/dovi_tool).
# Built via cargo-c so we get a proper static .a + libdovi.pc that
# libplacebo's meson and ffmpeg's configure can both consume via
# pkg-config. Cross-compiled per Android NDK ABI.

. ../../include/path.sh

if [ "$1" == "build" ]; then
    true
elif [ "$1" == "clean" ]; then
    rm -rf _build$ndk_suffix
    exit 0
else
    exit 255
fi

# Map the loadarch-style ndk_triple to the Rust target triple cargo expects.
case "$ndk_triple" in
    aarch64-linux-android)   rust_target=aarch64-linux-android ;;
    arm-linux-androideabi)   rust_target=armv7-linux-androideabi ;;
    x86_64-linux-android)    rust_target=x86_64-linux-android ;;
    i686-linux-android)      rust_target=i686-linux-android ;;
    *) echo "Unknown ndk_triple for Rust target: $ndk_triple" >&2; exit 1 ;;
esac

# rustup must already be on PATH (the GH Action installs it). Add the
# target if it isn't there yet — idempotent, no-op when present.
rustup target add "$rust_target" >/dev/null 2>&1 || true

# cargo-c must already be installed (workflow does `cargo install cargo-c`).

# Tell cargo which linker to use for this target. cargo reads from env
# vars named CARGO_TARGET_<TARGET_UPPER_UNDERSCORED>_LINKER.
target_upper=$(echo "$rust_target" | tr 'a-z-' 'A-Z_')
declare -x "CARGO_TARGET_${target_upper}_LINKER=$CC"
# Same for AR (cargo-c uses it for the static archive).
export AR="${ndk_triple}-ar"
[ -x "$(command -v llvm-ar)" ] && export AR=llvm-ar

# Build + install via cargo-c. Produces:
#   $prefix_dir/lib/libdovi.a
#   $prefix_dir/lib/pkgconfig/dovi.pc
# (cargo-c uses the crate's [package].name = "dovi" so the .pc is dovi.pc;
#  libplacebo's meson asks for dependency('dovi'), so this matches.)
cargo cinstall \
    --release \
    --target="$rust_target" \
    --library-type=staticlib \
    --prefix=/ \
    --destdir="$prefix_dir" \
    --manifest-path=./dolby_vision/Cargo.toml

# cargo-c's --prefix=/ + --destdir places files under
# $prefix_dir/lib + $prefix_dir/include. The default --libdir is "lib"
# which is correct for our flat prefix layout.

# Sanity check.
if [ ! -f "$prefix_dir/lib/libdovi.a" ]; then
    echo "libdovi.a not produced — cargo-cinstall layout differs?" >&2
    ls -R "$prefix_dir/lib" >&2 || true
    exit 1
fi
