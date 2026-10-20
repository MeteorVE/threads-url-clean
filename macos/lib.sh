# Shared paths for check.sh / install.sh / uninstall.sh (sourced, not run).
LABEL="io.github.meteorve.threads-url-clean"
INSTALL_DIR="$HOME/Library/Application Support/threads-url-clean"
INSTALLED_JS="$INSTALL_DIR/threads-url-clean.js"
PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"
LOG="$HOME/Library/Logs/threads-url-clean.log"
DOMAIN="gui/$(id -u)"

is_running() {
  launchctl print "$DOMAIN/$LABEL" 2>/dev/null | grep -q 'state = running'
}
