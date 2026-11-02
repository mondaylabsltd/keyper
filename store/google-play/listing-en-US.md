# Google Play listing (en-US)

Character counts are checked against Play Console's limits.

## App name (23/30)

```
Keyper: Recovery Phrase
```

## Short description (76/80)

```
Your email and a sentence only you know give the same BIP39 phrase, offline.
```

## Full description (2434/4000)

```
Keyper turns your email and a sentence only you know into a standard BIP39 recovery phrase, on an offline phone. The same inputs always give the same phrase, so there is nothing to write down and nothing to lose in a drawer or a fire. Keyper saves nothing you type.

HOW IT WORKS
1. Turn on airplane mode and switch off Wi-Fi and Bluetooth. Keyper lets you type only while the phone is offline.
2. Type your email, then your sentence, on Keyper's own keyboard.
3. Wait about a minute while Keyper runs Argon2id over 1 GiB of memory, 128 passes.
4. Copy the 12 or 24 words into a wallet on the same phone, or show them as a QR code.

EXPENSIVE TO GUESS
Argon2id makes each guess expensive, but an attacker’s hardware may be faster than your phone. The strength score is a rough model, not a measurement of your sentence’s entropy or a security guarantee. Quotes, lyrics, reused passwords and public personal facts can be easy to guess even when the score says Strong.

PROTECTIONS
- Its own keyboard: the system keyboard never sees what you type, so it cannot learn, sync or upload it.
- Offline gate: while Keyper is active, detected radio changes block derivation and clear sensitive screen data. Its current clipboard copy is cleared when Android permits.
- No permissions, no network access, no account, no analytics.
- Android’s secure-window flag protects against screenshots, screen recordings and app-switcher previews on supported systems.
- Copies are marked sensitive and scheduled for clearing after 60 seconds. Android background restrictions can delay removal until Keyper returns to the foreground. Clipboard history may retain copies.
- Recovery drill: type both inputs again from memory and check that they give the same phrase before you use it.

OPEN AND RECOVERABLE
The derivation is published and frozen, so every version of Keyper gives the same phrases, on Android and iPhone alike. The source code is open under the MIT License, and an independent Python script gives the same phrase on a computer if your phone is ever lost.

IMPORTANT
Nobody, including us, can recover a forgotten sentence. Choose one you will remember for years, keep its spelling consistent, and do the recovery drill.

Keyper is not a wallet: it never holds or moves funds. Use the phrase in any wallet that accepts a standard 12- or 24-word BIP39 phrase.

Needs Android 8.1 or later and 4 GB of RAM or more.
Website: https://getkeyper.app
```
