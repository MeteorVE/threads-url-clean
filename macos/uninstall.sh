#!/bin/bash
# Uninstall: stop the LaunchAgent and remove installed files and log.
# Usage: bash macos/uninstall.sh
. "$(dirname "$0")/lib.sh"

launchctl bootout "$DOMAIN/$LABEL" 2>/dev/null || true
rm -f "$PLIST" "$LOG"
rm -rf "$INSTALL_DIR"
echo "OK uninstalled"
