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
    var first = null
    for (var i = 0; i < players.length; i++) {
      var p = players[i]
      if (!p || !p.isPlaying)
        continue
      if (!first)
        first = p
      if (root.lastKey !== "" && root.playerKey(p) === root.lastKey)
        return p
    }
    return first
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
  // Label mode: full "artist — title" or title only. Persisted to the
  // widget's shell.json layout entry so it survives restarts.
  readonly property bool titleOnly: root.setting("titleOnly", false)
  property bool menuOpen: false
  function setTitleOnly(v) {
    var entry = { id: root.moduleName }
    for (var key in root.settings) if (key !== "id") entry[key] = root.settings[key]
    entry["titleOnly"] = !!v
    // Applied locally first so the label changes on the click itself; the
    // shell.json write comes back through the bar as the same value.
    root.settings = entry
    if (root.bar && root.bar.shell && typeof root.bar.shell.updateEntryInline === "function")
      root.bar.shell.updateEntryInline(root.moduleName, entry)
  }
  // Called by the popup card's outside-click dismissal.
  function close() {
    root.menuOpen = false
  }
  readonly property string mediaText: {
    if (root.titleOnly)
      return mediaTitle || mediaArtist
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
      var b = String(d.body || "")
        .replace(/<br\s*\/?>/gi, " ")
        .replace(/<[^>]*>/g, "")
        .replace(/&amp;/g, "&").replace(/&lt;/g, "<").replace(/&gt;/g, ">")
        .replace(/&quot;/g, "\"").replace(/&#39;/g, "'").replace(/&apos;/g, "'")
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
  readonly property int labelW: Math.min(root.showControls ? 150 : 240, Math.max(40, Math.ceil(labelMetrics.advanceWidth)))
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
        showControls: root.showControls,
        showNotif: root.showNotif,
        app: root.notifApp,
        summary: root.notifSummary,
        hasMedia: root.hasMedia,
        mediaText: root.mediaText,
        titleOnly: root.titleOnly
      })
    }
    function ping(): string {
      return "ok"
    }
    function controls(enable: string): string {
      root.forceControls = (enable === "true" || enable === "1")
      return root.showControls ? "shown" : "hidden"
    }
  }

  // ---------- pill ----------
  Rectangle {
    anchors.fill: parent
    anchors.topMargin: 4
    anchors.bottomMargin: 4
    radius: height / 2
    color: Color.bar.background
    border.color: Qt.rgba(1, 1, 1, 0.12)
    border.width: 1
    visible: root.active

    // Hover detection for the transport controls (bottom of stack; buttons sit above).
    // Left click anywhere else on the pill toggles play/pause; right click
    // opens the label-mode menu.
    MouseArea {
      anchors.fill: parent
      acceptedButtons: Qt.LeftButton | Qt.RightButton
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      enabled: root.showMedia && !root.vertical
      onClicked: function(mouse) {
        if (mouse.button === Qt.RightButton) {
          root.menuOpen = !root.menuOpen
          return
        }
        root.doToggle()
      }
      onEnabledChanged: {
        if (!enabled) {
          hoverExitGrace.stop()
          root.hovered = false
        }
      }
      onEntered: {
        hoverExitGrace.stop()
        root.hovered = true
      }
      onExited: {
        hoverExitGrace.restart()
      }
    }

    // Vertical bars: artwork dot only — the pill is one slot wide.
    Item {
      anchors.centerIn: parent
      width: 18
      height: 18
      visible: root.vertical && root.active
      Rectangle {
        anchors.fill: parent
        radius: 9
        color: root.showNotif ? Color.bar.active : Color.bar.background
        visible: root.showNotif || root.mediaArt === ""
      }
      Image {
        anchors.fill: parent
        source: root.mediaArt
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        sourceSize: Qt.size(36, 36)
        visible: !root.showNotif && root.mediaArt !== ""
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
          color: root.showNotif ? Color.bar.active : Color.bar.background
          visible: root.showNotif || root.mediaArt === ""
        }
        Text {
          anchors.centerIn: parent
          text: "♪"
          color: Color.bar.text
          font.pixelSize: 11
          visible: !root.showNotif && root.mediaArt === ""
        }
        Image {
          anchors.fill: parent
          source: root.mediaArt
          fillMode: Image.PreserveAspectCrop
          asynchronous: true
          sourceSize: Qt.size(40, 40)
          visible: !root.showNotif && root.mediaArt !== ""
        }
      }

      Text {
        width: root.labelW
        anchors.verticalCenter: parent.verticalCenter
        text: root.labelText
        color: Color.bar.text
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
            color: Color.bar.active
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
            color: Color.bar.text
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
            color: Color.bar.text
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
            color: Color.bar.text
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

  // ---------- label-mode menu (right click) ----------
  PopupCard {
    id: labelMenu
    anchorItem: root
    bar: root.bar
    owner: root
    open: root.menuOpen && root.showMedia && !root.vertical
    contentWidth: labelMenu.fittedContentWidth(Style.space(220))
    contentHeight: labelMenu.fittedContentHeight(menuColumn.implicitHeight)

    Column {
      id: menuColumn
      anchors.fill: parent
      spacing: 2

      Item {
        width: parent.width
        height: 28
        Rectangle {
          anchors.fill: parent
          radius: 6
          color: Color.bar.active
          opacity: fullMouse.containsMouse ? 0.30 : (!root.titleOnly ? 0.15 : 0)
        }
        Text {
          anchors.left: parent.left
          anchors.leftMargin: 12
          anchors.verticalCenter: parent.verticalCenter
          text: "Artist — Title"
          color: Color.bar.text
          font.family: Style.font.family
          font.pixelSize: 12
        }
        Text {
          anchors.right: parent.right
          anchors.rightMargin: 12
          anchors.verticalCenter: parent.verticalCenter
          text: "✓"
          color: Color.bar.active
          font.pixelSize: 12
          visible: !root.titleOnly
        }
        MouseArea {
          id: fullMouse
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: {
            root.setTitleOnly(false)
            root.menuOpen = false
          }
        }
      }

      Item {
        width: parent.width
        height: 28
        Rectangle {
          anchors.fill: parent
          radius: 6
          color: Color.bar.active
          opacity: titleMouse.containsMouse ? 0.30 : (root.titleOnly ? 0.15 : 0)
        }
        Text {
          anchors.left: parent.left
          anchors.leftMargin: 12
          anchors.verticalCenter: parent.verticalCenter
          text: "Title only"
          color: Color.bar.text
          font.family: Style.font.family
          font.pixelSize: 12
        }
        Text {
          anchors.right: parent.right
          anchors.rightMargin: 12
          anchors.verticalCenter: parent.verticalCenter
          text: "✓"
          color: Color.bar.active
          font.pixelSize: 12
          visible: root.titleOnly
        }
        MouseArea {
          id: titleMouse
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: {
            root.setTitleOnly(true)
            root.menuOpen = false
          }
        }
      }
    }
  }
}
