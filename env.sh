#!/usr/bin/env bash
# ==============================================================================
# Toolchain & Environment Detection for AndroidStudio-bionic-libs
# Supports both:
#   1. Native compilation inside Termux on aarch64
#   2. Cross-compilation on Linux x86_64 using Android NDK
# ==============================================================================

set -e

_ENV_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export REPO_ROOT="$_ENV_DIR"
export DIST_DIR="$REPO_ROOT/dist"
export TARGET_ARCH="aarch64"
export TARGET_API="${TARGET_API:-24}"

mkdir -p "$DIST_DIR/bin"
mkdir -p "$DIST_DIR/lib/pty4j/linux/aarch64"
mkdir -p "$DIST_DIR/lib/jna/linux-aarch64"
mkdir -p "$DIST_DIR/lib/sqlite/linux-aarch64"

# Check if running natively inside Termux
if [ -d "/data/data/com.termux" ] || [ "$(uname -o 2>/dev/null)" = "Android" ]; then
    echo "[env] Detected native Android / Termux environment ($(uname -m))"
    export IS_TERMUX=1
    export CC="${CC:-clang}"
    export CXX="${CXX:-clang++}"
    export AR="${AR:-llvm-ar}"
    export RANLIB="${RANLIB:-llvm-ranlib}"
    export STRIP="${STRIP:-llvm-strip}"
    export PREFIX="${PREFIX:-/data/data/com.termux/files/usr}"
    export CFLAGS="-O2 -fPIC -I$PREFIX/include"
    export LDFLAGS="-L$PREFIX/lib"
    export SYSROOT_INC="$PREFIX/include"
else
    export IS_TERMUX=0
    # Locate Android NDK for cross-compilation
    if [ -z "${ANDROID_NDK_ROOT:-}" ]; then
        if [ -d "/opt/android-ndk/android-ndk-r26d" ]; then
            export ANDROID_NDK_ROOT="/opt/android-ndk/android-ndk-r26d"
        elif [ -d "$HOME/android-ndk" ]; then
            export ANDROID_NDK_ROOT="$HOME/android-ndk"
        elif [ -n "${NDK:-}" ]; then
            export ANDROID_NDK_ROOT="$NDK"
        else
            echo "ERROR: ANDROID_NDK_ROOT not found! Please set ANDROID_NDK_ROOT or install NDK to /opt/android-ndk/android-ndk-r26d"
            exit 1
        fi
    fi

    echo "[env] Detected Linux host, cross-compiling with NDK: $ANDROID_NDK_ROOT"
    NDK_LLVM="$ANDROID_NDK_ROOT/toolchains/llvm/prebuilt/linux-x86_64"
    export CC="$NDK_LLVM/bin/aarch64-linux-android${TARGET_API}-clang"
    export CXX="$NDK_LLVM/bin/aarch64-linux-android${TARGET_API}-clang++"
    export AR="$NDK_LLVM/bin/llvm-ar"
    export RANLIB="$NDK_LLVM/bin/llvm-ranlib"
    export STRIP="$NDK_LLVM/bin/llvm-strip"
    export SYSROOT="$NDK_LLVM/sysroot"
    export SYSROOT_INC="$SYSROOT/usr/include"
    export CFLAGS="-O2 -fPIC"
    export LDFLAGS=""
fi

echo "[env] Compiler : $CC"
echo "[env] Dist dir : $DIST_DIR"
