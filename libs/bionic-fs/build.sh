#!/usr/bin/env bash
set -euo pipefail

# Build studio-bionic-fs.jar (JDK 25 premain ClassFile bytecode agent allowing
# unrooted Android Studio file choosers to browse through unreadable /, /data,
# /data/data, and /storage/emulated intermediate directories down to $HOME).

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
DIST_DIR="${DIST_DIR:-$REPO_ROOT/dist}"
BUILD_DIR="$SCRIPT_DIR/build"

JAVAC_BIN="${JAVAC_BIN:-}"
JAR_BIN="${JAR_BIN:-}"

for cand in "${JAVA_HOME:-}/bin" "/usr/lib/jvm/java-25-openjdk-amd64/bin" "${PREFIX:-/data/data/com.termux/files/usr}/lib/jvm/java-25-openjdk/bin" "$(dirname "$(command -v javac 2>/dev/null || true)")"; do
    if [ -n "$cand" ] && [ -x "$cand/javac" ] && [ -x "$cand/jar" ]; then
        JAVAC_BIN="$cand/javac"
        JAR_BIN="$cand/jar"
        break
    fi
done

if [ -z "$JAVAC_BIN" ] || [ -z "$JAR_BIN" ]; then
    echo "ERROR: Could not locate javac/jar (JDK 25 required for java.lang.classfile API)." >&2
    exit 1
fi

JVER="$("$JAVAC_BIN" -version 2>&1 | sed -n 's/.* \([0-9][0-9]*\).*/\1/p' | head -n1)"
if [ "${JVER:-0}" -lt 24 ]; then
    echo "ERROR: javac version '$JVER' found at $JAVAC_BIN, but JDK 24/25 is required (found: $("$JAVAC_BIN" -version 2>&1))." >&2
    exit 1
fi

echo "[bionic-fs] Compiling with $JAVAC_BIN (Java $JVER)..."
rm -rf "$BUILD_DIR/classes"
mkdir -p "$BUILD_DIR/classes" "$DIST_DIR/lib"

"$JAVAC_BIN" --release 25 \
    -d "$BUILD_DIR/classes" \
    "$SCRIPT_DIR/src/bionicfs/BionicFsHelper.java" \
    "$SCRIPT_DIR/src/bionicfs/BionicFsAgent.java"

OUT_JAR="$DIST_DIR/lib/studio-bionic-fs.jar"
"$JAR_BIN" cfm "$OUT_JAR" "$SCRIPT_DIR/MANIFEST.MF" -C "$BUILD_DIR/classes" .

echo "[bionic-fs] SUCCESS -> $OUT_JAR ($(stat -c%s "$OUT_JAR" 2>/dev/null || wc -c < "$OUT_JAR") bytes)"
