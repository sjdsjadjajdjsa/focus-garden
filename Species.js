.pragma library

// Focus Garden's plants, drawn in code so they grow smoothly.
//
// draw(ctx, w, h, plant) paints one plant in its pot:
//   plant.species  one of the keys of `species`
//   plant.growth   0..1 (seed → sprout → young plant → bud → bloom)
//   plant.droop    0..1 (0 = perky, 1 = very thirsty)
//   plant.seed     integer, so every plant of a species looks a bit different
//   plant.pal      colors as {r, g, b} (0..1): leaf, stem, flower, sun, petal,
//                  center, bark, pot, band, soil
// Coordinates are logical pixels (the canvas is 100 x 124); the caller scales
// the context for sharpness.

var species = {
  tulip:     { name: "Tulip",     emoji: "🌷", minutes: 1500 },
  sunflower: { name: "Sunflower", emoji: "🌻", minutes: 2100 },
  daisy:     { name: "Daisy",     emoji: "🌼", minutes: 1200 },
  fern:      { name: "Fern",      emoji: "🌿", minutes: 1500 },
  cactus:    { name: "Cactus",    emoji: "🌵", minutes: 2400 },
  bonsai:    { name: "Bonsai",    emoji: "🌳", minutes: 2700 },
}
var order = ["daisy", "tulip", "fern", "sunflower", "cactus", "bonsai"]

// ---------------------------------------------------------------- helpers
function rng(seed) {                       // mulberry32: small, deterministic
  var a = seed >>> 0
  return function() {
    a = (a + 0x6D2B79F5) >>> 0
    var t = a
    t = Math.imul(t ^ (t >>> 15), t | 1)
    t ^= t + Math.imul(t ^ (t >>> 7), t | 61)
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296
  }
}
function clamp(x, a, b) { return Math.max(a, Math.min(b, x)) }
function seg(g, a, b) { return clamp((g - a) / (b - a), 0, 1) }
function ease(x) { return 1 - Math.pow(1 - x, 2) }

// Colors are {r, g, b} in 0..1. shade(c, +k) lightens toward white, -k darkens.
function shade(c, k) {
  if (k >= 0) return { r: c.r + (1 - c.r) * k, g: c.g + (1 - c.g) * k, b: c.b + (1 - c.b) * k }
  return { r: c.r * (1 + k), g: c.g * (1 + k), b: c.b * (1 + k) }
}
function rgba(c, a) {
  return "rgba(" + Math.round(clamp(c.r, 0, 1) * 255) + "," + Math.round(clamp(c.g, 0, 1) * 255) + ","
    + Math.round(clamp(c.b, 0, 1) * 255) + "," + (a === undefined ? 1 : a) + ")"
}

// A stem from (x, y) up to its tip; a thirsty plant bends over.
function stem(ctx, x, y, len, lean, droop, width, color) {
  var dir = lean >= 0 ? 1 : -1
  var tx = x + lean + dir * len * 0.55 * droop
  var ty = y - len * (1 - 0.42 * droop)
  var cx = x + lean * 0.3 + dir * len * 0.08 * droop
  var cy = y - len * 0.62
  function path() { ctx.beginPath(); ctx.moveTo(x, y); ctx.quadraticCurveTo(cx, cy, tx, ty) }
  ctx.lineCap = "round"
  path(); ctx.lineWidth = width; ctx.strokeStyle = rgba(shade(color, -0.18)); ctx.stroke()
  ctx.save(); ctx.translate(-width * 0.18, 0)       // a soft highlight down one side
  path(); ctx.lineWidth = Math.max(0.6, width * 0.35); ctx.strokeStyle = rgba(shade(color, 0.28), 0.8); ctx.stroke()
  ctx.restore()
  return {
    at: function(t) {
      var mt = 1 - t
      return {
        x: mt * mt * x + 2 * mt * t * cx + t * t * tx,
        y: mt * mt * y + 2 * mt * t * cy + t * t * ty,
        angle: Math.atan2(2 * mt * (cx - x) + 2 * t * (tx - cx), -(2 * mt * (cy - y) + 2 * t * (ty - cy)))
      }
    },
    tip: { x: tx, y: ty }
  }
}

// An almond leaf from (x, y), pointing `angle` radians from straight up,
// shaded from a deeper base to a lighter tip, with a fine midrib.
function leaf(ctx, x, y, angle, len, wid, color, rib) {
  if (len < 0.5) return
  ctx.save()
  ctx.translate(x, y)
  ctx.rotate(angle)
  var grad = ctx.createLinearGradient(-wid, 0, wid, -len)
  grad.addColorStop(0, rgba(shade(color, -0.22)))
  grad.addColorStop(0.55, rgba(color))
  grad.addColorStop(1, rgba(shade(color, 0.22)))
  ctx.beginPath()
  ctx.moveTo(0, 0)
  ctx.bezierCurveTo(wid * 1.15, -len * 0.25, wid * 0.9, -len * 0.75, 0, -len)
  ctx.bezierCurveTo(-wid * 0.9, -len * 0.75, -wid * 1.15, -len * 0.25, 0, 0)
  ctx.fillStyle = grad
  ctx.fill()
  ctx.lineWidth = 0.5
  ctx.strokeStyle = rgba(shade(color, -0.35), 0.5)
  ctx.stroke()
  if (rib !== false && len > 5) {
    ctx.beginPath()
    ctx.moveTo(0, -len * 0.06)
    ctx.quadraticCurveTo(wid * 0.12, -len * 0.5, 0, -len * 0.88)
    ctx.lineWidth = 0.55
    ctx.strokeStyle = rgba(shade(color, 0.35), 0.75)
    ctx.stroke()
  }
  ctx.restore()
}

// Thirsty plants sag: leaves rotate toward the ground.
function sag(angle, droop) {
  var down = angle >= 0 ? Math.PI * 0.62 : -Math.PI * 0.62
  return angle + (down - angle) * droop * 0.55
}

// One petal: a rounded teardrop with a soft gradient from the middle out.
function petal(ctx, len, wid, color) {
  var grad = ctx.createLinearGradient(0, 0, 0, -len)
  grad.addColorStop(0, rgba(shade(color, -0.12)))
  grad.addColorStop(0.6, rgba(color))
  grad.addColorStop(1, rgba(shade(color, 0.18)))
  ctx.beginPath()
  ctx.moveTo(0, 0)
  ctx.bezierCurveTo(wid, -len * 0.3, wid * 0.85, -len, 0, -len)
  ctx.bezierCurveTo(-wid * 0.85, -len, -wid, -len * 0.3, 0, 0)
  ctx.fillStyle = grad
  ctx.fill()
  ctx.lineWidth = 0.45
  ctx.strokeStyle = rgba(shade(color, -0.3), 0.45)
  ctx.stroke()
}

function flowerHead(ctx, x, y, open, size, petals, petalColor, centerColor, seedy) {
  if (open <= 0) return
  if (open < 0.35) {                         // a closed bud first
    var b = open / 0.35
    ctx.save()
    ctx.translate(x, y)
    petal(ctx, size * 1.1 * b, size * 0.55 * b, shade(petalColor, -0.08))
    ctx.restore()
    return
  }
  var o = (open - 0.35) / 0.65
  for (var layer = 0; layer < 2; layer++) {  // two rings, the back one a touch darker
    var n = layer === 0 ? petals : Math.max(5, Math.floor(petals * 0.6))
    for (var i = 0; i < n; i++) {
      ctx.save()
      ctx.translate(x, y)
      ctx.rotate(i / n * Math.PI * 2 + layer * Math.PI / n)
      petal(ctx, size * (layer ? 0.75 : 1) * (0.55 + 0.45 * o), size * (layer ? 0.3 : 0.34),
            layer ? petalColor : shade(petalColor, -0.1))
      ctx.restore()
    }
  }
  var cr = size * (0.3 + 0.12 * o)
  var cg = ctx.createRadialGradient(x - cr * 0.3, y - cr * 0.3, cr * 0.1, x, y, cr)
  cg.addColorStop(0, rgba(shade(centerColor, 0.25)))
  cg.addColorStop(1, rgba(shade(centerColor, -0.2)))
  ctx.beginPath()
  ctx.arc(x, y, cr, 0, Math.PI * 2)
  ctx.fillStyle = cg
  ctx.fill()
  if (seedy) {                               // sunflower seeds in a spiral
    for (var s = 0; s < 22; s++) {
      var a = s * 2.39996, rr = cr * 0.85 * Math.sqrt(s / 22)
      ctx.beginPath()
      ctx.arc(x + Math.cos(a) * rr, y + Math.sin(a) * rr, 0.45, 0, Math.PI * 2)
      ctx.fillStyle = rgba(shade(centerColor, -0.45), 0.8)
      ctx.fill()
    }
  }
}

// ------------------------------------------------------------------- pot
function pot(ctx, w, h, pal, r) {
  var cx = w / 2, top = h - 33, bw = 42, tw = 56, rimH = 8
  // soft contact shadow
  var sh = ctx.createRadialGradient(cx, h - 2, 2, cx, h - 2, tw * 0.62)
  sh.addColorStop(0, "rgba(0,0,0,0.32)")
  sh.addColorStop(1, "rgba(0,0,0,0)")
  ctx.fillStyle = sh
  ctx.fillRect(cx - tw, h - 9, tw * 2, 9)
  // body, lit from the upper left
  var body = ctx.createLinearGradient(cx - bw / 2, 0, cx + bw / 2, 0)
  body.addColorStop(0, rgba(shade(pal.pot, 0.12)))
  body.addColorStop(0.35, rgba(shade(pal.pot, 0.04)))
  body.addColorStop(1, rgba(shade(pal.pot, -0.28)))
  ctx.beginPath()
  ctx.moveTo(cx - tw / 2 + 3, top + rimH - 1)
  ctx.lineTo(cx + tw / 2 - 3, top + rimH - 1)
  ctx.lineTo(cx + bw / 2, h - 5)
  ctx.quadraticCurveTo(cx + bw / 2, h - 2, cx + bw / 2 - 3, h - 2)
  ctx.lineTo(cx - bw / 2 + 3, h - 2)
  ctx.quadraticCurveTo(cx - bw / 2, h - 2, cx - bw / 2, h - 5)
  ctx.closePath()
  ctx.fillStyle = body
  ctx.fill()
  // a thin band in the theme's accent
  ctx.save()
  ctx.clip()
  ctx.fillStyle = rgba(pal.band, 0.85)
  ctx.fillRect(cx - tw / 2, top + rimH + 7, tw, 2.2)
  ctx.restore()
  // rim
  var rim = ctx.createLinearGradient(0, top, 0, top + rimH)
  rim.addColorStop(0, rgba(shade(pal.pot, 0.22)))
  rim.addColorStop(1, rgba(shade(pal.pot, -0.06)))
  ctx.beginPath()
  ctx.roundedRect(cx - tw / 2, top, tw, rimH, 3, 3)
  ctx.fillStyle = rim
  ctx.fill()
  ctx.beginPath()                            // highlight along the rim's top edge
  ctx.moveTo(cx - tw / 2 + 4, top + 1.2)
  ctx.lineTo(cx + tw / 2 - 4, top + 1.2)
  ctx.lineWidth = 0.8
  ctx.strokeStyle = rgba(shade(pal.pot, 0.45), 0.7)
  ctx.stroke()
  // soil, with a few pebbles
  var soil = ctx.createLinearGradient(0, top - 3, 0, top + 3)
  soil.addColorStop(0, rgba(shade(pal.soil, 0.1)))
  soil.addColorStop(1, rgba(shade(pal.soil, -0.25)))
  ctx.beginPath()
  ctx.ellipse(cx - tw / 2 + 4, top - 2, tw - 8, 5.5)
  ctx.fillStyle = soil
  ctx.fill()
  for (var i = 0; i < 6; i++) {
    ctx.beginPath()
    ctx.arc(cx - tw / 2 + 9 + r() * (tw - 18), top + 0.6 - r() * 2.2, 0.5 + r() * 0.6, 0, Math.PI * 2)
    ctx.fillStyle = rgba(shade(pal.soil, 0.35 + r() * 0.2), 0.8)
    ctx.fill()
  }
  return { x: cx, y: top + 1 }
}

// ------------------------------------------------------------------ draw
function draw(ctx, w, h, plant) {
  var pal = plant.pal
  var g = clamp(plant.growth, 0, 1)
  var d = clamp(plant.droop, 0, 1)
  var r = rng(plant.seed || 1)
  var base = pot(ctx, w, h, pal, rng((plant.seed || 1) ^ 0x5eed))
  var x = base.x, y = base.y

  if (g < 0.03) {                            // seed: a mound with a peek of green
    var mound = ctx.createRadialGradient(x - 1, y - 4, 1, x, y - 2, 7)
    mound.addColorStop(0, rgba(shade(pal.soil, 0.25)))
    mound.addColorStop(1, rgba(pal.soil))
    ctx.beginPath()
    ctx.ellipse(x - 6, y - 5, 12, 7)
    ctx.fillStyle = mound
    ctx.fill()
    if (g > 0.012) leaf(ctx, x, y - 4, -0.3, 3, 1.6, pal.leaf, false)
    return
  }
  if (g < 0.12) {                            // sprout: two round seed leaves
    var sp = seg(g, 0.03, 0.12)
    var s = stem(ctx, x, y, 6 + 10 * sp, (r() - 0.5) * 3, d, 1.7, pal.stem)
    leaf(ctx, s.tip.x, s.tip.y, sag(-1.15, d), 5 + 3.5 * sp, 3.4, pal.leaf, false)
    leaf(ctx, s.tip.x, s.tip.y, sag(1.15, d), 5 + 3.5 * sp, 3.4, pal.leaf, false)
    return
  }
  var k = seg(g, 0.12, 1)
  var bloom = seg(g, 0.8, 1)
  var draws = { tulip: tulip, sunflower: sunflower, daisy: daisy, fern: fern, cactus: cactus, bonsai: bonsai }
  ;(draws[plant.species] || daisy)(ctx, x, y, k, bloom, d, pal, r)
}

function tulip(ctx, x, y, k, bloom, d, pal, r) {
  var len = 18 + 44 * ease(k)
  leaf(ctx, x - 1, y, sag(-0.33 - 0.1 * r(), d), 14 + 22 * k, 6, pal.leaf)
  leaf(ctx, x + 1, y, sag(0.4 + 0.1 * r(), d), 12 + 20 * k, 5.5, shade(pal.leaf, -0.06))
  var s = stem(ctx, x, y, len, (r() - 0.5) * 4, d, 2.3, pal.stem)
  if (bloom > 0) {
    var t = s.tip, o = bloom, cw = 6.5 + 4 * o
    ctx.save()
    ctx.translate(t.x, t.y)
    ctx.rotate(s.at(1).angle)
    var order = [-1, 1, 0]                   // side petals behind, the middle in front
    for (var i = 0; i < 3; i++) {
      var side = order[i]
      ctx.save()
      ctx.translate(side * cw * 0.42, 0)
      ctx.rotate(side * 0.22)
      petal(ctx, cw * 2.1, cw * (side === 0 ? 0.95 : 0.85), side === 0 ? pal.flower : shade(pal.flower, -0.14))
      ctx.restore()
    }
    ctx.restore()
  }
}

function sunflower(ctx, x, y, k, bloom, d, pal, r) {
  var len = 20 + 56 * ease(k)
  var s = stem(ctx, x, y, len, (r() - 0.5) * 5, d, 3, pal.stem)
  var n = Math.floor(2 + k * 6)
  for (var i = 0; i < n; i++) {
    var t = 0.18 + i / 8 * 0.7
    var p = s.at(t)
    var side = i % 2 ? 1 : -1
    leaf(ctx, p.x, p.y, sag(p.angle + side * 1.15, d), 9 + 6 * k * (1 - t * 0.4), 6.5, i % 2 ? pal.leaf : shade(pal.leaf, -0.05))
  }
  if (bloom > 0) flowerHead(ctx, s.tip.x, s.tip.y, bloom, 7.5 + 4 * bloom, 16, pal.sun, pal.center, true)
}

function daisy(ctx, x, y, k, bloom, d, pal, r) {
  for (var i = 0; i < 4; i++)                // a leafy rosette at the base
    leaf(ctx, x, y, sag(-1.25 + i * 0.83, d), 6 + 5 * k, 3.6, i % 2 ? pal.leaf : shade(pal.leaf, -0.07))
  var stems = [{ lean: -9, len: 0.8 }, { lean: 3, len: 1 }, { lean: 12, len: 0.7 }]
  for (var j = 0; j < stems.length; j++) {
    var st = stems[j]
    var grow = clamp(k * 1.3 - j * 0.15, 0, 1)
    if (grow <= 0) continue
    var s = stem(ctx, x + (j - 1) * 2, y, (14 + 34 * ease(grow)) * st.len, st.lean * grow + (r() - 0.5) * 2, d, 1.4, pal.stem)
    var p = s.at(0.35)
    leaf(ctx, p.x, p.y, sag(p.angle + (j % 2 ? 1 : -1) * 1.0, d), 6 + 6 * grow, 3.4, pal.leaf)
    var b = clamp(bloom * 1.2 - j * 0.1, 0, 1)
    if (b > 0) flowerHead(ctx, s.tip.x, s.tip.y, b, 4.2 + 1.6 * b, 12, pal.petal, pal.flower, false)
  }
}

function fern(ctx, x, y, k, bloom, d, pal, r) {
  var fronds = 3 + Math.floor(k * 4)
  for (var f = 0; f < fronds; f++) {
    var a = -1.0 + f / Math.max(1, fronds - 1) * 2.0 + (r() - 0.5) * 0.2
    var len = (16 + 34 * ease(k)) * (0.75 + 0.25 * Math.cos(a))
    var col = f % 2 ? pal.leaf : shade(pal.leaf, -0.08)
    var s = stem(ctx, x, y, len, Math.sin(a) * len * 0.9, Math.max(d, 0.25), 1.1, pal.stem)
    var leaflets = Math.floor(6 + 8 * k)
    for (var i = 1; i < leaflets; i++) {
      var t = i / leaflets
      var p = s.at(t)
      var ll = (5.5 - 4 * t) * (0.6 + 0.4 * k)
      leaf(ctx, p.x, p.y, sag(p.angle - 1.25, d), ll, 1.9, col, false)
      leaf(ctx, p.x, p.y, sag(p.angle + 1.25, d), ll, 1.9, col, false)
    }
  }
  if (bloom > 0) {                           // a fresh fiddlehead uncurling in the middle
    ctx.beginPath()
    ctx.arc(x, y - 10 - 8 * bloom, 3 + 1.5 * bloom, Math.PI * 0.2, Math.PI * 2.0)
    ctx.lineWidth = 1.7
    ctx.lineCap = "round"
    ctx.strokeStyle = rgba(shade(pal.leaf, 0.3))
    ctx.stroke()
  }
}

function cactus(ctx, x, y, k, bloom, d, pal, r) {
  var hgt = 12 + 40 * ease(k)
  var wid = 12 + 6 * k
  var sq = 1 - 0.18 * d                      // a thirsty cactus looks shrivelled
  function body(cx, by, bw, bh) {
    var w2 = bw * sq
    var grad = ctx.createLinearGradient(cx - w2 / 2, 0, cx + w2 / 2, 0)
    grad.addColorStop(0, rgba(shade(pal.leaf, 0.15)))
    grad.addColorStop(0.45, rgba(pal.leaf))
    grad.addColorStop(1, rgba(shade(pal.leaf, -0.3)))
    ctx.beginPath()
    ctx.roundedRect(cx - w2 / 2, by - bh, w2, bh, w2 / 2, w2 / 2)
    ctx.fillStyle = grad
    ctx.fill()
    ctx.lineWidth = 0.6
    ctx.strokeStyle = rgba(shade(pal.leaf, -0.35), 0.6)
    for (var i = -1; i <= 1; i++) {          // ribs
      ctx.beginPath()
      ctx.moveTo(cx + i * w2 * 0.24, by - 2)
      ctx.lineTo(cx + i * w2 * 0.24, by - bh + w2 * 0.4)
      ctx.stroke()
    }
    for (var j = 0; j < bh / 5; j++) {       // tiny spines
      ctx.beginPath()
      ctx.arc(cx + (j % 2 ? 1 : -1) * w2 * 0.36, by - 4 - j * 5, 0.4, 0, Math.PI * 2)
      ctx.fillStyle = "rgba(255,255,240,0.75)"
      ctx.fill()
    }
  }
  if (k > 0.45) {                            // arms, joined to the body
    var arm = seg(k, 0.45, 1), ay = y - hgt * 0.38
    ctx.beginPath(); ctx.roundedRect(x - wid * 0.85, ay - 5, wid * 0.6, 5, 2.5, 2.5)
    ctx.fillStyle = rgba(shade(pal.leaf, -0.08)); ctx.fill()
    body(x - wid * 0.78, ay, 7, 6 + 14 * arm)
  }
  if (k > 0.7) {
    var arm2 = seg(k, 0.7, 1), by = y - hgt * 0.55
    ctx.beginPath(); ctx.roundedRect(x + wid * 0.25, by - 5, wid * 0.6, 5, 2.5, 2.5)
    ctx.fillStyle = rgba(shade(pal.leaf, -0.16)); ctx.fill()
    body(x + wid * 0.74, by, 6.5, 5 + 11 * arm2)
  }
  body(x, y, wid, hgt)
  if (bloom > 0) flowerHead(ctx, x, y - hgt + 1.5, bloom, 3.8 + 2 * bloom, 9, pal.flower, pal.sun, false)
}

function bonsai(ctx, x, y, k, bloom, d, pal, r) {
  var len = 14 + 30 * ease(k)
  function trunk(w, col) {
    ctx.beginPath()
    ctx.moveTo(x, y)
    ctx.bezierCurveTo(x - 10 * k, y - len * 0.35, x + 12 * k, y - len * 0.6, x + 2, y - len)
    ctx.lineWidth = w
    ctx.lineCap = "round"
    ctx.strokeStyle = col
    ctx.stroke()
  }
  trunk(3.2 + 3 * k, rgba(shade(pal.bark, -0.15)))
  ctx.save(); ctx.translate(-0.9, 0)
  trunk(1 + k, rgba(shade(pal.bark, 0.25), 0.7))
  ctx.restore()
  var pads = [[-14, -len * 0.62, 0.8], [13, -len * 0.75, 0.75], [-4, -len * 0.92, 0.7], [0, -len - 2, 1]]
  var n = Math.floor(1 + k * pads.length)
  for (var i = pads.length - Math.min(n, pads.length); i < pads.length; i++) {
    var pd = pads[i]
    var pw = (12 + 10 * k) * pd[2]
    var px = x + pd[0], py = y + pd[1] + 4 * d
    var grad = ctx.createRadialGradient(px - pw * 0.2, py - pw * 0.25, pw * 0.1, px, py, pw * 0.6)
    grad.addColorStop(0, rgba(shade(pal.leaf, 0.22)))
    grad.addColorStop(1, rgba(shade(pal.leaf, -0.18)))
    ctx.beginPath()
    ctx.ellipse(px - pw / 2, py - pw * 0.31, pw, pw * 0.62)
    ctx.fillStyle = grad
    ctx.fill()
    if (bloom > 0) {                         // blossoms dot the pads
      var dots = Math.floor(3 + 4 * bloom)
      for (var j = 0; j < dots; j++) {
        ctx.beginPath()
        ctx.arc(px + (r() - 0.5) * pw * 0.75, py + (r() - 0.5) * pw * 0.38, 1.1 + 0.9 * bloom, 0, Math.PI * 2)
        ctx.fillStyle = rgba(shade(pal.flower, r() * 0.25))
        ctx.fill()
      }
    }
  }
}
