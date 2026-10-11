#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

source "$REPO_ROOT/env.sh"

SRC_DIR="$SCRIPT_DIR/src"
BUILD_DIR="$SCRIPT_DIR/build"
mkdir -p "$BUILD_DIR"

VERSION="$(date '+%Y%m%d.%H%M')"
echo "[fsnotifier] Compiling fsnotifier (version: $VERSION)..."

cd "$SRC_DIR"

# 1. Dynamic executable (standard Bionic linker64)
$CC -O2 -Wall -Wextra -D "VERSION=\"$VERSION\"" -std=c11 \
    main.c inotify.c util.c \
    -o "$BUILD_DIR/fsnotifier"

# 2. Static executable (failsafe with no dynamic dependencies)
$CC -static -O2 -Wall -Wextra -D "VERSION=\"$VERSION\"" -std=c11 \
    main.c inotify.c util.c \
    -o "$BUILD_DIR/fsnotifier-static"

chmod 755 "$BUILD_DIR/fsnotifier" "$BUILD_DIR/fsnotifier-static"

# Copy to dist
cp -f "$BUILD_DIR/fsnotifier" "$DIST_DIR/bin/fsnotifier"
cp -f "$BUILD_DIR/fsnotifier-static" "$DIST_DIR/bin/fsnotifier-static"

echo "[fsnotifier] SUCCESS -> $DIST_DIR/bin/fsnotifier"
