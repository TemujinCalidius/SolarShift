# SolarShift

A cross-platform dynamic wallpaper that shifts with the sun and the seasons.

Your desktop wallpaper changes throughout the day — dawn, morning, midday, afternoon, golden hour, dusk, twilight, night — and automatically swaps to a new seasonal theme as the year progresses. No apps running in the background, no menubar clutter. Just your wallpaper, always matching the world outside.

## Preview

The default theme is a stylised medieval survival village — 32 hand-crafted images across 4 seasons.

| Dawn | Morning | Midday | Afternoon |
|------|---------|--------|-----------|
| ![dawn](images/autumn/dawn.png) | ![morning](images/autumn/morning.png) | ![midday](images/autumn/midday.png) | ![afternoon](images/autumn/afternoon.png) |

| Golden Hour | Dusk | Twilight | Night |
|-------------|------|----------|-------|
| ![golden_hour](images/autumn/golden_hour.png) | ![dusk](images/autumn/dusk.png) | ![twilight](images/autumn/twilight.png) | ![night](images/autumn/night.png) |

*Autumn shown above. Spring, summer, and winter sets also included.*

## Quick Install

### macOS

```bash
git clone https://github.com/TemujinCalidius/SolarShift.git
cd SolarShift
chmod +x scripts/install-macos.sh
./scripts/install-macos.sh
```

The installer will:
1. Build the `wallpapper` tool (if not already installed)
2. Package images into native macOS dynamic wallpaper `.heic` files
3. Ask your hemisphere and season preference
4. Install a launch agent that runs at login + daily
5. Set your wallpaper immediately

**How it works on macOS:** Each season is a single `.heic` file containing all 8 time-of-day frames with solar position metadata. macOS natively transitions between frames based on the sun's position at your location — no polling needed.

### Windows

```powershell
git clone https://github.com/TemujinCalidius/SolarShift.git
cd SolarShift
powershell -ExecutionPolicy Bypass -File .\scripts\install-windows.ps1
```

The installer will:
1. Check Python 3 is available
2. Copy images to `%APPDATA%\SolarShift\`
3. Ask your hemisphere and season preference
4. Create a Task Scheduler task (runs at logon + every 30 minutes)
5. Set your wallpaper immediately

**How it works on Windows:** The rotation script runs every 30 minutes via Task Scheduler, checks the current time against configurable time slots, and sets the matching image as your wallpaper.

**Requires:** [Python 3](https://www.python.org/downloads/) (no pip packages needed — uses only the standard library)

## Configuration

After installation, edit the config file to customise:

- **macOS:** `~/Library/Application Support/SolarShift/config.json`
- **Windows:** `%APPDATA%\SolarShift\config.json`

```json
{
  "hemisphere": "northern",
  "season_mode": "astronomical",
  "times": {
    "dawn": "05:30",
    "morning": "07:00",
    "midday": "11:30",
    "afternoon": "14:00",
    "golden_hour": "17:00",
    "dusk": "19:00",
    "twilight": "20:00",
    "night": "21:00"
  }
}
```

### Options

| Setting | Values | Default | Description |
|---------|--------|---------|-------------|
| `hemisphere` | `"northern"`, `"southern"` | `"northern"` | Flips the seasons (e.g. July = winter in southern) |
| `season_mode` | `"astronomical"`, `"meteorological"` | `"astronomical"` | When seasons start (see below) |
| `times` | `"HH:MM"` per slot | See above | When each time-of-day image activates (Windows only) |

### Season Modes

| Mode | Spring | Summer | Autumn | Winter |
|------|--------|--------|--------|--------|
| **Astronomical** | Mar 20 | Jun 21 | Sep 22 | Dec 21 |
| **Meteorological** | Mar 1 | Jun 1 | Sep 1 | Dec 1 |

Astronomical uses equinox/solstice dates (most of the world). Meteorological uses the 1st of the month (common in Australia, UK, and for weather reporting).

### Time Slots (Windows only)

On macOS, time-of-day transitions are handled natively using solar position — the `times` setting is ignored. On Windows, the script checks the current time against these values every 30 minutes and sets the matching image.

Adjust the times to match your local sunrise/sunset. For example, in winter you might set dawn later and dusk earlier:

```json
{
  "times": {
    "dawn": "06:30",
    "morning": "07:30",
    "midday": "12:00",
    "afternoon": "14:00",
    "golden_hour": "16:00",
    "dusk": "17:30",
    "twilight": "18:30",
    "night": "19:30"
  }
}
```

## Making Your Own Theme

SolarShift works with any set of images. To create your own theme:

1. Create 8 images per season (or just 1 season if you don't want seasonal rotation):
   ```
   images/
   ├── spring/   dawn.png morning.png midday.png afternoon.png golden_hour.png dusk.png twilight.png night.png
   ├── summer/   ...
   ├── autumn/   ...
   └── winter/   ...
   ```

2. Images should be the same resolution and aspect ratio (the defaults are 5504x3072)

3. Re-run the installer to rebuild `.heic` files (macOS) or just replace the images in the install directory

See [prompts.md](prompts.md) for the AI generation prompts used to create the default theme. The key to consistency is using an image editor with a reference image attached, so the AI edits the lighting rather than generating a new scene from scratch.

### Tips for consistent results
- Generate a single "anchor" image first (e.g. dawn) and use it as a reference for all other times of day
- Use edit/inpainting mode rather than text-to-image, so buildings and landmarks stay fixed
- For new seasons, edit the anchor image to change seasonal elements (foliage, snow, etc.) then use that as the new anchor

## Check Status

```bash
python3 scripts/rotate-wallpaper.py --status
```

```
SolarShift Status
========================================
  Platform:       Darwin
  Hemisphere:     southern
  Season mode:    meteorological
  Current season: autumn
  Active season:  autumn
  Last changed:   2026-04-01T10:37:42
```

## Uninstall

### macOS
```bash
./scripts/uninstall-macos.sh
```

### Windows
```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\uninstall-windows.ps1
```

## How It Works

### macOS
- **Time-of-day:** Native macOS feature. The `.heic` file contains 8 images with solar altitude/azimuth metadata. macOS reads your location and picks the right frame automatically — smooth, zero-CPU-cost transitions.
- **Seasons:** A `launchd` agent runs `rotate-wallpaper.py` at login and daily at 00:05. If the season has changed, it swaps the `.heic` file.

### Windows
- **Time-of-day:** Task Scheduler runs `rotate-wallpaper.py` every 30 minutes. The script checks the current time against configurable time slots and sets the matching PNG as the wallpaper via the Windows API.
- **Seasons:** Same script, same run — it checks both the season and the time slot on every execution.

## Requirements

| | macOS | Windows |
|---|---|---|
| OS | macOS Mojave (10.14)+ | Windows 10/11 |
| Runtime | Python 3 (pre-installed on macOS) | [Python 3](https://www.python.org/downloads/) |
| Build tool | `wallpapper` (auto-installed) | Not needed |
| Disk space | ~600 MB (images + .heic) | ~600 MB (images only) |

## Credits

- Default theme inspired by [The Counter Earth](https://github.com/TemujinCalidius/TheCounterEarth), a stylised survival-adventure game for Roblox
- macOS `.heic` packaging powered by [wallpapper](https://github.com/mczachurski/wallpapper) by Marcin Czachurski
- Built with the help of [Claude Code](https://claude.ai/claude-code)

## License

[MIT](LICENSE) — Samuel Lison
