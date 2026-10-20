# threads-url-clean

複製 Threads 連結時，自動把網址裡的 `xmt` 追蹤參數拿掉。

```
複製到： https://www.threads.com/@user/post/ABC123?xmt=AQGxxxxxxxxxxxx...
貼上時： https://www.threads.com/@user/post/ABC123
```

`threads.com/share/xxxx/` 這種短連結也會自動展開成乾淨的貼文網址。

支援 **Windows 10/11** 和 **macOS**。

## 為什麼要拿掉 xmt

Threads 的「複製連結」會在網址後面加上 `?xmt=...`。這串 token 綁定的是**分享的人**，
Meta 可以靠它知道這個連結是誰分享出去的、又被誰點開。拿掉之後連結照樣能開，
只是沒辦法追蹤到你。

## 安裝：交給你的 AI agent（推薦）

把下面這段話貼給你的 agent（Claude Code、Codex、Cursor、Gemini CLI 等可以執行指令的 agent）：

> 幫我安裝 https://github.com/MeteorVE/threads-url-clean ：clone 下來後照 AGENTS.md 的步驟，先檢查我的環境，再安裝並驗證。

agent 會：

1. 判斷你是 Windows 還是 Mac，跑環境檢查（`check`）
2. 缺東西的話**先問你**再安裝（只有 Windows 需要 AutoHotkey v2）
3. 安裝並設定開機自動啟動
4. 跑自我測試確認有效

給 agent 看的完整步驟在 [AGENTS.md](AGENTS.md)。

## 手動安裝

### Windows

需要 [AutoHotkey v2](https://www.autohotkey.com/)（v1 不行）：

```powershell
winget install --id AutoHotkey.AutoHotkey -e
```

接著在這個 repo 的資料夾裡執行：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File windows\check.ps1     # 檢查環境
powershell -NoProfile -ExecutionPolicy Bypass -File windows\install.ps1   # 安裝 + 開機啟動
powershell -NoProfile -ExecutionPolicy Bypass -File windows\selftest.ps1  # 驗證（會暫時改動剪貼簿）
```

成功的話，複製 Threads 連結時游標旁會短暫跳出「Threads: xmt removed」，
系統匣也會出現綠色的 **H** 圖示。

### macOS

不需要安裝任何東西，用的是系統內建的 `osascript`：

```bash
bash macos/check.sh      # 檢查環境
bash macos/install.sh    # 安裝 + 登入時自動啟動
bash macos/selftest.sh   # 驗證（會暫時改動剪貼簿）
```

Mac 版在背景安靜執行，沒有圖示也沒有提示。

## 移除

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File windows\uninstall.ps1
```

```bash
bash macos/uninstall.sh
```

程式和開機啟動設定會一起移除，AutoHotkey 本身不會被移除。

## 運作原理

| | Windows | macOS |
|---|---|---|
| 怎麼知道剪貼簿變了 | 系統的剪貼簿變動通知（AutoHotkey `OnClipboardChange`），收到通知才動作，平常不吃 CPU | macOS 沒有變動通知，所以每 0.5 秒看一次 `NSPasteboard.changeCount`（只是一個數字），數字變了才去讀內容 |
| 腳本 | `windows/threads-url-clean.ahk` | `macos/threads-url-clean.js`（JavaScript for Automation） |
| 開機啟動 | 「啟動」資料夾裡的捷徑 | LaunchAgent（掛掉會自動重啟） |

收到變動後的處理流程：

1. 不是文字、或文字裡沒有 `threads.` → 直接略過（大部分的複製在這裡就結束了）
2. 如果是 `/share/xxx/` 短連結 → 送出一個不跟隨轉址的請求，從 302 回應的 `Location` 拿到真正的網址（3 秒逾時，失敗就保持原樣）
3. 只拿掉 Threads 網址上的 `xmt`、`slof` 參數，其他參數和非 Threads 的網址都不動
4. 結果跟原本不一樣才寫回剪貼簿（所以不會因為自己寫入又觸發而無限循環）

## 隱私

- 除了展開 `/share/` 短連結時會連到 threads.com，程式不會連到任何其他地方。
- 不記錄、不上傳剪貼簿內容。Mac 版的 log 只記錄錯誤訊息。

## License

MIT
