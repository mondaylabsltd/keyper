# Keyper

**A recovery phrase you keep in your head.** On an offline Android phone, Keyper turns your
email and a sentence only you know into a standard BIP39 recovery phrase. The same inputs give
the same phrase, forever, so there is nothing to write down and nothing is stored.

English · [简体中文](README-zh.md)

<p align="center">
  <img src="docs/images/en-input.png" width="260" alt="Typing the sentence on Keyper's own keyboard">
  <img src="docs/images/en-result.png" width="260" alt="A 12-word recovery phrase">
  <img src="docs/images/en-offline.png" width="260" alt="The offline gate">
</p>

- **Standard output.** BIP39 phrases of 12 or 24 words, usable with any wallet.
- **Expensive to guess.** Every guess costs an Argon2id run over 1 GiB of memory, 128 passes:
  about a minute on a Snapdragon 870. For a sentence of about 48 bits of entropy, the
  attacker's electricity bill alone passes US$100 million.
- **Its own keyboard.** Both fields are typed only on Keyper's keyboard. The system keyboard
  never connects, so it cannot learn, sync or upload what you type.
- **Offline gate.** You can only type and generate with airplane mode on and Wi-Fi and
  Bluetooth off. Going back online wipes everything at once.
- **Nothing stored, nothing requested.** No permissions, no storage, no network, no
  third-party runtime dependencies. The release APK is about 90 KB.
- **Recovery drill.** Re-type both inputs from memory and confirm on the spot that you can
  recover the phrase later.
- **Open protocol.** [SPEC.md](SPEC.md) defines the derivation exactly (v1 is frozen), and an
  independent [Python implementation](reference/keyper.py) reproduces it.

Requires Android 8.1 (API 27) or later and 4 GB of RAM or more. English and Chinese.

## How it works

```
email ──── keep ASCII letters and digits, lowercase ──────────────┐ salt
sentence ─ collapse extra spaces ─ HMAC-SHA256(domain) ─ Argon2id(1 GiB × 128) ─── K ─┬─ HMAC ─ 12 words
                                                                                      └─ HMAC ─ 24 words
```

- **The sentence uses 80 characters**: `A`–`Z`, `a`–`z`, `0`–`9` and 18 symbols
  `! @ # $ % ^ & * ( ) . , ? - _ + = /`. Case, symbols and the spaces between words count;
  extra spaces (runs of spaces, spaces at either end) do not. There are no quotes, `|`, `\`,
  `:` or `;`, which are easy to mistype or misread. Other languages are written in Latin
  letters, for example pinyin: `Wo de di yi zhi mao jiao MiMi!`
- **The email is only a salt.** Case, dots, dashes and spaces drop out, so `138-0000-0000`
  and `13800000000` are the same. A phone number works as well.
- **12 and 24 words are independent.** Knowing one tells nothing about the other.
- **The domain constant** is 32 random bytes in
  [`Domain.kt`](app-android/app/src/main/kotlin/app/getkeyper/Domain.kt). It makes the same
  sentence give different phrases in different deployments. It ships inside the APK, so it
  is public, not a secret.

The email-as-salt construction is the standard one (WarpWallet uses it too): the same sentence
gives unrelated phrases for different people, and an attacker has to attack one person at a
time. One email can go with several sentences, each giving its own phrase. There is no account
and no index.

### The keyboard

```
letters                         digits and symbols
q w e r t y u i o p            1 2 3 4 5 6 7 8 9 0
 a s d f g h j k l             ! @ # $ % ^ & * ( )
⇧ z x c v b n m ⌫              . , ? - _ + = /  ⌫
123 [   space   ] Done          ABC [   space   ] Done
```

- Identical on every phone: fixed QWERTY, fixed sizes that ignore the system font scale, and a
  monospace face that tells `0`/`O` and `1`/`l`/`I` apart. The email gets `@` and `.` on the
  bottom row and a Next key.
- Touch works as on the iPhone. Every point belongs to its nearest key, so taps between keys
  still type. The key under your finger pops up magnified and types when you lift, so you can
  slide to the right key first. A second finger landing types the first one's key at once, so
  fast two-thumb typing keeps its order. ⇧, ⌫ and 123 act on touch-down.
- ⇧ once for one capital, twice for caps lock; hold ⌫ to keep deleting; Back closes the
  keyboard. Edge swipes over the keyboard are not taken as Back.
- The cursor is Android's own: tap to place it, drag it or its handle to move it, with the
  magnifier.
- The fields give the system keyboard no connection at all. Paste, the long-press menu,
  drag-and-drop, hardware keys and injected key events are all blocked.

## Security model: read this first

| An attacker has… | What still protects the phrase |
|---|---|
| only your sentence | your email, and the domain constant if the APK was never distributed |
| the APK and your email | how hard your sentence is to guess: every guess costs 1 GiB × 128 passes |
| the APK, your email and your sentence | nothing: together they are the phrase |

1. **Once the APK is out, the domain constant is public.** From then on only the sentence
   stands between an attacker and the phrase.
2. **Hard to guess is not the same as long.** Famous lines, lyrics, proverbs and templates like
   "my cat is called X" are an attacker's first guesses and fall for a few dollars of
   electricity. Use details only you know: names, years, places, numbers, a symbol or two.

   | Entropy of the sentence | 1000 top GPUs | Electricity alone |
   |---:|---:|---:|
   | 30 bits | 7.5 hours | US$300 |
   | 40 bits | 320 days | US$305,000 |
   | 50 bits | 890 years | US$313 million |
   | 60 bits | 910,000 years | US$320 billion |

   The app estimates this while you type, using assumptions that favour the attacker
   ([SPEC.md §4](SPEC.md#4-security-model)). Below US$100 million it warns you before
   generating, but it cannot recognise famous lines, so don't use one.
3. **Do the recovery drill before you move funds.** After generating, tap "First time? Do a
   recovery drill" and re-type both inputs from memory.
4. **If the domain constant is lost or changed, no phrase can ever be regenerated.** See
   [Building and maintaining](#building-and-maintaining).

Other protections: screenshots and screen recording are blocked, and the app is blank in
Recents. Leaving the app wipes the sentence and the phrase. On Android 14+ the sentence, the
phrase and the keyboard are hidden from accessibility services. A copied phrase is marked
sensitive and cleared from the clipboard after 60 seconds. The QR code screen blocks screenshots
on its own, and autofill services are excluded.

The **offline gate** reads airplane mode, the Wi-Fi setting and the live Bluetooth adapter
state, none of which needs a permission, every half second while the app is in front. Each
unmet condition is a link to the matching system settings screen. On **Xiaomi phones
(HyperOS)** the Control Center Bluetooth button only stops new connections and leaves the radio
on: turn Bluetooth off in Settings → Bluetooth.

The full audit and the attack scenarios are in [docs/security-audit.md](docs/security-audit.md).
To report a vulnerability, see [SECURITY.md](SECURITY.md).

## Using Keyper

1. Turn on airplane mode, and turn off Wi-Fi and Bluetooth.
2. Type your email on Keyper's keyboard, tap Next, then type your sentence. Tap Show to check it.
3. Choose 12 or 24 words and tap Generate. It takes about a minute.
4. The first time you use a sentence, do the recovery drill.
5. **Copy** the phrase into a wallet app on the same phone (the clipboard clears after 60
   seconds), or show the **QR code** to another device.
6. The footer shows the build's domain ID (`A248-7EAB` for this repository). The same ID means
   the same phrases. If it ever changes, **stop** and find out why before using the phrase.

## Building and maintaining

You need JDK 17 or later and the Android SDK (compileSdk 36).

```sh
cd app-android
./gradlew :core:test :app:testDebugUnitTest :app:lintDebug :app:assembleRelease
# app/build/outputs/apk/release/app-release.apk
```

The core tests run the SPEC vectors with the full 1 GiB Argon2id and take a few minutes.

- **The protocol is frozen.** `KeyperTest.protocolV1IsFrozen` pins every protocol constant and
  the SPEC vectors pin the outputs. A change that alters any v1 phrase fails the build.
- **Never change the domain constant** in
  [`Domain.kt`](app-android/app/src/main/kotlin/app/getkeyper/Domain.kt) (domain ID
  `A248-7EAB`); `DomainTest` pins it. Keep offline copies of this repository and of every
  released APK: both contain the constant.
- **Deploying your own Keyper?** Replace the constant with `openssl rand -hex 32` before anyone
  uses your build, and update `DomainTest`. Phrases from different deployments are unrelated.
- **Release signing** reads `app-android/keystore.properties` (`storeFile`, `storePassword`,
  `keyAlias`, `keyPassword`; git-ignored). Without it, release builds are signed with the debug
  key. Before distributing, configure your own key and publish the SHA-256 of its certificate.
- A build that carries SPEC's test domain constant shows a red "Test build" banner.
- **App stores.** Updates arrive automatically, and a new version can add permissions without
  asking, so the store account is part of the trust chain: protect it with two-factor
  authentication, and turn off auto-update for Keyper on the offline phone. Google Play's crypto
  policy targets custodial services; Keyper holds no assets, but check the current policy before
  submitting. Personal developer accounts created after November 2023 must first run a closed
  test with at least 12 testers for 14 days.

### Recovering without the app

With the domain constant, the independent Python implementation derives the same phrase (about
25 seconds on a laptop):

```sh
pip install -r reference/requirements.txt
python3 reference/keyper.py --domain-file app-android/app/src/main/kotlin/app/getkeyper/Domain.kt --words 12
python3 reference/keyper.py --self-test    # checks the vectors in SPEC.md
```

## Verification

| What | How | Result |
|---|---|---|
| Argon2id, BLAKE2b | RFC 9106 and RFC 7693 vectors; 48 random parameter sets against argon2-cffi (the RFC reference C code) | all equal |
| BIP39 | SHA-256 of the wordlist; Trezor's 24 official vectors | all equal |
| QR codes | module-by-module against segno for 40 versions × 8 masks; zxing-cpp decodes 42 real phrases and app screenshots | all equal, all decoded |
| Protocol | Kotlin against the Python reference (argon2-cffi + Trezor's mnemonic) on SPEC's 7 vectors; the app (emulator) against the Python reference with the real domain constant | equal |
| Freeze guards | protocol constants and the domain ID are pinned by tests | pass |
| The tests themselves | deliberately broken Argon2, QR masking and thread shutdown on cancel | each caught |
| Keyboard | every character class typed on the app's keyboard in the emulator; taps in the gaps and along the edges; sliding; two-finger rollover with real multi-pointer events | as designed |
| Input isolation | system keyboard state while the fields have focus; text and key events injected over adb | the system keyboard never appears; injection blocked |
| Cancel and abort | Cancel, Home and turning Wi-Fi on during a derivation | CPU from 300%+ to 0 within 2 s, no crash |
| Offline gate | every switch, on emulators (API 36, 30) and a Redmi K40 (HyperOS) | input and generation only offline; Bluetooth "half-on" detected |
| Memory | 8 derivations in a row on an emulator with a 192 MB Java heap limit | memory released each time |
| Screenshots, permissions | `screencap` on the device; the merged manifest | black; 0 permissions |

Argon2id, 1 GiB × 128 passes, 4 lanes: Redmi K40 (Snapdragon 870) release build 64.6 s, with no
throttling over a minute of full load; desktop JVM (M2 Pro) about 22 s; argon2-cffi (reference C
code, M2 Pro) about 25 s. Reproduce with `./gradlew :core:test` and `./gradlew :core:bench`; on a
phone, with a debug build:
`adb shell 'CLASSPATH=$(pm path app.getkeyper.private | cut -d: -f2) app_process / app.getkeyper.DeviceBenchKt'`.
`reference/make_fixtures.py` generates the test fixtures from the independent implementations
above.

## Known limitations

- The domain constant can be extracted from the APK; it is not a secret.
- The strength estimate is a heuristic. It does not recognise famous lines or public facts.
- Spelling must stay consistent over the years (capitals, symbols, pinyin such as `zh`/`z` or
  `ü` as `v`/`u`). The drill catches mistakes today; it cannot catch memory drifting later.
- The 60-second clipboard clear needs the app process alive. If the app is swiped away, Android
  13+ clears the clipboard after about an hour; older versions keep it. Keyboard apps and vendor
  clipboard histories may keep a copy: prefer the QR code, or copy the words by hand.
- The offline gate checks airplane mode, Wi-Fi and Bluetooth only, not USB tethering, Ethernet
  adapters or NFC. It prevents mistakes; it is not isolation.
- Hiding content from accessibility services needs Android 14+. On older systems the offline
  phone itself must be clean.
- Kotlin strings cannot be reliably wiped; the 1 GiB working memory goes back to the kernel
  after each run. Memory forensics is outside the threat model.
- 4 GB of RAM or more is needed. Not tested on 32-bit or low-end phones; phones slower than a
  K40 may take several minutes.
- The application ID `app.getkeyper.private` contains a Java keyword, so the code namespace is
  `app.getkeyper`.
- targetSdk 36; behaviour changes in Android 17 (API 37) have not been evaluated yet.

## Repository layout

```
SPEC.md                     the protocol: v1, frozen; design decisions; test vectors
SECURITY.md                 how to report a vulnerability
docs/security-audit.md      pre-freeze security audit, attack scenarios, residual risks
reference/keyper.py         independent Python implementation (cross-checks, recovery without the app)
reference/make_fixtures.py  regenerates the test fixtures from independent implementations
app-android/core/           pure Kotlin/JVM: protocol, Argon2id, BLAKE2b, BIP39, QR codes, strength estimate
app-android/app/            Android UI: keyboard, offline gate, recovery drill; platform views only
```

## Contributing

Bug reports, translations and UI improvements are welcome. The protocol is frozen: no change
may alter a v1 phrase. See [CONTRIBUTING.md](CONTRIBUTING.md).

## License

Copyright © 2026 Shelchin. Keyper is free software, licensed under the
[GNU General Public License v3.0](LICENSE).
