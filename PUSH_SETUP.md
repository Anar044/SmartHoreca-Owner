# Smart Horeca Owner — POS Push Notifications (Android)

## What is implemented
Authenticated owners/SYSADMIN receive FCM pushes for **five explicit POS event types**:
- Discount applied / removed
- Precheck cancelled
- Dish removed
- Receipt storned

POS events originate from the **authenticated** `/api/plugin/ingest` flow, are written to the existing Supabase plugin event journal, then forwarded to FCM using Cloudflare `waitUntil`. Dispatch is deduplicated in D1 and restricted by active workspace membership, Admin role and allowed department scope. No push is invented from a periodic order snapshot.

## Firebase setup — required before sending real pushes

1. Create a Firebase project and register an **Android** app with application ID **`com.example.smart_horeca_owner`** used by the current generated pilot Android runner. If you change the Android package/applicationId, update the Firebase registration too. The current build workflow runs `flutter create . --platforms=android,ios`.
2. In **GitHub repository Anar044/SmartHoreca-Owner → Settings → Secrets and variables → Actions → Variables**, set public Android Firebase configuration values:
   - `SH_FIREBASE_ANDROID_API_KEY`
   - `SH_FIREBASE_ANDROID_APP_ID`
   - `SH_FIREBASE_SENDER_ID`
   - `SH_FIREBASE_PROJECT_ID`
3. Obtain a dedicated Firebase Admin service account from a secure Google Cloud IAM setup with permissions for **Firebase Cloud Messaging API**. In **Cloudflare Pages → smarthoreca → Settings → Variables and Secrets**, configure encrypted server-side secret **`FCM_SERVICE_ACCOUNT_JSON`** for the **Preview environment** used by the pilot API; do not place it in GitHub, Flutter, public files, or messages. Deploy and validate preview before production.
4. Install a newly built `Smart-Horeca-Owner-Android-Real-Data-Pilot` APK, open **Уведомления**, and switch on **Push от Smart Horeca Owner**. Allow Android notifications. Test a **verified** POS discount event from a restaurant the owner is authorized to view.

## Scope & operation
- Notifications are scoped to the restaurant selection active when the device registers.
- On logout, the app unregisters and deletes its FCM token; server rechecks membership at send time.
- A 503 from Firebase or Cloudflare should not block POS event ingestion.
- The stored event ID is used for D1 deduplication. If the plugin did not send an event type, we cannot notify about it.
- App foreground: shows a Smart Horeca snackbar; app background/closed: Android displays FCM notification payload. Some manufacturers' battery restrictions can delay background notifications.
- Firebase is **optional** for pre-configuration pilot APKs: no credentials means the app still runs, but the push switch remains disabled.
- **Do not deploy the feature branch wholesale to production** without resolving its unrelated conflicts, reviewing the changes, and testing scoped alerts end-to-end.
