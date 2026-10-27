# Privacy, rating and compliance answers

The answers both stores ask for, and why each is true. Check them against the code if the app
changes.

## App Store Connect

- **App Privacy → Data collection:** "No, we do not collect data from this app." The app has no
  network code; the only stored value is the language choice, kept on the device by iOS.
- **Privacy manifest:** `app-ios/Keyper/PrivacyInfo.xcprivacy` declares the one required-reason
  API (UserDefaults, reason CA92.1) and no tracking.
- **Export compliance:** `ITSAppUsesNonExemptEncryption = NO`. The app uses only hashing
  (HMAC-SHA256, SHA-256, Argon2id) and no encryption.
- **Age rating:** answer "None" to every content question → 4+.
- **Category:** Utilities (secondary: Finance).
- **Price:** US$29.99 in the United States; let Apple derive the other storefronts' prices from
  it (do not set regional prices).
- **Guideline 3.1.5 (cryptocurrencies):** Keyper is not a wallet and moves no funds; it is
  published by an organisation (MONDAY LABS LTD), as wallet-related apps must be.
- **Availability:** iPhone only; Mac (Designed for iPhone) and Apple Vision Pro are disabled in
  the project.

## Google Play Console

- **Data safety:** "No" to "Does your app collect or share any of the required user data types?"
  No data is collected or shared; there is nothing to encrypt in transit or to delete.
- **Content rating (IARC):** category "Utility, productivity, communication or other"; "No" to
  every content question → Everyone / PEGI 3.
- **Target audience:** 18 and over (crypto-related; keeps the app out of the Families policy).
- **Ads:** no.
- **App access:** see `review-notes.md`.
- **Financial features declaration:** Keyper provides none of the listed services (no custody,
  exchange, transfers or trading). If the form insists on a crypto category, choose the
  non-custodial / software wallet option and explain in the notes that the app only derives a
  BIP39 phrase offline and never holds or moves funds.
- **Category:** Tools.
- **Price:** US$29.99; accept Google's converted local prices rather than a pricing template.
  Paid apps need a payments (merchant) profile.
- **Developer account:** organisation accounts are exempt from the closed-test requirement
  (12 testers for 14 days) that applies to personal accounts created after November 2023.
- **Permissions:** the merged manifest declares none.
