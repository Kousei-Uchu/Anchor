# Recovery (v2)

An optional area for day counters, motivations, a daily pledge and evening review, and a craving tool. It is free, local, and has no account or community. It lives under Plan, in the Recovery row.

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
- **Summary** is six swipeable pages: live time on this run (days, hours, minutes, seconds as slanted bars), progress this month (a dot for every day), total days with whole weekends, fresh starts and first start date, the streak record against your personal best, your current streak, and your start date. Share, Log urge and Start again sit underneath.
- **Calendar** shows a month at a time. Sober days are joined pills, a day you started again is a circled cross, and a "Streaks" row opens the history.
- **Streaks and Times.** The streak list shows every run with a bar against the longest one and a star on the best. Times lists how many times it happened on each slip day, and has a "before tracking" reference number.
- **Urges.** Log an urge with when, how strong it felt and a note, then optionally go straight into "riding out an urge". The tab shows this week, this month and the last 14 days.
- **Days are whole elapsed days** (24 hour periods from the start time), like a stopwatch, so "My streak is 0 days" means less than 24 hours.

### Deliberately different from other trackers
- Anchor's own colours, icons and wording, and no copied artwork or text.
- It says "Start again" and "Fresh starts", not "Reset" and "Comebacks".
- No community, no pausing a counter, no reordering of the summary pages. These can be added later.
- Times and urges are the user's own record and are never scored, ranked or compared.

## Where the code is
- `Models/RecoveryModels.swift` (also compiled into the widget target, because the shared schema lists these models)
- `Support/RecoverySupport.swift` (reminders, widget sync, delete)
- `Views/Recovery/` (the counter tabs, pledge and review, motivations and the craving tool)
- `Support/WidgetDataStore.swift` and `AnchorWidget/` (the counter widget)
- Hooks: the Recovery tile row in `PlanView`, export, import and Clear everything in `DataControlView`, and three entries in `AnchorSchema.models`.

## Data safety
- The three new models are additive, so existing stores migrate automatically. Do not rename or retype their fields after release without a migration.
- Export files gain three optional arrays. Exports made before v2 still import. A v2 export imported into an older build is accepted, and the Recovery data in it is ignored.
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
2. **Website.** Apply `anchor-v2-website.patch` when v2 ships, not before. It adds the Recovery sections to the privacy policy and a Support question. Update the "Effective" date on the privacy page to the release date.
3. **App Store Connect.** The App Privacy answer stays "Data not collected". Re-answer the age-rating questionnaire, since the app now references substance use and recovery. Add a line to the review notes saying Recovery is optional, on-device and has no community or accounts. Update the description and screenshots if you want to feature it.
4. **Crisis wording.** The craving tool tells users that their crisis numbers are in Plan. Confirm that is still where they live.

## Deliberate limits
- No community, no sync, no cloud backup of its own, and no streak sharing. Those would need servers.
- No stock quotes or milestone messages beyond a plain "You've reached 30 days." Everything motivational comes from what the user wrote.
