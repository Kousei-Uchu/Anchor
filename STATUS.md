# Anchor: where things stand

*Short current picture, kept up to date by the patches. The running plan is `ANCHOR_PATCH_PLAN.md`, the history of each patch is `docs/PLAN_CHANGELOG.md`, and one line per patch is in `CHANGELOG.md`. The old build log is kept whole in `docs/BUILD_STATUS_HISTORY.md`.*

## What it is

A private safety plan, contacts and journal app for iPhone and iPad, in SwiftUI with SwiftData. Five tabs: Now, Plan, Journal, Bridge, Thread. Recovery (counters and streaks) is its own area, and sleep, tasks, routines, lists and a focus timer sit under Plan. A WidgetKit extension shows contacts, a counter and the focus timer on the lock screen. Anchor sends no data anywhere: everything is stored on the phone, and exports are files you choose to share.

## Branch and build

- Work is on `v2-recovery`. Patches are written as `.sh` files and pasted into Terminal; the Progress table in `ANCHOR_PATCH_PLAN.md` says which are pushed and which are written and waiting.
- The code has never been compiled by the tool that writes the patches, which has no Xcode. It does run `bash scripts/check-all.sh`, which reads every Swift file with a parser and runs the content checks; that finds syntax slips, not compile errors. Every patch is marked "build not yet confirmed" until you have built it. A first build after several patches may need small fixes.
- Open `iOS/Anchor/Anchor.xcodeproj` in Xcode 26 or later. Two targets: the app and `AnchorWidget` (the widget extension). App group `group.page.aspens.anchor`; a shared Keychain item for the widget key (Patch 35a2).

## Where things live

| What | Where |
| --- | --- |
| The app | `iOS/Anchor/Anchor/` (Views by tab, Models, Support) |
| Widgets | `iOS/Anchor/AnchorWidget/`; `Support/WidgetDataStore.swift` is the only bridge |
| Privacy and support pages, website | `website/` (Vite and React); the privacy page is `src/pages/Privacy.tsx` |
| Promo video | `remotion-project/` |
| Screenshots, checks, backup tools | `scripts/` |
| Release steps and App Store text | `docs/RELEASE_GUIDE.md`, `docs/APP_STORE_COPY.md` |
| Feature notes | `docs/` (`SLEEP.md`, `SHOWCASE.md`, `ENCRYPTION.md`, `EXPORT.md`, `OPTIONAL_FEATURES.md`, `BACKUP.md`, `RECOVERY_V2.md`, `REVIEW.md`, `SCREENSHOTS.md`) |
| Decisions in plain words | `docs/DECISIONS_EXPLAINED.md` |

## Fixed rules

- No scores, streak pressure, or readings of how you have been. Check-ins show your own values and nothing summed up.
- Reminders and notifications use generic lock-screen wording. Escalation is a local reminder to you, never an automatic message to anyone.
- Reminders are optional and off by default.
- AI is optional, off by default, never front and centre, never a chatbot, and turned off completely by one switch. The app never suggests a cloud model. Nothing is sent without the person seeing it first, and the original is always kept. See `docs/OPTIONAL_FEATURES.md`.
- Every question for the user is tracked in section 0.4 of the plan.
- The NSW mental health law screen is compiled only with the `PERSONAL_BUILD` flag and is not in the public build.

## Words used in the app

Tabs: Now, Plan, Journal, Bridge, Thread. The area for counters is Recovery. Message log is what you sent to people; Things I haven't said is the unsent drafts. In the data viewer each kind is named as its screen is (Contacts, Message log, To future me, Things I haven't said, Decision presets, Lists). The copy edit of every screen against this list was done in Patch 46b2.

## Not done

See the ⬜ rows in the Progress table of `ANCHOR_PATCH_PLAN.md`: the locking work (35d; 35b1, 35b2 and 35b3 are pushed), the last two relationship reminders (30p), the website pages and video (47 to 53), the optional extras (Phase I: the AI switch and tools, dictation with voice notes, iCloud sync), and the web demo and Android work at the end.
