# Locking what Anchor stores

This is the at-rest work of point 20 in the plan. It is in two parts. Patch 34 made the keys. Patch 35 is split: 35a (done) seals what the widgets are shown, with a key of its own; 35b uses the data key to lock the stored text, in three patches: 35b1 the safety copy, 35b2 the locked fields, 35b3 Lock my data (D15, option B). Patch 35b3 adds Lock my data, which locks the stored text with the data key; until it has been run nothing stored in the database is locked, and the screens for it are only in test builds (Settings, Encryption (test build), Safety copy (test build), Lock my data (test build)).

## The pieces

- **The data key.** 32 random bytes, made on the phone, kept in the Keychain as one generic password (service `page.aspens.anchor.datakey`, account `master`). It is available after the first unlock and only on this device, so it does not leave in a phone backup or move to a new phone. The class matches the store's own file protection, so a notification action that starts the app while the phone is locked can still read it. It is not tied to Face ID: the app's own lock is a separate gate.
- **The recovery key.** 16 random bytes shown to the person once, as 28 characters in seven groups of four (for example `208H-44RM-2MB1-E60S-38DH-R78Y-3WZG`). It is not stored anywhere. Typing it forgives case, spaces, hyphens, and reads O as 0 and I or L as 1.
- **The recovery file.** `Application Support/Keys/recovery.anchorkey`, 93 bytes, holding the data key sealed under the recovery key. It lives beside the store, so it goes with the phone's own backups and a restored phone still has it. Without the recovery key it is just noise.
- **Sealed text.** One piece of text sealed with the data key, ready for Patch 35 to use on stored fields.

## Why a recovery key

The data key stays in this device's Keychain. A phone restored from a backup, or a reinstall, gets the store and the recovery file but not the key. The recovery key and recovery file are the way back. Losing both the key on the phone and the recovery key means whatever was locked cannot be opened, by anyone, and the screen says so.

## States

| State | Meaning |
| --- | --- |
| Not set up | No key and no recovery file. |
| Ready | The key is on this device. |
| Needs recovery | The recovery file is here and the key is not (a restored phone). |
| Unavailable | The Keychain cannot be read right now, for example straight after a restart and before the first unlock. This is never treated as missing, and never leads to a new key being made. |

Setting up makes the key and the recovery file together. If either cannot be saved, neither is kept. Making a new recovery key replaces the file in one step and the old recovery key stops working; the data key does not change. Restoring only works when the key is missing, and never replaces a key that is here. Checking a recovery key changes nothing.

## Formats, version 1

**Recovery key text.** The 16 bytes as 130 bits (the last two are zero) in Crockford base32 (`0123456789ABCDEFGHJKMNPQRSTVWXYZ`), 26 characters. Then two check characters: the first 10 bits of SHA-256 of the 16 bytes, as two base32 characters. 28 characters, grouped in fours with hyphens. The check catches nearly every single mistyped character (about one in a thousand gets past it), and one that does cannot open the recovery file anyway.

**Recovery file.** `ANCHORKY` (8), version `01` (1), key id (8), salt (16), nonce (12), ciphertext (32), tag (16). The key id is the first 8 bytes of SHA-256 of `anchor key id` followed by the data key. The sealing key is HKDF-SHA256 of the 16 recovery bytes, with the salt and the info text `anchor recovery key v1`, 32 bytes; the cipher is AES-256-GCM, and the first 17 bytes are the authenticated data, so the key id cannot be swapped. HKDF is enough here, with no slow derivation, because the recovery key is 128 random bits and not a chosen password.

**Sealed text.** `anchor.sealed.v1:` followed by base64 of the nonce (12), the ciphertext and the tag (16), AES-256-GCM with the data key. The authenticated data is the field's context label in UTF-8 (such as `JournalEntry.text`), so a sealed value cannot be moved into another field. A stored value counts as sealed only if it has the prefix and also opens. Ordinary text that happens to start with the prefix is still read as text.

`scripts/anchorkey.py` is the same thing in running form (it needs `pip install cryptography`):

    python3 scripts/anchorkey.py selftest
    python3 scripts/anchorkey.py vectors
    python3 scripts/anchorkey.py check-file recovery.anchorkey 208H-44RM-2MB1-E60S-38DH-R78Y-3WZG

A debug build checks its Swift against those vectors when the Encryption screen opens, and stops with a message if they disagree. The widget sealing is checked the same way, when the app starts in a debug build.

## The widget summaries (Patch 35a)

The widgets read two small summaries that the app writes into the App Group's defaults: the contact and plan summary (`AnchorWidgetSnapshot`) and the Recovery counters (`CounterWidgetItem`). A phone backup carries those defaults, so they are now sealed.

- **A separate key (Patch 35a2).** 32 random bytes in a Keychain item shared by the app and the widget extension: service `page.aspens.anchor.widgetkey`, account `widget`, kept on this phone only and available after the first unlock (`kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`), so it is never in a backup and never moves to another phone. Both targets list the group `$(AppIdentifierPrefix)page.aspens.anchor.widgetkey` in `keychain-access-groups` in their entitlements, and both Info.plists carry its full name under `AnchorWidgetKeychainGroup` (the build fills in the team prefix), so the code never writes the team's name. It is not the data key: the widget extension never holds the data key, so a flaw in the widget cannot open anything else. **Moving from the key file:** Patch 35a kept the key in `Keys/widget.key` in the App Group container. The first time the app writes a summary after the update, it copies that file's 32 bytes into the Keychain, checks the item reads back as the same bytes, and then removes the file. The key is the same, so what is already sealed still opens and nothing is sealed again. **If the Keychain cannot be used** (the group name is missing, or the Keychain refuses), the key file works as it did before, so the widgets keep working.
- **Who makes it.** Only the app. The widget only reads it (the Keychain item first, the key file only until the app has moved it). A key that is there but cannot be read (the phone has not been unlocked since it started) is never replaced, so a locked phone cannot lead to a second key.
- **Format.** `anchor.widget.v1:` followed by base64 of the nonce (12), the ciphertext and the tag (16), AES-256-GCM. The authenticated data is `WidgetSnapshot` or `CounterItems`, so one cannot be moved into the other. It is the same as sealed text apart from the prefix, and a sealed text value is never read as a widget value or the other way round.
- **Where it is kept.** `AnchorWidgetSnapshot.sealed` and `AnchorCounterWidgetItems.sealed`, as strings. The old plain copies (`AnchorWidgetSnapshot`, `AnchorCounterWidgetItems`) are sealed and removed the first time the app opens after the update. The widget reads the sealed copy, and only falls back to a plain copy that the app has not moved yet.
- **Restored phones.** A restored phone has the sealed summaries and no key, so the widget shows its empty state until the app is opened and writes a new summary with a new key (the Plan tab writes both when it appears).
- **Before the first unlock.** The widget cannot read the key and shows its empty state, as it always could not read the defaults then. It now asks again after 15 minutes in that case, not after four hours.
- **If no key can be made** (no App Group container, a disk error, or the key could not be kept out of backups), the old plain copy is written, so the widgets keep working. Availability comes before the lock for what a widget shows.
- **Clear everything** now also removes both summaries, the Keychain item and any key file, and reloads the widgets. It did not take the contact summary off the device before.

What this does and does not cover: it keeps the summaries out of a backup in a readable form, and out of a copy of the defaults file. It does not hide them from someone with the phone unlocked, and the widgets themselves can still show them on a lock screen (the privacy page says so). The key now sits in a shared Keychain item, which ties it to this device more tightly than a file does (Patch 35a2).

## Locked fields (Patch 35b2)

Each field that holds your own words is two stored properties on its model: the plain one (`textPlain`) and a sealed twin (`textSealed`, a string that is empty until locking is on). The field's old name (`text`) is a computed property that goes through `FieldLock`, so no screen, export or widget changed. The plain property keeps the old name as its `originalName`, so SwiftData carries the stored values over when the app first opens.

- **Sealing.** The sealed value is the same format as sealed text above, with the context `Model.field` (for example `JournalEntry.text`) so a value cannot move to another field. Lists of small records are sealed as JSON and Data as base64, each as one value.
- **Off until Lock my data has run.** `FieldLock.isOn` is false until a Lock my data run (Patch 35b3) has checked every item, so until then a write keeps the text plain and the sealed twin empty. A new item ends its init with `lockNewValues()`, which does nothing while it is off.
- **A value that will not open** reads as empty and is never written back, so a missing key cannot overwrite your words.
- **Who may touch the twins.** Only the models, `LockedFields.swift` and `AppLock.swift`; `scripts/check-locked-fields.mjs` enforces it, and also that nothing sorts or filters on a locked field.
- **Locked:** the text and notes on every model, contact names, phone numbers, Discord ids and message templates, goal notes, list and routine items, diagram data, and the Recovery counter's name, label and start dates. **Left readable:** dates, numbers, switches, ids and the links between items, icon and colour names, and shipped Mascot lines (D44). Voice note and photo files are locked in a second step (Patch 35d, below). That was the first answer to D44; on 10 Nov 2026 you asked for dates and numbers to be locked too, and the full list, field by field, is `docs/FIELD_INVENTORY.md` (Patch 35f), which says what is sealed today and what 35g locks.
- **Widgets.** The extension builds the model files but holds no key, so it never opens a sealed value. It reads its own sealed summaries as before.

## Lock my data (Patch 35b3)

One flow that locks every field in the list above on every model, after the way back exists. Settings, Lock my data (in every build since Patch 35e). The code is `Support/LockMyData.swift` and the screen is `Views/Settings/LockMyDataView.swift`.

**The order.**

1. On the screen the person checks the recovery key (typed, and checked against the recovery file) and ticks that an encrypted backup is kept somewhere other than this phone. Lock my data stays off until the key and recovery file are here, both are done, and the real store is open.
2. Lock my data records a job (the time it was asked) and asks for a safety copy. Nothing else happens while the app is open.
3. On the next start the safety copy is made first, before the database is opened (Patch 35b1).
4. Once the database is open, and after the older migrations, the run starts. It refuses, says why and locks nothing if the safety copy is older than the request, if the data key is missing or does not open what it seals, or if the recovery file was made for a different key.
5. It notes what every item reads as, in a fresh context. It locks every item (`lockExistingValues`, which seals only what is stored plain and leaves anything sealed alone), saves, and reads everything again in another fresh context. It checks that every kind has the same number of items, that every item reads exactly as before, and that every locked field is held sealed with nothing left in the plain property.
6. If every check passes, one write records that locking is on and that the run is over. From then on `FieldLock.isOn` is turned on at every launch, so every new value is sealed as it is saved.
7. If any check fails, locking is not turned on and the safety copy is asked to be put back on the next start. The run does not try to undo its own writes in place, because a value that did not open is the reason it might have failed.
8. If the app is closed in the middle of a run, the next start sees that it never finished (the state is "running") and asks for the safety copy to be put back, before the database is opened. The copy was made at the start of that same run and nothing was written in between, so going back loses nothing.
9. After a good run, the next start rebuilds the database file before it is opened (`PRAGMA wal_checkpoint(TRUNCATE)`, `secure_delete`, `VACUUM`), because the old plain text can stay in unused space in a SQLite file after a value is rewritten. If this fails nothing is lost, and the screen says some old text may still be in the file.

**The key gate.** While text is locked, and the key is not on this phone (a restored phone, or the key and recovery file both gone), the app shows a screen in place of Anchor: restore with the recovery key, try again, or open Anchor without it, with a warning. Without it every screen would show locked text as empty, and saving one of them would write the empty text over the locked text. The gate is off in showcase mode and when nothing is locked.

**What this does not cover.**

- **The safety copy is plain.** It was made before locking, so it holds your text unlocked until you delete it. It is kept out of phone backups. Delete it once you are happy (Settings, Safety copy). Clear all data deletes it too.
- **Old backups.** A phone backup made before locking still holds your text readable, and so does any export made before.
- **Voice notes and Journal photos** are files, not text, and are locked in a second step (Patch 35d, below).
- **After a failed run, until the next start.** Reading still works, because the key is here. Anything written before the app is closed and opened again is in the set-aside part after going back, and Undo go back brings it back.
- **Turning it off.** There is no switch that unlocks in place. The way back is the safety copy (Go back), or an encrypted backup. If you would like an in-place unlock, say so.
- **The tidy-up of the file** relies on SQLite's VACUUM on the store file before the app opens it. It has not been run on a real store.

## Locking more than the words (Patch 35g1a, D44)

Your answer to D44 on 10 Nov 2026 was to lock dates, numbers and marks too. `docs/FIELD_INVENTORY.md` lists every field and what is done to it. Patch 35g1a is the groundwork and changes no stored field; the fields themselves are locked in 35g1b to 35g4.

**Sealing a date, a number, a mark or a choice.** A locked field of these kinds is the same two stored properties as a locked word: the plain one, which keeps the old name as its `originalName`, and a sealed twin that is a string. The old name is a computed property that goes through `FieldLock`. The value is written as a short piece of text, sealed with the data key in the same format as sealed text (context `Model.field`), and the plain property is set to one fixed value, the same for every item, so the stored file tells nothing. A date is its seconds since the reference date, a decimal number is written so it reads back exactly, a mark is `1` or `0`, and a choice from a fixed list is its raw text. A value that may be missing is sealed as `-` for nothing or `=` and the value, so a sealed twin is there either way.

**The same rules as for words.** While locking is off the value stays plain and the twin is empty. If sealing is wanted and fails, the value stays plain, so a write is never lost. A sealed value that will not open reads as the plain property holds it and is never written back. A value cannot move to another field, because the field's name is part of what is sealed.

**Sorting.** The database cannot sort or filter on a sealed value. A screen that sorted on a date will fetch the items and sort them after they are opened, with `sortedByKey`, which opens each value once. `scripts/check-locked-fields.mjs` fails on any sort or filter on a locked field, and since 35g1a it reads the model a line names, so a field with the same name on another model is not flagged by mistake.

**Levels.** A finished run records the level it locked (`lockMyData.level`). Level 1 is the words (Patch 35b). 35g1b raises it to 2, and each later part raises it again. A store locked at an earlier level is still locked, and Lock my data shows More to lock, with Lock the rest. It is the same flow as the first run: safety copy first, the lock on the next start before any screen opens, every item read again and compared in a fresh context, every locked field held sealed. Locking an item seals only what is still plain.

**If the second run fails or is stopped.** The words stay locked all the while: the state and `FieldLock.isOn` stay on. A failed run asks for the safety copy made just before it to be put back on the next start. A run the app was closed in the middle of is noticed on the next start (`lockMyData.upgradeRunning`) and does the same, before the database is opened. At the end of a good run the run is marked over, then the level is kept, then the state, so if the app stops between them the data is locked all the way and the level is still the old one, and asking again just does it again.

**What the safety copy holds.** The copy for a second run holds the newer fields unlocked until it is deleted, as the first copy held the words.

## Check-ins, sleep and Recovery (Patch 35g1b, D44)

The first group of dates, numbers and marks, 28 fields on six models, locked with the groundwork above. The list is in `docs/FIELD_INVENTORY.md`.

- **CheckIn:** when it was recorded and the five slider values. **SleepEntry:** the night, bed time, wake time, minutes asleep, the feel word chosen, when it was made and when it was last changed. **RecoveryCounter:** what kind of count it is, the savings amount, its period and currency, the milestones seen, when it was made and the times a day it used to happen. **RecoveryMotivation:** which kind of reason, and when it was made. **RecoveryDayEntry:** the day, when the pledge and the review were done, and the times a slip happened. **RecoveryUrge:** the day and how strong it was.
- **Left plain, with the reason in the list:** ids and the links between items, the order on screen, whether a counter is archived or shows its name outside the app, and where a night came from.
- **Level 2.** `LockMyData.currentLevel` is now 2. A store locked at level 1 is offered More to lock, with Lock the rest. A store not yet locked gets everything in its first run.
- **Sorting moved.** Ten places no longer ask the database to sort or match on a locked field: the Journal's check-ins and nights, the four sleep lists in Plan, the sleep lists in Bridge's appointment preparation and one-page summary, the urges list, and the check for an existing Recovery day when a slip is recorded. Each now fetches the items and sorts or picks after they are opened, with `sortedByKey` or a filter. A long list is therefore opened (decrypted) each time its screen redraws; if that turns out slow on a real phone it can be cached.
- **New values before the second run.** Once the words are locked, a value saved in one of these fields is sealed as it is saved, even before Lock the rest has been run on the older items, and every read takes whichever form is there.
- **A value that will not open** (the key is missing) reads as the fixed placeholder: the 1 Jan 2001 date, zero, no value, or the first choice. It is never written back unless you change that field yourself. The key gate (Patch 35b3) stands in front of the app in that case.

## The Journal, messages and people (Patch 35g2, D44)

The second group, 25 fields on ten models. `docs/FIELD_INVENTORY.md` has the list.

- **JournalEntry:** when it was made, whether you bookmarked it, and how it was started. **ThreadMessage:** when it was recorded and when you asked to be reminded. **SupportCalendarEntry:** the day. **FutureNote:** when it was written, when you chose for it to open, and whether it has. **UnsentDraft:** when it was made and whether it was sent. **BridgeDraftItem:** when it was made, whether you raised it and whether it is a question. **TrustedContact:** the minutes before an escalation reminder, the time zone, and the hours the person can be reached. **PersonSection, MessageStarter:** when each was last changed. **PersonalGoal:** where the goal stands, when it was made and when it was last changed.
- **A choice that may be missing.** How an entry was started is one of a fixed list or nothing, so it is sealed as `-` for nothing or `=` and its raw text, like an optional date. This is the one new kind of sealed value in this patch (`FieldLock.readOptionalChoice`, `storeOptionalChoice`).
- **Level 3.** `LockMyData.currentLevel` is 3. A store locked at level 1 or 2 is offered More to lock, and the line says which parts it adds.
- **Sorting moved.** Eighteen lists no longer ask the database to sort on a locked field: the Journal timeline, the appointment preparation and one-page summary lists, Bridge's draft list, the messages, support days, future notes and unsent drafts on Thread, their summaries in Settings, and the widgets on the tabs. Each fetches the items and sorts them after they are opened. Nine places that sort or filter in the database on a field still to lock are left, all in 35g3.
- **Left plain, with the reason in the list:** ids and the links between items, the order on screen, the on or off switches for reminders, one fixed choice such as how to reach a person, and the days and times of a regular hello, which the phone's reminder store holds anyway (D69).

## Plans, tasks, lists and sessions (Patch 35g3, D44)

The third group, 32 fields on thirteen models. `docs/FIELD_INVENTORY.md` has the list.

- **TaskItem:** when you finished it, when you made it, whether it is done, the day you gave it and how loosely, where it stands, how much energy you said it needs, the focus sessions and minutes, and your time estimate. **NextHourItem, QuickList, Routine, ItemList:** when each was made, and for a quick list when it was archived. **TriggerWindow:** the days and the start and end times. **AppointmentSeries:** the usual day, time and how often. **AppointmentOccurrence:** the date and whether it was moved. **SafetyPlan, SafetyPlanSection, BoundarySection, FeedbackLoopDiagram:** when each was last changed. **GroundingTool:** the times of day it is for.
- **Three choices from a fixed list.** The day kind, where a task stands and its energy are each sealed as their raw text, like the other choices (`FieldLock.readChoice`, `storeChoice`).
- **Level 4.** `LockMyData.currentLevel` is 4. A store locked at level 1, 2 or 3 is offered More to lock, and the line says which parts it adds.
- **Sorting moved.** The routines, quick lists, item lists, hard times and diagrams lists no longer ask the database to sort on a locked field. Each fetches the items and sorts them after they are opened, and so does the one-time move of old Next hour rows. No place is left that sorts or filters in the database on a field still to lock.
- **Left plain, with the reason in the list:** ids and the links between items, the order on screen, the on or off switches for reminders, a routine's reminder days and time, and a task's folded or open steps (D69).

## Lock my files (Patch 35d)

The second step of locking: the voice notes and Journal photos, which are files and not stored text (D31). It is on the Lock my data screen, offered once the text is locked. The code is `LockMyFiles`, `StoredFiles` and `FileLock` in `Support/LockMyData.swift`, and `FileCipher` in `Support/AppLock.swift`.

**The file format.** A sealed file is the nine bytes `ANCHFILE` and `01`, then the AES-GCM nonce, ciphertext and tag, made with the same data key as the text. The authenticated context is `File.VoiceNotes/<name>` or `File.JournalAttachments/<name>`, so a sealed file cannot be renamed into another file's place. A photo starts with `FF D8` and a voice note has `ftyp` near its start, so a plain file is never taken for a sealed one. Sealed files are written with file protection until first unlock, the same as the store.

**The order.**

1. The screen offers Lock voice notes and photos only when the text is locked, the key and recovery file are here, and the real store is open. The recovery key and the backup box were dealt with in the first step.
2. Choosing it records a job and asks for a new safety copy, which holds the files as they are now.
3. On the next start the copy is made first (Patch 35b1). Once the database is open, the run refuses and says why if the copy is older than the request, the key is missing or does not open what it seals, or the recovery file was made for a different key.
4. The work then runs in the background, so a long list of photos never holds up the start. Each file is sealed, opened again in memory and compared with the plain bytes, written beside the file under a name that starts with a dot, read back from there, and only then put in the plain file's place in one step. The plain file is not touched before that. A file deleted while this runs stays deleted.
5. Halfway, new files start to be sealed as they are saved, and a second pass takes any saved before that. Then every file is read again from its sealed form. Only if every one opens does the state become on, which is what turns `FileLock.isOn` on at every launch.
6. A file changed in the last two minutes is left alone by the run and by the sweep, because a recording may still be writing to it. A recording is sealed when it stops, and the next start seals anything left.

**Why there is no automatic way back here.** The text lock changes every row at once and has to be undone as a whole. Each file is changed by itself, and a file that is half done does not exist: it is the plain file or the sealed one. A run that stops, or a file that cannot be sealed, leaves some files sealed and some plain, and every one opens, because every read goes through `StoredFiles.read`, which takes both. The run can be asked for again. If the app is closed in the middle, the next start says so on the screen. The way back to the files as they were is the safety copy, as for the text.

**Once files are locked.** A new recording is plain while it is being recorded, because the recorder writes straight to its file, and is sealed the moment it stops. A new photo or drawing is sealed as it is saved. A backup restored with Import is sealed as it is put in place. Every start looks for files still plain, such as a recording cut short or files put back by Go back, and seals them.

**Reading and handing on.** A photo is read, opened and drawn; the picture is held in memory while the app runs, as before. A voice note is opened into memory to play, and its length is worked out once and kept. Share and Send through Messages need a file, so a locked voice note is opened into a copy in the phone's temporary folder at that moment only. The copy is removed when the sheet closes and at every start. Share uses a share item that makes the copy only when something is shared.

**Backups.** The encrypted backup (Patch 33) opens each locked file and puts the plain bytes in the backup, one at a time. The backup has a password of its own and is opened on any phone, so it cannot depend on this phone's key; `scripts/anchorbackup.py` still reads it. If a locked file cannot be opened, the backup stops instead of leaving that file out.

**What this does not cover.**

- **The safety copy is plain.** It holds the files as they were, unlocked, until you delete it.
- **Names, sizes and times.** The file names are random ids, but the size and time of each file, and that a file is a photo or a recording, are still visible to anyone with the files.
- **The temporary copy** of a voice note exists for as long as a share or a send takes, and until the start after that if the app is closed first.
- **A recording in progress** is plain until it stops.
- **Old copies.** A phone backup or an export made before locking still holds the files readable.
- **Turning it off.** There is no switch that unlocks files in place. The way back is the safety copy or an encrypted backup.
- **It has not run on real files.** It is checked by a self-test on made-up bytes in a test build and by `scripts/check-locked-files.mjs`, which keeps every other file from reading or writing the two folders itself. Nothing has been compiled by the tool that wrote it.

## Checking a test build on a device

1. Open the screen: nothing should stop the app (the self-test runs on open).
2. Make a key and a recovery key. Write the key down, then type its last four characters to close the sheet.
3. Check my recovery key with the written key; then with one character changed (it should say it is not a whole recovery key or does not match).
4. Make a new recovery key (it asks for Face ID or the passcode). The old key should now say it does not match.
5. Delete the app and install again from Xcode, or use Remove the key and the recovery file and make another. After a reinstall from a backup the screen should say the key is not on this device and offer Restore.

## Checking the widget summaries on a device (Patch 35a)

1. Open a debug build: it should start (the widget self-test runs at launch and stops the app with a message if the Swift and the script disagree).
2. With a contact and a Recovery counter set up, open Plan once and check the widgets still show the names and the counter.
3. Optional, with a Mac: the sealed values are strings under `AnchorWidgetSnapshot.sealed` and `AnchorCounterWidgetItems.sealed` in the App Group defaults, and begin with `anchor.widget.v1:`. The plain keys should be gone.
4. Restart the phone and look at the widget before unlocking: empty is expected. Unlock it: the widget should fill in within about 15 minutes, or at once when the app is opened.
5. Clear everything in Your data: the widgets should empty.

## Checking Lock my files on a device (Patch 35d)

On a copy of your own data, with the text already locked, and an encrypted backup made first.

1. Open Settings, Lock my data. Under Voice notes and photos it should show how many files there are now.
2. Tap Lock voice notes and photos and confirm. It says it is waiting. Close Anchor from the app switcher and open it again.
3. Open Lock my data again. It should say Locking, with a count that rises, then Voice notes and photos with a date and the number of files. Last time, voice notes and photos should say it locked and checked every file.
4. Open a Journal entry with a photo, play a voice note, and share one voice note: all three work as before. Record a new voice note and add a new photo: both work, and the count of locked files goes up by two.
5. Make an encrypted backup, restore it on a second phone or a simulator with Import, and check the photos and voice notes are there.
6. Optional, with a Mac and a copy of the app's folder: a file in `VoiceNotes` or `JournalAttachments` should begin with the letters ANCHFILE.
7. To check the way back, use Safety copy, Go back, and look: the files are as they were before step 2, and the app still shows them, and the next start locks them again.
