# SolarShift — Windows Uninstaller
#
# Removes the scheduled task and optionally deletes installed files.
#
# Usage: powershell -ExecutionPolicy Bypass -File .\scripts\uninstall-windows.ps1

$TaskName = "SolarShift Wallpaper Rotate"
$InstallDir = "$env:APPDATA\SolarShift"

Write-Host ""
Write-Host "SolarShift Uninstaller"
Write-Host "======================"
Write-Host ""

# Remove scheduled task
$task = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
if ($task) {
    Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false
    Write-Host "Removed scheduled task."
} else {
    Write-Host "No scheduled task found."
}

# Remove installed files
if (Test-Path $InstallDir) {
    Write-Host ""
    $confirm = Read-Host "Remove installed wallpapers and config at $InstallDir? (y/N)"
    if ($confirm -match "^[Yy]$") {
        Remove-Item -Recurse -Force $InstallDir
        Write-Host "Removed."
    } else {
        Write-Host "Kept."
    }
} else {
    Write-Host "No installed files found."
}

Write-Host ""
Write-Host "SolarShift has been uninstalled."
Write-Host "Your current wallpaper will remain until you change it manually."
