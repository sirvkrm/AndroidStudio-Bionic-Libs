#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

source "$REPO_ROOT/env.sh"

SRC_DIR="$SCRIPT_DIR/src"
if [ ! -d "$SRC_DIR/src/main/java" ]; then
    echo "[sqlite-jdbc] Cloning upstream xerial/sqlite-jdbc..."
    git clone --depth 1 https://github.com/xerial/sqlite-jdbc.git "$SRC_DIR"
fi

BUILD_DIR="$SCRIPT_DIR/build"
TARGET_DIR="$SCRIPT_DIR/target"
mkdir -p "$BUILD_DIR" "$TARGET_DIR"
cd "$SCRIPT_DIR"

echo "[sqlite-jdbc] Ensuring JNI headers..."
if [ ! -f "$TARGET_DIR/common-lib/NativeDB.h" ]; then
    mkdir -p "$TARGET_DIR/classpath" "$TARGET_DIR/common-lib"
    if [ ! -f "$TARGET_DIR/classpath/slf4j-api.jar" ]; then
        curl -fsSL https://repo1.maven.org/maven2/org/slf4j/slf4j-api/2.0.13/slf4j-api-2.0.13.jar -o "$TARGET_DIR/classpath/slf4j-api.jar"
    fi
    javac -cp "$TARGET_DIR/classpath/slf4j-api.jar" \
        -d "$TARGET_DIR/common-lib" \
        -sourcepath "$SRC_DIR/src/main/java" \
        -h "$TARGET_DIR/common-lib" \
        "$SRC_DIR/src/main/java/org/sqlite/core/NativeDB.java"
    mv "$TARGET_DIR/common-lib/org_sqlite_core_NativeDB.h" "$TARGET_DIR/common-lib/NativeDB.h"
fi

echo "[sqlite-jdbc] Ensuring SQLite amalgamation..."
AMAL_DIR="$TARGET_DIR/sqlite-amalgamation-3530400"
if [ ! -f "$AMAL_DIR/sqlite3.c" ]; then
    curl -fsSL https://www.sqlite.org/2026/sqlite-amalgamation-3530400.zip -o "$TARGET_DIR/sqlite-amal.zip"
    unzip -q "$TARGET_DIR/sqlite-amal.zip" -d "$TARGET_DIR/"
fi

echo "[sqlite-jdbc] Compiling libsqlitejdbc.so..."
$CC $CFLAGS -shared -Wl,-soname,libsqlitejdbc.so \
    -DSQLITE_ENABLE_LOAD_EXTENSION=1 \
    -DSQLITE_ENABLE_COLUMN_METADATA \
    -DSQLITE_HAVE_ISNAN \
    -I"$TARGET_DIR/common-lib" \
    -I"$AMAL_DIR" \
    -I"$SYSROOT_INC" \
    "$SRC_DIR/src/main/java/org/sqlite/core/NativeDB.c" \
    "$AMAL_DIR/sqlite3.c" \
    $LDFLAGS -ldl -lm -lc \
    -o "$BUILD_DIR/libsqlitejdbc.so"

cp -f "$BUILD_DIR/libsqlitejdbc.so" "$DIST_DIR/lib/sqlite/linux-aarch64/libsqlitejdbc.so"

echo "[sqlite-jdbc] SUCCESS -> $DIST_DIR/lib/sqlite/linux-aarch64/libsqlitejdbc.so"
