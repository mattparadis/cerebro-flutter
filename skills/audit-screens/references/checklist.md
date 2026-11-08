# Screen audit checklist (Flutter, mobile)

Mark each item `present`, `partial`, `missing`, `n/a` or `can't tell`.
Thresholds follow Material 3, Apple HIG and WCAG 2.1 AA. Items adapted from
mobile-screen-eval, Checklist Design and parhamb/design-skills (MIT); see
NOTICE.

## A. Hierarchy and layout

1. One clear primary action per screen; secondary actions visibly weaker
   (FilledButton vs TextButton / OutlinedButton).
2. Title or heading visible without scrolling; heading levels readable in
   the semantics dump (`header` flag or AppBar title).
3. Content aligned to a consistent horizontal gutter (16 or 24 dp); nothing
   touches the screen edge.
4. Spacing follows one system (multiples of 4 or 8 dp); no mixed 10/14/18
   gaps. Check gaps between cards, between heading and body.
5. Safe areas respected: nothing under the status bar or home indicator.
   The capture simulates the system insets (`safe_area` in map.json, 24 dp
   top and bottom by default) and draws them as translucent dark bands at
   the top and bottom of every PNG. Text or controls inside a band mean a
   missing `SafeArea` / `AppBar`; an `AppBar` or `SafeArea` screen shows
   its content starting below the band.
6. No layout exceptions in `exceptions` (overflow, unbounded constraints).
7. Long content scrolls; the primary action stays reachable (pinned bottom
   or inside scroll with enough bottom padding, 88 dp above a FAB).
8. Related items grouped (Cards, section headers, dividers); unrelated
   items not visually merged.

## B. Typography

9. Text uses the theme type scale (`TextTheme` roles); no more than three
   sizes per screen plus labels.
10. Body text at least 14 sp (Material) / 17 pt (iOS); captions at least
    12 sp.
11. Line length under about 60 characters for body copy on phone.
12. Text not truncated where meaning is lost (ellipsis on titles, cut-off
    buttons). `maxLines` with ellipsis on body previews is fine.
13. Large text: when `text_scales` includes 1.3 or 2.0, judge the `__x1.3`
    / `__x2` captures (overflow, clipping, truncation); otherwise mark
    `not_checked` and point at fixed-height containers and single-line
    `Row`s with text as the likely break points. Keyboard-open captures
    (`__kb`) show whether the focused field and the submit action stay
    reachable.

## C. Colour and contrast

14. Body text contrast at least 4.5:1 against its background; large text
    (18 sp+ or 14 sp bold) at least 3:1. `low_contrast` in map.json holds
    the measured failures; `contrast_coverage` says how many texts were
    measured and `contrast_not_measurable` lists the ones that were not
    (multi-colour spans, text over images or gradients, no colour in the
    style). Only texts that were measured and are absent from
    `low_contrast` passed; the rest is `not_checked` and needs visual
    judgement or a device check.
15. Colours come from `ColorScheme` roles; signs of hardcoded colours:
    a surface that stays light in the dark screenshot, text that stays
    dark-on-dark, an accent that does not match the rest of the app.
16. Dark theme: surfaces, cards, inputs and dividers all adapt; no pure
    white cards on dark backgrounds, no pure black backgrounds with
    saturated accents.
17. Colour is not the only carrier of meaning (error state has an icon or
    text, selected state has a shape change).
18. Interactive elements distinguishable from static text (buttons look
    pressable, links are not plain body text).

## D. Touch targets and accessibility

19. Every tappable at least 48×48 dp (Material) / 44×44 pt (iOS); the
    tool applies the threshold of the captured platform
    (`min_tap_size` in map.json per screen). Use `tappables_below_min`;
    for `tappables_below_min_nested` check that the enclosing target
    performs the same action before dismissing it.
20. Spacing between adjacent targets at least 8 dp.
21. Icon-only buttons have a `tooltip` or `Semantics(label)`: in the
    semantics dump every node with `tap` should have a label or tooltip.
22. Images that carry meaning have a semantics label; decorative ones are
    `excludeFromSemantics`.
23. Form fields have visible labels (not placeholder-only), keyboard type
    and autofill hints where applicable (email, password).
24. Errors are announced next to the field and in text, not only by colour.
25. Reading order in the semantics dump matches the visual order.
26. Reduce-motion and large-text are not broken by fixed-size containers
    (`can't tell` from a static capture unless obvious).

## E. States and feedback

27. Empty state exists and explains what to do next (icon, one line, action).
28. Loading state exists and does not shift layout when data arrives
    (skeleton or centred indicator with the same chrome).
29. Error state exists with a plain-language message and a retry action.
30. Destructive actions ask for confirmation or offer undo (judge from
    visible labels like Delete / Discard).
31. Success and progress feedback visible where the user acts (Save, Send).

## F. Navigation and platform idiom

32. The way back is obvious: AppBar back button or close icon for modals;
    full-screen dialogs use a close (×) on the left and the action on the
    right.
33. Screens that must not go back (paywall after onboarding, forced
    update) offer an explicit alternative ("Not now", "Skip").
34. Bottom navigation has 3 to 5 destinations with labels; the current tab
    is clearly selected.
35. Push vs replace vs modal is used consistently: a detail is pushed,
    auth replaces, a quick create is a modal/sheet.
36. Platform idiom is consistent: on iOS, Cupertino-style navigation and
    sheets or a deliberate Material look; no half-and-half.
37. Deep states are reachable by URL (go_router location), so each screen
    can be opened directly; screens that render `error` in the capture are
    usually side effects in constructors.

## G. Content

38. Labels are plain language, verb-first for actions ("Save note", not
    "OK"); no developer jargon or raw error strings (`StateError:`,
    `Exception:` in the UI is a finding).
39. Numbers, dates and currency are localised or at least consistent.
40. Microcopy in empty / error states is specific to the screen, not generic.

## H. Heuristic sweep

41. After A-G, scan the ten Nielsen heuristics in `heuristics.md` once for
    the screen and name the heuristic in the "Why it matters" column of any
    finding it explains (e.g. "H3 user control: no way out").
