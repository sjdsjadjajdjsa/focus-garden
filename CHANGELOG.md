# Changelog

## 0.2.1

A few small fixes.

- The hover tip now goes away shortly after the mouse leaves the plant,
  instead of lingering for ten minutes.
- Starting a focus session while one is already running (for example
  `garden focus 50` from a keybind) now counts the time you already focused
  before starting the new session, instead of losing it.
- "Day N" in the terrarium now updates when midnight passes, without needing
  to reopen the card.

## 0.2.0

A new card.

- The icons' license notices (Lucide's ISC license, and the MIT license for
  the icons derived from Feather) now ship with the plugin in `LICENSE-lucide`.
- A terrarium at the top: your plant under glass, on a little grassy hill,
  under a sky that follows the time of day (dawn, blue day, golden hour,
  dusk, and a starry night with fireflies). During a focus session the sun
  crosses the glass as the minutes go by.
- Growth is a vine that sprouts leaves as it grows; water is a glass tube
  with a rippling surface that turns amber when your plant is parched.
- Start 25, 50 or 90 minutes from the card. Break time is a compact box
  with a Skip button, and a fully grown plant gets a "Plant a new seed"
  button.
- This week: seven seedlings, one per day, taller the more you focused. A
  day with an hour or more of focus gets a flower. (Days are kept for two
  weeks, starting from this version.)
- Line icons everywhere instead of emoji, one button height, a solid panel
  tinted by your theme, and a wooden shelf with some depth.
- Hovering the plant shows its status as icon rows, including screen time
  and your longest stretch.
- Short screens get a shorter terrarium so the whole card fits.
- `omarchy-shell garden sky <hour>` previews the sky at any hour.

## 0.1.0

First release.

- A plant in the bottom-left corner that grows while you use your computer,
  from seed to sprout to bloom over a week or two of normal use.
- Focus sessions (25 or 50 minutes) from the plant's card, or
  `omarchy-shell garden focus 25`. A little sun rises over the plant and
  crosses its arc as the session runs, and the plant grows twice as fast.
- When a session ends: a short, real break idea (stretch, rest your eyes,
  drink some water…). Stepping away for 5 minutes waters the plant.
- Water drains over about 2.5 hours of nonstop use; a thirsty plant droops,
  fades, grows slower, and asks for a break once.
- Today at a glance: focus time, sessions, breaks, screen time and your
  longest stretch without a break.
- Six species (daisy, tulip, fern, sunflower, cactus, bonsai), drawn in code
  so they grow smoothly, each one a little different, colored by your theme.
- A shelf of every plant you've grown.
- Hides during fullscreen apps. No network, no AI, no keyboard focus.
