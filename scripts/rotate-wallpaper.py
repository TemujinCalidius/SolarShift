#!/usr/bin/env python3
"""SolarShift — Cross-platform dynamic wallpaper rotation.

Determines the current season based on hemisphere and date mode,
then sets the appropriate wallpaper.

macOS: Swaps between seasonal .heic dynamic wallpaper files (time-of-day is
       handled natively by macOS using solar position metadata in the .heic).
Windows: Picks the correct time-of-day image and sets it directly
         (run every 30 min via Task Scheduler).

Usage:
    python3 rotate-wallpaper.py              # Normal rotation
    python3 rotate-wallpaper.py --force      # Force wallpaper change even if season hasn't changed
    python3 rotate-wallpaper.py --status     # Show current config and season
"""

import json
import os
import platform
import subprocess
import sys
from datetime import datetime
from pathlib import Path

SYSTEM = platform.system()  # "Darwin" or "Windows"

# Resolve paths — works whether run from scripts/ subfolder or installed flat
SCRIPT_DIR = Path(__file__).resolve().parent
if SCRIPT_DIR.name == "scripts":
    ROOT_DIR = SCRIPT_DIR.parent  # Running from repo: SolarShift/scripts/
else:
    ROOT_DIR = SCRIPT_DIR  # Installed flat: ~/Library/Application Support/SolarShift/
HEIC_DIR = ROOT_DIR / "heic"
IMAGES_DIR = ROOT_DIR / "images"
CONFIG_FILE = ROOT_DIR / "config.json"

# Default configuration
DEFAULT_CONFIG = {
    "hemisphere": "northern",
    "season_mode": "astronomical",
    "current_season": None,
    "current_image": None,
    "times": {
        "dawn": "05:30",
        "morning": "07:00",
        "midday": "11:30",
        "afternoon": "14:00",
        "golden_hour": "17:00",
        "dusk": "19:00",
        "twilight": "20:00",
        "night": "21:00",
    },
}

TIME_SLOTS = ["dawn", "morning", "midday", "afternoon", "golden_hour", "dusk", "twilight", "night"]


def load_config() -> dict:
    cfg = dict(DEFAULT_CONFIG)
    if CONFIG_FILE.exists():
        with open(CONFIG_FILE) as f:
            saved = json.load(f)
        cfg.update(saved)
        # Merge times dict (in case user only overrides some)
        if "times" in saved:
            merged_times = dict(DEFAULT_CONFIG["times"])
            merged_times.update(saved["times"])
            cfg["times"] = merged_times
    return cfg


def save_config(cfg: dict):
    with open(CONFIG_FILE, "w") as f:
        json.dump(cfg, f, indent=2)


def get_season(hemisphere: str, mode: str) -> str:
    """Determine current season from date, hemisphere, and mode."""
    month = datetime.now().month
    day = datetime.now().day

    if mode == "meteorological":
        # Seasons start on the 1st of the month (used in Australia, UK, etc.)
        if month in (3, 4, 5):
            raw = "spring"
        elif month in (6, 7, 8):
            raw = "summer"
        elif month in (9, 10, 11):
            raw = "autumn"
        else:
            raw = "winter"
    else:
        # Astronomical (equinox/solstice dates)
        if (month == 3 and day >= 20) or month in (4, 5) or (month == 6 and day < 21):
            raw = "spring"
        elif (month == 6 and day >= 21) or month in (7, 8) or (month == 9 and day < 22):
            raw = "summer"
        elif (month == 9 and day >= 22) or month in (10, 11) or (month == 12 and day < 21):
            raw = "autumn"
        else:
            raw = "winter"

    if hemisphere == "southern":
        flip = {
            "spring": "autumn",
            "summer": "winter",
            "autumn": "spring",
            "winter": "summer",
        }
        return flip[raw]

    return raw


def get_time_slot(times: dict) -> str:
    """Determine which time-of-day image to show based on current time."""
    now = datetime.now()
    current_minutes = now.hour * 60 + now.minute

    # Convert time strings to minutes and sort
    slots = []
    for name in TIME_SLOTS:
        time_str = times.get(name, DEFAULT_CONFIG["times"][name])
        h, m = map(int, time_str.split(":"))
        slots.append((h * 60 + m, name))

    slots.sort(key=lambda x: x[0])

    # Find the current slot (last one whose start time has passed)
    result = slots[-1][1]  # Default to last slot (night) if before first
    for minutes, name in slots:
        if current_minutes >= minutes:
            result = name
        else:
            break

    return result


# --- Platform-specific wallpaper setters ---


def get_current_wallpaper_macos() -> str:
    """Get the current macOS desktop wallpaper path."""
    try:
        result = subprocess.run(
            ["osascript", "-e", 'tell application "System Events" to tell desktop 1 to get picture'],
            capture_output=True, text=True,
        )
        return result.stdout.strip()
    except Exception:
        return ""


def set_wallpaper_macos(heic_path: str):
    """Set macOS desktop wallpaper to a .heic dynamic wallpaper file."""
    script = f'''
    tell application "System Events"
        tell every desktop
            set picture to POSIX file "{heic_path}"
        end tell
    end tell
    '''
    subprocess.run(["osascript", "-e", script], check=True, capture_output=True)


def set_wallpaper_windows(image_path: str):
    """Set Windows desktop wallpaper to a specific image file."""
    import ctypes

    SPI_SETDESKWALLPAPER = 20
    SPIF_UPDATEINIFILE = 0x01
    SPIF_SENDCHANGE = 0x02

    result = ctypes.windll.user32.SystemParametersInfoW(
        SPI_SETDESKWALLPAPER, 0, str(image_path), SPIF_UPDATEINIFILE | SPIF_SENDCHANGE
    )
    if not result:
        raise RuntimeError(f"Failed to set wallpaper: SystemParametersInfoW returned 0")


# --- Main logic ---


def run_macos(cfg: dict, season: str, force: bool):
    """macOS: swap the .heic file when season changes."""
    heic_path = HEIC_DIR / f"{season}.heic"

    if not heic_path.exists():
        print(f"Error: {heic_path} not found. Run 'python3 scripts/build-heic.py' first.", file=sys.stderr)
        sys.exit(1)

    current = cfg.get("current_season")
    # Also verify macOS is actually pointing at our file — it may have been
    # changed externally, or the install path may have moved.
    actual_wallpaper = get_current_wallpaper_macos()
    path_matches = actual_wallpaper == str(heic_path)

    if current == season and path_matches and not force:
        print(f"Already on {season} wallpaper, no change needed.")
        return

    print(f"Switching wallpaper: {current or 'none'} -> {season}")
    set_wallpaper_macos(str(heic_path))

    cfg["current_season"] = season
    cfg["last_changed"] = datetime.now().isoformat()
    save_config(cfg)
    print(f"Done! {season}.heic is now active.")


def run_windows(cfg: dict, season: str, force: bool):
    """Windows: pick the right time-of-day image and set it."""
    time_slot = get_time_slot(cfg.get("times", DEFAULT_CONFIG["times"]))
    image_path = IMAGES_DIR / season / f"{time_slot}.png"

    if not image_path.exists():
        print(f"Error: {image_path} not found.", file=sys.stderr)
        sys.exit(1)

    image_key = f"{season}/{time_slot}"
    current = cfg.get("current_image")
    if current == image_key and not force:
        return  # Silent — this runs every 30 min

    print(f"Setting wallpaper: {image_key}")
    set_wallpaper_windows(str(image_path))

    cfg["current_season"] = season
    cfg["current_image"] = image_key
    cfg["last_changed"] = datetime.now().isoformat()
    save_config(cfg)


def show_status(cfg: dict, season: str):
    """Print current configuration and status."""
    print("SolarShift Status")
    print("=" * 40)
    print(f"  Platform:       {SYSTEM}")
    print(f"  Hemisphere:     {cfg.get('hemisphere', 'northern')}")
    print(f"  Season mode:    {cfg.get('season_mode', 'astronomical')}")
    print(f"  Current season: {season}")
    print(f"  Active season:  {cfg.get('current_season', 'not set')}")
    if SYSTEM == "Windows":
        time_slot = get_time_slot(cfg.get("times", DEFAULT_CONFIG["times"]))
        print(f"  Current slot:   {time_slot}")
        print(f"  Active image:   {cfg.get('current_image', 'not set')}")
    print(f"  Last changed:   {cfg.get('last_changed', 'never')}")
    print(f"  Config file:    {CONFIG_FILE}")


def main():
    cfg = load_config()
    season = get_season(
        cfg.get("hemisphere", "northern"),
        cfg.get("season_mode", "astronomical"),
    )

    force = "--force" in sys.argv

    if "--status" in sys.argv:
        show_status(cfg, season)
        return

    if SYSTEM == "Darwin":
        run_macos(cfg, season, force)
    elif SYSTEM == "Windows":
        run_windows(cfg, season, force)
    else:
        print(f"Unsupported platform: {SYSTEM}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
