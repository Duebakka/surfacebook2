import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import qs.Commons
import qs.Ui
import "KeyboardLayout.js" as Kbd

// Surfbook2 split on-screen keyboard overlay.
//
// The shell instantiates this entry point with keepLoaded so the layer surface
// stays alive; visibility is driven by the plugin's own state (surfbookd
// mirrors the keyboard intent + tablet mode to state.json as keyboard_status).
// Keys inject through ydotool so events land on whatever the user's hands left
// focused — the layer never takes keyboard focus itself.
Item {
  id: root

  property string omarchyPath: Quickshell.env("OMARCHY_PATH")
  property var shell: null
  property var manifest: null

  readonly property string home: Quickshell.env("HOME") || ""
  readonly property string envStateHome: Quickshell.env("XDG_STATE_HOME") || ""
  readonly property string stateHome: envStateHome !== "" ? envStateHome : home + "/.local/state"
  readonly property string stateFile: stateHome + "/surfacebook/state.json"
  readonly property string toolPath: String(Qt.resolvedUrl("bin/surfbookctl")).replace(/^file:\/\//, "")

  // shell summon contract — a summon toggles the on-screen keyboard.
  property bool opened: root.keyboardVisible

  // Layout + injection state.
  property string page: Kbd.PAGE_LETTERS
  property bool shiftLatched: false
  property bool superLatched: false
  property var rowModel: Kbd.rows(root.page)
  property var ctrlLeft: Kbd.controlRows(root.page).left
  property var ctrlRight: Kbd.controlRows(root.page).right

  // Compact sizing: two thumb-reach halves pinned to the bottom corners,
  // small keys, and a transparent gap down the middle (the mask on the
  // panel keeps that gap click-through so the app behind stays usable).
  // Sizes are logical px (this panel is 1500x1000 at scale 2).
  property real halfRatio: 0.4
  property real halfMaxWidth: 400
  property real keyHMax: 56
  property real cardOpacity: 0.92

  readonly property real screenW: panel.screen ? panel.screen.width : 1920
  readonly property real halfWidth: Math.round(Math.min(halfMaxWidth, Math.max(300, screenW * halfRatio)))
  readonly property real keyH: Math.round(Math.min(Math.max(screenW / 34, 40), keyHMax))
  readonly property real sideMargin: Math.round(keyH * 0.5)
  readonly property real panelHeight: root.keyH * 4 + Style.spacing.sm * 6

  property bool keyboardVisible: false

  // Never leave a latched modifier physically held if the keypad disappears.
  onKeyboardVisibleChanged: {
    if (!root.keyboardVisible) root.dropLatchedSuper()
  }

  // Serialized ydotool injection queue.
  property var pending: []

  function pluginId() {
    return (root.manifest && root.manifest.id) || "dues.surfacebook2"
  }

  function setPage(p) {
    if (p !== Kbd.PAGE_LETTERS && p !== Kbd.PAGE_SYMBOLS) return false
    root.page = p
    root.shiftLatched = false
    root.rowModel = Kbd.rows(root.page)
    root.ctrlLeft = Kbd.controlRows(root.page).left
    root.ctrlRight = Kbd.controlRows(root.page).right
    return true
  }

  function charKeyData(k) {
    var ch = k.char
    if (root.shiftLatched && k.shifted) ch = k.shifted
    return ch
  }

  function injectChar(ch) {
    root.pending = root.pending.concat([["ydotool", "type", "--key-delay", "15", ch]])
    pumpPending()
  }

  function injectKey(code) {
    root.pending = root.pending.concat([["ydotool", "key", code + ":1", code + ":0"]])
    pumpPending()
  }

  function injectKeyDown(code) {
    root.pending = root.pending.concat([["ydotool", "key", code + ":1"]])
    pumpPending()
  }

  function injectKeyUp(code) {
    root.pending = root.pending.concat([["ydotool", "key", code + ":0"]])
    pumpPending()
  }

  // Release a latched modifier (super) after the following key has been
  // injected, so SUPER+key chords arrive as proper key events.
  function releaseSuper() {
    if (!root.superLatched) return
    root.superLatched = false
    injectKeyUp(125)
  }

  // If the OSK disappears (mode change, dismiss) while super is latched,
  // send the release so a modifier can never be left stuck down.
  function dropLatchedSuper() {
    if (!root.superLatched) return
    root.superLatched = false
    root.pending = root.pending.concat([["ydotool", "key", "125:0"]])
    pumpPending()
  }

  function pressKey(k) {
    switch (k.type) {
      case "char":
        injectChar(root.charKeyData(k))
        root.shiftLatched = false
        releaseSuper()
        return
      case "shift":
        root.shiftLatched = !root.shiftLatched
        return
      case "super":
        if (root.superLatched)
          injectKeyUp(125)
        else
          injectKeyDown(125)
        root.superLatched = !root.superLatched
        return
      case "sym":
        setPage(root.page === Kbd.PAGE_LETTERS ? Kbd.PAGE_SYMBOLS : Kbd.PAGE_LETTERS)
        return
      case "space":
      case "backspace":
      case "enter":
        injectKey(k.code)
        releaseSuper()
        return
      case "dismiss":
        dropLatchedSuper()
        root.close()
        return
    }
  }

  function pumpPending() {
    if (inject.running || root.pending.length === 0) return
    inject.command = root.pending[0]
    root.pending = root.pending.slice(1)
    inject.running = true
  }

  // Shell overlay contract: summoning = keyboard on, hiding = keyboard off,
  // exactly like surfbookctl keyboard on/off/toggle.
  function open(payload) {
    runCtl(["keyboard", "on"])
    return true
  }

  function close() {
    runCtl(["keyboard", "off"])
    return true
  }

  function toggle() {
    runCtl(["keyboard", "toggle"])
    return true
  }

  function runCtl(args) {
    var cmd = [root.toolPath]
    for (var i = 0; i < args.length; i++) cmd.push(String(args[i]))
    ctlProc.command = cmd
    ctlProc.running = true
  }

  // ---- key surface --------------------------------------------------------

  // Two thumb-sized halves anchored to the bottom corners; the middle of
  // the layer stays transparent (and click-through) so the app behind it
  // stays visible and usable. Each half carries its own control row, so no
  // control bar spans across the screen.
  PanelWindow {
    id: panel
    visible: root.keyboardVisible
    color: "transparent"
    anchors {
      left: true
      right: true
      bottom: true
    }
    implicitHeight: root.panelHeight
    WlrLayershell.namespace: "surfacebook2-osk"
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    WlrLayershell.exclusiveZone: root.panelHeight
    screen: Quickshell.screens.length > 0 ? Quickshell.screens[0] : null

    // Only the two cards take pointer input; the transparent middle gap
    // passes clicks straight through to the app behind.
    mask: Region {
      Region { item: leftCard }
      Region { item: rightCard }
    }

    // The OSK must never take keyboard focus — ydotool feeds the focused app,
    // so this surface stays input-transparent to key events while still
    // passing taps to the buttons below.
    Item {
      id: surface
      anchors.fill: parent

      // Left half: bottom-left corner. Letter rows plus a control row that
      // holds super / symbols / backspace / dismiss.
      Rectangle {
        id: leftCard
        anchors {
          left: parent.left
          leftMargin: root.sideMargin
          bottom: parent.bottom
          bottomMargin: Style.spacing.sm
        }
        width: root.halfWidth
        height: root.keyH * 4 + Style.spacing.sm * 5
        radius: Style.cornerRadius
        color: Color.menu.background
        border.width: Style.normalBorderWidth
        border.color: Color.menu.border
        opacity: root.cardOpacity
        clip: true

        Column {
          id: leftCol
          anchors.fill: parent
          anchors.margins: Style.spacing.sm
          spacing: Style.spacing.sm

          Repeater {
            model: root.rowModel.left
            delegate: Row {
              id: leftRow
              required property var modelData
              width: leftCol.width
              height: root.keyH
              spacing: Style.space(4)
              Repeater {
                model: modelData
                delegate: KeyboardKey {
                  required property var modelData
                  width: (leftRow.width - Style.space(4) * (leftRow.modelData.length - 1)) * (modelData.w || 1) / sumWeights(leftRow.modelData)
                  height: parent.height
                  label: root.shiftLatched && modelData.shifted ? modelData.shifted : modelData.label
                  dim: modelData.type !== "char"
                  accent: modelData.type === "shift" && root.shiftLatched
                  onTapped: pressKey(modelData)
                }
              }
            }
          }

          Row {
            id: ctrlRowL
            width: leftCol.width
            height: root.keyH
            spacing: Style.space(4)
            Repeater {
              model: root.ctrlLeft
              delegate: KeyboardKey {
                required property var modelData
                width: (ctrlRowL.width - Style.space(4) * (root.ctrlLeft.length - 1)) * (modelData.w || 1) / sumWeights(root.ctrlLeft)
                height: parent.height
                label: modelData.label
                dim: modelData.type !== "space" && modelData.type !== "dismiss"
                accent: (modelData.type === "sym" && root.page !== Kbd.PAGE_LETTERS) || modelData.type === "super" && root.superLatched || modelData.type === "dismiss"
                accentText: modelData.type === "dismiss"
                onTapped: pressKey(modelData)
              }
            }
          }
        }
      }

      // Right half: bottom-right corner. Letter rows plus a control row that
      // holds enter and a wide space bar.
      Rectangle {
        id: rightCard
        anchors {
          right: parent.right
          rightMargin: root.sideMargin
          bottom: parent.bottom
          bottomMargin: Style.spacing.sm
        }
        width: root.halfWidth
        height: root.keyH * 4 + Style.spacing.sm * 5
        radius: Style.cornerRadius
        color: Color.menu.background
        border.width: Style.normalBorderWidth
        border.color: Color.menu.border
        opacity: root.cardOpacity
        clip: true

        Column {
          id: rightCol
          anchors.fill: parent
          anchors.margins: Style.spacing.sm
          spacing: Style.spacing.sm

          Repeater {
            model: root.rowModel.right
            delegate: Row {
              id: rightRow
              required property var modelData
              width: rightCol.width
              height: root.keyH
              spacing: Style.space(4)
              Repeater {
                model: modelData
                delegate: KeyboardKey {
                  required property var modelData
                  width: (rightRow.width - Style.space(4) * (rightRow.modelData.length - 1)) * (modelData.w || 1) / sumWeights(rightRow.modelData)
                  height: parent.height
                  label: root.shiftLatched && modelData.shifted ? modelData.shifted : modelData.label
                  dim: modelData.type !== "char"
                  onTapped: pressKey(modelData)
                }
              }
            }
          }

          Row {
            id: ctrlRowR
            width: rightCol.width
            height: root.keyH
            spacing: Style.space(4)
            Repeater {
              model: root.ctrlRight
              delegate: KeyboardKey {
                required property var modelData
                width: (ctrlRowR.width - Style.space(4) * (root.ctrlRight.length - 1)) * (modelData.w || 1) / sumWeights(root.ctrlRight)
                height: parent.height
                label: modelData.label
                dim: modelData.type !== "space"
                onTapped: pressKey(modelData)
              }
            }
          }
        }
      }

      // Decorative brand plate between the halves: a quiet breathing glow so
      // the gap reads as intentional space. Sized to the *actual* gap so it
      // never spills over the keys — in portrait the gap is narrow and the
      // plate shrinks with it. Not part of the mask, so taps pass straight
      // through to the window behind the keyboard.
      Rectangle {
        id: gapPlate
        property real gap: parent.width - root.halfWidth * 2 - root.sideMargin * 2
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter
        width: Math.max(84, Math.min(280, Math.round(gapPlate.gap * 0.5)))
        height: Math.round(root.keyH * 1.45)
        radius: Math.round(Style.cornerRadius * 1.5)
        color: Color.menu.background
        border.width: Style.normalBorderWidth
        border.color: Color.menu.border
        opacity: root.cardOpacity * 0.55

        Text {
          id: gapText
          anchors.centerIn: parent
          text: "OMARCHY"
          color: Color.accent
          font.family: Style.font.menuFamily
          font.pixelSize: Math.max(10, Math.round(parent.width * 0.085))
          font.bold: true
          font.letterSpacing: 3
          horizontalAlignment: Text.AlignHCenter
          verticalAlignment: Text.AlignVCenter
        }

        SequentialAnimation {
          running: true
          loops: Animation.Infinite
          NumberAnimation {
            target: gapPlate
            property: "scale"
            from: 1.0; to: 1.03
            duration: 2200
            easing.type: Easing.InOutSine
          }
          NumberAnimation {
            target: gapPlate
            property: "scale"
            from: 1.03; to: 1.0
            duration: 2200
            easing.type: Easing.InOutSine
          }
          ColorAnimation {
            target: gapText
            property: "color"
            from: Color.accent; to: Color.menu.text
            duration: 1300
            easing.type: Easing.InOutSine
          }
          ColorAnimation {
            target: gapText
            property: "color"
            from: Color.menu.text; to: Color.accent
            duration: 1300
            easing.type: Easing.InOutSine
          }
        }
      }
    }
  }

// weight helper for a row of keys: keys fill the row proportionally to w.
  function sumWeights(keys) {
    var sum = 0
    for (var i = 0; i < keys.length; i++) sum += (keys[i].w || 1)
    return sum
  }

  // ---- ydotool + state plumbing -------------------------------------------

  Process {
    id: inject
    running: false
    command: []
    onRunningChanged: {
      if (!running)
        pumpPending()
    }
  }

  Process {
    id: ctlProc
    running: false
    command: []
    stdout: StdioCollector {
      waitForEnd: true
    }
  }

  Process {
    id: stateProc
    command: ["cat", root.stateFile]
    running: false

    onRunningChanged: {
      if (running) {
        stallTimer.restart()
        return
      }
      stallTimer.stop()
    }

    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var st = parseState(text)
        root.keyboardVisible = st ? st.keyboard_status === "on" : false
      }
    }
  }

  Timer {
    id: stallTimer
    interval: 3000
    onTriggered: {
      stateProc.running = false
      pollTimer.restart()
    }
  }

  Timer {
    id: pollTimer
    interval: 1000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: {
      if (!stateProc.running) stateProc.running = true
    }
  }

  function parseState(text) {
    try {
      var s = JSON.parse(text)
      return typeof s === "object" && s !== null ? s : null
    } catch (e) {
      return null
    }
  }
}