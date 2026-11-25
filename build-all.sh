#!/usr/bin/env bash
# ==============================================================================
# AndroidStudio-bionic-libs: Master Build Script
# Compiles all native libraries & Bionic FS agent for linux_android / aarch64.
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

source "$SCRIPT_DIR/env.sh"

echo "=================================================================="
echo " Starting AndroidStudio-bionic-libs Build All"
echo " Target Arch : $TARGET_ARCH"
echo " Target API  : $TARGET_API"
echo " Dist Output : $DIST_DIR"
echo "=================================================================="

echo ""
echo ">>> [1/7] Building fsnotifier..."
"$SCRIPT_DIR/libs/fsnotifier/build.sh"

echo ""
echo ">>> [2/7] Building pty4j (libpty.so)..."
"$SCRIPT_DIR/libs/pty4j/build.sh"

echo ""
echo ">>> [3/7] Building libutil (libutil.so)..."
"$SCRIPT_DIR/libs/libutil/build.sh"

echo ""
echo ">>> [4/7] Building jna (libjnidispatch.so)..."
"$SCRIPT_DIR/libs/jna/build.sh"

echo ""
echo ">>> [5/7] Building sqlite-jdbc (libsqlitejdbc.so)..."
"$SCRIPT_DIR/libs/sqlite-jdbc/build.sh"

echo ""
echo ">>> [6/7] Building skiko (libskiko-linux-arm64.so)..."
"$SCRIPT_DIR/libs/skiko/build.sh"

echo ""
echo ">>> [7/7] Building studio-bionic-fs.jar..."
"$SCRIPT_DIR/libs/bionic-fs/build.sh"

echo ""
echo ">>> Packaging dist archive..."
cd "$DIST_DIR"
tar -czf "$DIST_DIR/android-studio-bionic-libs-2026.2.1-aarch64.tar.gz" bin lib

echo ""
echo "=================================================================="
echo " BUILD ALL COMPLETED SUCCESSFULLY!"
echo "=================================================================="
echo "Generated artifacts in $DIST_DIR:"
find "$DIST_DIR" -type f ! -name "*.tar.gz" -exec ls -lh {} +
echo ""
echo "Release archive:"
ls -lh "$DIST_DIR/android-studio-bionic-libs-2026.2.1-aarch64.tar.gz"
echo "=================================================================="
