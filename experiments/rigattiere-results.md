# Rigattiere A/B: results

> Names in this document are the ones used during the runs: the tool was
> `ui_map` (now `cerebro`), the skills `design-screen` / `audit-screens`
> (now `cerebro-design` / `cerebro-audit`).

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


## Run B3: prototype-first, motion contract, fonts from the network

After B2 the person's verdict was "not that different from A, settings a
bit nicer, no animations anywhere". Three changes (commit `49c2dc4`):
prototype mode is now mandatory when starting from a brief, the brief has
a motion contract and `patterns.md` a Motion section, and ui_map's
explore records per-edge `transition` evidence (frames sampled every
50 ms with the tapped rect masked). B3 ran on a fresh project with the
skills, ui_map as a path dependency, `curl` allowed and one prompt line
saying fonts can be downloaded (`prompt-b3.txt`).

| | B2 | **B3** |
|---|---|---|
| Wall time / cost / turns | 29 min / $7.32 / 156 | 32 min / $9.60 / 199 |
| Prototype step | none | **Browse: 3 directions** (list / big-photo feed / grid), scored in DESIGN.md, sheet in `rigattiere/b3-proto-browse.jpg`; detail and sell were not prototyped |
| Fonts | gallery-assets stand-ins | **Bricolage Grotesque + Atkinson Hyperlegible Next, downloaded and bundled** |
| Own capture | 256 screens, 2 devices | 104 screens, explore, lint, `audit/SUMMARY.md` |
| Own tests | 17 flow | 23 flow + **a regression test that pushes animate** |
| Navigation | nested routes only | **bottom bar** Browse / Messages / Profile with badge |
| Bugs its loop caught | scroll-to-error no-op | **every push/pop instant**, off-screen fields escaping validation, chips without the font |

Standard config (one phone, light/dark, 1.0/1.3, keyboard, explore), all
four runs re-captured with the same ui_map build:

| | A | B | B2 | **B3** |
|---|---|---|---|---|
| captures | 88 | 88 | 92 | 96 |
| screens with tappables < 48 dp | 28 | 14 | 22 | 14 |
| screens with low contrast | 16 | 20 | 13 | 19 |
| error edges | 1 | 1 | 0 | 0 |
| navigation edges animated / instant | 0 / 40 | 0 / 43 | 9 / 48 | **45 / 5** |
| state changes animated / instant | 37 / 46 | 14 / 55 | 16 / 66 | 38 / 60 |
| continuous (still moving after 600 ms) | 10 | 9 | 1 | 2 |

Reading the motion row: in A, B and B2 **no page transition ever ran**.
go_router built `NoTransitionPage` for their `builder:` routes (B2's nine
animated edges are its one explicit `MaterialPage`); none of the agents
noticed because nothing showed it. B3's own capture showed `instant` on
every push, it switched to explicit `MaterialPage`s, set a
`PageTransitionsTheme`, and wrote a regression test. The 60 instant
state changes in B3 are mostly field focus, chip selection and toggles
whose own animation sits inside the masked rect, plus bookmark toggles
that could animate. `continuous` in A and B are the offer-expiry
countdowns and skeletons left running.

B3 findings (standard capture):
- confirmed: the `€` sign and helper text on the Sell form at 2.7-3.2:1;
  muted price-tag euro sign at 2.71:1 against 3.0 required.
- suspected: "Flaws, measurements…" placeholder and the counter at 1.17:1
  are the field under the sticky CTA (occlusion, see tool notes).
- small targets are clipped chips and fields at the viewport edge, plus
  "Post another item" at 42 dp.
- no error edges; Discard-style deep-link pops handled.

Verdict after B3: the prototype step and the motion evidence changed the
outcome in ways the first three runs could not: a layout chosen among
three rendered alternatives, real typography, page transitions that
exist and are tested, a bottom bar that makes the inbox reachable.
Cost went up by about a third. Still open: the skill asked for three key
screens and the agent prototyped one (now spelled out in the skill), and
the comparison is one run per arm, so run-to-run variance is not
controlled. Sheet: `rigattiere/sheet5-a-b-b2-b3.jpg`.

Session: `claude --resume 6cf5cb54-1484-4fbe-af3c-f7786da790dc` in
`~/code/rigattiere-b3`.


## Runs B3b and B3n: variance and natural triggering

Two more runs after two measurement fixes in ui_map (`clipped` targets,
`occluded` texts, commit `1a91171`): **B3b** repeats B3's prompt exactly;
**B3n** drops the "skills are installed, use them" lines and keeps only
the network note. Fresh projects, same model and permissions.

| | B3 | B3b | B3n |
|---|---|---|---|
| Wall time / cost / turns | 32 min / $9.60 / 199 | 33 min / $9.47 / 205 | 33 min / $9.68 / 203 |
| Skill invoked | yes (hinted) | yes (hinted) | **yes, by itself, after 10 s, no hint** |
| Prototyped screens | Browse only | **Browse, detail, sell** (3+2+2) | **Browse, detail, sell** (3+2+2) |
| Fonts bundled | Bricolage Grotesque + Atkinson Next | Fraunces + Atkinson Next | Big Shoulders Display + Atkinson |
| Bottom bar | yes | yes | no (chats from item and My listings) |
| Own flow tests | 23 | 16 | 16 |
| Bugs its loop caught | instant pushes, validation gap, chip font | invisible chip labels, accent on secondary buttons, faint disabled button, hidden composer | 800 ms default transition replaced by 300 ms, 14 occluded texts recognised as hidden |

Standard config, all six runs captured with the final ui_map (clipped and
occluded classes applied uniformly):

| | A | B | B2 | B3 | B3b | B3n |
|---|---|---|---|---|---|---|
| captures | 88 | 88 | 92 | 96 | 92 | 92 |
| screens with real tappables < 48 dp | **28** | 0 | 0 | 0 | 0 | 0 |
| screens with clipped tappables (not findings) | 18 | 14 | 22 | 14 | 12 | 18 |
| screens with real low contrast | 6 | **16** | 6 | 5 | 3 | 2 |
| occluded texts (not findings) | 21 | 4 | 13 | 22 | 18 | 22 |
| error edges | 1 | 1 | 0 | 0 | 0 | 0 |
| navigation animated / instant | 0 / 40 | 0 / 43 | 9 / 48 | 45 / 5 | 43 / 5 | **46 / 0** |
| state changes animated / instant | 37 / 46 | 14 / 55 | 16 / 66 | 38 / 60 | 16 / 74 | 35 / 68 |
| continuous after 600 ms | 10 | 9 | 1 | 2 | 0 | 0 |

With the two measurement classes applied, the picture is cleaner than in
the earlier tables: A's 40 dp chips are the only real small-target defect
in the whole experiment, B's muted declined text is the only run with
double-digit contrast failures, and only the B3 family has page
transitions. The remaining contrast findings in B3/B3b/B3n are a handful
of 3.2-4.0:1 labels each.

What the two extra runs settle:
- **Trigger:** the broadened description fires on a whole-app brief
  without being told (one data point, but a clean one).
- **Prototype step:** with "three screens" spelled out, both runs did all
  three with structurally different directions (list / grid / feed;
  photo-first / title-first detail; one-page / three-step sell). Sheets:
  `rigattiere/b3b-b3n-protos-light.jpg`.
- **Variance:** structure and process are stable across the three B3 runs
  (classified rows, price first, one stamp, offer slip, CTA with the price,
  animated pushes, zero tap exceptions, zero real small targets). What
  varies is typography (three different display faces from the same brief
  line) and one navigation decision (bottom bar or not). Cost is stable
  at $9.5-9.7 and 32-33 min.
- **Honest limit:** three runs of one arm against one run each of the
  others; the no-skill arm was never re-run with network access, so the
  typography gap partly measures the font rule, not the skills.

Sheet: `rigattiere/sheet6-a-b3-b3b-b3n.jpg`. Sessions:
`1e3be76e-c160-42d7-af6f-5b3e6d856b86` (B3b), `a09a8541-3993-4b46-bb9c-c3230a2bfb6b` (B3n).


## Run A2: no skills, no tool, network open

The control that was missing: `prompt-b3n.txt` (the original brief plus the
line that says fonts can be downloaded), no skills linked, no `ui_map` in
`pubspec.yaml`, `curl` allowed. Session `ead9bcf2-c3f8-4f9f-9a70-2686f0737b25`,
39 min, $6.81, 125 turns, 38 widget tests, analyze clean. It downloaded and
bundled Fraunces (variable) and Atkinson Hyperlegible, wrote its own
`test_screenshots/` harness with 26 PNGs, and used `MaterialPage` on one
route only (`/sell`).

Standard capture (factory added by us, `FakeMarket` disposed with the tree
because its offer timers otherwise outlive every test):

| | A | **A2** | B3 | B3b | B3n |
|---|---|---|---|---|---|
| captures | 88 | 84 | 96 | 92 | 92 |
| real tappables < 48 dp (screens) | 28 | 2 | 0 | 0 | 0 |
| real low contrast (screens) | 6 | 5 (SOLD stamp 2.4:1, "11 h ago" 2.9:1) | 5 | 3 | 2 |
| error edges | 1 | 0 | 0 | 0 | 0 |
| navigation animated / instant | 0 / 40 | **9 / 37** | 45 / 5 | 43 / 5 | 46 / 0 |
| state changes animated / instant | 37 / 46 | 38 / 43 | 38 / 60 | 16 / 74 | 35 / 68 |

Reading: with the font gap removed, A2 closes most of the distance on
targets and contrast (it is a careful run), but keeps the structural
difference: no prototype step, no inbox or bottom bar, and page
transitions missing on every route except the one it happened to declare
with `MaterialPage`. The B3 runs found that defect in their own capture;
A2 had no capture that could show it. Sheet: `docs/img/benchmark-a2-vs-b3.jpg`.
