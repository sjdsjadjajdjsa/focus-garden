import QtQuick
import qs.Commons
import qs.Commons as Commons

// Growth as a vine: a green stem creeps along the bar, leaves sprout along it,
// a bud sits at its tip, and the quarter marks light up as it passes them.
Column {
  id: vm
  property var g
  property real value: 0
  width: parent ? parent.width : 240
  spacing: 6

  MeterHeader { g: vm.g; icon: "leaf"; iconColor: g.mix(g.pal.leaf, "#ffffff", 0.15); label: "Growth"; detail: Math.floor(vm.value * 100) + "%" }

  Item {
    id: bar
    width: vm.width
    height: 16
    property real fillW: Math.max(0, Math.min(1, vm.value)) * (width - 6)
    Behavior on fillW { NumberAnimation { duration: 600; easing.type: Easing.OutCubic } }

    Rectangle {                                     // the trellis
      y: 5; width: parent.width; height: 6; radius: 3
      color: g.alpha(Commons.Color.popups.text, 0.08)
    }
    Repeater {                                      // quarter marks
      model: [0.25, 0.5, 0.75]
      Rectangle {
        required property real modelData
        readonly property bool passed: vm.value >= modelData
        x: (bar.width - 6) * modelData - 2; y: 6
        width: 4; height: 4; radius: 2
        color: passed ? g.mix(g.pal.leaf, "#ffffff", 0.35) : g.alpha(Commons.Color.popups.text, 0.22)
      }
    }
    Rectangle {                                     // the stem
      y: 6.5; height: 3; radius: 1.5
      width: bar.fillW
      visible: width > 1
      gradient: Gradient {
        orientation: Gradient.Horizontal
        GradientStop { position: 0; color: g.pal.stem }
        GradientStop { position: 1; color: g.pal.leaf }
      }
    }
    Repeater {                                      // leaves along the stem
      model: Math.max(0, Math.floor((bar.fillW - 6) / 13))
      Rectangle {
        required property int index
        readonly property bool up: index % 2 === 0
        x: 5 + index * 13
        y: up ? 1.5 : 9.5
        width: 8; height: 4.5; radius: 2.25
        rotation: up ? -32 : 32
        color: index % 3 === 1 ? g.mix(g.pal.leaf, "#ffffff", 0.12) : g.pal.leaf
      }
    }
    Rectangle {                                     // the bud at the tip
      visible: bar.fillW > 3
      x: bar.fillW - 3; y: 4.5
      width: 7; height: 7; radius: 3.5
      color: g.bloomed ? g.accent : g.mix(g.pal.leaf, g.accent, 0.55)
      border.width: 1
      border.color: g.alpha("#ffffff", 0.35)
    }
  }
}
