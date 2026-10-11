#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

source "$REPO_ROOT/env.sh"

SRC_DIR="$SCRIPT_DIR/src"
if [ ! -d "$SRC_DIR/native" ]; then
    echo "[pty4j] Cloning upstream JetBrains/pty4j..."
    git clone --depth 1 https://github.com/JetBrains/pty4j.git "$SRC_DIR"
fi

NATIVE_DIR="$SRC_DIR/native"
BUILD_DIR="$SCRIPT_DIR/build"
mkdir -p "$BUILD_DIR"

echo "[pty4j] Compiling libpty.so..."

cd "$NATIVE_DIR"

$CC $CFLAGS -shared -Wl,-soname,libpty.so \
    -I. \
    exec_pty.c openpty.c pfind.c \
    $LDFLAGS -ldl -lc \
    -o "$BUILD_DIR/libpty.so"

cp -f "$BUILD_DIR/libpty.so" "$DIST_DIR/lib/pty4j/linux/aarch64/libpty.so"

echo "[pty4j] SUCCESS -> $DIST_DIR/lib/pty4j/linux/aarch64/libpty.so"
