# Rigattiere A/B: results

> **Update, same day:** run B never invoked the skills (see "Run B2" at the
> end). The A-vs-B comparison below is therefore two no-skill runs; the
> valid skills-plus-tool run is B2.

Two headless Claude Code runs (Opus 5.5, same prompt in `prompt.txt`, same
empty `flutter create` project, 2026-11-08). **A** had no skills and no tool.
**B** had `skills/` linked as `.claude/skills` and `.agents/skills`, nothing
else. Neither could reach the network or run `flutter build`/`flutter run`.

| | A (no skills) | B (skills) |
|---|---|---|
| Wall time | 24 min | 29 min |
| Cost | $6.25 | $8.06 |
| Turns | 133 | 165 |
| Own tests (verified) | 67 pass | 98 pass |
| `flutter analyze` | clean | clean |
| Own screenshot harness | 33 PNG, real fonts from `flutter_gallery_assets` | 28 PNG, **Roboto stand-in** for both fonts |
| Used ui_map | no | **no** |
| Fonts | Abril Fatface + Libre Franklin + Oswald, bundled | Bricolage Grotesque + Atkinson Hyperlegible via `google_fonts` at runtime |
| Settings | own page `/profile/settings` | bottom sheet from Profile |

## ui_map capture (added by us afterwards, same config for both)

22 locations × light/dark × text 1.0/1.3, keyboard on `/sell` and `/chat/:id`,
explore on. Real fonts preloaded for both (B's fonts downloaded from the same
URLs `google_fonts` uses).

| map.json summary | A | B |
|---|---|---|
| screens ok | 88/88 | 88/88 |
| layout exceptions | 0 | 0 |
| screens with tappables < 48 dp | 28 | 14 |
| screens with low contrast | 16 | 20 |
| explored taps | 145 | 138 |
| push / pop / go / overlay | 21 / 19 / 0 / 1 | 23 / 19 / 1 / 3 |
| no observed effect | 10 | 13 |
| error edges | 1 | 1 |
| lint | 0 | 3 convention (literal font size), 1 info |

### Findings, with status

**Both apps**
- confirmed: tapping "See other …"/"More in …" on a sold item throws
  `Null check operator used on a null value` from `ScrollController.jumpTo`:
  the Browse screen listens to the shared filter notifier and jumps its
  scroll view while it is offstage under the item route. Same bug, same
  shape, written independently. No visible effect for the user after the
  navigation, but an exception on every tap.
- suspected: list content runs under the "Sell something" FAB (last row's
  text is covered); the text under it is what ui_map measured at ratio ~1.1.
- not_checked (device only): TalkBack order, back gesture, real keyboard.

**A**
- confirmed: Browse filter chips are 40 dp tall on Android (every Browse
  capture). B's chips are 48 dp.
- confirmed: muted meta text on paper is 2.5–2.6:1 ("900 m", "Santo
  Stefano", description lines on the item screen) against 4.5 required.
  The ACCEPTED stamp is 3.9–4.35:1.
- suspected: the Description field's helper and counter sit under the
  sticky "Post it" bar on `/sell` at the initial scroll.
- Sticky CTA on Sell stays visible with the keyboard open (good).

**B**
- confirmed: "Davide declined." is 3.97:1 (8 captures); small-caps labels
  ("LUCA'S OFFER", "Asking €110") 4.43–4.46:1, just under 4.5.
- confirmed: the chat Send button is tappable with an empty composer and
  does nothing (no_observed_effect on every chat); A disables it.
- confirmed: one unlabeled control in the offer sheet, one unlabeled
  353×22 dp tappable at the bottom of `/sell` (likely the clipped
  Description field, see tool notes).
- suspected: "Make a new offer" is an underlined text link where A uses a
  button; lower affordance.
- The Sell CTA is at the end of the form, not sticky: with the keyboard
  open it is off-screen.
- 3 literal font sizes outside the theme.

### Tool notes (capture artefacts seen here)
- Tappables clipped by the viewport edge (chips under the keyboard, a field
  at the bottom) are reported as small. Needs a `clipped` flag.
- Text occluded by a FAB or sticky CTA is measured against the button
  colour (ratio ~1.0). Needs an `occluded` class.
- Error edges keep only the exception's first line; a manual widget test
  was needed to find the `jumpTo` frame.
- Fixed during this run: `params` lists, `drain_timers_ms`, root-variant ids.

## Verdict

Visual quality (sheets in `rigattiere/sheet1-3.jpg`, A on top, B below):
B's item page (full-bleed photo, floating back/save, condition chip beside
the price, seller card) and its larger, more legible type are the clear
differences. Its Settings-as-sheet and the struck-through sold price are
nice touches. A has the denser "classified" row, a details table, a sticky
Sell CTA and a dedicated Settings page. Chats, profile, empty/error/loading
states and dark mode are close to interchangeable; both followed the
aesthetic brief (terracotta only for actions, oxblood errors, stamps,
hairlines) almost identically, so the prompt drove the look more than the
skills did.

Measured quality: B has half the touch-target failures and no 2.5:1 text,
but more borderline (4.4:1) labels and a no-op Send button. B wrote 46%
more tests, including the overflow sweep at 1.3× that the skill asks for.
Both shipped the same offstage-scroll bug.

What the skills did **not** achieve: B never installed or ran ui_map (the
skill assumes it is present and the package was not reachable offline), so
the capture loop that is the point of the toolchain did not happen in
either run. Fixes are in `todo.md`.

Reproduce: `claude --resume 2d56ebb4-ef2a-40a0-a001-1eb07ff9b333` in
`~/code/rigattiere-a`, `claude --resume 19f25c77-c7da-48d1-a37b-4bc4f76d35c2`
in `~/code/rigattiere-b`.


## Run B2: the valid skills + tool run

Run B's transcript shows no `SKILL.md` read, no Skill call and no mention
of ui_map in 165 turns: the skills were listed in its context but the
`design-screen` description only matched single-screen requests. Two fixes
(commit `5eebe52`): the description now triggers on whole-app briefs, and
a setup section tells the agent how to add and scaffold ui_map. B2 ran on
a fresh project with the skills linked, `ui_map` already a path dev
dependency, and three extra prompt lines saying the skills and ui_map are
installed (`prompt-b2.txt`).

| | A | B | **B2** |
|---|---|---|---|
| Wall time / cost / turns | 24 min / $6.25 / 133 | 29 min / $8.06 / 165 | 29 min / $7.32 / 156 |
| Invoked design-screen | no | no | **yes (build mode)** |
| Ran ui_map itself | no | no | **yes: 256 captures, 2 devices, explore, lint** |
| Own flow tests (verified) | 67 | 98 | 17 (+256 capture tests) |
| Fonts | bundled from gallery assets | google_fonts at runtime | bundled from gallery assets, loaded in the factory |
| Settings | own page | bottom sheet | inline on Profile |
| Extra screen | none | none | Messages inbox at `/chat` (justified: deep-linked chats need a back target) |

Standard ui_map config (one phone, light/dark, 1.0/1.3, keyboard on sell
and chat, explore), 92 captures for B2 vs 88 for A and B:

| | A | B | **B2** |
|---|---|---|---|
| screens with tappables < 48 dp | 28 | 14 | 22 |
| screens with low contrast | 16 | 20 | 13 |
| error edges (exceptions on tap) | 1 | 1 | **0** |
| no observed effect taps | 10 | 13 | 19 |

B2 findings:
- confirmed: the Condition picker on `/sell` is a radio (40×40 dp,
  unlabeled) next to a 21 dp text row; the row should be one labelled
  48 dp target. This is where most of B2's small-target count comes from.
- confirmed: muted meta on the item screen at 1.3× is 2.55–2.97:1
  ("yesterday", "Bikes", "FROM THE SELLER"); "Log out" 3.86:1.
- no offstage-scroll bug: Browse keeps filter and scroll through
  `AppScope` without touching the controller from a listener.
- no-effect taps are all "already selected" controls (theme segment,
  current tab) and the "All" chip; acceptable, A and B had the same.
- Sticky "Post item" CTA stays visible with the keyboard open; sold item
  gets a struck price, a stamp and a "More <category>" button; the offer
  panel explains the declined amount and the allowed range; the seller
  side shows "You're asking €45" next to the offer. Copy is the most
  consistent of the three (sheet in `rigattiere/sheet4-a-b-b2.jpg`).
- B2 reported a real ui_map limitation: `fonts:` cannot take package asset
  keys, so it loaded the fonts itself in the factory. Also found while
  evaluating: with `--config` outside the project, `out_dir` resolves
  against the config file's folder, not the project.

Verdict after B2: with the skill actually triggered, the agent set up the
capture loop on its own, checked two phone sizes and 1.3× text, ran lint,
produced the only run with zero tap exceptions and the lowest contrast
count, and spent less than B. The visual direction is still mostly the
prompt's; what the skill added is process (states by URL, flow contract
tests that were mutation-checked, capture evidence) and a few conventions
(one stamp per screen, display face only for prices and short titles).
Remaining gap is the skill's own trigger reliability without the explicit
"use the skills" line, which this run did not test.

Session: `claude --resume c52ab8ed-cf81-4dc3-a5d8-5d3ce4e3ba9e` in
`~/code/rigattiere-b2`.
