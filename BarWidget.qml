import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import qs.Commons
import qs.Ui
import "Model.js" as Model

// Surface Book 2 bar widget. Shows the current clipboard mode (laptop vs
// tablet) and hosts the panel with base eject + touchscreen control.
//
// State comes from the tablet-mode watchdog service (surfbookd), which reads
// org.surface.dtx on the system bus and mirrors it to
// $XDG_STATE_HOME/surfacebook/state.json. The widget polls that file; the
// panel actions talk to surfbookctl, which is the single entry point for
// ejecting the base and toggling the touchscreen.
BarWidget {
  id: root
  moduleName: "dues.surfacebook2"

  readonly property string home: Quickshell.env("HOME") || ""
  readonly property string envStateHome: Quickshell.env("XDG_STATE_HOME") || ""
  readonly property string stateHome: envStateHome !== "" ? envStateHome : home + "/.local/state"
  readonly property string stateFile: stateHome + "/surfacebook/state.json"
  readonly property string toolPath: String(Qt.resolvedUrl("bin/surfbookctl")).replace(/^file:\/\//, "")

  property var state: null
  readonly property string mode: state ? String(state.mode || "") : ""
  readonly property bool baseAttached: state ? String(state.base || "attached") === "attached" : true

  function refresh() {
    if (stateProc.running) return
    stateProc.running = true
  }

  function togglePanel() {
    if (panelLoader.item) panelLoader.item.toggle()
  }

  // Run surfbookctl actions (eject, touch toggle) from IPC / the pill. Uses a
  // Process object directly — this omarchy/Quickshell version has no Util.spawn.
  Process {
    id: cmdProc
    running: false
    command: []
    stdout: StdioCollector {
      waitForEnd: true
    }
  }

  function runSurfctl(args) {
    var cmd = [root.toolPath]
    for (var i = 0; i < args.length; i++) cmd.push(String(args[i]))
    cmdProc.command = cmd
    cmdProc.running = true
  }

  // ---- Panel popup contract: Bar.findPanelWidget routes shell.summon and
  //      popout switching through these on the bar-widget root.
  readonly property bool opened: panelLoader.item ? panelLoader.item.opened === true : false

  function open() {
    if (panelLoader.item) panelLoader.item.open()
  }

  function close() {
    if (panelLoader.item) panelLoader.item.close()
  }

  readonly property bool popoutSwitchClosing: panelLoader.item ? panelLoader.item.popoutSwitchClosing === true : false

  function closeForPopoutSwitch() {
    if (panelLoader.item) panelLoader.item.closeForPopoutSwitch()
  }

  function injectPanel() {
    var target = panelLoader.item
    if (!target) return
    if ("bar" in target) target.bar = root.bar
    if ("settings" in target) target.settings = root.settings
    if ("anchorItem" in target) target.anchorItem = button
    if ("hostWidget" in target) target.hostWidget = root
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  onBarChanged: injectPanel()
  onSettingsChanged: injectPanel()

  Connections {
    target: Hyprland
    function onRawEvent(event) {
      // Detach/attach replays devices and monitors; refresh so the pill
      // does not lag a full poll cycle behind a base swap.
      if (!event || !event.name) return
      const n = String(event.name)
      if (n.indexOf("device") !== -1 || n.indexOf("monitor") !== -1) root.refresh()
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
        root.state = Model.parseState(text)
      }
    }
  }

  Timer {
    id: stallTimer
    interval: 3000
    onTriggered: {
      stateProc.running = false
      root.refresh()
    }
  }

  Timer {
    interval: 2000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: root.refresh()
  }

  Loader {
    id: panelLoader
    active: true
    source: Qt.resolvedUrl("Panel.qml")
    visible: false
    onLoaded: {
      root.injectPanel()
      Qt.callLater(root.injectPanel)
    }
  }

  IpcHandler {
    target: "dues.surfacebook2"

    function refresh(): void { root.broadcast("refresh") }
    function open(): void { root.open() }
    function close(): void { root.close() }
    function show(): void { root.open() }
    function hide(): void { root.close() }
    function toggle(): void { root.togglePanel() }
    // Convenience IPC for keybindings: eject the base or flip the touchscreen
    // without opening the panel. See readme for example binds.
    function eject(): void { root.runSurfctl(["eject"]) }
    function touchToggle(): void { root.runSurfctl(["touch", "toggle"]) }
    // Raise/hide the on-screen keyboard without opening the panel (see readme).
    function keyboardToggle(): void { root.runSurfctl(["keyboard", "toggle"]) }
    function keyboardOn(): void { root.runSurfctl(["keyboard", "on"]) }
    function keyboardOff(): void { root.runSurfctl(["keyboard", "off"]) }
  }

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar

    // Laptop vs tablet glyph.
    text: root.mode === "tablet" ? "\uf3fa" : "\uf109"
    slotSize: Style.bar.statusSlot
    tooltipText: Model.tooltip(root.state)

    onPressed: function(b) {
      if (b === Qt.RightButton && root.baseAttached && root.mode !== "tablet") {
        // Right click: quick eject when attached; otherwise open the panel.
        root.runSurfctl(["eject"])
        return
      }
      root.togglePanel()
    }
  }
}