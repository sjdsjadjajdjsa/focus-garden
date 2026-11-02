<div align="center">

# 🌱 Focus Garden

**A focus timer that grows a little plant in the corner of your Omarchy desktop.**

[![omarchy](https://img.shields.io/badge/Omarchy%204-e8a2c8?style=flat-square&label=plugin%20for&labelColor=13111c)](https://omarchy.org)
[![built with](https://img.shields.io/badge/QML%20·%20Quickshell-c6a0f6?style=flat-square&label=built%20with&labelColor=13111c)](https://quickshell.org)
[![license](https://img.shields.io/badge/MIT-c6a0f6?style=flat-square&label=license&labelColor=13111c)](LICENSE)

<img src="docs/images/hero.webp" alt="Focus Garden's card above a sunflower in a pot: a 14:59 focus countdown, growth and water bars, today's stats (1h 40m focused, 4 sessions, 3 breaks) and a shelf of three small potted plants" width="320">

</div>

Focus Garden puts a small potted plant in the bottom-left corner of your
screen. It grows while you work, grows **twice as fast while you focus**, and
gets thirsty if you never take a break. Over days and weeks, your focused
hours turn into a shelf of plants.

## What it does

- **Focus sessions.** Click the plant and start a 25 or 50 minute session. A
  little sun rises over your plant and crosses the sky as the time passes.
- **Real breaks.** When a session ends, you get a short break with a small,
  useful idea: stretch, rest your eyes, refill your water. Step away for 5
  minutes and your plant gets a drink.
- **Gentle nudges.** After about an hour and a half of nonstop work your plant
  starts to droop, and it asks for a break once. No notifications, no sounds.
- **Your day at a glance.** Focus time, sessions, breaks, screen time and your
  longest stretch without a break.
- **A plant that's really growing.** Every plant goes from seed to sprout to
  bloom over a week or two of normal use, drawn in code so it grows smoothly
  instead of jumping between pictures.
- **Six species, each one different.** Daisy, tulip, fern, sunflower, cactus
  and bonsai, colored by your Omarchy theme. When one blooms it goes on your
  shelf and a new seed is planted.

<div align="center">
<img src="docs/images/species.webp" alt="Six potted plants in bloom: daisy, tulip, fern, sunflower, cactus and bonsai" width="100%">
<br>
<img src="docs/images/stages.webp" alt="A tulip growing from a seed to a sprout, a young plant, a bud, and a pink flower" width="100%">
</div>

## Install

Needs **Omarchy 4**. Nothing else.

```bash
omarchy plugin add https://github.com/sjdsjadjajdjsa/focus-garden.git --enable
```

Your first seed is planted right away in the bottom-left corner.

## Use

- **Hover** the plant to see how it's doing.
- **Click** it for the card: start a focus session, see today's stats, and
  your shelf.
- **From the keyboard**, bind these in `~/.config/hypr/bindings.lua`:

```lua
o.bind("SUPER + F12", "Focus 25 minutes", "omarchy-shell garden focus 25")
o.bind("SUPER + SHIFT + F12", "Stop focusing", "omarchy-shell garden stop")
```

## How it grows

| | |
|---|---|
| Growth | One step for every minute you're at the computer, two while you focus. A thirsty plant grows at half speed, a parched one not at all. |
| Water | Drains over about 2.5 hours of nonstop use and refills while you're away. Five minutes away is a full drink and counts as a break. Watching a video without touching the keyboard counts as away. |
| Bloom | 20 to 45 hours of use, depending on the species. |

<div align="center">
<img src="docs/images/thirst.webp" alt="The same tulip upright and green, and thirsty, bent over and faded" width="240">
</div>

## Privacy

Focus Garden doesn't use the network or any AI, and it doesn't read what's on
your screen. It only notices whether you've touched the keyboard or mouse in
the last minute. Everything it knows is in one file,
`~/.local/state/focus-garden/state.json`; the only command it ever runs is
`mkdir -p` for that folder. It never takes keyboard focus, and it hides
during fullscreen apps.

## Remove

```bash
omarchy plugin remove cj.focus-garden
rm -rf ~/.local/state/focus-garden   # forget your garden too
```

## For tinkerers

```bash
omarchy-shell garden info            # how the plant is doing
omarchy-shell garden focus 25        # start a session (1–180 minutes)
omarchy-shell garden stop
omarchy-shell garden plantSpecies fern   # daisy tulip fern sunflower cactus bonsai (replaces the current plant)
```

- **`Garden.qml`** is the plugin: growing, watering, focus sessions, the card.
- **`Species.js`** draws the plants. Each species is one small function.

## License

MIT
