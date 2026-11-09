# Material 3 essentials for Flutter screens

Source: https://m3.material.io (Material Design 3) and the Flutter
`material` library. Verified against Flutter 3.47 (Material 3 is the
default; `useMaterial3: true` is implied). Where M3 Expressive components
are mentioned, check they exist in your Flutter version before using them.

Everything here is a **default**: the fastest route to a coherent,
accessible Material screen. The brief's audience, density and character
decide where to depart from it (a denser type scale for a data app, a
warmer palette with a second accent for a consumer app, larger targets
for gloves). Departures are decisions written in the brief; the
requirements (touch targets, contrast, labels, a way back) stay.

## Colour roles (use these, never literals)

| Role | Use for |
|---|---|
| `primary` / `onPrimary` | the one accent: FilledButton, FAB, selected states |
| `primaryContainer` / `onPrimaryContainer` | prominent but softer: hero tiles, extended FAB background, selected nav indicator |
| `secondary*`, `tertiary*` | supporting accents (tags, charts, illustrations). Most apps need none on a screen |
| `surface` | page background (Scaffold default) |
| `surfaceContainerLowest` → `surfaceContainerHighest` | five tonal tiers for grouping: cards (`Low`/default), sheets and dialogs (`High`), inputs. Replace borders + shadows with tiers |
| `onSurface` | primary text and icons |
| `onSurfaceVariant` | secondary text, captions, supporting icons (contrast-safe on `surface*`) |
| `outline` | enabled borders (text fields, outlined buttons) |
| `outlineVariant` | dividers, decorative borders, inactive indicators (not for text) |
| `error` / `onError` / `errorContainer` | error text, destructive emphasis |
| `inverseSurface` / `onInverseSurface` | snackbars, tooltips |

Wiring: `ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: ..., brightness: ...))`,
or `colorSchemeSeed:`. For a brand palette, `ColorScheme.fromSeed(..., primary: brandColor)`
overrides a role while keeping the rest harmonised. Dark theme comes from
the same seed with `Brightness.dark`; never hand-tune two palettes.

Contrast: `on*` on its own container meets AA for seed-generated
schemes; overriding a role (`ColorScheme.fromSeed(..., primary: brand)`)
or using a role on a different surface voids that guarantee. Measure
mixed pairs (`low_contrast` in the capture) instead of assuming.

## Type scale (TextTheme role → size/weight, sp)

| Role | Size | Typical use |
|---|---|---|
| `displayLarge/Medium/Small` | 57 / 45 / 36 | hero numbers, splash; rarely on phone |
| `headlineLarge/Medium/Small` | 32 / 28 / 24 | screen titles without AppBar, onboarding titles |
| `titleLarge` | 22 (regular) | AppBar title, dialog title |
| `titleMedium` | 16 (medium) | card titles, list item titles, section headers |
| `titleSmall` | 14 (medium) | dense titles, tabs |
| `bodyLarge` | 16 | primary reading text, detail body |
| `bodyMedium` | 14 | default body, list subtitles |
| `bodySmall` | 12 | captions, metadata (pair with `onSurfaceVariant`) |
| `labelLarge` | 14 (medium) | buttons, prominent labels |
| `labelMedium` / `labelSmall` | 12 / 11 (medium) | chips, badges, nav labels; never for sentences |

Rules: three sizes plus labels per screen; minimum 12 sp for anything a
user must read; headlines regular weight, titles medium; let the role
carry the colour via `copyWith(color: scheme.onSurfaceVariant)` only for
secondary text. Custom fonts go in `ThemeData(fontFamily:)` or a custom
`TextTheme`, not per-widget `TextStyle(fontSize:)`.

## Shape, spacing, elevation

- Shape scale: 4 (extra small: chips), 8 (small), 12 (medium: cards,
  text fields), 16 (large: sheets, FAB), 28 (extra large: dialogs), full
  (buttons, pills). Components already use these; override via
  component themes, not `BorderRadius` per widget.
- Spacing: 4 dp grid. Gutter 16 dp (24 on standalone screens if the app
  does so). Between list items 8, between sections 24, between heading
  and body 8-12, above a bottom primary button 16-24, above a FAB 88.
- Elevation: prefer tonal tiers (`surfaceContainer*`) over shadows.
  Cards: `Card` (elevated, 1 dp), `Card.filled`, `Card.outlined`. Do not
  stack cards inside cards.
- Touch targets: 48 × 48 dp minimum, including `IconButton` (default
  constraints already comply; do not wrap in a smaller `SizedBox`).

## Components: pick the standard one

| Need | Component |
|---|---|
| Top of screen | `AppBar` (small), `AppBar.medium` / `.large` via `SliverAppBar` for scrolling titles |
| Primary action | `FilledButton`; `FloatingActionButton` / `.extended` for the screen's single create action |
| Secondary / tertiary | `FilledButton.tonal`, `OutlinedButton`, `TextButton` |
| Top-level navigation | `NavigationBar` (3-5 destinations, labels always), `NavigationRail` on wide layouts |
| Lists | `ListTile` (one/two/three lines), `ListView.separated`; cards only when items are rich |
| Grouping | section header (`titleSmall`/`labelLarge` in `primary`), `Divider` sparingly |
| Selection | `SegmentedButton`, `FilterChip`, `ChoiceChip`, `Radio`/`RadioListTile`, `Checkbox`, `Switch`/`SwitchListTile` |
| Input | `TextField` with `OutlineInputBorder` or filled (one style per app), `labelText` not placeholder-only, `helperText`, `errorText` |
| Search | `SearchBar` + `SearchAnchor` |
| Transient info | `SnackBar` (with `SnackBarAction` undo), `Tooltip` |
| Decision | `AlertDialog` (`showAdaptiveDialog`), confirm destructive with the action named ("Delete note") |
| Secondary flow | `showModalBottomSheet` (with drag handle) for quick choices; full page for long forms |
| Progress | `CircularProgressIndicator` (centred, indeterminate), `LinearProgressIndicator` under AppBar for background work |
| Tags / metadata | `Chip` (static) vs `ActionChip`/`FilterChip` (interactive); never style a static label as an interactive chip |
| Badge | `Badge` on icons |

## Motion

- Durations: short 50-200 ms (selection, toggles), medium 250-400 ms
  (expand, sheet), long 450-600 ms (page, large transforms).
- Easing: `Curves.easeInOutCubicEmphasized` for entering/exiting large
  elements, `Curves.easeOutCubic` for standard.
- Respect `MediaQuery.disableAnimationsOf(context)`; implicit widgets
  (`AnimatedContainer`, `AnimatedSwitcher`) are enough for most screens.
- Page transitions: `PageTransitionsTheme` in `ThemeData`; `fullscreenDialog`
  pages slide from the bottom.

## Material 3 Expressive (2025+)

Newer M3 guidance adds spring-based motion, shape morphing, button
groups, FAB menus and a floating toolbar, plus more emphasis on
large, tactile components. In Flutter, availability arrives
incrementally: use what the SDK ships (`SegmentedButton`,
`FilledButton.tonal`, `NavigationBar`, `SearchBar`, `Badge`,
`CarouselView`) and do not invent custom components to imitate ones not
yet available. If a design needs expressive shapes, use `ShapeDecoration`
with `RoundedSuperellipseBorder` / `ContinuousRectangleBorder` sparingly.

## Theme wiring checklist (Flutter)

```dart
ThemeData(
  colorScheme: ColorScheme.fromSeed(seedColor: seed, brightness: brightness),
  textTheme: ...,                 // only if a custom font or scale is required
  appBarTheme: AppBarTheme(centerTitle: false),
  cardTheme: const CardThemeData(margin: EdgeInsets.zero),
  inputDecorationTheme: const InputDecorationTheme(border: OutlineInputBorder()),
  filledButtonTheme: ...,         // sizes once, not per button
  navigationBarTheme: ...,
  pageTransitionsTheme: const PageTransitionsTheme(builders: {
    TargetPlatform.android: PredictiveBackPageTransitionsBuilder(),
    TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
  }),
)
```

Every screen reads `Theme.of(context).colorScheme` and `.textTheme`. A
`ThemeExtension` holds app-specific tokens (e.g. `success` colour, chart
palette) so they are themed in dark mode too.
