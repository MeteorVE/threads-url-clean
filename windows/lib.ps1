# Shared helpers for check.ps1 / install.ps1 / uninstall.ps1.
# Keep this file ASCII-only: Windows PowerShell 5.1 reads BOM-less scripts
# with the system code page, which breaks non-ASCII text.

$script:AppName     = 'threads-url-clean'
$script:InstallDir  = Join-Path $env:LOCALAPPDATA $AppName
$script:InstalledAhk = Join-Path $InstallDir 'threads-url-clean.ahk'
$script:StartupLnk  = Join-Path ([Environment]::GetFolderPath('Startup')) 'threads-url-clean.lnk'

function Find-AutoHotkeyV2 {
    $candidates = @()
    foreach ($key in 'HKLM:\SOFTWARE\AutoHotkey', 'HKCU:\SOFTWARE\AutoHotkey') {
        try {
            $dir = (Get-ItemProperty -Path $key -ErrorAction Stop).InstallDir
            if ($dir) { $candidates += (Join-Path $dir 'v2') }
        } catch {}
    }
    $candidates += @(
        (Join-Path $env:ProgramFiles 'AutoHotkey\v2'),
        (Join-Path $env:LOCALAPPDATA 'Programs\AutoHotkey\v2')
    )
    foreach ($dir in $candidates) {
        foreach ($exe in 'AutoHotkey64.exe', 'AutoHotkey32.exe', 'AutoHotkey.exe') {
            $p = Join-Path $dir $exe
            if (Test-Path $p) { return $p }
        }
    }
    return $null
}

# Every running AutoHotkey script owns a hidden window of class "AutoHotkey"
# titled "<script path> - AutoHotkey vX". Enumerating windows is used instead of
# Win32_Process (WMI), which can take 15s+ per query on some machines.
if (-not ('TUC.Win' -as [type])) {
    Add-Type -Namespace TUC -Name Win -MemberDefinition @'
public delegate bool EnumProc(IntPtr h, IntPtr l);
[DllImport("user32.dll")] public static extern bool EnumWindows(EnumProc f, IntPtr l);
[DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern int GetWindowText(IntPtr h, System.Text.StringBuilder s, int n);
[DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern int GetClassName(IntPtr h, System.Text.StringBuilder s, int n);
[DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr h, out uint p);
'@
}

function Get-CleanerProcesses {
    $found = New-Object System.Collections.ArrayList
    $cb = [TUC.Win+EnumProc] {
        param($h, $l)
        $cls = New-Object System.Text.StringBuilder 64
        [void][TUC.Win]::GetClassName($h, $cls, 64)
        if ($cls.ToString() -eq 'AutoHotkey') {
            $title = New-Object System.Text.StringBuilder 1024
            [void][TUC.Win]::GetWindowText($h, $title, 1024)
            if ($title.ToString() -like '*threads-url-clean.ahk - AutoHotkey*') {
                $procId = [uint32]0
                [void][TUC.Win]::GetWindowThreadProcessId($h, [ref]$procId)
                [void]$found.Add([pscustomobject]@{ ProcessId = $procId; Path = $title.ToString() })
            }
        }
        $true
    }
    [void][TUC.Win]::EnumWindows($cb, [IntPtr]::Zero)
    $found
}
