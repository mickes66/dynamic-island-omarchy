import QtQuick
import qs.Commons

// Animated EQ bars shown while media plays. Owns its phase timer so the
// pill stays declarative; the island only flips `playing`.
Row {
  id: root
  property bool playing: false
  spacing: 2

  property int eqPhase: 0
  Timer {
    interval: 380
    running: root.playing
    repeat: true
    onTriggered: root.eqPhase = (root.eqPhase + 1) % 4
  }
  function eqHeight(i) {
    var frames = [[4, 9, 6], [8, 5, 10], [10, 8, 4], [6, 10, 7]]
    return frames[root.eqPhase % 4][i % 3]
  }

  Repeater {
    model: 3
    Rectangle {
      required property int index
      width: 3
      height: root.eqHeight(index)
      radius: 1.5
      color: Color.bar.active
      Behavior on height {
        NumberAnimation {
          duration: 300
        }
      }
    }
  }
}
