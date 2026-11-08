# `<location>` — <route name or path>

Captured: <date> · device <name> (<w>×<h> dp) · themes: light, dark · fonts: <real|fallback>

![light](../screens/<id-light>.png) ![dark](../screens/<id-dark>.png)

## Strengths

- <genuine strength 1, with the element it refers to>
- <genuine strength 2>

## Findings

| # | Sev | Status | Evidence | Element | Observation | Why it matters | Fix (Flutter) |
|---|---|---|---|---|---|---|---|
| 1 | 3 | confirmed | `tappables_below_min` | `Edit profile` icon button | 32×32 dp at (349, 85) | Below the 48 dp minimum; hard to hit, fails a11y | Remove the `SizedBox(32)` wrapper; use `IconButton` default constraints or `visualDensity` |
| 2 | 3 | confirmed | `low_contrast` 1.69:1 | Card date caption | `#BDBDBD` on `#EEF4F1`, light theme | Fails WCAG AA 4.5:1 | Use `colorScheme.onSurfaceVariant` via `textTheme.labelSmall` |
| 3 | 2 | suspected | `no_effect_taps` + PNG | `Filter` icon button | Tap changed nothing observable; handler not yet read | Looks interactive, may do nothing | Read `onPressed`; disable with `null` until implemented |

Status: `confirmed` (measured or structural), `suspected` (one signal, needs a second), `not_checked`, `capture_issue` (harness limit, not a defect; goes to the summary's Capture limits).

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

## Not checked / capture limits

- <`not_checked`: item and what would settle it, e.g. "large text: capture with text_scales 1.3">
- <`capture_issue`: e.g. "3 texts without font family render as blocks; judged from source only">
- <contrast coverage from `contrast_coverage`: measured N of M texts; list `contrast_not_measurable` reasons>
