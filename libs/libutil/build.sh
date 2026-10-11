#!/usr/bin/env bash
# ==============================================================================
# Build script for Bionic libutil.so (provides login_tty for pty4j)
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/../.." && pwd)"

source "${ROOT_DIR}/env.sh"

BUILD_DIR="${SCRIPT_DIR}/build"
DIST_DIR="${ROOT_DIR}/dist"

mkdir -p "${BUILD_DIR}"
mkdir -p "${DIST_DIR}/lib/pty4j/linux/aarch64"

echo "[libutil] Compiling Bionic libutil.so (login_tty compatibility)..."
${CC} ${CFLAGS} -shared -fPIC -Wl,-soname,libutil.so \
    "${SCRIPT_DIR}/login_tty.c" \
    ${LDFLAGS} -lc \
    -o "${BUILD_DIR}/libutil.so"

${STRIP} --strip-unneeded "${BUILD_DIR}/libutil.so"
cp -f "${BUILD_DIR}/libutil.so" "${DIST_DIR}/lib/pty4j/linux/aarch64/libutil.so"

echo "[libutil] Built successfully: ${DIST_DIR}/lib/pty4j/linux/aarch64/libutil.so"
