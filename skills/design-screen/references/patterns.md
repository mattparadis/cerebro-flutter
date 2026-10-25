# Screen patterns, states and navigation semantics

Use the archetype as the skeleton, then design every state. Adapted ideas
from appllama-skills (navigation semantics), parhamb/design-skills and
Checklist Design (MIT); see NOTICE.

## Archetypes

| Archetype | Skeleton | Primary action | Must-have states |
|---|---|---|---|
| **List / feed** | AppBar (title, 1-2 actions) · optional filter row · `ListView.separated` of tiles or cards · FAB for create | create (FAB) or open item | full, empty (teach + action), loading (skeleton, same chrome), error (message + retry), offline |
| **Detail** | AppBar with back and 1-2 actions · hero/meta · body · bottom action bar if the detail has a main action | edit / share / primary domain action | loaded, loading, not found, error |
| **Form / create** | modal page (`fullscreenDialog`) or sheet · close × left · Save right (disabled until valid) · fields top-down, one column | Save | empty, valid, invalid (inline errors), saving, saved (dismiss + confirmation) |
| **Onboarding** | 2-4 pages, one idea each · page indicator · Skip top-right · Next / Get started bottom · `SafeArea` | continue | per page; last page leads to auth or home |
| **Auth** | logo · title · 2 fields with autofill · primary · secondary (guest / social) · forgot password · legal footer | sign in | idle, submitting, error (message near fields), success |
| **Paywall** | value proposition · 2-3 plans (selected by default, radio semantics) · primary CTA with price/trial · "Not now" · transparency line (renewal, cancel) · restore purchases | start trial / subscribe | idle, purchasing, error, restored |
| **Settings** | inset grouped lists with section headers · tiles with trailing switch, value or chevron · destructive at the bottom (sign out, delete) | none (each tile is its own) | loaded; per-tile loading if remote |
| **Search** | `SearchBar` top · suggestions / recent chips · results list | search | idle (recent), typing (suggestions), results, no results (with hint), error |
| **Dashboard** | summary tiles (max 4) · one chart · list of latest · period selector | drill-down | loaded, loading (skeleton tiles), empty period, error |
| **Empty / first-run** | icon or illustration · title (what this is) · one line (what to do) · one action | the action | single |

## State design rules

- **Empty** is a screen, not a line: icon (`outline` colour), `titleLarge`,
  one `bodyMedium` line in `onSurfaceVariant`, one action. Copy specific
  to the screen ("Your first field note is one tap away").
- **Loading** keeps the chrome (AppBar, nav) and the layout: skeleton
  rows the same height as real rows, or a centred indicator with no
  layout shift when data arrives. Never a blank page.
- **Error** names the problem in plain words, hides the technical cause
  (log it), offers one retry and, if possible, an alternative (offline
  data, go back). Raw `Exception:`/`StateError:` text is a defect.
- **Partial** (some data, some failed) shows what loaded and an inline
  banner for the rest.
- **Destructive**: confirm with the action named ("Delete note", not
  "OK") or offer undo via snackbar for 5 s; disabled states explain why
  (helper text), never silently.

## Navigation semantics (decide per transition)

| Transition | Use when | go_router / Flutter |
|---|---|---|
| **Push** | drilling into content; back returns to the list in the same state | `context.push('/notes/1')`; child route of the list |
| **Replace / go** | finishing a flow (auth → home, onboarding → login); back must not return | `context.go('/notes')` after the flow; top-level routes |
| **Modal page** | creating or editing; self-contained task with Cancel/Save | `pageBuilder` + `MaterialPage(fullscreenDialog: true)`; close × left |
| **Sheet** | quick choice, filter, share, short form (< 1 screen) | `showModalBottomSheet` (drag handle, `useSafeArea`) / `showCupertinoSheet` |
| **Dialog** | a decision that blocks (destructive confirm, permission rationale) | `showAdaptiveDialog`, two actions max |
| **Tabs** | top-level sections of equal rank; state preserved per tab | `StatefulShellRoute.indexedStack`; 3-5 branches; current tab tap pops to root |
| **No back** | forced flows (paywall after onboarding, mandatory update) | `PopScope(canPop: false)` **only** with an explicit alternative on screen ("Not now", "Skip") |

Rules: one modal at a time; no push from a sheet (dismiss, then push);
deep links open the screen with its parent stack (`/notes/1` can pop to
`/notes`); tab switches never push; the system back button and the
AppBar back do the same thing.

## Forms

- One column, labels above or floating (`labelText`), never placeholder
  only; helper text for format; `keyboardType`, `textInputAction`
  (`next` / `done`), `autofillHints`, `obscureText` with a show toggle.
- Validate on submit and on blur after first error, not on every
  keystroke; error text under the field, field outlined in `error`;
  focus the first invalid field.
- Primary action pinned at the bottom (above the keyboard with
  `resizeToAvoidBottomInset`) or in the AppBar for modal creation;
  disabled until valid.
- Multi-step forms show progress ("Step 2 of 3") and keep entered data on
  back.

## Onboarding and permissions

- Ask for permissions in context, after showing value, with a rationale
  screen first; never on launch.
- Onboarding is skippable; 2-4 pages; the last page ends in a decision
  (sign in / continue), not another "Next".

## Paywalls (transparency first)

- Show what is included, the price per period and the renewal rule
  before the CTA; trial length and "cancel anytime" in plain words.
- Default plan selected and announced as a radio group; the CTA restates
  the commitment ("Start 7-day free trial, then €29.99/year").
- An exit is visible without scrolling. Restore purchases is reachable.
- Dark mode and large text verified: this screen is often hardcoded.

## Settings

- Group by topic with headers; max 7 tiles per group; value shown on the
  tile (`subtitle` or trailing text); chevron only when it navigates.
- Account and destructive actions last; destructive in `error` colour
  with confirmation.
- Theme, text size and language changes apply immediately.
