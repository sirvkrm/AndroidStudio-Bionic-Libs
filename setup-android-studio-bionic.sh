#!/usr/bin/env bash
# ==============================================================================
# AndroidStudio-For-Android: Compatibility Wrapper -> install.sh / setup.py
# Keeps direct curl links to setup-android-studio-bionic.sh working cleanly.
# ==============================================================================
set -eo pipefail

REPO_RAW_BASE="https://raw.githubusercontent.com/sirvkrm/AndroidStudio-For-Android/main"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" 2>/dev/null && pwd || echo "$HOME")"

if [ -f "$SCRIPT_DIR/install.sh" ] && [ -f "$SCRIPT_DIR/setup.py" ]; then
    exec "$SCRIPT_DIR/install.sh" "$@"
fi

TMP_INSTALL="$(mktemp --suffix=.sh)"
trap 'rm -f "$TMP_INSTALL"' EXIT
echo "[setup] Fetching AndroidStudio-For-Android v2 interactive installer..."
curl -fsSL "$REPO_RAW_BASE/install.sh" -o "$TMP_INSTALL"
chmod +x "$TMP_INSTALL"
exec bash "$TMP_INSTALL" "$@"
