# Keyper security audit (before freezing protocol v1, 2026-10-21)

English · [简体中文](security-audit-zh.md). To report a vulnerability, see [SECURITY.md](../SECURITY.md).

Scope: the protocol, the Android app and the Python reference. The iOS app came later and is not
covered here.

Method: a reviewer who had not worked on the code read SPEC.md, the Kotlin implementation, the
Android UI and the Python reference implementation; the developers then checked every finding,
reproduced it on emulators and a real phone, fixed it and added tests. The cryptography
(Argon2id, HMAC, BIP39, the salt, the cost model) showed no problems. The findings concern two
things: whether users can still recover exactly years later, and leaks while typing.

## 1. Conclusions

1. **With a sentence that is hard enough to guess, guessing the phrase does not pay.** Every
   guess costs 1 GiB of memory × 128 passes; for a sentence of about 48.4 bits or more, the
   electricity alone exceeds US$100 million (under assumptions that favour the attacker, see
   [SPEC §4](../SPEC.md#4-security-model)).
2. **How guessable the sentence is lies outside the app's control.** Famous lines, lyrics,
   proverbs and templates of public facts are tried first, however large the parameters.
3. **The domain constant ships in the APK and provides no confidentiality.** It only keeps
   different deployments apart.
4. **The largest practical risk is users failing to recover their own phrase.** So the protocol
   restricts input to 80 unambiguous ASCII characters, ignores extra spaces, and the app offers a
   recovery drill.

## 2. Findings and resolutions

| # | Finding | Severity | Resolution |
|---|---|---|---|
| 1 | Normalisation unified only some variants: `。`/`.`, quotes, invisible characters, case and others would derive different wallets, making recovery impossible | high · protocol | The secret now allows only 80 ASCII characters (letters, digits, 18 unambiguous symbols), typed only on the app's keyboard; a run of spaces counts as one and spaces at either end are dropped. The email keeps only ASCII letters and digits, lowercased |
| 2 | Unicode version dependence (Android 8.1 ships Unicode 9): normalisation could differ between devices | low · protocol | The secret no longer involves Unicode; the email uses NFKC only to fold full-width forms, which raises no version question in practice |
| 3 | Minimum lengths: an email could be a placeholder such as `a`, giving many people the same salt | medium · protocol | The email needs at least 6 letters or digits; the secret at least 12 characters (single spaces between words included) |
| 4 | The 12 words were the first half of the 24 words' entropy, so the two were not independent | medium · protocol | Each length is now derived from K by its own HMAC |
| 5 | Lone surrogates were handled differently by Kotlin and Python | low · protocol | Gone with the ASCII alphabet |
| 6 | The strength estimate was too optimistic (a famous line rated "strong") | high · app | Recalibrated for natural language (1.5 bits per lowercase letter); famous lines are no longer rated strong, though the meter still cannot recognise them |
| 7 | A single typo produced a wallet nobody could reproduce | high · app | Added the recovery drill: re-type from memory, compared at once |
| 8 | Screen-reading accessibility services could read the phrase | medium · app | The secret field, the phrase and the keyboard are marked as sensitive data (Android 14+) |
| 9 | Third-party keyboards learning, syncing to the cloud, keeping clipboard history | medium · app | Keyper's own keyboard for both fields: the fields give the system keyboard no connection at all; paste, drag-and-drop, hardware keys and injected key events are blocked (adb injection verified blocked) |
| 10 | Counterfeit packages, release signing | medium · distribution | README: install only from official channels; configure your own signing key before distributing and publish the certificate fingerprint |
| 11 | Clipboard | medium · app | Marked sensitive, cleared after 60 seconds; README recommends the QR code |
| 12 | Reading the Bluetooth state needs a permission on Android 8.1–11 | low | Re-checked: reading works without a permission on API 30 |

Also found and fixed during development: a native crash when cancelling, caused by worker threads
writing to memory that had already been released (regression test added); long words hidden at
large font sizes, so the phrase was shown incomplete; MIUI's Bluetooth "half-on" state disagreeing
with the system setting, which fooled the offline gate; Ctrl+Z restoring a secret that had been
cleared when leaving the app.

## 3. How a phrase could be recovered by someone else, most likely first

| Scenario | Precondition | Cost | What Keyper can do |
|---|---|---|---|
| 1. A famous line, lyric, proverb or common pattern | The attacker knows your email and has the APK | Thousands to millions of guesses, a few dollars | Warnings; a 12-character minimum. Beyond that, only details nobody else knows protect you |
| 2. A template of public personal facts (pet's name, birthday, place) | The attacker knows you or has researched you | 2²⁵–2³⁵ guesses, tens to tens of thousands of dollars | As above |
| 3. Malware or a screen-reading service on the same phone | You installed it on the offline phone | Low | Own keyboard, sensitive-data flags, screenshot blocking, offline gate; the offline phone must be clean |
| 4. A counterfeit package or a tampered update | You installed an unofficial package, or the developer account was compromised | Low | Install only official builds, turn off auto-update, publish the signing certificate fingerprint |
| 5. The same sentence used as a password elsewhere | That service leaks it, with the same email | Low | Advice: use the sentence for Keyper only |
| 6. Dragnet: leaked email lists × popular sentences | Your sentence is on the popular list | Cheaper at scale | The email salt forces one attack per person; the minimum email length prevents shared salts |
| 7. Being watched: bystanders, cameras on the QR code or the screen | Physical proximity | Low | The sentence is masked by default, but the magnified key preview (kept for accuracy, as on the iPhone) is visible to onlookers too: use the app alone and close the QR code as soon as it is scanned |
| 8. Two people sharing an email who happen to choose the same sentence | Very rare | — | Everyone uses their own email |

**When guessing fails**: the attacker has the APK, the algorithm, the domain
constant and your email, but your sentence is a long one only you know (about 48.4 bits of entropy
or more). Every guess then costs an Argon2id run of 1 GiB × 128 passes, and the expected cost
exceeds US$100 million.

## 4. Residual risks

- No program can guarantee the strength of the sentence; the estimate is a hint and does not
  recognise famous lines.
- The backup of the domain constant and the source is a single point of failure for every user's
  recovery: lose it and nobody can recover.
- Memory drifting over the years (case, symbols, pinyin spelling) is up to the user; the drill
  only proves that the user remembers today.
- Below Android 14 there are no sensitive-data flags, so screen-reading malware could in theory
  see the phrase; the offline phone itself must be clean.
- Keyboard apps or vendor systems may keep their own clipboard history.
