# Launch post drafts (not committed until reviewed)

## r/FlutterDev

**Title:** I measured whether agent skills change what Claude builds in Flutter. Without a capture loop, 0 page transitions out of 40. With it, 46 out of 46.

**Body:**

I built two agent skills for Claude Code / Codex (design and audit of Flutter UI) and a small Dart tool, `cerebro`, that captures one headless screenshot per go_router route under `flutter test` (no emulator), dumps semantics, measures touch targets and contrast, taps every control to build a navigation map, and records whether each tap animated.

Then I gave the same brief (a second-hand marketplace app, 5 screens, an offer flow with retry and expiry, a detailed aesthetic direction) to the same model seven times, in fresh empty projects, with and without the toolkit, and captured every result with the same configuration.

What came out:

- Without the tool, go_router silently used `NoTransitionPage` in every run and nothing ever animated. The agents with the tool saw `transition: instant` in their own capture, fixed it and wrote a regression test.
- Two independent no-tool runs shipped the same crash (`ScrollController.jumpTo` on an offstage list). The explorer reports it as a tap that throws.
- Structure and measured quality became stable across three toolkit runs; typography did not. That is what the prototype step (2-3 rendered directions per key screen, picked before building) is for.
- Cost: $6-8 and 25-40 min per run without, $9.5-9.7 and 32-33 min with.

Limits: one brief, one model (Opus 5.5), three runs on the toolkit arm and one on the others. Every number, prompt and per-run report is in the repo.

Repo: https://github.com/mattparadis/cerebro-flutter (Apache-2.0). Quick start on the demo app is one `dart run cerebro capture`, 56 screenshots in under 30 s on my machine.

Works with go_router and plain `MaterialApp.routes`; auto_route and real-device checks are not there yet. Happy to hear what breaks on your app.

## Show HN

**Title:** Show HN: Cerebro – headless screenshots and a navigation map for Flutter apps, built for coding agents

**First comment:** (same content as above, shorter, leading with the method and the limits, then the link)
