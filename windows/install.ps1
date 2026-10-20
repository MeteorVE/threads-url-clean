# Install: copy the script to %LOCALAPPDATA%, add a Startup shortcut, start it.
# Safe to re-run (acts as update). Requires AutoHotkey v2.
# Usage: powershell -NoProfile -ExecutionPolicy Bypass -File windows\install.ps1
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'lib.ps1')

$ahk = Find-AutoHotkeyV2
if (-not $ahk) {
    Write-Error 'AutoHotkey v2 not found. Install it first: winget install --id AutoHotkey.AutoHotkey -e'
    exit 1
}

# Stop any running copy (including ones started from other paths).
Get-CleanerProcesses | ForEach-Object { Stop-Process -Id $_.ProcessId -Force }

New-Item -ItemType Directory -Force -Path $InstallDir | Out-Null
Copy-Item -Force (Join-Path $PSScriptRoot 'threads-url-clean.ahk') $InstalledAhk

$ws = New-Object -ComObject WScript.Shell
$lnk = $ws.CreateShortcut($StartupLnk)
$lnk.TargetPath = $ahk
$lnk.Arguments = '"' + $InstalledAhk + '"'
$lnk.WorkingDirectory = $InstallDir
$lnk.Description = 'Strip xmt tracking token from copied Threads URLs'
$lnk.Save()

Start-Process -FilePath $ahk -ArgumentList ('"' + $InstalledAhk + '"')
Start-Sleep -Milliseconds 800

$procs = @(Get-CleanerProcesses)
if (-not $procs.Count) {
    Write-Error 'Installed, but the script is not running. Try starting it manually.'
    exit 1
}
"OK installed to $InstalledAhk"
"OK autostart shortcut $StartupLnk"
"OK running pid $($procs.ProcessId -join ',')"
