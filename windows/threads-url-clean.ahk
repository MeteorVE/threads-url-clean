#Requires AutoHotkey v2.0
; Watch the clipboard; strip xmt / slof tracking params from Threads URLs.
; e.g. https://www.threads.com/@user/post/ABC?xmt=AQF...&slof=1
;   -> https://www.threads.com/@user/post/ABC
#SingleInstance Force
Persistent
A_IconTip := "Threads URL cleaner"

; Log start / exit reason / errors next to the script, so a silent
; disappearance (e.g. not running after a logon) can be diagnosed.
; Errors are logged instead of shown, so a dialog never blocks the script.
Log(msg) {
    try FileAppend(FormatTime(, "yyyy-MM-dd HH:mm:ss") " " msg "`n",
        A_ScriptDir "\threads-url-clean.log", "UTF-8")
}
Log("start pid=" DllCall("GetCurrentProcessId"))
OnExit((reason, code) => Log("exit reason=" reason " code=" code))
OnError((e, mode) => (Log("error: " e.Message " (line " e.Line ")"), true))

OnClipboardChange(OnClip)

OnClip(dataType) {
    if dataType != 1  ; text only
        return
    s := A_Clipboard
    if !InStr(s, "threads.")
        return
    t := CleanThreads(ExpandShare(s))
    if t == s
        return
    A_Clipboard := t
    ToolTip("Threads: xmt removed")
    SetTimer(() => ToolTip(), -1200)
}

; /share/<code>/ short links 302 to the real post URL (with xmt); resolve them.
ExpandShare(s) {
    out := "", pos := 1
    while p := RegExMatch(s, "i)https?://(?:www\.)?threads\.(?:net|com)/share/[\w-]+/?", &m, pos) {
        out .= SubStr(s, pos, p - pos) ResolveRedirect(m[0])
        pos := p + m.Len
    }
    return out SubStr(s, pos)
}

ResolveRedirect(url) {
    try {
        req := ComObject("WinHttp.WinHttpRequest.5.1")
        req.Option[6] := false  ; don't follow redirects
        req.SetTimeouts(3000, 3000, 3000, 3000)
        req.Open("GET", url, false)
        req.SetRequestHeader("User-Agent", "Mozilla/5.0")
        req.Send()
        if req.Status >= 300 && req.Status < 400
            return req.GetResponseHeader("Location")
    }
    return url
}

CleanThreads(s) {
    out := "", pos := 1
    ; The query is limited to ASCII key=value pairs, so text glued right after
    ; the URL (common in CJK, e.g. "...?xmt=abc<full-width comma>lol" or "(...?xmt=abc)") is kept.
    while p := RegExMatch(s, "i)(https?://(?:www\.)?threads\.(?:net|com)/[^\s?#]*)\?([\w.-]+(?:=[\w~%+-]*)?(?:&[\w.-]+(?:=[\w~%+-]*)?)*)", &m, pos) {
        q := ""
        for kv in StrSplit(m[2], "&") {
            if kv = "" || RegExMatch(kv, "i)^(xmt|slof)(=|$)")
                continue
            q .= (q = "" ? "" : "&") kv
        }
        out .= SubStr(s, pos, p - pos) m[1] (q != "" ? "?" q : "")
        pos := p + m.Len
    }
    return out SubStr(s, pos)
}
