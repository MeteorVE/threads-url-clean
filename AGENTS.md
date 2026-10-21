# AGENTS.md — install guide for AI agents

You are helping a user install **threads-url-clean**: a tiny background
program that watches the clipboard and removes the `xmt` (and `slof`)
tracking parameters from copied Threads URLs, and expands
`threads.com/share/<code>/` short links into clean post URLs.

```
https://www.threads.com/@user/post/ABC123?xmt=AQG...   ->  https://www.threads.com/@user/post/ABC123
https://www.threads.com/share/AbCdEf123/               ->  https://www.threads.com/@user/post/ABC123
```

Supported: **Windows 10/11** and **macOS**. Linux is not supported.

All scripts print `KEY=VALUE` / `OK ...` / `PASS|FAIL ...` lines so you can parse
them. Run every command from the repository root.

## Rules

- **Ask the user before installing third-party software** (only AutoHotkey on
  Windows; macOS needs nothing extra). Do not install it silently.
- Tell the user, before running it, that the self-test temporarily overwrites
  their clipboard (it restores the previous text, or empties it if it was empty; images/files on the
  clipboard are not restored).
- Do not modify or stop any other AutoHotkey scripts or LaunchAgents the user has.
- The install scripts copy the program out of this repo, so the clone can be
  deleted afterwards. Re-running the install script updates it.

## Step 1 — detect the OS and check the environment

Windows (PowerShell):

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File windows\check.ps1
```

macOS (Terminal):

```bash
bash macos/check.sh
```

Read the output:

| Key | Meaning / what to do |
|---|---|
| `AUTOHOTKEY_V2=missing` (Windows) | Required. Ask the user, then run `winget install --id AutoHotkey.AutoHotkey -e`. If `WINGET=missing`, send them to https://www.autohotkey.com/ to install **v2** (v1 will not work). Re-run check afterwards. |
| `OSASCRIPT` / `CURL` = `missing` (macOS) | Built into macOS; if missing, the system is unusual — stop and tell the user. |
| `CLIPBOARD=fail` / `GUI_SESSION=missing` (macOS) | You are not in the user's logged-in desktop session (e.g. plain SSH without a GUI login). The user must be logged in at the Mac. |
| `NETWORK_THREADS=fail` | Only short-link expansion needs network. Installation can continue; mention it. |
| `INSTALLED=yes` / `RUNNING=yes` | Already installed. Re-running install updates it; skip install unless the user wants an update. |

## Step 2 — install

Windows:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File windows\install.ps1
```

macOS:

```bash
bash macos/install.sh
```

Success = three `OK` lines. What it does:

| | Windows | macOS |
|---|---|---|
| Program | `%LOCALAPPDATA%\threads-url-clean\threads-url-clean.ahk` (AutoHotkey v2) | `~/Library/Application Support/threads-url-clean/threads-url-clean.js` (JXA, run by `/usr/bin/osascript`) |
| Autostart | Shortcut in the Startup folder (`threads-url-clean.lnk`) | LaunchAgent `~/Library/LaunchAgents/io.github.meteorve.threads-url-clean.plist` (RunAtLoad + KeepAlive) |
| Log | `%LOCALAPPDATA%\threads-url-clean\threads-url-clean.log` (start / exit reason / errors; last lines shown by `check.ps1` as `LOG=`) | `~/Library/Logs/threads-url-clean.log` (stderr) |

## Step 3 — verify

Windows:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File windows\selftest.ps1
```

macOS:

```bash
bash macos/selftest.sh
```

Success = `RESULT=PASS`. To also test short-link expansion, pass a real share
link the user gives you (`-ShareUrl <url>` on Windows, first argument on macOS).
Do not invent one.

Then tell the user: copy any Threads link (the app's "Copy link" button) and
paste it — the `?xmt=...` part should be gone. On Windows a small tooltip
"Threads: xmt removed" appears near the cursor.

## Uninstall

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File windows\uninstall.ps1
```

```bash
bash macos/uninstall.sh
```

This removes the program, the autostart entry and the log. It does not uninstall
AutoHotkey.

## Troubleshooting

- **Windows, script blocked by execution policy**: always invoke with
  `-ExecutionPolicy Bypass -File` as above; do not change the machine policy.
- **Windows, nothing happens**: `check.ps1` → `RUNNING=no` means the script
  is not running; re-run `install.ps1`. AutoHotkey v1 cannot run it.
  Read the `LOG=` lines first: no `start` line after the last logon means the
  Startup shortcut never launched it; an `exit reason=...` line says why it
  stopped; `error:` lines are runtime errors (logged instead of shown as dialogs).
- **macOS, `RUNNING=no` after install**: read `~/Library/Logs/threads-url-clean.log`,
  and `launchctl print gui/$(id -u)/io.github.meteorve.threads-url-clean`.
- **Short links not expanded**: needs network; there is a 3-second timeout,
  after which the link is left unchanged.
