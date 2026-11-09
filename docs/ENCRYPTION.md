# Locking what Anchor stores

This is the at-rest work of point 20 in the plan. It is in two parts. Patch 34 made the keys. Patch 35 is split: 35a (done) seals what the widgets are shown, with a key of its own; 35b will use the data key to lock the stored text and move what is already stored, and waits on a decision (D15 in the plan). Nothing stored in the database is locked with the data key yet, and the screen for it is only in test builds (Settings, Your data and help, Encryption (test build)).

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
- **Off for now.** `FieldLock.isOn` is false until Patch 35b3, so a write keeps the text plain and the sealed twin empty. A new item ends its init with `lockNewValues()`, which does nothing while it is off.
- **A value that will not open** reads as empty and is never written back, so a missing key cannot overwrite your words.
- **Who may touch the twins.** Only the models, `LockedFields.swift` and `AppLock.swift`; `scripts/check-locked-fields.mjs` enforces it, and also that nothing sorts or filters on a locked field.
- **Locked:** the text and notes on every model, contact names, phone numbers, Discord ids and message templates, goal notes, list and routine items, diagram data, and the Recovery counter's name, label and start dates. **Left readable:** dates, numbers, switches, ids and the links between items, icon and colour names, and shipped Mascot lines (D44). Voice note and photo files wait for 35d.
- **Widgets.** The extension builds the model files but holds no key, so it never opens a sealed value. It reads its own sealed summaries as before.

## Not done yet (Patch 35b3)

Locking the stored text and moving what is already there, in a way that can be undone and survives being stopped half way; a start-up check for a missing key that stops the store being opened over locked text; the voice note and photo files; and a way to turn it off. D15 is answered (option B, every model in one go, with a safety copy first), so 35b is three patches: 35b1 the safety copy and the way back, 35b2 the locked fields, and 35b3 the Lock my data flow. See the plan and `docs/DECISIONS_EXPLAINED.md`.

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
