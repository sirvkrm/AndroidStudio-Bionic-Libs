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

# Read JNA_JNI_VERSION and CHECKSUM from src/common.xml so runtime version check matches Java class
read -r JNA_JNI_VERSION JNA_CHECKSUM <<< "$(python3 -c '
import re, xml.etree.ElementTree as ET
root = ET.parse("'"$SRC_DIR"'/common.xml").getroot()
props = {p.attrib["name"]: p.attrib["value"] for p in root.findall(".//property") if "name" in p.attrib and "value" in p.attrib}
def resolve(val):
    for _ in range(5):
        n = re.sub(r"\$\{([^}]+)\}", lambda m: props.get(m.group(1), m.group(0)), val)
        if n == val: break
        val = n
    return val
ver = resolve(props.get("jni.version", "7.0.4"))
cs = resolve(props.get("jni.md5", "5fb98531302accd485c534c452dd952a"))
if "${" in ver: ver = "7.0.4"
if "${" in cs: cs = "5fb98531302accd485c534c452dd952a"
print(ver, cs)
')"
echo ">> JNA_JNI_VERSION=${JNA_JNI_VERSION}, CHECKSUM=${JNA_CHECKSUM}"

$CC $CFLAGS -shared -Wl,-soname,libjnidispatch.so \
    -DFFI_STATIC_BUILD -DNO_JAWT -DNO_WEAK_GLOBALS \
    -DJNA_JNI_VERSION="\"${JNA_JNI_VERSION}\"" \
    -DCHECKSUM="\"${JNA_CHECKSUM}\"" \
    -I. \
    -I"$SRC_DIR/build/headers" \
    -I"$LIBFFI_DIR/include" \
    -I"$LIBFFI_DIR/aarch64-unknown-linux-android/include" \
    -I"$SYSROOT_INC" \
    dispatch.c callback.c \
    "$LIBFFI_A" \
    $LDFLAGS -ldl -lm -lc \
    -o "$BUILD_DIR/libjnidispatch.so"

mkdir -p "$DIST_DIR/lib/jna/linux-aarch64" "$DIST_DIR/lib/jna/aarch64"
cp -f "$BUILD_DIR/libjnidispatch.so" "$DIST_DIR/lib/jna/linux-aarch64/libjnidispatch.so"
cp -f "$BUILD_DIR/libjnidispatch.so" "$DIST_DIR/lib/jna/aarch64/libjnidispatch.so"

echo "[jna] SUCCESS -> $DIST_DIR/lib/jna/{aarch64,linux-aarch64}/libjnidispatch.so"
