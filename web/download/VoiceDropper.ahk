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
app := Gui("+AlwaysOnTop +Resize -Caption", "VoiceDropper")
app.SetFont("s12")
app.OnEvent("Size", GuiResize)

MARGIN_RIGHT := 2
MARGIN_BOTTOM := 2
app.MarginX := 8
app.MarginY := 8

editCtrl := app.AddEdit("vMemoEdit w260 h120 Multi WantReturn")

btnClose := app.AddButton("w30 Section", "✕")
btnClose.OnEvent("Click", (*) => ExitApp())

app.SetFont("s14", "Segoe MDL2 Assets")
btnSettings := app.AddButton("w40 ys x+2", Chr(0xE713))
btnSettings.OnEvent("Click", OpenSettings)
app.SetFont("s12")

btnHistory := app.AddButton("w70 ys x+2", "▼履歴")
btnHistory.OnEvent("Click", ShowHistory)

chkTopmost := app.AddCheckbox("ys x+2 w62 Checked", "最前面")
chkTopmost.OnEvent("Click", ToggleTopmost)

app.SetFont("s14", "Segoe MDL2 Assets")
btnCopy := app.AddButton("w40 ys x+2", Chr(0xE8C8))
btnCopy.OnEvent("Click", ManualCopy)
app.SetFont("s12")

btnClear := app.AddButton("w40 ys x+2", "🗑")
btnClear.OnEvent("Click", ManualClear)

btnMic := app.AddButton("w40 ys x+2", "🎤")
btnMic.OnEvent("Click", ToggleVoiceInput)

app.Show("w460 h200")

; --- どこでもドラッグで移動 ---
OnMessage(0x0084, WM_NCHITTEST)
WM_NCHITTEST(wParam, lParam, msg, hwnd) {
    global app, editCtrl
    if (hwnd != app.Hwnd) {
        return
    }
    static WM_NC := 0x0084
    result := DllCall("DefWindowProc", "Ptr", hwnd, "UInt", WM_NC, "Ptr", wParam, "Ptr", lParam)
    if (result = 1) {
        return 2
    }
}

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

; --- 最前面トグル ---
ToggleTopmost(*) {
    global app, chkTopmost
    if (chkTopmost.Value) {
        app.Opt("+AlwaysOnTop")
    } else {
        app.Opt("-AlwaysOnTop")
    }
}

; --- 音声入力トグル ---
micPendingFocus := false
ToggleVoiceInput(*) {
    global editCtrl, app, micPendingFocus
    focused := ControlGetFocus(app)
    if (focused = editCtrl.Hwnd) {
        Send("#h")
    } else {
        micPendingFocus := true
        editCtrl.Focus()
        SetTimer(SendVoiceAfterFocus, -50)
    }
}

SendVoiceAfterFocus() {
    global micPendingFocus
    if (micPendingFocus) {
        micPendingFocus := false
        Send("#h")
    }
}

; --- 設定画面 ---
OpenSettings(*) {
    global TARGET_TITLES, MAX_HISTORY

    settingsGui := Gui("+AlwaysOnTop +Owner" app.Hwnd, "設定")
    settingsGui.SetFont("s10")
    settingsGui.MarginX := 10
    settingsGui.MarginY := 10

    settingsGui.AddText(, "対象ウィンドウ（チェックしたウィンドウへの切替時に自動コピー）:")
    lv := settingsGui.AddListView("w400 h200 Checked", ["ウィンドウタイトル"])

    windows := []
    for hwnd in WinGetList() {
        try {
            title := WinGetTitle(hwnd)
        } catch {
            continue
        }
        if (title = "" || title = "設定" || title = "VoiceDropper") {
            continue
        }
        try {
            style := WinGetStyle(hwnd)
        } catch {
            continue
        }
        if !(style & 0x10000000) {
            continue
        }
        alreadyAdded := false
        for w in windows {
            if (w = title) {
                alreadyAdded := true
                break
            }
        }
        if (alreadyAdded) {
            continue
        }
        windows.Push(title)
        row := lv.Add(, title)
        for targetTitle in TARGET_TITLES {
            if InStr(title, targetTitle) {
                lv.Modify(row, "Check")
                break
            }
        }
    }
    lv.ModifyCol(1, 380)

    settingsGui.AddText(, "")
    settingsGui.AddText(, "履歴の保持件数:")
    edHistory := settingsGui.AddEdit("w60 Number", MAX_HISTORY)
    udHistory := settingsGui.AddUpDown("Range1-100", MAX_HISTORY)

    btnRow := settingsGui.AddButton("w80 Section", "OK")
    btnRow.OnEvent("Click", SaveSettings.Bind(settingsGui, lv, edHistory))
    btnCancel := settingsGui.AddButton("w80 ys", "キャンセル")
    btnCancel.OnEvent("Click", (*) => settingsGui.Destroy())

    linkHelp := settingsGui.AddLink("ys", '<a href="https://door-fujita.com/contents/VoiceDropper/help/">ヘルプ</a>')

    settingsGui.Show()
}

SaveSettings(settingsGui, lv, edHistory, *) {
    global TARGET_TITLES, MAX_HISTORY

    newTargets := []
    loop lv.GetCount() {
        if (lv.GetText(A_Index, 0) != "") {
            checked := SendMessage(0x102C, A_Index - 1, 0xF000,, lv.Hwnd)
            isChecked := (checked >> 12) - 1
            if (isChecked) {
                newTargets.Push(lv.GetText(A_Index))
            }
        }
    }

    if (newTargets.Length > 0) {
        TARGET_TITLES := newTargets
    }

    newMax := Integer(edHistory.Value)
    if (newMax >= 1) {
        MAX_HISTORY := newMax
    }

    settingsGui.Destroy()
}

; --- リサイズ追従 ---
GuiResize(thisGui, minMax, width, height) {
    if (minMax = -1) {
        return
    }
    global editCtrl, btnClose, btnSettings, btnHistory, chkTopmost, btnCopy, btnClear, btnMic, MARGIN_RIGHT, MARGIN_BOTTOM
    marginX := 8
    editW := width - marginX - MARGIN_RIGHT
    btnH := 30
    btnY := height - btnH - MARGIN_BOTTOM
    editH := btnY - marginX - 4
    editCtrl.Move(, , editW, editH)
    btnClose.Move(, btnY)
    btnSettings.Move(, btnY)
    btnHistory.Move(, btnY)
    chkTopmost.Move(, btnY)
    btnCopy.Move(, btnY)
    btnClear.Move(, btnY)
    btnMic.Move(, btnY)
}
