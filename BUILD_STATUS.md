# Anchor — build status

> **Status note (November 2026).** This file is a running build log and some older entries are out of date. There is no Electron companion app in this repository. The privacy and support pages now live in `website/` (a Vite app). Escalation is a local reminder to the user, never an automatic message. Session reminders (the evening before and a couple of hours before) are optional, off by default and scheduled by `AppointmentReminders` in `NotificationScheduler.swift`. The NSW mental health law screen is compiled only with the `PERSONAL_BUILD` flag and is not part of the public build.

## Done
- Repo/project directory structure matching a standard Xcode App-template layout
  (`Anchor.xcodeproj/` sibling to `Anchor/`, source files under `Anchor/`, `Views/`
  and `Models/` groups, `Preview Content/` folder present).
- Full SwiftData model layer (`Models/AnchorModels.swift`) covering every
  screen's data needs in one shared store: JournalEntry (the shared content
  pool everything else links into), CheckIn (five sliders, no scoring),
  TrustedContact + MessageTemplate, GroundingTool (physical action or deep
  link, no generic ice/rubber-band suggestions seeded), SafetyPlan,
  TriggerWindow (time/routine-based only, no location), AppointmentSeries +
  AppointmentOccurrence (recurring rule + individually editable occurrences),
  BridgeDraftItem, FeedbackLoopDiagram, ThreadMessage, SupportCalendarEntry,
  FutureNote, UnsentDraft, and MascotLine (pre-written pool, never generative
  at runtime).
- `AnchorApp.swift` entry point wiring the local-only `ModelContainer` (no
  CloudKit config — sync stays local-network/manual export only).
- `ContentView.swift` root tab view: Now / Plan / Journal / Bridge / Thread,
  Now first as the default tab, Journal as its own tab per spec.
- Placeholder screen views so the above compiles end to end right now.
- `Info.plist` with Face ID usage string for the app's independent lock.

## Also done (this pass)
- `Anchor.xcodeproj/project.pbxproj` hand-authored and wired: app target,
  Debug/Release configs, sources/resources build phases, Assets.xcassets +
  AppIcon/AccentColor placeholders, Preview Content. Verified structurally
  balanced and every file referenced exactly where it needs to be
  (build file + file reference + group + sources phase).
- Real Now screen, fully wired to SwiftData: `NowView` composes
  `MascotPresenceView`, `CheckInSliderView` (five sliders, optional save,
  optional expand-to-Journal), `QuickContactsView` (native
  `MFMessageComposeViewController`, not a custom backend), `GroundingToolsView`
  (filtered by `TimeWindowHelper`, user-authored tools only — no seeded
  generic suggestions), `NextHourChecklistView`, `DeEscalationCardView`,
  `QuietRoomToggleView`.
- `MascotEngine`: selects from the `MascotLine` pool only, never generates;
  ships a small starter seed of plain, low-key lines so first launch isn't
  silent, clearly marked as replaceable by the real reviewed content pack.
- Real Journal screen: list, search, free-text editor, auto-linked
  `EntryOrigin` when opened from a check-in, its own tab per spec.

## Also done (this pass)
- Real Plan screen, wired to SwiftData: `SafetyPlanEditorView` (four
  free-text sections, no fields other than what's specified — the
  "reasons to keep going" section is explicitly the pool notification
  quotes draw from), `TriggerWindowListView`/`TriggerWindowEditorView`
  (day-of-week + time-of-day only, no location field anywhere in the
  file), `AppointmentView` (editable recurring cadence as a *default* for
  suggesting the next date, each occurrence individually editable and
  flagged `wasMoved` — not a hardcoded fixed interval), `DecisionFatigueView`
  (user-defined preset choices per category), `CrisisNumbersView` (000,
  Lifeline call/text, always visible at the top of Plan, one tap via
  `tel:`/`sms:` links).
- `NotificationScheduler`: local `UNUserNotificationCenter` only. Every
  notification body is either a fixed reviewed template or that template
  with one stored "reasons to keep going" line slotted in — the file has
  no path that calls a generator. Registers actionable categories
  (message a contact / "I'm okay" / open app) so windows are actionable
  without opening the app. (Optional session reminders are in `AppointmentReminders`, which is refreshed whenever sessions change.)
- Escalation timer logic (per-contact opt-in "if I don't respond in X
  minutes") is modeled in `TrustedContact.escalationEnabled` /
  `escalationWindowMinutes` from the data layer, but the actual
  timer-firing logic isn't wired up yet — see below.

## Also done (this pass)
- **WidgetKit lock-screen widget, as a real second Xcode target** — this was
  the highest-risk hand-authored piece so far (multi-target pbxproj: new
  PBXNativeTarget, PBXContainerItemProxy + PBXTargetDependency so the app
  depends on the widget, a Copy Files "Embed Foundation Extensions" phase,
  separate Debug/Release configs, its own Sources/Resources/Frameworks
  phases). Verified with a full dangling-reference AND orphaned-definition
  scan across every object ID in the file (both came back zero) — not just
  the "does it look right" check used earlier.
  - `WidgetDataStore.swift` (in `Support/`, compiled into *both* targets):
    the only bridge between the app's real data and the widget. Writes just
    contact name + phone number (top 2) and a boolean for "safety plan
    exists" to an App Group–shared UserDefaults suite
    (`group.com.sorren.anchor`) — never plan text, journal text, or
    anything else. This is what "non-sensitive summary info" means here:
    even the widget code itself has no path to richer data.
  - `AnchorWidget.swift` / `AnchorWidgetBundle.swift`: `accessoryRectangular`
    / `accessoryCircular` lock-screen families, showing the top contact
    with a one-tap `tel:` link, and a shield icon linking back into the app
    via a `widgetURL`.
  - App Group entitlements added to both targets (`Anchor.entitlements`,
    `AnchorWidget/AnchorWidgetExtension.entitlements`), both pointing at
    the same group ID, and wired into `CODE_SIGN_ENTITLEMENTS` in both
    targets' build settings.
  - `anchor://` URL scheme registered in the main app's Info.plist;
    `ContentView` handles `.onOpenURL` to jump to the Plan tab when the
    widget is tapped.
  - `PlanView` calls `WidgetDataStore.refresh(...)` on appear so the
    widget picks up contact/safety-plan changes whenever Plan is opened.
    **Known gap:** this only refreshes on-appear, not on every individual
    edit — SwiftData model arrays aren't `Equatable` so a simple
    `.onChange` wasn't viable; a proper fix would observe the specific
    fields that changed. Noted here rather than shipped as silently
    incomplete.

## Also done (this pass)
- **Escalation timer logic**, built honestly around what iOS actually
  allows: `NotificationScheduler.scheduleTriggerWindow` now also schedules
  a per-contact escalation reminder offset by that contact's chosen minutes.
  Stated plainly in the code comments: iOS cannot silently message someone
  in the background, so the escalation notification reminds *the user* and
  puts "Message a contact" one tap away — it does not auto-text anyone.
  If the user taps "I'm okay" or opens the app from the original
  notification first, the escalation is cancelled and the contact is never
  notified at all.
- `NotificationDelegate`: the missing piece that actually handles
  notification action taps (previously only categories were registered,
  nothing responded to them). Wired as the app's
  `UNUserNotificationCenterDelegate` from `AnchorApp.init()`.
- `ContentView` now presents a message composer when the delegate signals
  a "Message a contact" tap, and still handles the widget's `anchor://`
  deep link.
- **`ContactsEditorView`** — this was a real gap: nothing anywhere let the
  user actually create a `TrustedContact` before this. Now handles add/
  edit/delete/reorder, message templates, and the escalation opt-in
  toggle + minutes stepper.
- **`GroundingToolsEditorView`** — same gap for `GroundingTool`; Now's
  empty state said "add your own tools in Plan" before there was
  anywhere to do that. Handles physical-action vs. deep-link tools and
  per-tool time-of-day relevance.
- `PlanView.onAppear` now actually calls the scheduler: requests
  notification authorization, refreshes the widget snapshot, and
  re-syncs every trigger window's notifications (clear-and-re-add) against
  current safety-plan reasons and opted-in escalation contacts.

## Caught during this pass's verification (worth naming, not burying)
The file-tree-vs-pbxproj cross-check I added this round caught a real bug:
an earlier edit to add `WidgetDataStore.swift` to the main app's Sources
build phase had silently no-op'd, because by the time that `str_replace`
ran, the anchor text it was matching was no longer immediately followed by
the section-end marker (the widget's own Sources phase had been inserted
in between). The string simply didn't match, so nothing was added — no
error was thrown either. Caught by counting every `.swift` file's total
reference count in the pbxproj and flagging anything under 4, which is
now a standing check I'll re-run after any future pbxproj edit rather
than trusting one clean balance-check to mean everything landed.

## Also done (this pass)
- **Real Bridge screen**, all sourced from the same shared JournalEntry/
  data layer:
  - `BridgeDraftListView` — running draft, resolve (not hide) items, PDF
    export via `BridgeExportView`/`BridgeExporter` (on-device
    `UIGraphicsPDFRenderer`, handed to the system share sheet — no custom
    backend, no upload, matches "fully exportable" as a real mechanism
    rather than a stated intention).
  - `AppointmentPrepView` / `PostSessionNotesView` — both tied to the
    specific `AppointmentOccurrence` via `prepNoteEntryID` /
    `postSessionNoteEntryID`, not generic untethered notes.
  - `ReframingPromptView` — fact-vs-prediction, opt-in, entered
    deliberately from Bridge only. It asks structured questions; the user
    answers in their own words, and only that gets saved — Anchor doesn't
    analyze or characterize the thought itself.
  - `FeedbackLoopDiagramView` — a minimal node/edge canvas (tap to add a
    node, drag to move, tap two nodes in sequence to connect, long-press
    to rename/delete) so a systems metaphor can become something shown
    to a clinician directly, stored as `DiagramGraph` JSON.
  - `NSWMentalHealthReferenceView` — plain-language summary of Mental
    Health Act 2007 (NSW) ss 12–16 (involuntary admission criteria, the
    two-doctor process, statement-of-rights entitlement), paraphrased and
    sourced from the Act itself (legislation.nsw.gov.au) and the MHCC
    Mental Health Rights Manual, not from memory — pulled via live search
    this session rather than relying on training data for something
    this consequential to get right. Explicitly labeled "not legal
    advice, laws can change" rather than presented as definitive.
- Cross-checked this batch the same way as the widget-target fix: every
  new file's total pbxproj reference count confirmed at 4 (or more, for
  anything spanning multiple targets) before packaging — no repeat of the
  earlier silent no-op.

## Also done (this pass)
- **Real Thread screen** — the fifth and last of the core screens, so all
  of Now/Plan/Journal/Bridge/Thread are now real implementations, not
  placeholders:
  - `ThreadMessagesView` — async check-ins, optionally tied to a contact,
    voice-to-text via the keyboard's own dictation (same pattern as
    Journal, no custom transcription pipeline).
  - `SupportCalendarView` — "extra support today" entries with an explicit
    per-contact visibility list. Documented plainly in the file: since
    this app is local-first with no required backend, "visible to" is
    enforced by what a manual export/share includes, not by a server —
    stated rather than left as an implied guarantee it can't actually make.
  - `FutureNoteListView` — notes to future-you, genuinely unreadable
    (button disabled, text never rendered) until `unlockDate` passes, not
    just visually obscured.
  - `UnsentDraftsView` — "things I want to tell you but haven't." Never
    sends anything itself; `wasSent` is a self-reported toggle the user
    sets after sending some other way, so "never forced to send" is an
    actual property of the code, not just framing.
- `PlaceholderViews.swift` now holds no view code at all — reduced to a
  one-line index of where each real screen lives, kept rather than deleted
  since removing the file would mean also pulling its pbxproj entry for no
  functional gain.
- Same validation pass as the last two rounds (balance, dangling/orphaned
  IDs, per-file reference count ≥ 4) — all clean.

## Not done yet — next in this build, in order
1. Mascot content pack: a larger pre-written, reviewed line set beyond the
   current small starter seed.
2. Encryption at rest + independent Face ID/passcode lock.
3. Electron companion app (data layer, screens, local-network sync or
   manual export/import with the iOS side).

## Where things stand overall
Every screen in the original spec (Now, Plan, Journal, Bridge, Thread) is
a real, wired SwiftUI implementation against the shared SwiftData store,
plus the WidgetKit lock-screen extension and escalation notification
logic. What's left is: a fuller mascot line pack (functional but small
right now), the security layer (encryption + independent app lock), and
the entire Electron desktop companion, which hasn't been started.

## A note on verifying this without Xcode
Everything above has been checked as thoroughly as this container allows —
bracket-balance on the pbxproj, a full scan for dangling/orphaned object
IDs, and a manual file-tree-vs-pbxproj cross-check. What it can't do is
an actual `xcodebuild`/compile pass, since there's no macOS toolchain here.
The single most likely first-open issue, if any, would be a typo'd build
setting rather than a structural one — worth a quick build in Xcode before
relying on it.

This file gets updated as each step lands so nothing is duplicated or lost
across turns.

## Pass: fixing real bugs + full visual pass (this session)

The user tested a build from the previous pass and reported it looked
unfinished, was hard to navigate, and that several features didn't
actually work. Investigated each complaint against the actual code rather
than assuming — here's what was actually wrong and what changed:

- **"The call widget doesn't actually prompt to call."** Confirmed: phone
  numbers are stored exactly as typed (e.g. `0412 345 678`), and
  `URL(string: "tel:0412 345 678")` returns `nil` because of the spaces —
  so the `Link` never rendered at all, and every tap fell through to the
  `.widgetURL` that opened the app instead. Fixed by adding
  `ContactWidgetSummary.dialableNumber` (strips to digits + leading `+`)
  and rebuilding `AnchorWidget.swift`'s rectangular/circular bodies so the
  *entire* widget is the call `Link` when a contact exists (no more
  competing `.widgetURL` on the same tap area) — an actual `Link`
  destination is a hard requirement to trigger the system call-confirmation
  sheet at all, so this was a real functional gap, not styling.
- **"The deep links in the grounding things don't work."** Confirmed:
  `Info.plist` never declared `LSApplicationQueriesSchemes` for
  `spotify`/`discord`, and `UIApplication.shared.open` had no completion
  handler, no fallback, and no user-facing failure feedback — so a bad or
  unresolvable link just silently did nothing. Added the schemes to
  `Info.plist`, and rewrote the open logic as `DeepLinkOpener` (in
  `GroundingToolsView.swift`): tries the saved URL, falls back to a known
  web URL for Spotify/Discord if the native scheme fails, and surfaces a
  real alert if both fail, instead of failing invisibly.
- **"Grounding things with steps should open one at a time, not show
  everything at once."** Confirmed: steps were one text blob shown inline
  on tap. Added `GroundingToolStepRunnerView` (same file, no new file
  needed) — a real full-screen, one-step-at-a-time flow with a progress
  bar, Back/Next, parsed from the existing `steps: String?` field
  (newline-separated) so no SwiftData schema/migration change was needed.
  Updated the editor's footer copy to say "one step per line" so what the
  user types matches how it's parsed.
- **"The diagrams don't work."** Confirmed a real gesture-priority bug:
  `FeedbackLoopDiagramEditorView`'s node view had a bare `DragGesture()`,
  `.onTapGesture`, and `.onLongPressGesture` all attached to the exact
  same view with no priority set — SwiftUI doesn't reliably arbitrate
  that, so taps/drags/long-presses were misfiring against each other.
  Restructured the interaction model instead of trying to win a gesture-
  priority fight blind (no device here to test timing on): adding a node
  is now an explicit toolbar button, "connect mode" is an explicit toggle
  (drag-to-move and tap-to-connect are never live at the same time), and
  renaming moved to a small dedicated pencil button overlaid on each node
  (a real `Button` reliably wins tap priority over a parent drag gesture
  in SwiftUI, unlike two raw gesture recognizers stacked on one view).
- **"Mascot is non-existent."** It was an SF Symbol sparkle next to plain
  text. Replaced with an actual drawn character (`MascotCharacterView` —
  soft rounded body, gradient, two blinking eyes, an anchor "chest mark",
  a gentle idle breathing animation) and a real speech bubble with a tail
  pointing at it (`SpeechBubble`), both in `MascotPresenceView.swift`. All
  dialogue still only ever comes from `MascotEngine`'s pre-written pool —
  this file only draws the character, it doesn't touch what's said.
- **General UI/UX ("looks unfinished," "hard to navigate," "no warm
  feeling").** Added a real design system (`Anchor.Theme` / `Anchor.Card`
  / `Anchor.SectionHeader` / `Anchor.MenuRow` / button styles, all in
  `ContentView.swift` to avoid adding a new project file) — warm
  terracotta/sage palette (also set as the actual `AccentColor` asset,
  which was previously an unset placeholder), soft rounded cards instead
  of stock `List` rows, icon-led section headers, warm capsule buttons
  instead of default `.bordered`/`.plain`. Applied across Now (rebuilt as
  a stack of distinct warm cards instead of one flat undifferentiated
  scroll), Plan/Bridge/Thread (menu rows now have colored icons instead of
  plain text list rows), Journal (card-style rows, warm empty state), and
  the crisis-numbers block (now a high-visibility red card instead of
  looking identical to every other row, since that one specifically
  should never blend in).

### Verification given no macOS/Xcode toolchain here
Same constraint as every previous pass — no `xcodebuild` available. Did:
brace/paren balance check across every edited file (clean), a scan
confirming every new type (`GroundingToolStepRunnerView`, `DeepLinkOpener`,
`MascotCharacterView`, `SpeechBubble`, `Anchor.Card`/`SectionHeader`/
`MenuRow`/button styles) has exactly one definition and no dangling
references, and confirmed no new files were added anywhere in this pass —
every fix was made inside files already wired into the `.pbxproj`, which
means **zero risk of the pbxproj-reference bug from an earlier pass**
recurring, since there was nothing new to wire in. Still worth an actual
build in Xcode before relying on it, same as before.

### Not touched this pass (unchanged from before)
Mascot content pack (still the small starter seed) and the Electron
companion app — still not started.

## Pass: Face ID lock, encryption, more widgets, better notifications

Four things requested this pass, plus a correction partway through.

- **Face ID lock**: `Support/AppLock.swift` (new file, properly wired into
  the app target only). Gates the whole app behind Face ID/passcode via
  `LocalAuthentication`, independent of the phone's own lock state —
  re-locks whenever the app leaves the foreground (`ScenePhase`). If the
  device has no biometrics/passcode configured at all, it bypasses rather
  than locking someone out of their own safety plan, since that failure
  mode would be worse than no lock at all. User-toggleable in Plan under a
  new "Privacy" section; the footer text explains why the toggle is
  disabled if the device can't authenticate.
- **Encryption at rest**: `AnchorSchema.makeContainer()` now applies
  `FileProtectionType.complete` to the SwiftData store file (and its
  `-wal`/`-shm` sidecars). This is iOS's built-in Data Protection API —
  the file is encrypted with a key derived from the device passcode and
  fully inaccessible whenever the device is locked, including to Anchor
  itself. Went with this over a hand-rolled crypto layer or a dependency
  like SQLCipher, since those need a real Xcode/SPM toolchain to
  resolve and test that isn't available here, and Data Protection is
  Apple's own recommended mechanism for exactly this.
- **More lock-screen widgets**: added `AnchorDeEscalationWidget` (the
  script, always visible) and `AnchorNextWindowWidget` (soonest upcoming
  trigger window), both in the existing `AnchorWidget.swift` file and
  registered in `AnchorWidgetBundle.swift` — no new widget-extension
  target needed, just additional `Widget` conformances in the one that
  already exists.
- **Home screen widgets**: extended the existing `AnchorWidget` with
  `.systemSmall` (contact, tap to call) and `.systemMedium` (contact +
  safety plan status + next trigger window) layouts, reusing the same
  `AnchorTimelineProvider`/snapshot as the lock-screen versions.
- **Notifications**: added a daily, non-crisis check-in notification
  (user sets a time in Plan; separate from trigger-window reminders,
  since this one's just "want to check in today?"), varied the
  trigger-window message across four reviewed phrasings instead of
  repeating one sentence verbatim, and added a same-day appointment
  reminder alongside the existing day-before one.
- **`TimeWindowHelper`** gained `nextOccurrence(of:)` and
  `soonestUpcoming(among:)` to support the new "next window" widget and
  Plan's snapshot refresh — pure date math, no location involved.

### Correction made mid-pass
Partway through, the user pointed out `MascotFace.swift` (present in the
folder from their own edits) was a stale file they'd forgotten to delete,
and asked for it to be un-wired and for the mascot to go back to
eyes-only — no brows, no mouth. On investigation, an earlier attempt at
integrating a mood-expression system had actually been built as a
self-contained, separate implementation directly inside
`MascotPresenceView.swift` (brows + a curved mouth shape + a mood→face
mapping) rather than by using `MascotFace.swift`'s types at all — so
`MascotFace.swift` itself was never actually wired in or referenced
anywhere, and removing it required no pbxproj changes (confirmed via a
project-wide grep: zero references to `MascotFace`, `MascotExpression`,
`FaceParameters`, or its brow/eye/mouth types anywhere). What did need
fixing was `MascotCharacterView`, which has been reverted to the
original simple version: two blinking capsule eyes, mood affecting only
body color, no brows, no mouth shape.

### Also caught and fixed while verifying
`AppLock.swift` had only 3 of the 4 expected project-file references
(missing the Sources build-phase entry) from where a previous pass ended —
meaning `AnchorApp.swift` was already calling `AppLockGateView`, but the
file defining it wasn't actually wired into the build yet. This would
have failed to compile with an undefined-symbol error. Added the missing
entry and re-verified. Also finished two pieces that were flagged as
outstanding but turned out to already be wired (`AppLockGateView` in
`AnchorApp.swift`, the Data Protection call in `AnchorModels.swift`) —
confirmed by reading the actual files rather than trusting an end-of-turn
summary, and finished the two genuinely-missing pieces: Plan's new
Privacy/Daily-check-in sections, and computing `nextTriggerWindowLabel`
in `PlanView.refreshWidgetSnapshot()`.

### Verification given no macOS/Xcode toolchain here
Brace/paren balance check across every file touched this pass (clean).
A corrected project-file reference-count check: every Swift file appears
in exactly 4 pbxproj lines (BuildFile, FileReference, group child,
Sources phase) unless it's intentionally shared between the App and
Widget-extension targets, in which case 6 (verified `AnchorModels.swift`
and `WidgetDataStore.swift` are the only two at 6, and confirmed both are
deliberately multi-target, not duplicated by mistake). Confirmed every
new type (`AppLock`, `AppLockGateView`, `AnchorDeEscalationWidget`,
`AnchorNextWindowWidget`) has exactly one definition site. Still worth a
real Xcode build before relying on this — that toolchain isn't available
here.

### Not touched this pass
Mascot content pack (still the small starter seed) and the Electron
companion app — still not started.

## Pass: first batch from the reconstructed feedback document

The user lost a long, detailed analysis/feedback document mid-draft and
retyped everything they could remember from memory — 26 distinct points
across nearly every screen. Given the scope, tackled a first batch of the
most self-contained, high-value items rather than attempting all 26 at
once. Two real technical constraints flagged to the user up front:
Discord DMs need a numeric user ID (username alone can't open a DM via
URL scheme), and Apple's JournalingSuggestions framework (for
music/calendar/places/photo suggestions in the Journal) needs a
selectively-granted entitlement — same end result is achievable by
wiring EventKit/PhotoKit/MediaPlayer directly instead, just more manual.

**Fixed this batch:**

- **Decision-fatigue presets didn't save** — confirmed real bug: plain
  view `@State`, no persistence at all, reset to empty every launch.
  Replaced with real SwiftData models (`DecisionPresetCategory`,
  `DecisionPresetChoice`) and restructured per feedback: each category is
  a menu of named choices, and tapping a choice with steps written opens
  the same click-through step-by-step UI as Grounding Tools. Extracted a
  generic `StepByStepRunnerView` (in `GroundingToolsView.swift`) so both
  features share the exact same runner instead of duplicating it —
  `GroundingToolStepRunnerView` is now a thin wrapper around it. Seeded
  with the three categories from the original request (Outfit, Food,
  Morning routine) only on first launch; fully user-editable after that.
- **"Next hour only" also silently reset on every launch** — same class
  of bug, caught while working nearby. Added a persisted `NextHourItem`
  model (not yet wired into the view itself — that's queued alongside the
  Reminders-integration part of that request, since it's a separate,
  larger piece of work).
- **Trigger window day picker** — replaced the tall list of individual
  day toggles with `WeekdayCirclePicker`, a row of circle letter toggles
  matching the Health app's sleep-schedule pattern.
- **Quiet Room removed** — confirmed it was genuinely inert: a local
  toggle whose state was never read or displayed anywhere else in the
  app, despite copy claiming it was "visible to your chosen people."
  Removed entirely from Now, `ContentView`/model wiring, and the mascot's
  trigger vocabulary (`quietRoomOn`/`quietRoomOff` cases and their lines
  deleted, not just orphaned).
- **De-escalation script "needs workshopping"** — rather than guessing at
  better wording myself, made it real user-editable content: new
  `DeEscalationScript` model, a list editor in Plan (seeded with three
  varied starting scripts), and a "Try another" button on Now to cycle
  through the user's own set instead of showing one fixed line forever.
- **Check-in redesign** — two fixes in one:
  - *Sentiment consistency*: three of five sliders were framed "more =
    worse," two "more = better." All five now read "more = better" when
    dragged right (relabeled: Physical exhaustion → Physical energy,
    Cognitive burnout → Mental clarity, Mental load → Room in your head).
    The underlying `CheckIn` model's stored fields are untouched — this
    view just inverts what the slider shows and converts back on save, so
    nothing else that reads `CheckIn` needed to change.
  - *Optional extra prompts*: after the sliders (where "Finish" is a
    complete, default action, not a partial one), an optional "a few
    questions" flow offers five short, individually-skippable prompts
    using the same one-at-a-time pattern as Grounding Tools — directly
    answering the feedback that this same reduce-overwhelm design should
    show up elsewhere. Any answered prompts become one real Journal entry,
    auto-linked to the check-in; `NowView`'s existing journal-opening sheet
    now opens *that* linked entry instead of creating a redundant second
    blank one.
- **NSW law page "cluttered and confusing"** — restructured from one long
  scroll into a menu with three focused sub-pages: Hospitalisation,
  Confidentiality (didn't exist before at all — added real content on
  confidentiality's general limits, still hedged as not legal advice, same
  as the rest of this section), and Talking to your psych. Shared a common
  `ReferencePage` scaffold so every sub-page has the same consistent
  sources/disclaimer footer.
- **"What does Async Check-ins even do?"** — confirmed the feature itself
  was fine (a private log, tagged optionally with a contact — nothing was
  ever actually sent anywhere), the problem was that nothing in the UI
  said so, and the contact picker made it look like it might be live chat.
  Added an explanatory line at the top, and — since the name promises
  something interpersonal that the old version never actually did — added
  a real "Save & send via Messages" option alongside "Save privately,"
  reusing the same `MFMessageComposeViewController` pattern as Quick
  Contacts, so it can actually reach someone when that's what's wanted.

### Verification given no macOS/Xcode toolchain here
Same method as every previous pass: brace/paren balance check on every
file touched this batch (clean), single-definition check on every new
type (`DecisionFatigueView`, `WeekdayCirclePicker`,
`DeEscalationScriptsEditorView`, `StepByStepRunnerView`,
`HospitalisationReferenceView`, `ConfidentialityReferenceView`,
`TalkingToYourPsychReferenceView` — one definition each), and a full
project-wide grep confirming zero leftover references to the removed
Quiet Room feature anywhere (view, state, model enum cases, mascot
lines). New models (`DecisionPresetCategory`, `DecisionPresetChoice`,
`DeEscalationScript`, `NextHourItem`) registered in
`AnchorSchema.models` — no new pbxproj entries needed anywhere this
batch, since everything was added to files already wired into the
project. Still worth a real Xcode build before relying on this.

### Queued from the same feedback document (not done yet)
This was a 26-point document; the rest is queued for follow-up passes,
roughly in this order: full navigation redesign (tile-button dashboard
per screen), Journal rewritten as a scrollable timeline with an inline
check-in-slider graph, Journal as a full rich-text/Markdown editor with
attachments, Journal context suggestions (calendar/photos/music — via
EventKit/PhotoKit/MediaPlayer directly, per the entitlement note above),
mascot prompts library + more presence throughout the app, quotes/
affirmations feature (Now + a new widget), feedback-loop diagram overhaul,
shared calendar external access for non-app-users (likely `.ics`
generation), contacts-book picker + Discord contact option (ID-based) +
per-contact timezone/availability, Next Hour's actual Reminders/Calendar
integration (model's in place, view isn't wired yet), appointments as a
calendar-month UI, decoupling "settings" from "quick access" (depends on
the navigation redesign), an app tutorial / "?" help trigger, a full
data-control screen (view/export/import/clear, PDF/CSV, per-date-range),
and a tone/AI-indicator copy pass across the whole app.

## Pass: bug fixes + rearranging (this session)

Picked up from a user-modified upload (their edits, including a genuine
compile-fix in JournalEntryEditorView.swift's MarkdownTextView.apply — a
`text.wrappedValue` that should've been `$text.wrappedValue`, since `text`
was already the unwrapped String inside that method, not the Binding —
confirmed correct and audited the whole project for the same mistake
elsewhere; none found). Then worked through a new set of reported issues:

- **Face ID feels janky**: `AppLock.attemptUnlock()` had no re-entrancy
  guard. `.onAppear` and `.onChange(of: scenePhase)` transitioning to
  `.active` can both fire it within the same runloop at cold launch,
  starting two concurrent `LAContext.evaluatePolicy` calls that interfere
  with each other — a very plausible source of "doesn't quite work, can't
  explain why." Added an `isAuthenticating` guard so a second call while
  one's in flight is a no-op, and now keep a reference to the active
  `LAContext` so `lock()` can call `.invalidate()` on it if the app
  backgrounds mid-prompt instead of leaving it dangling.
- **Mascot speech bubbles don't work**: `MascotEngine.line(for:mood:)`
  used a SwiftData `#Predicate` comparing `$0.trigger == trigger` where
  `trigger` is a `Codable` enum. `#Predicate`'s support for enum equality
  comparisons has real, documented reliability issues across SwiftData
  versions — when it throws, the `try?` a reasonable caller writes
  swallows the error silently, meaning the function could return `nil` on
  literally every call with no visible error anywhere. That matches "the
  mascot doesn't seem to say anything" exactly. Rewrote to fetch the pool
  (small — tens of lines) and filter with plain Swift `==` instead, which
  doesn't go through the predicate compiler at all. Audited every other
  `#Predicate` usage in the project (`AppointmentPrepView`,
  `PostSessionNotesView`, `NowView`) — all three only compare `UUID`
  properties, which don't have this issue, so no other fixes needed there.
- **Widget taps unreliable**: redesigned per the user's own suggested
  fix. Every widget family in `AnchorWidget.swift` now renders plain,
  non-interactive content with exactly one `.widgetURL` on the whole
  view — no `Link` elements inside widget content anywhere anymore. The
  call widget routes to `anchor://action/call`, which `ContentView`
  catches and presents `WidgetActionConfirmationView` (new file) — a real
  in-app screen with a real `Button` that does the actual `tel:` open,
  where SwiftUI Button/Link behavior isn't a widget-rendering-surface
  concern at all. Added `TrustedContact.dialableNumber` (the same
  space-stripping logic that already existed on the widget DTO) since the
  call now happens from a live `TrustedContact` fetched in-app, not the
  widget's snapshot copy.
- **Decision-fatigue preset steps**: converted from a single
  newline-separated `TextEditor` to the same per-row editable list
  (add/delete/reorder) already used for de-escalation scripts —
  `choice.steps` stays the same underlying newline-joined string (so
  `StepByStepRunnerView`'s parsing didn't need to change), the editor
  just presents it as real rows now.
- **Appointments "All sessions"**: added a per-row delete (trash icon —
  this list lives in a custom `VStack`/`Anchor.Card`, not a native
  `List`, so real swipe-to-delete isn't available; a direct button is the
  reliable equivalent) and a "Remove all" action with a confirmation
  dialog.
- **Next Hour Only / Quick Contacts rearranging**: Next Hour moved
  "import from Reminders" into the section header as a compact icon
  button and merged "also add to Reminders" into the add-row as a bell
  toggle, instead of two extra full-width rows competing with the actual
  list for attention. Quick Contacts replaced two fully-stacked
  name+template blocks with a compact contact-selector row plus one
  template row for whichever contact is selected — meaningfully shorter
  when both contacts have several templates each.
- **"What's the point of Async Check-ins?"**: traced the actual
  confusion — it sat directly next to "Things I haven't said"
  (`UnsentDraftsView`) sounding like the same feature. They're genuinely
  different (this one's tied to a real `TrustedContact` and can actually
  send via Messages/Discord; that one uses a free-text recipient label
  and never auto-sends anything), but nothing said so. Renamed to
  "Message log" and rewrote the in-view explanation to explicitly
  contrast the two by name.
- **Tab rearrangement**: moved `CrisisNumbersView` from the top of Plan
  (increasingly a pure-configuration tab) to the very top of Now (the
  quick-access tab, above even the mascot) — the single most
  safety-critical piece of content in the app belongs on the tab meant
  for "get to it fast," not mixed in with settings rows.

### Verification given no macOS/Xcode toolchain here
Full project-wide string-literal-aware brace/paren balance check across
all 47 tracked Swift files (clean, aside from the already-known,
completely unwired `MascotFace.swift` stray file — confirmed 0 pbxproj
references again this pass, so it can't affect compilation regardless of
its own internal state) and a pbxproj reference-count check (every file
at 4, or 6 for the two legitimately multi-target files — clean). Caught
and fixed a real self-introduced bug during this pass too: a str_replace
edit to `AppointmentView.swift` accidentally duplicated an `if`/Card/VStack
wrapper; caught by the balance check immediately after, not left in.

### Not done yet
Further sub-screen/tab rearrangement beyond the Crisis Numbers move (no
other specific moves were named), full navigation redesign, further
feedback-loop diagram overhaul, an app tutorial, and the tone/AI-indicator
copy pass — all still queued from the previous pass's list.

## Pass: nav redesign, tutorial, tone pass, em dash sweep

- **Em dashes**: per explicit instruction that em dashes (and other
  "non-human typing behaviors") count as an AI indicator, went through
  every user-facing string in the app and removed them, restructuring
  sentences with periods/commas instead. Covered Text/Label content,
  alerts, error messages, notification templates, the PDF export text
  generator, and the actual seeded content pools (affirmations,
  de-escalation scripts) since those become real content the user might
  keep. Left source-code comments alone (not visible to the user, not
  "typing behavior" in the relevant sense) — happy to sweep those too if
  wanted.
- **Navigation redesign**: added `Anchor.TileButtonLabel` and
  `Anchor.TileRow` to `ContentView.swift`'s shared component set — a
  square icon+label tile and a horizontally-scrolling themed row of them,
  matching Now's card-based dashboard visual language rather than a plain
  `List`. Rebuilt `PlanView` and `BridgeView` around this: Plan groups
  into "Safety & people," "Presets & tools," and "Data" tile rows, plus
  one compact "Preferences" card for the two genuine on/off settings
  (Face ID, daily check-in) — deliberately not their own tiles, since
  a toggle doesn't benefit from a tap-through, and deliberately not a
  separate settings menu or per-page cog icon, per explicit instruction.
  Bridge groups into "For your psych," "Cognitive tools," and
  "Reference." Thread was deliberately left as its existing list — it's
  only 4 items, and the explanatory subtitles that were added to
  distinguish "Message log" from "Things I haven't said" a few passes ago
  would have nowhere to live in tile format, so converting it would trade
  clarity just fixed for consistency of pattern; not a clear win.
- **App tutorial / help**: new `HelpContent.swift` (`Support/`) holds one
  `HelpTopic` enum (now/plan/journal/bridge/thread) with concise, reviewed
  explanations, plus `HelpSheetView` and `HelpToolbarButton` — a single
  content source used both by a "?" button now present in every tab's
  toolbar and by `OnboardingTourView.swift` (`Views/Now/`), a paged,
  mascot-voiced first-launch tour. Shown automatically once
  (`OnboardingState.hasSeenTour`, a plain `UserDefaults` flag, not
  SwiftData — this is a device preference, not exportable user data) and
  replayable anytime from Plan → Preferences → "Replay the tour."

### Verification given no macOS/Xcode toolchain here
Full project-wide string-literal-aware balance check across all 48
tracked Swift files (clean, aside from the same already-known, completely
unwired `MascotFace.swift` stray file with 0 pbxproj references) and a
pbxproj reference-count check (every file at 4, or 6 for the two
legitimately multi-target files — clean). Both new files
(`HelpContent.swift`, `OnboardingTourView.swift`) confirmed at exactly 4
references each after wiring.

### Not done yet
Feedback-loop diagrams still need the larger overhaul beyond the
gesture-conflict fix from a few passes ago — that's the one item left
outstanding from the reconstructed feedback document.

## Pass: release prep (TestFlight / App Store)

- App group in code corrected to `group.page.aspens.anchor` to match both entitlements files (widget previously read from a different suite than the one granted). URL scheme name set to `page.aspens.anchor`.
- App icon: `Anchor/AppIcon.icon` (Icon Composer format: terracotta mascot body layer + cream face layer (eyes and anchor chest mark) over a sage gradient), wired into the app target's Resources phase. Old empty `AppIcon.appiconset` removed. Needs Xcode 26+.
- `PrivacyInfo.xcprivacy` added to the app (UserDefaults reasons CA92.1, 1C8F.1) and widget (1C8F.1), no tracking, no collected data types.
- Build settings: `ITSAppUsesNonExemptEncryption = NO`, iPad orientations (all four), `SUPPORTS_MAC_DESIGNED_FOR_IPHONE_IPAD = YES`.
- `CrisisNumbersView`: region aware (AU, US, CA, GB, IE, NZ, other), defaults to the device region, manual override stored in `anchor.crisisRegion`.
- Journaling Suggestions: `com.apple.developer.journal.allow` entitlement and a `JournalingSuggestionsPicker` section in `JournalContextSuggestionsView` (guarded by `canImport`).
- `AnchorSchema.makeContainer()` no longer `fatalError`s if the store cannot open. It falls back to an in-memory store, sets `openedPersistentStore = false`, and `AnchorApp` shows a red banner. Real store files are never deleted.
- Data protection class changed from `.complete` to `.completeUntilFirstUserAuthentication` so background launches while locked can open the store.
- Privacy and support pages live in `website/` (`src/pages/Privacy.tsx`, `Support.tsx`). The support email is set in `website/src/content/meta.ts`.
- Not compiled in this environment; the pbxproj additions were checked by reference count and brace balance only.
