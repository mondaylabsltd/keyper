# Notes for app review

Paste into App Store Connect (App Review Information → Notes) and Play Console (App content →
App access → "All or some functionality is restricted", with these instructions).

```
Keyper works only while the phone is offline. This is deliberate: it turns an email and a
sentence the user remembers into a standard BIP39 recovery phrase, and the sentence must never be
typed on a connected phone.

To test:
1. Turn on Airplane Mode and turn off Wi-Fi (Control Center). Turn off Bluetooth too; the app
   reminds you, but on iPhone it cannot check it.
2. Open Keyper. Type any email, e.g. review@example.com, then a sentence of at least 12
   characters, e.g. "Apple review 2026 test sentence". Both fields use Keyper's own keyboard;
   the system keyboard never appears, so nothing reaches keyboard apps.
3. Tap Generate. It takes about a minute (about 70 s on an iPhone 11): the app runs Argon2id
   over 1 GiB of memory on purpose, so that guessing sentences is slow.
4. The 12-word phrase appears. "First time? Do a recovery drill" lets you type both inputs again
   and checks they match. Turning Wi-Fi back on wipes everything at once.

A short or common sentence shows a warning first; tap "Generate anyway" to continue.

Keyper makes no network connections, has no account and collects no data. It is not a wallet:
it holds no funds and makes no transactions. The phrase works in any wallet that accepts a
standard BIP39 phrase.

The source code and the protocol are public: https://github.com/mondaylabsltd/keyper
```
