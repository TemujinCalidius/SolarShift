#!/bin/bash
# SolarShift — macOS Installer
#
# Builds .heic dynamic wallpapers, installs the rotation daemon,
# and sets your first wallpaper.
#
# Usage: ./scripts/install-macos.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"
INSTALL_DIR="$HOME/Library/Application Support/SolarShift"
LAUNCH_AGENT="$HOME/Library/LaunchAgents/com.solarshift.wallpaper-rotate.plist"

echo "╔══════════════════════════════════════╗"
echo "║         SolarShift Installer         ║"
echo "║   Dynamic wallpapers for macOS       ║"
echo "╚══════════════════════════════════════╝"
echo ""

# --- Step 1: Check for wallpapper ---
WALLPAPPER=""
if command -v wallpapper &>/dev/null; then
    WALLPAPPER="$(command -v wallpapper)"
elif [ -f "$HOME/bin/wallpapper" ]; then
    WALLPAPPER="$HOME/bin/wallpapper"
fi

if [ -z "$WALLPAPPER" ]; then
    echo "wallpapper not found. Building from source..."
    echo ""

    if ! command -v swift &>/dev/null; then
        echo "Error: Swift compiler not found. Install Xcode Command Line Tools:"
        echo "  xcode-select --install"
        exit 1
    fi

    TMPDIR_WP="/tmp/wallpapper-build"
    rm -rf "$TMPDIR_WP"
    git clone https://github.com/mczachurski/wallpapper.git "$TMPDIR_WP" 2>&1 | tail -1
    cd "$TMPDIR_WP"
    swift build -c release 2>&1 | tail -3
    mkdir -p "$HOME/bin"
    cp .build/release/wallpapper "$HOME/bin/wallpapper"
    WALLPAPPER="$HOME/bin/wallpapper"
    cd "$REPO_DIR"
    rm -rf "$TMPDIR_WP"
    echo "Installed wallpapper to ~/bin/wallpapper"
    echo ""
fi

echo "Using wallpapper: $WALLPAPPER"
echo ""

# --- Step 2: Build .heic files ---
echo "Building dynamic wallpapers..."
python3 "$SCRIPT_DIR/build-heic.py"
echo ""

# --- Step 3: Configure ---
echo "--- Configuration ---"
echo ""
echo "Which hemisphere are you in?"
echo "  1) Northern (default)"
echo "  2) Southern"
read -rp "Choice [1]: " hemisphere_choice
case "$hemisphere_choice" in
    2) HEMISPHERE="southern" ;;
    *) HEMISPHERE="northern" ;;
esac

echo ""
echo "When do seasons start?"
echo "  1) Astronomical — equinox/solstice dates: Mar 20, Jun 21, Sep 22, Dec 21 (default)"
echo "  2) Meteorological — 1st of the month: Mar 1, Jun 1, Sep 1, Dec 1"
read -rp "Choice [1]: " mode_choice
case "$mode_choice" in
    2) SEASON_MODE="meteorological" ;;
    *) SEASON_MODE="astronomical" ;;
esac

echo ""
echo "Hemisphere: $HEMISPHERE"
echo "Season mode: $SEASON_MODE"
echo ""

# --- Step 4: Install files ---
echo "Installing to $INSTALL_DIR..."
mkdir -p "$INSTALL_DIR/heic"
cp "$REPO_DIR/heic/"*.heic "$INSTALL_DIR/heic/"
cp "$SCRIPT_DIR/rotate-wallpaper.py" "$INSTALL_DIR/"

# Write config
cat > "$INSTALL_DIR/config.json" << CONF
{
  "hemisphere": "$HEMISPHERE",
  "season_mode": "$SEASON_MODE",
  "current_season": null
}
CONF

echo "Done."
echo ""

# --- Step 5: Install launchd daemon ---
echo "Installing launch agent..."

cat > "$LAUNCH_AGENT" << PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.solarshift.wallpaper-rotate</string>
    <key>ProgramArguments</key>
    <array>
        <string>/usr/bin/python3</string>
        <string>${INSTALL_DIR}/rotate-wallpaper.py</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>StartCalendarInterval</key>
    <dict>
        <key>Hour</key>
        <integer>0</integer>
        <key>Minute</key>
        <integer>5</integer>
    </dict>
    <key>StandardOutPath</key>
    <string>${INSTALL_DIR}/rotate.log</string>
    <key>StandardErrorPath</key>
    <string>${INSTALL_DIR}/rotate.log</string>
</dict>
</plist>
PLIST

# Unload old agent if it exists
launchctl unload "$LAUNCH_AGENT" 2>/dev/null || true
launchctl load "$LAUNCH_AGENT"

echo "Launch agent installed and loaded."
echo ""

# --- Step 6: Set initial wallpaper ---
echo "Setting wallpaper for the current season..."
python3 "$INSTALL_DIR/rotate-wallpaper.py" --force
echo ""

# --- Done ---
echo "╔══════════════════════════════════════╗"
echo "║        Installation Complete!        ║"
echo "╚══════════════════════════════════════╝"
echo ""
echo "Your wallpaper will now:"
echo "  • Change throughout the day based on sun position"
echo "  • Switch seasons automatically at the start of each new season"
echo "  • Persist across reboots"
echo ""
echo "Files installed:"
echo "  Wallpapers: $INSTALL_DIR/heic/"
echo "  Config:     $INSTALL_DIR/config.json"
echo "  Daemon:     $LAUNCH_AGENT"
echo ""
echo "To uninstall, run: ./scripts/uninstall-macos.sh"
