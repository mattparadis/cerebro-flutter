---
name: design-screen
description: Design and build Flutter mobile UI with the right UI/UX theory, Material 3 / Apple HIG rules, the app's own conventions, and a capture-and-check loop with ui_map. Use whenever Flutter UI is being written or changed from a brief: a whole app or several screens from scratch, a new screen, page, flow, onboarding, paywall, settings, list, detail or form, a redesign, or a request to design, create, build, mock up, prototype or propose directions. Has a prototype mode that produces 2-3 throwaway directions as screenshots before any real code, and a build mode that ships the real screens. Covers setting up ui_map in a project that does not have it yet.
---

# Design screen

Produce a Flutter screen a senior mobile designer would sign off: correct
hierarchy, platform idiom, theme tokens only, every state designed, and
verified from a rendered screenshot, not from the code alone.

Two modes. Pick from the request; when unclear, ask once:

- **prototype**: 2-3 distinct directions with fake data, rendered as PNGs
  for the person to choose from. Throwaway code behind a flag.
- **build**: the real screen wired into the app's router, with states,
  captured and self-audited before it is presented.

The references in `references/` are the theory. Read the ones the task
needs; do not paste them into the output.

| File | Use it for |
|---|---|
| `references/patterns.md` | screen archetypes, states, navigation semantics (push / replace / modal / sheet), forms, onboarding, paywalls, settings |
| `references/material3.md` | colour roles, type scale, shape, spacing, components, motion, Flutter theme wiring |
| `references/hig-cupertino.md` | Apple HIG essentials, Cupertino widgets, platform-adaptive strategy |
| `references/anti-patterns.md` | what makes a screen look AI-generated or break on devices; checked before delivery |

## 0. Make sure ui_map can run (once per project)

The capture loop below needs the `ui_map` dev dependency. Check
`pubspec.yaml` first; if it is missing, add it and scaffold it:

```sh
# from the repo that ships this skill (adjust the URL or use a local path)
dart pub add 'dev:ui_map:{"git":{"url":"git@github.com:mattparadis/flutter-ui-ux-design-skill.git","path":"packages/ui_map"}}'
# or, with a checkout next to the project:
dart pub add 'dev:ui_map:{"path":"../flutter-ui-ux-design-skill/packages/ui_map"}'
dart run ui_map init            # ui_map.yaml + test/ui_map/app_factory.dart
dart run ui_map routes          # must list every screen before you design
```

Fill `test/ui_map/app_factory.dart` with the app's real router and root
widget as soon as they exist (for a new app: right after the first
screen compiles), and keep `ui_map.yaml` current (params, variants,
`keyboard: true` on forms and chats, `text_scales: [1.0, 1.3]`).
Fonts: `flutter test` cannot download, so bundle the font files as
assets (preferred for a brief that names the typography) or list them
under `fonts:` in `ui_map.yaml`; never judge type from a stand-in font.

If the dependency cannot be installed (no network, private repo), say so
in the deliverable, keep going with a widget-test golden harness of your
own that loads the real font files, and mark every visual claim as
`not_checked` with ui_map.

## 1. Brief (always, short)

Write these before any code, and show them to the person in the final
message:

0. **Who and where**: the audience (two or three traits that matter:
   outdoors with gloves, one-handed on a commute, a clinician between
   patients), the context of use, and what they must find first on this
   screen (information priorities, top three). From these derive the
   **density** (airy / standard / dense) and the **character** the app
   already has or the brief asks for (quiet utility, warm consumer, data
   heavy, playful), in one line each. Every visual choice below must point
   back at one of these; a choice with no reason is a reflex.
1. **Job**: one sentence, feature + job to be done. "Hard paywall after
   onboarding, annual default, exit visible."
2. **Archetype** from `patterns.md` (list, detail, form, onboarding,
   paywall, settings, empty/first-run, dashboard).
3. **Platform strategy**: Material everywhere, Cupertino on iOS, or
   adaptive. Inherit the app's existing choice; never mix on one screen.
4. **Entry and exit**: where it sits in the navigation map (route path,
   push / replace / modal), what the back action does, what the primary
   action leads to.
5. **States**: default, empty, loading, error, plus any domain states.
   Each one must be designed, not just handled.
6. **Flow contract** (for any screen where the user *does* something:
   create, edit, pay, sign in, delete, filter): a table, one row per
   action, from `references/patterns.md` → "Flow contracts":
   situation → action → expected result → feedback → error and recovery.
   Say where the state lives, when it is persisted, and what must survive
   back, tab switch and reopening. Cover what applies: unsaved changes,
   cancel, in-flight (disabled + spinner), double tap, error + retry,
   duplicate prevention, scroll and filter preservation, permission
   denied, auth that returns to the original deep link. A screen that
   looks right while "Save" closes without persisting fails this contract.
7. **Coverage**: which devices, themes, platforms, text scales, locales
   and keyboard-open screens the capture will run (`ui_map.yaml`); for a
   form, set `keyboard: true` on its route. What is not run is reported
   as not verified, never assumed.

## 2. Inherit the app's conventions, not its defects

Before designing, look at what exists, and sort what you find into two
lists: **conventions to keep** (gutter, type usage, component style,
navigation chrome, tone of copy) and **defects not to propagate**
(hardcoded colours, 36 dp chips, placeholder-only fields, a second accent
colour). Copying a neighbouring screen verbatim carries its defects into
the new one; say in the brief which of its traits you kept and which you
corrected, and why. For a new app or a wide redesign, pick two or three
pertinent references (apps your audience already uses for a similar job)
and name the principles you take from them, not the pixels.

- `.ui-map/MAP.md` and `map.json` if present (run `dart run ui_map capture`
  if the app is set up for it): open two or three neighbouring screens'
  PNGs and note gutter, type usage, card style, button hierarchy, AppBar
  style, bottom navigation.
- `lib/theme*.dart` or wherever `ThemeData` is built: seed colour, custom
  `TextTheme`, component themes, `ThemeExtension`s. Use those tokens.
- The router file: path style, naming, how params and query strings are
  used, whether screens read `?state=` for scenarios.
- One existing screen file of the same archetype: copy its structure
  (Scaffold, padding, list building) so the new screen looks native to
  the app.

If there is no existing app (greenfield), start from `material3.md`
defaults: seed colour, `ColorScheme.fromSeed`, 16 dp gutter, M3 components.

## 3. Design decisions (write them down, briefly)

Three kinds of rule, kept apart: **requirements** (platform rules and
WCAG: touch targets, contrast, a way back, labels) are not negotiable;
**defaults** (one primary action, 16 dp gutter, three type sizes, M3
components) hold unless the brief gives a reason; **context choices**
(validation policy, push vs go, density, how much the screen may depart
from the app's conventions) are decided per screen and written down. A
default broken on purpose is a decision; a requirement broken is a defect.

- **Hierarchy** (default): one primary action (`FilledButton` or FAB),
  secondary as `TextButton`/`OutlinedButton`, nothing else competes.
- **Layout**: 4/8 dp grid, 16 dp gutter (24 on standalone marketing/auth
  screens if the app does that), sections grouped by whitespace before
  dividers or cards.
- **Type**: `Theme.of(context).textTheme` roles only, at most three sizes
  plus labels per screen.
- **Colour**: `ColorScheme` roles only. Surfaces use the
  `surfaceContainer*` tiers; text uses `onSurface` / `onSurfaceVariant`;
  the accent is `primary`. No `Color(0x...)`, no `Colors.*` literals.
- **Touch** (requirement): every target 48 dp on Android, 44 pt on iOS;
  8 dp between targets (default).
- **Semantics**: title is a header (`Semantics(header: true)` or AppBar),
  icon-only buttons have tooltips, images carry labels or are excluded,
  reading order follows visual order.
- **Motion**: Material standard/emphasized easing, 200-400 ms; respect
  `MediaQuery.disableAnimations`.
- **Copy**: verb-first actions, plain language, empty/error copy specific
  to the screen.

## 4a. Prototype mode

1. Create `lib/prototypes/<name>_proto.dart` with two or three directions
   as separate widgets (`<Name>ProtoA`, `ProtoB`, `ProtoC`), each a full
   `Scaffold`, using the app theme and fake data. Make the directions
   differ in **structure** (e.g. list vs cards vs grouped sections; sheet vs
   page; hero image vs text-first), not just in colour, and make each one
   serve a different reading of the brief's priorities (speed of the main
   task vs overview vs recognisability). Use realistic content: long
   names, an empty field, a 4-digit price, a 12-item list.
2. Register one route guarded by a compile-time flag so the prototypes
   never ship:

   ```dart
   const kUiProto = bool.fromEnvironment('UI_PROTO');
   // in the router's top-level routes:
   if (kUiProto)
     GoRoute(
       path: '/__proto/<name>',
       builder: (c, s) => switch (s.uri.queryParameters['v']) {
         'b' => const <Name>ProtoB(),
         'c' => const <Name>ProtoC(),
         _ => const <Name>ProtoA(),
       },
     ),
   ```

   If the final screen will live inside a shell (tabs), register the
   prototype route as a child of that branch (e.g. under `/settings`)
   instead of top-level, so the capture shows the real AppBar back button
   and bottom navigation around it.

3. Add to `ui_map.yaml`:

   ```yaml
   routes:
     "/__proto/<name>": { variants: ["?v=b", "?v=c"] }
   ```

4. Capture with the flag: `dart run ui_map capture -D UI_PROTO=true`.
   Open the PNGs yourself and reject any direction that breaks the rules
   in step 3 before showing it.
5. Present: for each direction, the PNG path(s) (light and dark), two
   lines on the idea and its trade-off, and how it scores against the
   brief's goals (legibility, speed of the main task, density, fit with
   the app, behaviour with real content). Recommend one. Ask the person to
   choose. Stop there.
6. On a choice: build mode for that direction, then delete
   `lib/prototypes/<name>_proto.dart`, the guarded route and the yaml
   entry. Prototypes do not linger.

## 4b. Build mode

1. Write the screen under the app's convention (`lib/screens/`,
   `lib/features/<x>/presentation/`, ...). One widget per state or a
   small state switch inside the screen; never leave a state unhandled.
2. Wire the route in the router with the semantics decided in the brief
   (`pageBuilder` with `fullscreenDialog: true` for modal creation flows,
   `context.push` for details, `context.go` for replacing flows). Make
   every state capturable: add factory scenarios in
   `test/ui_map/app_factory.dart` that put the data layer in each state
   (empty, loading, error, logged-in) and list them under
   `routes.<path>.scenarios` in `ui_map.yaml`; or, when the screen already
   reads a query parameter, URL variants (`?state=empty`).
3. Add the route (and its `params` / `variants`) to `ui_map.yaml`, run
   `dart run ui_map capture --explore`, and look at every PNG of the new
   screen in light and dark (and `__x1.3` if `text_scales` includes 1.3).
   Check the new screen's `edges` in `map.json`: every control does what
   the brief says (navigates, opens an overlay, or changes content in
   place as a `state_change`), nothing of yours is in `no_effect_taps`
   unless its effect is outside the screen by design, and the back/close
   action works when the screen is opened directly (no "nothing to pop"
   error).
4. Self-audit against the `audit-screens` checklist if that skill is
   installed, otherwise against `anti-patterns.md` and step 3 above.
   Fix anything of severity 3-4 (touch target, contrast, missing state,
   no way back, overflow) before presenting. Report `exceptions` from
   `map.json` as fixed, not as known issues.
4b. Prove the flow contract, not just the screen. For the main action
   write a widget test that drives it through an observable fake of the
   data layer (an in-memory repository you can inspect): the action
   persists what it should and the result is visible where the user will
   look next (the new item in the list, the updated balance, the
   confirmation); cancel leaves nothing behind; a second tap during the
   in-flight state does nothing; a failing fake shows the error state and
   retry succeeds. Put device-bound behaviour (real backend, plugins,
   haptics) in the "needs a device" list, never in the verified one.
5. `dart run ui_map lint` reports no `error` or `warning` in the new
   files; `convention` findings in them are either removed or justified
   with a `// ui_map: ignore <reason>` comment. `flutter analyze` clean;
   existing tests still pass.

## 5. Deliver

Final message: the brief, files created or changed, the route and how to
open it, the PNG paths, what was verified in the capture, what the flow
test proved **with fakes**, and what still needs a device or the real
backend (haptics, real keyboard, network, animations, payments). Keep the
two lists apart. No code in the message.
