# App Store listing (en)

Character counts are checked against App Store Connect's limits.

## Name (23/30)

```
Keyper: Recovery Phrase
```

## Subtitle (30/30)

```
A recovery phrase in your head
```

## Promotional text (153/170)

```
Your email and a sentence only you know give the same BIP39 recovery phrase every time. Nothing to write down, nothing stored, and it works only offline.
```

## Keywords (88/100)

```
seed phrase,bip39,mnemonic,offline,cold wallet,bitcoin,crypto,backup,self custody,argon2
```

## Description (2429/4000)

```
Keyper turns your email and a sentence only you know into a standard BIP39 recovery phrase, on an offline phone. The same inputs always give the same phrase, so there is nothing to write down and nothing to lose in a drawer or a fire. Keyper saves nothing you type.

HOW IT WORKS
1. Turn on airplane mode and switch off Wi-Fi and Bluetooth. Keep the phone offline while entering inputs and deriving a phrase.
2. Type your email, then your sentence, on Keyper's own keyboard.
3. Wait about a minute while Keyper runs Argon2id over 1 GiB of memory, 128 passes.
4. Copy the 12 or 24 words into a wallet on the same phone, or show them as a QR code.

EXPENSIVE TO GUESS
Argon2id makes each guess expensive, but an attacker’s hardware may be faster than your phone. The strength score is a rough model, not a measurement of your sentence’s entropy or a security guarantee. Quotes, lyrics, reused passwords and public personal facts can be easy to guess even when the score says Strong.

PROTECTIONS
- Its own keyboard: the system keyboard never sees what you type, so it cannot learn, sync or upload it.
- Offline gate: while Keyper is active, detected connectivity blocks derivation and clears sensitive screen data and Keyper’s copy. iOS cannot verify Bluetooth or Wi-Fi that is enabled but not connected; turn both off in Settings.
- No network requests, no account and no analytics.
- Screen content is shielded from capture where supported by iOS, and hidden in the app switcher. Capture protection can vary with system versions.
- Copies stay on this device and are set to expire after 60 seconds. Clipboard history in other apps may retain copies.
- Recovery drill: type both inputs again from memory and check that they give the same phrase before you use it.

OPEN AND RECOVERABLE
The derivation is published and frozen, so every version of Keyper gives the same phrases, on Android and iPhone alike. The source code is open under the MIT License, and an independent Python script gives the same phrase on a computer if your phone is ever lost.

IMPORTANT
Nobody, including us, can recover a forgotten sentence. Choose one you will remember for years, keep its spelling consistent, and do the recovery drill.

Keyper is not a wallet: it never holds or moves funds. Use the phrase in any wallet that accepts a standard 12- or 24-word BIP39 phrase.

Needs iOS 17 or later and 4 GB of RAM or more.
Website: https://getkeyper.app
```

## What's New (14/4000)

```
First release.
```

## URLs

```
Support URL: https://github.com/mondaylabsltd/keyper/issues
Marketing URL: https://getkeyper.app
Privacy Policy URL: https://getkeyper.app/privacy
```
