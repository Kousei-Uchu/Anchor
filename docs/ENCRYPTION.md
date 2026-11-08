# Locking what Anchor stores

This is the at-rest work of point 20 in the plan. It is in two parts. Patch 34 (this one) makes the keys. Patch 35 uses them to lock the stored text and moves what is already stored. Nothing is locked with this key yet, and the screen for it is only in test builds (Settings, Your data and help, Encryption (test build)).

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

A debug build checks its Swift against those vectors when the Encryption screen opens, and stops with a message if they disagree.

## Not done yet (Patch 35)

Locking the stored text and moving what is already there, in a way that can be undone and survives being stopped half way; a start-up check for a missing key that stops the store being opened over locked text; the voice note and photo files; the widget snapshot; and a way to turn it off.

## Checking a test build on a device

1. Open the screen: nothing should stop the app (the self-test runs on open).
2. Make a key and a recovery key. Write the key down, then type its last four characters to close the sheet.
3. Check my recovery key with the written key; then with one character changed (it should say it is not a whole recovery key or does not match).
4. Make a new recovery key (it asks for Face ID or the passcode). The old key should now say it does not match.
5. Delete the app and install again from Xcode, or use Remove the key and the recovery file and make another. After a reinstall from a backup the screen should say the key is not on this device and offer Restore.
