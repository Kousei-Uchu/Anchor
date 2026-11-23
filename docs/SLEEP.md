# Sleep journal and Apple Health

An optional, quiet record of nights. It has no score, no target hours, no streak, no stages and no word for a bad night. It is added hidden: nobody sees it until they turn it on under Customise on Plan.

## What it does
- **Nights.** One entry per night, named for the day you woke up. Bed time, wake time, time asleep (worked out from the two, or typed), an optional feel in three words you can rename, and a note.
- **Where it shows up.** Each is optional and off until switched on in Settings: a Last night card on Now in the morning, a small row for each night in the Journal and a mark on the month view, one extra question in a check-in, and a morning reminder whose wording never says what it is about. Two things reach Bridge: session prep has a Sleep since your last session card (how many nights are written down, the shortest and longest time asleep, and the usual bedtime, with an Add to prep notes button that only does anything when tapped), and Export for someone can include Sleep, with a plain chart of time asleep in the web page.
- **Apple Health.** A Bring in nights from Apple Health switch at the bottom of the Sleep screen reads sleep, and a separate Save nights I type to Apple Health switch writes it. Nothing is asked of Health until one of them is used, and writing is off to begin with.

## What session prep and export show
- **Session prep card.** Appears only when at least one night has something written down since the last session (or since a typical gap before now when there is no past session). It shows the count of nights, the shortest and longest time asleep, and the usual bedtime: the middle of the bed times, from three nights up, rounded to a quarter of an hour, the same rule as the usual range on the Sleep screen. It says nothing about whether it was enough and has no average. Nothing goes into the prep notes unless Add to prep notes is tapped. There is no switch, because the card shows only for someone who is already keeping the journal and does nothing on its own.
- **Export.** Sleep is a kind in Export for someone, one entry per night with the bed and up times, time asleep and the note. In the web page, Sleep also gets a line chart of time asleep from 0 h to the next whole hour above the longest night, with no target line. Nights with no time asleep are left out of the chart, and it needs two nights with a time. The PDF draws the same chart above the nights, under the same rule, and the Word file carries the lines as text. The web page's Download CSV has in_bed, up and minutes_asleep columns after its first five. In Your data, the CSV and PDF exports include sleep too: the CSV has bed_time, wake_time, minutes_asleep and feel columns after its first three (filled only on sleep rows), and the PDF has a Sleep heading, the chart and a line for each night. The feel word is in Your data's CSV only, never in Export for someone.

## How the Health import works
- Reads sleep analysis samples only. The last 90 days are read each time the Sleep screen opens. There is no background delivery.
- **Never stored (Patch HK2).** Nights from Health are held in memory only, as nights that belong to no store. They are never in the database, so they are never synced to iCloud (D39, and Apple does not allow health information in iCloud), never in a backup of the store, and they work the same with iCloud sync on or off. Copies an older version stored are deleted the next time sleep is read.
- One summary per night, for the day the sleep ended on. Samples less than three hours apart count as one sleep, and the longest one that day is kept, so naps are left out.
- Time asleep is the combined length of the asleep stages (overlaps from two devices counted once). Awake time is left out. If a source only records time in bed, the night has times and no time asleep.
- A night carries the id `health:YYYY-MM-DD`.
- **Typed wins.** If a day has a night that was typed, the Health night for that day is not shown. Opening a Health night makes a copy to look at; if it is changed in the sheet the copy becomes a typed night (which is then stored and can sync), and if not the copy is dropped. A Health night cannot be deleted in Anchor, because Anchor does not keep it.
- Anything Anchor itself writes to Health is ignored on import.
- **Denied looks like empty.** HealthKit does not say whether read access was refused, so the screen says "No sleep found in Apple Health yet." and nothing more.
- **Controls.** Bring in nights from Apple Health (switching it off stops reading and clears the nights held from it, and switching it on asks Health and reads the last 90 days). Stop reading sleep from Apple Health does the same and also deletes any copy an older version stored. Access itself is changed in the Health app, under Sharing. Clear everything switches importing off.
- The Health section is hidden where Health data is not available. Demo mode and showcase mode never touch Health.

## How writing back works
- Off by default, its own switch. Turning it on asks Health for permission to save sleep, and to look at sleep (so it can see what is already there for a night). Reading into the journal stays off unless Connect is used.
- Only typed nights with both a bed time and a wake time are saved. Nights from Apple Health are never written back. Nights typed before the switch was turned on are not saved unless Save the last 30 nights I typed is tapped.
- Each night is one in-bed sample (bed to wake) and one asleep sample whose length is the time asleep, placed so it ends when you got up. Both carry Anchor's sync identifier and a version, so editing a night replaces the samples instead of adding more.
- **Health is the source of truth.** If another source already holds time asleep over that night, Anchor leaves it alone and does not save one. Time in bed (an iPhone records it on its own) and time awake do not count as holding the night. The Sleep screen says how many nights were left alone, and why a save or a connect did not work.
- Deleting a night, or clearing its times, removes the samples Anchor saved for it, the next time the Sleep screen opens or the app comes forward. Remove what Anchor saved removes every sample Anchor wrote, and Clear everything does the same. Only samples Anchor itself saved can be removed.
- What was saved is tracked in the app's settings (night id and version), not in the database or an export.

## Release checklist (Health is part of the main release)
- [ ] HealthKit capability on the Anchor app target (Signing and Capabilities, then Capability, then HealthKit). The entitlements file already has it. Do not add it to the widget target.
- [ ] HealthKit enabled on the App ID in the developer portal (automatic signing normally does this the first time you build).
- [ ] `NSHealthShareUsageDescription` is set in both build configurations of the app. `NSHealthUpdateUsageDescription` is set too (SL4).
- [ ] Privacy page (`website/src/pages/Privacy.tsx`) lists Apple Health.
- [ ] App Privacy answers in App Store Connect: sleep stays on the device, so the answer very probably stays "Data not collected". Check Apple's current wording before submitting.
- [ ] App Review notes say that HealthKit is used to read sleep for the sleep journal, only after the person taps Connect, and that nothing is shared or used for advertising.
- [ ] Check the current App Store guideline text on Health data (no advertising, no iCloud storage). Anchor does neither.
- [ ] **Open, not blocking (D29a):** the Apple Health sleep cleanup has not been reviewed on a device. Try Remove imported sleep, Remove what Anchor saved, deleting a night and clearing a night's times, and check the rules for nights under three hours apart, naps, and the written asleep sample ending when you got up. Nothing else waits on this.
- [ ] Try on a real device with real sleep data: connect, deny, allow later in the Health app, disconnect, remove imported sleep, save a typed night, edit it, delete it, and check Health shows one set of samples from Anchor each time.

## Naps, other sleeps and earlier days (Patch SL1)

- A sleep has a kind: a night's sleep, or a nap or other sleep in the day (`kindRaw`, locked). There can be any number of sleeps on a day.
- Log sleep (the + on the Sleep screen) offers Last night, A nap or other sleep, and Sleep on an earlier day. The "Woke up on" date in the sheet picks any earlier day.
- Naps are listed with "Nap" on the date, but are left out of the dots, the usual range, the Last night card, the check-in question, and the appointment average. They are not left out of exports or the journal.
- A nap's times start at 2 pm and 3 pm rather than 11 pm and 7 am.

## The sleep calendar (Patch SL2)

- The Sleep screen keeps the 30 dots and the usual range, as one card that opens **Sleep calendar and entries**. The list of entries now lives there, not on the Sleep screen.
- The calendar is a month grid, newest first, that scrolls back through the months. Each day shows the night's sleep that ended on it ("7h30") and, under that, any daytime sleep ("+45m"). Today has a ring; days with sleep are tinted; days that have not happened cannot be opened.
- Tapping a day opens it in full: the night first, then the other sleeps in order, with the night, daytime and total time asleep, and buttons to add a night's sleep or a nap for that day. Each sleep opens in the usual sheet, and a Health night opens as a copy the same way it does on the Sleep screen.
- Months further back than 90 days are read from Apple Health as they scroll into view (nothing is stored). Your own entries show for any month.
- No score, no target, no streak, and no colour for a short night.
