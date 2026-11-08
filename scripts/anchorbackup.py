#!/usr/bin/env python3
"""Reference reader for Anchor's .anchorbackup files.

Use it to open a backup without the app, or to check a file:

    python3 scripts/anchorbackup.py unpack my.anchorbackup outfolder
    python3 scripts/anchorbackup.py verify my.anchorbackup

It needs the cryptography package (pip install cryptography) and asks for the
password. The format is written down in docs/BACKUP.md.
"""
import getpass
import hashlib
import os
import struct
import sys
import unicodedata

from cryptography.exceptions import InvalidTag
from cryptography.hazmat.primitives.ciphers.aead import AESGCM

MAGIC = b"ANCHORBK"
VERSION = 1
HEADER_LEN = 8 + 1 + 4 + 16 + 4
CHUNK = 1 << 20
MIN_ITER, MAX_ITER = 100_000, 5_000_000
ARCHIVE_MAGIC = b"AP01"
FOLDERS = {0: "JournalAttachments", 1: "VoiceNotes"}
MAX_JSON = 256 * 1024 * 1024


class BackupError(Exception):
    pass


def derive_key(password, salt, iterations):
    secret = unicodedata.normalize("NFC", password).encode("utf-8")
    return hashlib.pbkdf2_hmac("sha256", secret, salt, iterations, 32)


def encrypt_stream(plain, password, iterations=600_000, salt=None, prefix=None, chunk=CHUNK):
    salt = salt or os.urandom(16)
    prefix = prefix or os.urandom(4)
    header = MAGIC + bytes([VERSION]) + struct.pack(">I", iterations) + salt + prefix
    key = derive_key(password, salt, iterations)
    aes = AESGCM(key)
    out = [header]
    pieces = [plain[i:i + chunk] for i in range(0, len(plain), chunk)] or [b""]
    for i, piece in enumerate(pieces):
        flag = 1 if i == len(pieces) - 1 else 0
        nonce = prefix + struct.pack(">Q", i)
        ct = aes.encrypt(nonce, piece, header + bytes([flag]))
        out.append(bytes([flag]) + struct.pack(">I", len(ct)) + ct)
    return b"".join(out)


def decrypt_stream(blob, password):
    if len(blob) < HEADER_LEN or blob[:8] != MAGIC:
        raise BackupError("This is not an Anchor backup.")
    if blob[8] != VERSION:
        raise BackupError("This backup was made by a newer version of Anchor.")
    header = blob[:HEADER_LEN]
    iterations = struct.unpack(">I", blob[9:13])[0]
    if not (MIN_ITER <= iterations <= MAX_ITER):
        raise BackupError("The file header is not valid.")
    salt, prefix = blob[13:29], blob[29:33]
    aes = AESGCM(derive_key(password, salt, iterations))
    pos, index, plain, done = HEADER_LEN, 0, [], False
    while pos < len(blob):
        if done:
            raise BackupError("There is extra data after the end of the backup.")
        if pos + 5 > len(blob):
            raise BackupError("The backup is cut short.")
        flag = blob[pos]
        (n,) = struct.unpack(">I", blob[pos + 1:pos + 5])
        pos += 5
        if flag not in (0, 1) or n < 16 or n > CHUNK + 16 or pos + n > len(blob):
            raise BackupError("The backup is damaged or cut short.")
        try:
            plain.append(aes.decrypt(prefix + struct.pack(">Q", index), blob[pos:pos + n], header + bytes([flag])))
        except InvalidTag:
            if index == 0:
                raise BackupError("That password did not work, or the file was changed.")
            raise BackupError("The backup is damaged.")
        pos += n
        index += 1
        done = flag == 1
    if not done:
        raise BackupError("The backup is cut short.")
    return b"".join(plain)


def safe_name(name):
    return bool(name) and len(name.encode()) <= 255 and "/" not in name and "\\" not in name \
        and name not in (".", "..") and "\x00" not in name and not name.startswith(".")


def build_archive(json_bytes, files):
    out = [ARCHIVE_MAGIC, struct.pack(">I", len(json_bytes)), json_bytes, struct.pack(">I", len(files))]
    for folder, name, data in files:
        nb = name.encode()
        out += [bytes([folder]), struct.pack(">H", len(nb)), nb, struct.pack(">Q", len(data)), data]
    return b"".join(out)


def parse_archive(plain):
    view, pos = memoryview(plain), 0

    def take(n):
        nonlocal pos
        if n < 0 or pos + n > len(view):
            raise BackupError("The backup is damaged.")
        chunk = bytes(view[pos:pos + n])
        pos += n
        return chunk

    if take(4) != ARCHIVE_MAGIC:
        raise BackupError("The backup is damaged.")
    (jlen,) = struct.unpack(">I", take(4))
    if jlen > MAX_JSON:
        raise BackupError("The backup is damaged.")
    json_bytes = take(jlen)
    (count,) = struct.unpack(">I", take(4))
    files = []
    for _ in range(count):
        folder = take(1)[0]
        (nlen,) = struct.unpack(">H", take(2))
        name = take(nlen).decode("utf-8", "strict")
        (dlen,) = struct.unpack(">Q", take(8))
        data = take(dlen)
        if folder not in FOLDERS or not safe_name(name):
            raise BackupError("The backup holds a file name that is not allowed.")
        files.append((folder, name, data))
    if pos != len(view):
        raise BackupError("There is extra data after the end of the backup.")
    return json_bytes, files


def main(argv):
    if len(argv) < 3 or argv[1] not in ("unpack", "verify"):
        print(__doc__)
        return 2
    with open(argv[2], "rb") as handle:
        blob = handle.read()
    try:
        json_bytes, files = parse_archive(decrypt_stream(blob, getpass.getpass("Password: ")))
    except BackupError as err:
        print(err)
        return 1
    print(f"Backup is good: {len(json_bytes)} bytes of data and {len(files)} files.")
    if argv[1] == "unpack":
        if len(argv) < 4:
            print("Say which folder to put it in.")
            return 2
        out = argv[3]
        os.makedirs(out, exist_ok=True)
        with open(os.path.join(out, "anchor-export.json"), "wb") as handle:
            handle.write(json_bytes)
        for folder, name, data in files:
            target = os.path.join(out, FOLDERS[folder])
            os.makedirs(target, exist_ok=True)
            with open(os.path.join(target, name), "wb") as handle:
                handle.write(data)
        print(f"Written to {out}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
