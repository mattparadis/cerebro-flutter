# Nielsen's 10 usability heuristics, applied to Flutter screens

Source: Jakob Nielsen, "10 Usability Heuristics for User Interface Design",
Nielsen Norman Group (https://www.nngroup.com/articles/ten-usability-heuristics/).
Use these as the "why" behind findings and as a sweep after the checklist:
for each heuristic, ask what on this screen violates it. Severity uses
Nielsen's 0-4 scale (see SKILL.md).

| # | Heuristic | What to look for in the screenshot / semantics | Typical Flutter fix |
|---|---|---|---|
| 1 | **Visibility of system status** | Loading shows progress (indicator or skeleton); toggles reflect state; selected tab/plan is obvious; sync/offline state visible; a Save button gives feedback. | `CircularProgressIndicator`/skeleton in `FutureBuilder` waiting branch; `SnackBar` or inline status after actions; `Switch` bound to real state. |
| 2 | **Match between system and real world** | Labels in the user's words, verb-first actions, no jargon, no raw exceptions (`StateError:`, `Exception:`), dates and money formatted. | Map errors to copy before display; `intl` `DateFormat`/`NumberFormat`; rename "OK/Submit" to "Save note". |
| 3 | **User control and freedom** | A way back or out on every screen (AppBar back, close × on modals, "Not now" on paywalls); undo for destructive actions; cancel in forms; swipe-back on iOS. | `AppBar` leading; `fullscreenDialog` pages with close; `SnackBarAction` undo; `PopScope` only with an explicit alternative. |
| 4 | **Consistency and standards** | One gutter, one type scale, one button hierarchy across screens; platform idiom respected; icons mean the same everywhere; same action in the same place. | Component themes in `ThemeData`; shared widgets (`ScreenTitle`, `SectionHeader`); `Icons.adaptive.*`. |
| 5 | **Error prevention** | Disabled primary action until the form is valid; confirmation for destructive actions; input types and autofill reduce typos; sensible defaults selected. | `onPressed: null` when invalid; `showAdaptiveDialog` confirm; `keyboardType`, `autofillHints`, `inputFormatters`. |
| 6 | **Recognition rather than recall** | Labels visible (not placeholder-only); recent items and suggestions; current filter/sort shown; icons with labels in nav. | `InputDecoration.labelText`; chips for active filters; `NavigationBar` labels always shown. |
| 7 | **Flexibility and efficiency of use** | Shortcuts for frequent tasks (FAB for the main create action, swipe actions, long-press), search where lists are long, remembered settings. | `FloatingActionButton.extended`; `Dismissible`; `SearchBar`/`SearchAnchor`. |
| 8 | **Aesthetic and minimalist design** | One primary action; no competing accents; copy short; no decorative chrome; whitespace consistent; nothing that does not help the task. | Demote secondary actions to `TextButton`/overflow menu; remove cards-in-cards; use `surfaceContainer*` tiers instead of borders+shadows. |
| 9 | **Help users recognise, diagnose and recover from errors** | Error states in plain language with a cause and a next step; field errors next to the field; retry available; no dead ends. | `_ErrorState(message, onRetry)` pattern; `InputDecoration.errorText`; `FilledButton.tonal('Try again')`. |
| 10 | **Help and documentation** | First-run guidance where needed (onboarding, empty states that teach), contextual hints, link to help/legal from settings. | Empty states with one action; `Tooltip`; About screen with policy links that actually open. |

## How to use in an audit

1. After the checklist, scan the ten rows once for the screen. Most screens
   will trigger at most two or three.
2. Write the finding under the checklist group it belongs to (states,
   navigation, content, ...), and name the heuristic in "Why it matters":
   "Violates H3 user control: no way to leave the paywall."
3. Do not add a separate "heuristics" table per screen; the mapping is the
   rationale, not another list.
