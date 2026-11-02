import QtQuick
import QtQuick.Shapes
import qs.Commons
import qs.Commons as Commons

// Water as a glass tube: the water's edge ripples gently and drains as your
// plant gets thirsty.
Column {
  id: wm
  property var g
  property real value: 0            // 0..1
  property bool live: false
  property real phase: 0
  width: parent ? parent.width : 240
  spacing: 6

  readonly property color blue: g.water < 20 ? "#d9a35b" : "#5aaee8"
  Timer { interval: 60; running: wm.live && wm.value > 0.02; repeat: true; onTriggered: wm.phase += 0.12 }

  MeterHeader { g: wm.g; icon: "droplet"; iconColor: Qt.lighter(wm.blue, 1.2); label: "Water"
                detail: g.water < 45 && !g.breakDue && !g.focusing ? g.thirst + " · take a break" : g.thirst }

  Item {
    id: tube
    width: wm.width
    height: 12
    property real fillW: Math.max(0, Math.min(1, wm.value)) * (width - 4)
    Behavior on fillW { NumberAnimation { duration: 600; easing.type: Easing.OutCubic } }

    Rectangle {                                     // the glass
      anchors.fill: parent
      radius: 6
      color: g.alpha(Commons.Color.popups.text, 0.06)
      border.width: 1
      border.color: g.alpha(Commons.Color.popups.text, 0.1)
    }
    Shape {                                         // the water, with a rippling edge
      x: 1; y: 1
      width: tube.width - 2; height: 10
      visible: tube.fillW > 6
      preferredRendererType: Shape.CurveRenderer
      ShapePath {
        strokeColor: "transparent"
        fillGradient: LinearGradient {
          x1: 0; y1: 0; x2: tube.width; y2: 0
          GradientStop { position: 0; color: Qt.darker(wm.blue, 1.15) }
          GradientStop { position: 1; color: Qt.lighter(wm.blue, 1.35) }
        }
        PathSvg {
          path: {
            var w = tube.fillW, h = 10, r = 5, a = 1.3, p = wm.phase
            var s = "M " + r + " 0 L " + (w + a * Math.sin(p)).toFixed(2) + " 0"
            for (var i = 1; i <= 6; i++)
              s += " L " + (w + a * Math.sin(p + i * 1.1)).toFixed(2) + " " + (h * i / 6).toFixed(2)
            return s + " L " + r + " " + h + " A " + r + " " + r + " 0 0 1 " + r + " 0 Z"
          }
        }
      }
    }
    Rectangle {                                     // shine on the glass
      x: 5; y: 3
      width: Math.max(0, tube.fillW - 10); height: 1.5; radius: 0.75
      color: g.alpha("#ffffff", 0.4)
      visible: width > 2
    }
  }
}
