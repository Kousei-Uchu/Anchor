# Encrypted backups (.anchorbackup)

Plan, Your data, Make an encrypted backup. It holds everything the plain JSON export holds, plus the photos and drawings in the Journal and the voice notes on messages, which the JSON export leaves out. Restoring is the same Import button as before: Anchor sees the file is a backup and asks for the password.

## What to know

- The password is chosen when the backup is made (8 or more characters, typed twice). It is not stored anywhere and cannot be recovered. Without it the file cannot be opened by anyone.
- Restoring only adds. Records already on the device (same id) are left alone, and so is a photo or voice note whose file name is already there. Nothing is deleted or overwritten.
- A wrong password, a damaged or cut-short file, or a changed byte stops the restore before anything is added.
- The plain JSON export and the older import of it still work, and an old JSON file imports as it always did.
- A backup file is written to a temporary folder and handed to the share sheet. Where it goes after that is up to you.

## Format, version 1

All numbers are big endian.

**Header, 33 bytes:** `ANCHORBK` (8), version `01` (1), PBKDF2 rounds (4), salt (16), nonce prefix (4). Readers accept 100,000 to 5,000,000 rounds; Anchor writes 600,000.

**Key:** PBKDF2-HMAC-SHA256 over the password (Unicode NFC, UTF-8), the salt and the rounds, 32 bytes.

**Body:** a run of chunks, each `flag` (1: `00` more follow, `01` last), `length` (4), then `length` bytes of AES-256-GCM ciphertext with its 16 byte tag at the end. A chunk holds up to 1 MiB of plain bytes. The nonce is the 4 byte prefix followed by the chunk number (8 bytes, from 0). The authenticated data is the 33 header bytes followed by the flag byte, so a chunk cannot be moved, dropped, repeated or marked as the last by someone without the key. A file must end exactly after the chunk marked last.

**Plain stream (what the chunks hold, joined):** `AP01` (4); length of the JSON (4) and the JSON, which is the same document as the plain export; number of files (4); then for each file a folder byte (`00` the Journal's photos and drawings, `01` voice notes), name length (2), the name in UTF-8, size (8) and the bytes. Names cannot be empty, start with a dot, hold a slash or backslash, or be longer than 255 bytes.

## Opening one without the app

`scripts/anchorbackup.py` is a small reader that follows the rules above (it needs `pip install cryptography`):

    python3 scripts/anchorbackup.py verify my.anchorbackup
    python3 scripts/anchorbackup.py unpack my.anchorbackup folder

`unpack` writes `anchor-export.json` and the two folders of files. A debug build of the app also checks, each time Your data opens, that it can read a small file made by that script.

## Not covered

Backups are for moving or keeping a copy, not for syncing. Settings (such as reminder times and layout) are not in them, the same as the JSON export. The photo and voice note files on the device itself are locked by Lock my files (Patch 35d, `docs/ENCRYPTION.md`). A backup always holds them as plain bytes, so it opens on any phone with its password and `scripts/anchorbackup.py` reads it without this phone's key. If a locked file cannot be opened when a backup is made, the backup stops instead of leaving it out.
