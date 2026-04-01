# SolarShift — Windows Installer
#
# Copies wallpaper images, configures preferences,
# creates a Task Scheduler task for automatic rotation,
# and sets your first wallpaper.
#
# Usage: Right-click > "Run with PowerShell"
#    or: powershell -ExecutionPolicy Bypass -File .\scripts\install-windows.ps1

$ErrorActionPreference = "Stop"

$RepoDir = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$InstallDir = "$env:APPDATA\SolarShift"
$TaskName = "SolarShift Wallpaper Rotate"

Write-Host ""
Write-Host "  ======================================" -ForegroundColor Cyan
Write-Host "         SolarShift Installer" -ForegroundColor Cyan
Write-Host "    Dynamic wallpapers for Windows" -ForegroundColor Cyan
Write-Host "  ======================================" -ForegroundColor Cyan
Write-Host ""

# --- Step 1: Check Python ---
$python = $null
foreach ($cmd in @("python3", "python", "py")) {
    try {
        $ver = & $cmd --version 2>&1
        if ($ver -match "Python 3") {
            $python = $cmd
            break
        }
    } catch {}
}

if (-not $python) {
    Write-Host "Error: Python 3 not found." -ForegroundColor Red
    Write-Host "Download from https://www.python.org/downloads/"
    exit 1
}
Write-Host "Using: $($python) $(& $python --version 2>&1)"
Write-Host ""

# --- Step 2: Copy files ---
Write-Host "Installing to $InstallDir..."

New-Item -ItemType Directory -Force -Path "$InstallDir\images\spring" | Out-Null
New-Item -ItemType Directory -Force -Path "$InstallDir\images\summer" | Out-Null
New-Item -ItemType Directory -Force -Path "$InstallDir\images\autumn" | Out-Null
New-Item -ItemType Directory -Force -Path "$InstallDir\images\winter" | Out-Null
New-Item -ItemType Directory -Force -Path "$InstallDir\scripts" | Out-Null

Copy-Item "$RepoDir\images\spring\*.png" "$InstallDir\images\spring\" -Force
Copy-Item "$RepoDir\images\summer\*.png" "$InstallDir\images\summer\" -Force
Copy-Item "$RepoDir\images\autumn\*.png" "$InstallDir\images\autumn\" -Force
Copy-Item "$RepoDir\images\winter\*.png" "$InstallDir\images\winter\" -Force
Copy-Item "$RepoDir\scripts\rotate-wallpaper.py" "$InstallDir\scripts\" -Force

$imageCount = (Get-ChildItem "$InstallDir\images" -Recurse -Filter "*.png").Count
Write-Host "Copied $imageCount wallpaper images."
Write-Host ""

# --- Step 3: Configure ---
Write-Host "--- Configuration ---" -ForegroundColor Yellow
Write-Host ""

$hemisphereChoice = Read-Host "Which hemisphere? (1=Northern [default], 2=Southern)"
$hemisphere = if ($hemisphereChoice -eq "2") { "southern" } else { "northern" }

$modeChoice = Read-Host "Season dates? (1=Astronomical [default], 2=Meteorological)"
$seasonMode = if ($modeChoice -eq "2") { "meteorological" } else { "astronomical" }

Write-Host ""
Write-Host "Hemisphere:  $hemisphere"
Write-Host "Season mode: $seasonMode"
Write-Host ""

# Write config
$config = @{
    hemisphere = $hemisphere
    season_mode = $seasonMode
    current_season = $null
    current_image = $null
    times = @{
        dawn = "05:30"
        morning = "07:00"
        midday = "11:30"
        afternoon = "14:00"
        golden_hour = "17:00"
        dusk = "19:00"
        twilight = "20:00"
        night = "21:00"
    }
} | ConvertTo-Json -Depth 3

Set-Content -Path "$InstallDir\config.json" -Value $config
Write-Host "Config saved."
Write-Host ""

# --- Step 4: Create Task Scheduler task ---
Write-Host "Creating scheduled task..."

# Remove existing task if present
Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false -ErrorAction SilentlyContinue

$scriptPath = "$InstallDir\scripts\rotate-wallpaper.py"

# Action: run the rotation script
$action = New-ScheduledTaskAction -Execute $python -Argument "`"$scriptPath`"" -WorkingDirectory $InstallDir

# Triggers: at logon + every 30 minutes repeating
$triggerLogon = New-ScheduledTaskTrigger -AtLogOn
$triggerDaily = New-ScheduledTaskTrigger -Daily -At "00:00"
$triggerDaily.Repetition = (New-ScheduledTaskTrigger -Once -At "00:00" -RepetitionInterval (New-TimeSpan -Minutes 30)).Repetition

$settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable

Register-ScheduledTask -TaskName $TaskName -Action $action -Trigger @($triggerLogon, $triggerDaily) -Settings $settings -Description "SolarShift: rotates desktop wallpaper based on time of day and season" | Out-Null

Write-Host "Scheduled task created: '$TaskName'"
Write-Host "  Runs at logon + every 30 minutes"
Write-Host ""

# --- Step 5: Set initial wallpaper ---
Write-Host "Setting wallpaper..."
& $python "$scriptPath" --force
Write-Host ""

# --- Done ---
Write-Host "  ======================================" -ForegroundColor Green
Write-Host "        Installation Complete!" -ForegroundColor Green
Write-Host "  ======================================" -ForegroundColor Green
Write-Host ""
Write-Host "Your wallpaper will now:"
Write-Host "  - Change every 30 minutes based on time of day"
Write-Host "  - Switch seasons automatically"
Write-Host "  - Persist across reboots"
Write-Host ""
Write-Host "Files installed:"
Write-Host "  Wallpapers: $InstallDir\images\"
Write-Host "  Config:     $InstallDir\config.json"
Write-Host "  Task:       Task Scheduler > '$TaskName'"
Write-Host ""
Write-Host "To change time-of-day schedule, edit: $InstallDir\config.json"
Write-Host "To uninstall, run: .\scripts\uninstall-windows.ps1"
