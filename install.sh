#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")"

LABEL="net.morele.worktimer"
APP_NAME="WorkTimer"
DEST_DIR="$HOME/Applications"
APP_DEST="$DEST_DIR/$APP_NAME.app"
PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"

./build-app.sh

mkdir -p "$DEST_DIR"
rm -rf "$APP_DEST"
cp -R "$APP_NAME.app" "$APP_DEST"

mkdir -p "$HOME/Library/LaunchAgents"
cat > "$PLIST" <<PLISTEOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>$LABEL</string>
    <key>ProgramArguments</key>
    <array>
        <string>$APP_DEST/Contents/MacOS/$APP_NAME</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
    <key>ProcessType</key>
    <string>Interactive</string>
</dict>
</plist>
PLISTEOF

launchctl bootout "gui/$(id -u)/$LABEL" 2>/dev/null || true
launchctl bootstrap "gui/$(id -u)" "$PLIST"
launchctl kickstart -k "gui/$(id -u)/$LABEL"

echo "Installed and running: $APP_DEST"
echo "LaunchAgent: $PLIST"
