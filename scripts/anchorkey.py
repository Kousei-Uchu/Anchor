#!/usr/bin/env python3
"""
Reference for the key formats Anchor uses to lock what it stores (docs/ENCRYPTION.md).

This is the specification in running form. The Swift in AppLock.swift (DataKeyFormat,
RecoveryKeyText, RecoveryBlob, FieldCipher) is written to match it, and a debug build
checks itself against the vectors that `vectors` prints.

Needs the `cryptography` package: pip install cryptography

    python3 scripts/anchorkey.py selftest
    python3 scripts/anchorkey.py vectors
    python3 scripts/anchorkey.py check-file <recovery-file> <recovery-key>
"""

import base64
import hashlib
import os
import sys

from cryptography.exceptions import InvalidTag
from cryptography.hazmat.primitives import hashes
from cryptography.hazmat.primitives.ciphers.aead import AESGCM
from cryptography.hazmat.primitives.kdf.hkdf import HKDF

ALPHABET = "0123456789ABCDEFGHJKMNPQRSTVWXYZ"

BLOB_MAGIC = b"ANCHORKY"
BLOB_VERSION = 1
FIELD_PREFIX = "anchor.sealed.v1:"
WIDGET_PREFIX = "anchor.widget.v1:"


class KeyError_(Exception):
    pass


# ---- Recovery key text -----------------------------------------------------
# 16 random bytes, written as 26 characters of Crockford base32 (the last two
# bits are zero), then 2 characters that are the first 10 bits of SHA-256 of the
# 16 bytes. 28 characters in 7 groups of 4, joined with hyphens.

def _check_chars(raw: bytes) -> str:
    digest = hashlib.sha256(raw).digest()
    first = digest[0] >> 3
    second = ((digest[0] & 0x07) << 2) | (digest[1] >> 6)
    return ALPHABET[first] + ALPHABET[second]


def encode_recovery(raw: bytes) -> str:
    if len(raw) != 16:
        raise KeyError_("recovery bytes must be 16 long")
    bits = []
    for byte in raw:
        for shift in range(7, -1, -1):
            bits.append((byte >> shift) & 1)
    bits += [0, 0]
    chars = []
    for i in range(0, 130, 5):
        value = 0
        for bit in bits[i:i + 5]:
            value = (value << 1) | bit
        chars.append(ALPHABET[value])
    text = "".join(chars) + _check_chars(raw)
    return "-".join(text[i:i + 4] for i in range(0, 28, 4))


def decode_recovery(text: str) -> bytes:
    cleaned = []
    for ch in text.upper():
        if ch in " -\t\r\n":
            continue
        if ch == "O":
            ch = "0"
        elif ch in "IL":
            ch = "1"
        if ch not in ALPHABET:
            raise KeyError_("not a recovery key")
        cleaned.append(ch)
    if len(cleaned) != 28:
        raise KeyError_("not a recovery key")
    values = [ALPHABET.index(c) for c in cleaned]
    bits = []
    for value in values[:26]:
        for shift in range(4, -1, -1):
            bits.append((value >> shift) & 1)
    if bits[128] != 0 or bits[129] != 0:
        raise KeyError_("not a recovery key")
    raw = bytearray()
    for i in range(0, 128, 8):
        byte = 0
        for bit in bits[i:i + 8]:
            byte = (byte << 1) | bit
        raw.append(byte)
    raw = bytes(raw)
    if _check_chars(raw) != "".join(cleaned[26:]):
        raise KeyError_("not a recovery key")
    return raw


# ---- Recovery file -----------------------------------------------------------
# magic(8) | version(1) | key id(8) | salt(16) | nonce(12) | ciphertext(32) | tag(16)
# The ciphertext is the 32 byte data key. The key that seals it is HKDF-SHA256 of
# the 16 recovery bytes with the salt and the info text below. The first 17 bytes
# are the authenticated data, so the key id cannot be swapped.

def key_id(master: bytes) -> bytes:
    return hashlib.sha256(b"anchor key id" + master).digest()[:8]


def _wrapping_key(recovery: bytes, salt: bytes) -> bytes:
    return HKDF(algorithm=hashes.SHA256(), length=32, salt=salt,
                info=b"anchor recovery key v1").derive(recovery)


def make_blob(master: bytes, recovery: bytes, salt: bytes = None, nonce: bytes = None) -> bytes:
    if len(master) != 32 or len(recovery) != 16:
        raise KeyError_("bad key sizes")
    salt = salt or os.urandom(16)
    nonce = nonce or os.urandom(12)
    header = BLOB_MAGIC + bytes([BLOB_VERSION]) + key_id(master)
    sealed = AESGCM(_wrapping_key(recovery, salt)).encrypt(nonce, master, header)
    return header + salt + nonce + sealed


def open_blob(blob: bytes, recovery: bytes) -> bytes:
    if len(blob) != 93 or blob[:8] != BLOB_MAGIC or blob[8] != BLOB_VERSION:
        raise KeyError_("damaged file")
    header = blob[:17]
    salt, nonce, sealed = blob[17:33], blob[33:45], blob[45:]
    try:
        master = AESGCM(_wrapping_key(recovery, salt)).decrypt(nonce, sealed, header)
    except InvalidTag:
        raise KeyError_("wrong recovery key")
    if key_id(master) != blob[9:17]:
        raise KeyError_("damaged file")
    return master


# ---- Sealed text ---------------------------------------------------------------
# "anchor.sealed.v1:" + base64(nonce(12) | ciphertext | tag(16)). AES-256-GCM with
# the data key; the authenticated data is the field's context label, UTF-8, so a
# sealed value cannot be moved to a different field.

def seal_field(text: str, context: str, master: bytes, nonce: bytes = None) -> str:
    nonce = nonce or os.urandom(12)
    sealed = AESGCM(master).encrypt(nonce, text.encode("utf-8"), context.encode("utf-8"))
    return FIELD_PREFIX + base64.b64encode(nonce + sealed).decode("ascii")


def open_field(stored: str, context: str, master: bytes):
    """The text, or None when the value is not sealed or does not open."""
    if not stored.startswith(FIELD_PREFIX):
        return None
    try:
        raw = base64.b64decode(stored[len(FIELD_PREFIX):], validate=True)
    except Exception:
        return None
    if len(raw) < 28:
        return None
    try:
        return AESGCM(master).decrypt(raw[:12], raw[12:], context.encode("utf-8")).decode("utf-8")
    except (InvalidTag, UnicodeDecodeError):
        return None



# ---- Widget summaries ------------------------------------------------------------
# "anchor.widget.v1:" + base64(nonce(12) | ciphertext | tag(16)). The same AES-256-GCM
# as sealed text, with its own prefix, and the authenticated data is "WidgetSnapshot" or
# "CounterItems". The key is 32 random bytes in the App Group container (Keys/widget.key),
# not backed up, and is a different key from the data key so the widget never holds it.

def seal_widget(data: bytes, context: str, key: bytes, nonce: bytes = None) -> str:
    nonce = nonce or os.urandom(12)
    sealed = AESGCM(key).encrypt(nonce, data, context.encode("utf-8"))
    return WIDGET_PREFIX + base64.b64encode(nonce + sealed).decode("ascii")


def open_widget(stored: str, context: str, key: bytes):
    """The bytes, or None when the value is not a sealed widget value or does not open."""
    if not stored.startswith(WIDGET_PREFIX):
        return None
    try:
        raw = base64.b64decode(stored[len(WIDGET_PREFIX):], validate=True)
    except Exception:
        return None
    if len(raw) < 28:
        return None
    try:
        return AESGCM(key).decrypt(raw[:12], raw[12:], context.encode("utf-8"))
    except InvalidTag:
        return None


# ---- Fixed inputs for the vectors ------------------------------------------------

V_MASTER = bytes(range(32))
V_RECOVERY = bytes(range(0x10, 0x20))
V_SALT = bytes(range(0x20, 0x30))
V_NONCE = bytes(range(0x30, 0x3C))
V_FIELD_NONCE = bytes(range(0x40, 0x4C))
V_CONTEXT = "JournalEntry.text"
V_TEXT = "Felt tense before the call — it went better than I expected. ✓"
V_WIDGET_CONTEXT = "WidgetSnapshot"
V_WIDGET_JSON = ('{"topContacts":[{"name":"Sam","phoneNumber":"0400 000 001"}],'
                 '"hasSafetyPlan":true,"deEscalationScriptLine":"I need 10 minutes."}')


def vectors() -> dict:
    return {
        "master": V_MASTER.hex(),
        "recoveryBytes": V_RECOVERY.hex(),
        "recoveryText": encode_recovery(V_RECOVERY),
        "blob": make_blob(V_MASTER, V_RECOVERY, V_SALT, V_NONCE).hex(),
        "keyID": key_id(V_MASTER).hex(),
        "context": V_CONTEXT,
        "text": V_TEXT,
        "sealed": seal_field(V_TEXT, V_CONTEXT, V_MASTER, V_FIELD_NONCE),
        "widgetContext": V_WIDGET_CONTEXT,
        "widgetJSON": V_WIDGET_JSON,
        "widgetSealed": seal_widget(V_WIDGET_JSON.encode("utf-8"), V_WIDGET_CONTEXT, V_MASTER, V_FIELD_NONCE),
    }


def selftest() -> None:
    v = vectors()

    # Recovery text round trips, and forgives case, spaces, hyphens and look-alikes.
    for _ in range(200):
        raw = os.urandom(16)
        text = encode_recovery(raw)
        assert len(text) == 34 and text.count("-") == 6
        assert decode_recovery(text) == raw
        assert decode_recovery(text.lower().replace("-", " ")) == raw
        assert decode_recovery(text.replace("0", "O").replace("1", "l")) == raw
    # Nearly every single wrong character is caught by the check characters or the
    # zero bits (ten check bits miss about one typo in a thousand). A miss still
    # cannot open the recovery file, because that file's own tag fails.
    text = v["recoveryText"].replace("-", "")
    missed = 0
    for i in range(len(text)):
        for ch in ALPHABET:
            if ch == text[i]:
                continue
            try:
                changed = decode_recovery(text[:i] + ch + text[i + 1:])
            except KeyError_:
                continue
            missed += 1
            assert changed != V_RECOVERY
            try:
                open_blob(make_blob(V_MASTER, V_RECOVERY, V_SALT, V_NONCE), changed)
                raise SystemExit("a mistyped recovery key opened the file")
            except KeyError_:
                pass
    assert missed <= 3, missed
    for bad in ["", "ABCD", text + "A", text[:-1], text.replace(text[0], "U", 1)]:
        try:
            decode_recovery(bad)
            raise SystemExit("accepted a bad recovery key")
        except KeyError_:
            pass

    # The recovery file opens with the right key and nothing else.
    blob = bytes.fromhex(v["blob"])
    assert len(blob) == 93
    assert open_blob(blob, V_RECOVERY) == V_MASTER
    try:
        open_blob(blob, bytes(16))
        raise SystemExit("opened with the wrong recovery key")
    except KeyError_ as e:
        assert str(e) == "wrong recovery key"
    for index in range(len(blob)):
        changed = bytearray(blob)
        changed[index] ^= 1
        try:
            open_blob(bytes(changed), V_RECOVERY)
            raise SystemExit("accepted a changed file at byte %d" % index)
        except KeyError_:
            pass
    for bad in [blob[:-1], blob + b"\x00", b""]:
        try:
            open_blob(bad, V_RECOVERY)
            raise SystemExit("accepted a file of the wrong length")
        except KeyError_:
            pass
    master = os.urandom(32)
    recovery = os.urandom(16)
    assert open_blob(make_blob(master, recovery), recovery) == master
    assert make_blob(master, recovery) != make_blob(master, recovery)

    # Sealed text.
    assert open_field(v["sealed"], V_CONTEXT, V_MASTER) == V_TEXT
    assert open_field(v["sealed"], "JournalEntry.title", V_MASTER) is None
    assert open_field(v["sealed"], V_CONTEXT, bytes(32)) is None
    assert open_field(V_TEXT, V_CONTEXT, V_MASTER) is None
    assert open_field(FIELD_PREFIX + "not base64!", V_CONTEXT, V_MASTER) is None
    assert open_field(FIELD_PREFIX, V_CONTEXT, V_MASTER) is None
    body = v["sealed"][len(FIELD_PREFIX):]
    for index in range(0, len(base64.b64decode(body))):
        raw = bytearray(base64.b64decode(body))
        raw[index] ^= 1
        assert open_field(FIELD_PREFIX + base64.b64encode(bytes(raw)).decode(), V_CONTEXT, V_MASTER) is None
    for text in ["", "a", "café", "\U0001F642 " * 50, "line one\nline two", FIELD_PREFIX + "abc"]:
        sealed = seal_field(text, "Field.x", master)
        assert open_field(sealed, "Field.x", master) == text
        assert seal_field(text, "Field.x", master) != sealed
    # Widget summaries: opens only with the right key, context and prefix, and a changed byte is refused.
    wkey = os.urandom(32)
    for context in ("WidgetSnapshot", "CounterItems"):
        for sample in (b"", b"[]", b'{"a":"caf\xc3\xa9"}', os.urandom(300)):
            first = seal_widget(sample, context, wkey)
            assert open_widget(first, context, wkey) == sample
            assert seal_widget(sample, context, wkey) != first
            assert open_widget(first, "Other", wkey) is None
            assert open_widget(first, context, os.urandom(32)) is None
            assert open_field(first, context, wkey) is None          # not a sealed text value
            raw = bytearray(base64.b64decode(first[len(WIDGET_PREFIX):]))
            raw[-1] ^= 1
            assert open_widget(WIDGET_PREFIX + base64.b64encode(bytes(raw)).decode(), context, wkey) is None
    assert open_widget(v["widgetSealed"], V_WIDGET_CONTEXT, V_MASTER) == V_WIDGET_JSON.encode("utf-8")
    assert open_widget(seal_field("x", "WidgetSnapshot", wkey), "WidgetSnapshot", wkey) is None
    print("ok")


def main(argv) -> int:
    if len(argv) >= 2 and argv[1] == "selftest":
        selftest()
        return 0
    if len(argv) >= 2 and argv[1] == "vectors":
        for name, value in vectors().items():
            print("%s=%s" % (name, value))
        return 0
    if len(argv) == 4 and argv[1] == "check-file":
        try:
            blob = open(argv[2], "rb").read()
            master = open_blob(blob, decode_recovery(argv[3]))
        except (OSError, KeyError_) as error:
            print("Could not open: %s" % error)
            return 1
        print("The recovery key opens this file. Key id %s." % key_id(master).hex())
        return 0
    print(__doc__)
    return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv))
