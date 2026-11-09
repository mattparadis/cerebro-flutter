## 0.2.0

- Navigation map: pushes to unnamed Navigator 1.0 routes are matched to a
  captured screen by a labels fingerprint (`resolved_by_fingerprint`,
  `to_fingerprint` on the edge, `fingerprint` per screen); routes that only
  open overlays on themselves are drawn in their own dashed row instead of
  piling up in the first column.
- `error` edges carry `error_stack` (app frames first).
- Contrast: text with no glyph pixels in its rect (under an opaque bottom
  bar or sheet, or clipped) is `not visible` in `contrast_not_measurable`,
  counted in `contrast_coverage.not_visible` and `not_visible_texts`.
- Tap targets: an unlabeled checkbox/radio/switch carries a `hint` with the
  one-target fix (`*ListTile`).
- Lint: `scroll-from-listener` (jumpTo/animateTo in a listener without
  `hasClients`) and `go-route-builder-transitions` (`GoRoute(builder:)`
  with no `pageBuilder` and no `PageTransitionsTheme` in the project).
- `fonts:` accepts package asset keys (`packages/<pkg>/fonts/x.ttf`),
  resolved through `.dart_tool/package_config.json`.
- `--config` outside the project: a relative `out_dir` now resolves against
  the project root, not the config file's folder.
- Test guarding the shipped skills' frontmatter (valid YAML, `name`,
  `description`).

## 0.1.0

First public release, formerly `ui_map`.

- `init`, `routes`, `capture` for go_router apps and `MaterialApp.routes`
  (Navigator 1.0) apps, under `flutter test`: no emulator, no device.
- Per screen: PNG, semantics dump, tap targets below the platform minimum
  (clipped targets listed apart), WCAG contrast per text run with occluded
  texts listed apart, text without a font family, layout exceptions.
- Devices, themes, platforms, text scales, locales, keyboard-open captures,
  URL variants and factory scenarios.
- `--explore`: taps every control and records push / pop / go / overlay /
  state_change / no_observed_effect / error edges, with motion evidence
  (`transition`, `transition_ms`, `self_transition`).
- Prototype sheets for `/__proto/<name>` routes (`PROTO.md`).
- Navigation map picture: `map.dot` always, `map.png` / `map.svg` when
  Graphviz is installed; one node per route with its screenshot.
- `baseline`, `diff`, `check` for regressions; `lint` with ten rules.
