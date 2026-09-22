import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons

// EQ bars shown while media plays, driven by cava's live PipeWire levels
// (same technique as micke.cava) rather than a canned animation.
Row {
  id: root
  property bool playing: false
  spacing: 2

  readonly property int barCount: 12
  readonly property int maxLevel: 100
  readonly property int maxBarHeight: 12
  property var levels: []

  readonly property string configPath: Quickshell.env("HOME") + "/.config/omarchy/plugins/sharifmdathar.dynamic-island/island-cava.conf"

  Process {
    running: root.playing
    command: ["cava", "-p", root.configPath]
    stdout: SplitParser {
      onRead: function (line) {
        var parts = line.split(";")
        var values = []
        for (var i = 0; i < parts.length; i++) {
          var n = parseInt(parts[i], 10)
          if (!isNaN(n)) values.push(n)
        }
        if (values.length > 0) root.levels = values
      }
    }
    onRunningChanged: if (!running) root.levels = []
  }

  Repeater {
    model: root.barCount
    Rectangle {
      required property int index
      readonly property real level: index < root.levels.length ? root.levels[index] : 0
      anchors.bottom: parent.bottom
      width: 3
      height: Math.max(2, (level / root.maxLevel) * root.maxBarHeight)
      radius: 1.5
      color: Color.bar.active
      Behavior on height {
        NumberAnimation {
          duration: 80
        }
      }
    }
  }
}
