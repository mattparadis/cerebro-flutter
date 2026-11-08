# Anti-patterns to check before delivering a Flutter screen

Two groups: what makes a screen read as generic or AI-generated, and what
breaks on real devices. Ideas adapted from impeccable / klamben
(Apache-2.0) and the capture findings in this repo.

## Looks generated

Signals, not verdicts: each of these is wrong when it appears without a
reason tied to the content or the brand. A gradient that is the brand, a
centred composition on a hero or an empty state, two accents in a chart
are fine; the same choices as reflexes are what make screens look alike.
When a signal is kept on purpose, say why in the brief.

- Gradient backgrounds and gradient buttons used as decoration.
- Everything centred: centred body text, centred titles on list screens,
  centred cards with equal padding. Left-align reading content; centre
  onboarding, empty states and single-focus heroes.
- Cards inside cards, borders plus shadows, `Container(decoration:
  BoxDecoration(...))` where `Card`, `ListTile` or a `surfaceContainer*`
  tier would do.
- Emoji as icons; icons that do not match the action; decorative icons on
  every tile.
- Rounded corners at 999 on everything, or mixed radii on one screen.
- Three accent colours on one screen; coloured section headers for no
  reason; saturated colours on large surfaces.
- "Lorem ipsum", "Welcome to our app!", "Get Started" without saying what
  starts; exclamation marks; generic empty states ("Nothing here").
- Hero illustration taking half the screen above a list.
- Over-animation: bounce curves, staggered fades on every tile, 800 ms
  transitions.

## Breaks on devices (the capture catches most of these)

- `Color(0xFF...)` / `Colors.grey` literals: dark mode does not adapt;
  contrast unverified. Use `ColorScheme` roles.
- `TextStyle(fontSize: 14)` literals: ignore the type scale and Dynamic
  Type expectations. Use `TextTheme` roles.
- Tap targets below 48 dp (`SizedBox(width: 32, child: IconButton)`,
  `GestureDetector` on a 24 dp icon, `padding: EdgeInsets.zero` on
  buttons).
- Missing `SafeArea` / `AppBar` on screens without system chrome: content
  under the status bar or the home indicator.
- `Row` with `Text` and no `Expanded`/`Flexible`: overflow at large text
  or long strings. `Column` with a `ListView` and no `Expanded`: unbounded
  height error. Fixed-height containers around text.
- Non-scrolling `Column` on content screens: overflow on short phones and
  at `textScaleFactor` 1.3.
- `GestureDetector` / `InkWell` without `Semantics(button: true)` or a
  label; icon-only `IconButton` without `tooltip`; images without
  `semanticLabel`.
- Static `Chip`s styled like `FilterChip`s; rows with chevrons but no
  `onTap`; buttons with empty `onPressed: () {}` (use `null` to disable).
- `WillPopScope` (deprecated) instead of `PopScope`; `PopScope(canPop:
  false)` with no visible exit.
- Network images without placeholder/error builders; assets referenced
  but not declared in `pubspec.yaml`.
- `pumpAndSettle` in widget tests of screens with indeterminate
  progress indicators (hangs); side effects in widget constructors or
  `build` (network calls, `SharedPreferences`), which also make the
  screen fail under headless capture.
- Platform mixing: Material AppBar with `CupertinoSwitch`, or
  `Platform.isIOS` checks instead of `Theme.of(context).platform`.
- Missing `const` on static subtrees; rebuilding whole lists on every
  state change (no `ListView.builder`).

## Quick self-check before presenting

1. Open the light and dark PNGs: do surfaces, text and borders all change?
2. Any `exceptions` in `map.json` for the screen? Fix, do not explain.
3. Any `tappables_below_min` or `low_contrast`? Fix.
4. Run `dart run ui_map lint` (or grep the new file for `Color(0x`,
   `Colors.`, `fontSize:`, `() {}`).
5. Is there an empty, loading and error design, each reachable by URL?
6. Is the way back obvious, and is the primary action the only filled
   button?

## Motion that never happens

- Pages that appear with no transition on Android or iOS. Typical cause:
  go_router `builder:` routes resolved to `NoTransitionPage` because the
  app type was not detected, or a `PageTransitionsTheme` set to none.
  Signal: ui_map explore shows `transition: instant` on `push`/`pop`
  edges. Fix: `pageBuilder` with `MaterialPage`/`CupertinoPage` (or a
  `CustomTransitionPage`), an explicit `PageTransitionsTheme`, and a
  widget test asserting `ModalRoute.transitionDuration > 0`.
- A state the user caused (sent, accepted, saved, removed) that flips
  with no motion while the rest of the screen moves. Signal: `instant`
  state_change edge on the screen's main action.
- Motion with no cause: looping shimmer on loaded content, pulsing
  buttons. Signal: `continuous` on a screen that is not loading.
