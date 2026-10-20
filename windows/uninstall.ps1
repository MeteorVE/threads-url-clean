# Uninstall: stop the script, remove the Startup shortcut and installed files.
# Does not uninstall AutoHotkey itself.
# Usage: powershell -NoProfile -ExecutionPolicy Bypass -File windows\uninstall.ps1
. (Join-Path $PSScriptRoot 'lib.ps1')

Get-CleanerProcesses | ForEach-Object { Stop-Process -Id $_.ProcessId -Force }
if (Test-Path $StartupLnk) { Remove-Item -Force $StartupLnk }
if (Test-Path $InstallDir) { Remove-Item -Recurse -Force $InstallDir }
'OK uninstalled'
