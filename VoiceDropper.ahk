#Requires AutoHotkey v2.0
#SingleInstance Force

; --- 設定 ---
TIMER_INTERVAL := 100
MAX_HISTORY := 10
TARGET_TITLES := ["Chrome Remote Desktop", "Chrome リモート デスクトップ", "Chromeリモート デスクトップ"]
FLASH_COLOR := "C8F7C5"
DEFAULT_COLOR := "FFFFFF"

; --- 状態 ---
prevActiveHwnd := 0
wasTargetActive := false
history := []

; --- GUI構築 ---
app := Gui("+AlwaysOnTop +Resize", "VoiceDropper")
app.SetFont("s12")
app.OnEvent("Size", GuiResize)
app.OnEvent("Close", (*) => ExitApp())

MARGIN_RIGHT := 2
MARGIN_BOTTOM := 2
app.MarginX := 8
app.MarginY := 8

editCtrl := app.AddEdit("vMemoEdit w260 h120 Multi WantReturn")

btnHistory := app.AddButton("w70 Section", "▼履歴")
btnHistory.OnEvent("Click", ShowHistory)

btnCopy := app.AddButton("w40 ys", "📋")
btnCopy.OnEvent("Click", ManualCopy)

btnClear := app.AddButton("w40 ys", "🗑")
btnClear.OnEvent("Click", ManualClear)

btnMic := app.AddButton("w40 ys", "🎤")
btnMic.OnEvent("Click", ToggleVoiceInput)

app.Show("w340 h200")

; --- フォーカス監視タイマー開始 ---
SetTimer(CheckFocus, TIMER_INTERVAL)

; --- フォーカス検知 ---
CheckFocus() {
    global prevActiveHwnd, wasTargetActive
    try {
        activeHwnd := WinGetID("A")
    } catch {
        return
    }
    if (activeHwnd = prevActiveHwnd) {
        return
    }
    prevActiveHwnd := activeHwnd

    isTarget := IsTargetWindow(activeHwnd)
    if (isTarget && !wasTargetActive) {
        DoCopy()
    }
    wasTargetActive := isTarget
}

IsTargetWindow(hwnd) {
    global TARGET_TITLES
    try {
        title := WinGetTitle(hwnd)
    } catch {
        return false
    }
    for targetTitle in TARGET_TITLES {
        if InStr(title, targetTitle) {
            return true
        }
    }
    return false
}

; --- コピー処理 ---
DoCopy() {
    global editCtrl, history, MAX_HISTORY
    text := editCtrl.Value
    if (text = "") {
        return
    }

    A_Clipboard := text

    history.InsertAt(1, text)
    if (history.Length > MAX_HISTORY) {
        history.Pop()
    }

    editCtrl.Value := ""
    FlashNotify()
}

ManualCopy(*) {
    global editCtrl, history, MAX_HISTORY
    text := editCtrl.Value
    if (text = "") {
        return
    }

    A_Clipboard := text

    history.InsertAt(1, text)
    if (history.Length > MAX_HISTORY) {
        history.Pop()
    }

    FlashNotify()
}

ManualClear(*) {
    global editCtrl, history, MAX_HISTORY
    text := editCtrl.Value
    if (text = "") {
        return
    }

    history.InsertAt(1, text)
    if (history.Length > MAX_HISTORY) {
        history.Pop()
    }

    editCtrl.Value := ""
}

; --- コピー通知（背景色フラッシュ） ---
FlashNotify() {
    global editCtrl, FLASH_COLOR, DEFAULT_COLOR
    editCtrl.Opt("Background" FLASH_COLOR)
    editCtrl.Redraw()
    SetTimer(ResetColor, -300)
}

ResetColor() {
    global editCtrl, DEFAULT_COLOR
    editCtrl.Opt("Background" DEFAULT_COLOR)
    editCtrl.Redraw()
}

; --- 履歴ドロップダウン ---
ShowHistory(*) {
    global history
    if (history.Length = 0) {
        ToolTip("履歴がありません")
        SetTimer((*) => ToolTip(), -1500)
        return
    }

    histMenu := Menu()
    for idx, text in history {
        displayText := StrLen(text) > 20 ? SubStr(text, 1, 20) "..." : text
        displayText := StrReplace(displayText, "`n", " ")
        histMenu.Add(displayText, SelectHistory.Bind(idx))
    }
    histMenu.Show()
}

SelectHistory(idx, *) {
    global history, editCtrl
    if (idx > history.Length) {
        return
    }
    text := history[idx]
    editCtrl.Value := text
    A_Clipboard := text
    FlashNotify()
}

; --- 音声入力トグル ---
ToggleVoiceInput(*) {
    Send("#h")
}

; --- リサイズ追従 ---
GuiResize(thisGui, minMax, width, height) {
    if (minMax = -1) {
        return
    }
    global editCtrl, btnHistory, btnCopy, btnClear, btnMic, MARGIN_RIGHT, MARGIN_BOTTOM
    marginX := 8
    editW := width - marginX - MARGIN_RIGHT
    btnH := 30
    btnY := height - btnH - MARGIN_BOTTOM
    editH := btnY - marginX - 4
    editCtrl.Move(, , editW, editH)
    btnHistory.Move(, btnY)
    btnCopy.Move(, btnY)
    btnClear.Move(, btnY)
    btnMic.Move(, btnY)
}
