#!/usr/bin/env python3
"""Regenerates test-vectors/*.tsv, shared by the Android and iOS cores, from independent implementations:

  argon2id.tsv  argon2-cffi (RFC 9106 reference C code), random parameters
  bip39.tsv     Trezor's python-mnemonic test vectors (vectors.json, English)
  qr.tsv        segno, byte mode, level M, every version 1..40 and every mask

    pip install -r requirements.txt
    python3 make_fixtures.py path/to/trezor/vectors.json   # github.com/trezor/python-mnemonic
"""
import json
import os
import random
import string
import sys

import segno
from argon2.low_level import Type, hash_secret_raw

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "test-vectors")


def write(name, header, rows):
    with open(os.path.join(OUT, name), "w") as f:
        f.write("# " + "\t".join(header) + "\n")
        for r in rows:
            f.write("\t".join(map(str, r)) + "\n")


def argon2(rng):
    rows = []
    for _ in range(48):
        p = rng.randint(1, 8)
        m = rng.randint(8 * p, 3000)  # often not a multiple of 4p, which exercises rounding
        t = rng.randint(1, 4)
        password = rng.randbytes(rng.randint(0, 64))
        salt = rng.randbytes(rng.randint(8, 40))
        tag = rng.choice([4, 16, 32, 63, 64, 65, 96, 129])  # both sides of H''s 64-byte switch
        h = hash_secret_raw(password, salt, t, m, p, tag, Type.ID, version=0x13)
        rows.append([t, m, p, password.hex(), salt.hex(), tag, h.hex()])
    write("argon2id.tsv", ["t", "m_kib", "p", "password", "salt", "tag_len", "tag"], rows)


def bip39(vectors_json):
    with open(vectors_json) as f:
        english = json.load(f)["english"]
    write("bip39.tsv", ["entropy", "mnemonic"], [[e, m] for e, m, *_ in english])


def qr(rng):
    alphabet = string.ascii_lowercase + string.digits + " "
    rows = []

    def add(text, mask):
        q = segno.make(text, error="m", mode="byte", mask=mask, boost_error=False, micro=False)
        assert q.error == "M" and q.mask == mask
        bits = "".join(str(b) for row in q.matrix for b in row)
        bits += "0" * (-len(bits) % 4)
        rows.append([text, q.version, mask, f"{int(bits, 2):0{len(bits) // 4}x}"])

    for version in range(1, 41):
        # Longest text that still fits this version, so the encoder must pick it.
        lo, hi = 1, 3000
        while lo < hi:
            mid = (lo + hi + 1) // 2
            try:
                segno.make("a" * mid, error="m", mode="byte", version=version, boost_error=False, micro=False)
                lo = mid
            except segno.DataOverflowError:
                hi = mid - 1
        text = "".join(rng.choice(alphabet) for _ in range(lo))
        masks = range(8) if version in (1, 2, 7, 10, 11) else [version % 8]
        for mask in masks:
            add(text, mask)
    write("qr.tsv", ["text", "version", "mask", "modules_row_major_hex"], rows)


if __name__ == "__main__":
    rng = random.Random(20261021)
    argon2(rng)
    bip39(sys.argv[1])
    qr(rng)
