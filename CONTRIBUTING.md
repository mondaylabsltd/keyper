# Contributing to Keyper

Thanks for helping. Bug reports, translations, UI and accessibility improvements, documentation
and better tests are all welcome. For security issues, follow [SECURITY.md](SECURITY.md)
instead of opening an issue.

## Ground rules

Keyper is used to regenerate wallet recovery phrases from memory, possibly years from now. A few
rules follow from that and are not negotiable:

1. **Protocol v1 is frozen.** No change may alter the phrase derived from any v1 input: not the
   alphabet, normalisation, minimum lengths, salt, HMAC labels, Argon2id parameters or wordlist.
   `KeyperTest.protocolV1IsFrozen` and the SPEC vectors fail the build if one does. Ideas that
   need a protocol change belong in an issue about a future v2.
2. **The domain constant never changes** in this repository. `DomainTest` guards it.
3. **No permissions, no network, no storage.** The app must keep working on an offline phone and
   keep nothing.
4. **No new runtime dependencies.** The app uses only the Android platform; the core uses only
   the JDK. Test-only dependencies need a good reason.
5. **The strength meter may change; the rules it enforces may not.** It can warn differently,
   but it must never refuse a sentence that v1 accepts, or someone could be locked out.

## Building and testing

You need JDK 17 or later and the Android SDK (compileSdk 36).

```sh
cd app-android
./gradlew :core:test :app:testDebugUnitTest :app:lintDebug :app:assembleDebug
```

`:core:test` runs the SPEC vectors with the full 1 GiB Argon2id and takes a few minutes. Lint
should report no new warnings.

If you touch the derivation code or the Python reference, also run the independent check:

```sh
pip install -r reference/requirements.txt
python3 reference/keyper.py --self-test
```

The fixtures in `app-android/core/src/test/resources` come from independent implementations;
regenerate them with `reference/make_fixtures.py`, never by hand.

## Pull requests

- Keep each pull request to one change, and explain why it is needed.
- Match the style of the surrounding code ([Kotlin coding conventions](https://kotlinlang.org/docs/coding-conventions.html)).
  Comments explain why, not what.
- User-facing text goes in `res/values/strings.xml` and `res/values-zh/strings.xml`. A new
  language also needs an entry in `res/xml/locales_config.xml`.
- UI changes: include before and after screenshots from a build without `FLAG_SECURE` (debug
  builds keep it too, so remove it locally for the screenshots only).
- Update README.md and README-zh.md when behaviour visible to users changes, and CHANGELOG.md
  for anything notable.

By contributing, you agree that your contributions are licensed under the
[GNU General Public License v3.0](LICENSE).
