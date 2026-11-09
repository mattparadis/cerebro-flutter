# cerebro

Headless screenshots, semantics, touch-target and contrast measurement,
and a tap-by-tap navigation map for Flutter apps, produced under
`flutter test` with no emulator. Built for coding agents (Claude Code,
Codex) and usable on its own.

```sh
dart pub add dev:cerebro
dart run cerebro init        # cerebro.yaml + test/cerebro/app_factory.dart
dart run cerebro routes      # lists the locations it will capture
dart run cerebro capture --explore
```

Full documentation, the agent skills that drive it and a benchmark are in
the repository: <https://github.com/mattparadis/cerebro-flutter>.
