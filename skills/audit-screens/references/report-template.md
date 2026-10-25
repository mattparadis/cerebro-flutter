# `<location>` — <route name or path>

Captured: <date> · device <name> (<w>×<h> dp) · themes: light, dark · fonts: <real|fallback>

![light](../screens/<id-light>.png) ![dark](../screens/<id-dark>.png)

## Strengths

- <genuine strength 1, with the element it refers to>
- <genuine strength 2>

## Findings

| # | Severity | Element | Observation (evidence) | Why it matters | Fix (Flutter) |
|---|---|---|---|---|---|
| 1 | 3 | `Edit profile` icon button | 32×32 dp at (349, 85) in `tappables_below_min` | Below the 48 dp minimum; hard to hit, fails a11y | Remove the `SizedBox(32)` wrapper; use `IconButton` default constraints or `visualDensity` |
| 2 | 3 | Card date caption | `#BDBDBD` on white in light theme (~1.8:1) | Fails WCAG AA 4.5:1 | Use `colorScheme.onSurfaceVariant` via `textTheme.labelSmall` |

## Checklist

| Group | Status | Notes |
|---|---|---|
| A Hierarchy & layout | partial | items 3, 5 |
| B Typography | present | |
| C Colour & contrast | missing | items 14, 15 |
| D Touch targets & a11y | partial | item 19 |
| E States | n/a | single-state screen |
| F Navigation | present | |
| G Content | present | |

## Could not check

- <item and what would settle it, e.g. "large text: capture with textScaleFactor 1.3">
