import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import qs.Commons
import qs.Ui

// Dynamic Island as a bar widget: compact black pill living right of the clock.
// Idle (no media, no notification) it collapses to zero width.
BarWidget {
  id: root
  moduleName: "sharifmdathar.dynamic-island"

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
    // A pinned player wins over the auto-selection while it reports a track.
    if (root.pinnedPlayer !== "") {
      for (var i = 0; i < players.length; i++) {
        var pp = players[i]
        if (pp && root.playerKey(pp) === root.pinnedPlayer && (pp.trackTitle || pp.trackArtist))
          return pp
      }
    }
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
  // ---------- options (persisted to the widget's shell.json layout entry) ----------
  // Label mode: "artistTitle", "title", "artistTitleAlbum", or "titleAlbum".
  // Older stored values ("full", "album", "titlealbum", titleOnly bool)
  // normalize to the new names on read.
  readonly property string labelMode: {
    var m = String(root.setting("labelMode", root.setting("titleOnly", false) ? "title" : "artistTitle"))
    if (m === "full") return "artistTitle"
    if (m === "album") return "artistTitleAlbum"
    if (m === "titlealbum") return "titleAlbum"
    return (m === "title" || m === "titleAlbum" || m === "artistTitleAlbum") ? m : "artistTitle"
  }
  readonly property bool hideWhenPaused: root.setting("hideWhenPaused", false)
  readonly property bool showEqualizer: root.setting("showEqualizer", true)
  readonly property bool showHoverControls: {
    var v = root.setting("showHoverControls", undefined)
    if (v === undefined || v === null) v = root.setting("hoverControls", true)
    return !!v
  }
  readonly property bool showNotifications: root.setting("showNotifications", true)
  readonly property string clickAction: root.setting("clickAction", "toggle")
  readonly property string pinnedPlayer: root.setting("pinnedPlayer", "")
  property bool menuOpen: false
  function setOption(key, value) {
    var entry = { id: root.moduleName }
    for (var k in root.settings) if (k !== "id") entry[k] = root.settings[k]
    entry[key] = value
    if ("titleOnly" in entry) delete entry["titleOnly"]
    if ("showHoverControls" in entry) delete entry["hoverControls"]
    // Applied locally first so the change lands on the click itself; the
    // shell.json write comes back through the bar as the same value.
    root.settings = entry
    if (root.bar && root.bar.shell && typeof root.bar.shell.updateEntryInline === "function")
      root.bar.shell.updateEntryInline(root.moduleName, entry)
  }
  // Compat shim for the first-generation menu: true/false maps to title/artistTitle.
  function setLegacyTitleOnly(v) {
    root.setOption("labelMode", v ? "title" : "artistTitle")
  }
  // Called by the popup card's outside-click dismissal.
  function close() {
    root.menuOpen = false
  }
  function menuAction(action) {
    var s = String(action || "")
    var i = s.indexOf("|")
    var kind = i < 0 ? s : s.slice(0, i)
    var arg = i < 0 ? "" : s.slice(i + 1)
    if (kind === "label") root.setOption("labelMode", arg)
    else if (kind === "click") root.setOption("clickAction", arg)
    else if (kind === "pin") root.setOption("pinnedPlayer", arg)
    else if (kind === "opt") {
      if (arg === "hideWhenPaused") root.setOption(arg, !root.hideWhenPaused)
      else if (arg === "showEqualizer") root.setOption(arg, !root.showEqualizer)
      else if (arg === "showHoverControls") root.setOption(arg, !root.showHoverControls)
      else if (arg === "showNotifications") root.setOption(arg, !root.showNotifications)
    }
    root.menuOpen = false
  }
  function playerLabel(p) {
    if (!p) return ""
    return String(p.identity || p.desktopEntry || p.dbusName || "")
  }
  readonly property string mediaText: {
    var t = mediaTitle || mediaArtist
    if (root.labelMode === "title")
      return t
    if (root.labelMode === "artistTitleAlbum") {
      var s = (mediaArtist && mediaTitle) ? mediaArtist + " - " + mediaTitle : t
      return mediaAlbum !== "" ? s + " · " + mediaAlbum : s
    }
    if (root.labelMode === "titleAlbum") {
      if (mediaTitle !== "")
        return mediaAlbum !== "" ? mediaTitle + " · " + mediaAlbum : mediaTitle
      return mediaArtist
    }
    if (mediaArtist && mediaTitle)
      return mediaArtist + " - " + mediaTitle
    return t
  }
  readonly property string mediaArt: activePlayer ? (activePlayer.trackArtUrl || "") : ""
  readonly property string mediaAlbum: activePlayer ? (activePlayer.trackAlbum || "") : ""
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
  readonly property bool hasNotif: notifSummary !== "" || notifBody !== ""
  readonly property bool showNotif: root.showNotifications && hasNotif
  readonly property bool showMedia: !showNotif && hasMedia && (!root.hideWhenPaused || isPlaying)
  readonly property bool active: showNotif || showMedia || root.menuOpen
  readonly property bool showEq: showMedia && isPlaying && root.showEqualizer

  // Hover transport controls (media only): label + EQ swap for buttons.
  property bool hovered: false
  property bool forceControls: false
  readonly property bool controlsVisible: root.showHoverControls && (root.hovered || root.forceControls) && root.showMedia && !root.vertical

  function doPrev() {
    if (root.activePlayer && root.activePlayer.canGoPrevious)
      root.activePlayer.previous()
  }
  // Left-click action: play/pause toggle, or raise the player window.
  function doLeftClick() {
    if (root.clickAction !== "raise") {
      root.togglePlayback()
      return
    }
    var p = root.activePlayer
    if (!p)
      return
    if (p.canRaise) {
      p.raise()
      return
    }
  }
  function togglePlayback() {
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
  readonly property int artW: 20
  readonly property int labelW: Math.min(root.controlsVisible ? 150 : 240, Math.max(40, Math.ceil(labelMetrics.advanceWidth)))
  readonly property int controlsW: 3 * 26 + 2 * 8
  readonly property int pillW: 14 + artW + 8 + labelW + (root.controlsVisible ? 8 + controlsW : (root.showEq ? 8 + 16 : 0)) + 14

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
        controlsVisible: root.controlsVisible,
        showNotif: root.showNotif,
        app: root.notifApp,
        summary: root.notifSummary,
        hasMedia: root.hasMedia,
        mediaText: root.mediaText,
        labelMode: root.labelMode,
        hideWhenPaused: root.hideWhenPaused,
        clickAction: root.clickAction,
        pinnedPlayer: root.pinnedPlayer
      })
    }
    function ping(): string {
      return "ok"
    }
    function setOption(key: string, value: string): string {
      var v = value
      if (value === "true") v = true
      else if (value === "false") v = false
      root.setOption(key, v)
      return "ok"
    }
    function controls(enable: string): string {
      root.forceControls = (enable === "true" || enable === "1")
      return root.controlsVisible ? "shown" : "hidden"
    }
  }

  // ---------- menu rows (shared delegates + row models) ----------
  readonly property var labelModeRows: [
    { label: "Title only",             checked: root.labelMode === "title",            action: "label|title" },
    { label: "Artist - Title",         checked: root.labelMode === "artistTitle",      action: "label|artistTitle" },
    { label: "Title · Album",          checked: root.labelMode === "titleAlbum",       action: "label|titleAlbum" },
    { label: "Artist - Title · Album", checked: root.labelMode === "artistTitleAlbum", action: "label|artistTitleAlbum" }
  ]
  readonly property var behaviorRows: [
    { label: "Equalizer animation", checked: root.showEqualizer, action: "opt|showEqualizer" },
    { label: "Hover controls", checked: root.showHoverControls, action: "opt|showHoverControls" },
    { label: "Show notifications", checked: root.showNotifications, action: "opt|showNotifications" },
    { label: "Hide when paused", checked: root.hideWhenPaused, action: "opt|hideWhenPaused" }
  ]
  readonly property var clickActionRows: [
    { label: "Play / pause", checked: root.clickAction !== "raise", action: "click|toggle" },
    { label: "Raise player", checked: root.clickAction === "raise", action: "click|raise" }
  ]
  readonly property var pinnedPlayerRows: [{ label: "Automatic", checked: root.pinnedPlayer === "", action: "pin|" }].concat(
    root.players.map(function(p) {
      var key = root.playerKey(p)
      return { label: root.playerLabel(p), checked: root.pinnedPlayer !== "" && root.pinnedPlayer === key, action: "pin|" + key }
    })
  )
  Component {
    id: menuHeader
    Text {
      text: modelData
      color: Color.bar.text
      opacity: 0.55
      font.family: Style.font.family
      font.pixelSize: 10
      font.weight: Font.Medium
    }
  }
  Component {
    id: menuDivider
    Rectangle {
      width: parent.width
      height: 1
      color: Color.bar.text
      opacity: 0.15
    }
  }
  Component {
    id: menuRow
    Item {
      width: parent.width
      height: 28
      // Selection chrome follows the house pattern (CursorSurface): hover
      // and selected fills derived from foreground + accent. bar.active is
      // the attention/urgent color (red on Nord) — wrong semantics here.
      Rectangle {
        anchors.fill: parent
        radius: 6
        color: rowMouse.containsMouse
          ? Style.hoverFillFor(Color.bar.text, Color.accent)
          : (modelData.checked ? Style.selectedFillFor(Color.bar.text, Color.accent) : "transparent")
      }
      // Label clip: fits the row; when the text overflows (e.g. the long
      // album row at fixed menu width) it marquee-scrolls on hover.
      Item {
        id: labelClip
        anchors.left: parent.left
        anchors.leftMargin: 12
        anchors.right: checkGlyph.left
        anchors.rightMargin: 8
        anchors.verticalCenter: parent.verticalCenter
        height: 18
        clip: true
        Text {
          id: rowLabel
          text: modelData.label
          color: Color.bar.text
          font.family: Style.font.family
          font.pixelSize: 12
        }
        SequentialAnimation {
          id: marquee
          loops: Animation.Infinite
          running: rowMouse.containsMouse && rowLabel.contentWidth > labelClip.width
          onRunningChanged: if (!running) rowLabel.x = 0
          PauseAnimation { duration: 600 }
          NumberAnimation {
            target: rowLabel
            property: "x"
            from: 0
            to: -(rowLabel.contentWidth - labelClip.width)
            duration: Math.max(800, (rowLabel.contentWidth - labelClip.width) * 15)
            easing.type: Easing.Linear
          }
          PauseAnimation { duration: 600 }
          NumberAnimation { target: rowLabel; property: "x"; to: 0; duration: 400 }
        }
      }
      Text {
        id: checkGlyph
        anchors.right: parent.right
        anchors.rightMargin: 12
        anchors.verticalCenter: parent.verticalCenter
        text: "✓"
        color: Color.accent
        font.pixelSize: 12
        visible: modelData.checked
      }
      MouseArea {
        id: rowMouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.menuAction(modelData.action)
      }
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
        root.doLeftClick()
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
        width: root.artW
        height: root.artW
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
        visible: root.showEq && !root.controlsVisible
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
        visible: root.controlsVisible
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
            onClicked: root.togglePlayback()
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

  // ---------- options menu (right click) ----------
  PopupCard {
    id: labelMenu
    anchorItem: root
    bar: root.bar
    owner: root
    open: root.menuOpen && root.showMedia && !root.vertical
    contentWidth: labelMenu.fittedContentWidth(Style.space(240))
    contentHeight: labelMenu.fittedContentHeight(menuColumn.implicitHeight)

    Column {
      id: menuColumn
      anchors.fill: parent
      spacing: 2

      Repeater { model: ["Label"]; delegate: menuHeader }
      Repeater { model: root.labelModeRows; delegate: menuRow }

      Repeater { model: [0]; delegate: menuDivider }

      Repeater { model: ["Behavior"]; delegate: menuHeader }
      Repeater { model: root.behaviorRows; delegate: menuRow }

      Repeater { model: [0]; delegate: menuDivider }

      Repeater { model: ["Left click"]; delegate: menuHeader }
      Repeater { model: root.clickActionRows; delegate: menuRow }

      Repeater { model: [0]; delegate: menuDivider }

      Repeater { model: ["Player"]; delegate: menuHeader }
      Repeater { model: root.pinnedPlayerRows; delegate: menuRow }
    }
  }
}
