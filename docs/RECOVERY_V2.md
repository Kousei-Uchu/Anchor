# Recovery (v2)

An optional area for day counters, motivations, a daily pledge and evening review, and a craving tool. It is free, local, and has no account or community. Its home is under Plan, in the Recovery row, and its reminders (daily pledge, evening review, milestones) are switched on in Settings (the gear on Plan or on Recovery home), under Recovery, which only appears once a counter exists. Counter-level options (name, savings, lock-screen label) are in the counter's own settings gear. Once a counter exists, Recovery also shows up on Now and in Bridge's session prep (see "Where it shows up").

Ship this after v1 is approved. It adds data the v1 privacy policy does not describe, so keep it on its own branch (for example `v2-recovery`) and do not merge it into the release you submit first.

## What it does
- **Counters.** Several at once, each with its own name, start date and day-count mode: "current run and total days" (a slip starts a new run, the total stays) or "classic streak" (a slip resets to zero). Milestones at 1, 3, 7, 14, 21, 30, 60, 90, 120, 180, 270 days, then every year.
- **Savings.** An optional estimate per counter, in the user's currency, following that counter's mode.
- **Who I'm doing this for.** People and reasons the user writes. Nothing is pre-filled. Shown on the pledge and the craving tool.
- **Daily pledge and evening review.** The pledge is one tap. The review is three optional free-text boxes. No rating, no score.
- **Riding out an urge.** A 5 to 20 minute timer with a slow breathing circle, the user's motivations, and their existing grounding tools. Optionally saves a line to the journal.
- **Discreet by default.** Widgets and reminders use a generic label ("Your counter", "A quiet moment for yourself?") unless the user turns on "Show this name outside the app" for that counter.

## The counter screen
Each counter opens in tabs: **Summary, Savings, Calendar, Urges, Reasons, Today**.
- **Summary** is six swipeable pages: live time on this run (a solid centre circle with the counter's name inside concentric rings for days, hours, minutes and seconds, each labelled and driven by continuous elapsed time so the arcs glide rather than step; the days ring fills toward the next milestone), progress this month (a dot for every day), total days with whole weekends, fresh starts and first start date, the streak record against your personal best, your current streak, and your start date. Share, Log urge and Start again sit underneath.
- **Calendar** shows a month at a time. Sober days are joined pills, a day you started again is a circled cross, and a "Streaks" row opens the history.
- **Streaks and Times.** The streak list shows every run with a bar against the longest one and a star on the best. Times lists how many times it happened on each slip day, and has a "before tracking" reference number.
- **Urges.** Log an urge with when, how strong it felt and a note, then optionally go straight into "riding out an urge". The tab shows this week, this month and the last 14 days.
- **Days are whole elapsed days** (24 hour periods from the start time), like a stopwatch, so "My streak is 0 days" means less than 24 hours.

### Deliberately different from other trackers
- Anchor's own colours, icons and wording, and no copied artwork or text.
- It says "Start again" and "Fresh starts", not "Reset" and "Comebacks".
- No community, no pausing a counter, no reordering of the summary pages. These can be added later.
- Times and urges are the user's own record and are never scored, ranked or compared.

## Where it shows up
Recovery only appears outside its own pages once the user has added a counter. Nobody who never uses it sees any of this.
- **Now.** A Recovery card after Quick contacts: each counter (up to three) with its day count and next milestone, a line when a milestone is waiting, "Today's pledge" only if the daily pledge reminder is switched on and today's isn't done, and a one-tap "Ride out an urge". Tapping a counter opens its detail. The counter widget's tap target is Now, so it lands on this card.
- **Bridge, Session prep.** A "Recovery since your last session" card (days this run, urges logged and the strongest felt, fresh starts). It is read-only. "Add to prep notes" copies a plain-text summary into the prep note, and only when the user taps it.
- **Journal.** Entries written during a counter's run get a small tag like "Name · 12 days" on the timeline and in the editor (at most two). It is worked out from the entry's date and the counter's runs, so nothing is stored on the entry and older entries get it too.
- **Urges tab, trigger windows.** With at least four logged urges, and at least half of them in one two-hour stretch that no active trigger window covers, a card offers a trigger window for that time. "Add a trigger window" opens the normal editor with the time filled in (all seven days, label "Urge window"), and the reminders are re-synced when it closes. "Not now" turns the suggestion off for good.
- **Milestones.** The milestone card has "Tell someone" when at least one trusted contact has a phone number. It opens Messages with a short note that leaves out the counter's name and can be edited before sending.
- **Check-in.** Never prompted generally. A gentle, dismissible offer appears only after "Start again" is saved, and after a riding-out-an-urge timer ends. Skipping leaves no mark.
- **Help.** The Now and Bridge help text mention the first two.

## Where the code is
- `Models/RecoveryModels.swift` (also compiled into the widget target, because the shared schema lists these models)
- `Support/RecoverySupport.swift` (reminders, widget sync, delete)
- `Views/Recovery/` (the counter tabs, pledge and review, motivations and the craving tool)
- `Support/WidgetDataStore.swift` and `AnchorWidget/` (the counter widget)
- Hooks: the Recovery tile row in `PlanView`, export, import and Clear everything in `DataControlView`, and three entries in `AnchorSchema.models`.

## Data safety
- The three new models are additive, so existing stores migrate automatically. Do not rename or retype their fields after release without a migration.
- Export files gain optional recovery arrays. Import is tolerant: any missing section is treated as empty, a single unreadable record is skipped rather than failing the file, and dates are accepted with or without fractional seconds. Exports made before v2 still import. A v2 export imported into an older build is accepted, and the Recovery data in it is ignored.
- "Clear everything" deletes counters, motivations, pledges and reviews, cancels Recovery reminders, and empties the counter widget.

## Before you release it
1. **Test on a device:**
   - Add a counter with a past start date. No celebration should appear for days already behind it.
   - Slip and restart in both modes. In "current run and total days" the total must survive.
   - Open every tab on a counter that has a slip in its history. Page through all six Summary pages, flip the calendar back a month, and open Streaks and Times.
   - Log an urge, then "Save, then ride it out". Delete one from its context menu.
   - Start again with "Times that day" set to 3. It should appear in Times.
   - Edit the start date, then delete a counter. Do the delete from the Edit sheet and check the app does not crash.
   - Turn each reminder on. The permission prompt should appear then, and the text must be generic.
   - Add the counter widget in each size. Check it shows the discreet label, and that the count moves on after midnight.
   - Export, clear everything, import: counters, motivations and entries come back. Also import an export made before v2.
   - Run the craving timer to the end and with "I'm done waiting". The screen should not sleep while it runs.
   - With no counters, confirm Now and Session prep show nothing about Recovery. Add one and confirm the Now card appears, a waiting milestone shows, and "Today's pledge" only appears with the pledge reminder on.
   - In Session prep, log an urge and start again, then check the summary counts them and "Add to prep notes" appends once.
   - Write a journal entry today with a counter running, and one dated before the counter started: only the first gets a tag. Start again and check the next entry's tag restarts.
   - Log five urges around the same hour (edit the time in the log sheet). The trigger window card should appear, "Add a trigger window" should open the editor prefilled, and after Done the card should go away and the reminder should exist without opening Plan. Check "Not now" keeps it away.
   - Reach a milestone with one contact and with several: "Tell someone" goes straight to Messages, or asks who first. The text must not contain the counter's name.
   - Cancel the "Start again" sheet: no check-in offer. Save it: the offer appears, and "Check in" opens the normal check-in as a sheet. Finish an urge timer and confirm the same offer.
2. **Website.** Apply `anchor-v2-website.patch` when v2 ships, not before. It adds the Recovery sections to the privacy policy and a Support question. Update the "Effective" date on the privacy page to the release date.
3. **App Store Connect.** The App Privacy answer stays "Data not collected". Re-answer the age-rating questionnaire, since the app now references substance use and recovery. Add a line to the review notes saying Recovery is optional, on-device and has no community or accounts. Update the description and screenshots if you want to feature it.
4. **Crisis wording.** The craving tool tells users that their crisis numbers are in Plan. Confirm that is still where they live.

## Deliberate limits
- No community, no sync, no cloud backup of its own, and no streak sharing. Those would need servers.
- No stock quotes or milestone messages beyond a plain "You've reached 30 days." Everything motivational comes from what the user wrote.
