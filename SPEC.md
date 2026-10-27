# Keyper v1 — derivation specification

**Status: frozen (2026-10-21).** Everything in §1–§2 and the vectors in §5 are final. An
implementation either reproduces the §5 vectors exactly or is not Keyper v1.

Keyper turns an **email** and a **secret** (a sentence the user remembers) into a standard
BIP39 recovery phrase. This document is normative: any implementation that follows it
produces the same phrase for the same inputs, forever. `reference/keyper.py` is an
independent implementation; `app-android/core` and `app-ios/KeyperCore` are the ones the Android
and iOS apps ship.

## 1. Inputs

| Input    | Type                    | Notes                                                        |
|----------|-------------------------|--------------------------------------------------------------|
| `email`  | Unicode string          | Identifies the person; at least 6 ASCII letters or digits. An email or phone number is easy to remember and unique. |
| `secret` | ASCII string            | The memorised sentence: `A`–`Z`, `a`–`z`, `0`–`9`, the 18 symbols `!@#$%^&*().,?-_+=/` and spaces; at least 12 characters, single spaces between words included. |
| `words`  | 12 or 24                | Length of the phrase.                                        |
| `domain` | 32 bytes                | The deployment's domain constant: fixed in the build, not entered by the user, public once the APK is distributed (§3, §4). |

## 2. Algorithm

```
S             = secret with leading and trailing spaces removed and
                every run of spaces made one                   -- at least 12 characters, each a space
                                                                or one of A–Z a–z 0–9
                                                                ! @ # $ % ^ & * ( ) . , ? - _ + = /
E             = NFKC(email), keeping only ASCII A–Z a–z 0–9,
                with A–Z mapped to a–z                         -- at least 6 characters

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
- **The email only salts.** NFKC first folds full-width forms (`１３８` → `138`), then
  everything but ASCII letters and digits is dropped and letters are lowercased. The fold
  concerns compatibility characters that are decades old, so in practice no Unicode version
  question arises; an email should simply be typed in plain ASCII.
- **Argon2id** is RFC 9106. **BIP39** is the standard entropy → mnemonic encoding (SHA-256
  checksum, 11 bits per word, wordlist SHA-256 `2f5eed53…3b24dbda`).

The **domain ID** shown in the app is the first four bytes of `SHA-256(domain)` in upper-case
hex, as `XXXX-XXXX`. Two builds with the same ID produce the same phrases.

## 3. Design decisions

**Email as salt.** The salt makes the same secret produce unrelated phrases for different
people, and forces an attacker to attack one person at a time: no precomputed table works
against everyone. A salt must be unique and must be available again at recovery time without
being stored anywhere, so it has to be something the user already knows; an email address
fits. WarpWallet uses the same construction. The email is not secret; a phone number works as
well. At least six letters or digits keep out placeholders like `a`, which many people would
share.

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

**The email only salts, so it forgives.** Dots, dashes, spaces, `+` tags and capitals drop out:
`138-0000-0000` equals `13800000000`, and a Gmail address equals itself without its dots.

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
| `alice@example.com` | `correct horse battery staple` | `127ed582829bb66d20e2a075c691722dbd582ec8cd4dc7c783cdff609f636a2d` |
| `␠␠Alice@Example.COM␠` | `correct horse␠␠battery staple␠` | same as above |
| `alice@example.com` | `Correct horse battery staple` | `fb5495320579be258b82bde05db61f3717695e6643a6f130b954b61f58413b5e` |
| `bob@example.com` | `correct horse battery staple` | `ddd3a82317283ac110a07874b1e26751f7879e0cd242a6d57f92cff47bb49434` |
| `+86 138-0000-0000` | `Wo de di yi zhi mao jiao MiMi!` | `61e3a82980320163e34008fb705a0670ca7ecc3cb42641a2a42f828fb345ab50` |
| `ＡＢＣ.def@MAIL.com` | `In 2009 (summer) Grandma Li & me @ 7am #42 $5 50%*^` | `51d25d0e0f665370dd965c15bd8db5a8767b501419365801de1fc72fbb42bcbe` |
| `carol@example.org` | `Pi is 3.14, right? x+y=z / a-b_c` | `8fb415ba4c2a4940ff140d0ce5955f1280e5acf910d7a7c11f43198bbb532366` |

Phrases:

```
alice / correct horse battery staple
  12: anchor amount there travel play salmon require soon crawl jelly index toddler
  24: hair pattern foam equip ethics gather margin trouble cheese lobster void employ mammal city
      apple lawn duck upgrade permit almost hurry list tortoise already

alice / Correct horse battery staple
  12: catalog soft salon best lock toy pool spend cool goat cradle vault
  24: trust spawn idle adult genius spider inner desert dignity weird chimney busy pledge become
      way dice water track teach machine vast potato burst swear

bob / correct horse battery staple
  12: spirit intact corn food lumber enrich bunker surface loan fatal eye mobile
  24: robot push razor sad father usage blind roof tennis tomato amazing blossom faculty spoon
      finger math claw hub hold diary knock merge base track

+86 / Wo de di yi zhi mao jiao MiMi!
  12: buddy piano cluster cupboard crime luggage fall twenty olive choice nest crash
  24: essay game shove common length fatal window vote gesture east enemy direct biology equip
      exercise route return uncle target exercise firm style fly afford

ＡＢＣ / In 2009 (summer) Grandma Li & me @ 7am #42 $5 50%*^
  12: sunset ginger poverty wage chef ritual craft donkey solid list safe heavy
  24: elder cost screen manage question message siren setup express decrease spin brass woman curve
      stamp ecology large pyramid brother spray blur poem rocket state

carol / Pi is 3.14, right? x+y=z / a-b_c
  12: regret bench ticket bitter enforce dress skull aunt shiver maple friend spend
  24: canvas two army sugar pact dry design typical rib million supply baby merge siren
      shell beyond rack shallow sample salon melt orient box close
```

## 6. Versioning

Every constant above — the alphabet, normalisation, minimum lengths, salt prefix, Argon2
parameters, the two HMAC labels, wordlist — is part of v1. Changing any of them is a new version with a new salt prefix (`keyper/v2:`),
and an implementation must keep producing v1 phrases for as long as anyone may need them.
