import QtQuick
import qs.Commons

// Prev / play-pause / next buttons revealed on pill hover. Dumb by design:
// the island owns player state, this only reports presses as signals.
Row {
  id: root
  property var player: null
  property bool playing: false

  signal prevRequested()
  signal toggleRequested()
  signal nextRequested()
  signal raiseRequested()

  spacing: 8

  Item {
    width: 26
    height: 20
    anchors.verticalCenter: parent.verticalCenter
    Text {
      anchors.centerIn: parent
      text: "◀◀"
      color: Color.bar.text
      font.pixelSize: 11
      opacity: root.player && root.player.canGoPrevious ? 1 : 0.35
    }
    MouseArea {
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      property int pressModifiers: 0
      onPressed: function(mouse) { pressModifiers = mouse.modifiers }
      onClicked: {
        if (pressModifiers & Qt.ShiftModifier) root.raiseRequested()
        else root.prevRequested()
      }
    }
  }

  Item {
    width: 26
    height: 20
    anchors.verticalCenter: parent.verticalCenter
    opacity: (root.playing && root.player && !root.player.canPause
      || !root.playing && root.player && !root.player.canPlay) ? 0.35 : 1
    Text {
      anchors.centerIn: parent
      text: "▶"
      color: Color.bar.text
      font.pixelSize: 13
      visible: !root.playing
    }
    // Drawn bars instead of the ❚❚ glyph: glyph metrics sit it above
    // the text baseline, while rectangles stay exactly centered.
    Row {
      anchors.centerIn: parent
      anchors.verticalCenterOffset: 1
      spacing: 3
      visible: root.playing
      Repeater {
        model: 2
        Rectangle {
          width: 3
          height: 11
          radius: 1
          color: Color.bar.text
        }
      }
    }
    MouseArea {
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      property int pressModifiers: 0
      onPressed: function(mouse) { pressModifiers = mouse.modifiers }
      onClicked: {
        if (pressModifiers & Qt.ShiftModifier) root.raiseRequested()
        else root.toggleRequested()
      }
    }
  }

  Item {
    width: 26
    height: 20
    anchors.verticalCenter: parent.verticalCenter
    Text {
      anchors.centerIn: parent
      text: "▶▶"
      color: Color.bar.text
      font.pixelSize: 11
      opacity: root.player && root.player.canGoNext ? 1 : 0.35
    }
    MouseArea {
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      property int pressModifiers: 0
      onPressed: function(mouse) { pressModifiers = mouse.modifiers }
      onClicked: {
        if (pressModifiers & Qt.ShiftModifier) root.raiseRequested()
        else root.nextRequested()
      }
    }
  }
}
