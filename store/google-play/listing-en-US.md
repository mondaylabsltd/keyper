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

## Full description (2211/4000)

```
Keyper turns your email and a sentence only you know into a standard BIP39 recovery phrase, on an offline phone. The same inputs always give the same phrase, so there is nothing to write down and nothing to lose in a drawer or a fire. Keyper saves nothing you type.

HOW IT WORKS
1. Turn on airplane mode and switch off Wi-Fi and Bluetooth. Keyper lets you type only while the phone is offline.
2. Type your email, then your sentence, on Keyper's own keyboard.
3. Wait about a minute while Keyper runs Argon2id over 1 GiB of memory, 128 passes.
4. Copy the 12 or 24 words into a wallet on the same phone, or show them as a QR code.

EXPENSIVE TO GUESS
Every guess costs an attacker the same minute of work. With assumptions that favour the attacker, finding a sentence with 50 bits of entropy would cost over US$300 million in electricity alone. Keyper estimates this while you type and warns you about weak sentences. Famous lines, lyrics and birthdays are easy to guess whatever their length: use details only you know.

PROTECTIONS
- Its own keyboard: the system keyboard never sees what you type, so it cannot learn, sync or upload it.
- Offline gate: going back online wipes the sentence, the phrase and the clipboard.
- No permissions, no network access, no account, no analytics.
- Screenshots and screen recordings show nothing, and the app switcher shows a blank screen.
- A copied phrase is cleared after 60 seconds.
- Recovery drill: type both inputs again from memory and check that they give the same phrase before you use it.

OPEN AND RECOVERABLE
The derivation is published and frozen, so every version of Keyper gives the same phrases, on Android and iPhone alike. The source code is open under the MIT License, and an independent Python script gives the same phrase on a computer if your phone is ever lost.

IMPORTANT
Nobody, including us, can recover a forgotten sentence. Choose one you will remember for years, keep its spelling consistent, and do the recovery drill.

Keyper is not a wallet: it never holds or moves funds. Use the phrase in any wallet that accepts a standard 12- or 24-word BIP39 phrase.

Needs Android 8.1 or later and 4 GB of RAM or more.
Website: https://getkeyper.app
```
