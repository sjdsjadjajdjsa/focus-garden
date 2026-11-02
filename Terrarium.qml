import QtQuick
import QtQuick.Shapes
import "Species.js" as Species
import qs.Commons
import qs.Commons as Commons

// The top of the card: a little glass terrarium with your plant inside. The
// sky follows the real time of day (dawn, blue day, golden hour, dusk, a
// starry night with fireflies), and during a focus session a sun travels
// across the glass as the minutes go by.
Item {
  id: t
  property var g                      // the garden (Garden.qml's root)
  property bool live: false           // animate only while the card is open
  property real phase: 0
  height: 172

  readonly property real radius: 18
  readonly property real groundY: height - 30

  // ------------------------------------------------------------- the sky
  readonly property real hour: {
    if (g.previewHour >= 0) return g.previewHour
    var d = new Date(g.clock); return d.getHours() + d.getMinutes() / 60
  }
  readonly property real nightness: hour < 5 ? 1 : hour < 7 ? 1 - (hour - 5) / 2
    : hour < 19.5 ? 0 : hour < 21 ? (hour - 19.5) / 1.5 : 1
  // [hour, top, bottom]
  readonly property var keys: [
    [0, "#0d1233", "#211d45"], [5, "#141a45", "#2e2656"], [6.5, "#3f4180", "#e59a80"],
    [9, "#5b9bd3", "#bcd9ea"], [13, "#4e94d0", "#b2d4e8"], [17, "#5d72ba", "#eeb07e"],
    [19.5, "#3b3468", "#d27a8c"], [21, "#151a47", "#2b2455"], [24, "#0d1233", "#211d45"]]
  function skyAt(h, which) {
    for (var i = 0; i < keys.length - 1; i++)
      if (h >= keys[i][0] && h <= keys[i + 1][0])
        return g.mix(keys[i][which], keys[i + 1][which], (h - keys[i][0]) / Math.max(0.001, keys[i + 1][0] - keys[i][0]))
    return Qt.color(keys[0][which])
  }
  // A touch of the theme in every sky, and a little darker so it sits in the panel.
  readonly property color skyTop: g.mix(g.mix(skyAt(hour, 1), g.accent, 0.14), Commons.Color.popups.background, 0.12)
  readonly property color skyBottom: g.mix(g.mix(skyAt(hour, 2), g.accent, 0.14), Commons.Color.popups.background, 0.12)

  Timer { interval: 50; running: t.live; repeat: true; onTriggered: t.phase += 0.05 }

  Rectangle {
    id: glass
    anchors.fill: parent
    radius: t.radius
    gradient: Gradient {
      GradientStop { position: 0; color: t.skyTop }
      GradientStop { position: 1; color: t.skyBottom }
    }
  }

  // stars, twinkling (night only)
  Repeater {
    model: 22
    Rectangle {
      required property int index
      readonly property real r1: (Math.sin(index * 12.9898) * 43758.5453) % 1
      readonly property real r2: (Math.sin(index * 78.233) * 12543.123) % 1
      x: 14 + Math.abs(r1) * (t.width - 28)
      y: 12 + Math.abs(r2) * (t.groundY * 0.62)
      width: index % 5 === 0 ? 2.4 : 1.6
      height: width
      radius: width / 2
      color: "#ffffff"
      opacity: t.nightness * (0.45 + 0.4 * Math.sin(t.phase * (0.8 + Math.abs(r1)) + index))
      visible: t.nightness > 0.02
    }
  }

  // a crescent moon (night, when not focusing)
  Item {
    x: t.width - 46; y: 48
    width: 20; height: 20
    opacity: t.nightness * (t.g.focusing ? 0 : 1)
    visible: opacity > 0.02
    Behavior on opacity { NumberAnimation { duration: 500 } }
    Rectangle { anchors.fill: parent; radius: 10; color: "#fbf3d5"; opacity: 0.95 }
    Rectangle { x: 6; y: -3; width: 20; height: 20; radius: 10; color: t.skyTop }
    Rectangle { anchors.centerIn: parent; width: 34; height: 34; radius: 17; color: g.alpha("#fbf3d5", 0.08); z: -1 }
  }

  // two soft clouds drifting by (day only)
  Item {
    x: 12; y: 52
    width: t.width - 24; height: 40
    clip: true
    opacity: (1 - t.nightness) * 0.9
    visible: opacity > 0.02
    Repeater {
      model: 2
      Item {
        required property int index
        readonly property real span: t.width + 40
        x: ((index * 150 + t.phase * (3 + index * 1.5)) % span) - 50
        y: index * 18 + 2
        width: 46; height: 16
        opacity: 0.22 - index * 0.06
        Rectangle { x: 0; y: 6; width: 46; height: 10; radius: 5; color: "#ffffff" }
        Rectangle { x: 10; y: 1; width: 18; height: 13; radius: 6.5; color: "#ffffff" }
        Rectangle { x: 22; y: 0; width: 15; height: 12; radius: 6; color: "#ffffff" }
      }
    }
  }

  // ---------------------------------------------- the sun: a focus timer
  // During a session the sun rises at the left edge of the glass and sets on
  // the right as the session ends. Out of focus, by day, it rests where the
  // real sun would be.
  Item {
    id: arc
    anchors.fill: parent
    readonly property real rx: t.width / 2 - 24
    readonly property real ry: t.groundY + 2 - (t.height < 160 ? 66 : 76)   // the top of the arc stays below the name
    readonly property real cx: t.width / 2
    readonly property real cy: t.groundY + 2
    readonly property real dayP: Math.max(0, Math.min(1, (t.hour - 6) / 14))
    readonly property real p: t.g.focusing ? t.g.focusProgress : dayP
    readonly property real a: Math.PI * (1 + p)
    opacity: t.g.focusing ? 1 : (1 - t.nightness) * 0.75
    visible: opacity > 0.02
    Behavior on opacity { NumberAnimation { duration: 500 } }

    Shape {
      anchors.fill: parent
      visible: t.g.focusing
      preferredRendererType: Shape.CurveRenderer
      ShapePath {
        strokeColor: g.alpha("#ffffff", 0.28); strokeWidth: 1.4; fillColor: "transparent"
        strokeStyle: ShapePath.DashLine; dashPattern: [1.5, 4]; capStyle: ShapePath.RoundCap
        PathAngleArc { centerX: arc.cx; centerY: arc.cy; radiusX: arc.rx; radiusY: arc.ry; startAngle: 180; sweepAngle: 180 }
      }
      ShapePath {
        strokeColor: g.alpha(g.sunColor, 0.9); strokeWidth: 2.2; fillColor: "transparent"; capStyle: ShapePath.RoundCap
        PathAngleArc { centerX: arc.cx; centerY: arc.cy; radiusX: arc.rx; radiusY: arc.ry; startAngle: 180; sweepAngle: 180 * arc.p }
      }
    }
    Item {
      width: 40; height: 40
      x: arc.cx + arc.rx * Math.cos(arc.a) - width / 2
      y: arc.cy + arc.ry * Math.sin(arc.a) - height / 2
      Rectangle {
        anchors.centerIn: parent
        width: 38; height: 38; radius: 19
        color: g.alpha(g.sunColor, 0.16)
        scale: 0.9 + 0.1 * Math.sin(t.phase * 1.6)
      }
      Rectangle {
        anchors.centerIn: parent
        width: 22; height: 22; radius: 11
        color: g.alpha(g.sunColor, 0.28)
      }
      Rectangle {
        anchors.centerIn: parent
        width: 13; height: 13; radius: 6.5
        gradient: Gradient {
          GradientStop { position: 0; color: Qt.lighter(g.sunColor, 1.3) }
          GradientStop { position: 1; color: g.sunColor }
        }
      }
    }
  }

  // ------------------------------------------------- moss and the plant
  Shape {
    anchors.fill: parent
    preferredRendererType: Shape.CurveRenderer
    ShapePath {
      strokeColor: "transparent"
      fillGradient: LinearGradient {
        x1: 0; y1: t.groundY - 12; x2: 0; y2: t.height
        GradientStop { position: 0; color: g.mix(g.pal.leaf, "#1d2b1c", 0.35) }
        GradientStop { position: 1; color: g.mix(g.pal.leaf, "#0f160f", 0.7) }
      }
      PathSvg {
        readonly property real w: t.width
        readonly property real h: t.height
        readonly property real gy: t.groundY
        readonly property real r: t.radius
        path: "M 0 " + (gy + 2) + " Q " + (w * 0.28) + " " + (gy - 9) + " " + (w * 0.5) + " " + (gy - 6)
            + " T " + w + " " + (gy + 1)
            + " L " + w + " " + (h - r) + " A " + r + " " + r + " 0 0 1 " + (w - r) + " " + h
            + " L " + r + " " + h + " A " + r + " " + r + " 0 0 1 0 " + (h - r) + " Z"
      }
    }
  }
  // grass along the hill: little clumps of three blades
  Repeater {
    model: 15
    Item {
      required property int index
      readonly property real gx: 12 + index * (t.width - 24) / 14 + (index % 3 - 1) * 3
      readonly property real k: (gx - t.width / 2) / (t.width / 2)
      x: gx
      y: t.groundY - 5 + 7 * k * k + (index % 2)
      width: 8; height: 9
      opacity: 0.8
      Repeater {
        model: 3
        Rectangle {
          required property int index
          x: 2.5 + (index - 1) * 2; y: 9 - height
          width: 1.4; height: [5, 8, 6][index] - (parent.index % 3); radius: 0.7
          transformOrigin: Item.Bottom
          rotation: (index - 1) * 16 + 3 * Math.sin(t.phase * 0.9 + parent.index)
          color: g.mix(g.pal.leaf, "#ffffff", 0.08 + index * 0.06)
        }
      }
    }
  }

  Item {
    id: plant
    width: g.plantW; height: g.plantH
    x: (t.width - width) / 2
    y: t.groundY + 12 - height
    transformOrigin: Item.Bottom
    scale: t.height < 160 ? 0.98 : 1.18
    rotation: (1.0 - g.droop * 0.7) * Math.sin(t.phase * 0.9) * 0.8
    Canvas {
      id: heroCanvas
      width: g.plantW * g.ss
      height: g.plantH * g.ss
      scale: 1 / g.ss
      transformOrigin: Item.TopLeft
      antialiasing: true
      onPaint: {
        var ctx = getContext("2d")
        ctx.reset()
        ctx.scale(g.ss, g.ss)
        Species.draw(ctx, g.plantW, g.plantH, {
          species: g.species, growth: g.progress, droop: g.droop, seed: g.seed, pal: g.pal
        })
      }
    }
  }
  function repaint() { heroCanvas.requestPaint() }

  // fireflies at dusk and at night
  Repeater {
    model: 7
    Item {
      required property int index
      readonly property real bx: 18 + (index * 37) % (t.width - 36)
      readonly property real by: t.groundY - 22 - (index * 13) % 46
      x: bx + 9 * Math.sin(t.phase * 0.6 + index * 1.7)
      y: by + 6 * Math.cos(t.phase * 0.8 + index * 2.3)
      width: 10; height: 10
      opacity: t.nightness * (0.35 + 0.65 * Math.max(0, Math.sin(t.phase * 1.3 + index * 2.1)))
      visible: t.nightness > 0.05
      Rectangle { anchors.centerIn: parent; width: 10; height: 10; radius: 5; color: g.alpha("#f6e27a", 0.25) }
      Rectangle { anchors.centerIn: parent; width: 3; height: 3; radius: 1.5; color: "#fff3a6" }
    }
  }

  // ------------------------------------------------------------- glass
  // a soft shine down the left side, a darker top so the name reads, and the rim
  Rectangle {
    x: 12; y: 10
    width: 16; height: t.groundY - 24
    radius: 8
    rotation: 8
    gradient: Gradient {
      GradientStop { position: 0; color: g.alpha("#ffffff", 0.16) }
      GradientStop { position: 1; color: g.alpha("#ffffff", 0) }
    }
  }
  Rectangle {
    anchors { left: parent.left; right: parent.right; top: parent.top }
    height: 54
    radius: t.radius
    gradient: Gradient {
      GradientStop { position: 0; color: g.alpha("#000000", 0.32) }
      GradientStop { position: 1; color: g.alpha("#000000", 0) }
    }
  }
  Rectangle {
    anchors.fill: parent
    radius: t.radius
    color: "transparent"
    border.width: 1
    border.color: g.alpha("#ffffff", 0.14)
  }

  // ------------------------------------------------- name, day, stage
  Column {
    x: 14; y: 11
    spacing: 1
    Text {
      textFormat: Text.PlainText
      text: g.info.name
      color: "#ffffff"
      font.family: Style.font.family; font.pixelSize: 16; font.bold: true
    }
    Text {
      textFormat: Text.PlainText
      text: "Day " + g.dayNum()
      color: g.alpha("#ffffff", 0.7)
      font.family: Style.font.family; font.pixelSize: 10
    }
  }
  Rectangle {
    anchors { right: parent.right; top: parent.top; margins: 12 }
    width: stageText.implicitWidth + 18; height: 22; radius: 11
    color: g.bloomed ? g.accent : g.alpha("#000000", 0.28)
    border.width: 1
    border.color: g.bloomed ? g.accent : g.alpha("#ffffff", 0.22)
    Text {
      id: stageText
      textFormat: Text.PlainText
      anchors.centerIn: parent
      text: g.stage
      color: g.bloomed ? Commons.Color.background : "#ffffff"
      font.family: Style.font.family; font.pixelSize: 10; font.bold: true
    }
  }
}
