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
