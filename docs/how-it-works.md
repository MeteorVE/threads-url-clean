# 運作原理與設計紀錄

這份文件記錄每個設計決定的理由，以及背後查證的資料。使用方式請看 [README](../README.md)。

**主要平台是 Windows**，macOS 是附帶支援。

## 共通流程

剪貼簿每變動一次，兩個平台都會跑同一套判斷：

1. 不是文字，或文字裡沒有 `threads.` → 直接結束。絕大多數的複製都停在這一步，成本只有一次字串搜尋。
2. 有 `threads.com/share/<code>/` 短連結 → 送出一個不跟隨轉址的請求，從 302 回應的 `Location` 拿到真正的貼文網址（逾時 3 秒，失敗就保持原樣）。
3. 只拿掉 Threads 網址上的 `xmt`、`slof` 參數。其他參數、`#fragment`、非 Threads 的網址都不動。
4. 結果和原本不一樣，才寫回剪貼簿。

### 查詢參數只比對 ASCII 的 key=value

一開始的寫法是 `\?([^\s#]*)`，也就是從 `?` 一路吃到下一個空白或 `#`。
中文通常不加空格，結果網址後面的文字被當成 `xmt` 值的一部分，跟著一起刪掉了：

| 輸入 | 舊寫法的結果 |
|---|---|
| `看這個https://www.threads.com/@a/post/X?xmt=abc，超好笑` | `看這個https://www.threads.com/@a/post/X`（`，超好笑` 不見了） |
| `link (https://www.threads.com/@a/post/X?xmt=abc) end` | `link (https://www.threads.com/@a/post/X end`（`)` 不見了） |

現在查詢字串只比對 `key[=value](&key[=value])*`，key 限 `[\w.-]`、value 限 `[\w~%+-]`，都是 ASCII。
`xmt` 是 base64url 格式，剛好落在這個範圍內。緊接在後面的全形標點、括號、引號都會留下來。
這兩個情境都已加進 `selftest`。

## Windows：等系統通知，不輪詢

AutoHotkey v2 的 `OnClipboardChange` 掛在 Windows 的剪貼簿變動通知上。只有剪貼簿真的變了，callback 才會被呼叫，閒置時完全不耗資源。

### 實測：每次複製會呼叫幾次 callback

在除錯版本裡為每次 callback 加上紀錄，然後複製一次 Threads 連結、一次一般文字：

```
callback #1 type=2 text=                     ← PowerShell Set-Clipboard 會先清空，所以多一次
callback #2 type=1 text=https://www.threads.com/@a/post/X?xmt=abc
  -> WROTE cleaned text                      ← 寫回之後沒有再被呼叫
callback #3 type=2 text=
callback #4 type=1 text=hello, not a threads link
callback #5 type=1 text=hello, not a threads link   ← 同一次複製通知了兩次
```

- 任何程式複製東西都會呼叫 callback，有些程式寫入剪貼簿時會連續觸發兩三次。不是 Threads 的內容在 `InStr(s, "threads.")` 這步就結束了。
- **自己寫回不會再觸發。**AutoHotkey 文件寫明："If the clipboard changes while a callback is already running, that notification event is lost."（[OnClipboardChange](https://www.autohotkey.com/docs/v2/lib/OnClipboardChange.htm)）。寫回發生在 callback 裡，那次通知會被丟掉。就算以後行為改變，第 4 步的「一樣就不寫」也會擋住無限循環。
- `type` 的意思：0 = 剪貼簿是空的，1 = 可以當成文字的內容，2 = 完全不是文字（例如圖片）。

### 找出正在執行的實例：列舉視窗，不用 WMI

`install.ps1` 和 `check.ps1` 需要知道清理程式有沒有在跑。原本用 `Get-CimInstance Win32_Process` 查，在開發機上每次查詢要 **15 秒**。
換成 `tasklist /v` 一樣慢，用 `-Filter "Name='...'"` 縮小範圍也沒有變快，問題出在那台機器的 WMI 本身。

現在的做法：每個執行中的 AutoHotkey 腳本都有一個隱藏視窗，class 是 `AutoHotkey`，標題是 `<腳本路徑> - AutoHotkey vX`。
用 `EnumWindows` 找出標題含 `threads-url-clean.ahk` 的視窗，只要 **0.46 秒**。只比對這個檔名，所以不會誤停使用者的其他 AHK 腳本。

## macOS：輪詢 changeCount

### macOS 沒有剪貼簿變動的通知

macOS 沒有公開的剪貼簿變動通知 API，唯一能用的方法是定時讀 `NSPasteboard.changeCount`，這個整數每次剪貼簿被寫入都會加一。根據：

- Chromium 的 macOS 剪貼簿程式碼註解寫明，OS X 沒有提供剪貼簿變動通知，只能用輪詢偵測（[clipboard_mac.mm](https://chromium.googlesource.com/chromium/src/+/80.0.3987.116/remoting/host/clipboard_mac.mm)）。
- 2003 年 Apple cocoa-dev 郵件列表上的回覆，建議的也是用 `changeCount` 判斷剪貼簿有沒有變，而不是每次都去讀內容（[cocoa-dev](https://lists.apple.com/archives/cocoa-dev/2003/Jan/msg00511.html)）。
- Chromium 有另一段程式改寫了內部未公開的 `_CFPasteboardCache -setChangeCount:` 來拿到變動回呼（[pasteboard_changed_observation.mm](https://chromium.googlesource.com/chromium/src/+/08d828b920062e2b0be1f95b7d2416d163091745/base/mac/pasteboard_changed_observation.mm)）。這是私有 API，系統更新後可能失效，所以不採用。

### 別的工具怎麼做

| 工具 | 做法 | 來源 |
|---|---|---|
| Maccy（開源） | `Timer` 定時比對 `changeCount`，**預設 0.5 秒**，README 說可以調到 0.1 秒 | [Clipboard.swift](https://github.com/p0deje/Maccy/blob/master/Maccy/Clipboard.swift)、[README](https://github.com/p0deje/Maccy#speed-up-clipboard-check-interval) |
| Raycast 擴充套件 | 沒有剪貼簿變動觸發；背景執行最短間隔是 10 秒（"The minimum value is 10 seconds"），所以無法做到自動清理 | [Background Refresh](https://developers.raycast.com/information/lifecycle/background-refresh) |
| Raycast、Paste 本體 | 閉源，**無法證實**內部做法。只能推論系統沒有通知 API，它們大概也是輪詢 | — |

### 實測：每輪只比對一個整數

```js
const count = pb.changeCount;
if (count === last) continue;   // 每 0.5 秒都會跑：比對兩個整數
last = count;
// …只有 changeCount 變了，才會讀剪貼簿、跑 regex
pb.setStringForType(...);       // 寫回會讓 changeCount 再加 1
last = pb.changeCount;          // 立刻記下新值，自己的寫入就不會被當成新的複製
```

在除錯版本加計數器，複製一次 Threads 連結後等 6 秒：

```
PASS #1 changeCount=537
WROTE, changeCount now 538
polls=4 passes=1 writes=1
polls=8 passes=1 writes=1
polls=12 passes=1 writes=1
```

處理和寫回各只發生一次，之後每一輪都停在整數比對。常駐時的 CPU 約 0.2%（Apple Silicon, macOS 26）。

### 考慮過但沒採用：偵測到動作才輪詢

想法是先監聽 ⌘C 或滑鼠點擊，偵測到了才開始檢查剪貼簿。沒採用的原因：

1. **會漏掉主要情境。**Threads 的「複製連結」是 App 裡的按鈕，不會經過 ⌘C。要抓到就得監聽所有滑鼠點擊，檢查次數反而比現在多。
2. **需要額外授權。**全域監聽鍵盤和滑鼠，要在系統設定開「輔助使用」或「輸入監控」權限，就不再是零設定安裝了。
3. **省不了多少。**現在的成本只是每 0.5 秒讀一個整數。

### 已知限制

- 複製後最多要等 0.5 秒才會清理完成，複製完立刻貼上可能貼到還沒清的版本。如果需要，把 `threads-url-clean.js` 裡的 `delay(0.5)` 改成 `delay(0.1)`，成本一樣幾乎為零。
- 沒有提示：在背景安靜執行，選單列也沒有圖示。

## 執行方式與自動啟動

| | Windows | macOS |
|---|---|---|
| 執行者 | AutoHotkey v2（需要安裝） | `/usr/bin/osascript -l JavaScript`（系統內建，JXA） |
| 自動啟動 | 「啟動」資料夾裡的捷徑 | `~/Library/LaunchAgents` 裡的 plist（`RunAtLoad` + `KeepAlive`，掛掉會自動重啟） |
| 安裝位置 | `%LOCALAPPDATA%\threads-url-clean\` | `~/Library/Application Support/threads-url-clean/` |
| Log | 安裝資料夾裡的 `threads-url-clean.log`：啟動、結束原因、錯誤 | `~/Library/Logs/threads-url-clean.log`：stderr |

### Windows 為什麼要寫 log

2026-10-21 有一次重新登入後，`switch-input.ahk` 有被開機啟動，清理程式卻沒有在跑。
開機捷徑、安裝檔、「啟動應用程式」清單都正常，手動執行捷徑也能正常常駐，事件檢視器裡也沒有 AutoHotkey 當掉的紀錄，
所以無法分辨是登入時根本沒被執行，還是執行後自己結束了。

現在腳本會在安裝資料夾寫 log，`check.ps1` 會把最後幾行列成 `LOG=`：

- 沒有 `start`：開機捷徑根本沒有執行它。
- 有 `exit reason=...`：AutoHotkey 回報的結束原因，例如 `Logoff`、`Shutdown`、`Single`（被同一支腳本的新實例取代）。
- 有 `error: ...`：執行時期的錯誤。現在只寫 log、不跳對話框（`OnError` 回傳 true），避免使用者不小心按掉而讓程式結束。

安裝腳本會把程式複製出 repo，所以裝完可以把 clone 刪掉。

### PowerShell 腳本只用 ASCII

Windows PowerShell 5.1 會用系統的 ANSI 編碼（繁中 Windows 是 Big5）讀沒有 BOM 的 `.ps1`，非 ASCII 字元會壞掉，甚至吞掉下一行程式碼。
所以 `windows/*.ps1` 一律只寫 ASCII，`selftest.ps1` 裡的中文測試字串用 `[char]0x770B` 這種碼位組出來。
`.gitattributes` 另外固定 `.sh`/`.js` 用 LF、`.ps1`/`.ahk` 用 CRLF。

## 驗證紀錄

- Windows 11（AutoHotkey 2.0.2）和 macOS 26.6 arm64 都跑過完整流程：`check` → `install` → `selftest`（含 `/share/` 短連結）→ `uninstall`。移除後沒有任何殘留。
- 另外找了一個沒參與開發的 agent，只照 AGENTS.md 安裝並驗證一次。前面提到的中文吃字 bug 就是它找到的。
