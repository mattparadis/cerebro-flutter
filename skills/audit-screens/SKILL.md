---
name: audit-screens
description: Audit the UI/UX of a Flutter app from rendered screenshots and the semantics tree, not just source code. Use when asked to audit, review, critique or check the screens, UI, UX, design, accessibility, touch targets or dark mode of a Flutter app, or "what's wrong with these screens". Captures every go_router route headlessly with ui_map, then evaluates each screen against a Flutter-specific checklist and writes per-screen reports plus a summary.
---

# Audit screens

Audit a Flutter app's screens the way a senior mobile designer would: look at
every rendered screen in light and dark, read the semantics tree, and report
what is wrong with evidence and a Flutter-specific fix. Source code is
secondary; the screenshots are the primary evidence.

## 0. Preconditions

The app must use `go_router`. The capture tool is the `ui_map` package in this
repository (`packages/ui_map`).

1. Check `pubspec.yaml` for a `ui_map` dev dependency. If missing, add one
   (path or git) and run `flutter pub get`.
2. If `test/ui_map/app_factory.dart` does not exist, run `dart run ui_map init`.
3. If `app_factory.dart` still contains `UnimplementedError(`, fill it in
   yourself: find the function that builds the `GoRouter` and the root
   `MaterialApp.router` widget in `lib/`, and wire them so `buildRouter`
   honours `initialLocation` and `buildApp` honours `themeMode`. Only ask the
   developer when the router is built behind DI you cannot call from a test.
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

If `fonts.warnings` is non-empty, say so: glyph-level findings (type scale,
line length) are unreliable with the fallback font.

## 2. Evaluate every screen

Work location by location (`/notes`, `/notes?state=empty`, ...), with its
light and dark variants side by side.

1. Read the PNGs (they are images; look at them).
2. Skim the semantics file: unlabeled buttons, images without labels, heading
   structure, reading order, duplicated labels.
3. Take these as confirmed findings without further checking:
   - every entry in `tappables_below_min` (touch target below the minimum,
     coordinates and size are given);
   - every entry in `exceptions` (RenderFlex overflow, unbounded height, ...);
   - screens with `status: error` (the route could not render in a test;
     usually a missing dependency or side effect in the factory).
   Do **not** report `tappables_below_min_nested`: those sit inside a larger
   tappable parent (a Switch inside a ListTile) and the real hit area is fine.
4. Go through `references/checklist.md` item by item. Mark each
   `present`, `partial`, `missing`, `n/a` or `can't tell`. There is no score.
   Then do the heuristic sweep in `references/heuristics.md` (Nielsen's 10)
   and name the heuristic in the "Why it matters" of the findings it
   explains.
   For platform specifics (Material 3 tokens, Apple HIG, Cupertino
   mapping) consult the `design-screen` skill's `references/` if it is
   installed alongside this one.
5. Severity per finding, Nielsen's scale:
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
  routes), the single highest-leverage change, cross-screen findings
  (inconsistent spacing systems, hardcoded colours, dark mode gaps, missing
  states), a table of locations with their worst severity, and the Mermaid
  tree from `MAP.md` with nodes coloured by worst severity
  (`style n3 fill:#f8d7da` for 3-4, `#fff3cd` for 2, none otherwise).

Finish with a short message: screens audited, top three findings with
severity, path to `SUMMARY.md`, and anything you could not check.

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
