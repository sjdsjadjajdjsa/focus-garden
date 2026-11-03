import QtQuick
import QtQuick.Shapes

// A crisp line icon, drawn from 24×24 paths so every icon shares the same
// box, stroke and optical center. Paths from Lucide (lucide.dev): ISC license,
// with the icons derived from Feather (the stop square) under the MIT license.
// Both notices are in LICENSE-lucide.
Item {
  id: icon
  property string name
  property color color: "white"
  property real size: 16
  property real stroke: 2          // in the 24-unit grid
  property bool filled: false

  width: size
  height: size

  readonly property var paths: ({
    droplet: "M12 22a7 7 0 0 0 7-7c0-2-1-3.9-3-5.5s-3.5-4-4-6.5c-.5 2.5-2 4.9-4 6.5C6 11.1 5 13 5 15a7 7 0 0 0 7 7z",
    leaf: "M11 20A7 7 0 0 1 9.8 6.1C15.5 5 17 4.48 19 2c1 2 2 4.18 2 8 0 5.5-4.78 10-10 10Z M2 21c0-3 1.85-5.36 5.08-6C9.5 14.52 12 13 13 12",
    timer: "M10 2h4 M12 14l3-3 M20 14a8 8 0 1 1-16 0a8 8 0 1 1 16 0",
    coffee: "M10 2v2 M14 2v2 M6 2v2 M16 8a1 1 0 0 1 1 1v8a4 4 0 0 1-4 4H7a4 4 0 0 1-4-4V9a1 1 0 0 1 1-1h14a4 4 0 1 1 0 8h-1",
    sprout: "M7 20h10 M10 20c5.5-2.5.8-6.4 3-10 M9.5 9.4c1.1.8 1.8 2.2 2.3 3.7-2 .4-3.5.4-4.8-.3-1.2-.6-2.3-1.9-3-4.2 2.8-.5 4.4 0 5.5.8z M14.1 6a7 7 0 0 0-1.1 4c1.9-.1 3.3-.6 4.3-1.4 1-1 1.6-2.3 1.7-4.6-2.7.1-4 1-4.9 2z",
    stop: "M8 6h8a2 2 0 0 1 2 2v8a2 2 0 0 1-2 2H8a2 2 0 0 1-2-2V8a2 2 0 0 1 2-2z",
    play: "M6 3l14 9-14 9z",
    check: "M22 12a10 10 0 1 1-20 0a10 10 0 1 1 20 0 M9 12l2 2 4-4",
    skip: "M5 4l10 8-10 8z M19 5v14",
    eye: "M2.06 12.35a1 1 0 0 1 0-.7 10.75 10.75 0 0 1 19.88 0 1 1 0 0 1 0 .7 10.75 10.75 0 0 1-19.88 0 M15 12a3 3 0 1 1-6 0a3 3 0 1 1 6 0"
  })

  Shape {
    width: 24
    height: 24
    scale: icon.size / 24
    transformOrigin: Item.TopLeft
    preferredRendererType: Shape.CurveRenderer
    ShapePath {
      strokeColor: icon.color
      strokeWidth: icon.stroke
      fillColor: icon.filled ? icon.color : "transparent"
      capStyle: ShapePath.RoundCap
      joinStyle: ShapePath.RoundJoin
      PathSvg { path: icon.paths[icon.name] || "" }
    }
  }
}
