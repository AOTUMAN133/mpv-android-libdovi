#!/bin/bash -e

## Dependency versions
# Make sure to keep v_ndk and v_ndk_n in sync, both are listed on the NDK download page

v_sdk=11076708_latest
v_ndk=r29
v_ndk_n=29.0.14206865
v_sdk_platform=35
v_sdk_build_tools=35.0.0

v_lua=5.2.4
v_unibreak=7.0
v_harfbuzz=14.2.0
v_fribidi=1.0.16
v_freetype=2.14.3
v_mbedtls=3.6.5
v_libxml2=2.15.3
v_fontconfig=2.17.1
# Dolby Vision RPU decoder (Rust crate). Bumped together with libplacebo —
# the relevant API is pl_hdr_metadata_from_dovi_rpu / pl_shader_dovi_reshape
# which has been stable since libplacebo 6.x and libdovi 3.x.
v_libdovi=3.3.2


## Dependency tree

dep_mbedtls=()
dep_dav1d=()
dep_libxml2=()
dep_libdovi=()
dep_ffmpeg=(mbedtls dav1d libxml2 libdovi)
dep_freetype2=()
dep_fontconfig=(libxml2 freetype2)
dep_fribidi=()
dep_harfbuzz=()
dep_unibreak=()
dep_libass=(freetype2 fontconfig fribidi harfbuzz unibreak)
dep_lua=()
dep_libplacebo=(libdovi)
dep_mpv=(ffmpeg libass lua libplacebo)
dep_mpv_android=(mpv)


## for CI workflow

# pinned ffmpeg revision: 2026-07-20 commit with AV_HWACCEL_FLAG_ALLOW_PROFILE_MISMATCH (mediacodec)
# 锁在补丁提交点而非 master：master 的 hevc_mp4toannexb 对无参数集 Emby 流更严格，导致 P5 软解 RPU 重塑失效
v_ci_ffmpeg=c23123630e6a7e645c199599b8ade3fe7e9ab3db

# filename used to uniquely identify a build prefix
ci_tarball="prefix-ndk-${v_ndk}-lua-${v_lua}-unibreak-${v_unibreak}-harfbuzz-${v_harfbuzz}-fribidi-${v_fribidi}-freetype-${v_freetype}-libxml2-${v_libxml2}-fontconfig-${v_fontconfig}-mbedtls-${v_mbedtls}-ffmpeg-${v_ci_ffmpeg}-arm64-dovipatch9.tgz"
