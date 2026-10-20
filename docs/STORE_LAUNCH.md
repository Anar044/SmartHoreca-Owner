# SH Owner — publication readiness (October 2026)

## Current status

The Flutter app and Android debug pilot already exist. A debug APK is **not**
a Google Play release. The iOS simulator compile in `ios-smoke.yml` is **not**
an installable TestFlight build. Production publication is not automatic.

The pilot API currently targets a separate Cloudflare Preview environment.
Before inviting external users, confirm that the production API routes exist
with identical organization isolation; never silently change the target.

## Identity — must be agreed before creating store records

- Home screen label on both devices: **SH Owner**.
- In-app title and brand: **Smart Horeca Owner**.
- Suggested permanent iOS Bundle ID: `com.smarthoreca.owner`.
- Suggested Android applicationId: `com.smarthoreca.owner`.
- IDs are suggestions, not registered yet: the owner must confirm uniqueness
  in App Store Connect and Google Play Console before activation.
- Changing Android applicationId from the existing pilot package creates a
  distinct installation and resets the pilot's local preferences and FCM token.
  Avoid replacing it silently.

## TestFlight preparation

1. In Apple Developer, register the final Bundle ID (explicit identifier).
2. In App Store Connect, create an **iOS app** record named `SH Owner`
   associated with that Bundle ID. Pick SKU/category.
3. Configure Apple Distribution certificate + matching App Store provisioning
   profile named `AppStore <bundle-id>` (enable Push Notifications capability
   before creating the profile if you plan to test notifications).
4. GitHub repository Settings → Secrets and variables → Actions:
   - Variables: `SH_OWNER_IOS_BUNDLE_ID`, `APPSTORE_TEAM_ID`,
     `APPSTORE_ISSUER_ID`, `APPSTORE_API_KEY_ID`.
   - Secrets: `APPSTORE_API_PRIVATE_KEY` (.p8 contents),
     `APPSTORE_CERTIFICATES_FILE_BASE64` (base64 of Apple Distribution .p12),
     `APPSTORE_CERTIFICATES_PASSWORD` (p12 password).
   - Never paste private keys, signing certificates, or API tokens into chat.
5. GitHub Actions → **SH Owner Upload to TestFlight** →
   Run workflow manually. The workflow checks prerequisites, builds signed IPA
   on macOS, and uploads it to App Store Connect if signing succeeds.
6. In TestFlight, create an Internal Testing group and add the Apple ID of
   the user who will test the iPhone build. A non-App-Store-Connect user should
   be invited as an external tester; Apple's beta review can be required.
7. Install Apple's TestFlight app on iPhone and accept invitation.

### iOS Firebase push (additional setup)

Android FCM options do **not** work on iOS. For APNs-backed FCM notifications:

- Register the exact iOS Bundle ID in the same Firebase project.
- Upload your APNs authentication key to Firebase Cloud Messaging
  (or configure an Apple certificate). Enable Push Notifications / Background
  Modes in Xcode and your provisioning profile.
- Provide GitHub vars `SH_FIREBASE_IOS_API_KEY`,
  `SH_FIREBASE_IOS_APP_ID`, and `SH_FIREBASE_PROJECT_ID`,
  `SH_FIREBASE_SENDER_ID`. The iOS bundle ID must be consistent with
  `SH_OWNER_IOS_BUNDLE_ID`.
- A TestFlight build without these values can test login, read-only reports,
  and navigation, but iOS push remains disabled and must not be called verified.

## Google Play preparation

- Set an immutable Android applicationId once you register a new app in Play
  Console. Existing debug pilot can continue under its current package.
- Generate a **release-signed .aab**, not a debug .apk. Protect the keystore,
  alias and passwords in GitHub Secrets, and enable Play App Signing.
- Prepare store description, icon, feature graphic, 2+ real screenshots,
  contact email, privacy policy URL, Data Safety form, app-access/reviewer
  credentials, target audience, and appropriate permissions disclosures.
- Start with Internal Testing; launch public production only after full
  security/access review, privacy checks and store approvals.
- For certain **personal Play developer accounts created after Nov 13, 2023**,
  Google requires a closed test with 12 opted-in testers for 14 consecutive
  days before requesting production access.

## Release gates

- Verify multi-tenant and restaurant isolation across all read-only endpoints,
  reports, AI and push, in a production-like environment.
- Confirm splash + launcher icon in both themes, 320dp/390dp and iPhone sizes.
- Confirm real-device Android and iOS login and restaurant picker.
- Verify alerts and deep links on both operating systems, including cold start.
- Confirm backend error behavior (503, expired session, offline cash) before
  submitting publicly.
