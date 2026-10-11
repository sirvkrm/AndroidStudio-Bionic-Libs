#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

source "$REPO_ROOT/env.sh"

SRC_DIR="$SCRIPT_DIR/src"
if [ ! -d "$SRC_DIR/native" ]; then
    echo "[jna] Cloning upstream java-native-access/jna..."
    git clone --depth 1 https://github.com/java-native-access/jna.git "$SRC_DIR"
fi

NATIVE_DIR="$SRC_DIR/native"
LIBFFI_DIR="$NATIVE_DIR/libffi"
BUILD_DIR="$SCRIPT_DIR/build"
mkdir -p "$BUILD_DIR"

echo "[jna] Preparing libffi..."
LIBFFI_A="$LIBFFI_DIR/aarch64-unknown-linux-android/.libs/libffi.a"
if [ ! -f "$LIBFFI_A" ]; then
    cd "$LIBFFI_DIR"
    if [ ! -f "configure" ]; then
        ./autogen.sh
    fi
    ./configure --host=aarch64-linux-android \
        CC="$CC" \
        CFLAGS="-O2 -fPIC -Wno-error=implicit-function-declaration" \
        --enable-static --disable-shared --disable-docs
    make MAKEINFO=true -j"$(nproc)" || true
fi

echo "[jna] Generating JNI headers..."
cd "$SRC_DIR"
if [ ! -f "build/headers/com_sun_jna_Native.h" ]; then
    ant javah
fi

echo "[jna] Compiling libjnidispatch.so..."
cd "$NATIVE_DIR"

$CC $CFLAGS -shared -Wl,-soname,libjnidispatch.so \
    -DFFI_STATIC_BUILD -DNO_JAWT -DNO_WEAK_GLOBALS \
    -I. \
    -I"$SRC_DIR/build/headers" \
    -I"$LIBFFI_DIR/include" \
    -I"$LIBFFI_DIR/aarch64-unknown-linux-android/include" \
    -I"$SYSROOT_INC" \
    dispatch.c callback.c \
    "$LIBFFI_A" \
    $LDFLAGS -ldl -lm -lc \
    -o "$BUILD_DIR/libjnidispatch.so"

cp -f "$BUILD_DIR/libjnidispatch.so" "$DIST_DIR/lib/jna/linux-aarch64/libjnidispatch.so"

echo "[jna] SUCCESS -> $DIST_DIR/lib/jna/linux-aarch64/libjnidispatch.so"
