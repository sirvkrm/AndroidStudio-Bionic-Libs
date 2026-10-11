#!/usr/bin/env bash
# ==============================================================================
# AndroidStudio-bionic-libs: Master Build Script
# Compiles all native libraries for linux_android / linux_arm64_bionic.
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

# 1. fsnotifier
echo ""
echo ">>> [1/4] Building fsnotifier..."
"$SCRIPT_DIR/libs/fsnotifier/build.sh"

# 2. pty4j
echo ""
echo ">>> [2/6] Building pty4j (libpty.so)..."
"$SCRIPT_DIR/libs/pty4j/build.sh"

# 3. libutil (login_tty compatibility for pty4j)
echo ""
echo ">>> [3/6] Building libutil (libutil.so)..."
"$SCRIPT_DIR/libs/libutil/build.sh"

# 4. jna
echo ""
echo ">>> [4/6] Building jna (libjnidispatch.so)..."
"$SCRIPT_DIR/libs/jna/build.sh"

# 5. sqlite-jdbc
echo ""
echo ">>> [5/6] Building sqlite-jdbc (libsqlitejdbc.so)..."
"$SCRIPT_DIR/libs/sqlite-jdbc/build.sh"

# 6. skiko
echo ""
echo ">>> [6/6] Building skiko (libskiko-linux-arm64.so)..."
"$SCRIPT_DIR/libs/skiko/build.sh"

# 6. Pack archive
echo ""
echo ">>> Packaging dist archive..."
cd "$DIST_DIR"
tar -czf "$DIST_DIR/android-studio-bionic-libs-aarch64.tar.gz" bin lib

echo ""
echo "=================================================================="
echo " BUILD ALL COMPLETED SUCCESSFULLY!"
echo "=================================================================="
echo "Generated artifacts in $DIST_DIR:"
find "$DIST_DIR" -type f ! -name "*.tar.gz" -exec ls -lh {} +
echo ""
echo "Release archive:"
ls -lh "$DIST_DIR/android-studio-bionic-libs-aarch64.tar.gz"
echo "=================================================================="
