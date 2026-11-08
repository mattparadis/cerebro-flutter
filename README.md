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

## Prerequisites

- **Flutter SDK ≥ 3.44** on the `PATH` (`flutter doctor` passes for at
  least one desktop target; no emulator or device is needed). Install from
  <https://docs.flutter.dev/get-started/install>.
- An app that uses **`go_router` ≥ 18** or plain `MaterialApp.routes`.
- **Claude Code** or **Codex CLI** to run the skills.
- **Node.js** only if you install the skills with `npx skills add`; see the
  manual copy below if you prefer not to.

## Quick start (5 minutes)

```bash
git clone git@github.com:mattparadis/flutter-ui-ux-design-skill.git
cd flutter-ui-ux-design-skill/example/demo_app
flutter pub get
dart run ui_map capture          # writes .ui-map/ with 48 screenshots in ~30 s
claude                           # or: codex
```

then ask: *audit the screens of this app*. The demo app ships the skills
under `.claude/skills` and `.agents/skills`, so nothing else is needed.
To use it on your own app, see [Install in your own app](#install-in-your-own-app).

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

With `--explore` (or `explore: true`), the harness also taps every
semantics target of each screen on a fresh instance and records where it
leads: a `push`, `pop` or `go` to another location, an overlay (dialog,
sheet, snackbar), an `error` (for instance "nothing to pop" on a screen
reached by deep link), or nothing. `map.json` gets `edges` and
`dead_taps`; `MAP.md` gets a second Mermaid graph with the **real**
navigation edges labelled by the control that triggers them. On the demo
this takes about 20 s for 62 taps.

Large-text variants (`text_scales: [1.0, 1.3]`) and prototype routes
(`dart run ui_map capture -D UI_PROTO=true`) are captured the same way.

Screen **states** are addressed as locations: a list screen that reads
`?state=empty|loading|error` from `GoRouterState.uri.queryParameters` can
be captured in every state by listing `variants` in `ui_map.yaml`. No
test-only wiring needed.

## Try it on the demo app

```bash
cd example/demo_app
flutter pub get
dart run ui_map routes                     # 12 locations, incl. /notes?state=empty|loading|error
dart run ui_map capture                    # 48 PNGs (12 locations × light/dark × 1.0/1.3 text) in ~30 s
dart run ui_map capture -D UI_PROTO=true   # + the two prototype directions under /__proto/note-detail
dart run ui_map capture --explore          # + real navigation edges by tapping every target
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

Three pieces: the skills (Markdown folders the agent reads), the `ui_map`
tool (a Dart dev dependency), and the factory file that tells `ui_map`
how to build your app. Run everything from your app's root (where
`pubspec.yaml` is).

### 1. The skills

With Node.js, from your app's root:

```bash
# Claude Code → .claude/skills/<name>, Codex → .agents/skills/<name>
npx skills add mattparadis/flutter-ui-ux-design-skill --skill audit-screens
npx skills add mattparadis/flutter-ui-ux-design-skill --skill design-screen
```

The CLI asks which agents to install for and remembers the answer: tick
both Claude Code and Codex, or pass `-a claude-code,codex` (or `-a '*'`).
Add `-g` to install for every project instead of the current one.

Or by hand: copy (or symlink) `skills/audit-screens` and
`skills/design-screen` from a clone of this repo into `.claude/skills/`
(Claude Code) and/or `.agents/skills/` (Codex) inside your app. Each
skill is self-contained: `SKILL.md` plus its `references/` folder.

```bash
git clone git@github.com:mattparadis/flutter-ui-ux-design-skill.git ~/flutter-ui-ux-design-skill
mkdir -p .claude/skills .agents/skills
for s in audit-screens design-screen; do
  ln -s ~/flutter-ui-ux-design-skill/skills/$s .claude/skills/$s
  ln -s ~/flutter-ui-ux-design-skill/skills/$s .agents/skills/$s
done
```

To make a skill available in every project instead of one, put it under
`~/.claude/skills/` (Claude Code) or `~/.agents/skills/` (Codex).
Restart the agent after installing; verify with `/skills` in Claude Code.

### 2. The tool

```bash
# as a dev dependency (SSH form while the repo is private; needs a GitHub
# account with access to the repo and an SSH key)
dart pub add 'dev:ui_map:{"git":{"url":"git@github.com:mattparadis/flutter-ui-ux-design-skill.git","path":"packages/ui_map"}}'
# or, from a local clone:
dart pub add 'dev:ui_map:{"path":"../flutter-ui-ux-design-skill/packages/ui_map"}'
```

### 3. The factory

```bash
dart run ui_map init           # writes ui_map.yaml + test/ui_map/app_factory.dart
dart run ui_map routes         # lists the locations it will capture; add params in ui_map.yaml
dart run ui_map capture        # .ui-map/map.json, MAP.md, screens/, semantics/
```

`init` leaves two `UnimplementedError` stubs in `app_factory.dart`:
`buildRouter({required String initialLocation})` returns your `GoRouter`
with that initial location, and `buildApp(GoRouter router, {required
ThemeMode themeMode})` returns your root `MaterialApp.router` using that
router and theme mode. Usually both are one-line calls into functions you
already have in `lib/`. The audit skill fills them in itself when it can
find those functions; you only have to do it by hand when the router is
built behind dependency injection the test cannot call.

Add `.ui-map/` to `.gitignore` unless you want the screenshots in the
repo (keep `.ui-map/baseline/` if you use `ui_map check`, see below).

**Navigator 1.0 apps** (`MaterialApp` with `routes:` and `Navigator.pushNamed`,
no go_router): run `dart run ui_map init --navigator`. The factory then
returns only the root widget plus optional `argumentsFor(location)`; route
names are read from the running `MaterialApp`, each screen is opened with
`pushNamedAndRemoveUntil` like a deep link, and explore edges come from the
`ModalRoute` stack. Arguments can also be given in `ui_map.yaml` as
`routes.<name>.args` (YAML values). Apps without a dark theme should set
`themes: [light]`.

### Real apps: plugins, network, fonts

What a medium-sized production app needed to capture cleanly (all of it
lives in `test/ui_map/app_factory.dart` and `ui_map.yaml`, nothing in
`lib/`):

- **Plugins** have no implementation under `flutter test`. Screens that
  await `flutter_secure_storage`, `shared_preferences`, permissions or
  geolocation stay on their spinner forever. Mock the channels in
  `buildApp()` (`SharedPreferences.setMockInitialValues({})`,
  `TestDefaultBinaryMessengerBinding...setMockMethodCallHandler(...)`
  returning `null`/empty maps). Firebase that is only initialised in
  `main()` needs nothing: the factory never runs `main()`.
- **Network**: set `real_async_ms: 500`. The test binding answers every
  HTTP request with 400, so screens settle to their error/empty state
  instead of spinning in the fake-async zone.
- **google_fonts** cannot fetch in tests. Download the TTFs once (OFL)
  into `test/ui_map/fonts/`, set `GoogleFonts.config.allowRuntimeFetching
  = false` in the factory, and list them in `fonts:` under the family
  names google_fonts registers: `<Family>_regular`, `<Family>_500`,
  `<Family>_600`, `<Family>_700`, `<Family>_italic`, `<Family>_700italic`.
  Add a plain `<Family>` entry for `TextStyle(fontFamily:)` uses.
- **Auth guards**: screens that pop when no user is stored land on the
  initial route; `map.json` records `redirected_to` and the audit skill
  reports the redirect once instead of auditing the login screen 20 times.

Routes with `:params` need sample values in `ui_map.yaml`; screens that
hit the network or platform channels at build time will render their
error/empty branch (no HTTP in `flutter test`).

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
explore: false              # tap every target and record navigation edges
explore_max_taps: 40
lint:
  exclude: ["**/*.g.dart", "**/theme.dart", "**/theme/**"]
  rules: { no-safe-area: false }   # disable a rule
```

## Roadmap

- MCP wrapper, Android emulator capture for native plugins, auto_route
  support, network image mocking.

## Licence

Apache-2.0. See `NOTICE` for the projects whose checklist ideas are reused.
