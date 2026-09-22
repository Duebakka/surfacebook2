import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui
import "Model.js" as Model

// Popup panel for the Surface Book 2 widget: current clipboard mode, base
// latch, and the actions — software base eject and touchscreen toggle.
Panel {
  id: root
  moduleName: "dues.surfacebook2"
  ipcTarget: "dues.surfacebook2"
  manageIpc: false

  property var anchorItem: null
  property var hostWidget: null
  readonly property var barIdentity: hostWidget || root

  readonly property var state: (hostWidget ? hostWidget.state : null) || null
  readonly property string toolPath: hostWidget ? hostWidget.toolPath : ""

  readonly property string mode: state ? String(state.mode || "") : ""
  readonly property string base: state ? String(state.base || "attached") : "attached"
  readonly property string latch: state ? String(state.latch || "") : ""
  readonly property bool baseAttached: base === "attached"
  readonly property bool watchdogRunning: state ? state.updated > 0 : false
  readonly property string touchStatus: state ? String(state.touch || "unknown") : "unknown"
  readonly property bool touchOn: touchStatus === "on"

  readonly property string rotationMode: state ? String(state.rotation || "auto") : "auto"
  readonly property string orientation: state ? String(state.orientation || "") : ""
  readonly property bool rotationAuto: rotationMode === "auto"

  readonly property string keyboardMode: state ? String(state.keyboard || "auto") : "auto"
  readonly property string keyboardStatus: state ? String(state.keyboard_status || "off") : "off"
  readonly property bool keyboardAuto: keyboardMode !== "off"
  readonly property bool keyboardRunning: keyboardStatus === "on"

  property bool ejectBusy: false
  property bool touchBusy: false
  property bool rotateBusy: false
  property bool keyboardBusy: false
  property string actionNote: ""

  function note(text) {
    actionNote = text
    noteTimer.restart()
  }

  Timer {
    id: noteTimer
    interval: 4500
    onTriggered: root.actionNote = ""
  }

  // Layer-shell popup, like every first-party panel. KeyboardPanel (PanelWindow
  // + WlrLayershell) is what surfaces on this shell; PopupCard is an xdg-popup
  // that never mounts here.
  KeyboardPanel {
    id: card
    anchorItem: root.anchorItem
    owner: root.barIdentity
    bar: root.bar
    open: root.opened
    centerOnBar: true

    contentWidth: Style.space(360)
    contentHeight: card.fittedContentHeight(contentColumn.implicitHeight)
    borderSpec: Border.surfaceSpec("popups", "border", Color.popups.border, Math.max(1, Style.space(2)))

    // State summary + actions. KeyboardPanel's default contentItem places direct
    // children inside its padded, bordered frame, so size the column to the
    // inner width to avoid a scrollbar for content we know fits.
    Column {
      id: contentColumn
      width: card.contentWidth - card.padding * 2 - Border.left(card.borderSpec) - Border.right(card.borderSpec)
      spacing: Style.spacing.sm

      PanelSectionHeader {
        text: "SURFACE BOOK 2"
        foreground: root.barForeground
      }

      Row {
        width: parent.width
        spacing: Style.spacing.md

        Column {
          width: parent.width
          spacing: Style.space(2)

          Text {
            text: Model.modeLabel(root.mode)
            color: Qt.darker(root.barForeground, 1.0)
            font.family: Style.font.family
            font.pixelSize: Style.font.title
            font.bold: true
          }

          Text {
            text: {
              var parts = []
              parts.push(Model.baseLabel(root.base))
              if (root.latch) parts.push(Model.latchLabel(root.latch))
              return parts.join(" · ")
            }
            color: Qt.lighter(root.barForeground, 1.3)
            font.family: Style.font.family
            font.pixelSize: Style.font.caption
          }
        }
      }

      PanelSeparator {
        foreground: root.barForeground
        width: parent.width
      }

      Toggle {
        id: rotationToggle
        width: parent.width
        label: "Auto rotate"
        description: Model.rotationDescription(root.rotationMode, root.orientation)
        checked: root.rotationAuto
        accent: Color.accent
        foreground: root.barForeground
        enabled: !root.rotateBusy
        onClicked: {
          if (root.rotateBusy) return
          root.rotateBusy = true
          rotateProc.command = [root.toolPath, "rotation", "toggle"]
          rotateProc.running = true
        }
      }

      PanelSeparator {
        foreground: root.barForeground
        width: parent.width
      }

      Toggle {
        id: keyboardToggle
        width: parent.width
        label: "On-screen keyboard"
        description: Model.keyboardDescription(root.keyboardMode, root.keyboardRunning, root.mode)
        checked: root.keyboardAuto
        accent: Color.accent
        foreground: root.barForeground
        enabled: !root.keyboardBusy
        onClicked: {
          if (root.keyboardBusy) return
          root.keyboardBusy = true
          keyboardProc.command = [root.toolPath, "keyboard", "toggle"]
          keyboardProc.running = true
        }
      }

      PanelSeparator {
        foreground: root.barForeground
        width: parent.width
      }

      Toggle {
        id: touchToggle
        width: parent.width
        label: "Touchscreen"
        description: Model.touchDescription(root.touchStatus, root.baseAttached)
        checked: root.touchOn
        accent: Color.accent
        foreground: root.barForeground
        enabled: !root.touchBusy && root.baseAttached
        onClicked: {
          if (root.touchBusy || !root.baseAttached) return
          root.touchBusy = true
          touchProc.command = [root.toolPath, "touch", "toggle"]
          touchProc.running = true
        }
      }

      Button {
        id: ejectButton
        width: parent.width
        text: root.ejectBusy ? "Ejecting…" : "Eject base"
        iconText: "\uf085"
        accent: Color.accent
        foreground: root.barForeground
        enabled: root.baseAttached && !root.ejectBusy && root.mode !== "tablet"
        onClicked: {
          if (!root.baseAttached || root.ejectBusy) return
          root.ejectBusy = true
          ejectProc.command = [root.toolPath, "eject"]
          ejectProc.running = true
        }
      }

      Text {
        width: parent.width
        visible: text !== ""
        wrapMode: Text.WrapAtWordBoundaryOrAnywhere
        text: root.actionNote
        color: Color.accent
        font.family: Style.font.family
        font.pixelSize: Style.font.caption
      }

      Text {
        width: parent.width
        visible: !root.watchdogRunning
        wrapMode: Text.WrapAtWordBoundaryOrAnywhere
        text: "Tablet-mode service not running — run: surfbookctl install"
        color: root.barForeground
        font.family: Style.font.family
        font.pixelSize: Style.font.caption
      }
    }
  }

  // --- action runners -----------------------------------------------------
  // Process/Timer objects live inside a non-visual wrapper Item so they land
  // in this Panel's data list instead of the popup panel's contentItem list.
  Item {
    id: runners
    visible: false

  Process {
    id: ejectProc
    running: false
    onRunningChanged: {
      if (!running) root.ejectBusy = false
    }
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        if (String(text).trim() !== "") root.note(String(text).trim())
      }
    }
  }

  Process {
    id: touchProc
    running: false
    onRunningChanged: {
      if (!running) root.touchBusy = false
      hostRefresh.restart()
    }
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        if (String(text).trim() !== "") root.note(String(text).trim())
      }
    }
  }

  Process {
    id: rotateProc
    running: false
    onRunningChanged: {
      if (!running) root.rotateBusy = false
      hostRefresh.restart()
    }
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        if (String(text).trim() !== "") root.note(String(text).trim())
      }
    }
  }

  Process {
    id: keyboardProc
    running: false
    onRunningChanged: {
      if (!running) root.keyboardBusy = false
      hostRefresh.restart()
    }
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        if (String(text).trim() !== "") root.note(String(text).trim())
      }
    }
  }

  Timer {
    id: hostRefresh
    interval: 500
    onTriggered: root.hostWidget.refresh()
  }
  }
}