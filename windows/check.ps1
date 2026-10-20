# Report the local environment as KEY=VALUE lines (read-only, changes nothing).
# Usage: powershell -NoProfile -ExecutionPolicy Bypass -File windows\check.ps1
. (Join-Path $PSScriptRoot 'lib.ps1')

$ahk = Find-AutoHotkeyV2
$procs = @(Get-CleanerProcesses)

$net = 'unknown'
try {
    Invoke-WebRequest -Uri 'https://www.threads.com/' -Method Head -UseBasicParsing -TimeoutSec 5 -MaximumRedirection 0 -ErrorAction Stop | Out-Null
    $net = 'ok'
} catch {
    if ($_.Exception.Response) { $net = 'ok' } else { $net = 'fail' }
}

"OS=Windows $([Environment]::OSVersion.Version)"
"POWERSHELL=$($PSVersionTable.PSVersion)"
"AUTOHOTKEY_V2=$(if ($ahk) { $ahk } else { 'missing' })"
"WINGET=$(if (Get-Command winget -ErrorAction SilentlyContinue) { 'available' } else { 'missing' })"
"INSTALLED=$(if (Test-Path $InstalledAhk) { 'yes' } else { 'no' })"
"AUTOSTART=$(if (Test-Path $StartupLnk) { 'yes' } else { 'no' })"
"RUNNING=$(if ($procs.Count) { 'yes (' + ($procs.ProcessId -join ',') + ')' } else { 'no' })"
"NETWORK_THREADS=$net"
if (-not $ahk) {
    "HINT=AutoHotkey v2 is required. Install with: winget install --id AutoHotkey.AutoHotkey -e"
}
