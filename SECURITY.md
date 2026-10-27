# Security policy

## Reporting a vulnerability

Please email **hello@mondaylabs.ltd** with "Keyper security" in the subject. Do not open a public
issue or pull request for a vulnerability.

Include what you found, how to reproduce it, the app version (Android: Settings → Apps → Keyper;
iPhone: Settings → General → iPhone Storage → Keyper),
the domain ID from the app's footer, and the device and system version if relevant. You should get an
acknowledgement within a week. Fixes are released as soon as they are ready, and you will be
credited unless you prefer otherwise.

## Scope

In scope:

- Any deviation of either app or of `reference/keyper.py` from [SPEC.md](SPEC.md), or any input
  on which they disagree.
- Weaknesses in the derivation as specified: Argon2id usage, salt, HMAC construction, BIP39
  encoding.
- Leaks of the email, the sentence or the phrase: the keyboard, the clipboard, accessibility,
  screenshots, autofill, logs, memory left behind after use.
- Ways around the offline gate, or around input isolation (paste, injection, the system
  keyboard).
- Build and supply-chain problems in this repository.
- The website, getkeyper.app: anything that could mislead visitors about where to get Keyper or
  how to recover a phrase.

By design, and not vulnerabilities:

- The domain constant can be read from either app. It is public (SPEC.md §3).
- Phrases from guessable sentences can be recovered by guessing. The strength meter is a hint.
- A compromised offline phone (rooted or jailbroken, a malicious accessibility service on
  Android 13 or older, a camera watching the screen) is outside the threat model.
- On iOS, the screen shield and the offline gate do what iOS allows without private APIs or
  permissions (see the README's known limitations).

## Supported versions

Only the latest release receives fixes. Protocol v1 is frozen, so a fix never changes a v1
phrase. If a flaw is ever found in v1 itself, it will be addressed by a new protocol version,
and the app will keep deriving v1 phrases for as long as anyone may need to recover them.

## Further reading

- [SPEC.md §4](SPEC.md#4-security-model): threat model and the cost of guessing
- [docs/security-audit.md](docs/security-audit.md): the pre-freeze audit, attack scenarios and
  residual risks
