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
