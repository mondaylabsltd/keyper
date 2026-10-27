# Store submission

What Google Play and the App Store ask for, ready to paste or upload.

| File | Use |
|---|---|
| `app-store/listing-en.md`, `app-store/listing-zh-Hans.md` | name, subtitle, promotional text, keywords, description, URLs |
| `google-play/listing-en-US.md`, `google-play/listing-zh-CN.md` | name, short and full description |
| `review-notes.md` | notes for App Review and Play's "App access" |
| `privacy-and-compliance.md` | App Privacy, Data safety, ratings, export compliance, pricing |
| `google-play/feature-graphic-{en,zh}.png` | 1024×500 feature graphic (source: `feature-graphic.html`) |
| `google-play/icon-512.png`, `app-store/icon-1024.png` | store icons |
| `*/screenshots/{en,zh}/` | raw phone screenshots |
| `*/framed/{en,zh}/` | the same with captions, for upload (source: `screenshot-frame.html`) |

## Google Play

1. Create an upload key once and keep it, with a backup, offline:
   `keytool -genkeypair -keystore keyper-upload.jks -alias upload -keyalg RSA -keysize 4096 -validity 10000`.
   Point `app-android/keystore.properties` at it (`storeFile`, `storePassword`, `keyAlias`,
   `keyPassword`; git-ignored) and enrol in Play App Signing.
2. `cd app-android && ./gradlew :app:bundleRelease` →
   `app/build/outputs/bundle/release/app-release.aab`.
3. After the first upload, copy the SHA-256 of the app signing certificate from Play Console →
   Test and release → App integrity, and publish it in the README, so anyone can check an APK.

## App Store

1. In Xcode, set your team on the Keyper target, then Product → Archive (Release) and upload from
   the Organizer.
2. Fill in the listing, privacy answers and review notes; attach the 6.9-inch screenshots.

## After either store approves

- Set `googlePlay` / `appStore` in `website/src/lib/site.ts` to the listing URLs; the pricing
  card then shows store buttons instead of "Coming soon".
- Tag the released commit (`git tag v1.0.0`) so the store version can be matched to the source.

## Re-rendering the graphics

`cd website && node scripts/render-store.mjs` renders the framed screenshots from the raw ones
and the feature graphic. The captions are in that script.
