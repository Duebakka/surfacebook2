import QtQuick
import qs.Commons
import qs.Ui

// One tappable key on the on-screen keyboard. Emits `tapped` so the keyboard
// decides what the key does; size comes from the parent layout.
Rectangle {
  id: root

  property string label: ""
  property bool dim: false
  property bool accent: false
  property bool accentText: false

  signal tapped

  radius: Style.cornerRadius
  color: root.accent ? Color.accent
                     : Color.menu.selectedBackground
  border.width: root.accent ? Math.max(1, Style.space(2)) : 0
  border.color: Color.accent
  opacity: root.dim ? 0.72 : 1.0

  Behavior on color { ColorAnimation { duration: 80 } }

  Text {
    anchors.fill: parent
    anchors.margins: Style.space(2)
    text: root.label
    color: root.accent ? (root.accentText ? Color.menu.text : Color.accent) : Color.menu.text
    font.family: Style.font.menuFamily
    font.pixelSize: Math.max(16, Math.round(parent.height * 0.42))
    horizontalAlignment: Text.AlignHCenter
    verticalAlignment: Text.AlignVCenter
    elide: Text.ElideRight
  }

  MouseArea {
    id: area
    anchors.fill: parent
    onPressed: root.scale = 0.94
    onReleased: {
      root.scale = 1.0
      root.tapped()
    }
    onCanceled: root.scale = 1.0
  }

  Behavior on scale { NumberAnimation { duration: 70 } }
}