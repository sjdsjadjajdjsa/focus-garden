import QtQuick
import qs.Commons
import qs.Commons as Commons

// Icon + label on the left, a detail on the right.
Item {
  id: mh
  property var g
  property string icon
  property color iconColor
  property string label
  property string detail
  width: parent ? parent.width : 240
  height: 16

  Icon {
    id: ic
    anchors.verticalCenter: parent.verticalCenter
    name: mh.icon
    size: 13
    color: mh.iconColor
  }
  Text {
    textFormat: Text.PlainText
    anchors { left: ic.right; leftMargin: 6; verticalCenter: parent.verticalCenter }
    text: mh.label
    color: g.alpha(Commons.Color.popups.text, 0.85)
    font.family: Style.font.family; font.pixelSize: 11; font.bold: true
  }
  Text {
    textFormat: Text.PlainText
    anchors { right: parent.right; verticalCenter: parent.verticalCenter }
    text: mh.detail
    color: g.alpha(Commons.Color.popups.text, 0.5)
    font.family: Style.font.family; font.pixelSize: 10
  }
}
