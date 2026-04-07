# Changelog

## [1.0.1] - 2026-04-07

### Fixed
- macOS wallpaper not updating after install path changes — the script now verifies the actual macOS wallpaper path matches the expected file, not just the season name. Previously, if HEIC files were moved (e.g. during migration or reinstall), the script would skip the update thinking the correct season was already set.

## [1.0.0] - 2026-04-01

### Added
- Initial release
- 32 hand-crafted wallpaper images (8 times of day x 4 seasons)
- macOS support: native `.heic` dynamic wallpapers with solar metadata + launchd daemon
- Windows support: Task Scheduler + Python script setting wallpaper every 30 min
- Configurable hemisphere (northern/southern)
- Configurable season mode (astronomical equinox dates / meteorological 1st-of-month)
- Configurable time-of-day slots (Windows)
- Interactive installers and uninstallers for both platforms
- Default theme: stylised medieval survival village
