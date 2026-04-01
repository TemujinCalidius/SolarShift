#!/bin/bash
# SolarShift — macOS Uninstaller
#
# Removes the rotation daemon and optionally deletes installed files.
#
# Usage: ./scripts/uninstall-macos.sh

INSTALL_DIR="$HOME/Library/Application Support/SolarShift"
LAUNCH_AGENT="$HOME/Library/LaunchAgents/com.solarshift.wallpaper-rotate.plist"

echo "SolarShift Uninstaller"
echo "======================"
echo ""

# Unload daemon
if [ -f "$LAUNCH_AGENT" ]; then
    launchctl unload "$LAUNCH_AGENT" 2>/dev/null
    rm "$LAUNCH_AGENT"
    echo "Removed launch agent."
else
    echo "No launch agent found."
fi

# Remove installed files
if [ -d "$INSTALL_DIR" ]; then
    echo ""
    echo "Remove installed wallpapers and config?"
    echo "  Directory: $INSTALL_DIR"
    read -rp "Delete? [y/N]: " confirm
    if [[ "$confirm" =~ ^[Yy]$ ]]; then
        rm -rf "$INSTALL_DIR"
        echo "Removed."
    else
        echo "Kept."
    fi
else
    echo "No installed files found."
fi

echo ""
echo "SolarShift has been uninstalled."
echo "Your current wallpaper will remain until you change it manually."
