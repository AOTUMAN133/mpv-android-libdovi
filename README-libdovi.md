# mpv-android with libdovi

Fork of [mpv-android/mpv-android](https://github.com/mpv-android/mpv-android) that builds libmpv with **libdovi** statically linked into libplacebo + ffmpeg. This enables full Dolby Vision decoding (profiles 5, 7, 8.1, 8.4) instead of only the HDR10 base-layer fallback.

## What's changed vs upstream

| File | Change |
| --- | --- |
| `buildscripts/include/depinfo.sh` | Added `v_libdovi`, `dep_libdovi`, and made libplacebo + ffmpeg depend on it |
| `buildscripts/include/download-deps.sh` | Fetch libdovi tarball from `quietvoid/dovi_tool` release |
| `buildscripts/scripts/libdovi.sh` | New — `cargo cinstall` cross-compile per NDK ABI |
| `buildscripts/scripts/libplacebo.sh` | `-Ddovi=enabled` to meson |
| `buildscripts/scripts/ffmpeg.sh` | `--enable-libdovi` to configure |
| `.github/workflows/build-libdovi.yml` | New — builds all 4 ABIs on Ubuntu, uploads per-ABI ZIPs as a Release |

## Triggering a build

Push to the `libdovi` branch or run the workflow manually:

```
gh workflow run "Build mpv-android with libdovi"
```

Build takes ~60–90 min total (in parallel across the 4 ABIs).

## Consuming the output

Each Release contains `arm64-v8a.zip`, `armeabi-v7a.zip`, `x86_64.zip`, `x86.zip`. Each ZIP contains the native `.so` files (libmpv, libavcodec, libplacebo, libdovi, …).

Repackage into an AAR matching the `mpv-android-lib` structure, then drop into your app's `libs/` and reference via Gradle:

```gradle
implementation files('libs/mpv-android-lib-libdovi.aar')
```

## Notes for the future

- `cargo-c` produces `libdovi.a` + a `dovi.pc` pkg-config file. libplacebo's `meson` finds it via `PKG_CONFIG_PATH=$prefix_dir/lib/pkgconfig`.
- `ffmpeg --enable-libdovi` requires the `dovi.pc` to advertise `Libs: -ldovi`. cargo-c does this correctly out of the box.
- The cross-compile target naming follows the Rust convention (`aarch64-linux-android`, `armv7-linux-androideabi`, `x86_64-linux-android`, `i686-linux-android`), not the NDK triple — `libdovi.sh` maps between them.
