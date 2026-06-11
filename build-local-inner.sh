#!/bin/bash -e
#
# Runs inside the cyfer-mpv-builder container.
# Builds libmpv for all 4 Android ABIs with libdovi statically linked,
# then copies the per-ABI native .so files into /dist/<abi>/.
#
# First run: ~90-150 min (downloads NDK 1.2GB, builds everything fresh).
# Repeat runs: ~10-30 min (NDK + deps cached on the mounted volume;
# only changed components rebuilt).

cd /src/buildscripts

# Download Android NDK + dep tarballs (idempotent; skips already-downloaded).
# Use shopt+glob expansion since `[ -d foo* ]` doesn't expand globs.
shopt -s nullglob
ndk_dirs=(sdk/android-ndk-*)
shopt -u nullglob
if [ ${#ndk_dirs[@]} -eq 0 ] || [ ! -d deps/mpv ]; then
    echo '── Downloading Android SDK/NDK + deps ──'
    ./download.sh
fi

# Build mpv for each ABI. mpv-android segregates output per-arch under
# prefix/<arch>/lib/ so we just copy from there after each invocation.
mkdir -p /dist

for arch in arm64 armv7l x86_64 x86; do
    case "$arch" in
        arm64)  abi=arm64-v8a ;;
        armv7l) abi=armeabi-v7a ;;
        x86_64) abi=x86_64 ;;
        x86)    abi=x86 ;;
    esac

    echo
    echo "═══ Building for $arch (→ /dist/$abi) ═══"
    ./buildall.sh --arch "$arch" mpv

    prefix_lib="prefix/$arch/lib"
    if [ ! -d "$prefix_lib" ]; then
        echo "[FAIL] No $prefix_lib after building $arch — buildall.sh did not produce artifacts."
        ls -la "prefix/$arch" 2>/dev/null || true
        continue
    fi

    # Snapshot every .so the build produced into the per-ABI dist dir.
    mkdir -p "/dist/$abi"
    rm -f "/dist/$abi"/*.so
    found_so=0
    for so in "$prefix_lib"/lib*.so; do
        [ -f "$so" ] || continue
        cp -v "$so" "/dist/$abi/"
        found_so=1
    done
    if [ $found_so -eq 0 ]; then
        echo "[WARN] No .so files in $prefix_lib (only static archives?). Contents:"
        ls "$prefix_lib" | head -20
    fi

    # Verify libdovi symbols are in libmpv.so — the key sanity check.
    if [ -f "/dist/$abi/libmpv.so" ]; then
        echo "── DV symbols in $abi/libmpv.so ──"
        nm -D --defined-only "/dist/$abi/libmpv.so" 2>/dev/null | \
            grep -iE 'dovi|reshape' | head -5 \
          || echo "  (none — libdovi not linked into libmpv?)"
    fi
done

echo
echo '═══ Build complete ═══'
echo 'Per-ABI artifacts in /dist/:'
ls -la /dist/
for abi in arm64-v8a armeabi-v7a x86_64 x86; do
    if [ -d "/dist/$abi" ]; then
        echo "  $abi: $(ls /dist/$abi | wc -l) files, $(du -sh /dist/$abi | awk '{print $1}')"
    fi
done
