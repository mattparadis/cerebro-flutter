---
name: audit-screens
description: Audit the UI/UX of a Flutter app from rendered screenshots and the semantics tree, not just source code. Use when asked to audit, review, critique or check the screens, UI, UX, design, accessibility, touch targets or dark mode of a Flutter app, or "what's wrong with these screens". Captures every go_router or Navigator 1.0 route headlessly with ui_map, then evaluates each screen against a Flutter-specific checklist and writes per-screen reports plus a summary.
---

# Audit screens

Audit a Flutter app's screens the way a senior mobile designer would: look at
every rendered screen in light and dark, read the semantics tree, and report
what is wrong with evidence and a Flutter-specific fix. Source code is
secondary; the screenshots are the primary evidence.

## 0. Preconditions

The app must use `go_router`, or Navigator 1.0 (`MaterialApp` with
`routes:` and `Navigator.pushNamed`). The capture tool is the `ui_map`
package from this repository (`packages/ui_map`).

1. Check `pubspec.yaml` for a `ui_map` dev dependency. If missing, add one
   (path or git, see the repository README) and run `flutter pub get`.
2. If `test/ui_map/app_factory.dart` does not exist, run `dart run ui_map init`
   (go_router) or `dart run ui_map init --navigator` (Navigator 1.0).
3. If `app_factory.dart` still contains `UnimplementedError(`, fill it in
   yourself. go_router: find the function that builds the `GoRouter` and the
   root `MaterialApp.router` widget in `lib/`, and wire them so `buildRouter`
   honours `initialLocation` and `buildApp` honours `themeMode`. Navigator
   1.0: return the root `MaterialApp` and, if screens read route arguments,
   implement `argumentsFor(location)`. Only ask the developer when the
   router is built behind DI you cannot call from a test.
4. Run `dart run ui_map routes`. For every `SKIP ... missing params` line, add
   sample values under `routes:` in `ui_map.yaml`. For list screens, add
   `variants` for empty / loading / error states if the app exposes them via
   query parameters (see "Scenario hook" below). Then rerun `routes`.

## 1. Capture (or reuse) the screens

Run `dart run ui_map capture` when `.ui-map/map.json` is missing, or when any
file under `lib/` or `ui_map.yaml` is newer than it. Otherwise reuse the
existing capture and say so in the summary.

The command writes:

- `.ui-map/map.json`: summary, fonts report, route tree, skipped routes, and
  one entry per screen with `png`, `semantics`, `exceptions`,
  `tappables_below_min`, `tappables_below_min_nested`, `status`.
- `.ui-map/MAP.md`: the navigation tree as Mermaid plus thumbnails.
- `.ui-map/screens/*.png`, `.ui-map/semantics/*.txt`.

If `.ui-map/DIFF.md` exists (the project runs `dart run ui_map check`
against a baseline), read it first: audit the **changed** and **added**
screens in depth and only skim unchanged ones, and report regressions it
lists (new layout exceptions, new small targets, screens that stopped
rendering) as severity 3-4 findings.

Run the capture with `--explore` when auditing navigation (or when the
app is small): `map.json` then has `edges` (what every tap does),
`no_effect_taps` and the count of `state_change` taps. Use them as evidence:

- a `no_effect_taps` entry on a button, tile with a chevron, chip or link
  is a `suspected` "looks interactive, does nothing" finding (severity 3 on
  primary actions, 2 otherwise). Confirm it by reading the handler in the
  source (`onPressed: () {}` or a missing `onTap` confirms; a handler that
  calls the network, the clipboard or a plugin does not). `state_change`
  edges (page content changed in place: filter, expand, page swipe) are
  working controls, not findings;
- an `error` edge saying "nothing to pop" means the screen is reachable by
  deep link without a parent stack and its close/back action crashes
  there (severity 2: guard with `context.canPop()` or use `go`);
- compare `kind` with the navigation semantics in the checklist: a detail
  opened with `go` instead of `push` loses the back stack; a modal
  creation flow should be `push`.

If `fonts.warnings` is non-empty, say so: glyph-level findings (type scale,
line length) are unreliable with the fallback font.

## 2. Evaluate every screen

Work location by location (`/notes`, `/notes?state=empty`, ...), with its
light and dark variants side by side.

1. Read the PNGs (they are images; look at them).
2. Skim the semantics file: unlabeled buttons, images without labels, heading
   structure, reading order, duplicated labels.
3. Run `dart run ui_map lint` and read `.ui-map/lint.json`.
4. Classify every signal by **how it was obtained** before judging it.
   Every finding carries one of four statuses, kept separate from
   severity:

   | Status | Meaning | Comes from |
   |---|---|---|
   | `confirmed` | reproduced by a measurement or an unambiguous structural fact | `tappables_below_min` (size and position), `low_contrast` (measured ratio, fg, bg), `exceptions` (layout overflow), lint `error`/`warning` (`file:line`), an `error` edge, a visible defect in the PNG that you can point at |
   | `suspected` | plausible from one signal, needs a second look | `no_effect_taps` (focus-only controls, off-screen effects and empty handlers look the same), lint `convention` findings (hardcoded colour, literal font size), a `state_change` edge that looks wrong, visual judgement of spacing or hierarchy, contrast you estimated by eye |
   | `not_checked` | the capture could not cover it | items in `contrast_not_measurable`, screens or states not captured, large text when `text_scales` has no 1.3, behaviour needing a device (haptics, keyboard, real network) |
   | `capture_issue` | a limit of the harness, **not** an app defect | `status: error` screens, `redirected_to`, `text_without_font_family` (blocks in the PNG), `fonts.warnings`, mocks missing in the factory, routes skipped for missing params |

   A `suspected` finding becomes `confirmed` only with a second, independent
   piece of evidence: the source line, the semantics dump, or a measured
   value. Say which. A `capture_issue` goes in the summary's "Capture limits"
   section and is never counted as a defect, however severe it would be if
   real.
5. Do **not** report `tappables_below_min_nested` as defects by default,
   but check the parent: a 32 dp icon inside a 56 dp `ListTile` is fine only
   if tapping the tile does the same thing as the icon. If the parent does
   something else (opens the row) while the icon does another (deletes),
   the small icon is a confirmed finding.
6. Go through `references/checklist.md` item by item. Mark each
   `present`, `partial`, `missing`, `n/a` or `can't tell`. There is no score.
   Then do the heuristic sweep in `references/heuristics.md` (Nielsen's 10)
   and name the heuristic in the "Why it matters" of the findings it
   explains.
   For platform specifics (Material 3 tokens, Apple HIG, Cupertino
   mapping) consult the `design-screen` skill's `references/` if it is
   installed alongside this one.
7. Severity per finding, Nielsen's scale (independent of status: a
   `suspected` finding can be severity 4):
   - 4 catastrophic: blocks a task or violates platform rules (no way back,
     unreadable text, overflow hiding content);
   - 3 major: hurts most users (touch target < 48 dp, contrast < 4.5:1,
     dark mode not adapted);
   - 2 minor: noticeable, workaround exists (inconsistent spacing, weak
     hierarchy);
   - 1 cosmetic;
   - 0 not a problem.

Rules of evidence:

- Only report what is visible in the screenshot or present in the semantics
  dump. If you cannot tell, write `can't tell` and say which variant or
  device size would settle it.
- Quote the evidence: the location, the theme, coordinates or the semantics
  label.
- Large-text captures (`__x1.3` ids, when `text_scales` is configured)
  are evidence for item 13: report overflow, clipping or truncation that
  appears only at the larger scale as severity 2-3.
- A dark-mode finding must be checked against the light screenshot: report
  "not adapted" only when the light and dark PNGs look the same where they
  should differ.
- Prefer theme-level fixes (`ColorScheme`, `TextTheme`, `ThemeData`
  component themes) over per-widget patches when the defect repeats.

## 3. Write the reports

Create `.ui-map/audit/` and write:

- `<slug>.md` per location, both themes in one file, using
  `references/report-template.md`. Strengths first (at least two, genuine
  ones), then findings sorted by severity, each with Element, Observation,
  Why it matters, Fix (name the Flutter widget or theme property), Severity.
  Keep each file under ~60 lines.
- `SUMMARY.md`: capture info (date, screens, fonts warnings, skipped
  routes), a **Capture limits** section listing every `capture_issue` and
  `not_checked` item (what was not verified and what would verify it), the
  single highest-leverage change, cross-screen findings
  (inconsistent spacing systems, hardcoded colours, dark mode gaps, missing
  states), a table of locations with their worst severity, and the Mermaid
  tree from `MAP.md` with nodes coloured by worst severity
  (`style n3 fill:#f8d7da` for 3-4, `#fff3cd` for 2, none otherwise).

Finish with a short message: screens audited, counts of confirmed and
suspected findings, top three findings with severity and status, path to
`SUMMARY.md`, and the capture limits.

## Scenario hook (for the developer)

A screen state is addressed as a location. The recommended pattern is a
query parameter read by the screen, e.g. `/notes?state=empty`, declared in
`ui_map.yaml`:

```yaml
routes:
  "/notes": { variants: ["?state=empty", "?state=loading", "?state=error"] }
  "/notes/:id": { params: { id: "1" } }
```

If the app has no such hook, audit the default state and list the missing
states under "could not check".
