# Keyper v1 — derivation specification

**Status: frozen (2026-10-30).** Everything in §1–§2 and the vectors in §5 and
`test-vectors/email.tsv` are final. An implementation either reproduces them exactly or is not
Keyper v1. (v1 was first frozen on 2026-10-21; before any release, the email rule was made
strict on 2026-10-30, see §3.)

Keyper turns an **email** and a **secret** (a sentence the user remembers) into a standard
BIP39 recovery phrase. This document is normative: any implementation that follows it
produces the same phrase for the same inputs, forever. `reference/keyper.py` is an
independent implementation; `app-android/core` and `app-ios/KeyperCore` are the ones the Android
and iOS apps ship.

## 1. Inputs

| Input    | Type                    | Notes                                                        |
|----------|-------------------------|--------------------------------------------------------------|
| `email`  | Unicode string          | Identifies the person: a valid email address under the rule in §2. |
| `secret` | ASCII string            | The memorised sentence: `A`–`Z`, `a`–`z`, `0`–`9`, the 18 symbols `!@#$%^&*().,?-_+=/` and spaces; at least 12 characters, single spaces between words included. |
| `words`  | 12 or 24                | Length of the phrase.                                        |
| `domain` | 32 bytes                | The deployment's domain constant: fixed in the build, not entered by the user, public once the APK is distributed (§3, §4). |

## 2. Algorithm

```
S             = secret with leading and trailing spaces removed and
                every run of spaces made one                   -- at least 12 characters, each a space
                                                                or one of A–Z a–z 0–9
                                                                ! @ # $ % ^ & * ( ) . , ? - _ + = /
E             = NFKC(email) with leading and trailing U+0020
                spaces removed and A–Z mapped to a–z           -- must be a valid address (below)

P             = HMAC-SHA256(key = domain, message = S)
salt          = "keyper/v1:" ‖ E                                (ASCII)
K             = Argon2id(password = P, salt = salt,
                         t = 128, m = 1048576 KiB (1 GiB), p = 4, T = 32 bytes,
                         version = 0x13, secret = empty, associated data = empty)

entropy       = HMAC-SHA256(key = K, message = "keyper/v1 12 words")[0..16)   for 12 words
                HMAC-SHA256(key = K, message = "keyper/v1 24 words")[0..32)   for 24 words
phrase        = BIP39 encoding of entropy with the English wordlist
```

- **The secret is plain ASCII.** It is typed on Keyper's own keyboard, which offers exactly
  these 80 characters and a space bar. Case, the symbols and the spaces between words count;
  spaces at either end, and a second space in a row, do not.
  A secret with any other character is not a v1 secret, and implementations reject it.
- **The email keeps every character but case.** NFKC first folds compatibility forms
  (full-width `ａ` and `＠`, the ideographic space); then spaces at either end are removed and
  only the ASCII letters A–Z are lowercased. Nothing else is removed or changed. E is valid only
  if all of these hold, and implementations reject any other email:
  - at most 254 characters in all, and exactly one `@`, which splits E into a local part and a
    domain;
  - the local part has 1 to 64 characters, each one of `a`–`z`, `0`–`9`, `.`, `_`, `+`, `-`; it
    does not start or end with `.` and has no two `.` in a row;
  - the domain is two or more labels separated by `.`; each label has 1 to 63 characters, each one
    of `a`–`z`, `0`–`9`, `-`, and does not start or end with `-`; the last label contains at least
    one letter.

  A character outside these sets, such as a tab, a non-ASCII letter or a quote, makes E invalid;
  a domain with non-ASCII letters must be written in its punycode form (`xn--…`).
  `test-vectors/email.tsv` (made by `reference/make_email_vectors.py`) lists the edge cases.
  Different raw inputs can still give the same E, through NFKC and case; different addresses
  never do.
- **Argon2id** is RFC 9106. **BIP39** is the standard entropy → mnemonic encoding (SHA-256
  checksum, 11 bits per word, wordlist SHA-256 `2f5eed53…3b24dbda`).

The **domain ID** shown in the app is the first four bytes of `SHA-256(domain)` in upper-case
hex, as `XXXX-XXXX`. Two builds with the same ID produce the same phrases.

## 3. Design decisions

**Email as salt.** The salt makes the same secret produce unrelated phrases for different
people, and forces an attacker to attack one person at a time: no precomputed table works
against everyone. A salt must be unique and must be available again at recovery time without
being stored anywhere, so it has to be something the user already knows; an email address
fits. WarpWallet uses the same construction. The email is not secret, but it must be a real
address, which keeps out placeholders like `a` that many people would share.

**Several secrets per email.** Each different secret yields an independent phrase; nothing
is stored, so there is no index or account list.

**A fixed alphabet and Keyper's own keyboard.** Recovery must never fail because of how text
was typed, possibly years later, on another phone or another computer. A free Unicode sentence
invites a dozen invisible differences: full-width against half-width forms, `。` against `.`,
curly against straight quotes, zero-width spaces pasted from a note, normalisation that differs
between Unicode versions, and the system keyboard itself, which may learn, upload or alter what
it sees. Keyper removes all of them at the source: the secret is typed only on Keyper's own
keyboard, which offers the 80 characters above in a fixed layout on every phone, and every
computer keyboard can type the same characters for recovery. An extra space never matters: a
run of spaces counts as one and spaces at either end are dropped. Whether words are separated
does matter (`my cat` and `mycat` differ), as do case and the symbols, because they are part
of what the user chose. The 18 symbols are the ten above the digit keys and eight more that
cannot be mistaken for one another or for a letter: no quotes (curly and straight ones look
alike), no `|` or `\`, no `:` or `;`. Chinese is typed as pinyin.

**Every character of the email counts, except case.** The first freeze kept only the email's
letters and digits, so that dots and capitals could never break a recovery. That also made
different addresses share a salt (`ab@c.de` and `a@bc.de` both became `abcde`), accepted strings
that are not addresses at all, and let a mistyped address pass unnoticed. Before any release the
rule was made strict: E is the address as typed, and it must be valid. Only case is ignored,
because it never decides which mailbox an address is, and a user who typed `Alice@` once and
`alice@` later expects the same phrase. No provider's rules are applied (Gmail ignores dots and
`+` tags; others do not), so `a.b@gmail.com` and `ab@gmail.com` are different salts. A valid
address that is mistyped is still a different salt: the app's recovery drill, which asks for
both inputs again before the phrase is used, catches that.

**12 and 24 words are independent.** Both come from one slow derivation of K, but each length
is keyed from K separately, so one phrase reveals nothing about the other.

**A public domain constant, through HMAC.** Each deployment (each set of builds from one
source tree) has its own 32 random bytes, so the same sentence gives unrelated phrases in
different deployments, and no table built for another tool or deployment applies. It is not a
secret: anyone with the APK can read it, which is why it is not called a pepper. It keys an
HMAC of the secret rather than using Argon2's own `secret` input, because many Argon2
libraries (Python's argon2-cffi, Go's x/crypto, libsodium) do not expose that input; recovery
with standard tools must stay possible.

**Argon2id parameters.** Argon2id is the RFC 9106 recommendation for password hashing. The
goal is that guessing any reasonable secret is not worth it: a secret of about 48.4 bits should
already cost an attacker more than US$100 million in electricity alone (§4). Phrases are
generated rarely, so the derivation may take about a minute: 1 GiB × 128 passes, which the app
computes in about a minute on a Snapdragon 870 (Redmi K40); a minute of full load showed no
thermal throttling. For the same wait, more memory hurts GPUs more than more passes, because
fewer guesses fit in a GPU's memory at once, so memory is 1 GiB, which phones with 4 GB of RAM
or more can spare. Android caps the Java heap far below RAM (often 256–512 MB), so the app
keeps this memory in an anonymous off-heap mapping. Four lanes use the four fast cores most
phones have. A secret must have at least 12 characters; the rule is frozen with the rest of
v1, so it can never lock anyone out.

**An input-dependent computation path is already there.** Argon2id fills most of its memory
with *data-dependent addressing*: which blocks are read depends on the password, so different
secrets drive different memory access patterns, and the same secret always the same one. This
is the analysed, standard form of "the computation depends on the input". Hand-made branching
on top of it (choosing parameters or algorithms from the input) adds no cost for an attacker
who has the code, and adds ways to get it wrong.

**Why the algorithm itself is not secret.** The app *is* the algorithm, and an APK decompiles
in minutes. Keyper follows Kerckhoffs's principle: the method is public and the secret part
is the user's secret. The domain constant only stops attackers who have not seen the APK (§4);
once the APK is distributed, and certainly once it is on a store, it is public, adds no secret
entropy, and everything rests on the secret and the cost of each guess.

## 4. Security model

| The attacker has… | What still protects the phrase |
|---|---|
| the secret only (overheard, found written down) | the email, and the domain constant if the APK was never distributed |
| the APK and the email | the strength of the secret: every guess costs a 1 GiB × 128 Argon2id run |
| the APK, the email and the secret | nothing: that is the phrase |

**Cost of guessing.** Each guess moves about 383 GiB through memory (1048576 blocks; 2 KiB of
traffic per block in the first pass, 3 KiB in the other 127). Memory bandwidth alone caps an
RTX 4090 (1 TB/s, 450 W) near 2.5 guesses per second at about 180 J each, and an 8 TB/s, 1 kW
data-centre GPU near 20 per second at about 50 J. The app's meter assumes 20 guesses per
second at 40 J per guess and electricity at US$0.05 per kWh, all in the attacker's favour:
about US$0.00000056 per guess. On average an attacker searches half of the space:

| Secret entropy | 1000 top GPUs   | Electricity alone |
|---------------:|----------------:|------------------:|
| 30 bits        | 7.5 hours       | US$300            |
| 40 bits        | 320 days        | US$305 000        |
| 50 bits        | 890 years       | US$313 million    |
| 60 bits        | 910 000 years   | US$320 billion    |

The hardware is not included: a thousand such GPUs alone cost tens of millions of dollars.

What matters is not how many characters a secret has, but how many candidates an attacker who
knows people must try before reaching it. A famous line, a lyric, a proverb or a template of
public facts ("my cat X, born Y") sits among an attacker's first thousands or millions of
guesses, whatever its length: at the costs above that is a few dollars. Only a sentence built
from details nobody else knows reaches the bottom rows of the table.

The app's strength meter is a hint, not part of the protocol, and can be improved at any time.
It charges what natural language carries against a language model: about 1.5 bits per
lowercase letter of an English or pinyin sentence (a random one would carry 4.7), a little
more for capitals, digits and symbols, nothing for the spaces between words, and almost nothing
for repetition and runs. It cannot recognise famous lines, so it still overrates them. It warns
(never refuses) when the attack would cost less than US$100 million; only the frozen minimum
lengths are enforced.

**The domain constant is a single point of failure for recovery.** Every phrase depends on it.
Back it up as carefully as a seed phrase (the signed APK contains it too). If a new build uses a
different domain constant, the domain ID in the footer changes and so does every phrase.

## 5. Test vectors

`domain = 000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f`
(domain ID `630D-CD29`). This is a test constant; the app shows a warning banner when built with it.

| email | secret | K (hex) |
|---|---|---|
| `alice@example.com` | `correct horse battery staple` | `a635fff88c3d798c504edad2ec95c5d9f276d9d05bd193d840778d1993dcdfcb` |
| `␠␠Alice@Example.COM␠` | `correct horse␠␠battery staple␠` | same as above |
| `alice@example.com` | `Correct horse battery staple` | `b31450fc7df5731d49e358014def9866672a0d3f510ae729fb8e25aa6800dd47` |
| `bob@example.com` | `correct horse battery staple` | `f423d8b47d734f59d3f91e9bdfcb02ceb7494f8355acabc3c93d0d18f0c34368` |
| `a.lice+keyper@example.com` | `Wo de di yi zhi mao jiao MiMi!` | `2a089c83e6b0e9199992a853177cfb2024715c00674bbe3998dedeadf6283ab7` |
| `ＡＢＣ.def@MAIL.com` | `In 2009 (summer) Grandma Li & me @ 7am #42 $5 50%*^` | `1cb9e296dd2c02b44a48e31adb72af2a4ef08691bd85806652d2f812435b8540` |
| `carol@example.org` | `Pi is 3.14, right? x+y=z / a-b_c` | `937e3afe0e3066aade6b8896faab4ae7fe5c0ce84657776372b53ad622bb1529` |

The email rule's edge cases, valid and invalid, are in `test-vectors/email.tsv`.

Phrases:

```
alice / correct horse battery staple
  12: bright blood connect stomach they proof cover armor usual adult clip hen
  24: evoke tiger live cycle donkey appear struggle gaze surround solid industry source brush
      hover daughter rib mobile tissue dwarf example unfold seven cook fiscal

alice / Correct horse battery staple
  12: purpose sight afford hill tourist trap whale join error fog exhaust whip
  24: arrange anger swing glide armor hip master tourist science view panic fork thought police
      unique control crack panic stem finger advice govern little fire

bob / correct horse battery staple
  12: expose ripple enjoy test buddy fine cheap like minute swing egg donkey
  24: eyebrow mule item news various message ladder maple trim census magnet endorse sudden young
      road blossom hybrid judge hammer tell address defense moral question

a.lice+keyper / Wo de di yi zhi mao jiao MiMi!
  12: differ talent quantum quiz coil alone cost unhappy enhance pave solution square
  24: best better ostrich report walnut this blade quiz torch army state shaft debate try legend
      merit minor lyrics donkey eyebrow quiz require quick pottery

ＡＢＣ / In 2009 (summer) Grandma Li & me @ 7am #42 $5 50%*^
  12: park buddy sibling drip possible acoustic sniff unknown faith open drama abuse
  24: will awesome face pink bullet distance control plunge other basket frog wood duck ivory base
      vintage broken broken across solution race cheap later grocery

carol / Pi is 3.14, right? x+y=z / a-b_c
  12: stairs bone hamster universe fury salmon million opera cliff mask supply damage
  24: burger rather afraid robot luggage amateur people frame clog review clump bacon heavy
      giraffe someone armed soap shaft town virus crouch about window able
```

## 6. Versioning

Every constant above — the alphabet, normalisation, the email rule, length limits, salt prefix, Argon2
parameters, the two HMAC labels, wordlist — is part of v1. Changing any of them is a new version with a new salt prefix (`keyper/v2:`),
and an implementation must keep producing v1 phrases for as long as anyone may need them.
