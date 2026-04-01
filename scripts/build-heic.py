#!/usr/bin/env python3
"""SolarShift — Build macOS dynamic wallpaper .heic files.

Generates wallpapper JSON configs and runs the wallpapper CLI tool to
create .heic files with solar position metadata for each season.

Requires: wallpapper (https://github.com/mczachurski/wallpapper)
  Install: brew install wallpapper
  Or build from source: git clone ... && swift build -c release

Usage:
    python3 scripts/build-heic.py              # Build all 4 seasons
    python3 scripts/build-heic.py spring       # Build one season
"""

import json
import os
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

ROOT_DIR = Path(__file__).resolve().parent.parent
IMAGES_DIR = ROOT_DIR / "images"
HEIC_DIR = ROOT_DIR / "heic"

# Solar metadata for each time-of-day frame.
# altitude: sun angle above horizon (negative = below)
# azimuth: compass direction of sun (90=east, 180=south, 270=west)
FRAMES = [
    {"name": "dawn", "altitude": -5, "azimuth": 90, "isForLight": False, "isForDark": True},
    {"name": "morning", "altitude": 15, "azimuth": 120, "isForLight": True, "isForDark": False},
    {"name": "midday", "altitude": 70, "azimuth": 180, "isForLight": True, "isForDark": False},
    {"name": "afternoon", "altitude": 40, "azimuth": 240, "isForLight": False, "isForDark": False},
    {"name": "golden_hour", "altitude": 10, "azimuth": 270, "isForLight": False, "isForDark": False},
    {"name": "dusk", "altitude": -2, "azimuth": 280, "isForLight": False, "isForDark": True},
    {"name": "twilight", "altitude": -12, "azimuth": 300, "isForLight": False, "isForDark": True},
    {"name": "night", "altitude": -30, "azimuth": 0, "isForLight": False, "isForDark": True},
]

SEASONS = ["spring", "summer", "autumn", "winter"]


def find_wallpapper() -> str:
    """Find the wallpapper binary."""
    # Check common locations
    for path in [
        shutil.which("wallpapper"),
        os.path.expanduser("~/bin/wallpapper"),
        "/usr/local/bin/wallpapper",
    ]:
        if path and os.path.isfile(path):
            return path

    print("Error: wallpapper not found.", file=sys.stderr)
    print("", file=sys.stderr)
    print("Install it with one of:", file=sys.stderr)
    print("  brew install wallpapper", file=sys.stderr)
    print("  or build from source:", file=sys.stderr)
    print("    git clone https://github.com/mczachurski/wallpapper.git /tmp/wallpapper", file=sys.stderr)
    print("    cd /tmp/wallpapper && swift build -c release", file=sys.stderr)
    print("    cp .build/release/wallpapper ~/bin/wallpapper", file=sys.stderr)
    sys.exit(1)


def build_season(season: str, wallpapper_bin: str):
    """Build a single season's .heic file."""
    season_dir = IMAGES_DIR / season
    if not season_dir.exists():
        print(f"  Skipping {season}: {season_dir} not found")
        return False

    # Check all images exist
    missing = [f for f in FRAMES if not (season_dir / f"{f['name']}.png").exists()]
    if missing:
        names = ", ".join(f["name"] for f in missing)
        print(f"  Skipping {season}: missing images: {names}")
        return False

    # Build wallpapper JSON config
    config = []
    for frame in FRAMES:
        entry = {
            "fileName": str(season_dir / f"{frame['name']}.png"),
            "isPrimary": frame["name"] == "midday",
            "isForLight": frame["isForLight"],
            "isForDark": frame["isForDark"],
            "altitude": frame["altitude"],
            "azimuth": frame["azimuth"],
        }
        config.append(entry)

    # Write temp JSON and run wallpapper
    HEIC_DIR.mkdir(exist_ok=True)
    output_path = HEIC_DIR / f"{season}.heic"

    with tempfile.NamedTemporaryFile(mode="w", suffix=".json", delete=False) as f:
        json.dump(config, f, indent=2)
        config_path = f.name

    try:
        result = subprocess.run(
            [wallpapper_bin, "-i", config_path, "-o", str(output_path)],
            capture_output=True,
            text=True,
        )
        if result.returncode != 0:
            print(f"  Error building {season}: {result.stderr}")
            return False
    finally:
        os.unlink(config_path)

    size_mb = output_path.stat().st_size / (1024 * 1024)
    print(f"  {season}.heic — {size_mb:.0f} MB")
    return True


def main():
    if sys.platform != "darwin":
        print("build-heic.py is macOS only. Windows uses images directly.")
        sys.exit(0)

    wallpapper_bin = find_wallpapper()
    print(f"Using wallpapper: {wallpapper_bin}")
    print()

    seasons_to_build = sys.argv[1:] if len(sys.argv) > 1 else SEASONS

    # Validate season names
    for s in seasons_to_build:
        if s not in SEASONS:
            print(f"Unknown season: {s}. Options: {', '.join(SEASONS)}")
            sys.exit(1)

    print("Building dynamic wallpapers...")
    built = 0
    for season in seasons_to_build:
        if build_season(season, wallpapper_bin):
            built += 1

    print()
    if built > 0:
        print(f"Done! Built {built} .heic file(s) in {HEIC_DIR}/")
    else:
        print("No .heic files were built. Check that images/ contains the required PNGs.")


if __name__ == "__main__":
    main()
