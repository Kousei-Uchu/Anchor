# Anchor — Patch Plan (v2-recovery)

*Living document. Last updated: 9 Nov 2026, after your second round of answers (D17, D18, D21, D22, D29, D30; Patch 30o). Pushed through DOC7 (`d84ab85`); written and waiting for you to push: 30o and none is confirmed building; the ones not started are marked ⬜. Questions are in 0.4. Still waiting on you: the words for the About screen's creator section and the licence files (both D23). Open but not blocking anything: D29a, the Apple Health sleep cleanup, which you cannot review yet. New and assumed as read: D32. Held on purpose: medication notes (B5), recorded in Appendix D and no longer a decision or a to-do. Everything else in D16 to D31 is answered and either built or queued in the Progress table. D3 is parked until the end, just before the Android work. D15 is answered: option B, every model locked in one go, with a safety copy and an easy way back built first. Things I offered but did not build are in Appendix D. The history of updates is in `docs/PLAN_CHANGELOG.md`. Plain explanations of the decisions you asked about are in `docs/DECISIONS_EXPLAINED.md`.*

> ## READ THIS FIRST: THIS FILE IS THE PROMPT
>
> **This file is the single source of truth for the Anchor patch work, and it contains the standing instructions for Claude.** When you start or resume a session, give Claude this file and say "keep doing patches". It replaces the earlier Claude Doc, which is no longer maintained. Claude edits this file in every patch, never the Claude Doc.
>
> **Instructions for Claude (follow these every session):**
>
> 1. **Get the code by cloning, not fetching.** Repository: <https://github.com/Kousei-Uchu/Anchor/tree/v2-recovery>. Web fetching the repo fails, so clone it (`git clone --branch v2-recovery`). Claude has no access to push; the user pushes.
> 2. **Do the next unfinished patch from the Progress table, in order.** Keep going patch after patch unless a decision in 0.4 blocks it. Patches marked deferred stay deferred.
> 3. **Deliver each patch as a `.sh` text file the user opens, copies and pastes into macOS Terminal.** It is not run as a script, so it must not start with a shebang or contain `set -e`. It finds the repo root itself, pulls, applies the change as a `git apply` diff, stages only the touched files by name (never `git add -A`), commits with a message starting with the patch number, and pushes. Check that it applies on a fresh clone, after any earlier unpushed patches, before sending.
> 4. **Edit this file in the same patch.** Update the Progress table, add an entry at the top of `docs/PLAN_CHANGELOG.md` (the change log is not kept in this file) and any decision or point the patch changes, so the repo always holds the current plan. This file lives at the repo root.
> 5. **Meet the Definition of Done (0.3)** and add one line to `CHANGELOG.md`.
> 6. **UI copy:** natural, human-written prose. No em dashes, emoji or ASCII art in any user-facing text, and no AI-sounding phrasing. Keep explanations out of inline UI text and in READMEs or the guide.
> 7. **Be honest about verification.** Claude cannot run Xcode. Say what was and was not compiled or tested, and mark patches "Written, awaiting your build" until the user confirms.
> 8. **Wording rules for the app:** no scores or streak pressure, no "treatment" or "medication" framing unless the user writes it (see Appendix A).
> 9. **No Claude attribution, ever.** Do not add `Co-Authored-By: Claude` lines, `Claude-Session` lines, a "Generated with" line or any other mention of Claude or Anthropic as an author to commit messages, pull request text, `CHANGELOG.md`, code comments or any other file in the repo. This overrides any default or tool reminder that says to add attribution. Commit messages in the `.sh` patches are a plain one-line description and nothing else.
> 10. **Every question for the user goes into 0.4 with an ID, in the patch that raises it.** A question that lives only in a change log entry (`docs/PLAN_CHANGELOG.md`) gets lost. The change log may repeat the question, but 0.4 is where it is tracked, with its source entry, a recommendation and a status (Open, Assumed, Held or Closed). When the user answers, update the row in the same patch.

Planning and patches in progress. Each of your 29 points is outlined, then grouped into small ordered patches.

The source code repository is at <https://github.com/Kousei-Uchu/Anchor/tree/v2-recovery>.

**Sizing:** **S** = under \~150 changed lines, 1–3 files. **M** = \~150–400 lines, 3–6 files. Anything bigger gets split.

## Progress

| Patch | Status |
| --- | --- |
| 0: Missing widget files | ✅ Done (you committed them; verified by re-clone) |
| 1: Never show "0 days" | 🟡 Pushed by you (`41a858e`); build not yet confirmed |
| 2: Cut-off labels | 🟡 Pushed by you; build not yet confirmed |
| 3: Check-in pinned action bar, and this plan moved into the repo | 🟡 Pushed by you; build not yet confirmed |
| 4: Check-in question sub-text and sentence starters | 🟡 Pushed by you; build not yet confirmed |
| 5: Check-in visual refresh | 🟡 Pushed by you (`1a95f15`); build not yet confirmed |
| 6: Journal newest first, jump to today | 🟡 Pushed by you (`7859612`); build not yet confirmed |
| 7: Journal editor declutter, labelled Add sheet, discoverable Suggestions | 🟡 Pushed by you (`08b0dcc`); build not yet confirmed |
| 8: Journal month calendar | 🟡 Pushed by you (`19b9105`); build not yet confirmed |
| 9: Journal year overview | 🟡 Pushed by you (`041c874`); build not yet confirmed |
| 10: Tap-to-edit building blocks | 🟡 Pushed by you; build not yet confirmed |
| 11: Edit pattern on the Thread screens | 🟡 Pushed by you (`320930d`); build not yet confirmed |
| 12a: Edit pattern on the Plan screens, part 1: Safety plan and Trigger windows | 🟡 Pushed by you; build not yet confirmed |
| 12b: Plan screens, part 2: Contacts and Grounding tools, with Reorder | 🟡 Pushed by you; build not yet confirmed |
| 12c: Plan screens, part 3: Decision presets | 🟡 Pushed by you; build not yet confirmed |
| 12d: Plan screens, part 4: Appointments | 🟡 Pushed by you; build not yet confirmed |
| 13a: Edit pattern on Now and Recovery: Affirmations, De-escalation scripts, Who I'm doing this for, Before tracking | 🟡 Pushed by you; build not yet confirmed |
| 13b: Edit pattern on Bridge and the Journal entry preview; old Edit components removed | 🟡 Pushed by you (`e1ec93d`); build not yet confirmed |
| 14a: Message log, part 1: quick write to a person, per-person history, Send again and Copy, a Write button on the widget | 🟡 Pushed by you; build not yet confirmed |
| 14b: Message log, part 2: voice notes (record, play, attach when sending through Messages) | 🟡 Pushed by you (`823305a`); build not yet confirmed |
| 15: Tasks: `TaskItem`, carry-over from Next hour only, basic list, Plan widget, export and import, demo data | 🟡 Pushed by you (`20cf745`); build not yet confirmed |
| 16: Task due dates, fuzzy values, grouping by time | 🟡 Pushed by you (`8904af2`); build not yet confirmed |
| 17: Subtasks with collapse and derived progress | 🟡 Pushed by you (`9859ffa`); build not yet confirmed |
| 18: Task dependencies: greyed blocked tasks, "Waiting on…", auto-unlock | 🟡 Pushed by you (`33bad98`); build not yet confirmed |
| 19: Task status, energy tag, tiny first step, snooze to tomorrow | 🟡 Pushed by you (`fd8dda5`); build not yet confirmed |
| 20: Widget editing on the tab: drag to rearrange, hide and add back, half or full width | 🟡 Pushed by you (`2122d0d`); build not yet confirmed |
| 21: Focus timer (Pomodoro): settings, alert when a phase ends, session count per task | 🟡 Pushed by you (`5572bb7`); build not yet confirmed |
| 22: Plan my day: pick tasks and steps, time estimates, order, time available, walk through them | 🟡 Pushed by you (`d34d102`); build not yet confirmed |
| 21b: Focus timer on the lock screen and Dynamic Island (Live Activity) | 🟡 Pushed by you (`271d9a1`); build not yet confirmed |
| 23: Quick list: one-off checklists with an Archive | 🟡 Pushed by you (`ff9d994`); build not yet confirmed |
| 24: Routines beside Decision presets, with Run it | 🟡 Pushed by you (`78236c6`); build not yet confirmed |
| 24b: Routine schedule and reminder (off by default) | 🟡 Pushed by you (`934918c`); build not yet confirmed |
| 25: Item lists with quantity rules, Reset ticks and Make a copy | 🟡 Pushed by you (`9500f0f`); build not yet confirmed |
| SL1: Sleep journal basics (point 29) | 🟡 Pushed by you (`d462ac0`); build not yet confirmed |
| SL2a: Sleep on Now (point 29): the Last night card and its Settings switch | 🟡 Pushed by you (`343870e`); build not yet confirmed |
| SL2b: Sleep in the Journal (point 29): a row per night, a month mark, the note to journal | 🟡 Pushed by you (`0ad61fc`); build not yet confirmed |
| SL2c: Sleep in the check-in (point 29): the optional How did you sleep? question | 🟡 Pushed by you (`128c155`); build not yet confirmed |
| SL2d: Sleep morning reminder (point 29) | 🟡 Pushed by you (`c3bf8b7`); build not yet confirmed |
| SL3: Apple Health, read (point 29): Connect on the Sleep screen, one summary per night, Remove imported sleep | 🟡 Pushed by you (`4c3d637`); build not yet confirmed (needs the HealthKit capability, see change log entry 60) |
| SL4: Apple Health, write (point 29): its own switch, typed nights saved as Anchor's own samples, Remove what Anchor saved | 🟡 Pushed by you (`9c954b2`); build not yet confirmed |
| SL5: Sleep journal, Bridge and export (point 29): the Sleep since your last session card on session prep, and a time-asleep chart in the web page | 🟡 Pushed by you (`07cd4f4`); build not yet confirmed |
| 32: About screen (point 22): About Anchor in Settings with version and build, support email, links, a note on what Anchor is, licences and What's new; the copy shared with the website | 🟡 Pushed by you (`70426d9`); build not yet confirmed |
| 33: Encrypted backup (point 20): Make an encrypted backup in Your data (.anchorbackup, password, photos and voice notes included), opened by the same Import | 🟡 Pushed by you (`edd644d`); build not yet confirmed |
| 34: Encryption keys (point 20): a data key in the Keychain, a recovery key shown once, a recovery file kept with your data, check and replace the recovery key; test builds only, nothing is locked yet | 🟡 Pushed by you (`0e5664b`); build not yet confirmed |
| 35a: Widget summaries sealed (point 20): the contact and plan summary and the Recovery counters the widgets read are stored locked with their own key, kept out of backups; Clear everything removes them | 🟡 Pushed by you (`668e5bb`); build not yet confirmed |
| 35a2: Widgets' key moves to a Keychain item shared by the app and the widgets (D22d): the key file goes, the Keychain item replaces it, summaries already sealed are read once and sealed again, nothing is lost | ⬜ Not started; answered. Needs the Keychain Sharing capability on both targets, a step only you can do in Xcode (the patch lists it) |
| 35b1: Safety copy and way back (point 20, D15): an exact copy of the store, the voice notes and the Journal photos, made when Anchor starts and before anything is opened, checked, kept until you delete it; Go back to it, and Undo go back | ⬜ Not started; comes after the answered small items (see Order of work) |
| 35b2: Locked fields on every model (point 20, D15 option B): a new stored field beside each text field, read and written through the old name, nothing locked yet | ⬜ Not started; after 35b1 |
| 35b3: Lock my data (point 20, D15 option B): one flow that checks the recovery key and an off-phone backup, takes the safety copy, locks every model, checks every item, and goes back by itself if anything is off | ⬜ Not started; after 35b2 |
| 39: Showcase mode 1 (point 17): the demo store swapped in while it is on, the real store not opened on that launch, the app lock not asked for, off with the phone's Face ID or passcode; test builds only | 🟡 Pushed by you (`1b52ffd`); build not yet confirmed |
| 40a: Showcase mode 2a (point 17): the sweep. Widgets emptied and reminders removed while it is on and put back when it is off, share and export controls left out, Your data hides Export, Import and Clear all data, the app switcher shows a plain screen, and it stops instead of falling back to the real store; test builds only | 🟡 Pushed by you (`d51686c`); build not yet confirmed |
| 40b: Showcase mode 2b (point 17): a passcode of its own, the exit flow, the switch for everyone in Settings with its own screen and a ? help sheet, and the privacy page | 🟡 Pushed by you (`43773e3`); build not yet confirmed |
| 31: Data viewer (point 21): Look at what's stored, lock each time, every kind, read-only detail, blur switch | 🟡 Pushed by you (`4c334cb`); build not yet confirmed |
| 36: Export for someone (point 19, items 1 and 2): who it is for, a note, picker by kind, range and item, live count and preview, PDF named for the recipient | 🟡 Pushed by you (`0864157`); build not yet confirmed |
| 37: Export for someone, the web page (point 19, items 3 and 4 without Word): one self-contained file with search, a timeline, check-in charts, print and CSV, no network, optional password | 🟡 Pushed by you (`e844675`); build not yet confirmed |
| 38a: Export for someone, Word (point 19, item 4): a Download Word file button in the web page, made in the page with no library | 🟡 Pushed by you (`532f9ce`); build not yet confirmed |
| ~~38b: Website viewer (point 19, item 5, optional)~~ | Dropped, your answer to D27: the web page export covers everything it was for |
| 26: Feedback loops 1: loop builder | 🟡 Pushed by you (`df435e5`); build not yet confirmed |
| 27: Feedback loops 2: map mode | 🟡 Pushed by you (`d75b74d`); build not yet confirmed |
| 28: Feedback loops 3: templates, share as picture or PDF | 🟡 Pushed by you (`9babae1`); build not yet confirmed |
| 30a: Reusable custom sections; Safety plan sections with a copy-across migration | 🟡 Pushed by you (`5ebdccf`); build not yet confirmed |
| 30b: Boundaries list (T6) on the shared sections editor | 🟡 Pushed by you (`94714ee`); build not yet confirmed |
| 30c: Message starters (T2): your own short lines for starting a message | 🟡 Pushed by you (`ddf6fe7`); build not yet confirmed |
| 30d: Letters you open when you choose (T5, part 1) on To future me | 🟡 Pushed by you (`e328b9c`); build not yet confirmed |
| 30e: Questions to ask, with the answer written after the session (B3) on Things to raise | 🟡 Pushed by you (`450e1e2`); build not yet confirmed |
| 30f: Personal goals (the reframed B7): goals in your words with dated notes, a Bridge widget | 🟡 Pushed by you (`00a2e22`); build not yet confirmed |
| 30g: Add a journal entry to Things to raise in one tap (B2, journal part) | 🟡 Pushed by you (`3cd71a2`); build not yet confirmed |
| 30g1: Fix a crash loading photo suggestions (photo request called back twice) | 🟡 Pushed by you (`46664ec`); build not yet confirmed |
| 30h: Session prep, Journal since your last session (B1, journal and check-in part) | 🟡 Pushed by you (`90ebd52`); build not yet confirmed |
| 30i: Journal page rebuilt as blocks like Apple's Journal, cards for events, songs and suggestions, bookmarks | 🟡 Pushed by you (`455b765`); build not yet confirmed |
| 30j: Providers (B8, part 1): several providers, each with sessions, notes and an export name; appointments added to the JSON export | 🟡 Pushed by you (`de14649`); build not yet confirmed |
| 30k: Things to raise per provider (B8, part 2): an item is for anyone or for one provider, a filter on the list, the export follows it | 🟡 Pushed by you (`887134d`); build not yet confirmed |
| 30l: Person pages (T1): a page for each contact with sections of your own, their recent messages and the calendar days shared with them | 🟡 Pushed by you (`355d546`); build not yet confirmed |
| 30m: Session prep, the rest of B1: a Waiting to be raised card from Things to raise (for that provider and for anyone) and a To bring checklist for each session | 🟡 Pushed by you (`765d75e`); build not yet confirmed |
| 41: Guide (point 16, part 1): one guide registry, the tour rebuilt on it with pages that scroll, and a ? button on the pushed feature screens that opens that screen's entry or its tab's | 🟡 Pushed by you (`e14e177`); build not yet confirmed |
| 41a: Fix a build error in the app lock (a check for Face ID or a passcode was asked from outside the main actor) | 🟡 Pushed by you (`0e2d92b`); build not yet confirmed |
| 42: Guide content, Plan (point 16, part 2): the explanation for each of the 14 screens opened from Plan (Contacts, Safety plan, Trigger windows, Appointments, Grounding tools, Tasks, Quick list, Decision presets, Routines, Lists, De-escalation scripts, Affirmations, Sleep, Your data) | 🟡 Pushed by you (`ca6c25c`); build not yet confirmed |
| 43a: Guide content, Bridge, Thread and Recovery (point 16, part 3): the explanation for each of 15 screens (Things to raise, Session prep, Post-session notes, Personal goals, Feedback-loop diagrams; Message log, Message starters, People, Support calendar, To future me, Things I haven't said, Boundaries; Recovery, a counter, Who I'm doing this for) | 🟡 Pushed by you (`24a312c`); build not yet confirmed |
| 43b: Guide content, Journal and Settings (point 16, part 4): entries for writing a page, Journaling Suggestions, Settings, About Anchor, Customise widgets and (test builds only) Encryption, a ? on each, and Settings added to the end of the tour | 🟡 Pushed by you (`8b6b5cc`); build not yet confirmed |
| 44a: Audit 1, part 1 (Now, Plan, Recovery): appointment day count by calendar day, Previous and Next month labels, VoiceOver labels on the Recovery calendar days, neutral words in place of "sober" | 🟡 Pushed by you (`3fb8d68`); build not yet confirmed |
| 44b: Audit 1, part 2: the longest run and the personal best bar in Recovery are hidden until you switch on Show my longest run in Settings (your answer: opt in) | 🟡 Pushed by you (`0afba6e`); build not yet confirmed |
| 45b: Audit 2, part 2: Journaling Suggestions asks for calendar, photos and music only when each button is tapped; the unanswered check-in reminder names nobody on the lock screen and arrives on the right day when it falls after midnight | 🟡 Pushed by you (`9ed1542`); build not yet confirmed |
| 45c: Audit 2, part 3: the Journal timeline no longer scores a check-in from its sliders (one plain label and colour for every check-in); the Bridge help no longer mentions the personal-build-only law reference | 🟡 Pushed by you (`3d73737`); build not yet confirmed |
| 46a: Docs and coherence, part 1: the privacy page covers Recovery, the counter widget, every optional reminder and the focus timer Live Activity; `RECOVERY_V2.md`, `RELEASE_GUIDE.md` and `APP_STORE_COPY.md` brought up to date | 🟡 Pushed by you (`3a41967`); build not yet confirmed (the website builds, checked in a scratch copy) |
| R1: Review walkthrough (test builds only): `scripts/review-on-device.sh` puts the app on your connected iPhone (or a simulator) on made-up content, with a numbered bar that goes through every change, a screen to open for each, and a notes box you can copy out | 🟡 Pushed by you (`d0fa55a`, with the script fix R1a, `380e7ae`); build not yet confirmed |
| R2: Review fixes: the review run removes today's demo sleep night and shows the Last night card at any hour, so SL2a and SL2c can be seen (they were hidden by design, not broken) | 🟡 Pushed by you (`28cedbb`); build not yet confirmed |
| RV1: Tasks, quicker to fill and lighter to read: a card is a title and one quiet line, steps start folded, the editor keeps the common things up front (More options holds the rest), and a button by Add takes a pasted list | 🟡 Pushed by you (`4e25ede`, with RV2); build not yet confirmed |
| RV2: Steps inside steps to any depth; each step opens its own details and steps; deleting takes everything under it | 🟡 Pushed by you (`4e25ede`, with RV1); build not yet confirmed |
| RV3: Appointments, sessions: one calmer place to see, schedule, change and add sessions | 🟡 Pushed by you (`3b01ded`); build not yet confirmed |
| RV4: Goals: an optional SMART frame, a switch inside a goal, off by default, every part optional, no dates | 🟡 Pushed by you (`7b7b4eb`); build not yet confirmed |
| RV5: Check-ins in the Journal: show each day's own values without opening it, never inferred or summed up (revisits 45c) | 🟡 Pushed by you (`3fddb73`); build not yet confirmed |
| RV6: Privacy page: links to the other policies it mentions, and a section on Reject Convenience's Privacy Policy Visualiser | 🟡 Pushed by you (`bb2f83e`); build not yet confirmed (the website builds and prerenders `/privacy`) |
| RV7: Showcase mode: an audit that every feature has plenty of made-up content, and a script that keeps it so | 🟡 Pushed by you (`9e84ddd`); build not yet confirmed |
| RV8: The ? guides: far less crowded, ideas kept apart, plainer wording, the four main tabs first | 🟡 Pushed by you (`38c10ae`); build not yet confirmed |
| RV9: Apple Health sleep section: tidy the toggles | 🟡 Pushed by you (`2e929c1`); build not yet confirmed |
| RV10: Check-in mascot no longer follows the sliders (one switch, `mascotFollowsSliders`, brings it back) | 🟡 Pushed by you (`4c66161`); build not yet confirmed |
| 45a: Audit 2, part 1: session reminders, optional and off by default, with generic lock-screen wording; the unused reminder code that named the provider is removed | 🟡 Pushed by you (`237e998`); build not yet confirmed |
| 30n: Relationship reminders (T3, approved in Appendix C1): the first three types, regular hello, their dates and follow-up, off by default, generic lock-screen wording, one a day at most | ⬜ Not started; approved, not blocked |
| 30p onward | The last two T3 types come after 30n; T2 is 30c, B3 is 30e, Personal goals is 30f and T7 was done in 14b (30o is the letters row above) |
| 30q: Session actions offered as tasks (B4, D30): in Post-session notes, a line you mark as a thing to do gets an Add as task button; nothing is added until you tap, and the task has no date unless you give it one | ⬜ Not started; answered |
| 30r: One-page summary (B6, D30): a one-page layout inside Session prep and Export for someone, made only of your own words and plain facts in your order, with no scores, labels or readings | ⬜ Not started; answered, my reading is D32 |
| 45d: Escalation and trigger-window reminders (change log 83): cancelling one escalation leaves the following weeks alone (D16), and the trigger-window lock-screen wording is plain (D17) | 🟡 Pushed by you (`0f0f311`); build not yet confirmed |
| 45e: Appointment reminders, the things left out of 45a (D26): tap opens Session prep, a choice of evening time | 🟡 Pushed by you (`94d5e01`); build not yet confirmed |
| 30o: Letters you open (T5), situational ones: never locked, contents hidden in the list until you open one (D25). In Look at what's stored a letter is listed by its Open when words, a search does not read it, and it no longer shows as locked | 🟡 Written (change log 106), not yet pushed; build not yet confirmed |
| SL6: Sleep in the CSV (its own columns) and in the PDF (a time-asleep chart), for Export for someone and for Your data (D29) | ⬜ Not started; answered |
| SH2: Showcase mode, your changes (D21): a 4 to 6 digit number pad passcode, made-up content in the widgets, share and export working on made-up content | ⬜ Not started; answered |
| AB2: What's new by version (D23, 3): one collapsible section per version, the latest open | ⬜ Not started; answered. The creator section and the licence wait on your words and files |
| RV5a: Export check-in labels taken from the right sliders (change log 90) | 🟡 Pushed by you (`43b6a47`); build not yet confirmed |
| 46b: `STATUS.md` in place of `BUILD_STATUS.md`, one terminology list, an in-app copy edit (point 23) | ⬜ Not started; answered (D20: yes, as long as no information is lost, so every part of the old file is carried somewhere before it goes) |
| 35d: Voice notes and Journal photos locked too (D31) | ⬜ Not started; after 35b3 has been checked on your phone |

**Order of work from 9 Nov 2026.** The small answered items first, because each is one clear change you asked for: SL6, SH2, AB2, 46b (RV5a is pushed and 30o is written). Then 35a2, the widgets' key in a shared Keychain item, before any locking, because the locking work uses the keys. Then the locking work, which is the part that can lose data and needs your phone to check: 35b1, 35b2, 35b3, then 35d. Then 30n (relationship reminders), 30q (session actions as tasks) and 30r (the one-page summary). The website, demo and video patches stay last, with 55 at the very end.

## Change log of this plan

The history of this plan, one entry per update, is in [`docs/PLAN_CHANGELOG.md`](docs/PLAN_CHANGELOG.md). It was moved out of this file so the tables below are quick to reach. "Change log 83" anywhere in this file means entry 83 there. Add new entries at the top of that file.

The longer explanations of the open decisions (D3 and D15 so far) are in [`docs/DECISIONS_EXPLAINED.md`](docs/DECISIONS_EXPLAINED.md).

---

## 0. Read this first

### 0.1 The missing files (RESOLVED)

The branch did not build because `iOS/Anchor/Anchor/Views/Widgets/` was untracked. It is now committed and contains:

- **`TabWidgets.swift`** — `WidgetID` (the 19 widgets across Plan, Bridge and Thread), `TabLayoutStyle`, `Anchor.Widget`, `Anchor.WidgetCaption`, `Anchor.WidgetBig`, and every individual widget (`MessageLogWidget`, `SupportCalendarWidget`, `FutureNotesWidget`, `UnsentDraftsWidget` and the Plan/Bridge ones).
- **`WidgetCustomisation.swift`** — `Anchor.MoreTile`, `Anchor.WidgetStack`, `CustomiseWidgetsView` and its list.

`project.pbxproj` already references these files (7 mentions), so a clean clone should now build. **Still to confirm on your side:** a clean build in Xcode from a fresh clone. I can't run Xcode here.

**What this changes in the plan:**

- Points 11 and 14 can now be fixed precisely (see below). Point 10's "undefined widget" worry is gone.
- Patch 0 is complete. Patch 2 (labels) and Patch 20 (drag-and-drop) now have exact target code.
- The widget layer is bigger than I assumed (about 1,000 lines, 19 widgets, half-width/full-width packing in `WidgetStack`), so Patch 20 stays size M but needs care.

### 0.2 Already in the repo that helps

- **`DemoMode`** in `AnchorApp.swift`: an in-memory seeded store (launch arg `-AnchorDemo`). Point 17 builds on it.
- **`HelpTopic` / `HelpToolbarButton`**: per-screen "?" help. Point 16 extends it.
- **`TemporalDisplay`**: already calendar-aware. Point 6 is about the *other* places that print "N days".
- **File protection** `completeUntilFirstUserAuthentication`. Point 20 goes beyond it.
- **`DataControlView`**: JSON/CSV/PDF export and import with DTOs per model. Every new model needs a DTO here.
- **`WidgetID` registry**: one enum drives widget titles, sizes and ordering. New widgets (Tasks, Routines, Lists) should be added here, not built separately.

### 0.3 Definition of Done (every feature patch)

1. Works on a small iPhone (SE-size) and at large Dynamic Type: nothing truncated, nothing hidden below a button.
2. New/changed model is in `AnchorSchema.models`, has an export DTO, and shows in the data viewer.
3. Has a `HelpTopic` entry.
4. Added to the demo seed data.
5. One line in `CHANGELOG.md`; anything touching the privacy story also updates `Privacy.tsx`.
6. This document's Progress table is updated and a change log entry is added at the top of `docs/PLAN_CHANGELOG.md`.

### 0.4 Decisions needed

| # | Decision | Affects | My recommendation | Status |
| --- | --- | --- | --- | --- |
| D1 | Where is the missing widget-layout file? | Patch 0 | — | ✅ Closed |
| D2 | Keep the Reminders (EventKit) import from the old "Next Hour" list? | Patch 15 | Keep as an optional import on the task list | ✅ Assumed, 7 Nov 2026: Patch 15 follows the recommendation (import only). Say if you want it changed. |
| D3 | Demo strategy (point 25): how the web demo is made. | Patches 49–50, 55 | Parked to the end. When the time comes, build the demo from the app itself with a script (details in `docs/DECISIONS_EXPLAINED.md`). | ✅ Answered 9 Nov 2026: park it until the end, just before the Android work and the other awkward extras. The wish stays: one script brings the demo across, data held like a session store that clears on refresh, Apple-only features as small pretend placeholders, close enough to look the same at a glance, not a working port. How it is done is left to me. |
| D4 | Android: real goal or "nice to know"? | Point 28, D3, encryption (Patches 33–35) | Finish iOS first, decide *before* Patch 49 | ✅ Closed 7 Nov 2026: planned, but far in the future. Treat it as if it does not exist for now; nothing in the Swift patches waits on it. |
| D5 | Encryption approach (point 20) | Patches 33–35 | Field-level encryption, Keychain key, encrypted exports | ✅ Closed 7 Nov 2026: option b (field-level encryption, Keychain key, encrypted exports). The earlier idea of revisiting this for React Native is dropped, since D4 is parked. Voice note files (Patch 14b) are not covered by field-level encryption of text fields; Patches 34 and 35 must decide how to protect them. |
| D6 | Feedback loops: loops only, or loops plus free systems maps? | Patches 26–28 | Both, loops by default | ✅ Closed 7 Nov 2026: both, loops by default. |
| D7 | Point 27: unlisted page named `/demo-preview`, hidden from nav/sitemap, `noindex`? (`/demo` already exists) | Patch 51 | Yes | ✅ Closed 7 Nov 2026: yes to unlisted and `noindex`, but the page advertises the TestFlight beta sign-ups, so it is named and framed around that, not around a demo. Working route name: `/beta` (change it if you prefer another). |
| D8 | Message log: what was its "main function" for you — voice notes, quick sending, or per-person history? | Patch 14 | — | ✅ Closed 7 Nov 2026: all three. Checked `main` first (see the change log, entry 25): it explains the quick sending, and voice notes never existed, so 14a and 14b build all three. |
| D10 | Where does sleep live? | SL1, SL2 | A Sleep screen reached from a Plan widget (added hidden, so nobody sees it unless they add it), plus quiet rows in the Journal timeline. Not a sixth tab. | ✅ Closed 7 Nov 2026: recommendation accepted. |
| D11 | Apple Health: copy a nightly summary into Anchor's own store, or read Health live each time? | SL3, 31, 34 to 38, 39 | Copy one summary per night, with a clear "Remove imported sleep" control. Export, showcase mode, the data viewer and encryption all need the data to be in the store; live reads cannot offer that. | ✅ Closed 7 Nov 2026: recommendation accepted. |
| D12 | Write manual nights back into Apple Health (the tester's "contribute to that data")? | SL4 | Yes, as its own switch, off by default, separate from reading. | ✅ Closed 7 Nov 2026: yes, as recommended, but not held back: it is in the main release with reading (see D13). |
| D13 | When does sleep ship? | SL1 to SL5 | All of it in one lot. | ✅ Closed 7 Nov 2026: SL1 to SL4, Apple Health included, are in the main release together; Health is not an extra. The Health checklist (capability, usage strings, privacy page, App Store answers, review notes) is part of that release. SL5 follows Patches 31 and 36 to 38. |
| D14 | What does the app show about sleep? | SL1 to SL5 | Times, time asleep, an optional feel (Restful, Okay, Rough, your word for it) and a note. No sleep score, no goal hours, no "sleep debt", no stages in the first version, and no correlation views. | ✅ Closed 7 Nov 2026: recommendation accepted. |
| D9 | How long to keep investing in Swift UI polish before migrating to React Native? Polish-only patches (5, 7, 8–9) would be rewritten. | Phases B–D | Do bug fixes and behaviour first (1–4, 6, 10–14). Pause polish-only patches once a migration date exists. | ✅ Closed 7 Nov 2026: keep polishing in Swift for now. Revisit when a migration date exists. |
| D15 | How should locked text be held in the SwiftData store (point 20, Patch 35b)? Plain explanation and the options in `docs/DECISIONS_EXPLAINED.md`. | 35b1 to 35b3 | B | ✅ Answered 9 Nov 2026: option B, every model locked in one go. Condition from you: before locking or migrating anything, back up all the data and make going back easy, so nothing can be lost. Built as three patches, safety copy first (35b1), so the way back exists before any lock does. What it can and cannot promise is in `docs/DECISIONS_EXPLAINED.md`. |
| D16 | When one trigger-window escalation is cancelled (you tap I'm okay, or open the app from the check-in), should the weeks after it keep their reminders? | 45d | Do not cancel them. | ✅ Answered 9 Nov 2026: do not cancel them. Built in 45d as separate dated reminders for the next few weeks with a list of skipped ones, because iOS cannot skip one occurrence of a repeating reminder. The cost: they use some of the 64 waiting reminders iOS allows the whole app, and they stop being topped up if the app is not opened for those weeks. (change log 83) |
| D17 | Lock-screen wording of a trigger-window reminder. Today anyone who glances at your locked phone sees your window's label as the title and a line from your safety plan as the text. Change to a plain Anchor title and a line that names nothing, as every other reminder does? | 45d | Yes. | ✅ Answered 9 Nov 2026: yes, hide it when the phone is locked. Read as: the lock screen shows a plain Anchor title and a line that names nothing, the same as every other reminder; the window's label and your safety plan line show once the app is open. Built in 45d. (83) |
| D18 | Export for someone names check-in values from the wrong sliders (Moving is called Energy and the real Physical energy slider is left out), and the older CSV and PDF under Your data have the same mix-up and write one value twice. Fix it? | RV5a | Yes. | ✅ Closed 9 Nov 2026: fix it, and it is fixed. RV5a is pushed (`43b6a47`): four values named from the right sliders, Moving added, five lines in the web page chart. (90, 101) |
| D19 | Hold Recovery back until v1 is approved? Patch 46a removed that line from `docs/RECOVERY_V2.md`, because the privacy page now covers Recovery and the branch has moved well past it. | docs, release | No hold. | ✅ Closed 9 Nov 2026: no hold. (85) |
| D20 | Replace `BUILD_STATUS.md` (673 lines, partly out of date by its own note) with a short `STATUS.md`? | 46b | Yes. | ✅ Answered 9 Nov 2026: yes, as long as no actual information is lost. 46b goes through `BUILD_STATUS.md` section by section, carries each fact into `STATUS.md` or the doc that already holds it, and lists in the patch where every part went, before the old file is deleted. (85) |
| D21 | Showcase mode choices I built without an answer. (a) The Showcase mode row stays in Settings while it is on. (b) The showcase passcode is any text of four characters or more. (c) Widgets are empty while it is on. (d) Share and export are left out, so the export screens cannot be shown. (e) A plain screen covers the app switcher. (f) The phone's own Face ID or passcode always gets you out, and the mode survives closing the app. | 39, 40a, 40b, RV7, SH2 | As built. | Answered 9 Nov 2026, and (e) answered in the second round. **(a) fine as is. (b) change: a 4 to 6 digit number pad. (c) change: made-up content in the widgets. (d) change: share and export work on the made-up content, because showcase mode is meant to show every feature. (e) explained, and you said fine: the plain screen over the app switcher stays as built, closed. (f) fine.** (b), (c) and (d) are patch SH2. (71 to 73) |
| D22 | Encryption choices I built without an answer. (a) The data key can be used by background launches and never leaves the phone or travels in a backup. (b) The recovery key is 28 characters, shown once. (c) It is not offered as a printable page or a file to save in Files. (d) The widgets' key is a key file kept out of backups, not a Keychain item. | 34, 35a, 35b | As built. | Answered 9 Nov 2026: (a), (b) and (c) fine. **(d) change: you chose the shared Keychain item over the key file.** That is patch 35a2: the key moves into a Keychain item both the app and the widgets can read; it needs the Keychain Sharing capability on both in Xcode, which only you can switch on, and the patch tells you where. Until it is built the key file stands. (69, 70) |
| D23 | About screen. (1) The About the creator section. (2) A `LICENSE` file for the repository. (3) What's new: feature names, or versions. | 32, AB2 | Creator: your words. Licence: your decision. What's new: by version. | Answered 9 Nov 2026. **(1) your words, which I am waiting for. (2) a custom licence, with files you will attach in this chat or later, so nothing is written yet. (3) by version: a collapsible section for each version listing what it added, removed and changed, the latest open and the rest closed, patch AB2.** The three principles, the Licences line and the eight What's new entries are my wording and still need your read. (67) |
| D24 | Recovery wording left alone on purpose: the Streaks history page, the My streak page title and the milestone marks. | Recovery | Leave them. | ✅ Closed 9 Nov 2026: good enough as is. (82) |
| D25 | T5, letters you open: should a letter be locked until after an appointment? | 30o | Do not lock a letter that depends on a situation. | ✅ Answered 9 Nov 2026: a situational letter is never locked or blocked. Its contents are hidden in the list by default and open with a tap, so a mistaken app can never keep it from you when you need it. Built in 30o. (46, 74, 106) |
| D26 | Appointment reminders. Three things I left out of 45a: (a) name the provider inside the app (the lock screen stays generic); (b) a choice of evening time, today fixed at 6 pm; (c) a tap on the reminder opens Session prep, today it opens Anchor. | 45e | Yes to all three. | Answered 9 Nov 2026. **Read as yes to (a), (b) and (c).** (a) is met by (c), since Session prep shows the provider's name. Written as patch 45e (change log 104). Tell me if I read your note wrongly. (81, 104) |
| D27 | Website viewer for Export for someone (38b): build it at all? | 38b | Do not build it. | ✅ Answered 9 Nov 2026: the web page export replaced it, and it already covers search, timeline, charts, print, CSV, Word and a password. 38b is removed from the plan. (65) |
| D28 | Privacy page, a read before release: the Recovery, reminder, focus timer and Reading this policy sections. | release | Read it once, then open the five links. | ✅ Answered 9 Nov 2026: read, works alright. One thing left that I cannot do from here: open the Apple, Spotify, Discord and Privacy Visualiser links once on the built page. (85, 91) |
| D29 | Small rules I chose. Apple Health nights under three hours apart count as one sleep and naps are left out (60). The asleep sample written to Health ends when you got up (61). The Word file is A4, or US Letter for US, CA, MX and PH browsers (65). The CSV has no sleep columns and the PDF has no sleep chart (66). The check-in sheet shows each slider's position as a percentage (90). "The four main tabs first" and "tidy the toggles" read as described in 93 and 94. SL4 was not held back after reading (39). Reordering a loop's steps moves each step's outgoing link with it (40). The wording of the loop templates (42). | various, SL6 | As built. | Answered 9 Nov 2026: all fine as described, including the two you asked about. **The CSV and PDF sleep gap is read as: build them (patch SL6). The tour and toggle notes (93, 94) stand as built.** **D29a, open and not blocking: the Apple Health sleep cleanup.** You cannot review it yet, so it stays unresolved and nothing waits on it. I read "cleanup" as the removal side of Health sleep and the rules around it: Remove imported sleep, Remove what Anchor saved, samples removed when a night is deleted or its times cleared, nights under three hours apart counting as one with naps left out (60), and the written asleep sample ending when you got up (61). Tell me if you meant something narrower. Listed in the release checklist in `docs/SLEEP.md` so it is tried on a real device before release. |
| D30 | B4 (session actions into Tasks) and B6 (one-page summary of how I've been). B5 (medication notes) is no longer a decision: held, see Appendix D. | Appendix A | Keep them held. | ✅ Answered 9 Nov 2026. **B4: build the safe version, no date unless you add one (patch 30q). B6: build it as a re-formatting of Session prep and Export for someone (patch 30r), read as in D32. B5: held, taken out of the decisions and the to-do list, and noted in Appendix D.** (87, 102) |
| D31 | Voice notes and Journal photos are files, not stored text, so locking the text does not lock them. Lock them too, in a later patch (35d)? | 35d | Yes, later. | ✅ Answered 9 Nov 2026: yes. Patch 35d, after 35b3 has been checked on your phone. (99) |

| D32 | How I read your D30 answers, so you can correct me. **B4:** the offer sits on each line you mark as a thing to do in Post-session notes, as a button; tapping it makes a task with the line as its title and no date, and the line stays in the notes. Nothing is ever added by itself. **B6:** a layout choice, not a new screen: Session prep and Export for someone each get a one-page layout that puts what they already hold on a single page, in your order, in your own words and plain facts only (what you logged, counts that are plain tallies, your notes). No sentence about how you have been, no scores, labels or readings of the sliders. | 30q, 30r | As read. | Assumed 9 Nov 2026: built as read; say if you meant something else. (102) |
| D33 | Look at what's stored shows the words of a note that is still sealed until a date, in its list row and in a search, although To future me never shows them. In 30o a letter's words were hidden there because you asked for that; the dated notes were left alone because you did not. Hide a sealed note's words in the viewer too, until its date? | 30o | Yes, so the viewer keeps the same promise as the screen: the row says it is sealed until the date, and the words show once the date has passed. | Open, not blocking. (106) |

**How to read the Status column.** *Answered* or *Closed* means you have said what you want; where the row names a patch, that patch is queued or built. *Assumed* would mean already built the recommended way, with a reply needed only to change it (none are left). *Held* is parked on purpose. The source entry is the change log number (in `docs/PLAN_CHANGELOG.md`), where the full reasoning is. D3 and D15 have longer plain explanations in `docs/DECISIONS_EXPLAINED.md`.

**Update, 7 Nov 2026:** D3 and D4 answered in a comment. Android is wanted eventually, via a move from Swift to React Native, with demo and Android builds updating automatically. Both are parked as "eventually planned": Patches 49–50 and 54 are deferred. D5 should be revisited once the migration is decided (see point 28).

---

## 1. Your points, outlined (1 to 29)

### Check-in (1, 2, 3)

**1. Finish button hides the optional-questions button.** *Cause:* `CheckInSliderView.sliderStage` is a `Form` with a mascot, five sliders and a footer. On small screens **Finish** lands exactly at the bottom edge and "A few optional questions" sits below it, so nothing suggests more follows. *Fix:* pin both actions in a bottom bar (`safeAreaInset(edge: .bottom)`), optional questions above or beside Finish. Shrink the mascot on compact screens. Nothing important then sits below the fold.

**2. Check-in screens feel like stock iOS.** *Proposal:* replace the `Form` with soft themed cards. Each slider gets an icon and gentle end-labels ("running on empty" ↔ "fully charged"). The mascot's expression reacts as sliders move (existing `MascotFace` and `MascotMood`). The questions stage gets the mascot on top, with a different mood per question, and a calm "done" moment (mascot nod, one `MascotEngine` line). Still no scoring.

**3. Each question needs a sub-explanation and sentence starters.** *Proposal:* the five prompts become a struct (`prompt`, `detail`, `starters`). Under "What's your biggest emotion right now?": "Naming a feeling, even roughly, can make it a little less heavy." A "Need a start?" chip row offers 3–4 starters ("Right now I feel…", "I keep thinking about…") inserted at the cursor. The same data can feed the Journal editor and the guide.

### Journal (4, 5)

**4. Journal writing screen is cluttered; Apple Journaling Suggestions are hard to find.** *Cause:* the editor mixes a "Give me something to write about" card, a markdown toolbar with three icons (photo, drawing, and `calendar.badge.plus`, which is the one that opens Suggestions), a preview toggle and Done. Suggestions hide behind an unlabelled icon. *Proposal:* one calm writing surface. Top bar: Cancel / date / Done. Bottom: one "+" opening a labelled sheet with big rows ("Journaling Suggestions", "Photo", "Drawing", "Prompt for me", "Formatting"). Preview moves into a "…" menu. Suggestions get a name, a one-line explainer and a first-run hint.

**5. Timeline order and layout.** *Confirmed in code:* `groupedByDay` sorts days ascending and items within a day ascending, so it is oldest-first throughout. *Small fix:* days newest-first, entries newest-first, plus "Jump to today". *Layout brainstorm:*

- **A. Zoomable timeline (your idea):** Day list → Month calendar → Year overview. Month view shows dots per day (entry count, check-in present, no scoring); tap a day to drill in. Year view is a 12-month heatmap grid.
- **B. Calendar-first:** month grid on top, selected day's items below.
- **C. Today + browse:** today front and centre with a quick write box; a calendar button opens zoomed-out views.
- **D. Lenses:** entries only, check-ins only, by origin (check-in, craving, appointment…). *Recommendation:* A, with D's lenses later. Three small patches (list fix, month view, year view).

### Recovery (6)

**6. Never show "0 days".** *Cause:* `RecoveryText.days(_:)` returns `"0 days"`; `wholeDays` is a stopwatch count (23 hours is 0 days); the counter widget prints the number with a "days" label; the Now card and share text reuse the helper. *Fix:* one central `RecoveryText.elapsed(from:to:)` choosing the largest non-zero unit (years → months → days → hours → minutes → "just started"), with celebratory wording ("3 hours in"). Use it wherever the *current run* is shown; totals can keep days. The widget target needs a copy, so put it in `Support/` and compile it into both targets, as `WidgetDataStore.swift` already is. Widgets must refresh hourly early on, then daily. Call sites: `RecoveryModels.swift:119`, `RecoverySummaryTab:44, 488, 496`, `RecoveryHomeView:105`, `RecoverySupport:163, 165, 242`, `AnchorWidget.swift:~400–421`.

### Planning / tasks (7, 8, 9)

**7. Replace "Next Hour Only" with a real planner.** (`NextHourItem` and `NextHourChecklistView` are a self-purging single-hour list.)

*Task model (`TaskItem`, SwiftData):*

- title, notes
- priority (None / Low / Medium / High) plus an optional "tiny" tag for 2-minute things
- time estimate (minutes, quick chips 5 / 15 / 30 / 60)
- due: exact date, **or** fuzzy (`ASAP`, `Today`, `This week`, `This month`, `Someday`) stored as enum plus optional date
- category (user-defined, colour-coded)
- status: Not started / In progress / Done / Parked, with progress derived from subtasks
- subtasks (checkable, collapse/expand)
- dependencies (`blockedBy`): blocked tasks stay visible but greyed and collapsed under "Waiting on…" with the blocker's name; they unlock gently when the blocker completes
- extras to consider: energy level required (ties to check-in sliders), a "first tiny step" field, recurring tasks, "snooze to tomorrow", and a guilt-free overdue treatment (no red, consistent with the app's no-shame rules)

*Views:* list grouped by Today / This week / Later / Waiting / Done (switchable to category or priority), task detail, and a quick-add bar (title only).

*Pomodoro:* launched from a task or subtask. Settings: focus length, short break, long break, intervals before a long break, auto-start next phase, sound/haptic, breaks can be turned off. Needs a local notification so it ends when backgrounded, ideally a Live Activity for the lock screen. Session log per task (count and minutes), no scoring.

*"Plan my day":* pick tasks and subtasks from the unblocked pool, drag to order, see total estimate against time available, then "Start" walks through them offering a pomodoro each.

*Placement:* the Tasks area becomes a new entry in the `WidgetID` registry (see 0.2), so it appears as a widget on Plan and can be reordered like the others.

*Migration:* `NextHourItem` rows convert to `TaskItem` (Today, no priority) on first launch; the old model is removed in a later release. Keep or drop the EventKit import (D2).

**8. Routines and item lists.**

- **Routines:** keep Decision Presets, and add Routines as a sibling section in one "Presets" screen sharing editor components. A routine is a named, ordered list of steps with optional estimates and a "Run it" mode that walks through steps one at a time (the Grounding Tools pattern), plus an optional schedule/reminder ("School mornings, 7:30").
- **Item lists (packing-style):** a single-page checklist with categories and tick-off. Lines can be fixed ("1 passport") or computed from variables such as days: `1 per day`, `1 per day + 1 extra per 3 days`. Variables (days, nights, people) update quantities when changed. Reusable templates with "Reset ticks".

**9. One-time lists.** A "Quick list" button on the Tasks page: type or paste one item per line, shown as a single focused checklist, promotable into real tasks or discarded when done. A `TaskList` flagged `isOneOff` that auto-archives on completion but stays findable in an Archive section. *(Built in Patch 23 as a separate `QuickList` model; see change log entry 34 for why.)*

### Thread / Bridge fixes (10, 11, 13, 14, 15)

**10. Message Log has lost its main function.** *(Updated after the widget files landed.)* *Findings:* `ThreadMessagesView` is a read-only list. The composer (behind a sheet) can save privately, or save and send via Messages or Discord. The log has no actions on an entry: no resend, no "message this person again", no per-contact view. `ThreadMessage.audioFileName` still exists, but nothing records or plays audio, so voice notes (if that was it) are gone. `MessageLogWidget` exists and now shows only the latest message with the caption "Tied to a real contact, and can actually send." — which promises a function the widget itself does not offer, and a new message can only be started after opening the screen. *Proposal:* group by contact, tap a message to resend or copy, optional voice-note recording and playback, quick "write to X" at the top, and a "write" action directly on the widget. Review "Things I haven't said" (`UnsentDraftsView`) in the same patch. Needs your answer to D8.

**11. Text labels cut off.** *(Updated: exact causes found.)* In `TabWidgets.swift`:

- `Anchor.WidgetCaption` defaults to `lines = 2` with no scaling, so any description longer than two lines is clipped ("things to raise" description).
- The widget header title uses `lineLimit(2)` with `fixedSize`, inside a row sharing space with a 26-pt icon circle. Long titles ("Things I haven't said", "Who I'm doing this for") do not fit in a half-width card.
- `WidgetBig` uses `lineLimit(2)` with `minimumScaleFactor(0.8)`, too little shrink to rescue long text.
- "Appointments" is a half-width widget (`isHalf` in `WidgetID`), so the title column is narrow and the word splits across lines. In `ContentView.swift`, the older icon-style `TileButtonLabel` has a fixed `frame(height: 32)` that clips three-line wraps. *Fix:* let titles wrap to three lines or scale to \~0.6, remove fixed heights, disable hyphenation, consider making a half-width widget go full-width when its title is long (the `isHalf` flag is the single switch), and test every widget at the largest Dynamic Type.

**13. Too many taps; redundant edit buttons.** *Findings:* 18 screens use `Anchor.EditToolbarButton`, which opens an `Anchor.EditorSheet` (18 files), and 11 screens also contain `EditButton()`. "Things I haven't said" is therefore Thread → Unsent → draft → Edit → sheet → tap row → editor, and inside that sheet sits a second Edit button next to swipe-to-delete. That is the "my last tap did nothing" feeling. *Fix (one pattern, applied screen by screen):* tap a row to edit it directly. Swipe deletes (plus at most one other contextual action). A "+" adds. A labelled "Reorder" button appears only where order matters. No intermediate Edit sheet and no second Edit button.

**14. Widget reordering should be visual.** *(Updated: exact current implementation found.)* *Findings:* reordering lives in `CustomiseWidgetsView` (`WidgetCustomisation.swift`), reached from Settings. It is a plain `List` with a `Toggle` per widget and `.onMove`, with a segmented picker for the tab (Plan / Bridge / Thread). So you leave the screen you are arranging to arrange it, and the list gives no sense of the real layout, including half-width widgets that pair up in `WidgetStack`. *Proposal:* edit mode directly on the tab. Long-press (or a "Customise" button) makes cards wiggle. Drag to rearrange using SwiftUI `draggable`/`dropDestination`, with haptics. A "−" badge hides a widget, and a tray of hidden widgets lets you add them back. A size toggle changes a widget between half and full width (today fixed per widget by `isHalf`). Order and visibility keep their current storage, so no migration is needed. `WidgetStack`'s row-packing logic is reused and needs a look because dragging a half-width card changes how neighbours pair.

**15. Feedback-loop diagrams need a rethink.** *Findings:* the editor is a free canvas: drag nodes, tap two to connect, tap to rename. Data is `DiagramGraph` (nodes with x/y, edges with label) stored as JSON. There is no undo, no zoom or pan, no clear edge direction, no way to delete an edge, and no distinction between a *loop* and an arbitrary graph, so it suits neither well. *Proposal (D6):*

1. **Loop mode (default):** a guided builder that lays nodes on a ring ("What happens first? What does that lead to?…"). The last item links back to the first, so a real loop needs no manual connecting. Each arrow has polarity (**more → more** or **more → less**) and an optional label. The app labels the loop **reinforcing** or **balancing** by counting negative links, in plain language ("this one tends to keep itself going").
2. **Map mode:** the free canvas, rebuilt properly: pan/zoom, multi-select, undo/redo, drag between handles to connect, edge labels, node colours, auto-layout. For metaphors like "my defences work like Cloudflare".
3. **Templates** to start from (a short, user-reviewed set).
4. **Output:** a clean image or PDF for a clinician, plus a link into Bridge's export (point 19). This rebuilds `FeedbackLoopDiagramView` (367 lines). The stored `graphJSON` stays, with a version field and a `kind` (loop/map) added. *(Loop mode built in Patch 26, map mode in Patch 27; templates and export follow in Patch 28.)*

### Help, privacy, data (16, 17, 20, 21)

**16. A fuller guide.** Today: a short onboarding tour (`OnboardingTourView`, 85 lines) and per-screen `HelpTopic`s. *Proposal:* one content registry (`GuideEntry`: id, screen, title, what it is, how to use it, tips) powering (a) a full "Take the tour" walkthrough in Settings, ordered by tab, (b) the existing "?" button opening the entry for the current screen, and (c) website feature pages and docs generated from the same data so they cannot drift. Content is written tab by tab in small patches.

**17. Showcase mode (hide real data behind a passcode, show demo data).**

- Settings → "Showcase mode". Setup asks for a **separate showcase passcode** (salted hash in Keychain) and offers device Face ID/passcode as the way back.
- Turning on: swap to `DemoMode.makeContainer()` (in-memory, seeded), **disable the normal app lock**, and clear anything that leaks real data outside the store: the widget snapshot in the App Group (`WidgetDataStore`: contact names and numbers), pending notifications and their wording, the app-switcher snapshot, and the share/export actions (disabled).
- The real store file is **not opened at all** while on.
- Turning off: showcase passcode (or device authentication), then restore the real container and widget data.
- The demo fixture must cover *every* feature, so it becomes one seed definition (JSON) shared by showcase mode, UI tests and the website demo. Part of the Definition of Done.
- *Decided as built (D21):* device authentication always works if the showcase passcode is forgotten, and the mode survives closing the app.
- *Changed by your answers, 9 Nov 2026 (D21):* the showcase passcode becomes a 4 to 6 digit number pad; the widgets show made-up content instead of being empty; share and export work on the made-up content, so the export screens can be shown, since showcase mode is meant to show every feature. This is patch SH2.

**20. Encryption "as secure as possible".** *Now:* iOS file protection `completeUntilFirstUserAuthentication` (readable any time after first unlock since boot). Exports are plaintext. The widget snapshot (names and numbers) sits in unprotected App Group defaults.

- **a. Do nothing more.** Baseline only.
- **b. Field-level encryption** of sensitive text and blobs (journal text, notes, contacts, safety plan) with AES-GCM (CryptoKit), key in the Keychain (`WhenUnlockedThisDeviceOnly`, optionally biometric-bound). Plaintext never touches the SQLite file. Encrypted fields can't be used in `#Predicate`, but search is already in-memory. The key's accessibility class matters for background launches such as notification actions.
- **c. Whole-database (SQLCipher).** Strongest, but incompatible with SwiftData; it means replacing persistence. Only sensible if a rewrite (point 28) happens anyway.
- **Recommendation:** b, hardened widget snapshot, and encrypted exports.
- *Risks:* key loss means data loss, so a **recovery key** (shown once) is needed; migrating existing plaintext rows must be crash-safe and reversible; backups.
- *Exports:* versioned `.anchorbackup`, AES-256-GCM, password-derived key (PBKDF2 via CommonCrypto at high iterations, or scrypt/Argon2 if you accept a dependency). Import auto-detects old plaintext JSON. For *shared* exports (point 19) the password is chosen at export time and the HTML viewer decrypts in-browser with WebCrypto.

**21. Data viewer shows every entry.** Replace count rows with: section per type → searchable list → read-only detail with every field in plain language. **Never display** app-lock settings, key material, or raw binary (shown as "image, 240 KB"). The viewer re-prompts the app lock each time it opens and can blur values until tapped. Built on a small `DataBrowsable` protocol each model adopts, so new models (Tasks, Routines…) appear automatically.

### Bridge, About, docs (18, 19, 22, 23)

**18. Flesh out Bridge and Thread.** Ideas to confirm are in Appendix A. Nothing is built until you pick a subset.

**19. Bridge: detailed export for clinicians or loved ones.**

1. **Fine-grained picker:** choose what to include by category, date range, or individual item, with a live preview and summary ("12 journal entries, 3 check-ins…").
2. **Recipient label** ("For Dr. Patel", "For Sam") written into the file name and document header, plus an optional cover note.
3. **Format: one self-contained HTML file** with the data (encrypted if a password is set) and an offline viewer: sections, search, timeline, check-in charts, print stylesheet. It reads fine as a plain document *and* is interactive. It runs only in the browser, so **nothing is sent to any server** and the privacy policy stays true.
4. **Inside that HTML:** buttons for **PDF** (print stylesheet), **CSV** (generated in-page) and **Word .docx** (in-page, with a small inlined library that adds file size).
5. **Website viewer page (dropped, 9 Nov 2026, D27: the web page export covers it):** loads a chosen export entirely client-side (no network calls, no storage, no caching, strict CSP with `connect-src 'none'`), using the same viewer code. Worth it only if you want a way to view without trusting an HTML attachment. *Verify before building:* WebCrypto when opening a local file on iOS (Files/Safari), mail clients that block HTML attachments (offer a ZIP and PDF fallback), and docx library size.

**22. About screen** (Settings): version/build, support email (pre-filled with version and device info, nothing personal), website, privacy policy, GitHub repo, "About the creator", "About Anchor" (purpose, philosophy: no streaks, no scores, local-first, nothing shared unless you share it), licences, "What's new". Copy lives in one content file the website reuses.

**23. Docs and coherence.** To reconcile: `README.md`, `BUILD_STATUS.md` (673 lines, flagged stale by its own header), `docs/RECOVERY_V2.md` (still says "ship this after v1… keep it on its own branch"), `APP_STORE_COPY.md`, `RELEASE_GUIDE.md`, `SCREENSHOTS.md`, `Privacy.tsx`, website copy and in-app text. *Proposal:* replace `BUILD_STATUS.md` with a short `STATUS.md` plus `CHANGELOG.md`; one terminology list (tabs Now / Plan / Journal / Bridge / Thread; "Recovery"; "Message log" vs "Things I haven't said"); a final copy-edit across every screen.

### Website, demo, video (24–27)

**24. Website content.** Feature sections per tab and major feature, design philosophy, who it is and isn't for, privacy details, FAQ, changelog link, screenshots. Pages: Features, Philosophy, Privacy (update), Support, About. Content comes from the same registry as the in-app guide (point 16).

**25. Demo "compiled from the app's source".** *Constraint:* SwiftUI cannot be compiled to HTML or WASM, so a literal automatic port is not possible with this codebase. Options:

| Option | What you get | Cost / downside |
| --- | --- | --- |
| **A. Faithful rebuild + parity checks.** Keep the React demo (`DemoApp.tsx`, 415 lines), feed it from the shared seed and guide data, and add a CI step comparing screenshots of the real app (XCUITest already exists) and the web demo. | Low effort. | Still a re-implementation; UI changes need a manual port. |
| **B. Cloud-streamed real app (e.g. Appetize).** | Always exactly the real app. | Paid, latency, not "HTML". Fake data only, but via a third party. |
| **C. Screenshot-flow demo built in CI.** XCUITest walks every screen and writes screenshots plus tap targets for an interactive click-through. | Automatically current, cheap. | Not truly interactive. |
| **D. Cross-platform rewrite** (React Native/Expo + react-native-web, or Flutter). | The only genuinely compiled, always-identical demo; also solves Android. | A full rewrite of \~14k lines plus native bits. Biggest option by far. |

*Recommendation:* **A + C** now, revisit D only if Android is a real goal (D4). Patches 49–50.

**Update, 7 Nov 2026:** deferred. If the React Native move happens, option D becomes the plan: the web demo is then a build of the real app, and the stopgap options (A, C) are not worth building. Patches 49–50 are parked.

**Update, 9 Nov 2026 (option E):** a fifth option was asked about: compile the real Swift for the browser with Tokamak, so the demo is rebuilt by running one script. Written up in `docs/DECISIONS_EXPLAINED.md`. Tokamak was archived on 28 Jan 2026 and the app is tied to SwiftData and other Apple-only frameworks, so this is a refactor of most of the app, not a script. Still parked under D3.

**Update, 9 Nov 2026 (your answer to D3):** parked until the end, just before the Android work. What the demo is for, in your words: show screens and features with demo data, look close enough to be the same at a glance, build itself from the app's demo data and how the app really looks, run by one script when you want it updated. It does not need to be a working port. Data would be held like a session store that clears on refresh, and the Apple-only parts (Health, Journaling Suggestions, Photos and the rest) would be small pretend placeholders. That is a lighter job than the one assessed earlier, and `docs/DECISIONS_EXPLAINED.md` says how it changes the options. Patch 55 holds it.

**26. Remotion video.** (1) Refresh the existing promo with new screenshots and features. The compositions are duplicated (`remotion-project/src/Promo.tsx` and `website/src/promo/Promo.tsx`, synced by `sync:promo`); make `remotion-project` the single source. (2) A longer "full tour" video, scripted from the guide registry so captions match the docs. Do this **after** features stabilise.

**27. Unlisted beta sign-up page.** (D7, answered) The page advertises the TestFlight beta sign-ups, so it is named and framed around that, working route `/beta`: not linked from header or footer, excluded from the sitemap, `noindex`, with the pitch, a clear way to sign up and a flag to switch the sign-up on and off. `/demo` already exists (the current React demo) and stays separate.

### Review and platform (12, 28)

**12. Review all features.** Done per area, not as one giant pass (Patches 44–45). *Known issues so far:*

- Appointment reminders are implemented in `NotificationScheduler` but never called from the Appointments screen (per `BUILD_STATUS.md`).
- Per-contact escalation timers are modelled but not wired.
- The widget snapshot stores contact names and numbers in plaintext App Group defaults.
- Journaling Suggestions are hard to find (point 4).
- `MessageLogWidget`'s caption promises sending the widget cannot do (point 10).
- *Resolved:* the missing widget files (Patch 0).

**28. Android difficulty.** *Overall: high.* About 14,000 lines of SwiftUI plus SwiftData, WidgetKit, EventKit, LocalAuthentication, MessageUI, PencilKit, Charts, `UserNotifications` and a mascot drawn in SwiftUI shapes. Only the design, data model and content carry over.

| Concern | Android / React Native reality |
| --- | --- |
| UI | Complete rewrite. |
| Data | SQLite (op-sqlite/WatermelonDB or Room). **SQLCipher is available**, so whole-DB encryption becomes easy. |
| Widgets | Native Android code (Glance/AppWidget) even in RN. No lock-screen widget equivalent. |
| Notifications with actions | Supported; different channels and Android 13+ permissions. |
| Face ID/passcode lock | `BiometricPrompt`; fine. |
| Messages / Discord | SMS and deep-link intents; fine. |
| Reminders (EventKit) | No equivalent. Drop or reduce. |
| Journaling Suggestions | iOS-only; feature would not exist. |
| PencilKit drawing | Custom canvas (Skia/`react-native-svg`). |
| Mascot and animation | Rebuild in Skia/`react-native-svg`. |
| Distribution | Play Console, Data Safety form, `allowBackup` decisions. |

*Effort:* roughly the original build again, maybe 35–50 patches of this size, plus double maintenance. RN only makes sense if the web demo also comes from the same code (option D); for Android alone, native Kotlin/Compose gives better widgets, notifications and lock integration. *Recommendation:* finish iOS, ship the demo with A+C, re-evaluate Android with real demand.

**Status: eventually planned (deferred), 7 Nov 2026.** Direction: move from Swift to React Native (Expo) so one codebase serves iOS, Android and web. Nothing starts yet, and the Swift patches above carry on meanwhile.

- **Your tooling question: yes, this is feasible.** With Expo and react-native-web, one repo builds the iOS app, the Android app and a web version. A pre-commit hook (husky or lefthook) can run typecheck, lint, tests and the web build, and block the commit if they fail. A full Android build takes minutes and iOS builds need macOS, so those fit CI better than a hook: GitHub Actions plus EAS Build on every push, which also publishes the web demo and uploads the Android build. A pre-push hook is the middle ground. Net result: commit and push, and the demo and Android build update by themselves.
- **Not everything is shared.** Home-screen and lock-screen widgets, Live Activities, notification actions, Face ID/biometric lock, Journaling Suggestions and the Reminders import need small native modules per platform. Android widgets can't be written in JavaScript.
- **Upside for encryption.** SQLCipher works in React Native, so whole-database encryption (point 20, option c) becomes realistic. Revisit D5 before Patches 34–35.
- **Cost.** All \~14k lines of Swift are rewritten in TypeScript. Only the design, content and data model carry over.
- **Keep-it-portable rule for the Swift patches meanwhile:** put anything that will carry over into plain data (guide registry, demo seed JSON, check-in prompts and starters, quantity rules, export format spec) and keep backup and export formats language-neutral. The HTML export viewer (Patch 37) is already platform-independent.

**29. Sleep journal (a tester's request, 7 Nov 2026).** The request, as sent: *"I think it is important to add a sleep journal/diary. Perhaps it could integrate with HealthKit and work with / contribute to that data, and allow making sleep data an exportable data point for therapist shares. Perhaps weave it in some other places too."* It is a good fit: sleep is one of the first things a clinician asks about, and the app already has the pieces (a journal timeline, check-ins, Bridge session prep, a planned export). Nothing exists for it today.

*Decided, 7 Nov 2026 (D10 to D14).* All recommendations accepted. One change: Apple Health is part of the main release, not a later extra. It is still a separate step for the person using the app (opt-in, with its own switches), and still separate patches (SL3 and SL4), but it ships with the sleep journal rather than after it.

*What it is.* A quiet nightly record, one entry per night: the night it belongs to (the day you woke up), when you went to bed, when you woke, time asleep (worked out from the two, or typed if you do not know the times), an optional feel in three words you can rename, and a note. It is optional end to end and invisible until someone adds it. A new `SleepEntry` model (all fields defaulted, so no store migration), with a `source` (typed by you, or imported from Apple Health) and, for imports, the Health sample's identifier so the same night is never added twice. Where a night has both a typed entry and a Health one, yours wins and nothing of yours is overwritten.

*Wording and what it will not do (D14).* The same rules as the rest of the app: no sleep score, no target hours, no streak of nights logged, no red for a short night, nothing that says you slept "badly". No sleep stages or charts of stages in the first version. No insights engine and no correlation with mood, urges or check-ins: the entries sit beside each other in the Journal and the export, and spotting a pattern is left to you and your clinician. It is a record, not a medical device, and it makes no health claims.

*Apple Health (D11, D12).* Reading is its own step, started by a Connect Apple Health button on the Sleep screen, so the system permission question appears only then and never at launch. Things to know before building, to be checked against Apple's current documentation because they cannot be tested here:

- **Capability and strings.** The app target needs the HealthKit capability (an entitlement edit, plus HealthKit enabled on the App ID in the developer portal, which is a step for you) and an Info.plist reading-purpose string. Writing back needs a second string. The widget target must not link HealthKit.
- **What is read.** Sleep analysis samples, turned into one summary per night (time in bed, time asleep). Roughly the last 30 days on first connect, then whatever is new when the Sleep screen opens or the app comes to the foreground. No background delivery in the first version.
- **Denied looks like empty.** HealthKit does not tell an app whether read access was refused, so the screen cannot say so. It says \"No sleep found in Apple Health yet\" and nothing more.
- **Availability.** Check `HKHealthStore.isHealthDataAvailable()` and hide the whole Health section where it is false.
- **Control.** A Disconnect switch stops further imports; Remove imported sleep deletes only the nights that came from Health, never typed ones.
- **Writing back (D12).** Off by default and separate from reading. When on, a typed night is saved to Health as a sleep sample marked as coming from Anchor, so it is never imported back. Deleting a night in Anchor removes the sample Anchor wrote and no one else's. Health is the source of truth for anything it already holds.
- **Showcase mode and the demo** never touch Health.
- **App Store and privacy.** The sleep data stays on the device, so the App Privacy answer very probably stays \"Data not collected\", but check that against Apple's wording before submitting. The privacy page (`Privacy.tsx`) must describe Health use plainly, and App Review expects the HealthKit integration to be real and described in the review notes. Health data may not be used for advertising or kept in iCloud, which Anchor does not do; check the current guideline text before release.

*Where it shows up (weaving it in).* Each of these is optional and follows C2 (off by default, a quiet line in context, a switch in Settings, Reminders, generic wording):

- **Journal.** A small sleep row at the top of the morning it belongs to, a small mark on the month view, and the note offered as a normal journal entry if you want it there. Opens the same sheet.
- **Check-in.** An optional question, \"How did you sleep?\", with sentence starters in the same style as the other prompts. It fills in last night's entry if there is none; it never asks twice.
- **Now.** A morning card, \"Last night\", only if the sleep journal is switched on, only before midday, and gone once last night is logged or you say not now. Nothing is logged about not now.
- **Reminder.** An optional morning reminder at a time you pick, with generic lock-screen wording that never says sleep.
- **Bridge, session prep.** A read-only \"Sleep since your last session\" card: how many nights are logged, the shortest and longest time asleep, and the usual bedtime window. \"Add to prep notes\" copies it in only when you tap it, the same as the Recovery card.
- **Bridge export (Patches 36 to 38).** Sleep is a category in the picker: a date range, one row per night, and a plain small chart of time asleep with no target line. It is on only if you choose it, and appears in the CSV and the encrypted backup. If you want sleep in a shared export before the new export engine exists, the interim is a Sleep section in the current PDF export (SL5a).
- **Plan.** A Sleep widget, half width, added hidden (D10), with the last few nights as plain dots.
- **Data viewer, guide, showcase mode.** The model adopts `DataBrowsable` (Patch 31), has a guide entry (Patches 41 to 43), and the demo seed has a week of nights.

*Knock-on effects on existing patches.* **31** (data viewer: a Sleep section). **34 and 35** (field-level encryption: sleep times and notes are sensitive and are included). **36 to 38** (export: the Sleep category, CSV columns, HTML viewer chart). **39** (showcase: demo nights, no Health reads). **41 to 43** (guide entries). **46** (docs: a short `docs/SLEEP.md` with the Health checklist, like `RECOVERY_V2.md`). **48** (website: privacy page and FAQ).

---

## 2. Ordered patches

Order: unblock → visible quick wins → one shared pattern later screens inherit → the big feature → trust/data → docs/web, with video last.

**How patches are delivered.** Each patch is a text file of macOS shell commands (`patch-01.sh`, `patch-02.sh`, and so on). You open the file, copy its whole contents and paste them into Terminal; you never run the file itself. Terminal can be open anywhere inside your clone, because the block finds the repo root itself. The same block applies the change, stages only the files that patch touches, listed by name (never `git add -A`, so a stray untracked folder can't be swept in or, as happened with `Views/Widgets/`, quietly left behind), commits with a message that starts with the patch number, and pushes. Patches build on each other, so paste them in order.

### Phase A — Unblock and quick wins

| Patch | Contents | Points | Size | Status |
| --- | --- | --- | --- | --- |
| **0** | Missing widget files committed | blocker | — | ✅ Done |
| **1** | Central elapsed-time formatter, never "0 days"; update call sites and counter widget | 6 | S | 🟡 |
| **2** | Cut-off labels: `WidgetCaption` lines, header title wrapping, `WidgetBig` scale, long-title widgets go full-width, `TileButtonLabel` fixed height; Dynamic Type pass | 11 | S | 🟡 |
| **3** | Check-in: pinned action bar so "optional questions" can't be missed; plan moved into the repo | 1 | S | 🟡 |

### Phase B — Check-in and Journal

| Patch | Contents | Points | Size | Status |
| --- | --- | --- | --- | --- |
| **4** | Check-in questions: sub-text and sentence starters | 3 | S | 🟡 |
| **5** | Check-in visual refresh: themed cards, reacting mascot, mascot on questions | 2 | M | 🟡 |
| **6** | Journal order fix (newest first, jump to today) | 5 | S | 🟡 |
| **7** | Journal editor declutter; labelled "+" sheet; discoverable Suggestions | 4 | M | 🟡 |
| **8** | Journal month-calendar zoom | 5 | M | 🟡 |
| **9** | Journal year overview (+ optional lenses) | 5 | M | 🟡 |

### Phase C — Interaction patterns

| Patch | Contents | Points | Size | Status |
| --- | --- | --- | --- | --- |
| **10** | New edit pattern implemented in shared `Anchor` components only | 13 | S | 🟡 |
| **11** | Apply to Thread screens | 13 | M | 🟡 |
| **12a** | Apply to Plan screens: Safety plan, Trigger windows | 13 | S | 🟡 |
| **12b** | Plan screens: Contacts, Grounding tools (List of cards, Reorder) | 13 | M | 🟡 |
| **12c** | Plan screens: Decision presets | 13 | M | 🟡 |
| **12d** | Plan screens: Appointments | 13 | M | 🟡 |
| **13a** | Apply to Now and Recovery (Affirmations, De-escalation scripts, motivations, Before tracking) | 13 | M | 🟡 |
| **13b** | Apply to Bridge and the Journal entry preview; then remove `EditToolbarButton` and `EditorSheet` | 13 | M | 🟡 |
| ~~13~~ | ~~Apply to Bridge, Now (including De-escalation scripts and Affirmations, reached from Plan) and Recovery screens; then remove `EditToolbarButton` and `EditorSheet`~~ (split into 13a and 13b) | 13 | | |
| **14a** | Message log part 1: quick write to a person, per-person history, Send again and Copy, widget caption and Write button | 10 | M | 🟡 |
| **14b** | Message log part 2: voice notes | 10 | M | 🟡 |

Widget drag-and-drop (Patch 20) is independent of the planner and can be pulled forward any time.

### Phase D — Planner (points 7, 8, 9)

First add an explicit SwiftData migration plan: a store that fails to open shows the red "couldn't open your saved data" banner.

| Patch | Contents | Points | Size | Status |
| --- | --- | --- | --- | --- |
| **15** | `TaskItem` model, migration from `NextHourItem`, basic list; new `WidgetID` entry; DTO, data-viewer row, seed data | 7 | M | 🟡 |
| **16** | Due dates incl. fuzzy values, time-bucket grouping | 7 | S | 🟡 |
| **17** | Subtasks with collapse/expand and derived progress | 7 | M | 🟡 |
| **18** | Dependencies: greyed blocked tasks, "Waiting on…", auto-unlock | 7 | M | 🟡 |
| **19** | Status, progress display, extras (energy tag, tiny first step, snooze) | 7 | S | 🟡 |
| **20** | Widget drag-and-drop editing on the tab (see point 14) | 14 | M | 🟡 |
| **21** | Pomodoro: settings, alert when a phase ends, session count per task | 7 | M+ | 🟡 |
| **21b** | Pomodoro Live Activity on the lock screen and Dynamic Island | 7 | S | 🟡 |
| **22** | "Plan my day" screen, with a time estimate on tasks | 7 | M | 🟡 |
| **23** | Quick list (one-time) shortcut | 9 | M+ | 🟡 |
| **24** | Routines alongside Decision Presets, "run it" mode | 8 | M | 🟡 |
| **24b** | Routine schedule and reminder: off by default, quiet line, Settings → Reminders, generic wording | 8 | S | 🟡 |
| **25** | Item lists with quantity rules and templates | 8 | M | 🟡 |

### Phase E — Bridge and Thread

| Patch | Contents | Points | Size | Status |
| --- | --- | --- | --- | --- |
| **26** | Feedback loops 1: loop builder (ring layout, polarity, reinforcing/balancing) | 15 | M | 🟡 |
| **27** | Feedback loops 2: map mode (pan/zoom, undo, connect handles) | 15 | M | 🟡 |
| **28** | Feedback loops 3: templates, share as picture or PDF | 15 | S | 🟡 |
| **29** | Bridge/Thread ideas review: you pick from Appendix A | 18 | S | ✅ Done, 7 Nov 2026 |
| **30a** | Reusable custom sections component; Safety plan sections with migration | 18, C3 | M+ | 🟡 |
| **30b** | Boundaries list (T6) | 18 | M | 🟡 |
| **30c** | Message starters (T2) | 18 | S | 🟡 |
| **30d** | Open when letters (T5, part 1) | 18 | S | 🟡 |
| **30e** | Questions to ask, with answers (B3) | 18 | S | 🟡 |
| **30f** | Personal goals (reframed B7) | 18 | M | 🟡 |
| **30g** | Journal entry to Things to raise (B2, part 1) | 18 | S | 🟡 |
| **30h** | Session prep: Journal since your last session (B1, part 1) | 18 | S | 🟡 |
| **30i** | Journal page rebuilt as blocks, cards, bookmarks (your request after 30h) | 4, 5 | M+ | 🟡 |
| **30j** | Providers (B8, part 1): several providers, each with sessions, notes, export name | 18 | M | 🟡 |
| **30k** | Things to raise per provider (B8, part 2) | 18 | S | 🟡 |
| **30l** | Person pages (T1), on the shared sections editor | 18, C3 | M+ | 🟡 |
| **30m** | Session prep, the rest of B1: Waiting to be raised and a To bring checklist per session | 18 | S | 🟡 |
| **30n** | Relationship reminders (T3, Appendix C1): regular hello, their dates and follow-up, off by default, generic lock-screen wording, one a day at most, listed in Settings, Reminders | 18, C1 | M | ⬜ approved, not blocked |
| **30o** | Letters you open (T5), situational ones never locked, contents hidden in the list (D25) | 18 | S | 🟡 |
| **30p+** | The last two T3 types (hard-time companion, after an appointment), one patch each | 18 | per idea | ⬜ |
| **30q** | Session actions offered as tasks, with no date unless you add one (B4, D30) | 18 | S | ⬜ |
| **30r** | One-page summary as a layout of Session prep and Export for someone (B6, D30, D32) | 18 | M | ⬜ |

**Update, 7 Nov 2026:** Patch 29 (the ideas review) is done. Patch 30+ is now: B1, B2, B3, B8, T1 (light), T2, T5, T6, T7 and a Personal goals feature in place of B7, grouped into small patches of one or two ideas each. B4 and B6 were held and are now answered (30q and 30r, 9 Nov 2026); B5 stays held and is recorded in Appendix D; T4 is covered by Patches 36–38.

### Phase E2 — Sleep journal (point 29)

Decided (D10 to D14 closed, 7 Nov 2026) and part of the main release, Apple Health included. SL1 to SL5 are all pushed.

| Patch | Contents | Points | Size | Status |
| --- | --- | --- | --- | --- |
| **SL1** | `SleepEntry` model; Log sleep sheet (bed, wake, time asleep, optional feel and note); Sleep screen (nights newest first, a month of dots, one plain line on the usual range, no score); Plan widget added hidden; DTO, export, import, Clear all data, data counts, demo, Help, CHANGELOG | 29 | M+ | 🟡 |
| **SL2a** | Now: the Last night card (only with its switch on, only before midday, gone once logged or Not now) and a Sleep section in Settings that appears once Sleep is in use | 29 | S | 🟡 |
| **SL2b** | Journal: a small sleep row on the morning it belongs to, a mark on the month view, the note offered as a journal entry | 29 | S | 🟡 |
| **SL2c** | Check-in: an optional "How did you sleep?" question with sentence starters, filling in last night only if there is none | 29 | S | 🟡 |
| **SL2d** | An optional morning reminder at a time you pick, in Settings, Reminders, with generic lock-screen wording that never says sleep | 29 | S | 🟡 |
| **SL3** | Apple Health, read: capability, entitlement and usage string, Connect, import a summary per night, dedupe, typed wins, Disconnect, Remove imported sleep, neutral empty state; privacy page and `docs/SLEEP.md` updated | 29 | M | 🟡 |
| **SL4** | Apple Health, write: its own switch, off by default; typed nights saved as Anchor's own samples, never re-imported, removed when the night is deleted | 29 | S | 🟡 |
| **SL5** | Bridge: Sleep since your last session on session prep; viewer chart of time asleep (the Sleep category in the picker came with 36, the data viewer row with 31) | 29 | S | 🟡 |
| **SL6** | Sleep in the CSV (its own columns) and in the PDF (a time-asleep chart) (D29) | 29 | S | ⬜ |

### Phase F — Data, privacy, security

| Patch | Contents | Points | Size | Status |
| --- | --- | --- | --- | --- |
| **31** | Data viewer: per-type lists, read-only detail, re-authentication | 21 | M | 🟡 |
| **32** | About screen | 22 | S | 🟡 |
| **AB2** | About: What's new by version, collapsible, latest open (D23). Creator section and licence wait on you | 22 | S | ⬜ |
| **33** | Encrypted export/import (`.anchorbackup`), plaintext import kept | 20 | M | 🟡 |
| **34** | At-rest field encryption: keys, recovery key | 20 | M | 🟡 |
| **35a** | Widget summaries sealed with their own key (the widget snapshot half of 35) | 20 | S | 🟡 |
| **35a2** | Widgets' key in a Keychain item shared with the app, replacing the key file (D22d) | 20 | S | ⬜ |
| **35b1** | Safety copy and way back: an exact copy before anything is opened, Go back, Undo go back (D15) | 20 | M | ⬜ |
| **35b2** | Locked fields on every model, nothing locked yet (D15 option B) | 20 | M+ | ⬜ |
| **35b3** | Lock my data: recovery key and off-phone backup checked, safety copy, lock every model in one go, check, automatic way back (D15 option B) | 20 | M+ | ⬜ |
| **36** | Bridge export: picker and recipient labels | 19 | M | 🟡 |
| **37** | Bridge export: self-contained HTML viewer, PDF/CSV, password encryption | 19 | M | 🟡 |
| **38a** | Bridge export: Word file made inside the web page | 19 | S | 🟡 |
| ~~**38b**~~ | ~~Bridge export: optional website viewer~~ Dropped (D27): the web page export covers it | 19 | | |
| **39** | Showcase mode 1: container swap, lock disabled, off with the phone's own authentication; the shared JSON seed deferred (see change log 71) | 17 | M | 🟡 |
| **40a** | Showcase mode 2a: the sweep (widgets, reminders, share and export, app switcher, fail closed) | 17 | M | 🟡 |
| **40b** | Showcase mode 2b: passcode of its own, exit flow, the switch for everyone with its own screen and Help | 17 | M | 🟡 |
| **SH2** | Showcase mode, your changes: 4 to 6 digit number pad passcode, made-up content in the widgets, share and export working on made-up content (D21) | 17 | M | ⬜ |
| **35d** | Voice notes and Journal photos locked too, after 35b3 is checked on your phone (D31) | 20 | M | ⬜ |

### Phase G — Guide, audit, docs

| Patch | Contents | Points | Size | Status |
| --- | --- | --- | --- | --- |
| **41** | Guide registry, full tour, "?" on the pushed screens (part 1 of point 16; entries come in 42 and 43) | 16 | M | 🟡 |
| **42** | Guide content: Now and Plan (incl. Tasks, Routines, Lists). Written for the 14 screens opened from Plan; Now has no screens of its own to explain, and the Recovery screens go in 43 | 16 | M | 🟡 |
| **43** | Guide content: Journal, Bridge, Thread, Settings, Recovery. Split: 43a is Bridge, Thread and Recovery, 43b is Journal and Settings; both pushed | 16 | M | 🟡 |
| **44** | Audit 1: Now, Plan, Recovery. 44a is a first sweep and 44b made the longest run opt-in (your answer); both pushed | 12 | M | 🟡 |
| **45** | Audit 2: Journal, Bridge, Thread, Settings, widgets, notifications (appointment reminders, escalation). 45a is the appointment reminders; 45b is the Journaling Suggestions permissions and the escalation wording and timing; 45c is the Journal check-in rows and the Bridge help; 45a to 45e are all pushed; the escalation and trigger-window reminder changes in change log 83 are 45d, and the appointment reminder extras are 45e | 12 | M | 🟡 |
| **46** | Docs and coherence. 46a is the privacy page and the Recovery, release and App Store docs (pushed); 46b is `STATUS.md` in place of `BUILD_STATUS.md` (D20 answered: yes, nothing lost), the terminology list and the in-app copy edit, and is not written | 23 | M | 🟡 / ⬜ |

### Phase R: Review fixes (from your review of the 66 stops, 9 Nov 2026)

| Patch | Contents | Points | Size | Status |
| --- | --- | --- | --- | --- |
| **R1, R1a** | Review walkthrough for test builds, `scripts/review-on-device.sh`, and the launch-argument fix | 12 | M | 🟡 |
| **R2** | The review run shows the Last night card and the sleep check-in question | 29 | S | 🟡 |
| **RV1, RV2** | Tasks: lighter cards, Add several at once; steps inside steps to any depth | 7 | M | 🟡 |
| **RV3** | Appointments, sessions: Coming up and the calendar, earlier sessions folded away | 13 | M | 🟡 |
| **RV4** | Goals: optional SMART frame, off by default | 18 | S | 🟡 |
| **RV5** | Check-ins in the Journal show each day's own values, never inferred | 5 | S | 🟡 |
| **RV5a** | Export check-in labels from the right sliders (D18 answered: fix it) | 19 | S | 🟡 pushed `43b6a47` |
| **RV6** | Privacy page: links to the other policies and the Privacy Visualiser section (read it first, D28) | 20 | S | 🟡 |
| **RV7** | Showcase mode and the demo have made-up content for every kind of content, and a script keeps it so | 17 | M | 🟡 |
| **RV8** | The ? guides: ideas one to a line, Show more, short tab overviews, the tour meets the tabs first | 16 | M | 🟡 |
| **RV9** | Apple Health card: two matching switches, one short line each | 29 | S | 🟡 |
| **RV10** | Check-in mascot keeps one calm face | 2 | S | 🟡 |

### Phase H — Website, demo, video

| Patch | Contents | Points | Size | Status |
| --- | --- | --- | --- | --- |
| **47** | Website: Features and Philosophy pages | 24 | M | ⬜ |
| **48** | Website: About, FAQ, Privacy update | 24 | S | ⬜ |
| **49** | Demo route A: shared seed and guide data feed the React demo (parked, replaced by 55) | 25 | M | ⬜ |
| **50** | Demo route C: CI screenshot flow and parity check (parked, 55 may use it) | 25 | M | ⬜ |
| **51** | Unlisted TestFlight beta sign-up page (`/beta`, noindex, not in nav or sitemap) | 27 | S | ⬜ |
| **52** | Update existing Remotion promo; single source | 26 | M | ⬜ |
| **53** | Long "full tour" video, split into per-tab scenes | 26 | L (split) | ⬜ |
| **54** | Android decision write-up, optional prototype spike | 28 | S | ⬜ |
| **55** | Web demo made by a script from the app and its demo data (D3). Done last, just before the Android work | 25 | L (split) | ⬜ parked to the end |

Patches 49, 50 and 54 are **deferred (eventually planned)** pending the React Native decision. Their rows above stay as the fallback plan.

---

## Appendix A — Bridge and Thread ideas (point 18). Pick what you like.

**Now:** Bridge covers appointment prep, things to raise, post-session notes, reframing, feedback loops, a PDF export, and a personal-build-only NSW reference. Thread covers message log, support calendar, notes to future you, and things I haven't said.

| ID | Bridge idea | Why |
| --- | --- | --- |
| B1 | Prep checklist per appointment with a "since last time" auto-summary (check-in trends without scores, starred journal highlights, urges logged) and "things to raise" prefilled from tagged items | Saves rewriting your week in the waiting room |
| B2 | Star or tag anything for Bridge from Journal, check-ins and urges in one tap | Collecting for an appointment is manual today |
| B3 | Questions to ask, with answers captured after the session | Closes the loop with post-session notes |
| B4 | Post-session summary becomes action items in Tasks, with dates | Connects sessions to follow-through |
| B5 | Medication and side-effect notes (user-written only, no reminders or dosing advice) | A common thing to bring |
| B6 | "Explain it simply" one-screen summary of how I've been | Many appointments are short |
| B7 | Treatment goals with qualitative progress notes, no scores | Fits the no-scoring principle |
| B8 | Multiple providers, each with their own notes and export labels | Needed once exports carry a recipient |

| ID | Thread idea | Why |
| --- | --- | --- |
| T1 | Person pages: message log, support-calendar entries, notes and "things I've told them" per contact | Makes the tab person-centric |
| T2 | Editable message starters and scripts ("I'm not up to talking, but I'm safe") | Low-effort outreach on bad days |
| T3 | Guilt-free relationship nudges ("it's been a while with Sam?"), off by default | Support network upkeep |
| T4 | Shared-safe summary for a loved one, using the Bridge export engine with another template | Same machinery, different audience |
| T5 | Notes to future you with triggers (date, after an appointment, after a hard day) and "open when…" letters | Strengthens an existing feature |
| T6 | Boundaries list (things I'd like people to know or not do), shareable on request | Concrete and short |
| T7 | Voice notes on messages (the model field already exists) | Restores a probably-lost function (point 10) |

Suggested first set: **B1, B2, B4, T1, T2, T7**. High value, and they reuse planned work.

**Your review, 7 Nov 2026.** Decisions from your comments:

- **Yes:** B1, B2, B3, B8, T2, T5, T6, T7.
- **Yes, but keep it simple:** T1. Person pages stay light: messages, calendar entries and notes only, with no analytics and no "relationship health" views.
- **Maybe, decide later:** B4 (session actions into Tasks) and B6 (one-screen summary; needs care in its wording and in what it leaves out). *Answered 9 Nov 2026 (D30): B4 yes with no date unless you add one (30q); B6 yes as a re-formatting of Session prep and Export for someone (30r).*
- **Reframed:** B7 becomes "Personal goals": your own goals and notes, nothing framed as treatment. B5 (medication notes) is on hold. It only returns if you settle on a safe shape for it. *Confirmed held on 9 Nov 2026 and taken out of the decisions and the to-do list; the note on it is in Appendix D.*
- **Clarified:** T3 is a reminder you set yourself per person (see its thread). T4 isn't a separate feature: it is the loved-one preset of the point 19 export, built in Patches 36–38.
- **Wording rule for the whole app:** avoid "treatment" and "medication" framing in Bridge, exports and copy, unless the user writes those words themselves.

---

## Appendix C — Reminders, notification defaults and editable sections (7 Nov 2026)

### C1. Relationship reminders (T3) — approved

A reminder you set yourself, per person, **off by default**. Lock-screen text is always generic; the named wording only shows inside the app.

| Type | In-app wording | Lock screen | When it sends |
| --- | --- | --- | --- |
| **Regular hello** | "Thinking of Sam? A quick hello could be nice." | "A quiet moment to reach out?" | The cadence and time you pick, e.g. Sundays at 5pm |
| **Their dates** | "Alex has an exam tomorrow. A good-luck text?" | "Something to remember tomorrow." | The morning of, or the day before (uses Support calendar entries) |
| **Follow-up** | "You reached out to Jordan on Tuesday. Want to say thanks, or see how they are?" | "A follow-up you set earlier." | The delay you set after creating it, e.g. two days |
| **Hard-time companion** | "Sunday evenings can be heavy. Sam is one option." | "A gentle nudge for this evening." | The start of a trigger window you defined |
| **After an appointment** | "How did it go? Want to tell someone about it?" | "Something for this evening." | Early evening on the appointment day, or the next morning |

**Rules:** at most one per day across everyone, no repeats or snooze chains (Quiet Room was removed from the app, so the old rule about holding reminders back while it is on no longer applies), no "you haven't…" wording, nothing counted or scored, "Not now" is free and logged nowhere. Nothing is inferred from behaviour and the app never suggests removing someone. Tapping opens a message pre-filled from your T2 starters. **Build order:** the first three types first. The last two depend on trigger windows and appointments being set up (and on appointment reminders being wired, point 12).

### C2. Opt-in everywhere, with gentle discoverability

**Principle:** no notification or reminder is on by default, anywhere in the app. *Already true today:* daily check-in, daily pledge, evening review and milestones all default off, and per-contact escalation is opt-in. The gap is discoverability, so people may not know they exist. A quiet, non-intrusive pattern for every optional reminder or setting:

- **In context:** one small secondary-text line at the bottom of the relevant screen ("Reminders for this are off. Turn on"). No cards, badges or red dots.
- **One home:** a single **Settings → Reminders** section listing every optional reminder with its on/off switch and time.
- **One-time hint:** after first using a relevant feature, a dismissible hint may appear once. Once dismissed, it never returns.
- **Permission timing:** the system notification permission prompt appears only when you first switch a reminder on, never at launch.
- **Guide:** the in-app guide (point 16) mentions each one.

*Applies to:* relationship reminders (C1), appointment reminders (once wired), escalation, task due dates, pomodoro alerts and Live Activity, routine schedules, recovery reminders, and any lock-screen or widget content that shows personal details. **Definition of Done addition:** any new notification is off by default, has the quiet in-context line, and appears in Settings → Reminders.

### C3. Editable sections: Safety plan, Boundaries list, Person pages

*Assumption (correct me if wrong):* the *text* in each section is already editable. "Editable" here means the **structure**: you can rename, reorder, add, hide and remove sections.

**Safety plan.** Today `SafetyPlan` has four fixed text fields (warning signs, coping strategies, reasons to keep going, making the environment safer). Proposal: replace them with `SafetyPlanSection` rows (title, body, icon/colour, order, hidden, optional role). The four current sections are created from existing text on first launch, so nothing is lost. One section can carry the role **"Reasons to keep going"**: notification quotes and templated wording read only from it. If you delete or hide that section, you pick another or turn the quotes off, so the reminders can't point at nothing. The widget's "safety plan exists" check reads any non-empty section. Export, the data viewer and the guide are updated to match.

**Boundaries list (T6) and Person pages (T1)** use the same reusable *custom sections* component (title plus free text or a checklist), so one editor pattern serves three places.

- *Boundaries list:* starts with a few suggested headings ("Things I'd like people to know", "Things that help", "Things that don't"), all editable, none mandatory. Each section can be marked shareable.
- *Person pages:* start light, with notes plus that person's messages and calendar entries. Any extra sections are added by you. Still no analytics or scoring (T1 stays simple).

**Patch impact:** a new patch, **30a: reusable custom-sections component + Safety plan sections with migration**, goes before the other Patch 30+ items, since T1 and T6 depend on it. The migration must be additive and tested, because a store that fails to open shows the red banner.

## Appendix B: Suggested next session

Nothing in the Progress table is confirmed building yet. The quickest way to check a lot at once is the review run: `scripts/review-on-device.sh` puts the app on your connected iPhone or a simulator on made-up content, with a numbered bar that goes through every change (Patch R1, updated by each RV patch). Before a TestFlight build, also do D28 (read the privacy page and open its links) and the Apple Health checklist in `docs/SLEEP.md`. Patches 34 and 35a (keys and sealed widget summaries) are test-build only, and 35b waits on D15.

Answers still needed: the words for the About screen's creator section, and the licence files (D23). Nothing else is waiting on you. One thing is open but blocks nothing: D29a, trying the Apple Health sleep cleanup on a device, whenever you can.

---

## Appendix D: Offered but not built

Things I listed as not done, or offered with "say if you want it", in one place so none is lost. Nothing here is queued; tell me which you want and it becomes a patch. The number is the change log entry with the reasoning. Items already settled elsewhere are in 0.4 (D25, D26, D30). The one item kept here on purpose, with nothing queued and nothing to decide, is B5.

| Area | Not built | Entry |
| --- | --- | --- |
| Tasks | Recurring tasks; a priority or category field; steps of a blocked task waiting on anything (only whole tasks can); editing a title in place on the card; adding steps by typing on the card | 29, 28, 88 |
| Plan my day | Planning ahead for another day; keeping yesterday's plan; a focus timer offered automatically after each item; a time-left readout while walking through | 32 |
| Focus timer | A timer killed by iOS while the app is closed is lost; with auto-start on and the app closed you get one alert, not a chain | 31 |
| Widgets on a tab | Dragging a card into the Hidden row; moving a widget to another tab; making a full-width widget half width | 30 |
| Quick list | Renaming a list after it is made; rewording an item; reordering items; a widget or Now card | 34 |
| Routines | Reordering routines; renaming from the card; per-step notes; a per-step focus timer; a tap on the reminder that starts the routine | 35, 36 |
| Item lists | Reordering items or headings; renaming a heading for every item; a rule typed as text; a widget or Now card; tying a list to a task or routine; a starter library of templates (written content, which the app does not pre-fill) | 37 |
| Journal | Swiping between months; the optional lenses (entries only, check-ins only, by origin); changing an entry's date; a camera button; a map on place cards; album art on song cards; dragging blocks; a title field | 13, 14, 51 |
| Check-in | A calm "done" moment with a mascot line (needs a new reviewed line pool, Patch 5b); a tap on one bar in the Journal row, a month or year view of check-ins and any pattern across days, left out on purpose | 10, 90 |
| Feedback loops | Multi-select; auto-layout; pan and zoom when only looking; reordering links; loop templates beyond the four; multi-page PDFs for a very large map; a link from a diagram into Export for someone (now unblocked, since 36 to 38 are built) | 41, 42 |
| Sections and Boundaries | A section's words as a checklist; sharing Boundaries as a PDF or picture; a lock-screen or widget view of boundaries; folding the Safety plan and Boundaries list code into one | 43, 44 |
| Message starters | Starters per person; moving a starter between a contact's templates and the list; starters on a widget or the lock screen | 45 |
| Letters | Editing a letter after it is saved; suggested headings (nothing is written for you); a reminder to open one | 46 |
| Things to raise | A separate Questions list or filter; a prompt asking for the answer after an appointment; the answer also added to a session's notes in one tap; a star on journal entries; pulling a check-in or urge in as a plain note | 47, 49 |
| Personal goals | Editing a note after it is saved; linking a goal to a task or appointment; goals in Export for someone (now unblocked); a reminder; putting goals on Plan instead of Bridge | 48, 89 |
| Session prep | Editing a To bring line after it is saved; reordering; carrying a line to the next session | 74 |
| Providers | Reordering providers; provider notes on the Appointments page | 52, 53 |
| Recovery | Softening the Streaks history page, the My streak title and the milestone marks (D24) | 82 |
| Backup | Backing up settings; merging into an existing record (restore skips what is there); encrypting the photo and voice files on the device itself (entry 68 pointed at Patches 34 and 35, and neither did it) | 68 |
| Guide | Website pages made from the guide registry (Patch 47) | 75 |
| Sleep export | Now built as patch SL6 (D29), so nothing is left here | 66 |
| Held on purpose | **Medication notes (B5).** A plain notes box you write in about medication and side effects, with no reminders, no dose fields and no advice, was the only safe shape found. Held 9 Nov 2026 at your word: it is not a decision and not a to-do, and it comes back only if you ask. The reasons: a note about doses can be wrong in a way that matters, the app's wording rule is no medication framing unless you write the words, and a reminder or dose feature would be a medical claim. | 102 |
