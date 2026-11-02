import QtQuick
import QtQuick.Effects
import QtQuick.Particles
import QtQuick.Shapes
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import "Species.js" as Species
import qs.Commons
import qs.Commons as Commons

// Focus Garden: a little plant in the corner that grows while you work, twice
// as fast during focus sessions, and gets thirsty if you never take a break.
//
//  - Click the pot to start a focus session (25 or 50 minutes); a ring fills
//    around the plant, and when it's done you get a break with a small idea
//    for what to do with it.
//  - Every active minute grows it (thirsty: half speed, parched: not at all).
//  - Water drains over ~2.5 hours of nonstop use and refills while you're
//    away; 5 minutes away is a full drink and counts as a break.
//  - The card shows today's focus time, sessions, breaks and screen time, and
//    the shelf of plants you've grown.
// No network and no commands except creating its own state folder.
Item {
  id: root

  property var shell
  property string omarchyPath
  property var manifest

  // ---------------------------------------------------------------- tuning
  readonly property int thirstyAfter: 150     // active minutes from full to empty
  readonly property real refillPerIdleMinute: 20
  readonly property int breakMinutes: 5
  readonly property int plantW: 100           // drawing size, logical px
  readonly property int plantH: 124
  readonly property int ss: 3                 // drawn at 3x for crisp edges on scaled screens
  readonly property int edge: 10
  readonly property int cardW: 264

  // ----------------------------------------------------------------- state
  readonly property string stateDir: (Quickshell.env("XDG_STATE_HOME") || Quickshell.env("HOME") + "/.local/state") + "/focus-garden"
  property bool loaded: false
  property string species: "daisy"
  property int seed: 1
  property real growth: 0                     // active minutes, scaled by health
  property real water: 100                    // 0..100
  property string plantedOn: ""
  property var collection: []                 // [{ species, seed, bloomedOn, days }]
  property bool bloomRecorded: false
  property real activeMinutes: 0
  // today
  property string statsDay: ""
  property int todayActive: 0
  property int todayBreaks: 0
  property int stretch: 0                     // minutes since the last break
  property int longestStretch: 0
  property bool nudged: false                 // one thirst nudge per dry spell
  // focus sessions
  property double focusStartedAt: 0
  property double focusEndsAt: 0              // 0 = not focusing
  property bool breakDue: false               // a session just ended; a break would be good
  property string breakTip: ""
  property int todayFocus: 0                  // minutes focused today
  property int todaySessions: 0
  property real totalFocus: 0
  property double now: Date.now()             // ticks every second while focusing
  readonly property bool focusing: focusEndsAt > 0
  readonly property real focusProgress: focusing ? Math.max(0, Math.min(1, (now - focusStartedAt) / Math.max(1, focusEndsAt - focusStartedAt))) : 0
  readonly property string focusLeft: {
    var secs = Math.max(0, Math.ceil((focusEndsAt - now) / 1000))
    return Math.floor(secs / 60) + ":" + (secs % 60 < 10 ? "0" : "") + secs % 60
  }
  // Small, real things to do with a break.
  readonly property var breakTips: [
    "Stand up and stretch your arms over your head.",
    "Look at something far away for 20 seconds. Your eyes will thank you.",
    "Refill your water glass and drink some.",
    "Roll your shoulders back a few times and unclench your jaw.",
    "Take five slow, deep breaths.",
    "Walk around for a minute; get the blood moving.",
    "Close your eyes for 30 seconds and let them rest.",
    "Step outside or open a window for some fresh air."
  ]

  readonly property var info: Species.species[species] || Species.species.daisy
  readonly property real progress: Math.min(1, growth / info.minutes)
  readonly property bool bloomed: progress >= 1
  readonly property real droop: water >= 45 ? 0 : (45 - water) / 45
  readonly property string stage: progress < 0.03 ? "Seed" : progress < 0.12 ? "Sprout"
    : progress < 0.45 ? "Young" : progress < 0.8 ? "Growing" : progress < 1 ? "Budding" : "In bloom"
  readonly property string thirst: water >= 70 ? "Well watered" : water >= 45 ? "A little thirsty"
    : water >= 20 ? "Thirsty" : "Parched"

  function today() { return Qt.formatDate(new Date(), "yyyy-MM-dd") }
  function newSeed() { return Math.floor(Math.random() * 2147483647) }
  function dayNum() {
    return plantedOn === "" ? 1 : Math.max(1, Math.floor((Date.now() - new Date(plantedOn + "T00:00:00").getTime()) / 86400000) + 1)
  }
  function hm(mins) {
    var h = Math.floor(mins / 60), m = Math.round(mins % 60)
    return h > 0 ? h + "h " + (m < 10 ? "0" : "") + m + "m" : m + "m"
  }

  // A new species each time, preferring ones you haven't grown yet.
  function nextSpecies() {
    var grown = collection.map(function(c) { return c.species })
    var fresh = Species.order.filter(function(s) { return grown.indexOf(s) === -1 && s !== species })
    var pool = fresh.length ? fresh : Species.order.filter(function(s) { return s !== species })
    return pool[Math.floor(Math.random() * pool.length)]
  }
  function plantNew(sp) {
    species = sp || nextSpecies()
    seed = newSeed()
    growth = 0
    water = Math.max(water, 80)
    plantedOn = today()
    bloomRecorded = false
    save()
    repaint()
  }
  function repaint() { plantCanvas.requestPaint() }

  // ------------------------------------------------------------ saving
  FileView {
    id: stateFile
    path: root.stateDir + "/state.json"
    atomicWrites: true
    printErrors: false
    onLoaded: {
      var s = {}
      try { s = JSON.parse(text()) || {} } catch (e) { s = {} }
      root.species = Species.species[s.species] ? s.species : "daisy"
      root.seed = Number(s.seed) || root.newSeed()
      root.growth = Math.max(0, Number(s.growth) || 0)
      var w = Number(s.water)
      root.water = isNaN(w) ? 100 : Math.max(0, Math.min(100, w))
      root.plantedOn = /^\d{4}-\d\d-\d\d$/.test(s.plantedOn || "") ? s.plantedOn : root.today()
      root.collection = Array.isArray(s.collection) ? s.collection.filter(function(c) { return c && Species.species[c.species] }) : []
      root.bloomRecorded = s.bloomRecorded === true
      root.activeMinutes = Number(s.activeMinutes) || 0
      var t = s.today || {}
      if (t.day === root.today()) {
        root.statsDay = t.day
        root.todayActive = Number(t.active) || 0
        root.todayBreaks = Number(t.breaks) || 0
        root.longestStretch = Number(t.longest) || 0
        root.stretch = Number(t.stretch) || 0
        root.todayFocus = Number(t.focus) || 0
        root.todaySessions = Number(t.sessions) || 0
      }
      root.totalFocus = Number(s.totalFocus) || 0
      root.breakDue = s.breakDue === true
      root.breakTip = String(s.breakTip || "")
      if (Number(s.focusEndsAt) > 0) {        // a session survives a shell restart
        root.focusStartedAt = Number(s.focusStartedAt) || Date.now()
        root.focusEndsAt = Number(s.focusEndsAt)
        root.now = Date.now()
      }
      // Time away from the computer (or with the shell off) is a break.
      var away = (Date.now() - (Number(s.savedAt) || Date.now())) / 60000
      if (away > 0) root.water = Math.min(100, root.water + away * root.refillPerIdleMinute)
      if (away >= root.breakMinutes) root.stretch = 0
      root.loaded = true
      if (root.focusing && root.focusEndsAt <= Date.now()) root.finishFocus()  // it ended while the shell was off
      root.repaint()
    }
    onLoadFailed: {                          // first run: plant the first seed
      root.loaded = true
      root.plantNew("daisy")
    }
  }
  // The folder is created (harmless if it exists) right before each write.
  Process { id: mkdir; command: ["mkdir", "-p", root.stateDir]; onExited: root.writeState() }
  function save() { if (loaded) saveTimer.restart() }
  Timer { id: saveTimer; interval: 300; onTriggered: if (!mkdir.running) mkdir.running = true }
  function writeState() {
    stateFile.setText(JSON.stringify({
      version: 1, species: root.species, seed: root.seed, growth: Math.round(root.growth * 100) / 100,
      water: Math.round(root.water * 10) / 10, plantedOn: root.plantedOn, collection: root.collection,
      bloomRecorded: root.bloomRecorded, activeMinutes: Math.round(root.activeMinutes),
      today: { day: root.statsDay, active: root.todayActive, breaks: root.todayBreaks,
               longest: root.longestStretch, stretch: root.stretch, focus: root.todayFocus,
               sessions: root.todaySessions },
      totalFocus: Math.round(root.totalFocus), focusStartedAt: root.focusStartedAt, focusEndsAt: root.focusEndsAt,
      breakDue: root.breakDue, breakTip: root.breakTip,
      savedAt: Date.now()
    }, null, 1))
  }

  // ------------------------------------------------- growing and watering
  // Idle for a minute = away. Watching a video with no input counts as away.
  IdleMonitor {
    id: idle
    timeout: 60
    respectInhibitors: false
    onIsIdleChanged: {
      if (isIdle) root.idleSince = Date.now() - 60000
      else if (root.idleSince > 0) {
        if ((Date.now() - root.idleSince) / 60000 >= root.breakMinutes) root.tookBreak()
        root.idleSince = 0
      }
    }
  }
  property double idleSince: 0
  function tookBreak() {
    newDay()
    todayBreaks += 1
    stretch = 0
    nudged = false
    if (breakDue) {
      breakDue = false
      showTip("Welcome back! Your plant had a drink 💧 Ready for another focus?", 12000)
    }
    save()
  }
  function newDay() {
    if (statsDay === today()) return
    statsDay = today()
    todayActive = 0; todayBreaks = 0; longestStretch = 0; stretch = 0
    todayFocus = 0; todaySessions = 0
  }

  // ------------------------------------------------------- focus sessions
  // While focusing the plant grows twice as fast. When the time is up it asks
  // for a break, with a small idea for what to do with it.
  function startFocus(minutes) {
    minutes = Math.max(1, Math.min(180, Math.round(Number(minutes) || 25)))
    newDay()
    now = Date.now()
    focusStartedAt = now
    focusEndsAt = now + minutes * 60000
    breakDue = false
    cardOpen = false
    showTip("🎯 Focusing for " + minutes + " minutes. I'll grow while you work.", 5000)
    save()
  }
  function stopFocus() {
    if (!focusing) return
    var done = Math.floor((Date.now() - focusStartedAt) / 60000)
    todayFocus += done
    totalFocus += done
    focusEndsAt = 0
    showTip("Focus stopped after " + hm(done) + ".", 5000)
    save()
  }
  function finishFocus() {
    var mins = Math.round((focusEndsAt - focusStartedAt) / 60000)
    newDay()
    todayFocus += mins
    totalFocus += mins
    todaySessions += 1
    focusEndsAt = 0
    breakDue = true
    breakTip = breakTips[Math.floor(Math.random() * breakTips.length)]
    sparkles.burst(30)
    showTip("🎉 " + hm(mins) + " of focus done! Break time: " + breakTip, 60000)
    save()
  }
  function skipBreak() { breakDue = false; save() }
  Timer {
    interval: 1000
    running: root.focusing
    repeat: true
    onTriggered: {
      root.now = Date.now()
      if (root.now >= root.focusEndsAt) root.finishFocus()
    }
  }
  Timer {
    interval: 60000
    running: root.loaded
    repeat: true
    onTriggered: root.tick(idle.isIdle)
  }
  function tick(away) {
    newDay()
    var before = water
    if (away) {
      water = Math.min(100, water + refillPerIdleMinute)
      if (before < 60 && water - before >= 10) drops.start()
    } else {
      activeMinutes += 1
      todayActive += 1
      stretch += 1
      longestStretch = Math.max(longestStretch, stretch)
      water = Math.max(0, water - 100 / thirstyAfter)
      if (!bloomed) growth += (focusing ? 2 : 1) * (water >= 45 ? 1 : water >= 15 ? 0.5 : 0)
      if (water < 30 && !nudged && !focusing) {   // one gentle nudge per dry spell, never mid-focus
        nudged = true
        showTip("I'm getting thirsty 💧 A 5-minute break would water me.", 20000)
      }
    }
    if (bloomed && !bloomRecorded) celebrate()
    save()
    repaint()
  }
  function setGrowthPercent(p) {
    growth = Math.max(0, Math.min(100, Number(p) || 0)) / 100 * info.minutes
    if (growth < info.minutes) bloomRecorded = false
    save()
    repaint()
  }
  function celebrate() {
    bloomRecorded = true
    var c = collection.slice()
    c.push({ species: species, seed: seed, bloomedOn: today(), days: dayNum() })
    collection = c
    sparkles.burst(40)
    burstAgain.start()
    showTip(info.emoji + " Your " + info.name.toLowerCase() + " bloomed! It's on your shelf now.", 15000)
    save()
  }
  Timer { id: burstAgain; interval: 600; onTriggered: sparkles.burst(30) }

  // -------------------------------------------------------------- colors
  readonly property color accent: Commons.Color.accent
  function alpha(c, a) { c = Qt.color(c); return Qt.rgba(c.r, c.g, c.b, a) }
  function mix(a, b, t) {
    a = Qt.color(a); b = Qt.color(b)
    return Qt.rgba(a.r + (b.r - a.r) * t, a.g + (b.g - a.g) * t, a.b + (b.b - a.b) * t, 1)
  }
  // Leaves are a natural green with a touch of the theme; flowers wear the
  // theme's accent; the pot is terracotta warmed by it. Thirst fades the
  // greens toward straw.
  function palette(dry) {
    var wilt = dry * 0.55
    return {
      leaf: mix(mix("#5fb35a", accent, 0.12), "#b39a5a", wilt),
      stem: mix(mix("#4c8f46", accent, 0.08), "#9c8450", wilt),
      flower: mix(accent, "#ffffff", 0.08), petal: mix("#fbfaf4", accent, 0.08),
      sun: mix("#f5c542", accent, 0.15), center: mix("#6d4a2a", accent, 0.12),
      bark: mix("#6e4f36", accent, 0.06), pot: mix("#c7795a", accent, 0.3),
      band: mix(accent, "#ffffff", 0.15), soil: Qt.color("#4a3526")
    }
  }
  readonly property var pal: palette(droop)
  readonly property color sunColor: mix("#ffc94d", accent, 0.2)
  onPalChanged: repaint()

  // ----------------------------------------------------- popover state
  property string tip: ""
  function showTip(text, ms) { tip = text; tipTimer.interval = ms || 4000; tipTimer.restart() }
  Timer { id: tipTimer; onTriggered: if (!plantMouse.containsMouse) root.tip = "" }
  property bool cardOpen: false

  // Stay out of the way in fullscreen apps on this monitor.
  readonly property var mon: Hyprland.monitorFor(win.screen)
  readonly property bool hidden: !!(mon && mon.activeWorkspace && mon.activeWorkspace.hasFullscreen)

  // ------------------------------------------------------------ window
  PanelWindow {
    id: win
    screen: Quickshell.screens.length ? Quickshell.screens[0] : null
    anchors { bottom: true; left: true }
    margins { bottom: 0; left: 0 }
    implicitWidth: root.cardW + 40
    implicitHeight: 620
    color: "transparent"
    surfaceFormat.opaque: false
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "focus-garden"
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    HyprlandFocusGrab { active: root.cardOpen; windows: [win]; onCleared: root.cardOpen = false }
    mask: Region { item: root.hidden ? noHit : root.cardOpen ? fullHit : plantHit }
    Item { id: fullHit; anchors.fill: parent }
    Item { id: noHit; width: 0; height: 0 }
    Item { id: plantHit; x: pot.x + 18; y: pot.y + 30; width: pot.width - 36; height: pot.height - 30 }

    Item {
      anchors.fill: parent
      opacity: root.hidden ? 0 : 1
      visible: opacity > 0.01
      Behavior on opacity { NumberAnimation { duration: 300 } }

      // ---- the plant
      Item {
        id: pot
        width: root.plantW
        height: root.plantH
        x: root.edge
        anchors.bottom: parent.bottom
        anchors.bottomMargin: root.edge - 6

        // focus: a sun rises over the plant and travels its arc while you focus
        Item {
          id: sky
          readonly property real r: 50
          readonly property real cx: width / 2
          readonly property real cy: height - 34          // the soil line
          readonly property real a: Math.PI * (1 + root.focusProgress)   // left (π) → over the top → right (2π)
          anchors.fill: parent
          visible: opacity > 0.01
          opacity: root.focusing ? 1 : 0
          Behavior on opacity { NumberAnimation { duration: 500 } }
          Shape {
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer
            ShapePath {                                    // the path the sun will take
              strokeColor: root.alpha(root.accent, 0.35); strokeWidth: 1.4; fillColor: "transparent"
              strokeStyle: ShapePath.DashLine; dashPattern: [1.5, 3.5]; capStyle: ShapePath.RoundCap
              PathAngleArc { centerX: sky.cx; centerY: sky.cy; radiusX: sky.r; radiusY: sky.r; startAngle: 180; sweepAngle: 180 }
            }
            ShapePath {                                    // the part it has travelled
              strokeColor: root.alpha(root.accent, 0.9); strokeWidth: 2; fillColor: "transparent"; capStyle: ShapePath.RoundCap
              PathAngleArc { centerX: sky.cx; centerY: sky.cy; radiusX: sky.r; radiusY: sky.r; startAngle: 180; sweepAngle: 180 * root.focusProgress }
            }
          }
          Item {                                           // the sun
            width: 30; height: 30
            x: sky.cx + sky.r * Math.cos(sky.a) - width / 2
            y: sky.cy + sky.r * Math.sin(sky.a) - height / 2
            Rectangle {                                    // glow
              anchors.centerIn: parent
              width: 26; height: 26; radius: 13
              color: root.alpha(root.sunColor, 0.22)
              scale: 0.9 + 0.12 * Math.sin(swayer.t * 2)
            }
            Rectangle {
              anchors.centerIn: parent
              width: 11; height: 11; radius: 5.5
              gradient: Gradient {
                GradientStop { position: 0; color: Qt.lighter(root.sunColor, 1.25) }
                GradientStop { position: 1; color: root.sunColor }
              }
              border.width: 1
              border.color: root.alpha("#ffffff", 0.5)
            }
          }
        }
        // a cup of coffee beside the pot when a break is due
        Text {
          id: cup
          textFormat: Text.PlainText
          text: "☕"
          font.pixelSize: 15
          x: parent.width - 14
          y: parent.height - 30
          z: 2
          visible: opacity > 0.01
          opacity: root.breakDue && !root.focusing ? 1 : 0
          Behavior on opacity { NumberAnimation { duration: 400 } }
          SequentialAnimation on y {                  // a gentle bob
            running: cup.visible
            loops: Animation.Infinite
            NumberAnimation { to: pot.height - 33; duration: 900; easing.type: Easing.InOutSine }
            NumberAnimation { to: pot.height - 30; duration: 900; easing.type: Easing.InOutSine }
          }
          Repeater {                                  // steam
            model: 2
            Rectangle {
              required property int index
              width: 2; height: 6; radius: 1
              x: 5 + index * 4
              color: root.alpha(Commons.Color.popups.text, 0.35)
              SequentialAnimation on y {
                running: cup.visible
                loops: Animation.Infinite
                PauseAnimation { duration: index * 450 }
                NumberAnimation { from: -2; to: -12; duration: 1100 }
              }
              SequentialAnimation on opacity {
                running: cup.visible
                loops: Animation.Infinite
                PauseAnimation { duration: index * 450 }
                NumberAnimation { from: 0.8; to: 0; duration: 1100 }
              }
            }
          }
        }

        Item {
          id: swayer
          anchors.fill: parent
          transformOrigin: Item.Bottom
          property real t: 0
          rotation: (1.0 - root.droop * 0.7) * Math.sin(t) + (plantMouse.containsMouse ? 2.2 * Math.sin(t * 3.2) : 0)
          scale: plantMouse.pressed ? 0.95 : plantMouse.containsMouse ? 1.04 : 1
          Behavior on scale { NumberAnimation { duration: 180; easing.type: Easing.OutBack } }
          Timer {
            interval: 80
            running: win.visible && !root.hidden
            repeat: true
            onTriggered: swayer.t += 0.08
          }
          Canvas {
            id: plantCanvas
            width: root.plantW * root.ss
            height: root.plantH * root.ss
            scale: 1 / root.ss
            transformOrigin: Item.TopLeft
            antialiasing: true
            onPaint: {
              var ctx = getContext("2d")
              ctx.reset()
              ctx.scale(root.ss, root.ss)
              Species.draw(ctx, root.plantW, root.plantH, {
                species: root.species, growth: root.progress, droop: root.droop, seed: root.seed, pal: root.pal
              })
            }
          }
        }

        MouseArea {
          id: plantMouse
          anchors.fill: parent
          anchors.topMargin: 30
          anchors.leftMargin: 18
          anchors.rightMargin: 18
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onEntered: if (!root.cardOpen) root.showTip(
                       (root.focusing ? "🎯 Focusing · " + root.focusLeft + " left\n" : root.breakDue ? "☕ Break time: " + root.breakTip + "\n" : "")
                       + root.info.emoji + "  " + root.info.name + " · day " + root.dayNum() + " · "
                       + (root.bloomed ? "in bloom!" : Math.floor(root.progress * 100) + "% grown") + "\n💧 " + root.thirst, 600000)
          onExited: tipTimer.restart()
          onClicked: { root.cardOpen = !root.cardOpen; root.tip = "" }
        }

        // ---- sparkles (bloom) and drops (a drink after a break)
        ParticleSystem { id: fx; anchors.fill: parent }
        ImageParticle {
          system: fx; groups: ["spark"]
          source: "qrc:///particleresources/glowdot.png"
          color: Qt.lighter(root.accent, 1.2); colorVariation: 0.15; alpha: 0.9
        }
        ImageParticle {
          system: fx; groups: ["drop"]
          source: "qrc:///particleresources/glowdot.png"
          color: "#9ad4fa"; alpha: 0.95
        }
        Emitter {
          id: sparkles
          system: fx; group: "spark"
          x: parent.width * 0.2; y: parent.height * 0.1; width: parent.width * 0.6; height: parent.height * 0.5
          emitRate: 0; lifeSpan: 1800; lifeSpanVariation: 500; size: 7; sizeVariation: 4; endSize: 1
          velocity: AngleDirection { angle: 270; angleVariation: 70; magnitude: 26; magnitudeVariation: 12 }
        }
        Emitter {
          id: drops
          system: fx; group: "drop"
          x: parent.width * 0.3; y: 0; width: parent.width * 0.4; height: 4
          enabled: false; emitRate: 9; lifeSpan: 1300; size: 5; sizeVariation: 2
          velocity: PointDirection { y: 70; yVariation: 15 }
          function start() { enabled = true; dropsStop.restart() }
          Timer { id: dropsStop; interval: 1800; onTriggered: drops.enabled = false }
        }
      }

      // ---- hover tooltip
      Popover {
        id: tipBox
        shown: root.tip !== "" && !root.cardOpen
        x: root.edge + 6
        anchors.bottom: pot.top
        anchors.bottomMargin: 2
        width: Math.min(240, tipText.implicitWidth + 24)
        height: tipText.implicitHeight + 16
        Text {
          id: tipText
          textFormat: Text.PlainText
          x: 12; y: 8
          width: Math.min(216, implicitWidth)
          wrapMode: Text.Wrap
          lineHeight: 1.15
          text: root.tip
          color: Commons.Color.popups.text
          font.family: Style.font.family
          font.pixelSize: 11
        }
      }

      // ---- the card: growth, water, today, and the shelf
      Popover {
        id: card
        shown: root.cardOpen
        x: root.edge + 6
        anchors.bottom: pot.top
        anchors.bottomMargin: 2
        width: root.cardW
        height: cardCol.implicitHeight + 28

        Column {
          id: cardCol
          x: 14; y: 14
          width: parent.width - 28
          spacing: 10

          Item {                                    // name + stage badge
            width: parent.width
            height: 22
            Text {
              textFormat: Text.PlainText
              anchors.verticalCenter: parent.verticalCenter
              text: root.info.emoji + "  " + root.info.name
              color: Commons.Color.popups.text
              font.family: Style.font.family; font.pixelSize: 15; font.bold: true
            }
            Rectangle {
              anchors { right: parent.right; verticalCenter: parent.verticalCenter }
              width: stageText.implicitWidth + 16; height: 20; radius: 10
              color: root.alpha(root.accent, root.bloomed ? 0.9 : 0.16)
              Text {
                id: stageText
                textFormat: Text.PlainText
                anchors.centerIn: parent
                text: root.stage
                color: root.bloomed ? Commons.Color.background : root.accent
                font.family: Style.font.family; font.pixelSize: 10; font.bold: true
              }
            }
          }
          Text {
            textFormat: Text.PlainText
            topPadding: -6
            text: "Day " + root.dayNum() + " · planted " + Qt.formatDate(new Date(root.plantedOn + "T00:00:00"), "MMM d")
            color: root.alpha(Commons.Color.popups.text, 0.5)
            font.family: Style.font.family; font.pixelSize: 11
          }

          // focus: start, countdown, or break time
          Rectangle {
            width: parent.width
            height: focusCol.implicitHeight + 20
            radius: 10
            color: root.alpha(root.accent, root.focusing ? 0.14 : 0.07)
            border.width: 1
            border.color: root.alpha(root.accent, root.focusing ? 0.4 : 0.18)
            Column {
              id: focusCol
              x: 12; y: 10
              width: parent.width - 24
              spacing: 8
              Text {
                textFormat: Text.PlainText
                text: root.focusing ? root.focusLeft : root.breakDue ? "Break time ☕" : "Focus"
                color: root.focusing ? root.accent : Commons.Color.popups.text
                font.family: Style.font.family; font.pixelSize: root.focusing ? 24 : 13; font.bold: true
              }
              Text {
                textFormat: Text.PlainText
                width: parent.width
                wrapMode: Text.Wrap
                lineHeight: 1.15
                text: root.focusing ? "left in this session. Your plant grows twice as fast while you focus."
                      : root.breakDue ? root.breakTip + " Step away for 5 minutes and your plant gets a drink."
                      : "Start a session and your plant grows twice as fast while you work."
                color: root.alpha(Commons.Color.popups.text, 0.6)
                font.family: Style.font.family; font.pixelSize: 11
              }
              Row {
                spacing: 6
                Pill { visible: !root.focusing; label: "Focus 25"; primary: true; onClicked: root.startFocus(25) }
                Pill { visible: !root.focusing; label: "50"; onClicked: root.startFocus(50) }
                Pill { visible: root.focusing; label: "Stop"; onClicked: root.stopFocus() }
                Pill { visible: root.breakDue && !root.focusing; label: "Skip break"; onClicked: root.skipBreak() }
              }
            }
          }

          Meter { label: "Growth"; value: root.progress; detail: Math.floor(root.progress * 100) + "%"; tint: root.accent }
          Meter { label: "Water"; value: root.water / 100; detail: root.thirst; tint: "#6fbaf0" }

          Rectangle { width: parent.width; height: 1; color: root.alpha(Commons.Color.popups.text, 0.08) }

          // today
          Row {
            width: parent.width
            spacing: 0
            Stat { width: parent.width / 3; value: root.hm(root.todayFocus); label: "focused today" }
            Stat { width: parent.width / 3; value: String(root.todaySessions); label: root.todaySessions === 1 ? "session" : "sessions" }
            Stat { width: parent.width / 3; value: String(root.todayBreaks); label: root.todayBreaks === 1 ? "break" : "breaks" }
          }
          Text {
            textFormat: Text.PlainText
            width: parent.width
            topPadding: -4
            horizontalAlignment: Text.AlignHCenter
            text: "Screen time " + root.hm(root.todayActive) + " · longest stretch " + root.hm(root.longestStretch)
            color: root.alpha(Commons.Color.popups.text, 0.4)
            font.family: Style.font.family; font.pixelSize: 10
          }

          Text {
            textFormat: Text.PlainText
            width: parent.width
            wrapMode: Text.Wrap
            lineHeight: 1.15
            visible: root.bloomed || (root.water < 45 && !root.breakDue)
            text: root.bloomed ? "Fully grown! Plant a new seed whenever you're ready."
                  : "Your plant is thirsty. Step away for 5 minutes to water it 💧"
            color: root.alpha(Commons.Color.popups.text, 0.6)
            font.family: Style.font.family; font.pixelSize: 11
          }

          Rectangle {
            visible: root.bloomed
            width: newText.implicitWidth + 28; height: 30; radius: 15
            color: newMouse.containsMouse ? Qt.lighter(root.accent, 1.1) : root.accent
            Behavior on color { ColorAnimation { duration: 120 } }
            Text {
              id: newText
              textFormat: Text.PlainText
              anchors.centerIn: parent
              text: "🌱  Plant a new seed"
              color: Commons.Color.background
              font.family: Style.font.family; font.pixelSize: 12; font.bold: true
            }
            MouseArea { id: newMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: { root.plantNew(); root.cardOpen = false } }
          }

          // the shelf
          Item {
            width: parent.width
            height: 18
            Text {
              textFormat: Text.PlainText
              anchors.bottom: parent.bottom
              text: "Your shelf"
              color: root.alpha(Commons.Color.popups.text, 0.55)
              font.family: Style.font.family; font.pixelSize: 11; font.bold: true
            }
            Text {
              textFormat: Text.PlainText
              anchors { right: parent.right; bottom: parent.bottom }
              text: root.collection.length + (root.collection.length === 1 ? " plant" : " plants")
              color: root.alpha(Commons.Color.popups.text, 0.4)
              font.family: Style.font.family; font.pixelSize: 10
            }
          }
          Item {
            width: parent.width
            height: 58
            Text {
              visible: root.collection.length === 0
              textFormat: Text.PlainText
              anchors.centerIn: parent
              anchors.verticalCenterOffset: -6
              text: "Your first bloom will sit here 🌱"
              color: root.alpha(Commons.Color.popups.text, 0.4)
              font.family: Style.font.family; font.pixelSize: 11
            }
            Row {                                   // newest on the right, up to 6
              anchors.bottom: plank.top
              anchors.bottomMargin: -3
              spacing: -4
              Repeater {
                model: root.collection.slice(-6)
                MiniPlant { required property var modelData; entry: modelData }
              }
            }
            Rectangle {                             // a wooden plank
              id: plank
              anchors.bottom: parent.bottom
              width: parent.width; height: 6; radius: 3
              gradient: Gradient {
                GradientStop { position: 0; color: root.alpha(root.mix("#a87b55", root.accent, 0.15), 1) }
                GradientStop { position: 1; color: root.alpha(root.mix("#6f4c33", root.accent, 0.1), 1) }
              }
            }
          }
        }
      }
    }
  }

  // ---------------------------------------------------------- components
  // A floating panel styled like Omarchy's popups, with a soft shadow, that
  // grows out of the plant when shown.
  component Popover: Item {
    id: pop
    property bool shown: false
    default property alias content: inner.data
    visible: opacity > 0.01
    opacity: shown ? 1 : 0
    scale: shown ? 1 : 0.92
    transformOrigin: Item.BottomLeft
    Behavior on opacity { NumberAnimation { duration: 160 } }
    Behavior on scale { NumberAnimation { duration: 220; easing.type: Easing.OutBack } }
    Rectangle {
      id: panel
      anchors.fill: parent
      radius: Math.max(12, Style.cornerRadius + 4)
      color: root.alpha(root.mix(Commons.Color.popups.background, root.accent, 0.03), 1)
      border.width: 1
      border.color: root.alpha(Commons.Color.popups.border, 0.45)
      layer.enabled: true
      layer.effect: MultiEffect {
        shadowEnabled: true; shadowColor: "#000000"; shadowOpacity: 0.35
        shadowBlur: 0.8; shadowVerticalOffset: 3; autoPaddingEnabled: true
      }
    }
    Item { id: inner; anchors.fill: parent }
  }

  // A rounded button.
  component Pill: Rectangle {
    id: pill
    property string label
    property bool primary: false
    signal clicked()
    width: pillLabel.implicitWidth + 24
    height: 28
    radius: 14
    color: primary ? (pillMouse.containsMouse ? Qt.lighter(root.accent, 1.1) : root.accent)
                   : (pillMouse.containsMouse ? root.alpha(Commons.Color.popups.text, 0.14) : root.alpha(Commons.Color.popups.text, 0.07))
    Behavior on color { ColorAnimation { duration: 120 } }
    scale: pillMouse.pressed ? 0.96 : 1
    Behavior on scale { NumberAnimation { duration: 90 } }
    Text {
      id: pillLabel
      textFormat: Text.PlainText
      anchors.centerIn: parent
      text: pill.label
      color: pill.primary ? Commons.Color.background : Commons.Color.popups.text
      font.family: Style.font.family; font.pixelSize: 12; font.bold: pill.primary
    }
    MouseArea { id: pillMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: pill.clicked() }
  }

  // Label + rounded bar + detail on the right.
  component Meter: Column {
    id: meter
    property string label
    property string detail
    property real value
    property color tint
    width: parent ? parent.width : 200
    spacing: 4
    Item {
      width: meter.width; height: 14
      Text {
        textFormat: Text.PlainText
        text: meter.label
        color: root.alpha(Commons.Color.popups.text, 0.75)
        font.family: Style.font.family; font.pixelSize: 11
      }
      Text {
        textFormat: Text.PlainText
        anchors.right: parent.right
        text: meter.detail
        color: root.alpha(Commons.Color.popups.text, 0.5)
        font.family: Style.font.family; font.pixelSize: 10
      }
    }
    Rectangle {
      width: meter.width; height: 7; radius: 3.5
      color: root.alpha(Commons.Color.popups.text, 0.09)
      Rectangle {
        width: Math.max(height, parent.width * Math.max(0, Math.min(1, meter.value)))
        height: parent.height; radius: 3.5
        visible: meter.value > 0.005
        gradient: Gradient {
          orientation: Gradient.Horizontal
          GradientStop { position: 0; color: Qt.darker(meter.tint, 1.12) }
          GradientStop { position: 1; color: Qt.lighter(meter.tint, 1.15) }
        }
        Behavior on width { NumberAnimation { duration: 500; easing.type: Easing.OutCubic } }
      }
    }
  }

  // A number with a small caption under it.
  component Stat: Column {
    id: stat
    property string value
    property string label
    spacing: 1
    Text {
      textFormat: Text.PlainText
      width: stat.width
      horizontalAlignment: Text.AlignHCenter
      text: stat.value
      color: Commons.Color.popups.text
      font.family: Style.font.family; font.pixelSize: 13; font.bold: true
    }
    Text {
      textFormat: Text.PlainText
      width: stat.width
      horizontalAlignment: Text.AlignHCenter
      text: stat.label
      color: root.alpha(Commons.Color.popups.text, 0.45)
      font.family: Style.font.family; font.pixelSize: 9
    }
  }

  // A plant from your shelf, in bloom, drawn small.
  component MiniPlant: Item {
    id: mini
    property var entry
    width: 40
    height: 50
    Canvas {
      id: miniCanvas
      width: root.plantW * 2
      height: root.plantH * 2
      scale: mini.width / root.plantW / 2
      transformOrigin: Item.TopLeft
      antialiasing: true
      onPaint: {
        var ctx = getContext("2d")
        ctx.reset()
        ctx.scale(2, 2)
        Species.draw(ctx, root.plantW, root.plantH, {
          species: mini.entry.species, growth: 1, droop: 0, seed: mini.entry.seed || 1, pal: root.palette(0)
        })
      }
      Connections { target: root; function onAccentChanged() { miniCanvas.requestPaint() } }
    }
    MouseArea {
      anchors.fill: parent
      hoverEnabled: true
      onEntered: root.showTip((Species.species[mini.entry.species] || {}).name + " · bloomed "
                              + Qt.formatDate(new Date(mini.entry.bloomedOn + "T00:00:00"), "MMM d")
                              + " after " + mini.entry.days + (mini.entry.days === 1 ? " day" : " days"), 4000)
    }
  }

  // Preview and testing: omarchy-shell garden <command>
  IpcHandler {
    target: "garden"
    function info(): string {
      return root.info.name + " day " + root.dayNum() + ", " + Math.floor(root.progress * 100) + "% grown, water "
             + Math.round(root.water) + ", collection " + root.collection.length
    }
    function grow(percent: string): string { root.setGrowthPercent(percent); return info() }
    function water(level: string): string {
      var before = root.water
      root.water = Math.max(0, Math.min(100, Number(level) || 0))
      if (root.water > before + 10) drops.start()
      root.save(); root.repaint(); return info()
    }
    function plantSpecies(name: string): string {
      if (!Species.species[name]) return "species: " + Species.order.join(" ")
      root.plantNew(name); return info()
    }
    // Focus from the keyboard: `omarchy-shell garden focus 25`, `... stop`.
    function focus(minutes: string): string { root.startFocus(minutes); return "focusing until " + Qt.formatTime(new Date(root.focusEndsAt), "h:mm") }
    function stop(): string { root.stopFocus(); return "stopped" }
    function finish(): string { if (root.focusing) root.finishFocus(); return "done" }
    function bloom(): string { root.setGrowthPercent(100); root.celebrate(); return info() }
    function card(state: string): string { root.cardOpen = state !== "close"; return root.cardOpen ? "open" : "closed" }
    // Screenshots: put the sun at `pct` percent of a 25-minute session; sparkle on demand.
    function sun(pct: string): string {
      var len = 25 * 60000
      root.now = Date.now()
      root.focusStartedAt = root.now - Math.max(0, Math.min(99.9, Number(pct) || 0)) / 100 * len
      root.focusEndsAt = root.focusStartedAt + len
      return root.focusLeft
    }
    function sparkle(): string { sparkles.burst(30); return "ok" }
    function hush(): string { root.tip = ""; return "ok" }
    // Sample data for screenshots (undo with `reset`).
    function demo(): string {
      root.collection = [{ species: "daisy", seed: 11, bloomedOn: "2026-10-12", days: 6 },
                         { species: "tulip", seed: 27, bloomedOn: "2026-10-19", days: 7 },
                         { species: "fern", seed: 5, bloomedOn: "2026-10-27", days: 8 }]
      root.statsDay = root.today(); root.todayFocus = 100; root.todaySessions = 4; root.todayBreaks = 3
      root.todayActive = 212; root.longestStretch = 55
      root.plantNew("sunflower"); root.setGrowthPercent(64); root.water = 88
      root.startFocus(25); root.focusStartedAt = Date.now() - 10 * 60000; root.focusEndsAt = root.focusStartedAt + 25 * 60000
      root.tip = ""; root.repaint(); return info()
    }
    // Start over: empty shelf, a fresh daisy seed.
    function reset(): string {
      if (root.focusing) root.focusEndsAt = 0
      root.breakDue = false; root.collection = []; root.water = 100; root.totalFocus = 0; root.activeMinutes = 0
      root.statsDay = ""; root.newDay()
      root.plantNew("daisy"); return info()
    }
  }
}
