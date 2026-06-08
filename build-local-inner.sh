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
if [ ! -d sdk/android-ndk-* ] || [ ! -d deps/mpv ]; then
    echo '── Downloading Android SDK/NDK + deps (first run) ──'
    ./download.sh
fi

# Build mpv for each ABI. buildall.sh walks the dep graph so libdovi →
# libplacebo + libdovi → ffmpeg → libass → mpv all build in correct order.
for arch in arm64 armv7l x86_64 x86; do
    echo
    echo "═══ Building for $arch ═══"
    ./buildall.sh --arch "$arch" mpv
done

# Map our naming to Android ABI names + collect the produced .so files.
mkdir -p /dist
for arch in arm64 armv7l x86_64 x86; do
    case "$arch" in
        arm64)  abi=arm64-v8a ;;
        armv7l) abi=armeabi-v7a ;;
        x86_64) abi=x86_64 ;;
        x86)    abi=x86 ;;
    esac
    mkdir -p "/dist/$abi"
    # mpv-android writes built artifacts into prefix-<arch>/lib/
    prefix_lib=$(find . -maxdepth 2 -type d -name "prefix-*$arch*" | head -1)/lib
    if [ ! -d "$prefix_lib" ]; then
        echo "No prefix dir found for $arch — search: $(find . -maxdepth 2 -type d -name 'prefix-*' | tr '\n' ' ')"
        continue
    fi
    cp -v "$prefix_lib"/lib*.so "/dist/$abi/" 2>/dev/null || true

    # Sanity: verify libdovi symbols are present in libmpv.so
    if [ -f "/dist/$abi/libmpv.so" ]; then
        echo "── DV symbols in $abi/libmpv.so ──"
        nm -D --defined-only "/dist/$abi/libmpv.so" 2>/dev/null | \
            grep -iE 'dovi|reshape' | head -5 || \
            echo "  (none found — libdovi not linked?)"
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
