import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import qs.Commons
import qs.Ui

// Dynamic Island as a bar widget: compact black pill living left of the clock.
// Idle (no media, no notification) it collapses to zero width.
BarWidget {
  id: root
  moduleName: "doormat.dynamic-island"

  // ---------- media (MPRIS direct; multiple readers are fine) ----------
  readonly property var players: Mpris.players ? Mpris.players.values : []
  function playerKey(p) {
    if (!p)
      return ""
    return String(p.dbusName || p.desktopEntry || p.identity || "")
  }
  // Whoever played last wins: pausing Spotify must keep Spotify, not jump
  // to some older paused player that happens to sort first.
  readonly property var playingPlayer: {
    for (var i = 0; i < players.length; i++) {
      var p = players[i]
      if (p && p.isPlaying)
        return p
    }
    return null
  }
  property string lastKey: ""
  onPlayingPlayerChanged: {
    if (root.playingPlayer)
      root.lastKey = root.playerKey(root.playingPlayer)
  }
  readonly property var activePlayer: {
    if (root.playingPlayer)
      return root.playingPlayer
    if (root.lastKey !== "") {
      for (var i = 0; i < players.length; i++) {
        var p = players[i]
        if (p && root.playerKey(p) === root.lastKey && (p.trackTitle || p.trackArtist))
          return p
      }
    }
    var fallback = null
    for (var j = 0; j < players.length; j++) {
      var q = players[j]
      if (!q)
        continue
      if (!fallback && (q.trackTitle || q.trackArtist))
        fallback = q
    }
    return fallback
  }
  readonly property bool hasMedia: activePlayer !== null && !!((activePlayer.trackTitle || activePlayer.trackArtist))
  readonly property string mediaTitle: activePlayer ? (activePlayer.trackTitle || "") : ""
  readonly property string mediaArtist: activePlayer ? (activePlayer.trackArtist || "") : ""
  readonly property string mediaText: {
    if (mediaArtist && mediaTitle)
      return mediaArtist + " — " + mediaTitle
    return mediaTitle || mediaArtist
  }
  readonly property string mediaArt: activePlayer ? (activePlayer.trackArtUrl || "") : ""
  readonly property bool isPlaying: activePlayer ? !!activePlayer.isPlaying : false

  // ---------- notifications (mirror of the daemon's live popup files) ----------
  readonly property string notifDir: Quickshell.env("HOME") + "/.local/state/omarchy/notifications/"
  property string notifApp: ""
  property string notifSummary: ""
  property string notifBody: ""

  function clearNotif() {
    notifApp = ""
    notifSummary = ""
    notifBody = ""
  }

  function handlePoll(output) {
    var t = String(output || "").trim()
    if (t === "") {
      clearNotif()
      return
    }
    parseNotif(t)
  }

  function parseNotif(raw) {
    try {
      var d = JSON.parse(raw || "{}")
      var s = String(d.summary || "")
      var b = String(d.body || "").replace(/<[^>]*>/g, "")
      if (s === "" && b === "") {
        clearNotif()
        return
      }
      notifApp = String(d.app || "")
      notifSummary = s
      notifBody = b
    } catch (e) {
      clearNotif()
    }
  }

  property int tickCount: 0
  Timer {
    interval: 800
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: {
      root.tickCount++
      if (!pollProc.running)
        pollProc.running = true
    }
  }

  // Grace keeps controls visible briefly after the cursor leaves, so a
  // width change under the cursor can't start an enter/exit loop.
  Timer {
    id: hoverExitGrace
    interval: 350
    onTriggered: root.hovered = false
  }

  Process {
    id: pollProc
    command: ["sh", "-c", "f=$(ls -t \"" + root.notifDir + "\"*.json 2>/dev/null | head -n 1); if [ -n \"$f\" ] && [ -f \"$f\" ]; then cat \"$f\"; fi"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.handlePoll(text)
    }
  }

  // ---------- state ----------
  readonly property bool showNotif: notifSummary !== "" || notifBody !== ""
  readonly property bool showMedia: !showNotif && hasMedia
  readonly property bool active: showNotif || showMedia
  readonly property bool showEq: showMedia && isPlaying

  // Hover transport controls (media only): label + EQ swap for buttons.
  property bool hovered: false
  property bool everHovered: false
  property var hoverLog: []
  function logHover(e) {
    var l = root.hoverLog.slice(-11)
    l.push(e + "@" + String(Math.floor(Date.now() / 100) % 100000) + "w" + String(Math.round(root.pillW)))
    root.hoverLog = l
  }
  property bool forceControls: false
  readonly property bool showControls: (root.hovered || root.forceControls) && root.showMedia && !root.vertical

  function doPrev() {
    if (root.activePlayer && root.activePlayer.canGoPrevious)
      root.activePlayer.previous()
  }
  function doToggle() {
    var p = root.activePlayer
    if (!p)
      return
    if (p.isPlaying) {
      if (p.canPause)
        p.pause()
    } else if (p.canPlay) {
      p.play()
    }
  }
  function doNext() {
    if (root.activePlayer && root.activePlayer.canGoNext)
      root.activePlayer.next()
  }
  readonly property string labelText: showNotif
    ? ((notifApp !== "" ? notifApp + " · " : "") + (notifSummary !== "" ? notifSummary : notifBody))
    : mediaText
  readonly property string tooltipText: showNotif
    ? (notifSummary !== "" && notifBody !== "" ? notifSummary + "\n" + notifBody : labelText)
    : (mediaText + (isPlaying ? "\nNow Playing" : "\nPaused"))

  // ---------- sizing ----------
  TextMetrics {
    id: labelMetrics
    font.family: Style.font.family
    font.pixelSize: 12
    font.weight: Font.Medium
    text: root.labelText
  }
  readonly property int artBox: 20
  readonly property int labelW: Math.min(240, Math.max(40, Math.ceil(labelMetrics.advanceWidth)))
  readonly property int controlsW: 3 * 26 + 2 * 8
  readonly property int pillW: 14 + artBox + 8 + labelW + (root.showControls ? 8 + controlsW : (root.showEq ? 8 + 16 : 0)) + 14

  visible: root.active
  implicitWidth: root.active ? (vertical ? barSize : pillW) : 0
  implicitHeight: barSize

  Behavior on implicitWidth {
    NumberAnimation {
      duration: 180
      easing.type: Easing.OutCubic
    }
  }

  // ---------- equalizer ----------
  property int eqPhase: 0
  Timer {
    interval: 380
    running: root.showEq && !root.vertical
    repeat: true
    onTriggered: root.eqPhase = (root.eqPhase + 1) % 4
  }
  function eqHeight(i) {
    var frames = [[4, 9, 6], [8, 5, 10], [10, 8, 4], [6, 10, 7]]
    return frames[root.eqPhase % 4][i % 3]
  }

  // ---------- diagnostics ----------
  IpcHandler {
    target: "island"
    function state(): string {
      return JSON.stringify({
        active: root.active,
        ticks: root.tickCount,
        hovered: root.hovered,
        everHovered: root.everHovered,
        hoverLog: root.hoverLog,
        showControls: root.showControls,
        showNotif: root.showNotif,
        app: root.notifApp,
        summary: root.notifSummary,
        hasMedia: root.hasMedia,
        mediaText: root.mediaText
      })
    }
    function ping(): string {
      return "ok"
    }
    function controls(on: string): string {
      root.forceControls = (on === "true" || on === "1")
      return root.showControls ? "shown" : "hidden"
    }
  }

  // ---------- pill ----------
  Rectangle {
    anchors.fill: parent
    anchors.topMargin: 4
    anchors.bottomMargin: 4
    radius: height / 2
    color: "#000000"
    border.color: Qt.rgba(1, 1, 1, 0.12)
    border.width: 1
    visible: root.active

    // Hover detection for the transport controls (bottom of stack; buttons sit above).
    // A plain click anywhere else on the pill toggles play/pause.
    MouseArea {
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      enabled: root.showMedia && !root.vertical
      onClicked: root.doToggle()
      onEnabledChanged: {
        if (!enabled) {
          hoverExitGrace.stop()
          root.hovered = false
        }
      }
      onEntered: {
        hoverExitGrace.stop()
        root.hovered = true
        root.everHovered = true
        root.logHover("E")
      }
      onExited: {
        root.logHover("X")
        hoverExitGrace.restart()
      }
    }

    Row {
      anchors.fill: parent
      anchors.leftMargin: 14
      anchors.rightMargin: 14
      spacing: 8
      visible: !root.vertical
      anchors.verticalCenter: parent.verticalCenter

      // Album art / note glyph, or green dot for notifications.
      Item {
        width: root.artBox
        height: root.artBox
        anchors.verticalCenter: parent.verticalCenter
        Rectangle {
          anchors.fill: parent
          radius: root.showNotif ? 4 : 10
          color: root.showNotif ? "#30d158" : "#1c1c22"
          visible: root.showNotif || root.mediaArt === ""
        }
        Text {
          anchors.centerIn: parent
          text: "♪"
          color: "white"
          font.pixelSize: 11
          visible: !root.showNotif && root.mediaArt === ""
        }
        Image {
          anchors.fill: parent
          source: root.mediaArt
          fillMode: Image.PreserveAspectCrop
          visible: !root.showNotif && root.mediaArt !== ""
        }
      }

      Text {
        width: root.labelW
        anchors.verticalCenter: parent.verticalCenter
        text: root.labelText
        color: "white"
        font.family: labelMetrics.font.family
        font.pixelSize: 12
        font.weight: Font.Medium
        elide: Text.ElideRight
        maximumLineCount: 1
      }

      Row {
        spacing: 2
        anchors.verticalCenter: parent.verticalCenter
        visible: root.showEq && !root.showControls
        Repeater {
          model: 3
          Rectangle {
            required property int index
            width: 3
            height: root.eqHeight(index)
            radius: 1.5
            color: "#30d158"
            Behavior on height {
              NumberAnimation {
                duration: 300
              }
            }
          }
        }
      }

      // Hover transport controls (media only).
      Row {
        spacing: 8
        visible: root.showControls
        anchors.verticalCenter: parent.verticalCenter

        Item {
          width: 26
          height: 20
          anchors.verticalCenter: parent.verticalCenter
          Text {
            anchors.centerIn: parent
            text: "◀◀"
            color: "white"
            font.pixelSize: 11
            opacity: root.activePlayer && root.activePlayer.canGoPrevious ? 1 : 0.35
          }
          MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.doPrev()
          }
        }

        Item {
          width: 26
          height: 20
          anchors.verticalCenter: parent.verticalCenter
          Text {
            anchors.centerIn: parent
            text: root.isPlaying ? "❚❚" : "▶"
            color: "white"
            font.pixelSize: 13
            opacity: (root.isPlaying && root.activePlayer && !root.activePlayer.canPause
              || !root.isPlaying && root.activePlayer && !root.activePlayer.canPlay) ? 0.35 : 1
          }
          MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.doToggle()
          }
        }

        Item {
          width: 26
          height: 20
          anchors.verticalCenter: parent.verticalCenter
          Text {
            anchors.centerIn: parent
            text: "▶▶"
            color: "white"
            font.pixelSize: 11
            opacity: root.activePlayer && root.activePlayer.canGoNext ? 1 : 0.35
          }
          MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.doNext()
          }
        }
      }
    }
  }
}
