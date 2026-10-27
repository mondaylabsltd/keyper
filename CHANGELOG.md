# Changelog

All notable changes to Keyper are recorded here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and app versions follow
[Semantic Versioning](https://semver.org/). The derivation protocol is versioned separately in
[SPEC.md](SPEC.md): v1 is frozen, and no app release will ever change a v1 phrase.

## [1.0.0] - Unreleased

First release, with protocol v1.

### Protocol v1 (frozen)

- Email and a remembered sentence → standard BIP39 phrase of 12 or 24 words.
- Sentence: 80 ASCII characters (letters, digits, `!@#$%^&*().,?-_+=/`) and spaces; runs of
  spaces count as one, spaces at either end are dropped; at least 12 characters.
- Email: NFKC, then only ASCII letters and digits, lowercased, as the salt; at least 6 characters.
- HMAC-SHA256 with the deployment's 32-byte domain constant, then Argon2id with 1 GiB, 128
  passes and 4 lanes; independent HMAC-derived entropy for 12 and 24 words.
- Seven test vectors, reproduced by the app's core and by the independent Python reference.

### Android app

- Keyper's own keyboard for both fields, with no connection to the system keyboard: fixed
  layout, monospace keys, iPhone-style touch (nearest key, magnified preview, type on lift,
  slide to correct, two-finger rollover), and Android's own cursor, handle and magnifier.
- Offline gate: airplane mode on, Wi-Fi and Bluetooth off; going online wipes everything.
- Strength estimate with crack time and electricity cost for 1000 GPUs; a warning below
  US$100 million.
- Progress and cancel for the minute-long derivation, off-heap working memory.
- Copy, cleared from the clipboard after 60 seconds or when the phone goes online; QR code;
  recovery drill.
- No screenshots, nothing stored, no permissions; English and Chinese.

### iOS app

- The same app for iPhone (iOS 17+), deriving the same phrases: a Swift core on the system's
  CryptoKit, tested against the same fixtures and SPEC vectors as the Android core.
- SwiftUI screen laid out like the Android app's, with UIKit for the keyboard (the same touch
  rules), for fields with the native cursor and no system keyboard, and for the screen shield.
- Offline gate from what iOS shows without asking anything: no network interface beyond the
  link, cellular radio off; Bluetooth as a reminder. No Network framework, which would make
  iPhones sold in mainland China ask to allow wireless data.
- Screenshots, recordings and the app switcher see nothing; the copied phrase stays on the device
  and is cleared after 60 seconds or when the phone goes online.
