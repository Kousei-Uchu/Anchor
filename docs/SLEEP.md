# Sleep journal and Apple Health

An optional, quiet record of nights. It has no score, no target hours, no streak, no stages and no word for a bad night. It is added hidden: nobody sees it until they turn it on under Customise on Plan.

## What it does
- **Nights.** One entry per night, named for the day you woke up. Bed time, wake time, time asleep (worked out from the two, or typed), an optional feel in three words you can rename, and a note.
- **Where it shows up.** Each is optional and off until switched on in Settings: a Last night card on Now in the morning, a small row for each night in the Journal and a mark on the month view, one extra question in a check-in, and a morning reminder whose wording never says what it is about.
- **Apple Health.** A Connect Apple Health button at the bottom of the Sleep screen reads sleep, and a separate Save nights I type to Apple Health switch writes it. Nothing is asked of Health until one of them is used, and writing is off to begin with.

## How the Health import works
- Reads sleep analysis samples only. The first time, the last 30 days; after that, the last few days again, when the Sleep screen opens and when the app comes to the foreground. There is no background delivery.
- One summary per night, for the day the sleep ended on. Samples less than three hours apart count as one sleep, and the longest one that day is kept, so naps are left out.
- Time asleep is the combined length of the asleep stages (overlaps from two devices counted once). Awake time is left out. If a source only records time in bed, the night has times and no time asleep.
- A night is kept under the id `health:YYYY-MM-DD`, so it is never added twice.
- **Typed wins.** If a night has an entry that was typed, Health never adds or changes it. If an imported night is changed in the sheet, it becomes a typed night.
- Anything Anchor itself writes to Health is ignored on import.
- **Denied looks like empty.** HealthKit does not say whether read access was refused, so the screen says "No sleep found in Apple Health yet." and nothing more.
- **Controls.** Bring in new nights (off stops further imports). Remove imported sleep deletes only the nights that came from Health and were not changed, and switches importing off. Access itself is changed in the Health app, under Sharing. Clear everything switches importing off.
- The Health section is hidden where Health data is not available. Demo mode and showcase mode never touch Health.

## How writing back works
- Off by default, its own switch. Turning it on asks Health for permission to save sleep, and to look at sleep (so it can see what is already there for a night). Reading into the journal stays off unless Connect is used.
- Only typed nights with both a bed time and a wake time are saved. Nights from Apple Health are never written back. Nights typed before the switch was turned on are not saved unless Save the last 30 nights I typed is tapped.
- Each night is one in-bed sample (bed to wake) and one asleep sample whose length is the time asleep, placed so it ends when you got up. Both carry Anchor's sync identifier and a version, so editing a night replaces the samples instead of adding more.
- **Health is the source of truth.** If another source already holds sleep over that night, Anchor leaves it alone and does not save one.
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
- [ ] Try on a real device with real sleep data: connect, deny, allow later in the Health app, disconnect, remove imported sleep, save a typed night, edit it, delete it, and check Health shows one set of samples from Anchor each time.
