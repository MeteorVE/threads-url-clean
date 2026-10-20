# Verify the running cleaner by writing test URLs to the clipboard.
# The user's current clipboard text is saved and restored afterwards
# (an empty clipboard is cleared again; images/files are not restored).
# Usage: powershell -NoProfile -ExecutionPolicy Bypass -File windows\selftest.ps1 [-ShareUrl https://www.threads.com/share/XXXX/]
param([string]$ShareUrl)
Add-Type -AssemblyName System.Windows.Forms

# Non-ASCII test text is built from code points: this file must stay ASCII
# (Windows PowerShell 5.1 misreads BOM-less UTF-8 scripts).
$look  = [string][char]0x770B + [char]0x9019                 # "look at this"
$comma = [string][char]0xFF0C + [char]0x8D85 + [char]0x597D  # full-width comma + text

$cases = @(
    @('https://www.threads.com/@someone/post/ABC123?xmt=AQGexampleTOKEN_123-xyz',
      'https://www.threads.com/@someone/post/ABC123'),
    @('https://www.threads.net/@someone/post/ABC123?xmt=AQGexample&slof=1&foo=2',
      'https://www.threads.net/@someone/post/ABC123?foo=2'),
    @('see https://example.com/?xmt=keep and https://www.threads.com/@a/post/X?xmt=t',
      'see https://example.com/?xmt=keep and https://www.threads.com/@a/post/X'),
    @("${look}https://www.threads.com/@a/post/X?xmt=abc$comma",
      "${look}https://www.threads.com/@a/post/X$comma"),
    @('link (https://www.threads.com/@a/post/X?xmt=abc) end',
      'link (https://www.threads.com/@a/post/X) end'),
    @('https://www.threads.com/@someone/post/ABC123',
      'https://www.threads.com/@someone/post/ABC123')
)

# The clipboard can be briefly locked by other apps; retry instead of failing.
function Set-ClipboardRetry([string]$text) {
    for ($i = 0; $i -lt 10; $i++) {
        try {
            if ($text -eq '') { [System.Windows.Forms.Clipboard]::Clear() }
            else { Set-Clipboard -Value $text -ErrorAction Stop }
            return
        } catch { Start-Sleep -Milliseconds 100 }
    }
    throw 'Could not write to the clipboard.'
}

function Get-ClipboardText {
    $t = Get-Clipboard -Raw
    if ($null -eq $t) { return '' }
    $t.TrimEnd("`r", "`n")
}

$saved = ''
try { $saved = Get-Clipboard -Raw } catch {}
if ($null -eq $saved) { $saved = '' }

$fail = 0
foreach ($c in $cases) {
    Set-ClipboardRetry $c[0]
    Start-Sleep -Milliseconds 700
    $got = Get-ClipboardText
    if ($got -eq $c[1]) { "PASS $($c[0])" } else { "FAIL $($c[0])`n  want $($c[1])`n  got  $got"; $fail++ }
}

if ($ShareUrl) {
    Set-ClipboardRetry $ShareUrl
    Start-Sleep -Seconds 4
    $got = Get-ClipboardText
    if ($got -match '^https://www\.threads\.(com|net)/@[^/]+/post/[^?]+$') { "PASS $ShareUrl -> $got" }
    else { "FAIL $ShareUrl -> $got"; $fail++ }
}

Set-ClipboardRetry $saved
if ($fail) { "RESULT=FAIL ($fail)"; exit 1 } else { 'RESULT=PASS' }
