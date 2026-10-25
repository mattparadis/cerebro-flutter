# Flutter UI/UX agent skills + `ui_map`

Agent skills for **Claude Code** and **Codex CLI** that design and audit
Flutter mobile UI/UX from what the user actually sees, backed by `ui_map`:
a small Dart tool that captures one screenshot per `go_router` route
**headlessly** (no emulator, no device), dumps the semantics tree, flags
touch targets below the minimum, and builds a navigation map the agent can
read.

Status: **v0.1**. Two skills, one tool, one demo app. Works on Linux,
macOS and Windows hosts with the Flutter SDK only.

```
skills/audit-screens/     audit existing screens: checklist (40 items), Nielsen heuristics, report template
skills/design-screen/     design new screens: prototype mode (2-3 directions as PNGs) and build mode,
                          with Material 3, Apple HIG / Cupertino, patterns and anti-pattern references
packages/ui_map/          Dart package: `dart run ui_map init | routes | capture`
example/demo_app/         Flutter app with planted design defects, used as fixture
```

| Skill | Ask for | What it does |
|---|---|---|
| `audit-screens` | "audit / review / critique the screens of this app" | captures (or reuses) the map, reads every PNG and semantics dump, applies the checklist and Nielsen's heuristics, writes `.ui-map/audit/<screen>.md` + `SUMMARY.md` with the highest-leverage change |
| `design-screen` | "design / prototype / redesign the X screen" | writes a 5-line brief, inherits the app's conventions from the map and theme, then either renders 2-3 prototype directions behind a `UI_PROTO` flag for you to pick, or builds the real screen with all states, captures it and self-audits before presenting |

## How it works

1. `dart run ui_map init` scaffolds `ui_map.yaml` and
   `test/ui_map/app_factory.dart`, where you expose two functions:
   `buildRouter({required String initialLocation})` and
   `buildApp(GoRouter router, {required ThemeMode themeMode})`.
2. `dart run ui_map capture` runs a generated `flutter test` that walks
   `router.configuration.routes` (GoRoute, ShellRoute, StatefulShellRoute
   branches), opens the app on every location, renders it at the configured
   device sizes in light and dark, and writes:

   | File | Content |
   |---|---|
   | `.ui-map/map.json` | summary, fonts report, route tree, skipped routes, one entry per screen (png, semantics, layout exceptions, `tappables_below_min`, `low_contrast` with measured WCAG ratios, sha256) |
   | `.ui-map/MAP.md` | navigation tree as Mermaid + thumbnail table |
   | `.ui-map/screens/*.png` | screenshots with real Roboto / Material Icons glyphs; simulated system insets drawn as translucent bands so missing `SafeArea` is visible |
   | `.ui-map/semantics/*.txt` | semantics tree dump, deterministic across runs |

3. The `audit-screens` skill reads the map and the images, applies a
   Flutter-specific checklist (hierarchy, type scale, contrast, touch
   targets, states, navigation idiom, dark mode) and writes
   `.ui-map/audit/<screen>.md` plus `SUMMARY.md` with the single
   highest-leverage change.

Large-text variants (`text_scales: [1.0, 1.3]`) and prototype routes
(`dart run ui_map capture -D UI_PROTO=true`) are captured the same way.

Screen **states** are addressed as locations: a list screen that reads
`?state=empty|loading|error` from `GoRouterState.uri.queryParameters` can
be captured in every state by listing `variants` in `ui_map.yaml`. No
test-only wiring needed.

## Try it on the demo app

```bash
cd example/demo_app
dart run ui_map routes                     # 12 locations, incl. /notes?state=empty|loading|error
dart run ui_map capture                    # 48 PNGs (12 locations × light/dark × 1.0/1.3 text) in ~30 s
dart run ui_map capture -D UI_PROTO=true   # + the two prototype directions under /__proto/note-detail
```

The generated `MAP.md` starts with the route tree:

```mermaid
graph TD
  n0["/"]
  n1["/login"]
  n2["/paywall"]
  n3["/notes/new"]
  subgraph n4["StatefulShellRoute"]
    subgraph n5["branch"]
      n6["/notes"]
      n7["/notes/:id"]
      n6 --> n7
    end
    subgraph n8["branch"]
      n9["/search"]
    end
    subgraph n10["branch"]
      n11["/settings"]
      n12["/settings/about"]
      n11 --> n12
    end
  end
```

and `map.json` already carries deterministic findings, for example on
`/settings` and `/notes`:

```json
"tappables_below_min": [
  { "label": "Edit profile", "x": 337.0, "y": 120.0, "width": 32.0, "height": 32.0,
    "nested_in_larger_target": false }
],
"low_contrast": [
  { "text": "Today, 09:12", "ratio": 1.69, "required": 4.5,
    "fg": "#BDBDBD", "bg": "#EEF4F1", "font_size": 11.0, "x": 32.0, "y": 170.0, ... }
]
```

Contrast is measured, not estimated: the text colour comes from the
rendered `RenderParagraph`, the background is sampled from the screenshot
under it, and the threshold follows WCAG AA (4.5, or 3.0 for large text).

Then, in the same directory, ask Claude Code or Codex:

> audit the screens of this app

The skill is discovered through `.claude/skills` and `.agents/skills`
symlinks in the demo app. The planted defects it should find: a 32×32 dp
icon button on Settings, a `#BDBDBD` caption on the notes list, a hardcoded
light background on the paywall that stays light in dark mode, and
onboarding content without `SafeArea`.

## Install in your own app

```bash
# the skill (Claude Code → .claude/skills, Codex → .agents/skills)
npx skills add <this-repo-url> --skill audit-screens

# the tool, as a dev dependency
dart pub add --dev 'ui_map:{"git":{"url":"<this-repo-url>","path":"packages/ui_map"}}'
dart run ui_map init
```

Requirements: Flutter ≥ 3.44, `go_router` ≥ 18. Routes with `:params` need
sample values in `ui_map.yaml`; screens that hit the network or platform
channels at build time will render their error/empty branch (no HTTP in
`flutter test`).

## Keep screenshots up to date: baseline, diff, check

```bash
dart run ui_map capture      # current state
dart run ui_map baseline     # copy it to .ui-map/baseline/ (commit this in your app)
# ... change the app ...
dart run ui_map check        # capture + diff; exit 1 on regressions
```

`check` writes `.ui-map/diff.json` and `.ui-map/DIFF.md` (before/after
thumbnails) and classifies each change as visual only, semantics only
(labels, actions), or a **regression**: a screen that stopped rendering, a
new layout exception, or a new tap target below the minimum. Hashes are
deterministic, so an unchanged screen never shows up. Use `--fail-on any`
to block on every pixel change, `--fail-on none` to only report.

Pre-commit hook (`.git/hooks/pre-commit` or your hook manager):

```sh
#!/bin/sh
if git diff --cached --name-only | grep -qE '^(lib/|ui_map.yaml|pubspec.yaml)'; then
  dart run ui_map check || { echo "ui_map: UI regressions, see .ui-map/DIFF.md"; exit 1; }
fi
```

GitHub Actions step (after `flutter pub get`):

```yaml
- run: dart run ui_map check --fail-on regression
- uses: actions/upload-artifact@v4
  if: always()
  with: { name: ui-map, path: .ui-map }
```

When a change is intentional, run `dart run ui_map baseline` again and
commit the new baseline with the code; the agent reading `DIFF.md` can
tell you which screens to look at before you do.

## Deterministic code rules: `ui_map lint`

```bash
dart run ui_map lint            # .ui-map/lint.json + LINT.md, exit 1 on errors
dart run ui_map lint --lint-fail-on warning
```

Regex rules for the design defects the Dart analyzer does not know about,
each with `file:line`: `hardcoded-color`, `literal-font-size`,
`empty-handler`, `small-icon-button`, `deprecated-will-pop-scope`,
`platform-io-check`, `no-safe-area`, `network-image-no-error-builder`,
`gesture-without-semantics`, `pump-and-settle` (tests). Theme files and
generated code are excluded by default; tune `lint.exclude` and
`lint.rules` in `ui_map.yaml`. `check` runs capture, diff and lint
together. The audit skill treats lint errors and warnings as confirmed
findings.

## `ui_map.yaml`

```yaml
devices:
  - { name: phone, width: 393, height: 852, dpr: 3, safe_area: { top: 24, bottom: 24 } }
themes: [light, dark]
platforms: [android]        # android | ios
text_scales: [1.0, 1.3]     # large-text variants get an __x1.3 id suffix
settle_ms: 600              # fixed pumps; infinite spinners are fine
export_scale: 2             # PNG = logical size × 2
min_tap_size: 48
routes:
  "/notes/:id": { params: { id: "1" } }
  "/notes":     { variants: ["?state=empty", "?state=loading", "?state=error"] }
  "/debug":     { skip: true }
exclude: []
fonts: {}                   # family -> font files, for custom fonts
out_dir: .ui-map
lint:
  exclude: ["**/*.g.dart", "**/theme.dart", "**/theme/**"]
  rules: { no-safe-area: false }   # disable a rule
```

## Roadmap

- Dynamic navigation edges by exploring taps on every screen.
- MCP wrapper, Android emulator capture for native plugins, Navigator 1.0
  / auto_route support, network image mocking.

## Licence

Apache-2.0. See `NOTICE` for the projects whose checklist ideas are reused.
