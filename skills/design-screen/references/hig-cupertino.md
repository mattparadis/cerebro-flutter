# Apple HIG essentials and Cupertino mapping for Flutter

Source: Apple Human Interface Guidelines (https://developer.apple.com/design/human-interface-guidelines/)
and the Flutter `cupertino` library. iOS 17-26 conventions.

## Decide the platform strategy once per app

| Strategy | When | How in Flutter |
|---|---|---|
| **Material everywhere** | utility apps, Android-first, small teams | M3 components; `PageTransitionsTheme` with `CupertinoPageTransitionsBuilder` on iOS so navigation feels native; `Icons.adaptive.*`; `.adaptive` constructors for switches, sliders, dialogs, progress |
| **Cupertino on iOS, Material on Android** | consumer apps where iOS users expect native chrome | `Theme.of(context).platform` switch at the scaffold level; shared content widgets inside; two shells, one body |
| **Cupertino only** | iOS-only products | `CupertinoApp`, Cupertino widgets throughout |

What to avoid is two **navigation chromes** or two visual languages for
the same component class on one screen (a Cupertino nav bar with a
Material FAB, a Material AppBar with a bare `CupertinoSwitch` next to a
Material `Switch`). A Material shell that uses the `.adaptive`
constructors (`Switch.adaptive`, `AlertDialog.adaptive`,
`CircularProgressIndicator.adaptive`) and Cupertino transitions on iOS is
one coherent strategy, not mixing. Adaptive means the *shell* and the
platform-owned controls change together, the content stays.

## HIG rules that most often break in Flutter apps

Legend: **R** requirement (verifiable, platform rule or WCAG), **D**
default (follow unless the brief says why not), **C** context-dependent.

- **R Touch targets** 44 × 44 pt minimum on iOS (48 dp on Android;
  `min_tap_size: {android: 48, ios: 44}` in `ui_map.yaml` makes the tool
  apply the right one per captured platform); **D** spacing between
  targets 8 pt.
- **Safe areas**: respect top (status bar / Dynamic Island) and bottom
  (home indicator) insets; `SafeArea` or `CupertinoPageScaffold`. Never
  put a tappable control under the home indicator.
- **Navigation**: a navigation bar with a back chevron and the previous
  title, or a large title that collapses on scroll
  (`CupertinoSliverNavigationBar`). Edge swipe back must work
  (`CupertinoPageRoute` / `CupertinoPageTransitionsBuilder`).
- **Tab bar**: 2-5 tabs at the bottom, icon + label, current tab tinted;
  tapping the current tab pops to root.
- **Modality**: sheets (page sheet with grabber, swipe to dismiss) for
  self-contained tasks; full-screen modal for immersive creation; alerts
  only for decisions that block. Modal screens show Cancel left / Done
  right, no back chevron.
- **Destructive actions**: red in action sheets and context menus, with
  confirmation, never as the default.
- **Text**: Dynamic Type scales; body 17 pt, minimum 11 pt for captions,
  never fixed heights around text.
- **Lists**: inset grouped style for settings, plain for content; disclosure
  chevrons only on rows that navigate.
- **System materials and Liquid Glass (iOS 26)**: translucent bars and
  controls that refract content beneath; concentric corner radii; avoid
  placing dense text on glass. In Flutter approximate with
  `CupertinoNavigationBar` defaults and `BackdropFilter` sparingly; do not
  hand-paint glass.
- **SF Symbols** have no direct Flutter equivalent; `CupertinoIcons` is
  the closest set, keep weights consistent.

## Apple text styles → Flutter

| iOS style | Size/weight (pt) | Cupertino | Material role (adaptive apps) |
|---|---|---|---|
| Large Title | 34 bold | `CupertinoSliverNavigationBar.largeTitle` / `navLargeTitleTextStyle` | `headlineLarge` |
| Title 1 / 2 / 3 | 28 / 22 / 20 | `navTitleTextStyle` for bars | `headlineSmall` / `titleLarge` / `titleMedium` |
| Headline | 17 semibold | `textStyle` + `FontWeight.w600` | `titleMedium` |
| Body | 17 | `CupertinoTheme.of(context).textTheme.textStyle` | `bodyLarge` |
| Callout / Subhead | 16 / 15 | | `bodyMedium` |
| Footnote | 13 | | `bodySmall` |
| Caption 1 / 2 | 12 / 11 | `tabLabelTextStyle` | `labelMedium` / `labelSmall` |

## Cupertino widget mapping

| Need | Cupertino | Material counterpart |
|---|---|---|
| Page | `CupertinoPageScaffold` | `Scaffold` |
| Nav bar | `CupertinoNavigationBar`, `CupertinoSliverNavigationBar` | `AppBar`, `SliverAppBar.large` |
| Tabs | `CupertinoTabScaffold` + `CupertinoTabBar` | `NavigationBar` |
| Buttons | `CupertinoButton`, `CupertinoButton.filled` | `TextButton`, `FilledButton` |
| Lists | `CupertinoListSection.insetGrouped` + `CupertinoListTile` | `ListTile` + section headers |
| Toggles | `CupertinoSwitch`, `CupertinoSlider`, `CupertinoCheckbox` | `Switch.adaptive`, `Slider.adaptive`, `Checkbox.adaptive` |
| Segments | `CupertinoSlidingSegmentedControl` | `SegmentedButton` |
| Text input | `CupertinoTextField`, `CupertinoSearchTextField` | `TextField`, `SearchBar` |
| Dialogs | `CupertinoAlertDialog` via `showCupertinoDialog` | `AlertDialog.adaptive` via `showAdaptiveDialog` |
| Action sheet | `CupertinoActionSheet` via `showCupertinoModalPopup` | `showModalBottomSheet` |
| Sheet | `CupertinoSheetRoute` / `showCupertinoSheet` (Flutter 3.29+) | `showModalBottomSheet`, `fullscreenDialog` page |
| Pickers | `CupertinoDatePicker`, `CupertinoPicker` | `showDatePicker` |
| Progress | `CupertinoActivityIndicator` | `CircularProgressIndicator.adaptive` |
| Context menu | `CupertinoContextMenu` | `MenuAnchor` / long-press menu |
| Pull to refresh | `CupertinoSliverRefreshControl` | `RefreshIndicator.adaptive` |

Theming: `CupertinoThemeData(primaryColor:, brightness:)`; inside a
`MaterialApp`, Cupertino widgets read `CupertinoTheme` derived from the
Material theme via `MaterialBasedCupertinoThemeData`. Dark mode follows
`MediaQuery.platformBrightness`; use `CupertinoColors.systemBackground`
and `CupertinoDynamicColor` rather than fixed colours.

## Adaptive patterns worth copying

- Back: `Icons.adaptive.arrow_back`; share: `Icons.adaptive.share`; more:
  `Icons.adaptive.more`.
- Transitions: `PageTransitionsTheme` with `CupertinoPageTransitionsBuilder`
  for iOS and `PredictiveBackPageTransitionsBuilder` for Android.
- Dialogs: `showAdaptiveDialog` + `AlertDialog.adaptive`.
- Platform check: `Theme.of(context).platform == TargetPlatform.iOS`
  (respects test overrides), not `Platform.isIOS` (breaks tests and web).
