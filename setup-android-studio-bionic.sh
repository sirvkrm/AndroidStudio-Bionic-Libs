#!/usr/bin/env bash
# ==============================================================================
# androidstudio-bionic-termux: Compatibility Wrapper -> install.sh / setup.py
# Keeps direct curl links to setup-android-studio-bionic.sh working cleanly.
# ==============================================================================
set -eo pipefail

REPO_RAW_BASE="https://raw.githubusercontent.com/sirvkrm/androidstudio-bionic-termux/main"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" 2>/dev/null && pwd || echo "$HOME")"

if [ -f "$SCRIPT_DIR/install.sh" ] && [ -f "$SCRIPT_DIR/setup.py" ]; then
    exec "$SCRIPT_DIR/install.sh" "$@"
fi

TMP_INSTALL="$(mktemp --suffix=.sh)"
trap 'rm -f "$TMP_INSTALL"' EXIT
echo "[setup] Fetching androidstudio-bionic-termux v2 interactive installer..."
curl -fsSL "$REPO_RAW_BASE/install.sh" -o "$TMP_INSTALL"
chmod +x "$TMP_INSTALL"
exec bash "$TMP_INSTALL" "$@"
