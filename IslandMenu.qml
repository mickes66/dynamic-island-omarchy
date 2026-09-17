import QtQuick
import qs.Commons
import qs.Ui
import "IslandModel.js" as Model

// Right-click options menu. Owns row models, delegates, and the label
// marquee; the island owns settings state and only receives action strings
// back through actionRequested.
PopupCard {
  id: menu

  property string labelMode: "artistTitle"
  property bool hideWhenPaused: false
  property bool showEqualizer: true
  property bool showHoverControls: true
  property bool showNotifications: true
  property string pinnedPlayer: ""
  property var players: []

  // Now-playing info for the header.
  property string mediaTitle: ""
  property string mediaArtist: ""
  property string mediaAlbum: ""
  property string mediaArt: ""
  property string playerName: ""

  // Settings sections start collapsed; the header expands them.
  property bool settingsExpanded: false
  onOpenChanged: if (!open) settingsExpanded = false

  signal actionRequested(string action)

  contentWidth: menu.fittedContentWidth(Style.space(240))
  contentHeight: menu.fittedContentHeight(menuColumn.implicitHeight)

  readonly property var labelModeRows: [
    { label: "Title only",             checked: menu.labelMode === "title",            action: "label|title" },
    { label: "Artist - Title",         checked: menu.labelMode === "artistTitle",      action: "label|artistTitle" },
    { label: "Title · Album",          checked: menu.labelMode === "titleAlbum",       action: "label|titleAlbum" },
    { label: "Artist - Title · Album", checked: menu.labelMode === "artistTitleAlbum", action: "label|artistTitleAlbum" }
  ]
  readonly property var behaviorRows: [
    { label: "Equalizer animation", checked: menu.showEqualizer, action: "opt|showEqualizer" },
    { label: "Hover controls", checked: menu.showHoverControls, action: "opt|showHoverControls" },
    { label: "Show notifications", checked: menu.showNotifications, action: "opt|showNotifications" },
    { label: "Hide when paused", checked: menu.hideWhenPaused, action: "opt|hideWhenPaused" }
  ]
  readonly property var pinnedPlayerRows: [{ label: "Automatic", checked: menu.pinnedPlayer === "", action: "pin|" }].concat(
    menu.players.map(function(p) {
      var key = Model.playerKey(p)
      return { label: Model.playerLabel(p), checked: menu.pinnedPlayer !== "" && menu.pinnedPlayer === key, action: "pin|" + key }
    })
  )

  property Component menuHeader: Text {
    text: modelData
    color: Color.bar.text
    opacity: 0.55
    font.family: Style.font.family
    font.pixelSize: 10
    font.weight: Font.Medium
  }
  property Component menuDivider: Rectangle {
    width: parent.width
    height: 1
    color: Color.bar.text
    opacity: 0.15
  }
  property Component menuRow: Item {
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
        onClicked: menu.actionRequested(modelData.action)
      }
    }

  Column {
    id: menuColumn
    anchors.fill: parent
    spacing: 2

    // Now-playing header: large artwork with title / artist / album on
    // separate lines. Clicking anywhere on it expands the settings below.
    Item {
      width: parent.width
      height: 68
      Rectangle {
        anchors.fill: parent
        radius: 6
        color: Style.hoverFillFor(Color.bar.text, Color.accent)
        opacity: headerMouse.containsMouse ? 1 : 0
      }
      // Big artwork tile.
      Item {
        anchors.left: parent.left
        anchors.leftMargin: 8
        anchors.verticalCenter: parent.verticalCenter
        width: 52
        height: 52
        Rectangle {
          anchors.fill: parent
          radius: 8
          color: Color.bar.background
          visible: menu.mediaArt === ""
        }
        Text {
          anchors.centerIn: parent
          text: "♪"
          color: Color.bar.text
          font.pixelSize: 20
          visible: menu.mediaArt === ""
        }
        Image {
          anchors.fill: parent
          source: menu.mediaArt
          fillMode: Image.PreserveAspectCrop
          asynchronous: true
          sourceSize: Qt.size(104, 104)
          visible: menu.mediaArt !== ""
        }
      }
      Column {
        anchors.left: parent.left
        anchors.leftMargin: 68
        anchors.right: parent.right
        anchors.rightMargin: 12
        anchors.verticalCenter: parent.verticalCenter
        spacing: 2
        Text {
          width: parent.width
          text: menu.mediaTitle !== "" ? menu.mediaTitle : menu.mediaArtist
          color: Color.bar.text
          font.family: Style.font.family
          font.pixelSize: 13
          font.weight: Font.Medium
          textFormat: Text.PlainText
          elide: Text.ElideRight
          maximumLineCount: 1
        }
        Text {
          width: parent.width
          text: (menu.mediaTitle !== "" && menu.mediaArtist !== "")
            ? menu.mediaArtist : menu.playerName
          color: Color.bar.text
          opacity: 0.75
          font.family: Style.font.family
          font.pixelSize: 12
          textFormat: Text.PlainText
          elide: Text.ElideRight
          maximumLineCount: 1
          visible: text !== ""
        }
        Text {
          width: parent.width
          text: menu.mediaAlbum
          color: Color.bar.text
          opacity: 0.6
          font.family: Style.font.family
          textFormat: Text.PlainText
          font.pixelSize: 11
          elide: Text.ElideRight
          maximumLineCount: 1
          visible: menu.mediaAlbum !== ""
        }
      }
      MouseArea {
        id: headerMouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: menu.settingsExpanded = !menu.settingsExpanded
      }
    }

    // Explicit Settings button; expands/collapses the sections below.
    Item {
      width: parent.width
      height: 30
      Rectangle {
        anchors.fill: parent
        radius: 6
        color: Style.hoverFillFor(Color.bar.text, Color.accent)
        opacity: settingsMouse.containsMouse ? 1 : 0
      }
      Text {
        anchors.left: parent.left
        anchors.leftMargin: 12
        anchors.verticalCenter: parent.verticalCenter
        text: "⚙  Settings"
        color: Color.bar.text
        font.family: Style.font.family
        font.pixelSize: 12
        font.weight: Font.Medium
      }
      Text {
        anchors.right: parent.right
        anchors.rightMargin: 12
        anchors.verticalCenter: parent.verticalCenter
        text: menu.settingsExpanded ? "▾" : "▸"
        color: Color.bar.text
        opacity: 0.6
        font.pixelSize: 11
      }
      MouseArea {
        id: settingsMouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: menu.settingsExpanded = !menu.settingsExpanded
      }
    }

    Rectangle {
      width: parent.width
      height: 1
      color: Color.bar.text
      opacity: 0.15
    }

    Column {
      width: parent.width
      spacing: 2
      visible: menu.settingsExpanded

      Repeater { model: ["Label"]; delegate: menuHeader }
      Repeater { model: menu.labelModeRows; delegate: menuRow }

      Repeater { model: [0]; delegate: menuDivider }

      Repeater { model: ["Behavior"]; delegate: menuHeader }
      Repeater { model: menu.behaviorRows; delegate: menuRow }

      Repeater { model: [0]; delegate: menuDivider }

      Repeater { model: ["Player"]; delegate: menuHeader }
      Repeater { model: menu.pinnedPlayerRows; delegate: menuRow }
    }
  }
}
