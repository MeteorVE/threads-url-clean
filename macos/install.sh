#!/bin/bash
# Install: copy the script to ~/Library/Application Support, register a
# LaunchAgent (starts at login, restarts if it dies), start it now.
# Safe to re-run (acts as update). No third-party dependencies.
# Usage: bash macos/install.sh
set -euo pipefail
. "$(dirname "$0")/lib.sh"

mkdir -p "$INSTALL_DIR" "$HOME/Library/LaunchAgents" "$(dirname "$LOG")"
cp "$(dirname "$0")/threads-url-clean.js" "$INSTALLED_JS"

cat > "$PLIST" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key><string>$LABEL</string>
  <key>ProgramArguments</key>
  <array>
    <string>/usr/bin/osascript</string>
    <string>-l</string>
    <string>JavaScript</string>
    <string>$INSTALLED_JS</string>
  </array>
  <key>RunAtLoad</key><true/>
  <key>KeepAlive</key><true/>
  <key>ProcessType</key><string>Background</string>
  <key>StandardErrorPath</key><string>$LOG</string>
</dict>
</plist>
EOF

launchctl bootout "$DOMAIN/$LABEL" 2>/dev/null || true
launchctl bootstrap "$DOMAIN" "$PLIST"
sleep 1

if ! is_running; then
  echo "ERROR: LaunchAgent loaded but not running. See $LOG" >&2
  exit 1
fi
echo "OK installed to $INSTALLED_JS"
echo "OK autostart $PLIST"
echo "OK running ($LABEL)"
