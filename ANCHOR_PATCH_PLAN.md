# Anchor — Patch Plan (v2-recovery)

*Living document. Last updated: 7 Nov 2026, after the sleep journal was added to the plan (Patches 1 to 25 and 21b are pushed, `c19aa94` at the time; none confirmed building; the sleep journal, point 29, is planned and not yet scheduled).*

> ## READ THIS FIRST: THIS FILE IS THE PROMPT
>
> **This file is the single source of truth for the Anchor patch work, and it contains the standing instructions for Claude.** When you start or resume a session, give Claude this file and say "keep doing patches". It replaces the earlier Claude Doc, which is no longer maintained. Claude edits this file in every patch, never the Claude Doc.
>
> **Instructions for Claude (follow these every session):**
>
> 1. **Get the code by cloning, not fetching.** Repository: <https://github.com/Kousei-Uchu/Anchor/tree/v2-recovery>. Web fetching the repo fails, so clone it (`git clone --branch v2-recovery`). Claude has no access to push; the user pushes.
> 2. **Do the next unfinished patch from the Progress table, in order.** Keep going patch after patch unless a decision in 0.4 blocks it. Patches marked deferred stay deferred.
> 3. **Deliver each patch as a `.sh` text file the user opens, copies and pastes into macOS Terminal.** It is not run as a script, so it must not start with a shebang or contain `set -e`. It finds the repo root itself, pulls, applies the change as a `git apply` diff, stages only the touched files by name (never `git add -A`), commits with a message starting with the patch number, and pushes. Check that it applies on a fresh clone, after any earlier unpushed patches, before sending.
> 4. **Edit this file in the same patch.** Update the Progress table, the change log and any decision or point the patch changes, so the repo always holds the current plan. This file lives at the repo root.
> 5. **Meet the Definition of Done (0.3)** and add one line to `CHANGELOG.md`.
> 6. **UI copy:** natural, human-written prose. No em dashes, emoji or ASCII art in any user-facing text, and no AI-sounding phrasing. Keep explanations out of inline UI text and in READMEs or the guide.
> 7. **Be honest about verification.** Claude cannot run Xcode. Say what was and was not compiled or tested, and mark patches "Written, awaiting your build" until the user confirms.
> 8. **Wording rules for the app:** no scores or streak pressure, no "treatment" or "medication" framing unless the user writes it (see Appendix A).

Planning and patches in progress. Each of your 28 points is outlined, then grouped into small ordered patches.

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
| 13b: Edit pattern on Bridge and the Journal entry preview; old Edit components removed | 🟡 Pushed by you (`92d2c67`); build not yet confirmed |
| 14a: Message log, part 1: quick write to a person, per-person history, Send again and Copy, a Write button on the widget | 🟡 Pushed by you; build not yet confirmed |
| 14b: Message log, part 2: voice notes (record, play, attach when sending through Messages) | 🟡 Pushed by you (`464a9a0`); build not yet confirmed |
| 15: Tasks: `TaskItem`, carry-over from Next hour only, basic list, Plan widget, export and import, demo data | 🟡 Pushed by you (`698b6c0`); build not yet confirmed |
| 16: Task due dates, fuzzy values, grouping by time | 🟡 Pushed by you (`15e1daf`); build not yet confirmed |
| 17: Subtasks with collapse and derived progress | 🟡 Pushed by you (`484caca`); build not yet confirmed |
| 18: Task dependencies: greyed blocked tasks, "Waiting on…", auto-unlock | 🟡 Pushed by you (`03b920d`); build not yet confirmed |
| 19: Task status, energy tag, tiny first step, snooze to tomorrow | 🟡 Pushed by you (`0592258`); build not yet confirmed |
| 20: Widget editing on the tab: drag to rearrange, hide and add back, half or full width | 🟡 Pushed by you (`9d3ef0c`); build not yet confirmed |
| 21: Focus timer (Pomodoro): settings, alert when a phase ends, session count per task | 🟡 Pushed by you (`e36e11a`); build not yet confirmed |
| 22: Plan my day: pick tasks and steps, time estimates, order, time available, walk through them | 🟡 Pushed by you (`113ab11`); build not yet confirmed |
| 21b: Focus timer on the lock screen and Dynamic Island (Live Activity) | 🟡 Pushed by you (`1eb098e`); build not yet confirmed |
| 23: Quick list: one-off checklists with an Archive | 🟡 Pushed by you (`523b7bb`); build not yet confirmed |
| 24: Routines beside Decision presets, with Run it | 🟡 Pushed by you (`827d8e7`); build not yet confirmed |
| 24b: Routine schedule and reminder (off by default) | 🟡 Pushed by you (`e99c872`); build not yet confirmed |
| 25: Item lists with quantity rules, Reset ticks and Make a copy | 🟡 Pushed by you (`c19aa94`); build not yet confirmed |
| SL1 to SL5: Sleep journal (point 29, a tester's request) | ⬜ Planned, not scheduled; waiting on D10 to D14 |
| 26 onward | Not started |

## Change log of this plan

- **7 Nov 2026 (38):** Patches 24b and 25 confirmed pushed (HEAD was `c19aa94`). **Docs only, no code:** a tester asked for a sleep journal that can use Apple Health, be shared with a therapist and show up in other places. It is added as point 29, with five small patches (SL1 to SL5, in a new Phase E2 below Phase E) and five decisions (D10 to D14) that need your answers before any of it is built. The short version: a manual sleep journal comes first and changes nothing about the privacy story; Apple Health is a separate, opt-in step that does change it (a new capability, usage strings, the privacy page and the App Store health questions), so it is kept apart on purpose. Nothing about sleep has a score, a target or a streak. Knock-on effects on Patches 31, 34 to 38, 41 to 43, 46 and 48 are listed under point 29.
- **7 Nov 2026 (37):** Patch 25 written: item lists (point 8, second half), stacked on Patch 24b, which was not pushed yet when this was written, so paste 24b first. **Where:** a third side on the Presets screen, Decisions / Routines / Lists. A card per list shows its name, \"5 of 12 ticked\" (never a percentage) and its numbers (\"Day 3, Person 2\"). The plus makes a list and opens it; a list left with no name and no items is removed when you go back. **A list:** its name, its numbers, and its items under headings, in the order the headings first appear, with items that have no heading under Other. The circle ticks an item and tapping the item opens it; swipe or hold removes one. A bar at the bottom adds items, and pasting several lines makes one item per line (list markers dropped, the same as Quick list). Nothing changes or is announced when everything is ticked. **Numbers:** a list can hold up to six, each with a name and a value (Day 5, Person 2), changed with a stepper right on the list and renamed, added or removed in an Edit numbers sheet. **Amounts:** an item is either a set number or follows a number: N per unit, plus an optional extra, M extra for every K, rounded down. \"1 per day + 1 extra for every 3\" with 7 days is 7 + 2 = 9. The item shows the amount as a multiplication badge when it is not one, and a small line spelling out the rule. The item sheet has a Right now line so the rule can be checked as you set it. A rule points at its number by id, so renaming a number is safe; removing a number sends its items back to their set amount. **Reuse (the plan's templates):** a list menu has Reset ticks and Make a copy. A copy has its own numbers and every item unticked, so the same packing list can be used for the next trip. **Deviation:** the plan said \"reusable templates\". I did not build a separate templates area: a list you keep is the template, Reset ticks reuses it and Make a copy forks it. A starter library of templates would be written content, and the app does not pre-fill content; say if you want a different design. **Model:** `ItemList` with its numbers and items as small arrays of values inside it (`ListVariable`, `ListItem`, `QuantityRule`), so a list is one record; all fields have defaults and it is a new model, so no store migration. It is in the schema, export and import (optional `itemLists` key), the data counts, Clear all data and the demo (\"Weekend away\", 3 days). Help (Plan) and CHANGELOG are updated. **Not done:** reordering items or headings, renaming a heading for every item at once, a rule typed as text, a widget or Now card for lists, and tying a list to a task or routine; say if you want any. **Size:** about 520 changed lines in 7 files, over the M guide, because the model, three screens and the export came together; the new views are in `DecisionFatigueView.swift` again so the project file needs no change. **Needs a real check:** the third segment fitting at large text sizes; the new-list push (it uses `navigationDestination(item:)`); the quantity badge changing as a Day stepper moves; the item sheet's amount switch and Right now line; Make a copy, then Reset ticks. Checked only with a Swift syntax parser, not compiled.
- **7 Nov 2026 (36):** Patch 24 confirmed pushed (HEAD was `827d8e7`). Patch 24b written: the routine reminder, following C2. **Off by default:** a routine has no reminder until you switch Remind me on, in the routine's editor or in Settings, in a new Routine reminders section next to Reminders (one row per routine, with the time once it is on). **Setting it:** seven day buttons, starting from your calendar's first weekday, and a time. Switching it on picks every day to begin with, and asks the notification permission question only then, never at launch. If every day is switched off the editor says to pick one and nothing is scheduled. The card on the Routines screen shows a quiet bell line such as \"Mon, Wed, Fri at 7:30 AM\" when one is set. **Wording:** the lock screen always says \"Your routine is ready when you are.\" It never names the routine or a step; the editor says so under the switch. **How it works:** one repeating weekly notification per chosen day, identifiers starting `routine-`. Every refresh clears those and adds the current set again, the same way the recovery reminders do, so what is scheduled always matches what is saved. It refreshes when the routine editor closes, when a Settings switch or time changes, when Plan appears, after an import and on Clear everything; a routine with no written steps schedules nothing; the demo never schedules. **Model:** four fields on `Routine` (`reminderEnabled`, `reminderDays`, `reminderHour`, `reminderMinute`), all defaulted, so no store migration; export carries them as optional keys, so older files and Patch 24 exports import. **Not done:** the quiet \"Turn on\" line from C2 is the switch itself here, since the switch sits in the same screen; no tap action on the notification (tapping just opens Anchor, and it does not start the routine); nothing is held back while Quiet Room is on, the same as the recovery reminders. Say if you want either. **Size:** about 230 changed lines in 8 files. **Needs a real check:** the permission question appearing on the first switch-on, a notification arriving at the set time on a chosen day only, the day buttons at large text sizes, and Settings showing a row for each routine. Checked only with a Swift syntax parser, not compiled.
- **7 Nov 2026 (35):** Patch 23 confirmed pushed (HEAD was `523b7bb`). Patch 24 written: Routines (point 8, first half). **Where:** Decision presets and routines now share one screen, **Presets**, with a Decisions / Routines switch at the top (the plan's "one Presets screen"). Each side keeps its own title and plus button. The Plan tile in the classic layout is renamed Presets; the widget keeps its id and its title, Decision presets, so saved layouts are untouched. **Routine:** a name and an ordered list of steps, each with an optional rough time (none, 1, 2, 3, 5, 10, 15, 20, 30, 45 or 60 minutes). A card shows the name and one line such as "5 steps, about 32 min plus 1 with no estimate"; nothing is scored. **Making and editing:** tap a card to edit it, the plus adds one, Delete is inside the editor (with a question) and in the card's long-press menu. In the editor, steps are rows you can reword, set a time on, swipe to delete and reorder with a labelled Reorder button; a block pasted into the Add a step box becomes one step per line, with list markers dropped, the same way Quick list does it. A routine left with no name and no steps is removed when the editor closes. **Run it:** a play button on the card (and Run it in the editor) opens one step at a time with Back and Next, "Step 2 of 5" and the step's rough time if it has one, the same shape as the grounding tools. It records nothing, has no timer and never says how long you took. **On Plan:** routines you have written also show as play chips under the category chips on the Decision presets widget, so one can be started from the tab without opening the screen; the widget now shows if you have routines even with no decision categories. **Model:** a new `Routine` with its steps as a small array of `RoutineStep` values inside it (the way a quick list keeps its items), so a routine is one record. All fields have defaults and it is a new model, so no store migration. It is in the schema, export and import (optional `routines` key, so older files import and a v2 export imports into an older build), the data counts, Clear all data and the demo ("School mornings"). Help (Plan) mentions it, CHANGELOG has a line. **Deviation:** the plan listed an optional schedule and reminder on a routine in this patch. It is split off as **Patch 24b**, because a reminder needs the C2 pieces (off by default, a quiet in-context line, a switch in Settings, Reminders, generic lock-screen wording) and a notification identifier scheme, and bundling them would have made this well over the M guide. **Not done:** reordering routines themselves (they sit in the order made), renaming from the card without opening it, per-step notes, and a per-step focus timer from Run it; say if you want any of them. **Size:** about 480 changed lines in 8 files; the new views are in `DecisionFatigueView.swift`, so the project file needs no change. **Needs a real check:** the Decisions / Routines switch at the top (it is a safe-area inset over the two screens, and the nav title and plus button should change with it); the time menu inside a Form row; Reorder on steps; a routine added from the empty state; the play chips on the Plan widget; Run it from inside the editor sheet. Checked only with a Swift syntax parser, not compiled (no Swift tools in this environment).
- **7 Nov 2026 (34):** Patch 21b confirmed pushed (HEAD was `1eb098e`). Patch 23 written: Quick list (point 9). **Entry:** Quick list in the Tasks screen's menu, plus a quiet Make a quick list button on the empty Tasks screen. **Making one:** a sheet with an optional name and a box for the items, one per line, with a live count under it ("3 items"). A bullet, dash, number or tick box at the start of a line is dropped, so a list copied from Notes or a message pastes cleanly; a marker needs a space after it, so "-5 degrees" and "2024 taxes" are left alone. A blank name becomes "Quick list, 7 Nov". Start saves the list and opens it in the same sheet; Cancel saves nothing. **Using one:** one focused checklist with big rows. Tap an item to tick or untick it (ticked items stay where they are, struck through, so the list does not jump about under your thumb), swipe or long-press to remove one, add more from the bar at the bottom. **Archive:** ticking the last open item archives the list by itself, with one quiet line ("All ticked off. This list is in the Archive."); unticking any item, adding one, or Start again brings it back. Active lists show in a Quick lists section at the top of the Tasks screen ("2 of 5 ticked", no bars or percentages); an Archive row at the bottom opens the finished ones, newest first. **Menu on a list:** Move open items to Tasks (copies them in as plain tasks at the end of the list and takes them off, so nothing shows twice; what was ticked stays), Start again (unticks everything, for a list you reuse), and Delete list (asks first). A list left with no items is removed when its screen closes. **Model, and a deviation:** the plan said a `TaskList` flagged `isOneOff`. I built a separate `QuickList` instead: a quick list has no dates, steps, waiting, energy or estimate, and ending the list when the last item is ticked is different from a finished task. Reusing `TaskItem` would have meant every list, widget, plan and export filter learning to leave these items out. The items are a small array of values inside the list (`[QuickListItem]`, the way a contact keeps its message templates), so a list is one record. All fields have defaults and it is a new model, so there is no store migration (the same lightweight change as when tasks arrived). **Definition of Done:** added to the schema, export and import (optional key, so older files import), the data counts, Clear all data and the demo (one active list, one archived); Help (Plan) mentions it; CHANGELOG has a line. The privacy story does not change: nothing leaves the device. **Not done:** renaming a list after it is made (the name is set when you make it; delete and remake for now), rewording an item (remove and add again), reordering items, and a Quick list widget or Now card; say if you want any of them. **Size:** about 580 changed lines in 6 files, well over the S the plan gave it, because the model, the three screens and the export came together; the new views live in `NextHourChecklistView.swift` again so the project file needs no change. **Needs a real check:** pasting a multi-line list into the box and the items splitting correctly; Start opening the list inside the same sheet; the archive line appearing when the last item is ticked and the list leaving the Quick lists section; Move open items to Tasks; the empty Tasks screen showing quick lists when there are no tasks. Checked only by reading it through here, not compiled (no Swift tools in this environment).
- **7 Nov 2026 (33):** Patch 22 confirmed pushed (HEAD was `113ab11`). Patch 21b written: the focus timer on the lock screen. **Off by default** (C2): a Show the timer on the lock screen switch in the timer's settings, Focus timer on the lock screen in Settings, Reminders, and a quiet "The lock screen timer is off. Turn on" line on the timer screen. No permission question is involved; if Live Activities are off for Anchor in iOS Settings, nothing shows and nothing breaks. **What shows:** the phase (Focus, Short break, Long break), a live countdown that the system keeps ticking by itself, and "Paused" while paused. It never shows the task, the same rule as the alert and the lock-screen widget. It is there only while a phase is running or paused, and goes when the phase ends, you stop, or you skip. If the phase ended while the app was asleep it reads "Time is up" until the app wakes. Dynamic Island: compact, minimal and expanded forms. **Code:** `PomodoroActivityAttributes` is in `WidgetDataStore.swift` because that is the one file other than the models that both targets build, so the project file needs no change; the widget side is appended to `AnchorWidget.swift` and added to the widget bundle; the app side is in `PomodoroTimer`. `NSSupportsLiveActivities` is added to the app's `Info.plist`. A timer left on the lock screen by a run that iOS closed is cleared the next time a timer screen opens. **Needs a real check, more than most patches:** this is the first ActivityKit code in the project and it spans two targets, so a build error there is more likely than elsewhere; on a device, check that it appears, counts down, pauses, ends, and that the Dynamic Island forms look right. Live Activities in the Simulator work from Xcode 14.1 on, but a real device is the true test. Checked only with a Swift syntax parser, not compiled.
- **7 Nov 2026 (32):** Patch 21 confirmed pushed (HEAD was `e36e11a`). Patch 22 written: Plan my day. **Entry:** Plan my day in the Tasks screen's menu. **Time estimates:** the plan's task model listed an estimate but no earlier patch added one, so this patch adds `estimateMinutes` to `TaskItem` (default 0, no store migration): a How long row in the task editor (None, 5 min, 15 min, 30 min, 1 hr), shown on the card as "About 15 min". Export carries it (optional, so older files import); the demo has three. **The screen:** a stepper for the time you have (half hours, up to 12 hours, or not sure), one quiet line that adds up the plan ("About 1 hr 15 min planned, with 2 hr to spend, plus 1 with no estimate."), Your plan, and Add to your plan. The pool is what can be done now: open tasks that are not waiting or set aside, plus the open steps of those tasks (a step reads "Step of ..."). Plus and minus buttons add and remove; a labelled Reorder puts the plan in order. Nothing turns red or says you are over: the line only describes. Tasks ticked off elsewhere drop out of the plan by themselves. **Walking through it:** Start opens one item at a time with its first tiny step and estimate. Focus on this opens the focus timer on it (Patch 21), Done ticks it off and moves on, and Not now sets it down without changing it. At the end it says "That is the plan for today." and offers to go back to the ones set down. No counts, no "3 of 5". **Storage:** the plan (the ordered ids and the time you said you have) is kept in UserDefaults for the day. A plan from an earlier day is dropped without comment; the time you said you have carries over. It is not in export and is cleared by Clear everything. A real plan that outlives the day would need a model, so say if you want yesterday's plan kept. **Not done:** planning ahead for another day; a pomodoro offered automatically after each item (Focus on this is a button, so nothing starts without a tap); a time-left readout while walking through. New views are in `NextHourChecklistView.swift` again. `durationText` lives in `AnchorModels.swift` because that file is built into the widget too and the screens are not. Checked only with a Swift syntax parser, not compiled.
- **7 Nov 2026 (31):** Patches 19 and 20 confirmed pushed (HEAD was `9d3ef0c`). Patch 21 written: the focus timer. **Where:** "Focus on this" in a task's long-press menu, "Focus on this step" on a step, a Focus section in the task editor, and Focus timer in the Tasks screen's menu (no task needed). While a timer is going, a slim bar at the top of the Tasks screen shows the phase and time and reopens it. **Timer:** one shared timer that works from an end time, so it stays right when the app is in the background and keeps going when the screen is closed. Focus, short break and long break, with a round count ("Round 2 of 4"); Start, Pause, Resume, Stop and Skip break. When a phase ends the next one waits for you unless you turned on "Start the next one by itself"; if the app was asleep when it ended it never auto-starts. The screen stays awake while the timer screen is open and running. The task can be picked or changed from the timer screen except in the middle of a focus phase. **Settings** (the gear on the timer screen): focus 5 to 90 minutes in fives (25), short break 1 to 30 (5), long break 5 to 60 in fives (15), rounds before a long break 2 to 8 (4), breaks on or off, auto-start (off), haptic when one ends (on), alert in the background (off), sound with the alert (off). Stored in UserDefaults, nothing in the store. **Alerts follow C2:** off by default; a quiet line on the timer screen ("Alerts when a phase ends are off. Turn on"); a Focus timer alerts switch in Settings, Reminders; the permission question is asked only when the switch is first turned on. The notification is one local notification for the phase now running, removed on pause, stop or skip; its words are generic ("Focus time is up. A break could be nice.") and never name the task. **Session log:** two fields on `TaskItem`, `focusSessions` and `focusMinutes`, both defaulted so there is no store migration; a task or step shows "2 focus sessions, 50 minutes" once it has one. A session counts only when its time runs all the way out; stopping early records nothing and says nothing. No goals, streaks or totals across tasks. Export carries both fields (optional, so older files import). Demo: "Reply to one message" has two sessions. Help (Plan) mentions it. **Deviation from the plan:** the plan listed an optional Live Activity; it is not in this patch (it needs the widget extension, ActivityKit and a new Info.plist key, and I cannot check any of it), so it is Patch 21b. **Not done:** a timer killed by iOS while the app is closed is lost (the alert still arrives, but no session is recorded); the notification covers only the phase running now, so with auto-start on and the app closed you get one alert, not a chain. **Size:** about 600 changed lines in 8 files, over the M guide; splitting it would have left a timer without its settings or log. New views live in `NextHourChecklistView.swift` again so the project file needs no change. **Needs a real check:** the alert arriving with the app in the background, pause and resume across a lock, the bar reopening the screen, and the layout at large text sizes. Checked only with a Swift syntax parser, not compiled.

- **7 Nov 2026 (30):** Patch 20 written: widget editing on the tab itself (point 14). **Entry:** a quiet **Customise** button under the widgets on Plan, Bridge and Thread, and the long-press menu's last item (it used to open the Customise sheet). Move up, Move down and Hide stay in the long-press menu as the way to do it without dragging. **While editing:** the cards wiggle a little (off when Reduce Motion is on), their content is dimmed and cannot be opened, and each card has a minus (hide), a resize button where the widget has a half-width form, and a grip mark. **Drag** a card onto another to move it: it lands after the one it was dropped on when dragging down and before it when dragging up, the target gets an outline, and the order changes with a light haptic. Hidden widgets keep their slots, exactly as the old list did. **Hidden tray:** while editing, the More row is replaced by a Hidden row of buttons (plus icon and the widget's name) to add them back. **Size:** only widgets that are half width by default (Trigger windows, Appointments, Recovery, Who I'm doing this for and so on, as `WidgetID.isHalf` already decides, including the 16-character title rule) get the resize button, because the full-width ones were never designed to be narrow and I cannot check how they look. A new per-tab key `widgetFull.<tab>` stores the ones made full width; nothing changes for existing saved layouts. At accessibility text sizes everything is full width and the resize button is hidden, as before. **Leaving:** Done is in the navigation bar and also at the bottom next to Reset (Reset asks first and clears order, hidden and widths). VoiceOver gets Move up, Move down, Hide and the resize action on each card. **Kept:** Settings, Layout, Customise widgets still has the list with toggles and drag handles, and its Reset now clears widths too. **Not done:** dragging a card into the Hidden row (the minus does that); moving a widget to another tab; making a full-width widget half width. **Needs a real check:** I could not run any of this, so these are the parts to try first on a device: the drag and drop (long press then drag on the dimmed card, including the auto-scroll near the screen edge), the Done button appearing in the navigation bar (it is declared inside the stack, which I believe propagates to the bar; the Done at the bottom is the fallback if it does not), and the wiggle. Checked only with a Swift syntax parser, not compiled.

- **7 Nov 2026 (29):** Patches 17 and 18 confirmed pushed (HEAD was `03b920d`). Patch 19 written: the last of the task fields. **Model:** three fields on `TaskItem`, all with defaults, so no store migration: `status` (Not started, Started, Set aside for now), `energy` (Not set, A little, Some, A lot) and `firstStep` (one line of text). **Deviation from the plan:** the plan said "Parked"; the app says **Set aside for now**, which reads as relief rather than failure. **Status:** a task counts as Started when you say so or as soon as one of its steps is ticked, with no manual step. A set-aside task moves to a last group, "Set aside for now", dimmed, with its steps folded away; Now and the Tasks widget leave it out, like a waiting task. Ticking a set-aside task off still works. **Energy:** a small "Needs a little / some / a lot of energy" line on the card, and a filter in the Tasks screen's menu (Everything, Some energy or less, Only a little energy). Tasks with no energy set are always shown, and a line above the list says what the filter is doing and has a Show everything button. The filter is not remembered: it resets when the screen is reopened, so nothing stays hidden by accident. **First tiny step:** its own one-line field, shown on the card as "Start with: ..." until the task is started; separate from steps so it can be one line. **Snooze:** swipe right on a task (or long-press) for Move to tomorrow or Set aside; the editor has a Move to tomorrow button. It sets the day to tomorrow, shows as "Tomorrow", and the task returns to Today on its own when the day arrives. Nothing is marked as late. Swipe left still deletes. Export carries `status`, `energy` and `firstStep` (optional, so older files import). Demo: energy tags on three tasks, a first step on the call, and "Sort out the old paperwork" set aside. Help (Plan) mentions it. **Size:** about 250 changed lines in 6 files, larger than S, because the energy filter and the row actions came with it. **Not done:** recurring tasks and a priority or category field from the original task idea; they are not in the patch list, so say if you want them. Checked here only with a Swift syntax parser, not compiled.

- **7 Nov 2026 (28):** Patch 18 written: tasks that wait on other tasks. **Model:** `blockedByIDs` on `TaskItem` (a list, default empty, so no store migration). A task is blocked while any task it waits on is still open; a deleted blocker is ignored. **List:** a fifth group, "Waiting on something else", after No date. A blocked task is shown dimmed with an hourglass instead of a tick, a line "Waiting on Call to book the appointment" (or "and 2 more"), and its steps folded away. It still opens in the editor. **Unlocking is quiet:** when the last blocker is ticked off the task simply moves into its usual group, with the list's normal animation, and nothing announces it. **Editor:** a "Waiting on" section lists what it is waiting on (swipe to remove; a done blocker stays listed, greyed, until removed) and a menu offers other open tasks. Steps are never offered, and a task that already waits on this one, directly or through others, is left out so two tasks cannot wait on each other. **Now and the Plan widget** show only what can be done now: blocked tasks are left out of the first four and of the "to do" count, and an all-waiting list says "Nothing to do right now." instead of "All ticked off." Export carries `blockedByIDs` (optional, so older files import). Demo: "Bring the form along" waits on "Call to book the appointment". Help (Plan) mentions it. **Not done:** sub-steps of a blocked task cannot wait on anything; only whole tasks can. Not compiled here.
- **7 Nov 2026 (27):** Patch 17 written: steps on tasks. **Model:** a step is a `TaskItem` with a `parentID` (the id of its task), plus a `subtasksCollapsed` flag on the task. Both have defaults, so there is still no store migration, and ticking, ordering, export and import all reuse what tasks already do. `TaskItem.topLevel` is what the list, Now and the Plan widget show, so steps never appear as tasks of their own; a step whose task has gone is treated as a task so it cannot vanish. **Card:** a task with steps shows "2 of 5 steps" and a thin bar (no percentage, nothing red, nothing when all are done beyond the full bar), a chevron to fold the steps away, and the steps themselves underneath; tap a step to tick it. Ticking every step does **not** tick the task, because finishing is your call. A done task hides its steps. **Editor:** a Steps section with a field to add one, tap to reword, swipe to delete, a labelled Reorder, and the tick. A blank task that has steps is kept when the editor closes. Deleting a task, clearing done tasks or swiping removes its steps too. Export carries `parentID` and `subtasksCollapsed` (optional, so older files import). **Known quirk:** the data screen's Tasks count includes steps. Demo: "Reply to one message" has three steps, one done. Help (Plan) mentions steps. Not compiled here.
- **7 Nov 2026 (26):** Patch 14b written: voice notes on messages. **Recording:** the composer has a Record a voice note button; it asks for the microphone the first time, shows the time while recording, stops by itself at five minutes, and offers Record again and Remove after. A recording with nothing in it is thrown away, and one that is never saved is deleted when the sheet closes. A message can be text, a voice note, or both. **Playing:** each card on the log has a play button with the length, and the same is in the message sheet, which also has Share voice note (so it can go over Discord or anywhere else). **Sending:** through Messages the recording is attached to the text (the Messages sheet is given the file; iMessage and SMS decide what they accept), and Send again does the same. Discord cannot take an attachment from the app, so it only opens the chat and the Share button is the way. **Storage:** files live in Application Support/VoiceNotes with the same file protection as the database; deleting a message, swiping, or Clear everything removes its file. Export and import carry only the file name, not the audio, so an imported message says the voice note is not on this device; real backups of audio belong to Patch 33. **Open for Patches 34 and 35:** voice files are not covered by field-level encryption yet (D5). The microphone key is added to both build configurations, the Privacy page gets a Microphone line, Help is updated, and the widget shows "Voice note" when the latest message has no text. The demo has no voice note, because audio cannot be seeded. Not compiled here, and recording and playback need a real device or the simulator's microphone to check.
- **7 Nov 2026 (25):** D4 to D8 answered (see the table); Patch 14 split in two because it came to about 600 lines. **What `main` shows about the message log:** the original screen had the composer on the same screen, with the "About" picker, the text box and the Save and Send buttons under the list, so writing to someone and sending it was one screen. The later "separate settings from information" commit turned the log into a read-only list and moved the composer behind a sheet, which is the loss you felt. Nothing on `main` ever recorded or played audio: `audioFileName` was an unused field. So quick sending is a regression to undo and voice notes are new, and per-person history was only ever a contact name on each row. **Patch 14a:** a "Write to" row of your contacts at the top of the log opens the composer already set to that person, with the keyboard up; the plus does the same for whoever the log is filtered to. A small menu narrows the log to one person (only people who have something in it are listed). Tapping a message now offers Send again (Messages, or Open Discord) and Copy text, besides Delete. The Message log widget has a Write button under it and an honest caption. `ThreadMessageComposer` is no longer private so the widget can open it. The demo's one message is now tied to Sam. **Patch 14b (next):** voice notes. Help text, CHANGELOG and this file are updated. Not compiled here.

- **7 Nov 2026 (24):** Patch 16 written: task timing. Two new fields on `TaskItem` (`dueKind`, `dueDate`), both with defaults so no store migration is needed. The choices are No date, As soon as I can, Today, This week, This month, Someday, or a particular day, picked in a new "When" section of the task sheet. For the loose choices the stored date is the last moment of that day, week or month, so a plan that has passed can be told from one still ahead. The list is grouped Today, This week, Later and No date (Waiting arrives with dependencies in Patch 18). As soon as I can and a particular day that has arrived sit in Today. **Overdue is quiet:** a plan whose time has passed moves into Today with a plain line such as "Carried over from this week" or "Planned for Tue 4 Nov"; no red, no "late", no count. Reorder works within a group and leaves the other groups alone. Now's card and the Plan widget show open tasks in the same order. Export carries the two fields (optional, so older files import). The demo has a task for today and one for this week. Not compiled here.
- **7 Nov 2026 (23):** Patch 15 written; Patch 14 is skipped for now because it needs your answer to D8. **Tasks:** a new `TaskItem` model (title, notes, done, created and completed dates, order, an optional Reminders link). Every field after the title has a default, so Patches 16 to 19 can add due dates, subtasks, dependencies and status without a store migration. **No migration plan was added:** adding a model to an existing SwiftData store is an automatic lightweight change, and a versioned plan is only worth writing once a field changes shape. If you would rather have one first, say so. **Carry-over:** the first launch after this copies any "Next hour only" rows into tasks, saves them, marks itself done and removes the old rows; if the saved store could not open it does nothing. `NextHourItem` stays in the schema, unused, until a later release removes it. **Screens:** Plan gains a Tasks widget (after Appointments in the default order; saved layouts get it at the end) and a classic-layout tile; the Tasks screen has tap to edit, the plus, a quick add bar, a labelled Reorder, swipe or long-press delete, a Done section with Clear done, and Import from Reminders. Now's "Next hour only" card is now a Tasks card showing the first four open tasks, with quick add and the header opening the list. **Dropped:** the old bell on the add row that also created a Reminders item; Reminders is import and tick-off only, per D2's recommendation. The Reminders permission text and Privacy page say so. Export, import, clear all and the data counts include tasks (the export key is optional, so older files still import). Demo data seeds three tasks. The new views live in `NextHourChecklistView.swift` so the project file needs no change; a rename can wait for a tidy-up patch. The web demo (`DemoApp.tsx`) still says "Next hour only" and is left alone while the web demo is deferred. Not compiled here.
- **7 Nov 2026 (22):** Patch 13b written: the last screens on the old pattern, and the old pattern is gone. **Bridge draft:** tap an item to reword it, the plus adds, Delete is in the sheet and the swipe and long-press menu; ticking off stays on the card; the small compose sheet and the manage list are removed, and an "Already brought up" switch is in the item sheet. **Session prep:** tap the notes card to write in it. **Post-session notes:** tap a past session to write its notes in one sheet (the read page is removed, so it is one tap, not two); a session whose notes were opened and left blank no longer says "Has notes". **Feedback-loop diagrams:** the plus adds a diagram and opens it, swipe or long-press deletes, the manage list is removed. A diagram keeps a plain **Edit** button on its own page, on purpose: dragging nodes cannot share a screen with just looking at it, and the rebuild in Patches 26 to 28 will revisit it. **Journal entry preview:** tapping the entry opens the editor, and a pencil replaces the Edit text button. `EditToolbarButton` and `EditorSheet` are deleted from `ContentView.swift`; nothing references them. **Open:** the prep notes screen still creates an empty entry every time it opens, which is older behaviour I left alone. Not compiled here.
- **7 Nov 2026 (21):** Patch 13a written: the screens left on the old pattern in Now and Recovery. **Affirmations** and **De-escalation scripts** are lists of cards: tap one to rewrite it, the plus adds, Delete is in the sheet and the long-press menu, and a labelled Reorder shows with two or more because the order is the order Now steps through. Browse suggestions is a button under the affirmations (and under the empty state). **Who I'm doing this for** has a card per line under its two headings; the plus is a small menu (someone, or a reason) and each heading has its own add button; no Reorder, because order means nothing there. **Before tracking** (Streaks) is tap to change. `AffirmationsEditorView`, `DeEscalationScriptsEditorView` and `RecoveryMotivationsEditorView` are removed. History was rewritten afterwards to drop Claude co-author trailers; hashes quoted earlier in this file are from before that. **Still left for 13b:** Bridge (Appointment prep, Post-session notes, Bridge draft list, Feedback loop diagrams) and the Edit button on the Journal entry preview, then removing `EditToolbarButton` and `EditorSheet`. Not compiled here.
- **7 Nov 2026 (20):** Patch 12d written: Appointments, the last of the Plan screens. One screen and no Edit button. Tap an empty calendar day to schedule a session, tap a day with a session (or its row in the list) to move or cancel it, and the plus schedules any date; the schedule sheet now has a date picker so the plus and the calendar share it. Cancelling is inside the session sheet and in the row's long-press menu. The typical cadence is a stepper on the screen, and Remove all (with its question) stays in the All sessions card. `AppointmentEditorView` is removed. **Moved to Patch 13:** De-escalation scripts and Affirmations are reached from Plan but their files live in `Views/Now`, so they go with Now; Patch 13 also removes `EditToolbarButton` and `EditorSheet` when the last screen has moved. Patch 12 is complete once 12a to 12d are pasted. Not compiled here.
- **7 Nov 2026 (19):** Patch 12c written: Decision-fatigue presets. Tap an option to edit it, tap a category's name to rename it, the plus in the bar adds a category, and an "Add an option" button inside each card adds an option. Delete is inside each sheet, and an option's long-press menu has it too. A small play button on an option with steps runs it. Steps inside an option have a labelled Reorder in the section header, and the red minus buttons are hidden while you reorder. Blank categories and options left behind are removed. The manage list and the second `EditButton` are gone. Categories and options themselves still cannot be reordered, same as before. Not compiled here.
- **7 Nov 2026 (18):** Patch 12b written: Contacts and Grounding tools. Both are now a List of cards so dragging to reorder works; a new `anchorCardRow()` helper in `ContentView.swift` strips the row chrome so they still look like cards. Tap a card to edit it, the plus adds (on Contacts the plus is a small menu: pick from Contacts, or add manually), and Delete is inside the sheet and in the long-press menu. **Reorder** is a labelled button that shows when there are two or more, because order matters on both screens: the top two contacts are the quick buttons on Now, and the tools show in this order on Now. A tool with written steps keeps a small play button on its card, because running it is using it, not editing it. Someone picked from the system Contacts app opens in the editor once the picker has closed. A contact or tool added and left blank is removed. "Who's awake right now" stays at the top of Contacts, outside the rows you can reorder. `ContactsEditorView` and `GroundingToolsEditorView` (the manage lists) are removed. Not compiled here.
- **7 Nov 2026 (17):** Patch 12a written: the Safety plan and Trigger windows screens use the new edit pattern, the first Plan screens to move. Patch 12 as one patch came to about 1,400 changed lines, over the size limit for a patch, so it is split into 12a to 12d, pasted in order. **Safety plan:** each of the four cards opens its own section in a sheet. There is nothing to add or delete, so there is no plus, no Edit button and no separate form. **Trigger windows:** tap a card to open it, the plus adds one, and Delete is inside the sheet (with a question first) and in the card's long-press menu. Deleting happens after the sheet has closed, and a window deleted that way no longer leaves its reminders behind, which it did before. `TriggerWindowEditorView` stays because Recovery opens it too, and gains an optional `onDelete`. `SafetyPlanEditorView` and the trigger-window manage list are removed; the file names stay so the project file needs no change. Patches 10 and 11 confirmed pushed (HEAD was `320930d`). Not compiled here.
- **7 Nov 2026 (16):** Patch 11 written: the four Thread screens use the new edit pattern. No Edit buttons, no manage-list sheets, no second Edit button. A plus adds on each screen. Tapping a card opens that item in one sheet: a draft, a support day (both editable), a future note (its text only if it has unlocked; a locked note shows just its date) or a logged message (read only, because it is a record of what was said). Each sheet has a Delete that asks first, and the card's long-press menu has Delete too. Deleting happens after the sheet has closed, so a sheet never reads something that is already gone. Locked notes can now be deleted by tapping them, which the old Edit list did but the card itself did not allow. The empty drafts left behind by closing a new draft without writing anything are removed. The extra full-width buttons at the bottom of each list are gone because the plus does that job. `UnsentDraftView` (the read page for one draft) is removed; the editor shows the same fields. Patch 14 can add resend and copy to the message sheet. Patches 8 and 9 confirmed pushed. Not compiled here.
- **7 Nov 2026 (15):** Patch 10 written. Nothing changes on screen yet. `ContentView.swift` gains the pieces of the new edit pattern: `AddToolbarButton` (a plus), `ReorderToolbarButton` (a text button that says Reorder, then Done), `TapToEditRow` (the whole row opens its editor), `ItemEditorSheet` (one item in one sheet, with an optional Delete that asks first) and a `.anchorDeletable` modifier (swipe, and the same action on long-press). The older `EditToolbarButton` and `EditorSheet` stay until Patches 11 to 13 have moved every screen. Deletion inside a reorder session uses swipe only, so reorder mode shows handles and no red minus buttons. Not compiled here.
- **7 Nov 2026 (14):** Patch 9 written: the Journal switch gains Year. Twelve small months, a filled square for each day with something on it (darker if more than one thing), tap a month to open it in Month view. Deliberately plain: no colour for better or worse and no totals, so it cannot turn into a streak chart. Year arrows stop at the earliest entry and this year; future months are dimmed. Patches 6 and 7 confirmed pushed (`7859612`, `08b0dcc`). **Not done:** the optional lenses (entries only, check-ins only, by origin); the plan said "later". Not compiled here.
- **7 Nov 2026 (13):** Patch 8 written: a Days / Month switch at the top of the Journal (remembered between launches). Month is a calendar grid, one dot per entry (up to three) and a small square for a check-in, with no colour or score. Tapping a day that has something on it switches to Days and scrolls to that day. Month arrows stop at the earliest entry and at this month; "Jump to today" returns to the current month. Search still applies. The month view is a struct inside `JournalView.swift`, so there is no project file change. **Not done:** swiping between months. Not compiled here.
- **7 Nov 2026 (12):** D9 answered: option 1, keep polishing in Swift for now, so Patches 7 to 9 go ahead. Patch 7 written: the editor has one calm writing surface. The inline prompt card and the six-icon toolbar are gone. A single Add button under the text opens a labelled sheet (Journaling Suggestions, Photo, Drawing, Prompt for me, Formatting); Preview moved into a menu in the top bar; the Suggestions screen is now titled Journaling Suggestions; a one-time "Got it" hint points at Add. **Deviation from the plan:** no Cancel button, because entries save as you type and a Cancel would not undo that. Done stays on the right. Also fixed: "Use this" on a prompt used to replace the whole entry text; it now appends. Not compiled here.
- **7 Nov 2026 (11):** Patch 6 written: the Journal timeline is newest day first and newest entry first within a day, and a "Jump to today" action in the toolbar menu scrolls back to the top, which is where today sits. Patches 2 to 5 confirmed pushed (HEAD was `1a95f15`); their build is still unconfirmed. Not compiled here.
- **7 Nov 2026 (10):** Patch 5 written: the check-in `Form` is now a scrolling stack of `Anchor.Card`s, each slider with an icon and gentle end labels ("running on empty" to "fully charged" and so on); the mascot's mood follows the sliders (quiet day, gentle, encouraging; picture only, nothing stored, scored or compared) and its line is re-picked from the reviewed pool when the mood changes; each optional question has its own mascot mood. **Not done:** the calm "done" moment with a mascot line, because it needs a new reviewed line pool and trigger (the mascot never gets generated dialogue). Added as an open item for Patch 5b.
- **7 Nov 2026 (9):** Patch 4 written: `CheckInPrompt` struct (question, detail, starters), a "Need a start?" chip row that appends a starter to the answer, and a scrolling question screen with pinned buttons so it fits an SE-size screen. The same prompt data can later feed the Journal editor and the guide.
- **7 Nov 2026 (8):** Patch 1 confirmed pushed (`41a858e`). This plan moved into the repo as `ANCHOR_PATCH_PLAN.md` (Patch 3) and now carries the standing instructions for Claude at the top. Edit it here, not in the Claude Doc. Patch 3 written: both check-in actions are pinned in a bottom bar.
- **7 Nov 2026 (7):** Patches are delivered as a `.sh` text file whose contents are pasted into Terminal, not run (no shebang or `set -e`). Patch 1 re-sent that way. Patch 2 written: titles, `WidgetBig` and `WidgetCaption` wrap to three lines then shrink, `TileButtonLabel` loses its fixed height, half-width is limited to titles of 16 characters or fewer, and nothing pairs up at accessibility text sizes.
- **7 Nov 2026 (6):** Patch 1 written: one `ElapsedFormat` helper in `WidgetDataStore.swift` (in both targets), used across Recovery screens, share text, export headline and both counter widgets, which now refresh every 15 minutes in the first hour, hourly in the first day, then daily. Durations of a day or more still read in days (assumption; say if you want months and years). `CHANGELOG.md` created.
- **7 Nov 2026 (3):** From your comments: patches are now delivered as macOS shell commands (commit and push included, run at repo root). Android and the web demo are deferred as "eventually planned", with a possible move to React Native; the answer to your tooling question is under point 28.

* **7 Nov 2026 (4):** Bridge and Thread ideas reviewed (Appendix A). Medication and treatment framing is out of scope for the app's wording; Patch 29 is done.

- **7 Nov 2026 (5):** Added Appendix C: relationship reminders (T3) approved with five types; opt-in-by-default principle with a gentle discoverability pattern; editable sections for Safety plan, Boundaries list and Person pages (new Patch 30a).

* **7 Nov 2026 (2):** Patch 0 resolved. `TabWidgets.swift` (666 lines) and `WidgetCustomisation.swift` (328 lines) are now in the repo and every previously undefined symbol is defined. Points 10, 11, 12 and 14 updated with real findings. Decision D1 closed. Plan moved into a Claude Doc.
* **7 Nov 2026 (1):** First version, written from the code on `v2-recovery` (`ca78aaa`).

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
6. This document's Progress table and change log are updated.

### 0.4 Decisions needed

| # | Decision | Affects | My recommendation | Status |
| --- | --- | --- | --- | --- |
| D1 | Where is the missing widget-layout file? | Patch 0 | — | ✅ Closed |
| D2 | Keep the Reminders (EventKit) import from the old "Next Hour" list? | Patch 15 | Keep as an optional import on the task list | ✅ Assumed, 7 Nov 2026: Patch 15 follows the recommendation (import only). Say if you want it changed. |
| D3 | Demo strategy (point 25): shared-data rebuild with parity checks, or cross-platform rewrite? | Patches 49–50, 54 | Decide with D4 | Open |
| D4 | Android: real goal or "nice to know"? | Point 28, D3, encryption (Patches 33–35) | Finish iOS first, decide *before* Patch 49 | ✅ Closed 7 Nov 2026: planned, but far in the future. Treat it as if it does not exist for now; nothing in the Swift patches waits on it. |
| D5 | Encryption approach (point 20) | Patches 33–35 | Field-level encryption, Keychain key, encrypted exports | ✅ Closed 7 Nov 2026: option b (field-level encryption, Keychain key, encrypted exports). The earlier idea of revisiting this for React Native is dropped, since D4 is parked. Voice note files (Patch 14b) are not covered by field-level encryption of text fields; Patches 34 and 35 must decide how to protect them. |
| D6 | Feedback loops: loops only, or loops plus free systems maps? | Patches 26–28 | Both, loops by default | ✅ Closed 7 Nov 2026: both, loops by default. |
| D7 | Point 27: unlisted page named `/demo-preview`, hidden from nav/sitemap, `noindex`? (`/demo` already exists) | Patch 51 | Yes | ✅ Closed 7 Nov 2026: yes to unlisted and `noindex`, but the page advertises the TestFlight beta sign-ups, so it is named and framed around that, not around a demo. Working route name: `/beta` (change it if you prefer another). |
| D8 | Message log: what was its "main function" for you — voice notes, quick sending, or per-person history? | Patch 14 | — | ✅ Closed 7 Nov 2026: all three. Checked `main` first (see the change log, entry 25): it explains the quick sending, and voice notes never existed, so 14a and 14b build all three. |
| D10 | Where does sleep live? | SL1, SL2 | A Sleep screen reached from a Plan widget (added hidden, so nobody sees it unless they add it), plus quiet rows in the Journal timeline. Not a sixth tab. | Open |
| D11 | Apple Health: copy a nightly summary into Anchor's own store, or read Health live each time? | SL3, 31, 34 to 38, 39 | Copy one summary per night, with a clear "Remove imported sleep" control. Export, showcase mode, the data viewer and encryption all need the data to be in the store; live reads cannot offer that. | Open |
| D12 | Write manual nights back into Apple Health (the tester's "contribute to that data")? | SL4 | Yes, as its own switch, off by default, separate from reading. Can wait until SL3 has been used for a while. | Open |
| D13 | When does sleep ship? | SL1 to SL5 | SL1 and SL2 are local and manual and need no privacy change, so they can go in the current release. SL3 and SL4 add a HealthKit capability and change the privacy page and App Store answers, so keep them with the v2 release. | Open |
| D14 | What does the app show about sleep? | SL1 to SL5 | Times, time asleep, an optional feel (Restful, Okay, Rough, your word for it) and a note. No sleep score, no goal hours, no "sleep debt", no stages in the first version, and no correlation views. | Open |
| D9 | How long to keep investing in Swift UI polish before migrating to React Native? Polish-only patches (5, 7, 8–9) would be rewritten. | Phases B–D | Do bug fixes and behaviour first (1–4, 6, 10–14). Pause polish-only patches once a migration date exists. | ✅ Closed 7 Nov 2026: keep polishing in Swift for now. Revisit when a migration date exists. |

**Update, 7 Nov 2026:** D3 and D4 answered in a comment. Android is wanted eventually, via a move from Swift to React Native, with demo and Android builds updating automatically. Both are parked as "eventually planned": Patches 49–50 and 54 are deferred. D5 should be revisited once the migration is decided (see point 28).

---

## 1. Your 28 points, outlined

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
4. **Output:** a clean image or PDF for a clinician, plus a link into Bridge's export (point 19). This rebuilds `FeedbackLoopDiagramView` (367 lines). The stored `graphJSON` stays, with a version field and a `kind` (loop/map) added.

### Help, privacy, data (16, 17, 20, 21)

**16. A fuller guide.** Today: a short onboarding tour (`OnboardingTourView`, 85 lines) and per-screen `HelpTopic`s. *Proposal:* one content registry (`GuideEntry`: id, screen, title, what it is, how to use it, tips) powering (a) a full "Take the tour" walkthrough in Settings, ordered by tab, (b) the existing "?" button opening the entry for the current screen, and (c) website feature pages and docs generated from the same data so they cannot drift. Content is written tab by tab in small patches.

**17. Showcase mode (hide real data behind a passcode, show demo data).**

- Settings → "Showcase mode". Setup asks for a **separate showcase passcode** (salted hash in Keychain) and offers device Face ID/passcode as the way back.
- Turning on: swap to `DemoMode.makeContainer()` (in-memory, seeded), **disable the normal app lock**, and clear anything that leaks real data outside the store: the widget snapshot in the App Group (`WidgetDataStore`: contact names and numbers), pending notifications and their wording, the app-switcher snapshot, and the share/export actions (disabled).
- The real store file is **not opened at all** while on.
- Turning off: showcase passcode (or device authentication), then restore the real container and widget data.
- The demo fixture must cover *every* feature, so it becomes one seed definition (JSON) shared by showcase mode, UI tests and the website demo. Part of the Definition of Done.
- *Decide:* forgotten showcase passcode (recommend: device authentication always works) and whether the mode survives a force-quit (recommend yes).

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
5. **Website viewer page (optional):** loads a chosen export entirely client-side (no network calls, no storage, no caching, strict CSP with `connect-src 'none'`), using the same viewer code. Worth it only if you want a way to view without trusting an HTML attachment. *Verify before building:* WebCrypto when opening a local file on iOS (Files/Safari), mail clients that block HTML attachments (offer a ZIP and PDF fallback), and docx library size.

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
| **26** | Feedback loops 1: loop builder (ring layout, polarity, reinforcing/balancing) | 15 | M | ⬜ |
| **27** | Feedback loops 2: map mode (pan/zoom, undo, connect handles) | 15 | M | ⬜ |
| **28** | Feedback loops 3: templates, export to image/PDF | 15 | S | ⬜ |
| **29** | Bridge/Thread ideas review: you pick from Appendix A | 18 | S | ⬜ |
| **30+** | Approved Bridge/Thread ideas, one patch each | 18 | per idea | ⬜ |

**Update, 7 Nov 2026:** Patch 29 (the ideas review) is done. Patch 30+ is now: B1, B2, B3, B8, T1 (light), T2, T5, T6, T7 and a Personal goals feature in place of B7, grouped into small patches of one or two ideas each. B4 and B6 are held; B5 is dropped for now; T4 is covered by Patches 36–38.

### Phase E2 — Sleep journal (point 29)

Planned, not scheduled. Needs your answers to D10 to D14 first. These can be pulled forward any time; SL1 and SL2 do not depend on anything unbuilt, SL5 does.

| Patch | Contents | Points | Size | Status |
| --- | --- | --- | --- | --- |
| **SL1** | `SleepEntry` model; Log sleep sheet (bed, wake, time asleep, optional feel and note); Sleep screen (nights newest first, a month of dots, one plain line on the usual range, no score); Plan widget added hidden; DTO, export, import, Clear all data, data counts, demo, Help, CHANGELOG | 29 | M | ⬜ |
| **SL2** | Weaving it in, all optional: Journal timeline row and month mark, optional check-in question, Now morning card, optional morning reminder in Settings, Reminders | 29 | M | ⬜ |
| **SL3** | Apple Health, read: capability, entitlement and usage string, Connect, import a summary per night, dedupe, typed wins, Disconnect, Remove imported sleep, neutral empty state; privacy page and `docs/SLEEP.md` updated | 29 | M | ⬜ |
| **SL4** | Apple Health, write: its own switch, off by default; typed nights saved as Anchor's own samples, never re-imported, removed when the night is deleted | 29 | S | ⬜ |
| **SL5** | Bridge: Sleep since your last session on session prep; Sleep category in the export picker, CSV and viewer chart; data viewer row. Done after Patches 31 and 36 to 38. **SL5a (optional, earlier):** a Sleep section in the current PDF export | 29 | M | ⬜ |

### Phase F — Data, privacy, security

| Patch | Contents | Points | Size | Status |
| --- | --- | --- | --- | --- |
| **31** | Data viewer: per-type lists, read-only detail, re-authentication | 21 | M | ⬜ |
| **32** | About screen | 22 | S | ⬜ |
| **33** | Encrypted export/import (`.anchorbackup`), plaintext import kept | 20 | M | ⬜ |
| **34** | At-rest field encryption: keys, recovery key | 20 | M | ⬜ |
| **35** | At-rest field encryption: migration, widget snapshot hardening | 20 | M | ⬜ |
| **36** | Bridge export: picker and recipient labels | 19 | M | ⬜ |
| **37** | Bridge export: self-contained HTML viewer, PDF/CSV, password encryption | 19 | M | ⬜ |
| **38** | Bridge export: Word export, optional website viewer | 19 | M | ⬜ |
| **39** | Showcase mode 1: shared demo seed, container swap, lock disabled | 17 | M | ⬜ |
| **40** | Showcase mode 2: passcode, leak sweep, exit flow | 17 | M | ⬜ |

### Phase G — Guide, audit, docs

| Patch | Contents | Points | Size | Status |
| --- | --- | --- | --- | --- |
| **41** | Guide registry, full tour, "?" on every screen | 16 | M | ⬜ |
| **42** | Guide content: Now and Plan (incl. Tasks, Routines, Lists) | 16 | M | ⬜ |
| **43** | Guide content: Journal, Bridge, Thread, Settings, Recovery | 16 | M | ⬜ |
| **44** | Audit 1: Now, Plan, Recovery | 12 | M | ⬜ |
| **45** | Audit 2: Journal, Bridge, Thread, Settings, widgets, notifications (appointment reminders, escalation) | 12 | M | ⬜ |
| **46** | Docs and coherence: `STATUS.md`, `CHANGELOG.md`, terminology, in-app copy | 23 | M | ⬜ |

### Phase H — Website, demo, video

| Patch | Contents | Points | Size | Status |
| --- | --- | --- | --- | --- |
| **47** | Website: Features and Philosophy pages | 24 | M | ⬜ |
| **48** | Website: About, FAQ, Privacy update | 24 | S | ⬜ |
| **49** | Demo route A: shared seed and guide data feed the React demo | 25 | M | ⬜ |
| **50** | Demo route C: CI screenshot flow and parity check | 25 | M | ⬜ |
| **51** | Unlisted TestFlight beta sign-up page (`/beta`, noindex, not in nav or sitemap) | 27 | S | ⬜ |
| **52** | Update existing Remotion promo; single source | 26 | M | ⬜ |
| **53** | Long "full tour" video, split into per-tab scenes | 26 | L (split) | ⬜ |
| **54** | Android decision write-up, optional prototype spike | 28 | S | ⬜ |

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
- **Maybe, decide later:** B4 (session actions into Tasks) and B6 (one-screen summary; needs care in its wording and in what it leaves out).
- **Reframed:** B7 becomes "Personal goals": your own goals and notes, nothing framed as treatment. B5 (medication notes) is on hold. It only returns if you settle on a safe shape for it.
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

**Rules:** at most one per day across everyone, no repeats or snooze chains, nothing while Quiet Room is on, no "you haven't…" wording, nothing counted or scored, "Not now" is free and logged nowhere. Nothing is inferred from behaviour and the app never suggests removing someone. Tapping opens a message pre-filled from your T2 starters. **Build order:** the first three types first. The last two depend on trigger windows and appointments being set up (and on appointment reminders being wired, point 12).

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

Patch **26** (Feedback loops 1: loop builder), once Patches 1 to 25 build. Patch 29 (the Bridge/Thread ideas review) is already done, so Phase E continues 26 to 28, then 30a. D4 to D9 are answered. D10 to D14 (the sleep journal) are open and block only SL1 to SL5, so Patches 26 onward carry on without them.
