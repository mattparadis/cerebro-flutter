# Device checks the capture cannot do

The headless capture renders layout, colour, text, semantics and
navigation. It does not run the platform. Every audit lists these as
`not_checked` unless someone ran them on a device, with the result.
Each check: steps, what "pass" looks like, what to record.

| # | Check | Steps | Pass | Record |
|---|---|---|---|---|
| D1 | Screen reader order | Android: TalkBack on, swipe right through the screen. iOS: VoiceOver on, swipe right. | Order follows the visual reading order; every control is announced with role and state; no "button" without a name; meaningful images have labels, decorative ones are skipped. | Screens tried, controls mis-announced, missing names. |
| D2 | Headings and route announcement | With the screen reader, open the screen from the previous one. | The screen title is announced on arrival; headings navigable (TalkBack local context menu → Headings; VoiceOver rotor → Headings). | Screens without announcement. |
| D3 | Focus and keyboard | Connect a hardware keyboard (or Tab on desktop builds). Tab through the screen. | Focus ring visible; order logical; Enter/Space activate; Esc closes sheets/dialogs; no focus trap. | Controls unreachable or trapped. |
| D4 | Back gesture / button | Android: edge swipe and system back. iOS: edge swipe. On each screen, including modals and sheets. | Behaves like the AppBar back/close; predictive back previews the previous screen on Android 14+; no screen where back does nothing silently. | Screens where back is inconsistent. |
| D5 | Real keyboard overlap | Focus each text field, scroll to the end of the form. | Focused field and submit action stay visible above the keyboard; the form scrolls; `resizeToAvoidBottomInset` behaviour is intentional. | Fields or CTAs hidden by the keyboard. |
| D6 | Large text and bold text | System font size at the largest step (and "Bold text" on iOS). Open every screen. | No clipped or overlapping text; fixed-height containers do not cut text; single-line rows wrap or scroll. | Screens that break and at which step. |
| D7 | Display size / zoom | Android display size at the largest step. | Same as D6 for layout density. | Screens that break. |
| D8 | Reduce motion | Enable the OS setting. Trigger transitions, expanding content, loaders. | Animations shortened or replaced by fades; nothing depends on motion to be understood. | Animations that ignore the setting. |
| D9 | High contrast / inversion | Enable high-contrast text (Android) or Increase Contrast (iOS). | Text readable; icons keep contrast; no colour-only meaning lost. | Elements that become unreadable. |
| D10 | Haptics and sound | Perform destructive and confirming actions. | Feedback matches platform conventions; no haptics on every tap. | Overuse or absence. |
| D11 | Plugins and permissions | Trigger camera, location, notifications, payments, deep links. | Rationale before the system prompt; denial handled with a next step; deep link opens the right screen with a back stack. | Flows that dead-end on denial. |
| D12 | Network conditions | Airplane mode, then slow network (developer options). | Offline state explicit, retries work, no infinite spinner; slow loads show progress. | Screens without offline handling. |
| D13 | Interruptions | Rotate (if supported), background and return, incoming call, system dialog. | State preserved, no re-fetch storm, form input kept. | State lost on which screen. |

Record results in the audit summary under "Device checks" as `pass`,
`fail` (with the finding) or `not run`. A check that was not run is
`not_checked`, never implied.
