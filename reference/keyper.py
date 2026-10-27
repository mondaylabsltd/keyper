#!/usr/bin/env python3
"""Keyper v1 reference implementation (see SPEC.md).

Independent of the Android code: Argon2id comes from argon2-cffi (the RFC 9106
reference C implementation) and BIP39 from Trezor's python-mnemonic. Use it to
cross-check the app, or to recover mnemonics without the app if you still have
the domain constant.

    pip install --require-hashes -r requirements-recovery.txt
    python3 keyper.py --domain-file ../app-android/app/src/main/kotlin/app/getkeyper/Domain.kt
    python3 keyper.py --self-test    # checks SPEC.md's vectors
"""
import argparse
import getpass
import hashlib
import hmac
import re
import string
import sys
import unicodedata

from argon2.low_level import Type, hash_secret_raw
from mnemonic import Mnemonic

ITERATIONS = 128
MEMORY_KIB = 1024 * 1024
PARALLELISM = 4
MIN_SECRET_LENGTH = 12  # characters of the normalized secret
MIN_EMAIL_LENGTH = 6  # ASCII letters and digits of the email
SECRET_CHARS = set(string.ascii_letters + string.digits + "!@#$%^&*().,?-_+=/")
SALT_PREFIX = "keyper/v1:"


def normalize_secret(s: str) -> str:
    """Leading and trailing spaces dropped, runs of spaces made one; everything else significant."""
    return re.sub(" +", " ", s.strip(" "))


def normalize_email(s: str) -> str:
    """NFKC, then only ASCII letters and digits, lowercased."""
    return "".join(c for c in unicodedata.normalize("NFKC", s) if c in string.ascii_letters + string.digits).lower()


def derive_key(email: str, secret: str, domain: bytes) -> bytes:
    e, s = normalize_email(email), normalize_secret(secret)
    if len(e) < MIN_EMAIL_LENGTH:
        raise ValueError(f"the email needs at least {MIN_EMAIL_LENGTH} ASCII letters or digits")
    if not set(s) <= SECRET_CHARS | {" "} or len(s) < MIN_SECRET_LENGTH:
        raise ValueError(f"the secret needs at least {MIN_SECRET_LENGTH} of: ASCII letters, digits, !@#$%^&*().,?-_+=/ (and spaces)")
    if len(domain) != 32:
        raise ValueError("the domain must be 32 bytes")
    password = hmac.new(domain, s.encode(), hashlib.sha256).digest()
    salt = (SALT_PREFIX + e).encode()
    return hash_secret_raw(password, salt, ITERATIONS, MEMORY_KIB, PARALLELISM, 32, Type.ID, version=0x13)


def mnemonic(key: bytes, words: int) -> str:
    if words not in (12, 24):
        raise ValueError("words must be 12 or 24")
    entropy = hmac.new(key, f"keyper/v1 {words} words".encode(), hashlib.sha256).digest()
    return Mnemonic("english").to_mnemonic(entropy[: words // 3 * 4])


def domain_id(domain: bytes) -> str:
    h = hashlib.sha256(domain).hexdigest().upper()
    return f"{h[0:4]}-{h[4:8]}"


# The official Keyper's domain ID (Domain.kt, Domain.swift).
OFFICIAL_DOMAIN_ID = "A248-7EAB"

# Mirrored in SPEC.md, KeyperTest.kt and the Swift core's tests.
TEST_DOMAIN = bytes(range(32))
VECTORS = [
    ("alice@example.com", "correct horse battery staple"),
    # Same as the first: the email's case, dots and spaces drop out; extra spaces in the secret count as one.
    ("  Alice@Example.COM ", "correct horse  battery staple "),
    ("alice@example.com", "Correct horse battery staple"),  # case counts in the secret
    ("bob@example.com", "correct horse battery staple"),
    ("+86 138-0000-0000", "Wo de di yi zhi mao jiao MiMi!"),
    ("\uff21\uff22\uff23.def@MAIL.com", "In 2009 (summer) Grandma Li & me @ 7am #42 $5 50%*^"),
    ("carol@example.org", "Pi is 3.14, right? x+y=z / a-b_c"),  # the other eight symbols
]


def self_test(expected) -> bool:
    ok = True
    for (email, secret), (m12, m24) in zip(VECTORS, expected):
        key = derive_key(email, secret, TEST_DOMAIN)
        got = (mnemonic(key, 12), mnemonic(key, 24))
        if got != (m12, m24):
            ok = False
            print(f"MISMATCH {email!r} {secret!r}\n  got      {got}\n  expected {(m12, m24)}")
    print("domain id", domain_id(TEST_DOMAIN))
    print("self-test", "passed" if ok else "FAILED")
    return ok


EXPECTED = [  # (12 words, 24 words) for each of VECTORS
    ("anchor amount there travel play salmon require soon crawl jelly index toddler",
     "hair pattern foam equip ethics gather margin trouble cheese lobster void employ mammal city apple lawn duck upgrade permit almost hurry list tortoise already"),
    ("anchor amount there travel play salmon require soon crawl jelly index toddler",
     "hair pattern foam equip ethics gather margin trouble cheese lobster void employ mammal city apple lawn duck upgrade permit almost hurry list tortoise already"),
    ("catalog soft salon best lock toy pool spend cool goat cradle vault",
     "trust spawn idle adult genius spider inner desert dignity weird chimney busy pledge become way dice water track teach machine vast potato burst swear"),
    ("spirit intact corn food lumber enrich bunker surface loan fatal eye mobile",
     "robot push razor sad father usage blind roof tennis tomato amazing blossom faculty spoon finger math claw hub hold diary knock merge base track"),
    ("buddy piano cluster cupboard crime luggage fall twenty olive choice nest crash",
     "essay game shove common length fatal window vote gesture east enemy direct biology equip exercise route return uncle target exercise firm style fly afford"),
    ("sunset ginger poverty wage chef ritual craft donkey solid list safe heavy",
     "elder cost screen manage question message siren setup express decrease spin brass woman curve stamp ecology large pyramid brother spray blur poem rocket state"),
    ("regret bench ticket bitter enforce dress skull aunt shiver maple friend spend",
     "canvas two army sugar pact dry design typical rib million supply baby merge siren shell beyond rack shallow sample salon melt orient box close"),
]


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--domain-file", help="Domain.kt, or any file holding the domain constant as 64 hex digits")
    ap.add_argument("--words", type=int, choices=(12, 24), default=12)
    ap.add_argument("--self-test", action="store_true")
    ap.add_argument("--print-vectors", action="store_true", help="print the test vectors (for SPEC.md)")
    args = ap.parse_args()

    if args.print_vectors:
        print("domain", TEST_DOMAIN.hex(), "id", domain_id(TEST_DOMAIN))
        for email, secret in VECTORS:
            key = derive_key(email, secret, TEST_DOMAIN)
            print(repr(email), repr(secret), key.hex(), mnemonic(key, 12), mnemonic(key, 24), sep="\n  ")
        return
    if args.self_test:
        sys.exit(0 if self_test(EXPECTED) else 1)
    if not args.domain_file:
        ap.error("--domain-file is required")
    with open(args.domain_file) as f:
        found = set(re.findall(r"\b[0-9a-fA-F]{64}\b", f.read()))
    if len(found) != 1:
        ap.error(f"{args.domain_file} must hold exactly one 64-digit hex domain constant, found {len(found)}")
    domain = bytes.fromhex(found.pop())
    if domain == TEST_DOMAIN:
        ap.error("that is SPEC's test domain constant, not a real deployment's; pass Domain.kt or Domain.swift")
    official = domain_id(domain) == OFFICIAL_DOMAIN_ID
    print("domain id", domain_id(domain), "(official Keyper)" if official else "(NOT the official Keyper)", file=sys.stderr)
    # The sentence is not echoed, so it is asked twice: one typo would silently give another phrase.
    email = input("email: ")
    secret = getpass.getpass("sentence: ")
    if getpass.getpass("sentence again: ") != secret:
        sys.exit("the two sentences differ; nothing derived")
    try:
        print(mnemonic(derive_key(email, secret, domain), args.words))
    except ValueError as e:
        sys.exit(str(e))

if __name__ == "__main__":
    main()
