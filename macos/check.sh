#!/bin/bash
# Report the local environment as KEY=VALUE lines (read-only, changes nothing).
# Usage: bash macos/check.sh
. "$(dirname "$0")/lib.sh"

have() { command -v "$1" >/dev/null 2>&1 && echo available || echo missing; }

echo "OS=macOS $(sw_vers -productVersion) $(uname -m)"
echo "OSASCRIPT=$(have osascript)"
echo "CURL=$(have curl)"
if pbpaste >/dev/null 2>&1; then echo "CLIPBOARD=ok"; else echo "CLIPBOARD=fail"; fi
if launchctl print "$DOMAIN" >/dev/null 2>&1; then echo "GUI_SESSION=ok"; else echo "GUI_SESSION=missing"; fi
[ -f "$INSTALLED_JS" ] && echo "INSTALLED=yes" || echo "INSTALLED=no"
[ -f "$PLIST" ] && echo "AUTOSTART=yes" || echo "AUTOSTART=no"
is_running && echo "RUNNING=yes" || echo "RUNNING=no"
if curl -s -o /dev/null -m 5 -I https://www.threads.com/; then echo "NETWORK_THREADS=ok"; else echo "NETWORK_THREADS=fail"; fi
