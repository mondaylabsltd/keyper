#!/usr/bin/env python3
"""Regenerates test-vectors/email.tsv, the email rule's edge cases (SPEC §2), from keyper.py.

Each row is an input, as UTF-8 hex so that spaces, tabs and full-width forms survive the file,
the normalized email or "-" when the input is not a valid address, and a note. The Kotlin, Swift
and Python implementations must agree on every row.

    python3 make_email_vectors.py
"""
import os

from keyper import normalize_email

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "test-vectors", "email.tsv")

CASES = [
    # Valid, unchanged.
    ("alice@example.com", "plain"),
    ("a.b@gmail.com", "dots count"),
    ("ab@gmail.com", "differs from a.b@gmail.com"),
    ("alice+work@gmail.com", "+ tags count"),
    ("alicework@gmail.com", "differs from alice+work@gmail.com"),
    ("ab@c.de", "differs from a@bc.de"),
    ("a@bc.de", "differs from ab@c.de"),
    ("first_last-1@sub.example.co.uk", "_ and - in the local part, several labels"),
    ("x@y.io", "short"),
    ("-a_+b@example.com", "local part may start with - or _ or contain +"),
    ("user@xn--fsqu00a.xn--fiqs8s", "punycode domain"),
    ("user@123.example.c0m", "digits in labels; the last label has a letter"),
    ("user@a-b.example.com", "inner hyphen"),
    # Valid, normalized.
    ("Alice@Example.COM", "ASCII case folded"),
    ("  alice@example.com   ", "surrounding spaces dropped"),
    ("\u3000alice@example.com\u3000", "ideographic spaces become spaces under NFKC, then dropped"),
    ("\uff21\uff22\uff23.def@\uff2d\uff21\uff29\uff2c.com", "full-width forms folded by NFKC"),
    ("alice\uff20example.com", "full-width @"),
    ("alice\ufe6bexample.com", "small @"),
    # Length limits.
    ("a" * 64 + "@example.com", "64-character local part"),
    ("a" * 65 + "@example.com", "65-character local part"),
    ("a@" + "b" * 63 + ".com", "63-character label"),
    ("a@" + "b" * 64 + ".com", "64-character label"),
    ("a@" + ".".join(["b" * 63] * 3) + "." + "c" * 61, "a 253-character domain makes 255 in all"),
    ("a@" + ".".join(["b" * 63] * 3) + "." + "c" * 59, "253 in all"),
    ("ab@" + ".".join(["b" * 63] * 3) + "." + "c" * 59, "254 in all"),
    ("abc@" + ".".join(["b" * 63] * 3) + "." + "c" * 59, "255 in all"),
    # Invalid.
    ("", "empty"),
    ("   ", "only spaces"),
    ("alice", "no @"),
    ("alice@", "no domain"),
    ("@example.com", "no local part"),
    ("alice@example", "one label"),
    ("alice@@example.com", "two @"),
    ("a@b@example.com", "two @"),
    (".alice@example.com", "leading dot"),
    ("alice.@example.com", "trailing dot"),
    ("al..ice@example.com", "two dots in a row"),
    ("alice@-example.com", "label starts with -"),
    ("alice@example-.com", "label ends with -"),
    ("alice@example..com", "empty label"),
    ("alice@.example.com", "empty first label"),
    ("alice@example.com.", "trailing dot in the domain"),
    ("alice@example.123", "all-digit last label"),
    ("alice smith@example.com", "inner space"),
    ("alice@exa_mple.com", "_ in the domain"),
    ("alice@exa+mple.com", "+ in the domain"),
    ("alice!@example.com", "! is not allowed"),
    ("\"alice\"@example.com", "quoted local parts are not allowed"),
    ("al\u00efce@example.com", "non-ASCII letter"),
    ("alice@\u4f8b\u5b50.\u4e2d\u56fd", "non-ASCII domain: use its punycode"),
    ("alice@example.com\t", "a tab is not a space"),
    ("alice@example.com\n", "a newline is not a space"),
    ("alice@[192.168.0.1]", "address literals are not allowed"),
    ("+86 138-0000-0000", "a phone number is not an email"),
]


def main() -> None:
    with open(OUT, "w") as f:
        f.write("# input_utf8_hex\tnormalized_or_dash\tnote\n")
        for raw, note in CASES:
            e = normalize_email(raw)
            f.write(f"{raw.encode().hex()}\t{e if e is not None else '-'}\t{note}\n")
    print(f"{len(CASES)} cases written to {os.path.relpath(OUT)}")


if __name__ == "__main__":
    main()
