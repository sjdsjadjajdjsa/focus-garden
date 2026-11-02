import QtQuick
import qs.Commons
import qs.Commons as Commons

// The last seven days as a row of seedlings: the more you focused that day,
// the taller it grew. A day with an hour or more gets a flower.
Column {
  id: ws
  property var g
  width: parent ? parent.width : 240
  spacing: 6

  readonly property var days: {
    var out = [], hist = g.history || {}
    var elapsed = g.focusing ? Math.floor((g.now - g.focusStartedAt) / 60000) : 0
    for (var i = 6; i >= 0; i--) {
      var d = new Date(g.clock - i * 86400000)
      var key = Qt.formatDate(d, "yyyy-MM-dd")
      var mins = i === 0 ? (g.statsDay === key ? g.todayFocus : 0) + elapsed : Number(hist[key]) || 0
      out.push({ key: key, letter: Qt.formatDate(d, "ddd").charAt(0), mins: mins, today: i === 0 })
    }
    return out
  }
  readonly property real most: Math.max(30, Math.max.apply(null, days.map(function(d) { return d.mins })))

  MeterHeader {
    g: ws.g; icon: "sprout"; iconColor: g.mix(g.pal.leaf, "#ffffff", 0.15)
    label: "This week"
    detail: g.hm(g.todayActive) + " on screen today"
  }

  Row {
    width: ws.width
    Repeater {
      model: ws.days
      Item {
        id: day
        required property var modelData
        width: ws.width / 7
        height: 44
        readonly property real h: modelData.mins > 0 ? 6 + 22 * modelData.mins / ws.most : 0
        readonly property color stemColor: modelData.today ? g.mix(g.pal.stem, g.accent, 0.4) : g.pal.stem
        readonly property color leafColor: modelData.today ? g.mix(g.pal.leaf, g.accent, 0.35) : g.pal.leaf

        Rectangle {                                 // a little mound of soil
          anchors.horizontalCenter: parent.horizontalCenter
          y: 31; width: 16; height: 4; radius: 2
          color: g.alpha(g.mix(g.pal.soil, Commons.Color.popups.text, 0.15), 0.9)
        }
        Rectangle {                                 // the stem
          visible: day.h > 0
          anchors.horizontalCenter: parent.horizontalCenter
          y: 32 - day.h; width: 2; height: day.h; radius: 1
          color: day.stemColor
        }
        Rectangle {                                 // two leaves
          visible: day.h > 0
          x: parent.width / 2 - 8; y: 32 - day.h * 0.55
          width: 7; height: 4; radius: 2; rotation: -28
          color: day.leafColor
        }
        Rectangle {
          visible: day.h > 0
          x: parent.width / 2 + 1; y: 32 - day.h * 0.75
          width: 7; height: 4; radius: 2; rotation: 28
          color: day.leafColor
        }
        Rectangle {                                 // a flower for an hour or more
          visible: day.modelData.mins >= 60
          anchors.horizontalCenter: parent.horizontalCenter
          y: 32 - day.h - 3; width: 7; height: 7; radius: 3.5
          color: g.accent
          border.width: 1.5
          border.color: g.mix(g.accent, "#ffffff", 0.5)
        }
        Text {
          textFormat: Text.PlainText
          anchors.horizontalCenter: parent.horizontalCenter
          y: 36
          text: day.modelData.letter
          color: day.modelData.today ? g.accent : g.alpha(Commons.Color.popups.text, 0.4)
          font.family: Style.font.family; font.pixelSize: 9; font.bold: day.modelData.today
        }
      }
    }
  }
}
